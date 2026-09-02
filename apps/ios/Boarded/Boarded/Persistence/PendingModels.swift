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
        syncState: SyncState = .queued
    ) {
        self.id = id
        self.sessionId = sessionId
        self.featuredAttemptId = featuredAttemptId
        self.caption = caption
        self.imageFileName = imageFileName
        self.imageAlt = imageAlt
        self.overlayStyleRaw = overlayStyle.rawValue
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
/// pointing at a missing file.
enum DraftImageStore {
    enum Error: LocalizedError, Equatable {
        case invalidFileName

        var errorDescription: String? {
            "Draft image file names must be a single local file name."
        }
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Boarded/DraftImages", isDirectory: true)
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func write(_ data: Data, fileName: String) throws -> URL {
        guard isSafeFileName(fileName) else { throw Error.invalidFileName }
        try ensureDirectory()
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func read(fileName: String) -> Data? {
        guard isSafeFileName(fileName) else { return nil }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        return try? Data(contentsOf: url)
    }

    static func delete(fileName: String) {
        guard isSafeFileName(fileName) else { return }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try? FileManager.default.removeItem(at: url)
    }

    private static func isSafeFileName(_ fileName: String) -> Bool {
        !fileName.isEmpty
            && fileName != "."
            && fileName != ".."
            && fileName == URL(fileURLWithPath: fileName).lastPathComponent
            && !fileName.contains("\0")
    }
}
