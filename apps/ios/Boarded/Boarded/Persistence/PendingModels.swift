import Foundation
import SwiftData

/// Local-first pending records. Every record carries a client-generated UUID so
/// replay is idempotent: the server upserts on `id` and a replayed write never
/// duplicates a session or attempt.
@Model
final class PendingSession {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var venueName: String
    var startedAt: Date
    var endedAt: Date?
    var syncStateRaw: String

    init(id: UUID = UUID(), userId: UUID, venueName: String, startedAt: Date, endedAt: Date?, syncState: SyncState = .queued) {
        self.id = id
        self.userId = userId
        self.venueName = venueName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.syncStateRaw = syncState.rawValue
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .queued }
        set { syncStateRaw = newValue.rawValue }
    }

    var remote: ClimbingSession {
        ClimbingSession(
            id: id,
            userId: userId,
            venueName: venueName,
            startedAt: startedAt,
            endedAt: endedAt,
            createdAt: startedAt,
            updatedAt: endedAt ?? startedAt
        )
    }
}

@Model
final class PendingAttempt {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var userId: UUID
    var boardRouteId: UUID?
    var routeName: String
    var disciplineRaw: String
    var gradeSystemRaw: String
    var gradeLabel: String
    var outcomeRaw: String
    var attemptNumber: Int
    var notes: String?
    var occurredAt: Date
    var syncStateRaw: String

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        userId: UUID,
        boardRouteId: UUID?,
        routeName: String,
        discipline: ClimbDiscipline,
        gradeSystem: GradeSystem,
        gradeLabel: String,
        outcome: AttemptOutcome,
        attemptNumber: Int,
        notes: String?,
        occurredAt: Date,
        syncState: SyncState = .queued
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.boardRouteId = boardRouteId
        self.routeName = routeName
        self.disciplineRaw = discipline.rawValue
        self.gradeSystemRaw = gradeSystem.rawValue
        self.gradeLabel = gradeLabel
        self.outcomeRaw = outcome.rawValue
        self.attemptNumber = attemptNumber
        self.notes = notes
        self.occurredAt = occurredAt
        self.syncStateRaw = syncState.rawValue
    }

    var discipline: ClimbDiscipline {
        get { ClimbDiscipline(rawValue: disciplineRaw) ?? .other }
        set { disciplineRaw = newValue.rawValue }
    }

    var gradeSystem: GradeSystem {
        get { GradeSystem(rawValue: gradeSystemRaw) ?? .custom }
        set { gradeSystemRaw = newValue.rawValue }
    }

    var outcome: AttemptOutcome {
        get { AttemptOutcome(rawValue: outcomeRaw) ?? .stopped }
        set { outcomeRaw = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .queued }
        set { syncStateRaw = newValue.rawValue }
    }

    var remote: ClimbAttempt {
        ClimbAttempt(
            id: id,
            sessionId: sessionId,
            userId: userId,
            boardRouteId: boardRouteId,
            routeName: routeName,
            discipline: ClimbDiscipline(rawValue: disciplineRaw) ?? .other,
            gradeSystem: GradeSystem(rawValue: gradeSystemRaw) ?? .custom,
            gradeLabel: gradeLabel,
            outcome: AttemptOutcome(rawValue: outcomeRaw) ?? .stopped,
            attemptNumber: attemptNumber,
            notes: notes,
            occurredAt: occurredAt,
            createdAt: occurredAt
        )
    }
}

/// Durable tombstone for an attempt that may already have reached the server.
/// The attempt UUID is the tombstone identity, so replaying a deletion is
/// idempotent across retries and app restarts.
@Model
final class PendingAttemptDeletion {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var createdAt: Date
    var syncStateRaw: String

    init(
        id: UUID,
        userId: UUID,
        createdAt: Date = Date(),
        syncState: SyncState = .queued
    ) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.syncStateRaw = syncState.rawValue
    }

    var attemptId: UUID { id }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .queued }
        set { syncStateRaw = newValue.rawValue }
    }
}

