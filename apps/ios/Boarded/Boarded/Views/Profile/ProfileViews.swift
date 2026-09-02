import SwiftUI
import UIKit

@MainActor
final class ProductProfileViewModel: ObservableObject {
    @Published var statistics = ProfileStatistics.empty
    @Published var posts: [SessionFeedItem] = []
    @Published var loading = true
    @Published var error: String?
    private var hasLoaded = false

    var isEmpty: Bool {
        hasLoaded && statistics.sessionCount == 0 && statistics.attemptCount == 0 && posts.isEmpty
    }

    func load(userID: UUID) async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let stats = AppServices.profileRepository.fetchStatistics(userID: userID)
            async let page = AppServices.feedRepository.fetchFeed(cursor: nil, authorFilter: userID, pageSize: 20)
            let (loadedStats, loadedPage) = try await (stats, page)
            statistics = loadedStats
            posts = loadedPage.items
            hasLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = ProductProfileViewModel()
    @State private var edit = false

    var body: some View {
        Group {
            if let profile = session.profile, let id = session.userId {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                        header(profile)
                        profileContent(userID: id)
                        ProfileSettingsView(editProfile: { edit = true })
                    }
                    .padding(AppLayout.screenMargin)
                    .boardedContentWidth()
                    .frame(maxWidth: .infinity)
                }
                .task { await model.load(userID: id) }
            } else {
                AuthenticationView(showsDismissButton: false)
            }
        }
        .navigationTitle("Profile")
        .boardedPageBackground()
        .sheet(isPresented: $edit) { EditProfileView() }
    }

    private func header(_ profile: Profile) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.space16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.space16))

        return layout {
            ProfileIdentityImage(profile: profile) {
                edit = true
            }
            VStack(alignment: .leading, spacing: AppSpacing.space4) {
                Text(profile.displayName)
                    .font(AppTypography.titleM)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let username = profile.username {
                    Text("@\(username)").foregroundStyle(AppColor.textSecondary)
                }
                if let home = profile.homeArea {
                    Label(home, systemImage: "mappin")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardedPanel(padding: AppLayout.featureCardPadding)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func profileContent(userID: UUID) -> some View {
        if model.loading {
            VStack(alignment: .leading, spacing: AppSpacing.space12) {
                ProgressView("Loading profile…")
                BoardedFeedCardSkeleton()
            }
            .accessibilityIdentifier("profile-loading")
        } else if let error = model.error {
            BoardedInlineError(message: error) { Task { await model.load(userID: userID) } }
                .accessibilityIdentifier("profile-error")
        } else if model.isEmpty {
            BoardedRouteLineEmptyState(
                title: "Your journal starts here",
                message: "Log a session and share it to build your climbing journal."
            )
            .accessibilityIdentifier("profile-empty")
        } else {
            milestone
            tiles
            best
            ownPosts
        }
    }

    private var milestone: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            BoardedEyebrow(text: "Personal Best")
            Text(model.statistics.bestGrade?.label ?? "Your first send starts here")
                .font(AppTypography.displayL)
                .foregroundStyle(model.statistics.bestGrade == nil ? AppColor.textPrimary : AppColor.accentDefault)
        }
        .boardedPanel(padding: AppLayout.featureCardPadding)
    }

    @ViewBuilder
    private var tiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.space12) {
                metricRow("Sessions", "\(model.statistics.sessionCount)", "calendar")
                metricRow("Sends", "\(model.statistics.sendCount)", "checkmark.circle")
                metricRow("Send rate", model.statistics.sendRate.map(BoardedFormat.percent) ?? "—", "chart.line.uptrend.xyaxis")
                metricRow("Attempts", "\(model.statistics.attemptCount)", "number")
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.space12) {
                tile("Sessions", "\(model.statistics.sessionCount)", "calendar")
                tile("Sends", "\(model.statistics.sendCount)", "checkmark.circle")
                tile("Send rate", model.statistics.sendRate.map(BoardedFormat.percent) ?? "—", "chart.line.uptrend.xyaxis")
                tile("Attempts", "\(model.statistics.attemptCount)", "number")
            }
        }
    }

    private func tile(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            Image(systemName: icon).foregroundStyle(AppColor.textSecondary)
            Text(value).font(AppTypography.dataM)
            Text(label).font(AppTypography.labelM).foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardedPanel()
    }

    private func metricRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.space12) {
            Label(label, systemImage: icon)
                .font(AppTypography.labelL)
                .foregroundStyle(AppColor.textSecondary)
            Spacer(minLength: AppSpacing.space8)
            Text(value)
                .font(AppTypography.dataM)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardedPanel()
        .accessibilityElement(children: .combine)
    }

    private var best: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Best by grade", subtitle: "Highest completed grade in your journal.")
            if let grade = model.statistics.bestGrade {
                HStack {
                    Text(grade.label).font(AppTypography.displayS)
                    Spacer()
                    Text(grade.system.title).font(AppTypography.labelM).foregroundStyle(AppColor.textSecondary)
                }
            } else {
                Text("No completed grades yet.").foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var ownPosts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            BoardedSectionHeading(title: "Session journal")
            if model.posts.isEmpty {
                Text("Share a completed session with a photo to add it to your journal.")
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                ForEach(model.posts) { SendPostCard(item: $0, showsActions: false) }
            }
        }
    }
}

