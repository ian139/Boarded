import SwiftUI

/// Post detail: the send card with its comment thread and composer. Guests
/// read the thread; commenting requires an account.
struct PostDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.boardedAuth) private var auth
    @StateObject private var viewModel: PostDetailViewModel
    @State private var likeCount: Int
    @State private var isLiked: Bool
    @State private var isTogglingLike = false

    private let item: SendFeedItem
    private let repository: any FeedRepository

    init(item: SendFeedItem, repository: any FeedRepository = AppServices.feedRepository) {
        self.item = item
        self.repository = repository
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(repository: repository, postID: item.id))
        _likeCount = State(initialValue: item.likeCount)
        _isLiked = State(initialValue: item.isLiked)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.space16) {
                SendPostCard(item: current) {
                    toggleLike()
                }
                commentsSection
            }
            .padding(.horizontal, AppLayout.screenMargin)
            .padding(.vertical, AppSpacing.space16)
            .boardedContentWidth()
            .frame(maxWidth: .infinity)
        }
        .boardedPageBackground()
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var current: SendFeedItem {
        var updated = item
        updated.likeCount = likeCount
        updated.isLiked = isLiked
        return updated
    }

    private func toggleLike() {
        guard auth.isAuthenticated else {
            auth.requestAuthentication()
            return
        }
        guard !isTogglingLike else { return }
        isTogglingLike = true
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        Task {
            defer { isTogglingLike = false }
            do {
                let nowLiked = try await repository.toggleLike(postID: item.id)
                isLiked = nowLiked
            } catch {
                // Roll back the optimistic toggle.
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Comments")
            if viewModel.isLoading {
                VStack(spacing: AppSpacing.space8) {
                    BoardedSkeleton(shape: AppRadius.control).frame(height: 44)
                    BoardedSkeleton(shape: AppRadius.control).frame(height: 44)
                }
            } else if let errorMessage = viewModel.errorMessage, viewModel.comments.isEmpty {
                BoardedInlineError(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.comments.isEmpty {
                Text("No comments yet. Start the conversation.")
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("comments-empty")
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.space12) {
                    ForEach(viewModel.comments) { comment in
                        VStack(alignment: .leading, spacing: AppSpacing.space4) {
                            Text(comment.content)
                                .font(AppTypography.bodyL)
                                .foregroundStyle(AppColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(BoardedFormat.relative(comment.createdAt))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .accessibilityIdentifier("comments-list")
            }
            composer
        }
    }

    @ViewBuilder
    private var composer: some View {
        if auth.isAuthenticated {
            HStack(alignment: .bottom, spacing: AppSpacing.space12) {
                TextField("Add a comment", text: $viewModel.newComment, axis: .vertical)
                    .font(AppTypography.bodyL)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, AppSpacing.space16)
                    .padding(.vertical, AppSpacing.space12)
                    .boardedSurface(in: AppRadius.control, interactive: true)
                    .accessibilityLabel("Comment")
                    .accessibilityIdentifier("comment-field")
                Button {
                    Task { await viewModel.postComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? AppColor.textDisabled
                                         : AppColor.accentDefault)
                        .frame(width: AppLayout.minimumTarget, height: AppLayout.minimumTarget)
                }
                .disabled(viewModel.isPosting || viewModel.newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Post comment")
                .accessibilityIdentifier("comment-submit")
            }
            if let errorMessage = viewModel.errorMessage, !viewModel.comments.isEmpty {
                BoardedInlineError(message: errorMessage) {
                    Task { await viewModel.postComment() }
                }
            }
        } else {
            Button {
                auth.requestAuthentication()
            } label: {
                Text("Sign in to comment")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BoardedButtonStyle(.secondary))
            .accessibilityIdentifier("comment-auth")
        }
    }
}
