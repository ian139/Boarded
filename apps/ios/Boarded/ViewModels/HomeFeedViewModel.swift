import Foundation
import Combine

@MainActor
final class HomeFeedViewModel: ObservableObject {
    @Published private(set) var items: [SendFeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationErrorMessage: String?

    private let repository: any FeedRepository
    private let pageSize: Int
    private var generation = 0
    private var nextCursor: FeedCursor?

    init(repository: any FeedRepository, pageSize: Int = 20) {
        self.repository = repository
        self.pageSize = pageSize
    }

    /// Resets the feed state, clearing items, cursors, loading flags,
    /// and errors while invalidating any in-flight requests.
    func reset() {
        generation += 1
        items = []
        nextCursor = nil
        canLoadMore = true
        errorMessage = nil
        paginationErrorMessage = nil
        isLoading = false
        isLoadingMore = false
    }

    func load() async {
        generation += 1
        let request = generation
        items = []
        nextCursor = nil
        canLoadMore = true
        errorMessage = nil
        paginationErrorMessage = nil
        isLoading = true
        defer {
            if request == generation { isLoading = false }
        }
        do {
            let page = try await repository.fetchFeed(cursor: nil, authorFilter: nil, pageSize: pageSize)
            try Task.checkCancellation()
            guard request == generation else { return }
            items = page.items
            nextCursor = page.nextCursor
            canLoadMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, let cursor = nextCursor else { return }
        let request = generation
        isLoadingMore = true
        paginationErrorMessage = nil
        defer {
            if request == generation { isLoadingMore = false }
        }
        do {
            let page = try await repository.fetchFeed(cursor: cursor, authorFilter: nil, pageSize: pageSize)
            try Task.checkCancellation()
            guard request == generation else { return }
            let existing = Set(items.map(\.id))
            let additions = page.items.filter { !existing.contains($0.id) }
            items.append(contentsOf: additions)
            nextCursor = page.nextCursor
            canLoadMore = page.hasMore
        } catch is CancellationError {
            return
        } catch {
            guard request == generation else { return }
            paginationErrorMessage = error.localizedDescription
        }
    }

    /// Applies an optimistic like toggle and rolls back on failure.
    func toggleLike(postID: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == postID }) else { return }
        let previous = items[index]
        items[index].isLiked.toggle()
        items[index].likeCount += items[index].isLiked ? 1 : -1
        do {
            let nowLiked = try await repository.toggleLike(postID: postID)
            guard let current = items.firstIndex(where: { $0.id == postID }) else { return }
            items[current].isLiked = nowLiked
        } catch {
            if let reset = items.firstIndex(where: { $0.id == postID }) {
                items[reset] = previous
            }
        }
    }
}