/// Durable tombstone for a discarded session-post draft. Persisted before any
/// remote deletion so a discarded post can never republish after a crash, and
/// carries the image file name so local cleanup can resume after restart even
/// when the draft row is already gone.
@Model
final class PendingDraftDeletion {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var imageFileName: String
    var publicationClaimID: UUID?
    var createdAt: Date
    var syncStateRaw: String

    init(
        id: UUID,
        userId: UUID,
        imageFileName: String,
        publicationClaimID: UUID? = nil,
        createdAt: Date = Date(),
        syncState: SyncState = .queued
    ) {
        self.id = id
        self.userId = userId
        self.imageFileName = imageFileName
        self.publicationClaimID = publicationClaimID
        self.createdAt = createdAt
        self.syncStateRaw = syncState.rawValue
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .queued }
        set { syncStateRaw = newValue.rawValue }
    }
}

/// A session-post draft awaiting publication. The image is stored on disk under
/// Application Support and referenced by `imageFileName`; the post is only
/// created after the ended session and relevant attempts have synced.
@Model
final class PendingSessionDraft {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var featuredAttemptId: UUID
    var caption: String?
    var imageFileName: String
    var imageAlt: String
    var overlayStyleRaw: String
    var publicationStartedAt: Date?
    var publicationClaimID: UUID?
    var createdAt: Date
    var syncStateRaw: String

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        featuredAttemptId: UUID,
        caption: String?,
        imageFileName: String,
        imageAlt: String,
        overlayStyle: OverlayStyle = .stats,
        createdAt: Date = Date(),
        syncState: SyncState = .queued,
        publicationStartedAt: Date? = nil,
        publicationClaimID: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.featuredAttemptId = featuredAttemptId
        self.caption = caption
        self.imageFileName = imageFileName
        self.imageAlt = imageAlt
        self.overlayStyleRaw = overlayStyle.rawValue
        self.publicationStartedAt = publicationStartedAt
        self.publicationClaimID = publicationClaimID
        self.createdAt = createdAt
        self.syncStateRaw = syncState.rawValue
    }

    var overlayStyle: OverlayStyle {
        get { OverlayStyle(rawValue: overlayStyleRaw) ?? .stats }
        set { overlayStyleRaw = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .queued }
        set { syncStateRaw = newValue.rawValue }
    }
}

