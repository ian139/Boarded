import Foundation
import Combine

@MainActor
final class SessionPostDetailViewModel: ObservableObject {
    @Published private(set) var post: SessionFeedItem?
    @Published private(set) var comments: [SessionPostComment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPosting = false
    @Published private(set) var errorMessage: String?
    @Published var newComment = ""

    private let repository: any FeedRepository
    private let postID: UUID
    private var generation = 0

    init(repository: any FeedRepository, postID: UUID, post: SessionFeedItem? = nil) {
        self.repository = repository
        self.postID = postID
        self.post = post
    }

    func load() async {
        generation += 1
        let request = generation
        isLoading = true
        errorMessage = nil
        defer {
            if request == generation { isLoading = false }
        }
        do {
            let fetched = try await repository.fetchComments(postID: postID)
            try Task.checkCancellation()
            guard request == generation else { return }
            comments = fetched
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Reloads comments in chronological order, deduplicating by id.
    func reloadComments() async {
        generation += 1
        let request = generation
        do {
            let fetched = try await repository.fetchComments(postID: postID)
            try Task.checkCancellation()
            guard request == generation else { return }
            let existing = Set(comments.map(\.id))
            let additions = fetched.filter { !existing.contains($0.id) }
            comments.append(contentsOf: additions)
            comments.sort { $0.createdAt < $1.createdAt }
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func postComment() async {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isPosting else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }
        do {
            let comment = try await repository.createComment(postID: postID, content: trimmed)
            if !comments.contains(where: { $0.id == comment.id }) {
                comments.append(comment)
                comments.sort { $0.createdAt < $1.createdAt }
            }
            newComment = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