private struct ProfileIdentityImage: View {
    let profile: Profile
    let edit: () -> Void

    var body: some View {
        Group {
            if let avatar = profile.avatarUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: avatar) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .overlay(alignment: .bottomTrailing) {
                                BoardedPhotoHUD {
                                    Button(action: edit) {
                                        Image(systemName: "pencil")
                                            .foregroundStyle(AppColor.textPrimary)
                                            .frame(
                                                minWidth: AppLayout.minimumTarget,
                                                minHeight: AppLayout.minimumTarget
                                            )
                                    }
                                    .accessibilityLabel("Edit profile")
                                }
                            }
                    case .empty:
                        BoardedSkeleton(shape: AppRadius.card())
                    case .failure:
                        BoardedAvatar(name: profile.displayName, size: 96)
                    @unknown default:
                        BoardedAvatar(name: profile.displayName, size: 96)
                    }
                }
            } else {
                BoardedAvatar(name: profile.displayName, size: 96)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(AppRadius.card())
        .overlay {
            AppRadius.card()
                .stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline)
        }
        .accessibilityLabel("Profile photo of \(profile.displayName)")
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.openURL) private var openURL
    @AppStorage("preferred-grade-system") private var preferredGradeSystem = GradeSystem.vScale.rawValue
    @AppStorage("preferred-distance-unit") private var preferredDistanceUnit = "metric"
    let editProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space24) {
            BoardedSectionHeading(title: "Settings")
            settingsGroup("Account") {
                settingsButton("Edit Profile", systemImage: "person.crop.circle", action: editProfile)
            }
            settingsGroup("Climbing preferences") {
                Picker("Grade system", selection: $preferredGradeSystem) {
                    ForEach(GradeSystem.allCases, id: \.rawValue) { system in Text(system.title).tag(system.rawValue) }
                }
                Picker("Units", selection: $preferredDistanceUnit) {
                    Text("Metric").tag("metric")
                    Text("Imperial").tag("imperial")
                }
            }
            settingsGroup("Accessibility") {
                Text("Boarded follows your system text size, Reduce Motion, VoiceOver, and contrast settings.")
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                settingsButton("Open System Accessibility Settings", systemImage: "accessibility") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            settingsGroup("About") {
                LabeledContent("App", value: "Boarded")
                LabeledContent("Audience", value: "Public posts and meetups")
            }
            Button(role: .destructive) { Task { await session.signOut() } } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, minHeight: AppLayout.listRowMinHeight, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("profile-settings")
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            Text(title).font(AppTypography.labelM).foregroundStyle(AppColor.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardedPanel()
    }

    private func settingsButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: AppLayout.minimumTarget, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var home = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.space16) {
                    BoardedTextField(label: "Display Name", prompt: "Your name", text: $name)
                    BoardedTextField(label: "Username", prompt: "Username", text: $username, autocapitalization: .never)
                    BoardedTextEditor(label: "Bio", prompt: "A short climbing note", text: $bio)
                    BoardedTextField(label: "Home Area", prompt: "Gym or climbing area", text: $home)
                    if let error { Text(error).foregroundStyle(AppColor.danger) }
                    BoardedPrimaryButton(title: "Save") { save() }
                }
                .padding(AppLayout.screenMargin)
            }
            .navigationTitle("Edit Profile")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .boardedPageBackground()
            .onAppear {
                name = session.profile?.fullName ?? ""
                username = session.profile?.username ?? ""
                bio = session.profile?.bio ?? ""
                home = session.profile?.homeArea ?? ""
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanUsername.isEmpty else {
            error = "Display name and username are required."
            return
        }
        Task {
            do {
                try await session.updateProfile(fullName: cleanName, username: cleanUsername, bio: bio, homeArea: home)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
