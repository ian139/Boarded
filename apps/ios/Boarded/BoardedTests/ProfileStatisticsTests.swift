import XCTest
@testable import Boarded

final class ProfileStatisticsTests: XCTestCase {
    private let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private func session(id: String = "s1", venue: String = "Gym") -> ClimbingSession {
        ClimbingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: venue,
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
    }

    private func attempt(
        id: String = "a1",
        outcome: AttemptOutcome,
        system: GradeSystem = .vScale,
        label: String = "V3"
    ) -> ClimbAttempt {
        ClimbAttempt(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            sessionId: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            boardRouteId: nil,
            routeName: "Route",
            discipline: .boulder,
            gradeSystem: system,
            gradeLabel: label,
            outcome: outcome,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 150),
            createdAt: Date(timeIntervalSince1970: 150)
        )
    }

    func testEmptyStatistics() {
        let stats = ProfileStatisticsCalculator.calculate(sessions: [], attempts: [])
        XCTAssertEqual(stats.sessionCount, 0)
        XCTAssertEqual(stats.sendCount, 0)
        XCTAssertEqual(stats.attemptCount, 0)
        XCTAssertNil(stats.sendRate)
        XCTAssertNil(stats.bestGrade)
    }

    func testSendRateIsSendsOverAttempts() {
        let attempts = [
            attempt(id: "a1", outcome: .sent),
            attempt(id: "a2", outcome: .fell),
            attempt(id: "a3", outcome: .sent),
            attempt(id: "a4", outcome: .stopped)
        ]
        let stats = ProfileStatisticsCalculator.calculate(sessions: [session()], attempts: attempts)
        XCTAssertEqual(stats.sendCount, 2)
        XCTAssertEqual(stats.attemptCount, 4)
        XCTAssertEqual(stats.sendRate ?? 0, 0.5, accuracy: 0.0001)
    }

    func testBestGradeUsesHighestRankedSentAttempt() {
        let attempts = [
            attempt(id: "a1", outcome: .sent, label: "V3"),
            attempt(id: "a2", outcome: .sent, label: "V7"),
            attempt(id: "a3", outcome: .fell, label: "V10"),
            attempt(id: "a4", outcome: .sent, label: "V5")
        ]
        let stats = ProfileStatisticsCalculator.calculate(sessions: [session()], attempts: attempts)
        XCTAssertEqual(stats.bestGrade?.label, "V7")
        XCTAssertEqual(stats.bestGrade?.rank, GradeCatalog.rank("V7", system: .vScale))
    }

    func testBestGradeIgnoresUnknownAndNonSent() {
        let attempts = [
            attempt(id: "a1", outcome: .sent, label: "not-a-grade"),
            attempt(id: "a2", outcome: .fell, label: "V10")
        ]
        let stats = ProfileStatisticsCalculator.calculate(sessions: [session()], attempts: attempts)
        XCTAssertNil(stats.bestGrade)
    }

    func testGradeCatalogOrdering() {
        XCTAssertEqual(GradeCatalog.rank("VB", system: .vScale), 0)
        XCTAssertEqual(GradeCatalog.rank("V0", system: .vScale), 1)
        XCTAssertEqual(GradeCatalog.rank("V17", system: .vScale), 18)
        XCTAssertEqual(GradeCatalog.rank("V18", system: .vScale), -1)
        XCTAssertEqual(GradeCatalog.rank("5.10a", system: .yds), 10)
        XCTAssertEqual(GradeCatalog.rank("6a", system: .font), 4)
        XCTAssertEqual(GradeCatalog.rank("anything", system: .custom), -1)
        XCTAssertEqual(GradeCatalog.canonical(" v7 ", system: .vScale), "V7")
        XCTAssertEqual(GradeCatalog.canonical("custom label", system: .custom), "custom label")
    }

    func testDisciplineCompatibility() {
        XCTAssertEqual(ClimbDiscipline(rawValue: "boulder"), .boulder)
        XCTAssertEqual(ClimbDiscipline(rawValue: "top_rope"), .topRope)
        XCTAssertEqual(ClimbDiscipline(rawValue: "board"), .board)
        XCTAssertNil(ClimbDiscipline(rawValue: "unknown"))
    }
}
