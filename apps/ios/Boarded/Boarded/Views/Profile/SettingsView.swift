import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var session: AppSession

    private var theme: BoardedTheme {
        BoardedTheme()
    }

    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.dark.rawValue
    @StateObject private var metrics = ProfileViewModel(repository: AppServices.profileRepository)
    @StateObject private var wallsViewModel = WallsViewModel(repository: AppServices.wallsRepository)
    @State private var isWallPickerPresented = false

    private var appearanceMode: AppAppearanceMode { .dark }

    var body: some View {
        List {
            accountSection
            appearanceSection
            climbingPreferencesSection
            privacyAccessibilitySection
            wallsSection
            dataSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .environment(\.colorScheme, .dark)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: AppSpacing.space64 + AppSpacing.space48)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await metrics.load(userID: session.userId)
            await wallsViewModel.load(userId: session.userId)
        }
        .sheet(isPresented: $isWallPickerPresented) {
            WallPickerView(viewModel: wallsViewModel, navigationTitle: "Manage Walls")
                .environmentObject(session)
        }
    }

    private var accountSection: some View {
        Section {
            NavigationLink {
                AccountAccessView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.space4) {
                        Text("Account access").font(AppTypography.body).foregroundStyle(theme.primaryText)
                        Text(accountSubtitle).font(AppTypography.caption).foregroundStyle(theme.secondaryText)
                    }
                } icon: {
                    Image(systemName: session.userId == nil ? "person.badge.key" : "person.crop.circle.badge.checkmark")
                        .foregroundStyle(theme.primary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: AppLayout.minimumControlHeight)
            }
            .accessibilityLabel("Account access, \(accountSubtitle)")
            .accessibilityHint("Opens account and sign-in settings")
        } header: {
            Text("Account")
        }
        .listRowBackground(theme.panelBackground)
    }

    private var accountSubtitle: String {
        if let fullName = session.profile?.fullName, !fullName.isEmpty {
            return fullName
        }
        if let email = session.userEmail, !email.isEmpty {
            return email
        }
        return "Log in or create an account"
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Sync", value: syncStatus)
            LabeledContent("Routes", value: metrics.routesCount.formatted())
            LabeledContent("Sends", value: metrics.sendsCount.formatted())
            LabeledContent("Likes", value: metrics.likesCount.formatted())
        } header: {
            Text("Your climbing data")
        } footer: {
            Text("Counts reflect the climbing journal stored for this account.")
        }
        .foregroundStyle(theme.primaryText)
        .listRowBackground(theme.panelBackground)
    }

    private var appearanceSection: some View {
        Section {
            LabeledContent {
                Text("Dark")
                    .foregroundStyle(theme.primaryText)
            } label: {
                Label("Appearance", systemImage: "moon.fill")
                    .foregroundStyle(theme.primaryText)
            }
            .frame(minHeight: AppLayout.minimumControlHeight)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Appearance, dark only")

            .accessibilityIdentifier("Appearance setting")
            .accessibilityValue("Dark")
            LabeledContent("Version", value: appVersion)
                .foregroundStyle(theme.secondaryText)
        } header: {
            Text("Display")
        } footer: {
            Text("Boarded always uses its high-contrast dark field. System Reduce Motion and Reduce Transparency settings are respected.")
        }
        .listRowBackground(theme.panelBackground)
    }

    private var climbingPreferencesSection: some View {
        Section {
            LabeledContent {
                Text("Shown per route")
                    .foregroundStyle(theme.secondaryText)
            } label: {
                Label("Grades & units", systemImage: "ruler")
                    .foregroundStyle(theme.primaryText)
            }
            .frame(minHeight: AppLayout.minimumControlHeight)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Grades and units, shown as supplied by each climbing route")
        } header: {
            Text("Climbing")
        } footer: {
            Text("Boarded preserves each route’s grading system and recorded measurements; there is no separate conversion preference yet.")
        }
        .listRowBackground(theme.panelBackground)
    }

    private var privacyAccessibilitySection: some View {
        Section {
            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                Label("Privacy", systemImage: "hand.raised")
                    .frame(minHeight: AppLayout.minimumControlHeight)
            }
            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                Label("Accessibility", systemImage: "accessibility")
                    .frame(minHeight: AppLayout.minimumControlHeight)
            }
        } header: {
            Text("System settings")
        } footer: {
            Text("Manage Boarded permissions in Settings. Text size, VoiceOver, Reduce Motion, and Reduce Transparency follow your iPhone or iPad settings.")
        }
        .foregroundStyle(theme.primaryText)
        .listRowBackground(theme.panelBackground)
    }

    private var appearanceSubtitle: String {
        "Boarded uses its high-contrast dark field"
    }

    private var wallsSection: some View {
        Section {
            Button {
                isWallPickerPresented = true
            } label: {
                HStack {
                    Label("Manage walls", systemImage: "square.3.layers.3d")
                    Spacer()
                    Text(wallsViewModel.walls.count.formatted())
                        .foregroundStyle(theme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: AppLayout.minimumControlHeight)
                .contentShape(Rectangle())
            }
            .foregroundStyle(theme.primaryText)
            .accessibilityIdentifier("Manage Walls")
            .accessibilityLabel("Manage walls, \(wallsViewModel.walls.count.formatted()) walls")
            .accessibilityHint("Opens the wall picker")
        } header: {
            Text("Climbing walls")
        }
        .listRowBackground(theme.panelBackground)
    }

    private var syncStatus: String {
        SupabaseClientProvider.client == nil ? "On-device only" : "Ready"
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

private enum AuthMode {
    case signIn
    case signUp
}

private struct AccountAccessView: View {
    @EnvironmentObject var session: AppSession

    private var theme: BoardedTheme {
        BoardedTheme()
    }

    @State private var email = ""
    @State private var password = ""
    @State private var authMode: AuthMode = .signIn

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if session.userId == nil {
                        signedOutContent
                    } else {
                        signedInContent
                    }
                }
                .padding(AppLayout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: AppLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(session.userId == nil ? "Log In" : "Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(authMode == .signIn ? "Welcome back" : "Create account")
                    .font(AppTypography.title)
                    .foregroundColor(theme.primaryText)
                Text(authMode == .signIn ? "Log in to sync climbs and comments." : "Create an account to save routes to Supabase.")
                    .font(AppTypography.body)
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.bottom, 4)

            AccountTextField(
                title: "Email",
                icon: "envelope",
                placeholder: "you@example.com",
                text: $email,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                autocorrectionDisabled: true
            )

            AccountSecureField(password: $password)

            if let error = session.errorMessage, !error.isEmpty {
                Text(error)
                    .font(AppTypography.label)
                    .foregroundColor(theme.destructive)
                    .padding(.top, 2)
            }

            Button {
                Task {
                    if authMode == .signIn {
                        await session.signIn(email: email, password: password)
                    } else {
                        await session.signUp(email: email, password: password)
                    }
                }
            } label: {
                HStack {
                    if session.isLoading {
                        ProgressView()
                            .tint(theme.actionForeground)
                    }
                    Text(authMode == .signIn ? "Log In" : "Create Account")
                }
                .font(AppTypography.headline)
                .foregroundColor(theme.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            }
            .disabled(email.isEmpty || password.isEmpty || session.isLoading)
            .opacity(email.isEmpty || password.isEmpty || session.isLoading ? 0.55 : 1)

            Button {
                authMode = authMode == .signIn ? .signUp : .signIn
            } label: {
                Text(authMode == .signIn ? "Need an account? Create one" : "Already have an account? Log in")
                    .font(AppTypography.label)
                    .foregroundColor(theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding(14)
        .background(theme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                .stroke(theme.border.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(theme.primary.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(theme.primary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(AppTypography.headline)
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                    Text(session.userEmail ?? "Signed in")
                        .font(AppTypography.label)
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Button(role: .destructive) {
                Task { await session.signOut() }
            } label: {
                HStack {
                    if session.isLoading {
                        ProgressView()
                            .tint(theme.actionForeground)
                    }
                    Text("Log Out")
                }
                .font(AppTypography.headline)
                .foregroundColor(theme.actionForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.destructive)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
            }
            .disabled(session.isLoading)
            .opacity(session.isLoading ? 0.65 : 1)
        }
        .padding(14)
        .background(theme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                .stroke(theme.border.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
    }
}

private struct AccountTextField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String

    private var theme: BoardedTheme {
        BoardedTheme()
    }

    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.secondaryText)
                    .tracking(0.6)
                TextField(placeholder, text: $text)
                    .font(AppTypography.body)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
                    .foregroundColor(theme.primaryText)
            }
        }
        .padding(12)
        .background(theme.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
    }
}

private struct AccountSecureField: View {
    @Binding var password: String

    private var theme: BoardedTheme {
        BoardedTheme()
    }


    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: "lock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("PASSWORD")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.secondaryText)
                    .tracking(0.6)
                SecureField("password", text: $password)
                    .font(AppTypography.body)
                    .foregroundColor(theme.primaryText)
            }
        }
        .padding(12)
        .background(theme.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
    }
}
