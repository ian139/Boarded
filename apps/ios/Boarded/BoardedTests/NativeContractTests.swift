import XCTest
import SwiftData
@testable import Boarded

@MainActor
final class NativeContractTests: XCTestCase {
    // MARK: - Decoding

    func testSessionFeedItemDecodesCanonicalWireFields() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "user_id": "22222222-2222-4222-8222-222222222222",
          "session_id": "33333333-3333-4333-8333-333333333333",
          "featured_attempt_id": "44444444-4444-4444-8444-444444444444",
          "caption": "Strong session on the board.",
          "image_path": "22222222-2222-4222-8222-222222222222/11111111-1111-4111-8111-111111111111.jpg",
          "image_alt": "Climber holding small crimp on 40 degree board",
          "overlay_style": "stats",
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
          "session": {
            "id": "33333333-3333-4333-8333-333333333333",
            "venue_name": "Granite Works",
            "started_at": "2026-08-31T10:30:00Z",
            "ended_at": "2026-08-31T12:30:00Z",
            "duration_seconds": 7200,
            "attempt_count": 8,
            "send_count": 4,
            "featured_attempt": {
              "id": "44444444-4444-4444-8444-444444444444",
              "route_name": "North Arete",
              "discipline": "boulder",
              "grade_system": "v_scale",
              "grade_label": "V6",
              "outcome": "sent",
              "attempt_number": 3,
              "occurred_at": "2026-08-31T12:20:00Z"
            }
          },
          "like_count": 4,
          "comment_count": 2,
          "is_liked": true
        }
        """
        let item = try JSONDecoder().boarded().decode(SessionFeedItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.id, UUID(uuidString: "11111111-1111-4111-8111-111111111111")!)
        XCTAssertEqual(item.userId, UUID(uuidString: "22222222-2222-4222-8222-222222222222")!)
        XCTAssertEqual(item.sessionId, UUID(uuidString: "33333333-3333-4333-8333-333333333333")!)
        XCTAssertEqual(item.featuredAttemptId, UUID(uuidString: "44444444-4444-4444-8444-444444444444")!)
        XCTAssertEqual(item.caption, "Strong session on the board.")
        XCTAssertEqual(item.imagePath, "22222222-2222-4222-8222-222222222222/11111111-1111-4111-8111-111111111111.jpg")
        XCTAssertEqual(item.imageAlt, "Climber holding small crimp on 40 degree board")
        XCTAssertEqual(item.overlayStyle, .stats)
        XCTAssertEqual(item.author.username, "mara")
        XCTAssertEqual(item.author.homeArea, "Boulder")
        XCTAssertEqual(item.session.venueName, "Granite Works")
        XCTAssertEqual(item.session.durationSeconds, 7200)
        XCTAssertEqual(item.session.attemptCount, 8)
        XCTAssertEqual(item.session.sendCount, 4)
        XCTAssertEqual(item.session.featuredAttempt.gradeLabel, "V6")
        XCTAssertEqual(item.session.featuredAttempt.discipline, .boulder)
        XCTAssertEqual(item.session.featuredAttempt.gradeSystem, .vScale)
        XCTAssertEqual(item.session.featuredAttempt.outcome, .sent)
        XCTAssertEqual(item.likeCount, 4)
        XCTAssertEqual(item.commentCount, 2)
        XCTAssertTrue(item.isLiked)
    }

    func testSessionFeedItemDecodesAttemptTimelineOverlayAndFellOutcomeWithoutNotes() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "user_id": "22222222-2222-4222-8222-222222222222",
          "session_id": "33333333-3333-4333-8333-333333333333",
          "featured_attempt_id": "44444444-4444-4444-8444-444444444444",
          "caption": null,
          "image_path": "22222222-2222-4222-8222-222222222222/11111111-1111-4111-8111-111111111111.jpg",
          "image_alt": "Timeline photo",
          "overlay_style": "attempt_timeline",
          "created_at": "2026-08-31T12:30:00Z",
          "updated_at": "2026-08-31T12:30:00Z",
          "author": {
            "id": "22222222-2222-4222-8222-222222222222",
            "username": "mara",
            "full_name": null,
            "avatar_url": null,
            "bio": null,
            "home_area": null
          },
          "session": {
            "id": "33333333-3333-4333-8333-333333333333",
            "venue_name": "Movement",
            "started_at": "2026-08-31T10:30:00Z",
            "ended_at": "2026-08-31T12:30:00Z",
            "duration_seconds": 7200,
            "attempt_count": 3,
            "send_count": 0,
            "featured_attempt": {
              "id": "44444444-4444-4444-8444-444444444444",
              "route_name": "High Project",
              "discipline": "sport",
              "grade_system": "yds",
              "grade_label": "5.13a",
              "outcome": "fell",
              "attempt_number": 1,
              "occurred_at": "2026-08-31T11:00:00Z"
            }
          },
          "like_count": 0,
          "comment_count": 0,
          "is_liked": false
        }
        """
        let item = try JSONDecoder().boarded().decode(SessionFeedItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.overlayStyle, .attemptTimeline)
        XCTAssertEqual(item.session.featuredAttempt.outcome, .fell)
        XCTAssertEqual(item.session.featuredAttempt.gradeSystem, .yds)
        XCTAssertEqual(item.session.featuredAttempt.gradeLabel, "5.13a")
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

    func testProfileRepositoryCreateTrimsFieldsAndRejectsDuplicate() async throws {
        let repository = MockProfileRepository()
        let created = try await repository.createProfile(
            ProfileDraft(
                id: userID,
                username: "  mara ",
                displayName: "  Mara Climber ",
                homeArea: "  Boulder "
            )
        )

        XCTAssertEqual(created.id, userID)
        XCTAssertEqual(created.username, "mara")
        XCTAssertEqual(created.fullName, "Mara Climber")
        XCTAssertEqual(created.homeArea, "Boulder")

        do {
            _ = try await repository.createProfile(
                ProfileDraft(id: userID, username: "other", displayName: nil, homeArea: nil)
            )
            XCTFail("A second profile must be rejected")
        } catch let error as ProfileRepositoryError {
            XCTAssertEqual(error, .alreadyExists)
        }
    }

    // MARK: - AppSession profile setup

    func testAppSessionCompleteProfileSetupSucceedsAndClearsError() async throws {
        let repository = MockProfileRepository()
        let session = AppSession(profileRepository: repository, userId: userID, userEmail: "mara@example.com")
        XCTAssertTrue(session.needsProfileSetup)
        XCTAssertNil(session.profile)
        XCTAssertNil(session.errorMessage)

        await session.completeProfileSetup(
            username: "  mara ",
            displayName: "  Mara Climber ",
            homeArea: "  Boulder "
        )

        XCTAssertFalse(session.needsProfileSetup)
        XCTAssertEqual(session.profile?.id, userID)
        XCTAssertEqual(session.profile?.username, "mara")
        XCTAssertEqual(session.profile?.fullName, "Mara Climber")
        XCTAssertEqual(session.profile?.homeArea, "Boulder")
        XCTAssertEqual(session.displayName, "Mara Climber")
        XCTAssertNil(session.errorMessage)
        XCTAssertFalse(session.isLoading)
    }

    func testAppSessionCompleteProfileSetupRejectsEmptyUsername() async throws {
        let repository = MockProfileRepository()
        let session = AppSession(profileRepository: repository, userId: userID, userEmail: "mara@example.com")
        XCTAssertTrue(session.needsProfileSetup)

        await session.completeProfileSetup(
            username: "   ",
            displayName: "Mara Climber",
            homeArea: "Boulder"
        )

        XCTAssertTrue(session.needsProfileSetup)
        XCTAssertNil(session.profile)
        XCTAssertEqual(session.errorMessage, "Username cannot be empty.")
    }

    func testAppSessionCompleteProfileSetupRejectsUnauthenticated() async throws {
        let repository = MockProfileRepository()
        let session = AppSession(profileRepository: repository, userId: nil)
        XCTAssertFalse(session.needsProfileSetup)

        await session.completeProfileSetup(username: "mara", displayName: nil, homeArea: nil)
        XCTAssertNil(session.profile)
    }

    func testAppSessionCompleteProfileSetupAcceptsExistingProfileOnCreateFailure() async throws {
        let existing = Profile(
            id: userID,
            username: "existing_mara",
            fullName: "Existing Mara",
            avatarUrl: nil,
            bio: nil,
            homeArea: "Boulder",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let repository = MockProfileRepository(profile: existing)
        let session = AppSession(profileRepository: repository, userId: userID, userEmail: "mara@example.com")
        XCTAssertTrue(session.needsProfileSetup)

        await session.completeProfileSetup(
            username: "different_mara",
            displayName: "Different",
            homeArea: "Denver"
        )

        XCTAssertFalse(session.needsProfileSetup)
        XCTAssertEqual(session.profile?.username, "existing_mara")
        XCTAssertNil(session.errorMessage)
    }

    func testAppSessionCompleteProfileSetupRetainsRecoverableErrorWhenCreationFailsAndNoProfileExists() async throws {
        let repository = MissingProfileFailingCreateRepository()
        let session = AppSession(profileRepository: repository, userId: userID, userEmail: "mara@example.com")
        XCTAssertTrue(session.needsProfileSetup)

        await session.completeProfileSetup(
            username: "mara",
            displayName: "Mara Climber",
            homeArea: "Boulder"
        )

        XCTAssertTrue(session.needsProfileSetup)
        XCTAssertNil(session.profile)
        XCTAssertEqual(session.errorMessage, ProfileRepositoryError.unavailable.localizedDescription)
    }

    // MARK: - Active session store

    func testActiveSessionStoreScopesRowsToSignedInUser() throws {
        let context = try makeContext()
        let otherID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let currentSession = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Current Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil
        )
        let otherSession = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            userId: otherID,
            venueName: "Other Gym",
            startedAt: Date(timeIntervalSince1970: 200),
            endedAt: nil
        )
        let currentAttempt = PendingAttempt(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
            sessionId: currentSession.id,
            userId: userID,
            boardRouteId: nil,
            routeName: "Current Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .fell,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 110)
        )
        let currentSend = PendingAttempt(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000004")!,
            sessionId: currentSession.id,
            userId: userID,
            boardRouteId: nil,
            routeName: "Current Overhang",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V5",
            outcome: .sent,
            attemptNumber: 2,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 120),
            syncState: .synced
        )
        let otherSend = PendingAttempt(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000005")!,
            sessionId: otherSession.id,
            userId: otherID,
            boardRouteId: nil,
            routeName: "Other Send",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V7",
            outcome: .sent,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 210),
            syncState: .synced
        )
        context.insert(currentSession)
        context.insert(otherSession)
        context.insert(currentAttempt)
        context.insert(currentSend)
        context.insert(otherSend)
        try context.save()

        XCTAssertEqual(
            ActiveSessionStore.fetchActive(userID: userID, in: context)?.id,
            currentSession.id
        )
        XCTAssertNil(ActiveSessionStore.fetchActive(userID: nil, in: context))
        XCTAssertEqual(
            ActiveSessionStore.attempts(
                sessionID: currentSession.id,
                userID: userID,
                in: context
            ).map(\.id),
            [currentSend.id, currentAttempt.id]
        )
        XCTAssertEqual(
            ActiveSessionStore.sendableAttempts(userID: userID, in: context).map(\.id),
            [currentSend.id]
        )
        XCTAssertEqual(
            ActiveSessionStore.sendableAttempts(userID: otherID, in: context).map(\.id),
            [otherSend.id]
        )
        XCTAssertTrue(ActiveSessionStore.sendableAttempts(userID: nil, in: context).isEmpty)
    }

    // MARK: - Grade statistics

    func testGradeStatsSendRateAndBestGrade() {
        let attempts = [
            attempt(outcome: .sent, label: "V3"),
            attempt(outcome: .sent, label: "V7"),
            attempt(outcome: .fell, label: "V8"),
            attempt(outcome: .stopped, label: "V5")
        ]
        let pending = attempts.map { attempt in
            PendingAttempt(
                id: attempt.id,
                sessionId: attempt.sessionId,
                userId: attempt.userId,
                boardRouteId: attempt.boardRouteId,
                routeName: attempt.routeName,
                discipline: attempt.discipline,
                gradeSystem: attempt.gradeSystem,
                gradeLabel: attempt.gradeLabel,
                outcome: attempt.outcome,
                attemptNumber: attempt.attemptNumber,
                notes: attempt.notes,
                occurredAt: attempt.occurredAt
            )
        }
        let summary = SessionSummary(
            venue: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            attempts: pending
        )
        XCTAssertEqual(summary.sendCount, 2)
        XCTAssertEqual(summary.bestSend?.gradeLabel, "V7")
        XCTAssertEqual(summary.successRate, 0.5)
    }

    // MARK: - Session logger

    func testSessionLoggerTransitionsAndPersists() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID)
        let viewModel = SessionLoggerViewModel(modelContext: context, syncService: sync, userId: userID)

        XCTAssertFalse(viewModel.isActive)
        XCTAssertTrue(viewModel.attempts.isEmpty)

        viewModel.startSession(venueName: "Gym")
        XCTAssertTrue(viewModel.isActive)
        XCTAssertEqual(viewModel.activeSession?.venueName, "Gym")

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
        XCTAssertTrue(viewModel.attempts.isEmpty)
        XCTAssertNotNil(try context.fetch(FetchDescriptor<PendingSession>()).first?.endedAt)
    }

    func testSessionLoggerReplaysImmediatelyWhileOnline() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, feedRepository: MockFeedRepository(), modelContext: context, userID: userID)
        let viewModel = SessionLoggerViewModel(modelContext: context, syncService: sync, userId: userID)

        viewModel.startSession(venueName: "Gym")
        let sessionID = try XCTUnwrap(viewModel.activeSession?.id)
        viewModel.recordAttempt(
            routeName: "Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            notes: nil
        )

        viewModel.endSession()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(try await repository.fetchSessions(userID: userID).count, 1)
        XCTAssertEqual(try await repository.fetchAttempts(sessionID: sessionID).count, 1)
    }

    // MARK: - Undo and attempt management

    func testUndoQueuedAttemptRemovesLocallyWithoutRemoteUpload() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)
        let pending = pendingAttempt(id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!, syncState: .queued)
        context.insert(pending)
        try context.save()

        try sync.delete(attempt: pending)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttemptDeletion>()).isEmpty)
        XCTAssertEqual(sync.state, .synced)

        let onlineSync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: true)
        await onlineSync.replay()
        XCTAssertTrue(try await repository.fetchAttempts(sessionID: pending.sessionId).isEmpty)
    }

    func testUndoSyncedAttemptReplaysRemoteDeleteAndIsIdempotent() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)
        let pending = pendingAttempt(id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!, syncState: .synced)
        context.insert(pending)
        try context.save()
        _ = try await repository.upsertAttempt(pending.remote)

        try sync.delete(attempt: pending)
        let tombstones = try context.fetch(FetchDescriptor<PendingAttemptDeletion>())
        XCTAssertEqual(tombstones.map(\.id), [pending.id])
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).isEmpty)

        let onlineSync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: true)
        await onlineSync.replay()
        await onlineSync.replay()

        XCTAssertTrue(try await repository.fetchAttempts(sessionID: pending.sessionId).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttemptDeletion>()).isEmpty)
        XCTAssertEqual(onlineSync.state, .synced)
    }

    func testUndoAttemptCleansLinkedDraftAndImageWithoutAffectingUnrelatedDrafts() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)

        let session1ID = UUID(uuidString: "11111111-0000-4000-8000-000000000001")!
        let session2ID = UUID(uuidString: "22222222-0000-4000-8000-000000000002")!
        let attempt1ID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let attempt2ID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let attempt1 = pendingAttempt(id: attempt1ID, syncState: .queued)
        attempt1.sessionId = session1ID
        let attempt2 = pendingAttempt(id: attempt2ID, syncState: .queued)
        attempt2.sessionId = session2ID

        let draft1ID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let draft2ID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let fileName1 = "draft-\(draft1ID.uuidString).jpg"
        let fileName2 = "draft-\(draft2ID.uuidString).jpg"
        let data1 = Data([0x01, 0x02])
        let data2 = Data([0x03, 0x04])

        let draft1 = PendingSessionDraft(
            id: draft1ID,
            sessionId: session1ID,
            featuredAttemptId: attempt1ID,
            caption: "Draft 1",
            imageFileName: fileName1,
            imageAlt: "Alt 1"
        )
        let draft2 = PendingSessionDraft(
            id: draft2ID,
            sessionId: session2ID,
            featuredAttemptId: attempt2ID,
            caption: "Draft 2",
            imageFileName: fileName2,
            imageAlt: "Alt 2"
        )

        try sync.enqueue(attempt: attempt1)
        try sync.enqueue(attempt: attempt2)
        try sync.enqueue(draft: draft1, imageData: data1)
        try sync.enqueue(draft: draft2, imageData: data2)

        XCTAssertEqual(DraftImageStore.read(fileName: fileName1), data1)
        XCTAssertEqual(DraftImageStore.read(fileName: fileName2), data2)

        try sync.delete(attempt: attempt1)

        // Draft 1 and its image are deleted after the model save.
        let remainingDraftsAfterDelete1 = try context.fetch(FetchDescriptor<PendingSessionDraft>())
        XCTAssertEqual(remainingDraftsAfterDelete1.map(\.id), [draft2ID])
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).contains(where: { $0.id == attempt2ID }))
        XCTAssertNil(DraftImageStore.read(fileName: fileName1))

        // Draft 2 and image 2 preserved
        XCTAssertEqual(DraftImageStore.read(fileName: fileName2), data2)
        XCTAssertEqual(sync.state, .queued)

        try sync.delete(attempt: attempt2)

        // Draft 2 and its image are deleted after the model save.
        let remainingDraftsAfterDelete2 = try context.fetch(FetchDescriptor<PendingSessionDraft>())
        XCTAssertTrue(remainingDraftsAfterDelete2.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName2))
        XCTAssertEqual(sync.state, .synced)
    }

    func testDeleteAttemptOnlyDiscardsDraftWhenAttemptIsFeaturedAttemptInSameSession() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)

        let sessionID = UUID(uuidString: "11111111-0000-4000-8000-000000000001")!
        let featuredAttemptID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let unrelatedAttemptID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let featuredAttempt = pendingAttempt(id: featuredAttemptID, syncState: .queued)
        featuredAttempt.sessionId = sessionID
        let unrelatedAttempt = pendingAttempt(id: unrelatedAttemptID, syncState: .queued)
        unrelatedAttempt.sessionId = sessionID

        let draftID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let fileName = "draft-\(draftID.uuidString).jpg"
        let imageData = Data([0x01, 0x02, 0x03, 0x04])
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: featuredAttemptID,
            caption: "Featured send draft",
            imageFileName: fileName,
            imageAlt: "Board climb"
        )

        try sync.enqueue(attempt: featuredAttempt)
        try sync.enqueue(attempt: unrelatedAttempt)
        try sync.enqueue(draft: draft, imageData: imageData)

        XCTAssertEqual(DraftImageStore.read(fileName: fileName), imageData)

        // 1. Deleting an unrelated attempt in the same session does NOT delete the draft or its image.
        try sync.delete(attempt: unrelatedAttempt)

        let draftsAfterUnrelatedDelete = try context.fetch(FetchDescriptor<PendingSessionDraft>())
        XCTAssertEqual(draftsAfterUnrelatedDelete.map(\.id), [draftID])
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), imageData)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).contains(where: { $0.id == featuredAttemptID }))
        XCTAssertFalse(try context.fetch(FetchDescriptor<PendingAttempt>()).contains(where: { $0.id == unrelatedAttemptID }))

        // 2. Deleting the draft's featured attempt DOES delete the draft and cleans up the image.
        try sync.delete(attempt: featuredAttempt)

        let draftsAfterFeaturedDelete = try context.fetch(FetchDescriptor<PendingSessionDraft>())
        XCTAssertTrue(draftsAfterFeaturedDelete.isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).isEmpty)
    }

    func testEnqueueDraftEnforcesOnePendingDraftPerSessionByReplacingPriorDraftAndCleaningOrphanImage() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(
            repository: repository,
            feedRepository: feed,
            modelContext: context,
            userID: userID,
            connectivityOverride: false
        )

        let sessionID = UUID(uuidString: "11111111-0000-4000-8000-000000000001")!
        let attemptID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let session = PendingSession(
            id: sessionID,
            userId: userID,
            venueName: "Granite",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .queued
        )
        let attempt = pendingAttempt(id: attemptID, syncState: .queued)
        attempt.sessionId = sessionID

        try sync.enqueue(session: session)
        try sync.enqueue(attempt: attempt)

        let draft1ID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let draft2ID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let fileName1 = "draft1-\(draft1ID.uuidString).jpg"
        let fileName2 = "draft2-\(draft2ID.uuidString).jpg"
        let data1 = Data([0x11, 0x22])
        let data2 = Data([0x33, 0x44])

        let draft1 = PendingSessionDraft(
            id: draft1ID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Draft 1",
            imageFileName: fileName1,
            imageAlt: "Alt 1"
        )
        let draft2 = PendingSessionDraft(
            id: draft2ID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Draft 2 (replacement)",
            imageFileName: fileName2,
            imageAlt: "Alt 2"
        )

        // Enqueue first draft
        try sync.enqueue(draft: draft1, imageData: data1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingSessionDraft>()).map(\.id), [draft1ID])
        XCTAssertEqual(DraftImageStore.read(fileName: fileName1), data1)

        // Enqueue second draft for the same session replaces the prior draft and removes its orphan image file
        try sync.enqueue(draft: draft2, imageData: data2)
        let remainingDrafts = try context.fetch(FetchDescriptor<PendingSessionDraft>())
        XCTAssertEqual(remainingDrafts.map(\.id), [draft2ID])
        XCTAssertNil(DraftImageStore.read(fileName: fileName1))
        XCTAssertEqual(DraftImageStore.read(fileName: fileName2), data2)

        // Replay creates only the replacement post and succeeds cleanly without conflict
        await sync.replay()
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertEqual(feed.createdPosts().first?.id, draft2ID)
        XCTAssertEqual(feed.createdPosts().first?.caption, "Draft 2 (replacement)")
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName2))
        XCTAssertEqual(sync.state, .synced)
    }

    func testReplayDeduplicatesMultiplePendingDraftsForSameSessionWithoutBackendConflict() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(
            repository: repository,
            feedRepository: feed,
            modelContext: context,
            userID: userID,
            connectivityOverride: false
        )

        let sessionID = UUID(uuidString: "11111111-0000-4000-8000-000000000001")!
        let attemptID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let session = PendingSession(
            id: sessionID,
            userId: userID,
            venueName: "Granite",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attempt = pendingAttempt(id: attemptID, syncState: .synced)
        attempt.sessionId = sessionID
        context.insert(session)
        context.insert(attempt)
        _ = try await repository.upsertSession(session.remote)
        _ = try await repository.upsertAttempt(attempt.remote)

        let draft1ID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let draft2ID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let fileName1 = "draft1-\(draft1ID.uuidString).jpg"
        let fileName2 = "draft2-\(draft2ID.uuidString).jpg"
        let data1 = Data([0x11, 0x22])
        let data2 = Data([0x33, 0x44])

        let draft1 = PendingSessionDraft(
            id: draft1ID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Draft 1",
            imageFileName: fileName1,
            imageAlt: "Alt 1"
        )
        let draft2 = PendingSessionDraft(
            id: draft2ID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Draft 2",
            imageFileName: fileName2,
            imageAlt: "Alt 2"
        )
        context.insert(draft1)
        context.insert(draft2)
        try context.save()
        try DraftImageStore.write(data1, fileName: fileName1)
        try DraftImageStore.write(data2, fileName: fileName2)

        // Replay deduplicates duplicate drafts for the same session so backend parent uniqueness is not violated
        await sync.replay()
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName1))
        XCTAssertNil(DraftImageStore.read(fileName: fileName2))
        XCTAssertEqual(sync.state, .synced)
    }

    func testUndoAttemptSaveFailureRetainsLinkedRowsAndImage() throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)

        let sessionID = UUID()
        let attemptID = UUID()
        let draftID = UUID()
        let conflictID = UUID()
        let fileName = "draft-\(draftID.uuidString).jpg"
        let imageData = Data([0x0a, 0x0b])
        let attempt = pendingAttempt(id: attemptID, syncState: .queued)
        attempt.sessionId = sessionID
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Retry me",
            imageFileName: fileName,
            imageAlt: "Alt text"
        )
        let conflict = pendingAttempt(id: conflictID, syncState: .queued)

        context.insert(attempt)
        context.insert(draft)
        context.insert(conflict)
        try context.save()
        try DraftImageStore.write(imageData, fileName: fileName)
        defer { DraftImageStore.delete(fileName: fileName) }

        // A duplicate unique ID makes the model save fail after the delete
        // mutations have been staged.
        context.insert(pendingAttempt(id: conflictID, syncState: .queued))

        XCTAssertThrowsError(try sync.delete(attempt: attempt))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).contains(where: { $0.id == attemptID }))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).contains(where: { $0.id == draftID }))
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), imageData)
    }

    func testUndoAttemptReportsImageCleanupFailureAfterRowsSave() throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)
        let sessionID = UUID()
        let attemptID = UUID()
        let draftID = UUID()
        let fileName = "draft-\(draftID.uuidString).jpg"
        let attempt = pendingAttempt(id: attemptID, syncState: .queued)
        attempt.sessionId = sessionID
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Cleanup me",
            imageFileName: fileName,
            imageAlt: "Alt text"
        )

        try sync.enqueue(attempt: attempt)
        try sync.enqueue(draft: draft)
        let imageURL = DraftImageStore.directory.appendingPathComponent(fileName, isDirectory: false)
        try FileManager.default.createDirectory(at: imageURL, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: imageURL) }
        try Data([0x01]).write(to: imageURL.appendingPathComponent("retained.bin"))

        XCTAssertThrowsError(try sync.delete(attempt: attempt)) { error in
            XCTAssertTrue(error.localizedDescription.contains(fileName))
            XCTAssertEqual(sync.errorMessage, error.localizedDescription)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttempt>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertEqual(sync.state, .failed)
    }

    func testUndoSyncedAttemptCleansLinkedDraftAndPreventsOrphanPublish() async throws {
        let context = try makeContext()
        let repository = MockSessionRepository()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(repository: repository, feedRepository: feed, modelContext: context, userID: userID, connectivityOverride: false)

        let sessionID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let attemptID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let pending = pendingAttempt(id: attemptID, syncState: .synced)
        pending.sessionId = sessionID
        context.insert(pending)
        try context.save()
        _ = try await repository.upsertAttempt(pending.remote)

        let draftID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let fileName = "draft-\(draftID.uuidString).jpg"
        let imageData = Data([0xaa, 0xbb])
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Undo me",
            imageFileName: fileName,
            imageAlt: "Alt"
        )
        try sync.enqueue(draft: draft, imageData: imageData)

        try sync.delete(attempt: pending)

        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        let tombstones = try context.fetch(FetchDescriptor<PendingAttemptDeletion>())
        XCTAssertEqual(tombstones.map(\.id), [attemptID])

        let onlineSync = SessionSyncService(repository: repository, feedRepository: feed, modelContext: context, userID: userID, connectivityOverride: true)
        await onlineSync.replay()

        XCTAssertTrue(try await repository.fetchAttempts(sessionID: pending.sessionId).isEmpty)
        XCTAssertTrue(feed.createdPosts().isEmpty)
        XCTAssertTrue(feed.uploadedPaths().isEmpty)
        XCTAssertEqual(onlineSync.state, .synced)
    }

    func testFailedRemoteDeleteRetainsTombstoneForRetry() async throws {
        let context = try makeContext()
        let repository = DeletionRecordingSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)
        let pending = pendingAttempt(id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!, syncState: .synced)
        context.insert(pending)
        try context.save()
        _ = try await repository.upsertAttempt(pending.remote)

        try sync.delete(attempt: pending)
        repository.failDelete = true
        await sync.replay()

        let retained = try XCTUnwrap(try context.fetch(FetchDescriptor<PendingAttemptDeletion>()).first)
        XCTAssertEqual(retained.id, pending.id)
        XCTAssertEqual(retained.syncState, .failed)
        XCTAssertEqual(sync.state, .failed)

        repository.failDelete = false
        await sync.replay()
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttemptDeletion>()).isEmpty)
        XCTAssertTrue(try await repository.fetchAttempts(sessionID: pending.sessionId).isEmpty)
    }

    func testUndoDuringInFlightReplayUploadsThenDeletesAttempt() async throws {
        let context = try makeContext()
        let repository = BlockingSessionRepository()
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID, connectivityOverride: false)
        let viewModel = SessionLoggerViewModel(modelContext: context, syncService: sync, userId: userID)
        viewModel.startSession(venueName: "Gym")
        let sessionID = try XCTUnwrap(viewModel.activeSession?.id)
        viewModel.recordAttempt(
            routeName: "Slab",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            notes: nil
        )
        let replayTask = Task { await sync.replay() }
        await repository.waitForSessionUpsert()

        let claimed = try XCTUnwrap(try context.fetch(FetchDescriptor<PendingAttempt>()).first)
        XCTAssertEqual(claimed.syncState, .syncing)
        viewModel.undoLatestAttempt()
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingAttemptDeletion>()).count, 1)

        await repository.releaseSessionUpsert()
        await replayTask.value

        XCTAssertTrue(try await repository.fetchAttempts(sessionID: sessionID).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingAttemptDeletion>()).isEmpty)
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

    func testMeetupsViewModelShowsCreatedMeetupImmediately() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = MockMeetupRepository(meetups: [], currentUserID: userID, now: now)
        let model = MeetupsViewModel(repository: repository)
        await model.load()
        let created = try await repository.createMeetup(
            MeetupDraft(
                title: "New Line",
                description: "A session",
                venueName: "Granite Works",
                area: "North Shore",
                startsAt: now.addingTimeInterval(3600),
                endsAt: nil,
                capacity: nil
            )
        )

        model.insert(created)

        XCTAssertEqual(model.meetups.map(\.id), [created.id])
        XCTAssertEqual(model.meetups.first?.title, "New Line")
    }

    // MARK: - Draft publication and gating

    func testDraftReplayPublishesAfterEndedSessionAndAttemptAndCleansLocalArtifacts() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(repository: MockSessionRepository(), feedRepository: feed, modelContext: context, userID: userID)
        let sessionID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let attemptID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let draftID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let session = PendingSession(
            id: sessionID,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let attempt = PendingAttempt(
            id: attemptID,
            sessionId: sessionID,
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
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "A session",
            imageFileName: fileName,
            imageAlt: "A slab",
            overlayStyle: .stats,
            createdAt: Date(timeIntervalSince1970: 210)
        )
        try sync.enqueue(session: session)
        try sync.enqueue(attempt: attempt)
        try sync.enqueue(draft: draft, imageData: imageData)

        await sync.replay()

        let posts = feed.createdPosts()
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts[0].id, draftID)
        XCTAssertEqual(posts[0].sessionId, sessionID)
        XCTAssertEqual(posts[0].featuredAttemptId, attemptID)
        XCTAssertEqual(posts[0].overlayStyle, .stats)
        XCTAssertEqual(posts[0].imagePath, "\(userID.uuidString.lowercased())/\(draftID.uuidString.lowercased()).jpg")
        XCTAssertEqual(feed.uploadedPaths(), [posts[0].imagePath])
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertEqual(sync.state, .synced)

        await sync.replay()
        XCTAssertEqual(feed.createdPosts().count, 1)
    }

    func testDraftReplayGatedUntilSessionIsEndedAndSynced() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(repository: MockSessionRepository(), feedRepository: feed, modelContext: context, userID: userID)
        let sessionID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let attemptID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let draftID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!

        // Active session: endedAt is nil
        let session = PendingSession(
            id: sessionID,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil
        )
        let attempt = PendingAttempt(
            id: attemptID,
            sessionId: sessionID,
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
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Session draft",
            imageFileName: fileName,
            imageAlt: "A slab",
            overlayStyle: .stats,
            createdAt: Date(timeIntervalSince1970: 160)
        )
        try sync.enqueue(session: session)
        try sync.enqueue(attempt: attempt)
        try sync.enqueue(draft: draft, imageData: imageData)

        // 1. Replay with unended session: session and attempt sync, but draft remains queued
        await sync.replay()
        XCTAssertTrue(feed.createdPosts().isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingSessionDraft>()).count, 1)
        XCTAssertEqual(sync.state, .queued)

        // 2. End the session and replay again: now draft publishes cleanly
        session.endedAt = Date(timeIntervalSince1970: 200)
        session.syncState = .queued
        try context.save()

        await sync.replay()
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertEqual(sync.state, .synced)
    }

    func testDraftReplayRetainsDraftAndImageAfterPublishFailure() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        feed.failCreatePost = true
        let sync = SessionSyncService(repository: MockSessionRepository(), feedRepository: feed, modelContext: context, userID: userID)
        let sessionID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let attemptID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let draftID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
        let session = PendingSession(
            id: sessionID,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let attempt = PendingAttempt(
            id: attemptID,
            sessionId: sessionID,
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
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: "Retry me",
            imageFileName: fileName,
            imageAlt: "A crimp",
            createdAt: Date(timeIntervalSince1970: 210)
        )
        try sync.enqueue(session: session)
        try sync.enqueue(attempt: attempt)
        try sync.enqueue(draft: draft, imageData: imageData)

        await sync.replay()

        let retained = try XCTUnwrap(try context.fetch(FetchDescriptor<PendingSessionDraft>()).first)
        XCTAssertEqual(retained.syncState, .failed)
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), imageData)
        XCTAssertEqual(sync.state, .failed)
        XCTAssertNotNil(sync.errorMessage)

        feed.failCreatePost = false
        await sync.replay()

        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertEqual(sync.state, .synced)
    }

    func testDiscardingFailedDraftRemovesItBeforeAnyLaterReplay() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        feed.failCreatePost = true
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context,
            userID: userID
        )
        let session = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attempt = pendingAttempt(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            syncState: .synced
        )
        attempt.sessionId = session.id
        let draftID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let fileName = "discard-\(draftID.uuidString).jpg"
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: session.id,
            featuredAttemptId: attempt.id,
            caption: "Abandoned",
            imageFileName: fileName,
            imageAlt: "A session"
        )
        context.insert(session)
        context.insert(attempt)
        try context.save()
        try sync.enqueue(draft: draft, imageData: Data([0x01, 0x02]))

        await sync.replay()
        XCTAssertEqual(
            try XCTUnwrap(try context.fetch(FetchDescriptor<PendingSessionDraft>()).first).syncState,
            .failed
        )
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), Data([0x01, 0x02]))

        try await sync.delete(draft: draft)
        XCTAssertEqual(
            feed.deletedImagePaths(),
            ["\(userID.uuidString.lowercased())/\(draftID.uuidString.lowercased()).jpg"]
        )
        feed.failCreatePost = false
        await sync.replay()

        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertTrue(feed.createdPosts().isEmpty)
    }

    // MARK: - Account switch and feed reset

    func testHomeFeedIdentityResetAndActiveSessionAccountSwitch() async throws {
        let context = try makeContext()
        let userA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let userB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        let sessionA = PendingSession(
            id: UUID(uuidString: "aaaaaaaa-0000-4000-8000-000000000001")!,
            userId: userA,
            venueName: "Gym A",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: nil
        )
        let sessionB = PendingSession(
            id: UUID(uuidString: "bbbbbbbb-0000-4000-8000-000000000002")!,
            userId: userB,
            venueName: "Gym B",
            startedAt: Date(timeIntervalSince1970: 200),
            endedAt: nil
        )
        context.insert(sessionA)
        context.insert(sessionB)
        try context.save()

        let item1 = feedItem()
        var item2 = feedItem()
        item2.id = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        let feedRepo = UserAwareFeedRepository(
            items: [item1, item2],
            likesByUser: [
                userA: [item1.id],
                userB: [item2.id]
            ],
            activeUserID: userA
        )

        let viewModel = HomeFeedViewModel(repository: feedRepo, pageSize: 20)

        // 1. Under Account A: active session is A's, feed reflects A's likes (item1 is liked).
        let activeForA = ActiveSessionStore.fetchActive(userID: userA, in: context)
        XCTAssertEqual(activeForA?.id, sessionA.id)
        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items.first(where: { $0.id == item1.id })?.isLiked, true)
        XCTAssertEqual(viewModel.items.first(where: { $0.id == item2.id })?.isLiked, false)

        // 2. Sign-out to guest: active session is nil, feed state resets and reloads without likes.
        feedRepo.activeUserID = nil
        let activeForGuest = ActiveSessionStore.fetchActive(userID: nil, in: context)
        XCTAssertNil(activeForGuest)

        viewModel.reset()
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertNil(viewModel.errorMessage)

        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items.first(where: { $0.id == item1.id })?.isLiked, false)
        XCTAssertEqual(viewModel.items.first(where: { $0.id == item2.id })?.isLiked, false)

        // 3. Switch to Account B: active session is B's (not A's), feed reloads with B's likes (item2 is liked).
        feedRepo.activeUserID = userB
        let activeForB = ActiveSessionStore.fetchActive(userID: userB, in: context)
        XCTAssertEqual(activeForB?.id, sessionB.id)

        viewModel.reset()
        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items.first(where: { $0.id == item1.id })?.isLiked, false)
        XCTAssertEqual(viewModel.items.first(where: { $0.id == item2.id })?.isLiked, true)
    }

    func testHomeFeedViewModelResetClearsAllStateAndInvalidatesInFlightRequests() async {
        let item = feedItem()
        let repository = UserAwareFeedRepository(items: [item])
        let viewModel = HomeFeedViewModel(repository: repository, pageSize: 20)

        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 1)

        viewModel.reset()
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertTrue(viewModel.canLoadMore)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.paginationErrorMessage)
    }

    // MARK: - Draft discard and media retention

    func testDraftDiscardDeletesUploadedRemoteMediaAndLocalDraft() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        feed.failCreatePost = true
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context,
            userID: userID
        )
        let session = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attempt = pendingAttempt(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            syncState: .synced
        )
        attempt.sessionId = session.id
        let draftID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let fileName = "discard-\(draftID.uuidString).jpg"
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: session.id,
            featuredAttemptId: attempt.id,
            caption: "Discard uploaded",
            imageFileName: fileName,
            imageAlt: "A session"
        )
        context.insert(session)
        context.insert(attempt)
        try context.save()
        try sync.enqueue(draft: draft, imageData: Data([0x01, 0x02]))

        await sync.replay()
        XCTAssertEqual(sync.state, .failed)
        let canonicalPath = "\(userID.uuidString.lowercased())/\(draftID.uuidString.lowercased()).jpg"
        XCTAssertTrue(feed.uploadedPaths().contains(canonicalPath))
        XCTAssertNotNil(DraftImageStore.read(fileName: fileName))

        try await sync.delete(draft: draft)
        XCTAssertEqual(feed.deletedImagePaths(), [canonicalPath])
        XCTAssertFalse(feed.uploadedPaths().contains(canonicalPath))
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertEqual(sync.state, .synced)
    }

    func testDraftDiscardTreatsAbsentRemoteImageIdempotently() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context,
            userID: userID
        )
        let session = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attempt = pendingAttempt(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            syncState: .synced
        )
        attempt.sessionId = session.id
        let draftID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
        let fileName = "discard-absent-\(draftID.uuidString).jpg"
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: session.id,
            featuredAttemptId: attempt.id,
            caption: "Discard absent",
            imageFileName: fileName,
            imageAlt: "A session"
        )
        context.insert(session)
        context.insert(attempt)
        try context.save()
        try sync.enqueue(draft: draft, imageData: Data([0x03, 0x04]))

        let canonicalPath = "\(userID.uuidString.lowercased())/\(draftID.uuidString.lowercased()).jpg"
        try await sync.delete(draft: draft)

        XCTAssertEqual(feed.deletedImagePaths(), [canonicalPath])
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertEqual(sync.state, .synced)
    }

    func testDraftDiscardRetainsDraftAndLocalImageWhenRemoteDeleteFails() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        feed.failCreatePost = true
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context,
            userID: userID
        )
        let session = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attempt = pendingAttempt(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            syncState: .synced
        )
        attempt.sessionId = session.id
        let draftID = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let fileName = "discard-fail-\(draftID.uuidString).jpg"
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: session.id,
            featuredAttemptId: attempt.id,
            caption: "Discard fail",
            imageFileName: fileName,
            imageAlt: "A session"
        )
        context.insert(session)
        context.insert(attempt)
        try context.save()
        try sync.enqueue(draft: draft, imageData: Data([0x05, 0x06]))

        await sync.replay()
        XCTAssertEqual(sync.state, .failed)

        feed.failDeletePostImage = true
        do {
            try await sync.delete(draft: draft)
            XCTFail("Remote deletion failure must throw")
        } catch {
            XCTAssertEqual(sync.state, .failed)
            XCTAssertNotNil(sync.errorMessage)
        }

        // Local draft and local image file are retained on remote deletion failure.
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingSessionDraft>()).map(\.id), [draftID])
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), Data([0x05, 0x06]))
    }

    func testPublishFailureRetainsRemoteMediaForRetry() async throws {
        let context = try makeContext()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        feed.failCreatePost = true
        let sync = SessionSyncService(
            repository: MockSessionRepository(),
            feedRepository: feed,
            modelContext: context,
            userID: userID
        )
        let session = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            venueName: "Gym",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attempt = pendingAttempt(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            syncState: .synced
        )
        attempt.sessionId = session.id
        let draftID = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!
        let fileName = "publish-fail-\(draftID.uuidString).jpg"
        let draft = PendingSessionDraft(
            id: draftID,
            sessionId: session.id,
            featuredAttemptId: attempt.id,
            caption: "Retryable publish",
            imageFileName: fileName,
            imageAlt: "A session"
        )
        context.insert(session)
        context.insert(attempt)
        try context.save()
        try sync.enqueue(draft: draft, imageData: Data([0x07, 0x08]))

        await sync.replay()
        XCTAssertEqual(sync.state, .failed)
        let canonicalPath = "\(userID.uuidString.lowercased())/\(draftID.uuidString.lowercased()).jpg"
        XCTAssertTrue(feed.uploadedPaths().contains(canonicalPath))
        XCTAssertTrue(feed.deletedImagePaths().isEmpty)
        XCTAssertEqual(DraftImageStore.read(fileName: fileName), Data([0x07, 0x08]))
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingSessionDraft>()).map(\.id), [draftID])

        // Retry succeeds without losing the remote media.
        feed.failCreatePost = false
        await sync.replay()
        XCTAssertEqual(sync.state, .synced)
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileName))
    }

    func testSessionSyncReplaysOnlyRowsOwnedByActiveUser() async throws {
        let context = try makeContext()
        let otherID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let repository = MockSessionRepository()
        let feed = RecordingDraftFeedRepository(currentUserID: userID)
        let sync = SessionSyncService(
            repository: repository,
            feedRepository: feed,
            modelContext: context,
            userID: userID
        )
        let currentSession = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
            userId: userID,
            venueName: "Current",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let otherSession = PendingSession(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
            userId: otherID,
            venueName: "Other",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200)
        )
        let currentAttempt = pendingAttempt(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!,
            syncState: .queued
        )
        currentAttempt.sessionId = currentSession.id
        let otherAttempt = pendingAttempt(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000104")!,
            syncState: .queued
        )
        otherAttempt.userId = otherID
        otherAttempt.sessionId = otherSession.id
        context.insert(currentSession)
        context.insert(otherSession)
        context.insert(currentAttempt)
        context.insert(otherAttempt)
        try context.save()

        await sync.replay()

        XCTAssertEqual(try await repository.fetchSessions(userID: userID).count, 1)
        XCTAssertTrue(try await repository.fetchSessions(userID: otherID).isEmpty)
        XCTAssertEqual(try await repository.fetchAttempts(sessionID: currentSession.id).count, 1)
        XCTAssertTrue(try await repository.fetchAttempts(sessionID: otherSession.id).isEmpty)
    }

    func testFreshAccountWithoutOwnedSessionsCannotObserveReplayOrDeleteOtherAccountDrafts() async throws {
        let context = try makeContext()
        let userA = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let userB = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let repository = MockSessionRepository()
        let feed = RecordingDraftFeedRepository(currentUserID: userA)

        // User A creates a synced session, attempt, and enqueues a draft with image data.
        let syncA = SessionSyncService(
            repository: repository,
            feedRepository: feed,
            modelContext: context,
            userID: userA,
            connectivityOverride: false
        )
        let sessionA = PendingSession(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            userId: userA,
            venueName: "Granite",
            startedAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 200),
            syncState: .synced
        )
        let attemptA = pendingAttempt(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            syncState: .synced
        )
        attemptA.userId = userA
        attemptA.sessionId = sessionA.id

        let draftAID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let fileNameA = "draft-\(draftAID.uuidString).jpg"
        let imageDataA = Data([0x12, 0x34, 0x56])
        let draftA = PendingSessionDraft(
            id: draftAID,
            sessionId: sessionA.id,
            featuredAttemptId: attemptA.id,
            caption: "User A send",
            imageFileName: fileNameA,
            imageAlt: "User A image"
        )
        context.insert(sessionA)
        context.insert(attemptA)
        try context.save()
        try syncA.enqueue(draft: draftA, imageData: imageDataA)
        defer { DraftImageStore.delete(fileName: fileNameA) }

        // User B (fresh account with 0 owned sessions and 0 owned attempts)
        let syncB = SessionSyncService(
            repository: repository,
            feedRepository: feed,
            modelContext: context,
            userID: userB,
            connectivityOverride: false
        )

        // Fresh account B has no pending work and its state is synced, never queued on User A's draft
        XCTAssertEqual(syncB.state, .synced)

        // Replay under User B must not publish User A's draft
        await syncB.replay()
        XCTAssertTrue(feed.createdPosts().isEmpty)
        XCTAssertTrue(feed.uploadedPaths().isEmpty)

        // Account B attempting to delete Account A's draft must be a no-op:
        // it must not discard User A's draft, delete its cached image, or call remote deletion.
        try await syncB.delete(draft: draftA)
        XCTAssertTrue(feed.deletedImagePaths().isEmpty)
        XCTAssertEqual(DraftImageStore.read(fileName: fileNameA), imageDataA)
        let storedDrafts = try context.fetch(FetchDescriptor<PendingSessionDraft>())
        XCTAssertEqual(storedDrafts.map(\.id), [draftAID])

        // When switching back to User A, User A owns the draft and can replay / publish it cleanly.
        let onlineSyncA = SessionSyncService(
            repository: repository,
            feedRepository: feed,
            modelContext: context,
            userID: userA,
            connectivityOverride: true
        )
        await onlineSyncA.replay()
        XCTAssertEqual(feed.createdPosts().count, 1)
        XCTAssertEqual(feed.createdPosts().first?.id, draftAID)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingSessionDraft>()).isEmpty)
        XCTAssertNil(DraftImageStore.read(fileName: fileNameA))
        XCTAssertEqual(onlineSyncA.state, .synced)
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
        let sync = SessionSyncService(repository: repository, modelContext: context, userID: userID)

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
        let schema = Schema([PendingSession.self, PendingAttempt.self, PendingAttemptDeletion.self, PendingSessionDraft.self])
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

    private func pendingAttempt(id: UUID, syncState: SyncState) -> PendingAttempt {
        PendingAttempt(
            id: id,
            sessionId: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            userId: userID,
            boardRouteId: nil,
            routeName: "Route",
            discipline: .boulder,
            gradeSystem: .vScale,
            gradeLabel: "V4",
            outcome: .sent,
            attemptNumber: 1,
            notes: nil,
            occurredAt: Date(timeIntervalSince1970: 150),
            syncState: syncState
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

    private func feedItem() -> SessionFeedItem {
        let sessionID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let attemptID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let postID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        return SessionFeedItem(
            id: postID,
            userId: userID,
            sessionId: sessionID,
            featuredAttemptId: attemptID,
            caption: nil,
            imagePath: "\(userID.uuidString.lowercased())/\(postID.uuidString.lowercased()).jpg",
            imageAlt: "Feed photo",
            overlayStyle: .stats,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            author: FeedAuthor(id: userID, username: "mara", fullName: nil, avatarUrl: nil, bio: nil, homeArea: nil),
            session: FeedSessionSummary(
                id: sessionID,
                venueName: "Gym",
                startedAt: Date(timeIntervalSince1970: 0),
                endedAt: Date(timeIntervalSince1970: 100),
                durationSeconds: 100,
                attemptCount: 1,
                sendCount: 1,
                featuredAttempt: FeedFeaturedAttempt(
                    id: attemptID,
                    routeName: "Slab",
                    discipline: .boulder,
                    gradeSystem: .vScale,
                    gradeLabel: "V4",
                    outcome: .sent,
                    attemptNumber: 1,
                    occurredAt: Date(timeIntervalSince1970: 90)
                )
            ),
            likeCount: 0,
            commentCount: 0,
            isLiked: false
        )
    }
}

/// A feed repository whose like toggle always fails, used to verify rollback.
private final class FailingLikeFeedRepository: FeedRepository, @unchecked Sendable {
    private let items: [SessionFeedItem]

    init(items: [SessionFeedItem]) {
        self.items = items
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        FeedPage(items: items, nextCursor: nil, hasMore: false)
    }

    func fetchComments(postID: UUID) async throws -> [SessionPostComment] { [] }

    func createComment(postID: UUID, content: String) async throws -> SessionPostComment {
        throw FeedRepositoryError.unavailable
    }

    func toggleLike(postID: UUID) async throws -> Bool {
        throw FeedRepositoryError.unavailable
    }

    func createPost(
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle
    ) async throws -> SessionPost {
        throw FeedRepositoryError.unavailable
    }

    func createPost(
        id: UUID,
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle
    ) async throws -> SessionPost {
        throw FeedRepositoryError.unavailable
    }

    func uploadPostImage(data: Data, path: String) async throws {
        throw FeedRepositoryError.unavailable
    }

    func deletePostImage(path: String) async throws {}
}

private final class DeletionRecordingSessionRepository: SessionRepository, @unchecked Sendable {
    private let base = MockSessionRepository()
    private let lock = NSLock()
    private var shouldFailDelete = false

    var failDelete: Bool {
        get {
            lock.lock(); defer { lock.unlock() }
            return shouldFailDelete
        }
        set {
            lock.lock(); defer { lock.unlock() }
            shouldFailDelete = newValue
        }
    }

    func fetchSessions(userID: UUID) async throws -> [ClimbingSession] {
        try await base.fetchSessions(userID: userID)
    }

    func fetchAttempts(sessionID: UUID) async throws -> [ClimbAttempt] {
        try await base.fetchAttempts(sessionID: sessionID)
    }

    func upsertSession(_ session: ClimbingSession) async throws -> ClimbingSession {
        try await base.upsertSession(session)
    }

    func upsertAttempt(_ attempt: ClimbAttempt) async throws -> ClimbAttempt {
        try await base.upsertAttempt(attempt)
    }

    func deleteAttempt(id: UUID) async throws {
        lock.lock()
        let shouldFailDelete = self.shouldFailDelete
        lock.unlock()
        if shouldFailDelete {
            throw SessionRepositoryError.unavailable
        }
        try await base.deleteAttempt(id: id)
    }
}

private actor ReplayGate {
    private var started = false
    private var released = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func markStarted() {
        started = true
        startWaiter?.resume()
        startWaiter = nil
    }

    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { continuation in
            startWaiter = continuation
        }
    }

    func release() {
        released = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }

    func waitForRelease() async {
        if released { return }
        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
        }
    }
}

