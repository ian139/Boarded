import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var routeDetailPresenter: RouteDetailPresenter
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var routeDetailsViewModel = RoutesViewModel(repository: AppServices.routesRepository)
    @State private var profileRefreshID = 0
    @State private var isEditPresented = false
    @State private var editFullName = ""
    @State private var editUsername = ""
    @State private var editBio = ""

    init(repository: any ProfileRepository = AppServices.profileRepository) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(repository: repository))
    }

    private var theme: BoardedTheme { BoardedTheme() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if viewModel.hasLoadedSelectedProfile, let followError = viewModel.followErrorMessage {
                    Label("Follow change failed: \(followError)", systemImage: "exclamationmark.triangle")
                        .font(AppTypography.body)
                        .foregroundStyle(theme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                }
                if viewModel.isLoading {
                    profileLoadingPanel
                } else if let errorMessage = viewModel.errorMessage {
                    errorPanel(errorMessage)
                } else if viewModel.sendsCount == 0 {
                    journalEmptyState
                    historySection
                } else {
                    pointsPanel
                    highlightsSection
                    historySection
                    leaderboardSection
                }
                if viewModel.hasLoadedSelectedProfile, let countError = viewModel.followCountsRefreshErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Follow updated, but counts could not refresh: \(countError)", systemImage: "arrow.clockwise.circle")
                            .font(AppTypography.body)
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Retry count refresh") { Task { await viewModel.retryFollowCounts() } }
                            .buttonStyle(BoardedButtonStyle(.secondary))
                    }
                    .accessibilityElement(children: .contain)
                }
                settingsRow
            }
            .padding(theme.pagePadding)
            .padding(.bottom, AppSpacing.space64 + AppSpacing.space48)
            .frame(maxWidth: AppLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppSpacing.space64 + AppSpacing.space48)
        }
        .boardedPageBackground()
        .task(id: session.userId) {
            viewModel.setCurrentUserID(session.userId)
            await viewModel.load(userID: session.userId)
        }
        .task(id: profileRefreshID) {
            guard profileRefreshID > 0 else { return }
            await viewModel.refreshCurrentProfile()
        }
        .refreshable {
            await viewModel.load(userID: session.userId)
        }
        .sheet(isPresented: $isEditPresented) {
            EditProfileSheet(
                fullName: $editFullName,
                username: $editUsername,
                bio: $editBio,
                onSave: {
                    try await session.updateProfile(fullName: editFullName, username: editUsername, bio: editBio)
                    guard !Task.isCancelled else { return }
                    viewModel.syncProfileFromSession(currentUserID: session.userId, profile: session.profile)
                    isEditPresented = false
                },
                onCancel: { isEditPresented = false }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.space16) {
                    profileMark
                    profileIdentity
                    Spacer(minLength: 0)
                    editProfileButton
                }
                VStack(alignment: .leading, spacing: AppSpacing.space12) {
                    HStack(alignment: .top, spacing: AppSpacing.space16) {
                        profileMark
                        profileIdentity
                    }
                    editProfileButton
                }
            }
            if viewModel.hasLoadedSelectedProfile {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.space20) { followFact("Followers", count: viewModel.followCounts.followerCount); followFact("Following", count: viewModel.followCounts.followingCount) }
                    VStack(alignment: .leading, spacing: AppSpacing.space8) { followFact("Followers", count: viewModel.followCounts.followerCount); followFact("Following", count: viewModel.followCounts.followingCount) }
                }
                if let currentUserID = session.userId, viewModel.selectedUserID != currentUserID {
                    Button {
                        Task { await viewModel.setFollowing(!viewModel.isFollowing, currentUserID: currentUserID) }
                    } label: {
                        HStack(spacing: AppSpacing.space8) {
                            if viewModel.isUpdatingFollow { ProgressView().accessibilityHidden(true) }
                            Image(systemName: viewModel.isFollowing ? "person.badge.minus" : "person.badge.plus").accessibilityHidden(true)
                            Text(viewModel.isFollowing ? "Unfollow" : "Follow")
                        }
                    }
                    .buttonStyle(BoardedButtonStyle(viewModel.isFollowing ? .secondary : .primary))
                    .disabled(viewModel.isUpdatingFollow)
                    .accessibilityHint(viewModel.isFollowing ? "Stops showing this climber’s routes in Activity" : "Shows this climber’s public routes in Activity")
                }
            }
        }
        .boardedPanel()
    }

    private var profileMark: some View {
        Circle()
            .fill(theme.primary.opacity(0.15))
            .frame(width: AppSpacing.space64, height: AppSpacing.space64)
            .overlay(Image(systemName: "figure.climbing").font(.title2).foregroundStyle(theme.primary))
            .accessibilityHidden(true)
    }

    private var profileIdentity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            if viewModel.isLoading {
                Text("Loading profile…").font(AppTypography.title).foregroundStyle(theme.primaryText)
                ProgressView().accessibilityLabel("Loading profile")
            } else if viewModel.errorMessage != nil {
                Text("Profile unavailable").font(AppTypography.title).foregroundStyle(theme.primaryText)
                Text("This climber’s profile could not be loaded.").font(AppTypography.body).foregroundStyle(theme.secondaryText)
            } else {
                Text(viewModel.profile?.displayName ?? (viewModel.selectedUserID == session.userId ? session.profile?.displayName : nil) ?? session.userEmail ?? "Guest Climber")
                    .font(AppTypography.display)
                    .foregroundStyle(theme.primaryText)
                if let username = viewModel.profile?.username ?? (viewModel.selectedUserID == session.userId ? session.profile?.username : nil), !username.isEmpty {
                    Text("@\(username)").font(AppTypography.label).foregroundStyle(theme.primary)
                }
                Text(viewModel.profile?.bio ?? (viewModel.selectedUserID == session.userId ? session.profile?.bio : nil) ?? (session.userId == nil ? "Sign in to track your climbs." : "Your climbing profile"))
                    .font(AppTypography.body)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var editProfileButton: some View {
        if viewModel.hasLoadedSelectedProfile, session.userId != nil, viewModel.selectedUserID == session.userId {
            Button {
                editFullName = session.profile?.fullName ?? ""
                editUsername = session.profile?.username ?? ""
                editBio = session.profile?.bio ?? ""
                isEditPresented = true
            } label: {
                Label("Edit profile", systemImage: "square.and.pencil")
                    .frame(minHeight: AppLayout.minimumControlHeight)
            }
            .buttonStyle(BoardedButtonStyle(.secondary))
        }
    }

    private func followFact(_ label: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.space4) {
            Text(count.formatted()).font(AppTypography.display).foregroundStyle(theme.primaryText)
            Text(label).font(AppTypography.caption).foregroundStyle(theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var profileLoadingPanel: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading profile details…")
                .font(AppTypography.body)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardedPanel()
        .accessibilityElement(children: .combine)
    }


    private var journalEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space16) {
            Label("YOUR CLIMBING LINE", systemImage: "point.3.connected.trianglepath.dotted")
                .font(AppTypography.caption)
                .foregroundStyle(theme.primary)
            Text("Your journal starts at the wall.")
                .font(AppTypography.display)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Log a completed climb to begin a truthful record of progression, volume, and memorable sends.")
                .font(AppTypography.body)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .boardedPanel()
        .accessibilityElement(children: .combine)
    }
    private var pointsPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Climbing facts", subtitle: "A concise record of completed climbs")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.space8) {
                    statValue(title: "Sends", value: viewModel.sendsCount.formatted())
                    statValue(title: "Flashes", value: viewModel.flashedCount.formatted())
                    statValue(title: "Highest", value: viewModel.highestGrade ?? "—")
                }
                VStack(alignment: .leading, spacing: AppSpacing.space12) {
                    statValue(title: "Sends", value: viewModel.sendsCount.formatted())
                    statValue(title: "Flashes", value: viewModel.flashedCount.formatted())
                    statValue(title: "Highest", value: viewModel.highestGrade ?? "—")
                }
            }
        }
        .boardedPanel()
    }

    private func statValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Text(value)
                .font(AppTypography.display)
                .foregroundStyle(theme.primaryText)
                .minimumScaleFactor(0.8)
            Text(title).font(AppTypography.caption).foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BoardedSectionHeading(title: "Leaderboard", subtitle: "Name and account ID break ties when points are unavailable")
            if viewModel.leaderboard.isEmpty {
                emptyRow(icon: "trophy", text: "No public leaderboard data yet.")
            } else {
                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 12) {
                        if index > 0 {
                            theme.primaryText.opacity(0.12).frame(height: 1)
                        }
                        Button {
                            guard let id = UUID(uuidString: entry.id) else { return }
                            Task { await viewModel.selectAccount(userID: id) }
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)").font(AppTypography.headline).foregroundStyle(theme.primary).frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.displayName).font(AppTypography.body).foregroundStyle(theme.primaryText).lineLimit(1)
                                    Text("\(entry.sendsCount) sends • best \(entry.highestGrade ?? "—")")
                                        .font(AppTypography.caption).foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                                Text(entry.points.map { "\($0) pts" } ?? "—")
                                    .font(AppTypography.headline).foregroundStyle(theme.primaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let current = session.userId, viewModel.selectedUserID != current {
                Button("My Profile") { Task { await viewModel.myProfile(currentUserID: current) } }
                    .buttonStyle(BoardedButtonStyle(.secondary))
            }
        }
        .boardedPanel()
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BoardedSectionHeading(title: "Previous Highlights", subtitle: "Your strongest and longest completed climbs")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.space12) {
                    highlightCard(title: "Best Climb", climb: viewModel.highlights.bestClimb, icon: "star.fill")
                    highlightCard(title: "Longest Project", climb: viewModel.highlights.longestProject, icon: "flag.fill")
                }
                VStack(spacing: AppSpacing.space12) {
                    highlightCard(title: "Best Climb", climb: viewModel.highlights.bestClimb, icon: "star.fill")
                    highlightCard(title: "Longest Project", climb: viewModel.highlights.longestProject, icon: "flag.fill")
                }
            }
        }
        .boardedPanel()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BoardedSectionHeading(title: "Previous Climbs", subtitle: viewModel.selectedUserID == session.userId ? "Newest first" : "Selected climber")
            if viewModel.isLoading && viewModel.previousClimbs.isEmpty {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.previousClimbs.isEmpty {
                emptyRow(icon: "checkmark.circle", text: viewModel.selectedUserID == nil ? "Sign in to see climbing history." : "No public climbing history.")
            } else {
                ForEach(Array(viewModel.previousClimbs.enumerated()), id: \.element.id) { index, climb in
                    VStack(alignment: .leading, spacing: 12) {
                        if index > 0 {
                            theme.primaryText.opacity(0.12).frame(height: 1)
                        }
                        Button {
                            if let route = climb.route {
                                routeDetailsViewModel.upsertRoute(route)
                                presentRoute(route)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: climb.flashed ? "bolt.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(climb.flashed ? theme.accent : theme.secondaryText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(climb.routeName).font(AppTypography.body).foregroundStyle(theme.primaryText).lineLimit(1)
                                    Text("\(climb.grade ?? "Unknown grade") • \(formattedDate(climb.completedAt))")
                                        .font(AppTypography.caption).foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                                if !climb.isAvailable {
                                    Text("Unavailable").font(AppTypography.caption).foregroundStyle(theme.secondaryText)
                                } else {
                                    Image(systemName: "chevron.right").foregroundStyle(theme.secondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!climb.isAvailable)
                    }
                }
            }
        }
        .boardedPanel()
    }

    private func highlightCard(title: String, climb: ProfileClimbHistoryItem?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            Label(title, systemImage: icon).font(AppTypography.caption).foregroundStyle(theme.secondaryText)
            Text(climb?.routeName ?? "No data").font(AppTypography.headline).foregroundStyle(theme.primaryText)
            if let climb {
                Text(climb.grade ?? "Unknown grade").font(AppTypography.display).foregroundStyle(theme.primary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: AppLayout.minimumControlHeight, alignment: .leading)
        .padding(AppSpacing.space8)
        .accessibilityElement(children: .combine)
    }

    private var settingsRow: some View {
        NavigationLink { SettingsView() } label: {
            HStack {
                Image(systemName: "gearshape").foregroundStyle(theme.secondaryText)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings").font(AppTypography.headline).foregroundStyle(theme.primaryText)
                    Text("Account, data, and appearance").font(AppTypography.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .boardedPanel()
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Unable to load profile", systemImage: "exclamationmark.triangle")
                .font(AppTypography.headline).foregroundStyle(theme.primaryText)
            Text(message).font(AppTypography.body).foregroundStyle(theme.secondaryText)
            Button("Retry") { Task { await viewModel.retry() } }
                .buttonStyle(BoardedButtonStyle())
        }
        .boardedPanel()
    }

    private func emptyRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon).font(AppTypography.body).foregroundStyle(theme.secondaryText)
    }

    private func presentRoute(_ route: Route) {
        routeDetailPresenter.present(
            RouteDetailPresentation(
                route: route,
                routesViewModel: routeDetailsViewModel,
                onRouteChanged: { updatedRoute in
                    routeDetailsViewModel.upsertRoute(updatedRoute)
                    profileRefreshID += 1
                },
                onRouteDeleted: { _ in
                    profileRefreshID += 1
                }
            )
        )
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Date unavailable" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct EditProfileSheet: View {
    @Binding var fullName: String
    @Binding var username: String
    @Binding var bio: String
    let onSave: () async throws -> Void
    let onCancel: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Full name", text: $fullName)
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Section("Bio") { TextEditor(text: $bio).frame(minHeight: 100) }
                if let errorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        HStack(spacing: 4) {
                            if isSaving {
                                ProgressView()
                            }
                            Text(isSaving ? "Saving..." : "Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onSave()
                if Task.isCancelled {
                    isSaving = false
                    return
                }
                isSaving = false
            } catch is CancellationError {
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(repository: MockProfileRepository())
            .environmentObject(AppSession())
            .environmentObject(RouteDetailPresenter())
    }
}

struct ActivityView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var routeDetailPresenter: RouteDetailPresenter
    @StateObject private var viewModel = FollowingFeedViewModel(
        profileRepository: AppServices.profileRepository,
        routesRepository: AppServices.routesRepository
    )
    @StateObject private var routeViewModel = RoutesViewModel(repository: AppServices.routesRepository)

    var body: some View {
        Group {
            if session.userId == nil {
                EmptyStateView(title: "Follow the line", subtitle: "Sign in, follow climbers, and their newest public routes will appear here.")
            } else if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading following activity…").font(AppTypography.body)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Activity is offline or unavailable", systemImage: "wifi.exclamationmark")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColor.warning)
                    Text(error).font(AppTypography.body).foregroundStyle(AppColor.muted)
                    Text("Saved routes and climb logging remain available.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.text)
                    Button("Try Again") { Task { await viewModel.load(userID: session.userId) } }
                        .buttonStyle(BoardedButtonStyle())
                }
                .boardedPanel()
                .padding(20)
            } else if viewModel.items.isEmpty {
                EmptyStateView(title: "No activity yet", subtitle: "Follow a climber from Profile to see their newest public routes.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.items) { item in
                            activityRow(item)
                        }
                        if let paginationError = viewModel.paginationErrorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Couldn’t load more activity", systemImage: "exclamationmark.triangle")
                                    .font(AppTypography.headline)
                                    .foregroundStyle(AppColor.warning)
                                Text(paginationError)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Try loading more again") {
                                    Task { await viewModel.loadMore(userID: session.userId) }
                                }
                                .buttonStyle(BoardedButtonStyle(.secondary))
                                .disabled(viewModel.isLoadingMore)
                            }
                            .boardedPanel()
                            .accessibilityElement(children: .contain)
                        }
                        if viewModel.canLoadMore {
                            Button {
                                Task { await viewModel.loadMore(userID: session.userId) }
                            } label: {
                                if viewModel.isLoadingMore {
                                    Label("Loading more activity", systemImage: "hourglass")
                                } else {
                                    Label("Load more", systemImage: "arrow.down")
                                }
                            }
                            .buttonStyle(BoardedButtonStyle(.secondary))
                            .disabled(viewModel.isLoadingMore)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await viewModel.load(userID: session.userId) }
            }
        }
        .foregroundStyle(AppColor.text)
        .boardedPageBackground()
        .navigationTitle("Activity")
        .task(id: session.userId) { await viewModel.load(userID: session.userId) }
    }

    private func activityRow(_ item: FollowingFeedItem) -> some View {
        let route = viewModel.routesByID[item.routeId]
        return Button {
            guard let route else { return }
            routeViewModel.upsertRoute(route)
            routeDetailPresenter.present(RouteDetailPresentation(
                route: route,
                routesViewModel: routeViewModel,
                onRouteChanged: { routeViewModel.upsertRoute($0) },
                onRouteDeleted: { deletedID in routeViewModel.routes.removeAll { $0.id == deletedID } }
            ))
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: route == nil ? "point.3.filled.connected.trianglepath.dotted" : "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(route == nil ? AppColor.tertiaryText : AppColor.primary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.authorUsername.map { "@\($0)" } ?? "Climber")
                        .font(AppTypography.label)
                        .foregroundStyle(AppColor.muted)
                    Text(route?.gradeV ?? "Route")
                        .font(AppTypography.display)
                        .foregroundStyle(AppColor.text)
                    Text(route?.name ?? "Route details unavailable")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.text)
                    Text(item.activityAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
                if route != nil { Image(systemName: "chevron.right").foregroundStyle(AppColor.muted) }
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(route == nil)
        .boardedPanel()
        .accessibilityElement(children: .combine)
        .accessibilityHint(route == nil ? "Route details are unavailable" : "Opens route details")
    }
}
