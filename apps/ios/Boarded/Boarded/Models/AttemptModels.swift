import Foundation
enum AttemptFormatting {
    static func duration(from start: Date, to end: Date, abbreviated: Bool) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = abbreviated ? .positional : .full
        formatter.zeroFormattingBehavior = abbreviated ? [.pad] : [.dropAll]
        return formatter.string(from: max(0, end.timeIntervalSince(start))) ?? "0"
    }

    static func attemptCount(_ count: Int) -> String {
        let value = count.formatted(.number)
        return count == 1 ? "\(value) attempt" : "\(value) attempts"
    }

    static func grade(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

enum AttemptOutcome: String, Codable, CaseIterable, Identifiable {
    case sent
    case fell
    case stopped

    var id: String { rawValue }
    var title: String {
        switch self {
        case .sent: return "Sent"
        case .fell: return "Fell"
        case .stopped: return "Stopped"
        }
    }
    var symbol: String {
        switch self {
        case .sent: return "checkmark.circle.fill"
        case .fell: return "xmark.circle.fill"
        case .stopped: return "stop.circle.fill"
        }
    }
}

struct ClimbAttempt: Codable, Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let outcome: AttemptOutcome
}

struct ClimbSession: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var routeName: String
    var grade: String
    var attempts: [ClimbAttempt]

    var isActive: Bool { endedAt == nil }
    var sentCount: Int { attempts.filter { $0.outcome == .sent }.count }
    var result: SessionResult { sentCount > 0 ? .sent : .noSend }
}

enum SessionResult: String, Codable {
    case sent
    case noSend

    var title: String { self == .sent ? "Route sent" : "Session logged" }
    var symbol: String { self == .sent ? "checkmark.seal.fill" : "flag.checkered" }
}

enum SyncState: String, Codable, Equatable {
    case synced
    case queued
    case syncing
    case failed
}

struct AttemptLogSnapshot: Codable, Equatable {
    var activeSession: ClimbSession?
    var history: [ClimbSession]
    var syncState: SyncState

    static let empty = AttemptLogSnapshot(activeSession: nil, history: [], syncState: .synced)
}

enum AttemptLogFixture: String {
    case empty, active, offline, queued, sent, noSend = "no-send", result
    case loading, error, success
}
