import Foundation

protocol FeedRepository {
    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage
    func fetchComments(postID: UUID) async throws -> [SendPostComment]
    func createComment(postID: UUID, content: String) async throws -> SendPostComment
    func toggleLike(postID: UUID) async throws -> Bool
    func createPost(attemptID: UUID, caption: String?, imagePath: String?, imageAlt: String?) async throws -> SendPost
    func createPost(
        id: UUID,
        attemptID: UUID,
        caption: String?,
        imagePath: String?,
        imageAlt: String?
    ) async throws -> SendPost
    func uploadPostImage(data: Data, path: String) async throws
}

enum FeedRepositoryError: LocalizedError {
    case unavailable
    case notFound
    case notSent
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The feed is unavailable. Check your Supabase configuration."
        case .notFound: return "The post could not be found."
        case .notSent: return "Only sent attempts can be shared."
        case .unauthenticated: return "Sign in to interact with the feed."
        }
    }
}

/// Deterministic data source for previews and unit tests only. Production code
/// always uses SupabaseFeedRepository and surfaces configuration/network errors.
final class MockFeedRepository: FeedRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [SendFeedItem]
    private var comments: [SendPostComment]
    private var likedPostIDs: Set<UUID>
    private var posts: [SendPost] = []
    private var uploadedImages: [String: Data] = [:]

    /// Deterministic identity and clock used by the fixture.
    let currentUserID: UUID
    let now: Date

    init(
        items: [SendFeedItem] = [],
        comments: [SendPostComment] = [],
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

    func fetchComments(postID: UUID) async throws -> [SendPostComment] {
        lock.lock(); defer { lock.unlock() }
        return comments
            .filter { $0.postId == postID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createComment(postID: UUID, content: String) async throws -> SendPostComment {
        lock.lock(); defer { lock.unlock() }
        let comment = SendPostComment(
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
        lock.lock(); defer { lock.unlock() }
        if let existing = posts.first(where: { $0.id == id }) {
            return existing
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
        uploadedImages[path] = data
    }
}

#if canImport(Supabase)
import Supabase

struct SupabaseFeedRepository: FeedRepository {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    @MainActor init() {
        self.init(client: SupabaseClientProvider.client)
    }

    func fetchFeed(cursor: FeedCursor?, authorFilter: UUID?, pageSize: Int) async throws -> FeedPage {
        guard let client else { throw FeedRepositoryError.unavailable }
        let params = FeedParameters(
            before_created_at: cursor?.createdAt,
            before_id: cursor?.id,
            author_filter: authorFilter,
            page_size: min(max(pageSize, 1), 50)
        )
        let items: [SendFeedItem] = try await client.rpc("get_send_feed", params: params)
            .execute()
            .value
        let hasMore = items.count == params.page_size
        let nextCursor = items.last.map { FeedCursor(createdAt: $0.createdAt, id: $0.id) }
        return FeedPage(items: items, nextCursor: hasMore ? nextCursor : nil, hasMore: hasMore)
    }

    func fetchComments(postID: UUID) async throws -> [SendPostComment] {
        guard let client else { throw FeedRepositoryError.unavailable }
        return try await client.from("send_post_comments")
            .select("*")
            .eq("post_id", value: postID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createComment(postID: UUID, content: String) async throws -> SendPostComment {
        guard let client else { throw FeedRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let payload = CommentInsert(post_id: postID, user_id: userID, content: content)
        let rows: [SendPostComment] = try await client.from("send_post_comments")
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
        let existing: [SendPostLike] = try await client.from("send_post_likes")
            .select("*")
            .eq("post_id", value: postID.uuidString)
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
        if existing.isEmpty {
            _ = try await client.from("send_post_likes")
                .insert(LikeInsert(post_id: postID, user_id: userID))
                .execute()
            return true
        } else {
            _ = try await client.from("send_post_likes")
                .delete()
                .eq("post_id", value: postID.uuidString)
                .eq("user_id", value: userID.uuidString)
                .execute()
            return false
        }
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
        guard let client else { throw FeedRepositoryError.unavailable }
        let userID = try await client.auth.session.user.id
        let payload = PostInsert(
            id: id,
            user_id: userID,
            attempt_id: attemptID,
            caption: caption,
            image_path: imagePath,
            image_alt: imageAlt
        )
        let rows: [SendPost] = try await client.from("send_posts")
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
}
private struct FeedParameters: Encodable {
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
    let attempt_id: UUID
    let caption: String?
    let image_path: String?
    let image_alt: String?
}
#endif
