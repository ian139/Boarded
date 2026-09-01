import SwiftUI

/// Environment-injected authentication context. Read-only screens check
/// `isAuthenticated`; mutations call `requestAuthentication` to present the
/// authentication sheet instead of failing silently.
struct BoardedAuthContext {
    let isAuthenticated: Bool
    let requestAuthentication: () -> Void

    static let guest = BoardedAuthContext(isAuthenticated: false, requestAuthentication: {})
}

private struct BoardedAuthContextKey: EnvironmentKey {
    static let defaultValue = BoardedAuthContext.guest
}

extension EnvironmentValues {
    var boardedAuth: BoardedAuthContext {
        get { self[BoardedAuthContextKey.self] }
        set { self[BoardedAuthContextKey.self] = newValue }
    }
}

/// Sign in and account creation. Used both inline (guest Log/Profile tabs) and
/// as a sheet when a guest attempts a mutation. Surfaces configuration errors
/// (missing Supabase configuration) inline with recovery guidance.
struct AuthenticationView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case signUp = "Create Account"
        var id: String { rawValue }
    }

    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var validationError: String?

    var showsDismissButton = true

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDisplayName: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.space24) {
                header
                modePicker
                fields
                if let errorText = currentError {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.labelL)
                        .foregroundStyle(AppColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("auth-error")
                }
                BoardedPrimaryButton(title: submitTitle, action: submit)
                    .disabled(session.isLoading)
                    .accessibilityIdentifier("auth-submit")
                if session.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Signing in")
                }
            }
            .padding(AppLayout.screenMargin)
            .boardedContentWidth()
            .frame(maxWidth: .infinity)
        }
        .boardedPageBackground()
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("auth-close")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            Text("Boarded")
                .font(AppTypography.displayM)
                .foregroundStyle(AppColor.textPrimary)
            Text(mode == .signIn
                 ? "Sign in to log sessions and share sends."
                 : "Create an account to keep a climbing journal.")
                .font(AppTypography.bodyL)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        HStack(spacing: AppSpacing.space12) {
            ForEach(Mode.allCases) { option in
                BoardedFilterControl(title: option.rawValue, isSelected: mode == option) {
                    mode = option
                    validationError = nil
                }
                .accessibilityIdentifier(option == .signIn ? "auth-mode-signin" : "auth-mode-signup")
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: AppSpacing.space16) {
            BoardedTextField(
                label: "Email",
                prompt: "you@example.com",
                text: $email,
                autocapitalization: .never,
                contentType: .emailAddress,
                keyboardType: .emailAddress
            )
            .accessibilityIdentifier("auth-email")
            BoardedTextField(
                label: "Password",
                prompt: "At least 6 characters",
                text: $password,
                isSecure: true,
                contentType: mode == .signIn ? .password : .newPassword
            )
            .accessibilityIdentifier("auth-password")
            if mode == .signUp {
                ProfileSetupFields(username: $username, displayName: $displayName)
            }
        }
    }

    private var submitTitle: String {
        if session.isLoading { return mode == .signIn ? "Signing In…" : "Creating Account…" }
        return mode == .signIn ? "Sign In" : "Create Account"
    }

    private var currentError: String? {
        validationError ?? session.errorMessage
    }

    private func submit() {
        validationError = nil
        guard trimmedEmail.contains("@") else {
            validationError = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            validationError = "Passwords need at least 6 characters."
            return
        }
        if mode == .signUp {
            guard !trimmedUsername.isEmpty else {
                validationError = "Choose a username."
                return
            }
            guard !trimmedDisplayName.isEmpty else {
                validationError = "Enter a display name."
                return
            }
        }
        Task {
            if mode == .signIn {
                await session.signIn(email: trimmedEmail, password: password)
            } else {
                await session.signUp(
                    email: trimmedEmail,
                    password: password,
                    username: trimmedUsername,
                    displayName: trimmedDisplayName
                )
            }
            if session.errorMessage == nil, session.userId != nil {
                dismiss()
            }
        }
    }
}

/// Username and display name collection shared by signup and the profile setup
/// gate. Both fields are required.
struct ProfileSetupFields: View {
    @Binding var username: String
    @Binding var displayName: String

    var body: some View {
        VStack(spacing: AppSpacing.space16) {
            BoardedTextField(
                label: "Username",
                prompt: "Other climbers find you by this name",
                text: $username,
                autocapitalization: .never
            )
            .accessibilityIdentifier("profile-username")
            BoardedTextField(
                label: "Display Name",
                prompt: "Shown on your posts and profile",
                text: $displayName
            )
            .accessibilityIdentifier("profile-display-name")
        }
    }
}

/// Gate shown when a signed-in account has no profile row yet (legacy auth
/// accounts created before profile provisioning). Profile-dependent UI is
/// blocked until the profile exists.
struct ProfileSetupView: View {
    @EnvironmentObject private var session: AppSession
    @State private var username = ""
    @State private var displayName = ""
    @State private var validationError: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.space24) {
                VStack(alignment: .leading, spacing: AppSpacing.space8) {
                    BoardedEyebrow(text: "Profile Setup")
                    Text("Set up your profile")
                        .font(AppTypography.titleL)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Choose the name other climbers see. You can change these later in settings.")
                        .font(AppTypography.bodyL)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ProfileSetupFields(username: $username, displayName: $displayName)
                if let errorText = validationError ?? session.errorMessage {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(AppTypography.labelL)
                        .foregroundStyle(AppColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("profile-setup-error")
                }
                BoardedPrimaryButton(title: isSaving ? "Saving…" : "Save Profile", action: save)
                    .disabled(isSaving)
                    .accessibilityIdentifier("profile-setup-save")
            }
            .padding(AppLayout.screenMargin)
            .boardedContentWidth()
            .frame(maxWidth: .infinity)
        }
        .boardedPageBackground()
        .accessibilityElement(children: .contain)
    }

    private func save() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            validationError = "Choose a username."
            return
        }
        guard !trimmedDisplayName.isEmpty else {
            validationError = "Enter a display name."
            return
        }
        validationError = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await session.completeProfileSetup(
                    username: trimmedUsername,
                    displayName: trimmedDisplayName,
                    homeArea: nil
                )
            } catch {
                validationError = error.localizedDescription
            }
        }
    }
}
