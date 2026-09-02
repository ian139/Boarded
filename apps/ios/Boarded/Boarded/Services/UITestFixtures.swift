import Foundation
import UIKit
import SwiftUI

enum UITestFixtures {
    static let userID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    static let otherID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let sessionID = UUID(uuidString: "22222222-3333-4444-8888-222222222222")!
    static let attemptID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    static let postID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
    static let localSessionImagePath = "fixture://session-wall"
    static let sessionImageAlt = "Overhanging home bouldering wall with colorful holds and training volumes"
    static var sessionImage: UIImage? { UIImage(named: "SessionFixtureWall") }
    static var requestedDynamicTypeSize: DynamicTypeSize? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-UIPreferredContentSizeCategoryName"),
              arguments.indices.contains(index + 1)
        else { return nil }
        switch arguments[index + 1] {
        case "UICTContentSizeCategoryXS": return .xSmall
        case "UICTContentSizeCategoryS": return .small
        case "UICTContentSizeCategoryM": return .medium
        case "UICTContentSizeCategoryL": return .large
        case "UICTContentSizeCategoryXL": return .xLarge
        case "UICTContentSizeCategoryXXL": return .xxLarge
        case "UICTContentSizeCategoryXXXL": return .xxxLarge
        case "UICTContentSizeCategoryAccessibilityMedium": return .accessibility1
        case "UICTContentSizeCategoryAccessibilityLarge": return .accessibility2
        case "UICTContentSizeCategoryAccessibilityExtraLarge": return .accessibility3
        case "UICTContentSizeCategoryAccessibilityExtraExtraLarge": return .accessibility4
        case "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge": return .accessibility5
        default: return nil
        }
    }

    static var usesAccessibilityLargeText: Bool {
        requestedDynamicTypeSize?.isAccessibilitySize == true
    }
    static let feed: [SessionFeedItem] = [
        SessionFeedItem(
            id: postID,
            userId: otherID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "First try, quiet feet.",
            imagePath: localSessionImagePath,
            imageAlt: sessionImageAlt,
            overlayStyle: .attemptTimeline,
            createdAt: now,
            updatedAt: now,
            author: FeedAuthor(id: otherID, username: "mara", fullName: "Mara Chen", avatarUrl: nil, bio: nil, homeArea: "North Shore"),
            session: FeedSessionSummary(
                id: sessionID,
                venueName: "Home Board",
                startedAt: now.addingTimeInterval(-7200),
                endedAt: now,
                durationSeconds: 7200,
                attemptCount: 48,
                sendCount: 16,
                featuredAttempt: FeedFeaturedAttempt(
                    id: attemptID,
                    routeName: "Steep Circuit",
                    discipline: .boulder,
                    gradeSystem: .vScale,
                    gradeLabel: "V6",
                    outcome: .sent,
                    attemptNumber: 1,
                    occurredAt: now
                ),
                attemptTimeline: (1...48).map { number in
                    let outcome: AttemptOutcome
                    switch number % 3 {
                    case 1: outcome = .sent
                    case 2: outcome = .fell
                    default: outcome = .stopped
                    }
                    return FeedAttemptTimelineItem(attemptNumber: number, outcome: outcome)
                }
            ),
            likeCount: 3,
            commentCount: 1,
            isLiked: false
        )
    ]
    static let comments: [SessionPostComment] = [
        SessionPostComment(
            id: UUID(uuidString: "55555555-5555-4555-8555-555555555555")!,
            postId: postID,
            userId: userID,
            content: "Precise finish.",
            createdAt: now,
            updatedAt: now
        )
    ]
    static let meetups: [Meetup] = [Meetup(id: UUID(uuidString: "66666666-6666-4666-8666-666666666666")!, organizerId: otherID, title: "Tuesday Granite Session", description: "A focused two-hour bouldering session.", venueName: "Granite Works", area: "North Shore", startsAt: now.addingTimeInterval(86400), endsAt: now.addingTimeInterval(93600), capacity: 6, status: .scheduled, createdAt: now, updatedAt: now)]
    static let profile = Profile(id: userID, username: "fixture", fullName: "Fixture Climber", avatarUrl: nil, bio: "Building a climbing journal, one line at a time.", homeArea: "North Shore", createdAt: now)
    static let statistics = ProfileStatistics(sessionCount: 8, sendCount: 21, attemptCount: 37, sendRate: 21.0 / 37.0, bestGrade: RankedGrade(system: .vScale, label: "V7", rank: 7))
}
