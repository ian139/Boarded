import SwiftUI
import SwiftData

/// Home tab: the shared send feed. Readable by guests; posting and reactions
/// require an account.
struct HomeFeedView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.modelContext) private var modelContext
    @Environment(\.boardedAuth) private var auth
    @StateObject private var viewModel: HomeFeedViewModel
    @State private var composerPresented = false
    @State private var activeSession: PendingSession?

    init(feedRepository: any FeedRepository = AppServices.feedRepository) {
        _viewModel = StateObject(wrappedValue: HomeFeedViewModel(repository: feedRepository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.space16) {
                BoardedEyebrow(text: "Today")
                    .accessibilityIdentifier("home-eyebrow")
                if let activeSession {
                    activeSessionCard(activeSession)
                }
                content
            }
            .padding(.horizontal, AppLayout.screenMargin)
            .padding(.top, AppSpacing.space8)
            .padding(.bottom, AppSpacing.space32)
            .boardedContentWidth()
            .frame(maxWidth: .infinity)
        }
        .boardedPageBackground()
        .navigationTitle("Home")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if auth.isAuthenticated {
                        composerPresented = true
                    } else {
                        auth.requestAuthentication()
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
                }
                .accessibilityLabel("Share a send")
                .accessibilityIdentifier("home-compose")
            }
        }
        .sheet(isPresented: $composerPresented) {
            ShareSendComposer()
        }
        .navigationDestination(for: SendFeedItem.self) { item in
            PostDetailView(item: item)
        }
        .task {
            activeSession = ActiveSessionStore.fetchActive(in: modelContext)
            if viewModel.items.isEmpty {
                await viewModel.load()
            }
        }
    }

    private func activeSessionCard(_ session: PendingSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedEyebrow(text: "Active Session")
            Text(session.venueName)
                .font(AppTypography.titleM)
                .foregroundStyle(AppColor.textPrimary)
            Text("Continue your newest-first attempt queue.")
                .font(AppTypography.bodyM)
                .foregroundStyle(AppColor.textSecondary)
            BoardedPrimaryButton(title: "Resume Logging", systemImage: "arrow.right") {
                navigation.selectedTab = .log
            }
        }
        .boardedPanel(padding: AppLayout.featureCardPadding)
        .accessibilityIdentifier("home-active-session")
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            skeletonState
        } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
            BoardedInlineError(message: errorMessage) {
                Task { await viewModel.load() }
            }
            .accessibilityIdentifier("feed-error")
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            feedList
        }
    }

    private var skeletonState: some View {
        VStack(spacing: AppLayout.cardGap) {
            BoardedFeedCardSkeleton()
            BoardedFeedCardSkeleton()
        }
        .accessibilityIdentifier("feed-loading")
    }

    private var emptyState: some View {
        BoardedRouteLineEmptyState(
            title: "Nothing shared yet.",
            message: auth.isAuthenticated
                ? "Send a route, then share it with your crew."
                : "Sign in to log sessions and share your sends.",
            actionTitle: auth.isAuthenticated ? "Share a Send" : "Sign In",
            action: {
                if auth.isAuthenticated {
                    composerPresented = true
                } else {
                    auth.requestAuthentication()
                }
            }
        )
        .accessibilityIdentifier("feed-empty")
    }

    private var feedList: some View {
        LazyVStack(spacing: AppLayout.cardGap) {
            ForEach(viewModel.items) { item in
                NavigationLink(value: item) {
                    SendPostCard(item: item) {
                        guard auth.isAuthenticated else {
                            auth.requestAuthentication()
                            return
                        }
                        Task { await viewModel.toggleLike(postID: item.id) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed-item")
            }
            paginationFooter
        }
        .accessibilityIdentifier("feed-list")
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.space16)
        } else if let paginationError = viewModel.paginationErrorMessage {
            BoardedInlineError(message: paginationError) {
                Task { await viewModel.loadMore() }
            }
        } else if viewModel.canLoadMore, let last = viewModel.items.last {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    if viewModel.items.last?.id == last.id {
                        Task { await viewModel.loadMore() }
                    }
                }
        }
    }
}