/// Application Support-backed store for draft session-post images. Images are
/// written before the draft is persisted so a crash never leaves a draft
/// pointing at a missing file. A draft image may have a `<name>.source`
/// companion sidecar (the original source asset); every delete/stage/restore/
/// finalize/reconcile operation includes the companion when present so the two
/// files are always moved and cleaned up atomically together.
enum DraftImageStore {
    enum Error: LocalizedError, Equatable {
        case invalidFileName
        case stagingFailed(String)
        case restorationFailed(String)
        case creationFailed(String)
        case replacementFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFileName:
                return "Draft image file names must be a single local file name."
            case .stagingFailed(let fileName):
                return "Failed to stage deletion for image \(fileName)."
            case .restorationFailed(let fileName):
                return "Failed to restore staged image \(fileName)."
            case .creationFailed(let fileName):
                return "Failed to create durable media transaction for image \(fileName)."
            case .replacementFailed(let fileName):
                return "Failed to create durable replacement transaction for image \(fileName)."
            }
        }
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Boarded/DraftImages", isDirectory: true)
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func fileURL(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    static func sourceFileName(for fileName: String) -> String {
        "\(fileName).source"
    }

    static func sourceURL(for fileName: String) -> URL {
        fileURL(for: sourceFileName(for: fileName))
    }

    static func stagingURL(for fileName: String) -> URL {
        directory.appendingPathComponent("\(fileName).staging", isDirectory: false)
    }

    static func sourceStagingURL(for fileName: String) -> URL {
        directory.appendingPathComponent("\(sourceFileName(for: fileName)).staging", isDirectory: false)
    }

    /// Durable marker for a replacement transaction. The marker payload
    /// carries both basenames so startup can restore the old pair when the
    /// row still references it, or finalize the old pair after the row points
    /// at the new pair.
    static func replacementMarkerURL(for newFileName: String) -> URL {
        directory.appendingPathComponent("\(newFileName).replacement", isDirectory: false)
    }

    static func beginReplacement(oldFileName: String, newFileName: String) throws {
        guard isSafeFileName(newFileName),
              oldFileName.isEmpty || isSafeFileName(oldFileName) else {
            throw Error.invalidFileName
        }
        try ensureDirectory()
        do {
            let payload = "\(oldFileName)\n\(newFileName)"
            try Data(payload.utf8).write(to: replacementMarkerURL(for: newFileName), options: .atomic)
        } catch {
            throw Error.replacementFailed(newFileName)
        }
    }

    static func completeReplacement(newFileName: String) {
        guard isSafeFileName(newFileName) else { return }
        try? FileManager.default.removeItem(at: replacementMarkerURL(for: newFileName))
    }

    /// Resolves replacement markers left across a termination. A row that
    /// durably references the new basename commits the replacement; otherwise
    /// the old pair is restored and the unreferenced new pair is removed.
    static func reconcileReplacementStages(activeFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let markerSuffix = ".replacement"
        for marker in files where marker.hasSuffix(markerSuffix) {
            let markerURL = directory.appendingPathComponent(marker, isDirectory: false)
            guard let payload = try? String(contentsOf: markerURL, encoding: .utf8) else { continue }
            let parts = payload.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { continue }
            let oldFileName = parts[0]
            let newFileName = parts[1]
            guard isSafeFileName(newFileName),
                  oldFileName.isEmpty || isSafeFileName(oldFileName) else { continue }

            if activeFileNames.contains(newFileName) {
                if !oldFileName.isEmpty {
                    finalizeStagedDeletion(fileName: oldFileName)
                }
            } else {
                if !oldFileName.isEmpty {
                    try? restoreStagedDeletion(fileName: oldFileName)
                }
                delete(fileName: newFileName)
            }
            try? FileManager.default.removeItem(at: markerURL)
        }
    }
    /// Durable marker for a pair creation transaction. The marker is written
    /// before either byte is touched and removed only after the draft row save.
    static func creationMarkerURL(for fileName: String) -> URL {
        directory.appendingPathComponent("\(fileName).creation", isDirectory: false)
    }

    static func beginCreation(fileName: String) throws {
        guard isSafeFileName(fileName) else { throw Error.invalidFileName }
        try ensureDirectory()
        do {
            try Data(fileName.utf8).write(to: creationMarkerURL(for: fileName), options: .atomic)
        } catch {
            throw Error.creationFailed(fileName)
        }
    }

    static func completeCreation(fileName: String) {
        guard isSafeFileName(fileName) else { return }
        try? FileManager.default.removeItem(at: creationMarkerURL(for: fileName))
    }

    /// Resolves markers left by termination during a paired creation. A
    /// referenced complete pair is finalized; an unreferenced or incomplete
    /// pair is removed in its entirety.
    static func reconcileCreationStages(activeFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let markerSuffix = ".creation"
        for marker in files where marker.hasSuffix(markerSuffix) {
            let fileName = String(marker.dropLast(markerSuffix.count))
            guard isSafeFileName(fileName) else { continue }
            let primaryExists = FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
            let sourceExists = FileManager.default.fileExists(atPath: sourceURL(for: fileName).path)
            if activeFileNames.contains(fileName), primaryExists, sourceExists {
                completeCreation(fileName: fileName)
            } else {
                try? FileManager.default.removeItem(at: fileURL(for: fileName))
                try? FileManager.default.removeItem(at: sourceURL(for: fileName))
                completeCreation(fileName: fileName)
            }
        }
    }

    static func write(_ data: Data, fileName: String) throws -> URL {
        guard isSafeFileName(fileName) else { throw Error.invalidFileName }
        try ensureDirectory()
        let url = fileURL(for: fileName)
        let stagingUrl = stagingURL(for: fileName)
        if FileManager.default.fileExists(atPath: stagingUrl.path) {
            try? FileManager.default.removeItem(at: stagingUrl)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func read(fileName: String) -> Data? {
        guard isSafeFileName(fileName) else { return nil }
        let url = fileURL(for: fileName)
        let stagingUrl = stagingURL(for: fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            return try? Data(contentsOf: url)
        }
        if FileManager.default.fileExists(atPath: stagingUrl.path) {
            try? FileManager.default.moveItem(at: stagingUrl, to: url)
            let sourceUrl = sourceURL(for: fileName)
            let sourceStagingUrl = sourceStagingURL(for: fileName)
            if FileManager.default.fileExists(atPath: sourceStagingUrl.path),
               !FileManager.default.fileExists(atPath: sourceUrl.path) {
                try? FileManager.default.moveItem(at: sourceStagingUrl, to: sourceUrl)
            }
            return try? Data(contentsOf: url)
        }
        return nil
    }

    static func delete(fileName: String) {
        guard isSafeFileName(fileName) else { return }
        let url = fileURL(for: fileName)
        let stagingUrl = stagingURL(for: fileName)
        let sourceUrl = sourceURL(for: fileName)
        let sourceStagingUrl = sourceStagingURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: stagingUrl)
        try? FileManager.default.removeItem(at: sourceUrl)
        try? FileManager.default.removeItem(at: sourceStagingUrl)
    }

    static func stageDeletion(fileName: String) throws {
        guard isSafeFileName(fileName) else { throw Error.invalidFileName }
        try ensureDirectory()
        let url = fileURL(for: fileName)
        let stagingUrl = stagingURL(for: fileName)
        var stagedPrimary = false
        if FileManager.default.fileExists(atPath: url.path) {
            if FileManager.default.fileExists(atPath: stagingUrl.path) {
                try? FileManager.default.removeItem(at: stagingUrl)
            }
            do {
                try FileManager.default.moveItem(at: url, to: stagingUrl)
                stagedPrimary = true
            } catch {
                throw Error.stagingFailed(fileName)
            }
        }
        let sourceUrl = sourceURL(for: fileName)
        let sourceStagingUrl = sourceStagingURL(for: fileName)
        if FileManager.default.fileExists(atPath: sourceUrl.path) {
            if FileManager.default.fileExists(atPath: sourceStagingUrl.path) {
                try? FileManager.default.removeItem(at: sourceStagingUrl)
            }
            do {
                try FileManager.default.moveItem(at: sourceUrl, to: sourceStagingUrl)
            } catch {
                if stagedPrimary {
                    try? FileManager.default.moveItem(at: stagingUrl, to: url)
                }
                throw Error.stagingFailed(sourceFileName(for: fileName))
            }
        }
    }

    static func restoreStagedDeletion(fileName: String) throws {
        guard isSafeFileName(fileName) else { throw Error.invalidFileName }
        let url = fileURL(for: fileName)
        let stagingUrl = stagingURL(for: fileName)
        if FileManager.default.fileExists(atPath: stagingUrl.path) {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            do {
                try FileManager.default.moveItem(at: stagingUrl, to: url)
            } catch {
                throw Error.restorationFailed(fileName)
            }
        }
        let sourceUrl = sourceURL(for: fileName)
        let sourceStagingUrl = sourceStagingURL(for: fileName)
        if FileManager.default.fileExists(atPath: sourceStagingUrl.path) {
            if FileManager.default.fileExists(atPath: sourceUrl.path) {
                try? FileManager.default.removeItem(at: sourceUrl)
            }
            do {
                try FileManager.default.moveItem(at: sourceStagingUrl, to: sourceUrl)
            } catch {
                throw Error.restorationFailed(sourceFileName(for: fileName))
            }
        }
    }

    static func finalizeStagedDeletion(fileName: String) {
        guard isSafeFileName(fileName) else { return }
        let url = fileURL(for: fileName)
        let stagingUrl = stagingURL(for: fileName)
        let sourceUrl = sourceURL(for: fileName)
        let sourceStagingUrl = sourceStagingURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: stagingUrl)
        try? FileManager.default.removeItem(at: sourceUrl)
        try? FileManager.default.removeItem(at: sourceStagingUrl)
    }

    static func reconcileStagedDeletions(activeFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        var primaryStaged = Set<String>()
        var sourceStaged = Set<String>()
        for file in files where file.hasSuffix(".staging") {
            let stagedName = String(file.dropLast(".staging".count))
            if stagedName.hasSuffix(".source") {
                let baseFileName = String(stagedName.dropLast(".source".count))
                if isSafeFileName(baseFileName) {
                    sourceStaged.insert(baseFileName)
                }
            } else if isSafeFileName(stagedName) {
                primaryStaged.insert(stagedName)
            }
        }
        for baseFileName in primaryStaged.union(sourceStaged) {
            let stagingUrl = stagingURL(for: baseFileName)
            let primaryUrl = fileURL(for: baseFileName)
            let sourceStagingUrl = sourceStagingURL(for: baseFileName)
            let sourceUrl = sourceURL(for: baseFileName)
            if activeFileNames.contains(baseFileName) {
                if !FileManager.default.fileExists(atPath: primaryUrl.path),
                   FileManager.default.fileExists(atPath: stagingUrl.path) {
                    try? FileManager.default.moveItem(at: stagingUrl, to: primaryUrl)
                } else {
                    try? FileManager.default.removeItem(at: stagingUrl)
                }
                if !FileManager.default.fileExists(atPath: sourceUrl.path),
                   FileManager.default.fileExists(atPath: sourceStagingUrl.path) {
                    try? FileManager.default.moveItem(at: sourceStagingUrl, to: sourceUrl)
                } else {
                    try? FileManager.default.removeItem(at: sourceStagingUrl)
                }
            } else {
                try? FileManager.default.removeItem(at: stagingUrl)
                try? FileManager.default.removeItem(at: sourceStagingUrl)
            }
        }
    }

    /// Removes ordinary files that no live draft references. Source
    /// companions are retained only when their primary draft is retained.
    static func reconcileUnreferencedFiles(activeFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let stagingSuffix = ".staging"
        let creationSuffix = ".creation"
        let sourceSuffix = ".source"
        for file in files {
            guard !file.hasSuffix(stagingSuffix), !file.hasSuffix(creationSuffix) else { continue }
            let baseFileName: String
            if file.hasSuffix(sourceSuffix) {
                baseFileName = String(file.dropLast(sourceSuffix.count))
            } else {
                baseFileName = file
            }
            guard isSafeFileName(baseFileName), !activeFileNames.contains(baseFileName) else { continue }
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file, isDirectory: false))
        }
    }

    /// Runs every startup media recovery pass in a deterministic order.
    static func reconcile(activeFileNames: Set<String>) {
        reconcileReplacementStages(activeFileNames: activeFileNames)
        reconcileCreationStages(activeFileNames: activeFileNames)
        reconcileStagedDeletions(activeFileNames: activeFileNames)
        reconcileUnreferencedFiles(activeFileNames: activeFileNames)
    }

    static func isSafeFileName(_ fileName: String) -> Bool {
        !fileName.isEmpty
            && fileName != "."
            && fileName != ".."
            && fileName == URL(fileURLWithPath: fileName).lastPathComponent
            && !fileName.contains("\0")
    }
}
