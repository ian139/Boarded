import Foundation
import Combine
import Network
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Replays locally-pending sessions, attempts, and session posts to Supabase.
/// Replay is idempotent because every record carries a client-generated UUID
/// and the server upserts on `id`; a replayed write never duplicates data.
/// Records are never dropped on failure: failed rows stay `failed` and are
/// retried on the next connectivity or app-active trigger.
@MainActor
final class SessionSyncService: ObservableObject {

    @MainActor
    private enum PublicationCoordinator {
        private static var activeClaims: [UUID: UUID] = [:]

        static func acquire(draftID: UUID, claimID: UUID) -> Bool {
            guard activeClaims[draftID] == nil else { return false }
            activeClaims[draftID] = claimID
            return true
        }

        static func release(draftID: UUID, claimID: UUID) {
            guard activeClaims[draftID] == claimID else { return }
            activeClaims.removeValue(forKey: draftID)
        }

        static func isActive(draftID: UUID, claimID: UUID) -> Bool {
            activeClaims[draftID] == claimID
        }

        static func activeClaimID(draftID: UUID) -> UUID? {
            activeClaims[draftID]
        }
    }
    private enum ReplayError: LocalizedError {
        case missingImage(UUID)
        case missingSourceImage(UUID)
        case invalidSession(UUID)
        case sessionNotEnded(UUID)
        case missingFeaturedAttempt(UUID)
        case publicationCancelled(UUID)

        var errorDescription: String? {
            switch self {
            case .missingImage(let draftID):
                return "The image for pending draft \(draftID.uuidString) is missing."
            case .missingSourceImage:
                return "This photo is unavailable. Choose it again to retry."
            case .invalidSession(let sessionID):
                return "The session \(sessionID.uuidString) is invalid or not owned by the active user."
            case .sessionNotEnded(let sessionID):
                return "Session \(sessionID.uuidString) must be ended before a session post can be published."
            case .missingFeaturedAttempt(let attemptID):
                return "The featured attempt \(attemptID.uuidString) was not found."
            case .publicationCancelled(let draftID):
                return "Publication for pending draft \(draftID.uuidString) was cancelled."
            }
        }
    }

    enum DraftImageCleanupError: LocalizedError, Equatable {
        case invalidFileName(String)
        case failed(String, String)

        var errorDescription: String? {
            switch self {
            case .invalidFileName(let fileName):
                return "The draft image file name is invalid: \(fileName)."
            case .failed(let fileName, let reason):
                return "Failed to remove draft image \(fileName): \(reason)"
            }
        }
    }

    enum DraftMediaError: LocalizedError, Equatable {
        case sourceDataRequired
        case incompletePair(String)
        case publicationAlreadyStarted

        var errorDescription: String? {
            switch self {
            case .sourceDataRequired:
                return "Choose a photo before sharing this session."
            case .incompletePair:
                return "This photo could not be saved. Choose it again to retry."
            case .publicationAlreadyStarted:
                return "This photo has already started publishing. Discard it and share it again."
            }
        }
    }

    @Published private(set) var state: SyncState = .synced
    @Published private(set) var errorMessage: String?