private final class BlockingSessionRepository: SessionRepository, @unchecked Sendable {
    private let base = MockSessionRepository()
    private let gate = ReplayGate()

    func waitForSessionUpsert() async {
        await gate.waitForStart()
    }

    func releaseSessionUpsert() async {
        await gate.release()
    }

    func fetchSessions(userID: UUID) async throws -> [ClimbingSession] {
        try await base.fetchSessions(userID: userID)
    }

    func fetchAttempts(sessionID: UUID) async throws -> [ClimbAttempt] {
        try await base.fetchAttempts(sessionID: sessionID)
    }

    func upsertSession(_ session: ClimbingSession) async throws -> ClimbingSession {
        await gate.markStarted()
        await gate.waitForRelease()
        return try await base.upsertSession(session)
    }

    func upsertAttempt(_ attempt: ClimbAttempt) async throws -> ClimbAttempt {
        try await base.upsertAttempt(attempt)
    }

    func deleteAttempt(id: UUID) async throws {
        try await base.deleteAttempt(id: id)
    }
}

private final class RecordingDraftFeedRepository: FeedRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let currentUserID: UUID
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var posts: [SessionPost] = []
    private var paths: [String] = []
    private var deletedPaths: [String] = []
    private var shouldFailCreatePost = false
    private var shouldFailDeletePostImage = false

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

    var failDeletePostImage: Bool {
        get {
            lock.lock(); defer { lock.unlock() }
            return shouldFailDeletePostImage
        }
        set {
            lock.lock(); defer { lock.unlock() }
            shouldFailDeletePostImage = newValue
        }
    }

    func uploadedPaths() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return paths
    }

    func deletedImagePaths() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return deletedPaths
    }

    func createdPosts() -> [SessionPost] {
        lock.lock(); defer { lock.unlock() }
        return posts
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        FeedPage(items: [], nextCursor: nil, hasMore: false)
    }

    func fetchComments(postID: UUID) async throws -> [SessionPostComment] { [] }

    func createComment(postID: UUID, content: String) async throws -> SessionPostComment {
        throw FeedRepositoryError.unavailable
    }

    func toggleLike(postID: UUID) async throws -> Bool {
        throw FeedRepositoryError.unavailable
    }

    func createPost(
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle = .stats
    ) async throws -> SessionPost {
        try await createPost(
            id: UUID(),
            sessionID: sessionID,
            featuredAttemptID: featuredAttemptID,
            caption: caption,
            imagePath: imagePath,
            imageAlt: imageAlt,
            overlayStyle: overlayStyle
        )
    }

    func createPost(
        id: UUID,
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle = .stats
    ) async throws -> SessionPost {
        lock.lock()
        defer { lock.unlock() }
        if let existing = posts.first(where: { $0.id == id }) {
            return existing
        }
        if shouldFailCreatePost {
            throw FeedRepositoryError.unavailable
        }
        let post = SessionPost(
            id: id,
            userId: currentUserID,
            sessionId: sessionID,
            featuredAttemptId: featuredAttemptID,
            caption: caption,
            imagePath: imagePath,
            imageAlt: imageAlt,
            overlayStyle: overlayStyle,
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

    func deletePostImage(path: String) async throws {
        lock.lock(); defer { lock.unlock() }
        if shouldFailDeletePostImage {
            throw FeedRepositoryError.unavailable
        }
        deletedPaths.append(path)
        paths.removeAll { $0 == path }
    }
}

private final class UserAwareFeedRepository: FeedRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [SessionFeedItem]
    private var likesByUser: [UUID: Set<UUID>] = [:]
    var activeUserID: UUID?

    init(items: [SessionFeedItem], likesByUser: [UUID: Set<UUID>] = [:], activeUserID: UUID? = nil) {
        self.items = items
        self.likesByUser = likesByUser
        self.activeUserID = activeUserID
    }

    func setLikes(for user: UUID, postIDs: Set<UUID>) {
        lock.lock(); defer { lock.unlock() }
        likesByUser[user] = postIDs
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        lock.lock(); defer { lock.unlock() }
        let currentLikes = activeUserID.flatMap { likesByUser[$0] } ?? []
        let mapped = items.map { item in
            var copy = item
            copy.isLiked = currentLikes.contains(item.id)
            return copy
        }
        return FeedPage(items: mapped, nextCursor: nil, hasMore: false)
    }

    func fetchComments(postID: UUID) async throws -> [SessionPostComment] { [] }
    func createComment(postID: UUID, content: String) async throws -> SessionPostComment {
        throw FeedRepositoryError.unavailable
    }
    func toggleLike(postID: UUID) async throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let userID = activeUserID else { throw FeedRepositoryError.unauthenticated }
        var userLikes = likesByUser[userID] ?? []
        let nowLiked: Bool
        if userLikes.contains(postID) {
            userLikes.remove(postID)
            nowLiked = false
        } else {
            userLikes.insert(postID)
            nowLiked = true
        }
        likesByUser[userID] = userLikes
        return nowLiked
    }
    func createPost(
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle = .stats
    ) async throws -> SessionPost {
        throw FeedRepositoryError.unavailable
    }
    func createPost(
        id: UUID,
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle = .stats
    ) async throws -> SessionPost {
        throw FeedRepositoryError.unavailable
    }
    func uploadPostImage(data: Data, path: String) async throws {}
    func deletePostImage(path: String) async throws {}
}

private final class MissingProfileFailingCreateRepository: ProfileRepository, @unchecked Sendable {
    func fetchProfile(userID: UUID) async throws -> Profile? {
        return nil
    }

    func fetchStatistics(userID: UUID) async throws -> ProfileStatistics {
        throw ProfileRepositoryError.unavailable
    }

    func createProfile(_ draft: ProfileDraft) async throws -> Profile {
        throw ProfileRepositoryError.unavailable
    }

    func updateProfile(userID: UUID, update: ProfileUpdate) async throws -> Profile {
        throw ProfileRepositoryError.unavailable
    }
}
