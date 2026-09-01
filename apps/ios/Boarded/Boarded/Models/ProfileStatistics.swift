import Foundation

/// A grade ranked within its own system's ordering.
struct RankedGrade: Hashable {
    let system: GradeSystem
    let label: String
    let rank: Int
}

/// Session-derived profile statistics. There is deliberately no points value
/// and no leaderboard: the social release derives stats from private sessions
/// and attempts only.
struct ProfileStatistics: Hashable {
    let sessionCount: Int
    let sendCount: Int
    let attemptCount: Int
    let sendRate: Double?
    let bestGrade: RankedGrade?

    static let empty = ProfileStatistics(
        sessionCount: 0,
        sendCount: 0,
        attemptCount: 0,
        sendRate: nil,
        bestGrade: nil
    )
}

enum ProfileStatisticsCalculator {
    static func calculate(sessions: [ClimbingSession], attempts: [ClimbAttempt]) -> ProfileStatistics {
        let sessionCount = sessions.count
        let attemptCount = attempts.count
        let sentAttempts = attempts.filter { $0.outcome == .sent }
        let sendCount = sentAttempts.count
        let sendRate: Double? = attemptCount > 0 ? Double(sendCount) / Double(attemptCount) : nil

        let bestGrade = sentAttempts
            .compactMap { attempt -> RankedGrade? in
                let rank = GradeCatalog.rank(attempt.gradeLabel, system: attempt.gradeSystem)
                guard rank >= 0 else { return nil }
                return RankedGrade(system: attempt.gradeSystem, label: attempt.gradeLabel, rank: rank)
            }
            .max { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.label < rhs.label
            }

        return ProfileStatistics(
            sessionCount: sessionCount,
            sendCount: sendCount,
            attemptCount: attemptCount,
            sendRate: sendRate,
            bestGrade: bestGrade
        )
    }
}
