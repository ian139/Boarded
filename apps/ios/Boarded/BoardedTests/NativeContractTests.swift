import XCTest
import SwiftData
@testable import Boarded

@MainActor
final class NativeContractTests: XCTestCase {
    // MARK: - Decoding

    func testSendFeedItemDecodesCanonicalWireFields() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "user_id": "22222222-2222-4222-8222-222222222222",
          "attempt_id": "33333333-3333-4333-8333-333333333333",
          "caption": "First of the grade",
          "image_path": null,
          "image_alt": null,
          "created_at": "2026-08-31T12:30:00Z",
          "updated_at": "2026-08-31T12:30:00Z",
          "author": {
            "id": "22222222-2222-4222-8222-222222222222",
            "username": "mara",
            "full_name": "Mara Climber",
            "avatar_url": null,
            "bio": null,
            "home_area": "Boulder"
          },
          "attempt": {
            "id": "33333333-3333-4333-8333-333333333333",
            "board_route_id": null,
            "route_name": "North Arete",
            "discipline": "boulder",
            "grade_system": "v_scale",
            "grade_label": "V6",
            "outcome": "sent",
            "attempt_number": 3,
            "occurred_at": "2026-08-31T12:20:00Z",
            "created_at": "2026-08-31T12:20:00Z"
          },
          "like_count": 4,
          "comment_count": 2,
          "is_liked": true
        }
        """
        let item = try JSONDecoder().boarded().decode(SendFeedItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.author.username, "mara")
        XCTAssertEqual(item.author.homeArea, "Boulder")
        XCTAssertEqual(item.attempt.gradeLabel, "V6")
        XCTAssertEqual(item.attempt.discipline, .boulder)
        XCTAssertEqual(item.attempt.gradeSystem, .vScale)
        XCTAssertEqual(item.attempt.outcome, .sent)
        XCTAssertEqual(item.likeCount, 4)
        XCTAssertEqual(item.commentCount, 2)
        XCTAssertTrue(item.isLiked)
    }

    func testClimbAttemptDecodesSnakeCaseAndEnums() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "session_id": "22222222-2222-4222-8222-222222222222",
          "user_id": "33333333-3333-4333-8333-333333333333",
          "board_route_id": null,
          "route_name": "Slab",
          "discipline": "top_rope",
          "grade_system": "yds",
          "grade_label": "5.10a",
          "outcome": "fell",
          "attempt_number": 2,
          "notes": "foot slip",
          "occurred_at": "2026-08-31T12:20:00Z",
          "created_at": "2026-08-31T12:20:00Z"
        }
        """
        let attempt = try JSONDecoder().boarded().decode(ClimbAttempt.self, from: Data(json.utf8))
        XCTAssertEqual(attempt.discipline, .topRope)
        XCTAssertEqual(attempt.gradeSystem, .yds)
        XCTAssertEqual(attempt.outcome, .fell)
        XCTAssertEqual(attempt.notes, "foot slip")
    }

    func testProfileDecodesHomeArea() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "username": "mara",
          "full_name": "Mara Climber",
          "avatar_url": null,
          "bio": null,
          "home_area": "Boulder",
          "created_at": "2026-01-01T00:00:00Z"
        }
        """
        let profile = try JSONDecoder().boarded().decode(Profile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.homeArea, "Boulder")
        XCTAssertEqual(profile.displayName, "Mara Climber")
    }

    // MARK: - Sent-only eligibility

    func testOnlySentAttemptsAreSendEligible() {
        XCTAssertTrue(attempt(outcome: .sent).isSendEligible)
        XCTAssertFalse(attempt(outcome: .fell).isSendEligible)
        XCTAssertFalse(attempt(outcome: .stopped).isSendEligible)
    }

    // MARK: - Grade statistics

    func testGradeStatsSendRateAndBestGrade() {
        let attempts = [
            attempt(outcome: .sent, label: "V3"),
            attempt(outcome: .sent, label: "V7"),
            attempt(outcome: .fell, label: "V10")
        ]
        let stats = ProfileStatisticsCalculator.calculate(sessions: [session()], attempts: attempts)
        XCTAssertEqual(stats.sendCount, 2)
        XCTAssertEqual(stats.attemptCount, 3)
        XCTAssertEqual(stats.sendRate ?? 0, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(stats.bestGrade?.label, "V7")
    }

    // MARK: - Session transitions

    func testSessionLoggerTransitionsAndPersists() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context)
        let viewModel = SessionLoggerViewModel(modelContext: context, syncService: sync, userId: userID)

        viewModel.startSession(venueName: "Gym")
        XCTAssertTrue(viewModel.isActive)
        XCTAssertNotNil(viewModel.activeSession)

        viewModel.recordAttempt(
            routeName: "Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            notes: nil
        )
        XCTAssertEqual(viewModel.attempts.count, 1)

        viewModel.endSession()
        XCTAssertFalse(viewModel.isActive)
        XCTAssertNil(viewModel.activeSession)
        XCTAssertTrue(viewModel.attempts.isEmpty)

        let pendingSessions = try context.fetch(FetchDescriptor<PendingSession>())
        let pendingAttempts = try context.fetch(FetchDescriptor<PendingAttempt>())
        XCTAssertEqual(pendingSessions.count, 1)
        XCTAssertEqual(pendingAttempts.count, 1)
    }

    func testSessionLoggerReplaysImmediatelyWhileOnline() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(
            repository: repository,
            feedRepository: MockFeedRepository(),
            modelContext: context
        )
        let viewModel = SessionLoggerViewModel(modelContext: context, syncService: sync, userId: userID)

        viewModel.startSession(venueName: "Gym")
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(try await repository.fetchSessions(userID: userID).count, 1)
        XCTAssertEqual(viewModel.syncState, .synced)

        viewModel.recordAttempt(
            routeName: "Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            notes: nil
        )
        await Task.yield()
        await Task.yield()
        let sessionID = try XCTUnwrap(viewModel.activeSession?.id)
        XCTAssertEqual(try await repository.fetchAttempts(sessionID: sessionID).count, 1)
        XCTAssertEqual(viewModel.syncState, .synced)
    }

    // MARK: - Optimistic rollback

    func testFeedLikeRollsBackOnFailure() async {
        let item = feedItem()
        let repository = FailingLikeFeedRepository(items: [item])
        let viewModel = HomeFeedViewModel(repository: repository, pageSize: 20)
        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 1)
        let before = viewModel.items[0]

        await viewModel.toggleLike(postID: item.id)
        XCTAssertEqual(viewModel.items[0], before)
    }

    // MARK: - Meetup capacity and open-state semantics

    func testMeetupJoinIsIdempotentAndEnforcesOpenState() async throws {
        let organizer = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let joiner = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let full = Meetup(
            id: UUID(), organizerId: organizer, title: "Full", description: "d", venueName: "v",
            area: "a", startsAt: now.addingTimeInterval(3600), endsAt: nil, capacity: 2,
            status: .scheduled, createdAt: now, updatedAt: now
        )
        let cancelled = Meetup(
            id: UUID(), organizerId: organizer, title: "Cancelled", description: "d", venueName: "v",
            area: "a", startsAt: now.addingTimeInterval(3600), endsAt: nil, capacity: nil,
            status: .cancelled, createdAt: now, updatedAt: now
        )
        let past = Meetup(
            id: UUID(), organizerId: organizer, title: "Past", description: "d", venueName: "v",
            area: "a", startsAt: now.addingTimeInterval(-3600), endsAt: nil, capacity: nil,
            status: .scheduled, createdAt: now, updatedAt: now
        )
        let own = Meetup(
            id: UUID(), organizerId: joiner, title: "Own", description: "d", venueName: "v",
            area: "a", startsAt: now.addingTimeInterval(3600), endsAt: nil, capacity: nil,
            status: .scheduled, createdAt: now, updatedAt: now
        )
        let repository = MockMeetupRepository(
            meetups: [full, cancelled, past, own],
            currentUserID: joiner,
            now: now
        )

        let first = try await repository.joinMeetup(id: full.id)
        let second = try await repository.joinMeetup(id: full.id)
        XCTAssertEqual(second, first)

        do {
            _ = try await repository.joinMeetup(id: cancelled.id)
            XCTFail("Expected cancelled error")
        } catch let error as MeetupRepositoryError {
            XCTAssertEqual(error, .cancelled)
        }
        do {
            _ = try await repository.joinMeetup(id: past.id)
            XCTFail("Expected past error")
        } catch let error as MeetupRepositoryError {
            XCTAssertEqual(error, .past)
        }
        do {
            _ = try await repository.joinMeetup(id: own.id)
            XCTFail("Expected organizer error")
        } catch let error as MeetupRepositoryError {
            XCTAssertEqual(error, .organizerJoin)
        }
    }

    func testMeetupJoinRejectsFullCapacityForNewAttendee() async throws {
        let organizer = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let existingAttendee = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let joiner = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let meetup = Meetup(
            id: UUID(), organizerId: organizer, title: "Full", description: "d", venueName: "v",
            area: "a", startsAt: now.addingTimeInterval(3600), endsAt: nil, capacity: 2,
            status: .scheduled, createdAt: now, updatedAt: now
        )
        let attendee = MeetupAttendee(meetupId: meetup.id, userId: existingAttendee, joinedAt: now)
        let repository = MockMeetupRepository(
            meetups: [meetup],
            attendees: [attendee],
            currentUserID: joiner,
            now: now
        )

        do {
            _ = try await repository.joinMeetup(id: meetup.id)
            XCTFail("Expected full error for a new attendee")
        } catch let error as MeetupRepositoryError {
            XCTAssertEqual(error, .full)
        }
    }

    func testDraftReplayPublishesAfterAttemptAndCleansLocalArtifacts() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context
        )
        let attemptID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let draftID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let attempt = PendingAttempt(
            id: attemptID,
            sessionId: UUID(uuidString: "66666666-6666-4666-8666-666666666666")!,
            userId: userID,
            boardRouteId: nil,
            routeName: "Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 150)
        )
        let fileName = "draft-\(draftID.uuidString).jpg"
        let imageData = Data([0x01, 0x02, 0x03])
        let draft = PendingSendDraft(
            id: draftID,
            attemptId: attemptID,
            caption: "A send",
            imageFileName: fileName,
            imageAlt: "A slab",
            createdAt: Date(timeIntervalSince1970: 160)
        )
        try sync.enqueue(attempt: attempt)
        try sync.enqueue(draft: draft, imageData: imageData)

        await sync.replay()

        let posts = feed.createdPosts()
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].id, draftID)
        XCTAssertEqual(posts[0].imagePath, "\(userID.uuidString.lowercased())/\(draftID.uuidString.lowercased()).jpg")
        XCTAssertEqual(feed.uploadedPaths(), [posts[0].imagePath!])
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSendDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertEqual(sync.state, .synced)

        await sync.replay()
        XCTAssertEqual(feed.createdPosts().count, 1)
    }

    func testDraftReplayRetainsDraftAndImageAfterPublishFailure() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        feed.failCreatePost = true
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context
        )
        let attemptID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let draftID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
        let attempt = PendingAttempt(
            id: attemptID,
            sessionId: UUID(uuidString: "99999999-9999-4999-8999-999999999999")!,
            userId: userID,
            boardRouteId: nil,
            routeName: "Crimp",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V5",
            outcome: .sent,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 150)
        )
        let fileName = "draft-\(draftID.uuidString).jpg"
        let imageData = Data([0x09, 0x08, 0x07])
        let draft = PendingSendDraft(
            id: draftID,
            attemptId: attemptID,
            caption: "Retry me",
            imageFileName: fileName,
            imageAlt: "A crimp",
            createdAt: Date(timeIntervalSince1970: 160)
        )
        try sync.enqueue(attempt: attempt)
        try sync.enqueue(draft: draft, imageData: imageData)

        await sync.replay()

        let retained = try XCTUnwrap(try context.fetch(FetchDescriptor<PendingSendDraft>()).first)
        XCTAssertEqual(retained.syncState, .failed)
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), imageData)
        XCTAssertEqual(sync.state, .failed)
        XCTAssertNotNil(sync.errorMessage)

        feed.failCreatePost = false
        await sync.replay()

        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSendDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertEqual(sync.state, .synced)
    }

    // MARK: - Draft persistence

    func testDraftImageStoreRoundTrip() throws {
        let fileName = "test-\(UUID().uuidString).jpg"
        let data = Data([0x01, 0x02, 0x03])
        let url = try DraftImageStore.write(data, fileName: fileName)
        XCTAssertEqual(try Data(contentsOf: url), data)
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), data)
        DraftImageStore.delete(fileName: fileName)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
    }

    // MARK: - Offline replay and idempotency

    func testReplayIsIdempotentAndNeverLosesAttempts() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context)

        let pendingSession = PendingSession(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let pendingAttempt = PendingAttempt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            sessionId: pendingSession.id,
            userId: userID,
            boardRouteId: nil,
            routeName: "Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 150)
        )
        try sync.enqueue(session: pendingSession)
        try sync.enqueue(attempt: pendingAttempt)

        await sync.replay()
        XCTAssertEqual(sync.state, .synced)
        XCTAssertEqual(try await repository.fetchSessions(userID: userID).count, 1)
        XCTAssertEqual(try await repository.fetchAttempts(sessionID: pendingSession.id).count, 1)

        await sync.replay()
        XCTAssertEqual(try await repository.fetchSessions(userID: userID).count, 1)
        XCTAssertEqual(try await repository.fetchAttempts(sessionID: pendingSession.id).count, 1)
    }

    // MARK: - Helpers

    private let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private func makeContext() throws -> ModelContext {
        let schema = Schema([PendingSession.self, PendingAttempt.self, PendingSendDraft.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func session() -> ClimbingSession {
        ClimbingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
    }

    private func attempt(outcome: AttemptOutcome, label: String = "V3") -> ClimbAttempt {
        ClimbAttempt(
            id: UUID(),
            sessionId: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            boardRouteId: nil,
            routeName: "Route",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: label,
            outcome: outcome,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 150),
            createdAt: Date(timeIntervalSince1970: 150)
        )
    }

    private func feedItem() -> SendFeedItem {
        SendFeedItem(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            userId: userID,
            attemptId: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
            caption: nil,
            imagePath: nil,
            imageAlt: nil,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            author: FeedAuthor(id: userID, username: "mara", fullName: nil, avatarUrl: nil, bio: nil, homeArea: nil),
            attempt: FeedAttempt(
                id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
                boardRouteId: nil,
                routeName: "Slab",
                discipline: .boulder,
                gradeSystem: .vScale,
                gradeLabel: "V4",
                outcome: .sent,
                attemptNumber: 1,
                occurredAt: Date(timeIntervalSince1970: 90),
                createdAt: Date(timeIntervalSince1970: 90)
            ),
            likeCount: 0,
            commentCount: 0,
            isLiked: false
        )
    }
}

/// A feed repository whose like toggle always fails, used to verify rollback.
private final class FailingLikeFeedRepository: FeedRepository, @unchecked Sendable {
    private let items: [SendFeedItem]

    init(items: [SendFeedItem]) {
        self.items = items
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        FeedPage(items: items, nextCursor: nil, hasMore: false)
    }

    func fetchComments(postID: UUID) async throws -> [SendPostComment] { [] }

    func createComment(postID: UUID, content: String) async throws -> SendPostComment {
        throw FeedRepositoryError.unavailable
    }

    func toggleLike(postID: UUID) async throws -> Bool {
        throw FeedRepositoryError.unavailable
    }

    func createPost(attemptID: UUID, caption: String?, imagePath: String?, imageAlt: String?) async throws -> SendPost {
        throw FeedRepositoryError.unavailable
    }

    func createPost(
        id: UUID,
        attemptID: UUID,
        caption: String?,
        imagePath: String?,
        imageAlt: String?
    ) async throws -> SendPost {
        throw FeedRepositoryError.unavailable
    }

    func uploadPostImage(data: Data, path: String) async throws {
        throw FeedRepositoryError.unavailable
    }
}

private final class RecordingDraftFeedRepository: FeedRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let currentUserID: UUID
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var posts: [SendPost] = []
    private var paths: [String] = []
    private var shouldFailCreatePost = false

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    var failCreatePost: Bool {
        get {
            lock.lock(); defer { lock.unlock() }
            return shouldFailCreatePost
        }
        set {
            lock.lock(); defer { lock.unlock() }
            shouldFailCreatePost = newValue
        }
    }

    func uploadedPaths() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return paths
    }

    func createdPosts() -> [SendPost] {
        lock.lock(); defer { lock.unlock() }
        return posts
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        FeedPage(items: [], nextCursor: nil, hasMore: false)
    }

    func fetchComments(postID: UUID) async throws -> [SendPostComment] { [] }

    func createComment(postID: UUID, content: String) async throws -> SendPostComment {
        throw FeedRepositoryError.unavailable
    }

    func toggleLike(postID: UUID) async throws -> Bool {
        throw FeedRepositoryError.unavailable
    }

    func createPost(attemptID: UUID, caption: String?, imagePath: String?, imageAlt: String?) async throws -> SendPost {
        try await createPost(
            id: UUID(),
            attemptID: attemptID,
            caption: caption,
            imagePath: imagePath,
            imageAlt: imageAlt
        )
    }

    func createPost(
        id: UUID,
        attemptID: UUID,
        caption: String?,
        imagePath: String?,
        imageAlt: String?
    ) async throws -> SendPost {
        lock.lock()
        defer { lock.unlock() }
        if let existing = posts.first(where: { $0.id == id }) {
            return existing
        }
        if shouldFailCreatePost {
            throw FeedRepositoryError.unavailable
        }
        let post = SendPost(
            id: id,
            userId: currentUserID,
            attemptId: attemptID,
            caption: caption,
            imagePath: imagePath,
            imageAlt: imageAlt,
            createdAt: now,
            updatedAt: now
        )
        posts.append(post)
        return post
    }

    func uploadPostImage(data: Data, path: String) async throws {
        lock.lock(); defer { lock.unlock() }
        paths.append(path)
    }
}
