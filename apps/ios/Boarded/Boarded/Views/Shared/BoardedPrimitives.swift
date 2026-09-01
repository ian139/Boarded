import SwiftUI

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
            .onAppear { guard !reduceMotion else { return }; withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { highlighted = true } }
    }
}

struct BoardedRouteLineEmptyState: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.title).foregroundStyle(AppColor.textSecondary).accessibilityHidden(true)
            BoardedSectionHeading(title: title, subtitle: message)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(BoardedButtonStyle(.secondary))
            }
        }.boardedPanel()
    }
}

struct BoardedInlineError: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.space12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(AppTypography.body).foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: AppSpacing.space8)
            Button("Retry", action: retry)
                .font(AppTypography.label)
                .frame(minWidth: AppLayout.minimumControlHeight, minHeight: AppLayout.minimumControlHeight)
                .accessibilityHint("Tries to load the content again")
        }
        .padding(.horizontal, AppSpacing.space16)
        .background(AppColor.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }
}

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
            .padding(.leading, AppSpacing.space16).padding(.trailing, AppSpacing.space8)
            .foregroundStyle(AppColor.textPrimary)
            .background(AppColor.warning.opacity(0.14))
        }
    }

    private func bannerLayout(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: AppSpacing.space12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.space8))
        return layout {
            Label(statusText, systemImage: statusSymbol)
                .font(AppTypography.label)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(statusText)
            Spacer(minLength: AppSpacing.space4)
            if isOffline || state == .failed || state == .queued {
                Button("Retry Sync", action: retry)
                    .frame(minWidth: AppLayout.minimumControlHeight, minHeight: AppLayout.minimumControlHeight)
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
            .font(AppTypography.label).foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.space16).frame(minHeight: 44)
            .background(AppColor.accentSoft, in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}

struct BoardedLabeledField: View {
    let label: String
    let prompt: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space8) {
            Text(label).font(AppTypography.label).foregroundStyle(AppColor.textSecondary)
            TextField(prompt, text: $text)
                .focused($focused).font(AppTypography.body).foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.space16).frame(minHeight: AppLayout.primaryControlHeight)
                .boardedGlassSurface(in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous), interactive: true)
                .boardedFocusRing(isFocused: focused, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .accessibilityLabel(label)
        }
    }
}

struct BoardedPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: systemImage).frame(maxWidth: .infinity) }
            .buttonStyle(BoardedButtonStyle(.primary))
            .accessibilityLabel(title)
    }
}
