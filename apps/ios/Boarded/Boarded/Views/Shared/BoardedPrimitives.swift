import SwiftUI

// MARK: - Loading

struct BoardedSkeleton<S: Shape>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    @State private var highlighted = false

    var body: some View {
        shape
            .fill(reduceTransparency ? AppColor.backgroundElevated : AppColor.surfaceCard)
            .overlay { shape.fill(AppColor.textPrimary.opacity(highlighted ? 0.10 : 0.03)) }
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { highlighted = true }
            }
    }
}

/// Skeleton shaped like a feed card: avatar row, grade block, media rectangle.
struct BoardedFeedCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space12) {
            HStack(spacing: AppSpacing.space12) {
                BoardedSkeleton(shape: Circle()).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: AppSpacing.space4) {
                    BoardedSkeleton(shape: AppRadius.control).frame(width: 140, height: 12)
                    BoardedSkeleton(shape: AppRadius.control).frame(width: 90, height: 10)
                }
            }
            BoardedSkeleton(shape: AppRadius.control).frame(width: 96, height: 40)
            BoardedSkeleton(shape: AppRadius.card()).frame(maxWidth: .infinity).frame(height: 180)
            BoardedSkeleton(shape: AppRadius.control).frame(width: 160, height: 12)
        }
        .boardedPanel()
        .accessibilityLabel("Loading")
    }
}

// MARK: - Empty states

/// Empty state: simplified route-line motif, serif headline, one sentence, one
/// useful action.
struct BoardedRouteLineEmptyState: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space16) {
            BoardedRouteLine()
                .frame(width: 120, height: 88)
            VStack(alignment: .leading, spacing: AppSpacing.space8) {
                Text(title)
                    .font(AppTypography.displayS)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(AppTypography.bodyL)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(BoardedButtonStyle(.secondary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardedPanel(padding: AppLayout.featureCardPadding)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Errors, sync, confirmation

struct BoardedInlineError: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.space12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(AppTypography.bodyM)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: AppSpacing.space8)
            Button("Retry", action: retry)
                .font(AppTypography.labelL)
                .foregroundStyle(AppColor.textPrimary)
                .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
                .accessibilityHint("Tries to load the content again")
        }
        .padding(.horizontal, AppSpacing.space16)
        .background(AppColor.danger.opacity(0.12), in: AppRadius.control)
    }
}

/// Persistent compact offline/sync banner. Logging always continues locally;
/// queued content is clearly marked and sync resumes automatically.
struct BoardedSyncBanner: View {
    let isOffline: Bool
    let state: SyncState
    let retry: () -> Void
    var body: some View {
        if isOffline || state != .synced {
            ViewThatFits(in: .horizontal) {
                bannerLayout(axis: .horizontal)
                bannerLayout(axis: .vertical)
            }
            .padding(.vertical, AppSpacing.space8)
            .padding(.horizontal, AppSpacing.space16)
            .foregroundStyle(AppColor.textPrimary)
            .background(AppColor.warning.opacity(0.14))
            .accessibilityElement(children: .contain)
        }
    }

    private func bannerLayout(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: AppSpacing.space12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.space8))
        return layout {
            Label(statusText, systemImage: statusSymbol)
                .font(AppTypography.labelM)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(statusText)
            Spacer(minLength: AppSpacing.space4)
            if isOffline || state == .failed || state == .queued {
                Button("Retry Sync", action: retry)
                    .font(AppTypography.labelL)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(minWidth: AppLayout.minimumTarget, minHeight: AppLayout.minimumTarget)
                    .accessibilityHint("Attempts to sync queued sessions")
            }
        }
    }

    private var statusText: String {
        if isOffline { return "Offline. Attempts stay safely on this device and are queued." }
        switch state {
        case .failed: return "Sync needs attention"
        case .syncing: return "Syncing attempts"
        case .queued: return "Attempts queued to sync"
        case .synced: return "Attempts synced"
        }
    }

    private var statusSymbol: String {
        if isOffline { return "wifi.slash" }
        return state == .failed ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath"
    }
}

struct BoardedSuccessConfirmation: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(AppTypography.labelL)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.space16)
            .frame(minHeight: AppLayout.minimumTarget)
            .background(AppColor.accentSoft, in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Form controls

/// Labeled text field with persistent label, focus ring, and inline error.
/// Never relies on placeholder-only labeling.
struct BoardedTextField: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var error: String? = nil
    var isSecure = false
    var autocapitalization: TextInputAutocapitalization = .words
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            Text(label)
                .font(AppTypography.labelM)
                .foregroundStyle(error == nil ? AppColor.textSecondary : AppColor.danger)
            Group {
                if isSecure {
                    SecureField(prompt, text: $text)
                } else {
                    TextField(prompt, text: $text)
                        .textInputAutocapitalization(autocapitalization)
                        .keyboardType(keyboardType)
                }
            }
            .textContentType(contentType)
            .focused($focused)
            .font(AppTypography.bodyL)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.space16)
            .frame(minHeight: AppLayout.primaryControlHeight)
            .boardedSurface(in: AppRadius.control, interactive: true)
            .boardedFocusRing(isFocused: focused, in: AppRadius.control)
            .accessibilityLabel(label)
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(AppTypography.labelM)
                    .foregroundStyle(AppColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("field-error-\(label)")
            }
        }
    }
}

/// Labeled multiline text field for captions, descriptions, notes, and bio.
struct BoardedTextEditor: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var minHeight: CGFloat = 96
    var error: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            Text(label)
                .font(AppTypography.labelM)
                .foregroundStyle(error == nil ? AppColor.textSecondary : AppColor.danger)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(AppTypography.bodyL)
                        .foregroundStyle(AppColor.textTertiary)
                        .padding(.horizontal, AppSpacing.space16)
                        .padding(.vertical, AppSpacing.space12)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .font(AppTypography.bodyL)
                    .foregroundStyle(AppColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, AppSpacing.space12)
                    .padding(.vertical, AppSpacing.space4)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .boardedSurface(in: AppRadius.control, interactive: true)
            .boardedFocusRing(isFocused: focused, in: AppRadius.control)
            .accessibilityLabel(label)
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(AppTypography.labelM)
                    .foregroundStyle(AppColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BoardedPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BoardedButtonStyle(.primary))
        .accessibilityLabel(title)
    }
}

// MARK: - Material depth

/// Compact control or single-line fact over photography.
struct BoardedPhotoHUD<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, AppSpacing.space12)
            .frame(minHeight: AppLayout.minimumTarget)
            .boardedMaterial(.photoHUD, in: Capsule())
    }
}

/// Multi-fact shelf attached to photography. Reading content belongs in an
/// opaque panel instead.
struct BoardedSessionFactShelf<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.space16)
            .boardedMaterial(.sessionFactShelf, in: AppRadius.card())
    }
}

/// Compact logger or media actions floating over underlapping content.
struct BoardedFloatingRail<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.space8)
            .boardedMaterial(.floatingRail, in: AppRadius.card())
    }
}

/// Navigation or tab chrome used only while scrolling content visibly
/// underlaps it.
struct BoardedContentChrome<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, AppSpacing.space16)
            .padding(.vertical, AppSpacing.space8)
            .boardedMaterial(.contentChrome, in: AppRadius.card())
    }
}
