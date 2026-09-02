import Foundation

protocol FeedRepository: Sendable {
    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage
    func fetchComments(postID: UUID) async throws -> [SessionPostComment]
    func createComment(postID: UUID, content: String) async throws -> SessionPostComment
    func toggleLike(postID: UUID) async throws -> Bool
    func createPost(
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle
    ) async throws -> SessionPost
    func createPost(
        id: UUID,
        sessionID: UUID,
        featuredAttemptID: UUID,
        caption: String?,
        imagePath: String,
        imageAlt: String,
        overlayStyle: OverlayStyle
    ) async throws -> SessionPost
    func uploadPostImage(data: Data, path: String) async throws
    func deletePostImage(path: String) async throws
    func deletePost(id: UUID) async throws
}

enum FeedRepositoryError: LocalizedError {
    case unavailable
    case notFound
    case invalidSession
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The feed is unavailable. Check your Supabase configuration."
        case .notFound: return "The post could not be found."
        case .invalidSession: return "Session post requires an ended session and valid featured attempt."
        case .unauthenticated: return "Sign in to interact with the feed."
        }
    }
}

/// Deterministic data source for previews and unit tests only. Production code
/// always uses SupabaseFeedRepository and surfaces configuration/network errors.
final class MockFeedRepository: FeedRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [SessionFeedItem]
    private var comments: [SessionPostComment]
    private var likedPostIDs: Set<UUID>
    private var posts: [SessionPost] = []
    private var uploadedImages: [String: Data] = [:]

    /// Deterministic identity and clock used by the fixture.
    let currentUserID: UUID
    let now: Date

    init(
        items: [SessionFeedItem] = [],
        comments: [SessionPostComment] = [],
        likedPostIDs: Set<UUID> = [],
        currentUserID: UUID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) {
        self.items = items
        self.comments = comments
        self.likedPostIDs = likedPostIDs
        self.currentUserID = currentUserID
        self.now = now
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        lock.lock(); defer { lock.unlock() }
        var filtered = items
        if let authorFilter {
            filtered = filtered.filter { $0.userId == authorFilter }
        }
        filtered.sort { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        if let cursor {
            filtered = filtered.filter { item in
                (item.createdAt, item.id.uuidString) < (cursor.createdAt, cursor.id.uuidString)
            }
        }
        let page = Array(filtered.prefix(pageSize))
        let hasMore = filtered.count > pageSize
        let nextCursor = page.last.map { FeedCursor(createdAt: $0.createdAt, id: $0.id) }
        return FeedPage(items: page, nextCursor: hasMore ? nextCursor : nil, hasMore: hasMore)
    }

    func fetchComments(postID: UUID) async throws -> [SessionPostComment] {
        lock.lock(); defer { lock.unlock() }
        return comments
            .filter { $0.postId == postID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createComment(postID: UUID, content: String) async throws -> SessionPostComment {
        lock.lock(); defer { lock.unlock() }
        let comment = SessionPostComment(
            id: UUID(),
            postId: postID,
            userId: currentUserID,
            content: content,
            createdAt: now,
            updatedAt: now
        )
        comments.append(comment)
        return comment
    }

    func toggleLike(postID: UUID) async throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        let nowLiked: Bool
        if likedPostIDs.contains(postID) {
            likedPostIDs.remove(postID)
            nowLiked = false
        } else {
            likedPostIDs.insert(postID)
            nowLiked = true
        }
        if let index = items.firstIndex(where: { $0.id == postID }) {
            items[index].isLiked = nowLiked
            items[index].likeCount += nowLiked ? 1 : -1
        }
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
        lock.lock(); defer { lock.unlock() }
        if let existing = posts.first(where: { $0.id == id }) {
            return existing
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

        // Reuse the matching fixture's factual session and featured-attempt
        // details so a newly published card is immediately renderable by the
        // same feed surface as seeded items.
        let fixture = items.first {
            $0.sessionId == sessionID && $0.featuredAttemptId == featuredAttemptID
        } ?? items.first { $0.sessionId == sessionID } ?? items.first
        let fixtureSession = fixture?.session
        let fixtureAttempt = fixtureSession?.featuredAttempt
        let featuredAttempt = FeedFeaturedAttempt(
            id: featuredAttemptID,
            routeName: fixtureAttempt?.routeName ?? "Featured attempt",
            discipline: fixtureAttempt?.discipline ?? .other,
            gradeSystem: fixtureAttempt?.gradeSystem ?? .custom,
            gradeLabel: fixtureAttempt?.gradeLabel ?? "—",
            outcome: fixtureAttempt?.outcome ?? .stopped,
            attemptNumber: fixtureAttempt?.attemptNumber ?? 1,
            occurredAt: fixtureAttempt?.occurredAt ?? now
        )
        let session = FeedSessionSummary(
            id: sessionID,
            venueName: fixtureSession?.venueName ?? "Session",
            startedAt: fixtureSession?.startedAt ?? now,
            endedAt: fixtureSession?.endedAt ?? now,
            durationSeconds: fixtureSession?.durationSeconds ?? 0,
            attemptCount: fixtureSession?.attemptCount ?? 0,
            sendCount: fixtureSession?.sendCount ?? 0,
            featuredAttempt: featuredAttempt
        )
        let author = FeedAuthor(
            id: currentUserID,
            username: fixture?.author.username,
            fullName: fixture?.author.fullName,
            avatarUrl: fixture?.author.avatarUrl,
            bio: fixture?.author.bio,
            homeArea: fixture?.author.homeArea
        )
        items.append(
            SessionFeedItem(
                id: post.id,
                userId: post.userId,
                sessionId: post.sessionId,
                featuredAttemptId: post.featuredAttemptId,
                caption: post.caption,
                imagePath: post.imagePath,
                imageAlt: post.imageAlt,
                overlayStyle: post.overlayStyle,
                createdAt: post.createdAt,
                updatedAt: post.updatedAt,
                author: author,
                session: session,
                likeCount: 0,
                commentCount: 0,
                isLiked: false
            )
        )
        return post
    }

    func uploadPostImage(data: Data, path: String) async throws {
        lock.lock(); defer { lock.unlock() }
        uploadedImages[path] = data
    }

    func deletePostImage(path: String) async throws {
        lock.lock(); defer { lock.unlock() }
        uploadedImages.removeValue(forKey: path)
    }

    func deletePost(id: UUID) async throws {
        lock.lock(); defer { lock.unlock() }
        posts.removeAll { $0.id == id }
        items.removeAll { $0.id == id }
    }

    func hasUploadedImage(at path: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return uploadedImages[path] != nil
    }
}

#if canImport(Supabase)
import Supabase

struct SupabaseFeedRepository: FeedRepository, Sendable {
    private let client: SupabaseClient?

    init(client: SupabaseClient? = SupabaseClientProvider.client) {
        self.client = client
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        guard let client else { throw FeedRepositoryError.unavailable }
        let params = FeedParameters(
            before_created_at: cursor?.createdAt,
            before_id: cursor?.id,
            author_filter: authorFilter,
            page_size: min(max(pageSize, 1), 50)
        )
        let items: [SessionFeedItem] = try await client.rpc("get_session_feed", params: params)
            .execute()
            .value
        let hasMore = items.count == params.page_size
        let nextCursor = items.last.map { FeedCursor(createdAt: $0.createdAt, id: $0.id) }
        return FeedPage(items: items, nextCursor: hasMore ? nextCursor : nil, hasMore: hasMore)
    }

    func fetchComments(postID: UUID) async throws -> [SessionPostComment] {
        guard let client else { throw FeedRepositoryError.unavailable }
        return try await client.from("session_post_comments")
            .select("*")
            .eq("post_id", value: postID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createComment(postID: UUID, content: String) async throws -> SessionPostComment {
        guard let client else { throw FeedRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let payload = CommentInsert(post_id: postID, user_id: userID, content: content)
        let rows: [SessionPostComment] = try await client.from("session_post_comments")
            .insert(payload)
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw FeedRepositoryError.notFound }
        return row
    }

    func toggleLike(postID: UUID) async throws -> Bool {
        guard let client else { throw FeedRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let existing: [SessionPostLike] = try await client.from("session_post_likes")
            .select("*")
            .eq("post_id", value: postID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        if existing.isEmpty {
            _ = try await client.from("session_post_likes")
                .insert(LikeInsert(post_id: postID, user_id: userID))
                .execute()
            return true
        } else {
            _ = try await client.from("session_post_likes")
                .delete()
                .eq("post_id", value: postID.uuidString)
                .eq("user_id", value: userID.uuidString)
                .execute()
            return false
        }
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
        guard let client else { throw FeedRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let payload = PostInsert(
            id: id,
            user_id: userID,
            session_id: sessionID,
            featured_attempt_id: featuredAttemptID,
            caption: caption,
            image_path: imagePath,
            image_alt: imageAlt,
            overlay_style: overlayStyle.rawValue
        )
        let rows: [SessionPost] = try await client.from("session_posts")
            .upsert(payload, onConflict: "id")
            .select("*")
            .execute()
            .value
        guard let row = rows.first else { throw FeedRepositoryError.notFound }
        return row
    }

    func uploadPostImage(data: Data, path: String) async throws {
        guard let client else { throw FeedRepositoryError.unavailable }
        _ = try await client.storage
            .from("social-media")
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "31536000",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
    }

    func deletePostImage(path: String) async throws {
        guard let client else { throw FeedRepositoryError.unavailable }
        _ = try await client.storage
            .from("social-media")
            .remove(paths: [path])
    }

    func deletePost(id: UUID) async throws {
        guard let client else { throw FeedRepositoryError.unavailable }
        _ = try await client.from("session_posts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private nonisolated struct FeedParameters: Encodable, Sendable {
    let before_created_at: Date?
    let before_id: UUID?
    let author_filter: UUID?
    let page_size: Int
}

private struct CommentInsert: Encodable {
    let post_id: UUID
    let user_id: UUID
    let content: String
}

private struct LikeInsert: Encodable {
    let post_id: UUID
    let user_id: UUID
}

private struct PostInsert: Encodable {
    let id: UUID
    let user_id: UUID
    let session_id: UUID
    let featured_attempt_id: UUID
    let caption: String?
    let image_path: String
    let image_alt: String
    let overlay_style: String
}
#endif
