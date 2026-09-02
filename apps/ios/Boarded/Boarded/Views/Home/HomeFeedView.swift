import SwiftUI
import SwiftData

/// Home tab: a photo-led journal of completed climbing sessions. Reading is
/// public; publishing and reactions require an account.
struct HomeFeedView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.modelContext) private var modelContext
    @Environment(\.boardedAuth) private var auth
    @StateObject private var viewModel: HomeFeedViewModel
    @State private var composerPresented = false
    @State private var activeSession: PendingSession?
    @State private var authenticationPresented = false

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
                        authenticationPresented = true
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
                }
                .accessibilityLabel("Share a session")
                .accessibilityIdentifier("home-compose")
            }
        }
        .sheet(isPresented: $composerPresented) {
            ShareSessionComposer()
        }
        .sheet(isPresented: $authenticationPresented) {
            NavigationStack { AuthenticationView() }
                .environmentObject(session)
        }
        .environment(
            \.boardedAuth,
            BoardedAuthContext(
                isAuthenticated: auth.isAuthenticated,
                requestAuthentication: { authenticationPresented = true }
            )
        )
        .navigationDestination(for: SessionFeedItem.self) { item in
            SessionPostDetailView(item: item)
        }
        .onAppear {
            refreshActiveSession()
        }
        .onChange(of: navigation.selectedTab) { _, tab in
            if tab == .home {
                refreshActiveSession()
                Task { await viewModel.load() }
            }
        }
        .onChange(of: session.userId) { _, _ in
            activeSession = nil
            viewModel.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeSessionDidChange)) { _ in
            refreshActiveSession()
        }
        .task(id: session.userId) {
            refreshActiveSession()
            await viewModel.load()
        }
    }

    private func refreshActiveSession() {
        guard let userID = session.userId else {
            activeSession = nil
            return
        }
        activeSession = ActiveSessionStore.fetchActive(userID: userID, in: modelContext)
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
        BoardedEmptyState(
            title: "No session journal entries yet",
            message: auth.isAuthenticated
                ? "End a session, add a climbing photo, and share the whole result."
                : "Sign in to log and share completed climbing sessions.",
            actionTitle: auth.isAuthenticated ? "Share session" : "Sign In",
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
                    SessionPostCard(item: item) {
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