    private let repository: any SessionRepository
    private let feedRepository: any FeedRepository
    private let modelContext: ModelContext
    private let userID: UUID
    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "boarded.session-sync.monitor")

    private var isSyncing = false
    private var hasConnectivity = true
    private var appActiveObserver: NSObjectProtocol?

    var isOnline: Bool { hasConnectivity }

    /// Internal failure seam for testing persistence failures deterministically.
    var saveHook: (() throws -> Void)?

    /// Internal failure seam for testing image cleanup failures deterministically.
    var imageRemover: ((String) throws -> Void)?

    /// Internal failure seam for testing paired media writes deterministically.
    var imageWriter: ((Data, String) throws -> Void)?

    private func saveModelContext() throws {
        if let saveHook {
            try saveHook()
        }
        try modelContext.save()
    }

    convenience init(
        repository: any SessionRepository,
        modelContext: ModelContext,
        userID: UUID,
        connectivityOverride: Bool? = nil
    ) {
        self.init(
            repository: repository,
            feedRepository: AppServices.feedRepository,
            modelContext: modelContext,
            userID: userID,
            connectivityOverride: connectivityOverride
        )
    }

    init(
        repository: any SessionRepository,
        feedRepository: any FeedRepository,
        modelContext: ModelContext,
        userID: UUID,
        connectivityOverride: Bool? = nil
    ) {
        self.repository = repository
        self.feedRepository = feedRepository
        self.modelContext = modelContext
        self.userID = userID
        self.pathMonitor = NWPathMonitor()
        self.hasConnectivity = connectivityOverride ?? true
        if connectivityOverride == nil {
            pathMonitor.pathUpdateHandler = { [weak self] path in
                let online = path.status == .satisfied
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let wasOffline = !self.hasConnectivity
                    self.hasConnectivity = online
                    if online && wasOffline {
                        await self.replay()
                    }
                }
            }
            pathMonitor.start(queue: monitorQueue)
        }

        #if canImport(UIKit)
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.replay()
            }
        }
        #endif
        do {
            let allDrafts = try modelContext.fetch(FetchDescriptor<PendingSessionDraft>())
            let deletionTombstones = try modelContext.fetch(FetchDescriptor<PendingDraftDeletion>())
            let activeFileNames = Set(
                (allDrafts.map(\.imageFileName) + deletionTombstones.map(\.imageFileName))
                    .filter { !$0.isEmpty }
            )
            DraftImageStore.reconcile(activeFileNames: activeFileNames)
        } catch {
            // Leave staged deletions untouched so a later recovery pass can
            // reconcile them once draft rows are readable again.
        }
    }

    deinit {
        pathMonitor.cancel()
        if let appActiveObserver {
            NotificationCenter.default.removeObserver(appActiveObserver)
        }
    }

    /// Persists a pending session locally before any network I/O. Throws when
    /// the save fails so callers never silently lose a session.
    func enqueue(session: PendingSession) throws {
        session.syncState = .queued
        modelContext.insert(session)
        try saveModelContext()
        state = .queued
        errorMessage = nil
    }

    /// Persists a pending attempt locally before any network I/O. Throws when
    /// the save fails so callers never silently lose an attempt.
    func enqueue(attempt: PendingAttempt) throws {
        attempt.syncState = .queued
        modelContext.insert(attempt)
        try saveModelContext()
        state = .queued
        errorMessage = nil
    }


    /// Persists a draft only after both the flattened image and its source
    /// companion are durable. A creation marker lets startup reconcile every
    /// termination window without exposing a half-written pair.
    func enqueue(draft: PendingSessionDraft, imageData: Data, sourceData: Data) throws {
        guard !imageData.isEmpty, !sourceData.isEmpty else {
            throw DraftMediaError.sourceDataRequired
        }
        let fileName = draft.imageFileName.isEmpty ? "\(draft.id.uuidString).jpg" : draft.imageFileName
        let priorDrafts = fetchAllDrafts().filter { $0.sessionId == draft.sessionId && $0.id != draft.id }
        let priorDeletionIDs = Set(fetchAllDraftDeletions().map(\.id))
        let priorImageFiles = Array(
            Set(priorDrafts.map(\.imageFileName).filter { !$0.isEmpty && $0 != fileName })
        )
        var stagedFileNames: [String] = []
        var markerStarted = false
        do {
            try DraftImageStore.beginCreation(fileName: fileName)
            markerStarted = true
            try writeDraftMedia(imageData, fileName: fileName)
            try writeDraftMedia(sourceData, fileName: DraftImageStore.sourceFileName(for: fileName))
            for priorFileName in priorImageFiles {
                try DraftImageStore.stageDeletion(fileName: priorFileName)
                stagedFileNames.append(priorFileName)
            }
            draft.imageFileName = fileName
            draft.syncState = .queued
            for prior in priorDrafts where !priorDeletionIDs.contains(prior.id) {
                modelContext.insert(
                    PendingDraftDeletion(
                        id: prior.id,
                        userId: userID,
                        imageFileName: prior.imageFileName,
                        publicationClaimID: prior.publicationClaimID
                    )
                )
            }
            for prior in priorDrafts {
                modelContext.delete(prior)
            }
            modelContext.insert(draft)
            try saveModelContext()
        } catch {
            modelContext.rollback()
            for staged in stagedFileNames {
                try? DraftImageStore.restoreStagedDeletion(fileName: staged)
            }
            if markerStarted {
                DraftImageStore.delete(fileName: fileName)
            }
            throw error
        }

        for staged in stagedFileNames {
            DraftImageStore.finalizeStagedDeletion(fileName: staged)
        }
        DraftImageStore.completeCreation(fileName: fileName)
        state = .queued
        errorMessage = nil
    }

    /// Replaces a draft's media with a fresh random basename. The old pair is
    /// staged until the row's new metadata is durably saved, so rollback and
    /// startup recovery always converge on one complete pair.
    func replaceDraftMedia(
        draft: PendingSessionDraft,
        imageData: Data,
        sourceData: Data
    ) throws {
        guard !imageData.isEmpty, !sourceData.isEmpty else {
            throw DraftMediaError.sourceDataRequired
        }
        guard draft.publicationStartedAt == nil,
              try publicationHasStarted(draftID: draft.id) == false else {
            throw DraftMediaError.publicationAlreadyStarted
        }
        let oldFileName = draft.imageFileName
        let newFileName = "\(UUID().uuidString).jpg"
        var stagedOld = false
        var creationMarkerStarted = false
        var replacementMarkerStarted = false
        do {
            try DraftImageStore.beginReplacement(oldFileName: oldFileName, newFileName: newFileName)
            replacementMarkerStarted = true
            try DraftImageStore.beginCreation(fileName: newFileName)
            creationMarkerStarted = true
            try writeDraftMedia(imageData, fileName: newFileName)
            try writeDraftMedia(sourceData, fileName: DraftImageStore.sourceFileName(for: newFileName))
            if !oldFileName.isEmpty {
                try DraftImageStore.stageDeletion(fileName: oldFileName)
                stagedOld = true
            }

            draft.imageFileName = newFileName
            draft.syncState = .queued
            try saveModelContext()
        } catch {
            modelContext.rollback()
            draft.imageFileName = oldFileName
            if stagedOld {
                try? DraftImageStore.restoreStagedDeletion(fileName: oldFileName)
            }
            if creationMarkerStarted {
                DraftImageStore.delete(fileName: newFileName)
            }
            if replacementMarkerStarted {
                DraftImageStore.completeReplacement(newFileName: newFileName)
            }
            throw error
        }

        if stagedOld {
            DraftImageStore.finalizeStagedDeletion(fileName: oldFileName)
        }
        DraftImageStore.completeCreation(fileName: newFileName)
        DraftImageStore.completeReplacement(newFileName: newFileName)
        state = .queued
        errorMessage = nil
    }

    /// Removes an attempt from the local timeline. Attempts that have entered
    /// replay are represented by a durable tombstone so an undo cannot be
    /// lost between an in-flight upsert and a later retry. If this attempt was
    /// featured in a session-post draft, that draft and its image are cleaned
    /// up so sync cannot remain queued on a missing featured attempt.
    func delete(attempt: PendingAttempt) throws {
        guard attempt.userId == userID else { return }
        let linkedDrafts = fetchAllDrafts().filter { $0.featuredAttemptId == attempt.id }

        var durableClaimIDs: [UUID: UUID] = [:]
        for draft in linkedDrafts {
            if let claimID = try durablePublicationClaimID(draftID: draft.id) ?? draft.publicationClaimID {
                durableClaimIDs[draft.id] = claimID
            }
        }

        // Stage every linked draft image (primary + source sidecar) while the
        // draft rows are still live so a crash never leaves a row pointing at
        // a missing file. If any staging fails, restore everything already
        // staged and leave all rows untouched for a retry.
        var stagedFileNames: [String] = []
        for draft in linkedDrafts {
            let fileName = draft.imageFileName
            if !fileName.isEmpty {
                do {
                    try cleanupDraftImage(fileName: fileName)
                    stagedFileNames.append(fileName)
                } catch {
                    for staged in stagedFileNames {
                        try? DraftImageStore.restoreStagedDeletion(fileName: staged)
                    }
                    state = .failed
                    errorMessage = error.localizedDescription
                    throw error
                }
            }
        }

        let requiresRemoteDelete = attempt.syncState != .queued
        if requiresRemoteDelete, !fetchAllAttemptDeletions().contains(where: { $0.id == attempt.id }) {
            modelContext.insert(
                PendingAttemptDeletion(id: attempt.id, userId: attempt.userId)
            )
        }
        for draft in linkedDrafts {
            if !fetchAllDraftDeletions().contains(where: { $0.id == draft.id }) {
                modelContext.insert(
                    PendingDraftDeletion(
                        id: draft.id,
                        userId: userID,
                        imageFileName: draft.imageFileName,
                        publicationClaimID: durableClaimIDs[draft.id]
                    )
                )
            }
            modelContext.delete(draft)
        }
        modelContext.delete(attempt)

        do {
            try saveModelContext()
        } catch {
            modelContext.rollback()
            for fileName in stagedFileNames {
                try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
            }
            state = .failed
            errorMessage = error.localizedDescription
            throw error
        }

        for fileName in stagedFileNames {
            DraftImageStore.finalizeStagedDeletion(fileName: fileName)
        }

        let hasPendingWork = !fetchPendingSessions().isEmpty
            || !fetchPendingAttempts().isEmpty
            || !fetchPendingDrafts().isEmpty
            || !fetchPendingAttemptDeletions().isEmpty
            || !fetchPendingDraftDeletions().isEmpty
        state = requiresRemoteDelete || hasPendingWork ? .queued : .synced
        errorMessage = nil
    }

    /// Removes a pending or failed session-post draft.
    /// If a remote post was created, it is deleted idempotently first.
    /// If an image is associated with the draft, its remote storage object is deleted
    /// idempotently before the local database row and cached image are removed.
    /// If remote deletion fails, the local draft and image are retained with a
    /// retryable error.
    func delete(draft: PendingSessionDraft) async throws {
        let isOwned = fetchAllSessionsIncludingSynced().contains(where: { $0.id == draft.sessionId && $0.userId == userID })
            || fetchAllAttemptsIncludingSynced().contains(where: { ($0.sessionId == draft.sessionId || $0.id == draft.featuredAttemptId) && $0.userId == userID })
        guard isOwned else {
            return
        }
        let fileName = draft.imageFileName
        let path = canonicalImagePath(userID: userID, postID: draft.id)
        let sourcePath = sourceImagePath(for: path)
        let durableClaimID: UUID?
        do {
            if let activeClaimID = PublicationCoordinator.activeClaimID(draftID: draft.id) {
                durableClaimID = activeClaimID
            } else {
                durableClaimID = try durablePublicationClaimID(draftID: draft.id)
                    ?? draft.publicationClaimID
            }
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
            throw error
        }

        // Persist a durable replay-excluded deletion intent before the first
        // remote await so a discarded post can never republish after a crash.
        if !fetchAllDraftDeletions().contains(where: { $0.id == draft.id }) {
            modelContext.insert(
                PendingDraftDeletion(
                    id: draft.id,
                    userId: userID,
                    imageFileName: fileName,
                    publicationClaimID: durableClaimID
                )
            )
        }
        do {
            try saveModelContext()
        } catch {
            modelContext.rollback()
            state = .failed
            errorMessage = error.localizedDescription
            throw error
        }

        // A different service that did not acquire the durable generation may
        // persist discard intent, but it must not delete the owner's remote
        // objects while publication is still in flight.
        if PublicationCoordinator.activeClaimID(draftID: draft.id) != nil {
            state = .queued
            errorMessage = DraftMediaError.publicationAlreadyStarted.errorDescription
            throw DraftMediaError.publicationAlreadyStarted
        }
        // Stage both local objects while the draft row is live. Every failure
        // below restores the pair and leaves the tombstone retryable.
        if !fileName.isEmpty {
            do {
                try cleanupDraftImage(fileName: fileName)
            } catch let error as DraftImageCleanupError {
                try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
                state = .failed
                errorMessage = error.localizedDescription
                throw error
            }
        }

        guard await deleteRemotePublication(postID: draft.id, userID: userID) else {
            if !fileName.isEmpty {
                try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
            }
            state = .failed
            errorMessage = "This photo could not be deleted. Try again."
            throw FeedRepositoryError.unavailable
        }

        modelContext.delete(draft)
        if let deletion = fetchAllDraftDeletions().first(where: { $0.id == draft.id }) {
            modelContext.delete(deletion)
        }
        do {
            try saveModelContext()
        } catch {
            modelContext.rollback()
            if !fileName.isEmpty {
                try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
            }
            state = .failed
            errorMessage = error.localizedDescription
            throw error
        }

        if !fileName.isEmpty {
            DraftImageStore.finalizeStagedDeletion(fileName: fileName)
        }

        state = hasPendingWork() ? .queued : .synced
        errorMessage = nil
    }

    func replay() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let pendingSessions = fetchPendingSessions()
        let pendingAttempts = fetchPendingAttempts()
        let pendingAttemptPayloads = pendingAttempts.map { (id: $0.id, remote: $0.remote) }
        let pendingDrafts = fetchPendingDrafts()
        let pendingDeletions = fetchPendingAttemptDeletions()
        let pendingDraftDeletions = fetchPendingDraftDeletions()

        guard !pendingSessions.isEmpty
                || !pendingAttempts.isEmpty
                || !pendingDrafts.isEmpty
                || !pendingDeletions.isEmpty
                || !pendingDraftDeletions.isEmpty else {
            state = .synced
            errorMessage = nil
            return
        }

        // Claim every attempt before the first network await. Undo can
        // interleave with a session upsert, so a queued snapshot must already
        // be considered potentially remote when the user removes it.
        for attempt in pendingAttempts {
            attempt.syncState = .syncing
        }
        do {
            try modelContext.save()
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
            return
        }

        state = .syncing
        errorMessage = nil
        var replayFailed = false

        // Sessions first so attempts always have a parent row to reference.
        var sessionsReady = true
        for session in pendingSessions {
            session.syncState = .syncing
            try? modelContext.save()
            do {
                _ = try await repository.upsertSession(session.remote)
                session.syncState = .synced
                try? modelContext.save()
            } catch {
                session.syncState = .failed
                try? modelContext.save()
                replayFailed = true
                sessionsReady = false
                errorMessage = error.localizedDescription
                break
            }
        }

        if sessionsReady {
            for payload in pendingAttemptPayloads {
                do {
                    _ = try await repository.upsertAttempt(payload.remote)
                    // An undo can happen while the upsert is in flight. In
                    // that case leave the tombstone to the delete phase below
                    // instead of resurrecting the local attempt as synced.
                    if !fetchAllAttemptDeletions().contains(where: { $0.id == payload.id }),
                       let attempt = fetchAllAttempts().first(where: { $0.id == payload.id }) {
                        attempt.syncState = .synced
                        try? modelContext.save()
                    }
                } catch {
                    // The attempt may have been deleted while the request was
                    // in flight. Its tombstone, not the deleted model, owns
                    // the retry in that case.
                    if !fetchAllAttemptDeletions().contains(where: { $0.id == payload.id }),
                       let attempt = fetchAllAttempts().first(where: { $0.id == payload.id }) {
                        attempt.syncState = .failed
                        try? modelContext.save()
                    }
                    replayFailed = true
                    errorMessage = error.localizedDescription
                }
            }
        }

        // Deletions intentionally follow every upsert, including an upsert
        // which failed locally after the network request began. This closes
        // the race where undo lands while a request is in flight.
        var deletionFailed = false
        for deletion in fetchPendingAttemptDeletions() {
            deletion.syncState = .syncing
            try? modelContext.save()
            do {
                try await repository.deleteAttempt(id: deletion.id)
                modelContext.delete(deletion)
                try modelContext.save()
            } catch {
                deletion.syncState = .failed
                try? modelContext.save()
                deletionFailed = true
                errorMessage = error.localizedDescription
            }
        }

        // Draft deletions: stage local media while its draft row is live,
        // then delete both remote objects idempotently before finalizing the
        // tombstone and staged files.
        var draftDeletionFailed = false
        for deletion in fetchPendingDraftDeletions() {
            let activeDraft = fetchAllDrafts().first(where: { $0.id == deletion.id })
            let publicationClaimID = deletion.publicationClaimID ?? activeDraft?.publicationClaimID
            if PublicationCoordinator.activeClaimID(draftID: deletion.id) != nil {
                continue
            }
            let cleanupClaimID = publicationClaimID ?? UUID()
            guard PublicationCoordinator.acquire(draftID: deletion.id, claimID: cleanupClaimID) else {
                continue
            }
            defer {
                PublicationCoordinator.release(draftID: deletion.id, claimID: cleanupClaimID)
            }

            deletion.publicationClaimID = cleanupClaimID
            deletion.syncState = .syncing
            do {
                try saveModelContext()
            } catch {
                modelContext.rollback()
                draftDeletionFailed = true
                errorMessage = error.localizedDescription
                continue
            }

            let fileName = deletion.imageFileName
            if !fileName.isEmpty {
                do {
                    try cleanupDraftImage(fileName: fileName)
                } catch {
                    deletion.syncState = .failed
                    try? modelContext.save()
                    draftDeletionFailed = true
                    errorMessage = error.localizedDescription
                    continue
                }
            }

            let converged = await deleteRemotePublication(postID: deletion.id, userID: deletion.userId)
            guard converged else {
                if !fileName.isEmpty {
                    try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
                }
                deletion.syncState = .failed
                try? modelContext.save()
                draftDeletionFailed = true
                errorMessage = "This photo could not be deleted. Try again."
                continue
            }

            if let activeDraft {
                modelContext.delete(activeDraft)
            }
            modelContext.delete(deletion)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                if !fileName.isEmpty {
                    try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
                }
                draftDeletionFailed = true
                errorMessage = error.localizedDescription
                continue
            }
            if !fileName.isEmpty {
                DraftImageStore.finalizeStagedDeletion(fileName: fileName)
            }
        }

        let sessionsByID = Dictionary(
            uniqueKeysWithValues: fetchAllSessionsIncludingSynced().map { ($0.id, $0) }
        )
        let attemptsByID = Dictionary(
            uniqueKeysWithValues: fetchAllAttempts().map { ($0.id, $0) }
        )
        var draftFailed = false

        var seenDraftSessionIDs = Set<UUID>()
        for draft in pendingDrafts {
            guard fetchAllDrafts().contains(where: { $0.id == draft.id }),
                  !fetchAllDraftDeletions().contains(where: { $0.id == draft.id }) else {
                continue
            }
            guard seenDraftSessionIDs.insert(draft.sessionId).inserted else {
                // Duplicate pending draft: persist a deletion tombstone,
                // stage its pair, and clean both remote objects before the
                // local row is removed.
                let fileName = draft.imageFileName
                let existingDeletion = fetchAllDraftDeletions().first(where: { $0.id == draft.id })
                let publicationClaimID = existingDeletion?.publicationClaimID ?? draft.publicationClaimID
                if PublicationCoordinator.activeClaimID(draftID: draft.id) != nil {
                    continue
                }
                let cleanupClaimID = publicationClaimID ?? UUID()
                guard PublicationCoordinator.acquire(draftID: draft.id, claimID: cleanupClaimID) else {
                    continue
                }
                defer {
                    PublicationCoordinator.release(draftID: draft.id, claimID: cleanupClaimID)
                }
                if existingDeletion == nil {
                    modelContext.insert(
                        PendingDraftDeletion(
                            id: draft.id,
                            userId: userID,
                            imageFileName: fileName,
                            publicationClaimID: cleanupClaimID
                        )
                    )
                }
                do {
                    try saveModelContext()
                    if !fileName.isEmpty {
                        try cleanupDraftImage(fileName: fileName)
                    }
                    guard await deleteRemotePublication(postID: draft.id, userID: userID) else {
                        if !fileName.isEmpty {
                            try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
                        }
                        draftFailed = true
                        errorMessage = "This photo could not be deleted. Try again."
                        continue
                    }
                    modelContext.delete(draft)
                    if let deletion = fetchAllDraftDeletions().first(where: { $0.id == draft.id }) {
                        modelContext.delete(deletion)
                    }
                    try saveModelContext()
                    if !fileName.isEmpty {
                        DraftImageStore.finalizeStagedDeletion(fileName: fileName)
                    }
                } catch {
                    if !fileName.isEmpty {
                        try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
                    }
                    draftFailed = true
                    errorMessage = error.localizedDescription
                }
                continue
            }
            guard let session = sessionsByID[draft.sessionId],
                  session.userId == userID,
                  let endedAt = session.endedAt,
                  session.syncState == .synced,
                  let featuredAttempt = attemptsByID[draft.featuredAttemptId],
                  featuredAttempt.userId == userID,
                  featuredAttempt.sessionId == session.id,
                  featuredAttempt.syncState == .synced else {
                continue
            }

            let publicationClaimID: UUID
            do {
                guard let acquiredClaimID = try acquirePublicationClaim(for: draft) else {
                    continue
                }
                publicationClaimID = acquiredClaimID
            } catch {
                replayFailed = true
                errorMessage = error.localizedDescription
                continue
            }
            defer {
                PublicationCoordinator.release(draftID: draft.id, claimID: publicationClaimID)
            }

            let claimedImageFileName = draft.imageFileName
            var stagedFileName: String?
            do {
                let fileName = claimedImageFileName
                guard let imageData = DraftImageStore.read(fileName: fileName) else {
                    throw ReplayError.missingImage(draft.id)
                }
                let sourceFileName = DraftImageStore.sourceFileName(for: fileName)
                guard let sourceData = DraftImageStore.read(fileName: sourceFileName) else {
                    throw ReplayError.missingSourceImage(draft.id)
                }
                let orderedAttempts = attemptsByID.values
                    .filter { $0.sessionId == session.id && $0.userId == userID }
                    .sorted {
                        if $0.attemptNumber != $1.attemptNumber {
                            return $0.attemptNumber < $1.attemptNumber
                        }
                        return $0.occurredAt < $1.occurredAt
                    }
                let sessionSummary = FeedSessionSummary(
                    id: session.id,
                    venueName: session.venueName,
                    startedAt: session.startedAt,
                    endedAt: endedAt,
                    durationSeconds: max(0, Int(endedAt.timeIntervalSince(session.startedAt))),
                    attemptCount: orderedAttempts.count,
                    sendCount: orderedAttempts.filter { $0.outcome == .sent }.count,
                    featuredAttempt: FeedFeaturedAttempt(
                        id: featuredAttempt.id,
                        routeName: featuredAttempt.routeName,
                        discipline: featuredAttempt.discipline,
                        gradeSystem: featuredAttempt.gradeSystem,
                        gradeLabel: featuredAttempt.gradeLabel,
                        outcome: featuredAttempt.outcome,
                        attemptNumber: featuredAttempt.attemptNumber,
                        occurredAt: featuredAttempt.occurredAt
                    ),
                    attemptTimeline: orderedAttempts.map {
                        FeedAttemptTimelineItem(attemptNumber: $0.attemptNumber, outcome: $0.outcome)
                    }
                )
                let path = canonicalImagePath(userID: session.userId, postID: draft.id)
                let sourcePath = sourceImagePath(for: path)
                do {
                    try await feedRepository.uploadPostImage(data: imageData, path: path)
                } catch {
                    await compensateRemotePublication(postID: draft.id, userID: session.userId)
                    throw error
                }
                guard publicationIsActive(
                    draftID: draft.id,
                    expectedImageFileName: claimedImageFileName,
                    expectedClaimID: publicationClaimID
                ) else {
                    _ = await compensateAndFinalizeCancelledPublication(draft: draft, userID: session.userId)
                    throw ReplayError.publicationCancelled(draft.id)
                }

                do {
                    try await feedRepository.uploadPostImage(data: sourceData, path: sourcePath)
                } catch {
                    await compensateRemotePublication(postID: draft.id, userID: session.userId)
                    throw error
                }
                guard publicationIsActive(
                    draftID: draft.id,
                    expectedImageFileName: claimedImageFileName,
                    expectedClaimID: publicationClaimID
                ) else {
                    _ = await compensateAndFinalizeCancelledPublication(draft: draft, userID: session.userId)
                    throw ReplayError.publicationCancelled(draft.id)
                }

                _ = try await feedRepository.createPost(
                    id: draft.id,
                    sessionID: draft.sessionId,
                    featuredAttemptID: draft.featuredAttemptId,
                    sessionSummary: sessionSummary,
                    caption: draft.caption,
                    imagePath: path,
                    imageAlt: draft.imageAlt,
                    overlayStyle: draft.overlayStyle
                )
                guard publicationIsActive(
                    draftID: draft.id,
                    expectedImageFileName: claimedImageFileName,
                    expectedClaimID: publicationClaimID
                ) else {
                    _ = await compensateAndFinalizeCancelledPublication(draft: draft, userID: session.userId)
                    throw ReplayError.publicationCancelled(draft.id)
                }
                guard publicationIsActive(
                    draftID: draft.id,
                    expectedImageFileName: claimedImageFileName,
                    expectedClaimID: publicationClaimID
                ) else {
                    _ = await compensateAndFinalizeCancelledPublication(draft: draft, userID: session.userId)
                    throw ReplayError.publicationCancelled(draft.id)
                }
                if !fileName.isEmpty {
                    try cleanupDraftImage(fileName: fileName)
                    stagedFileName = fileName
                }
                modelContext.delete(draft)
                try saveModelContext()
                if let stagedFileName {
                    DraftImageStore.finalizeStagedDeletion(fileName: stagedFileName)
                }
            } catch {
                if let stagedFileName {
                    try? DraftImageStore.restoreStagedDeletion(fileName: stagedFileName)
                }
                if let replayError = error as? ReplayError,
                   case .publicationCancelled = replayError {
                    continue
                }
                draft.syncState = .failed
                try? modelContext.save()
                draftFailed = true
                errorMessage = error.localizedDescription
            }
        }
        if replayFailed || deletionFailed || draftFailed || draftDeletionFailed {
            state = .failed
        } else if !fetchPendingSessions().isEmpty
                    || !fetchPendingAttempts().isEmpty
                    || !fetchPendingDrafts().isEmpty
                    || !fetchPendingAttemptDeletions().isEmpty
                    || !fetchPendingDraftDeletions().isEmpty {
            // Drafts whose sessions or attempts are not synced remain queued
            // for a later replay; they must not be published out of order.
            state = .queued
        } else {
            state = .synced
        }
    }

    private func fetchPendingSessions() -> [PendingSession] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingSession>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingAttempts() -> [PendingAttempt] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingDrafts() -> [PendingSessionDraft] {
        let ownedSessionIDs = Set(fetchAllSessionsIncludingSynced().map(\.id))
        let ownedAttemptSessionIDs = Set(fetchAllAttemptsIncludingSynced().map(\.sessionId))
        let allOwnedSessionIDs = ownedSessionIDs.union(ownedAttemptSessionIDs)
        guard !allOwnedSessionIDs.isEmpty else {
            return []
        }
        let descriptor = FetchDescriptor<PendingSessionDraft>(
            predicate: #Predicate { $0.syncStateRaw != "synced" }
        )
        let pending = (try? modelContext.fetch(descriptor)) ?? []
        // A draft with a durable deletion tombstone must never be published:
        // the discard may have failed mid-flight and the tombstone owns the
        // retry, not the draft row.
        let tombstonedIDs = Set(fetchAllDraftDeletions().map(\.id))
        return pending.filter {
            allOwnedSessionIDs.contains($0.sessionId) && !tombstonedIDs.contains($0.id)
        }
    }

    private func fetchPendingAttemptDeletions() -> [PendingAttemptDeletion] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttemptDeletion>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttemptDeletions() -> [PendingAttemptDeletion] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttemptDeletion>(
            predicate: #Predicate { $0.userId == activeUserID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchPendingDraftDeletions() -> [PendingDraftDeletion] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingDraftDeletion>(
            predicate: #Predicate {
                $0.userId == activeUserID && $0.syncStateRaw != "synced"
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllDraftDeletions() -> [PendingDraftDeletion] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingDraftDeletion>(
            predicate: #Predicate { $0.userId == activeUserID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllSessionsIncludingSynced() -> [PendingSession] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingSession>(
            predicate: #Predicate { $0.userId == activeUserID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttemptsIncludingSynced() -> [PendingAttempt] {
        let activeUserID = userID
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate { $0.userId == activeUserID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAttempts() -> [PendingAttempt] {
        fetchAllAttemptsIncludingSynced()
    }

    private func fetchAllDrafts() -> [PendingSessionDraft] {
        let ownedSessionIDs = Set(fetchAllSessionsIncludingSynced().map(\.id))
        let ownedAttemptSessionIDs = Set(fetchAllAttemptsIncludingSynced().map(\.sessionId))
        let allOwnedSessionIDs = ownedSessionIDs.union(ownedAttemptSessionIDs)
        guard !allOwnedSessionIDs.isEmpty else {
            return []
        }

        let allDrafts = (try? modelContext.fetch(FetchDescriptor<PendingSessionDraft>())) ?? []
        return allDrafts.filter { allOwnedSessionIDs.contains($0.sessionId) }
    }

    private func hasPendingWork() -> Bool {
        !fetchPendingSessions().isEmpty
            || !fetchPendingAttempts().isEmpty
            || !fetchPendingDrafts().isEmpty
            || !fetchPendingAttemptDeletions().isEmpty
            || !fetchPendingDraftDeletions().isEmpty
    }
    private func writeDraftMedia(_ data: Data, fileName: String) throws {
        if let imageWriter {
            try imageWriter(data, fileName)
            guard DraftImageStore.read(fileName: fileName) == data else {
                throw DraftMediaError.incompletePair(fileName)
            }
            return
        }
        try DraftImageStore.write(data, fileName: fileName)
    }

    private func cleanupDraftImage(fileName: String) throws {
        guard isSafeDraftImageFileName(fileName) else {
            throw DraftImageCleanupError.invalidFileName(fileName)
        }

        if let imageRemover {
            try imageRemover(fileName)
            return
        }

        do {
            try DraftImageStore.stageDeletion(fileName: fileName)
        } catch {
            throw DraftImageCleanupError.failed(fileName, error.localizedDescription)
        }
    }

    private func isSafeDraftImageFileName(_ fileName: String) -> Bool {
        !fileName.isEmpty
            && fileName != "."
            && fileName != ".."
            && fileName == URL(fileURLWithPath: fileName).lastPathComponent
            && !fileName.contains("\0")
    }

    private func durablePublicationClaimID(draftID: UUID) throws -> UUID? {
        let durableContext = ModelContext(modelContext.container)
        let tombstone = try durableContext.fetch(FetchDescriptor<PendingDraftDeletion>())
            .first(where: { $0.id == draftID })
        if let tombstoneClaimID = tombstone?.publicationClaimID {
            return tombstoneClaimID
        }
        return try durableContext.fetch(FetchDescriptor<PendingSessionDraft>())
            .first(where: { $0.id == draftID })?
            .publicationClaimID
    }

    private func acquirePublicationClaim(for draft: PendingSessionDraft) throws -> UUID? {
        let durableDraft = ModelContext(modelContext.container)
        let persistedDraft = try durableDraft.fetch(FetchDescriptor<PendingSessionDraft>())
            .first(where: { $0.id == draft.id })
        if let persistedClaimID = persistedDraft?.publicationClaimID,
           PublicationCoordinator.isActive(draftID: draft.id, claimID: persistedClaimID) {
            return nil
        }

        let claimID = UUID()
        guard PublicationCoordinator.acquire(draftID: draft.id, claimID: claimID) else {
            return nil
        }
        let previousStartedAt = draft.publicationStartedAt
        let previousClaimID = draft.publicationClaimID
        draft.publicationStartedAt = persistedDraft?.publicationStartedAt
            ?? previousStartedAt
            ?? Date()
        draft.publicationClaimID = claimID
        do {
            try saveModelContext()
            return claimID
        } catch {
            modelContext.rollback()
            draft.publicationStartedAt = previousStartedAt
            draft.publicationClaimID = previousClaimID
            PublicationCoordinator.release(draftID: draft.id, claimID: claimID)
            throw error
        }
    }

    private func publicationHasStarted(draftID: UUID) throws -> Bool {
        let durableContext = ModelContext(modelContext.container)
        return try durableContext.fetch(FetchDescriptor<PendingSessionDraft>())
            .contains(where: { $0.id == draftID && $0.publicationStartedAt != nil })
    }

    private func publicationIsActive(
        draftID: UUID,
        expectedImageFileName: String,
        expectedClaimID: UUID
    ) -> Bool {
        // A separate context prevents a concurrent replacement/discard from
        // being hidden by this service's registered model objects.
        let durableContext = ModelContext(modelContext.container)
        let ownedSessionIDs = Set(
            ((try? durableContext.fetch(FetchDescriptor<PendingSession>())) ?? [])
                .filter { $0.userId == userID }
                .map(\.id)
        )
        let ownedAttemptSessionIDs = Set(
            ((try? durableContext.fetch(FetchDescriptor<PendingAttempt>())) ?? [])
                .filter { $0.userId == userID }
                .map(\.sessionId)
        )
        let ownedSessionIDsIncludingAttempts = ownedSessionIDs.union(ownedAttemptSessionIDs)
        guard let currentDraft = ((try? durableContext.fetch(FetchDescriptor<PendingSessionDraft>())) ?? [])
            .first(where: {
                $0.id == draftID && ownedSessionIDsIncludingAttempts.contains($0.sessionId)
            }),
            currentDraft.imageFileName == expectedImageFileName,
            currentDraft.publicationStartedAt != nil,
            currentDraft.publicationClaimID == expectedClaimID else {
            return false
        }
        let hasDeletionIntent = ((try? durableContext.fetch(FetchDescriptor<PendingDraftDeletion>())) ?? [])
            .contains(where: { $0.userId == userID && $0.id == draftID })
        return !hasDeletionIntent
    }

    private func deleteRemotePublication(postID: UUID, userID: UUID) async -> Bool {
        let path = canonicalImagePath(userID: userID, postID: postID)
        var succeeded = true
        do {
            try await feedRepository.deletePost(id: postID)
        } catch {
            succeeded = false
        }
        do {
            try await feedRepository.deletePostImage(path: path)
        } catch {
            succeeded = false
        }
        do {
            try await feedRepository.deletePostImage(path: sourceImagePath(for: path))
        } catch {
            succeeded = false
        }
        return succeeded
    }

    private func compensateAndFinalizeCancelledPublication(
        draft: PendingSessionDraft,
        userID: UUID
    ) async -> Bool {
        guard await deleteRemotePublication(postID: draft.id, userID: userID) else {
            return false
        }

        let fileName = draft.imageFileName
        var staged = false
        do {
            if !fileName.isEmpty {
                try cleanupDraftImage(fileName: fileName)
                staged = true
            }
            modelContext.delete(draft)
            if let deletion = fetchAllDraftDeletions().first(where: { $0.id == draft.id }) {
                modelContext.delete(deletion)
            }
            try saveModelContext()
            if staged {
                DraftImageStore.finalizeStagedDeletion(fileName: fileName)
            }
            return true
        } catch {
            modelContext.rollback()
            if staged {
                try? DraftImageStore.restoreStagedDeletion(fileName: fileName)
            }
            return false
        }
    }

    private func compensateRemotePublication(postID: UUID, userID: UUID) async {
        _ = await deleteRemotePublication(postID: postID, userID: userID)
    }


    private func sourceImagePath(for path: String) -> String {
        String(path.dropLast(".jpg".count)) + ".source.jpg"
    }

    private func canonicalImagePath(userID: UUID, postID: UUID) -> String {
        "\(userID.uuidString.lowercased())/\(postID.uuidString.lowercased()).jpg"
    }
}
