import Foundation
import SwiftData

enum ActiveSessionStore {
    static func fetchActive(in context: ModelContext) -> PendingSession? {
        var descriptor = FetchDescriptor<PendingSession>(predicate: #Predicate { $0.endedAt == nil })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func attempts(sessionID: UUID, in context: ModelContext) -> [PendingAttempt] {
        let descriptor = FetchDescriptor<PendingAttempt>(
            predicate: #Predicate { $0.sessionId == sessionID },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func sendableAttempts(in context: ModelContext) -> [PendingAttempt] {
        let descriptor = FetchDescriptor<PendingAttempt>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.outcome == .sent && $0.syncState == .synced }
    }
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
