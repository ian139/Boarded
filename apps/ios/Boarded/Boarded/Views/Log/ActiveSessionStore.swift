import Foundation
import SwiftData

enum ActiveSessionStore {
    static func fetchActive(userID: UUID?, in context: ModelContext) -> PendingSession? {
        guard let userID else { return nil }
        var descriptor = FetchDescriptor<PendingSession>(
            predicate: #Predicate { $0.userId == userID && $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func attempts(sessionID: UUID, userID: UUID?, in context: ModelContext) -> [PendingAttempt] {
        guard let userID else { return [] }
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate { $0.sessionId == sessionID && $0.userId == userID },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func sendableAttempts(userID: UUID?, in context: ModelContext) -> [PendingAttempt] {
        guard let userID else { return [] }
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate {
                $0.userId == userID
                    && $0.outcomeRaw == "sent"
                    && $0.syncStateRaw == "synced"
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

extension Notification.Name {
    static let activeSessionDidChange = Notification.Name("BoardedActiveSessionDidChangeNotification")
}

struct SessionSummary {
    let venue: String
    let startedAt: Date
    let endedAt: Date
    let attempts: [PendingAttempt]

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
    var sendCount: Int { attempts.filter { $0.outcome == .sent }.count }
    var routeCount: Int { Set(attempts.map(\.routeName)).count }
    var successRate: Double? { attempts.isEmpty ? nil : Double(sendCount) / Double(attempts.count) }
    var bestSend: PendingAttempt? {
        attempts.filter { $0.outcome == .sent }.max {
            GradeCatalog.rank($0.gradeLabel, system: $0.gradeSystem) < GradeCatalog.rank($1.gradeLabel, system: $1.gradeSystem)
        }
    }
}
