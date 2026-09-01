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

/// A send-post draft awaiting publication. The image is stored on disk under
/// Application Support and referenced by `imageFileName`; the post is only
/// created after the attempt has synced and is confirmed `sent`.
@Model
final class PendingSendDraft {
    @Attribute(.unique) var id: UUID
    var attemptId: UUID
    var caption: String?
    var imageFileName: String?
    var imageAlt: String?
    var createdAt: Date
    var syncStateRaw: String

    init(
        id: UUID = UUID(),
        attemptId: UUID,
        caption: String?,
        imageFileName: String?,
        imageAlt: String?,
        createdAt: Date = Date(),
        syncState: SyncState = .queued
    ) {
        self.id = id
        self.attemptId = attemptId
        self.caption = caption
        self.imageFileName = imageFileName
        self.imageAlt = imageAlt
        self.createdAt = createdAt
        self.syncStateRaw = syncState.rawValue
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .queued }
        set { syncStateRaw = newValue.rawValue }
    }
}

/// Application Support-backed store for draft send-post images. Images are
/// written before the draft is persisted so a crash never leaves a draft
/// pointing at a missing file.
enum DraftImageStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Boarded/DraftImages", isDirectory: true)
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func write(_ data: Data, fileName: String) throws -> URL {
        try ensureDirectory()
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func read(fileName: String) -> Data? {
        let url = directory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    static func delete(fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
