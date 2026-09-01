import SwiftUI
import Foundation

struct RouteRow: View {
    let route: Route
    let onOpen: () -> Void
    var onLike: (() -> Void)? = nil
    var onLogClimb: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isKeyboardFocused: Bool

    private var usesVerticalLayout: Bool {
        horizontalSizeClass == .compact || dynamicTypeSize >= .xxLarge
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)

        ZStack {
            Button(action: onOpen) {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isKeyboardFocused)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Opens route details")
            .accessibilityInputLabels([route.name, "Open \(route.name)"])
            .accessibilityAction(named: (route.isLiked ?? false) ? "Unlike" : "Like") {
                onLike?()
            }
            .accessibilityAction(named: "Log Send") {
                onLogClimb?()
            }

            Group {
                if usesVerticalLayout {
                    VStack(alignment: .leading, spacing: AppSpacing.space12) {
                        routeSummary
                        actions
                    }
                } else {
                    HStack(alignment: .center, spacing: AppSpacing.space12) {
                        routeSummary
                        actions
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: AppLayout.primaryControlHeight, alignment: .leading)
        .padding(AppSpacing.space12)
        .background(isKeyboardFocused ? AppColor.surfaceSelected : AppColor.surfaceCard, in: shape)
        .overlay {
            shape.stroke(
                isKeyboardFocused ? AppColor.accentDefault : AppColor.strokeSubtle,
                lineWidth: isKeyboardFocused ? AppStroke.focus : AppStroke.hairline
            )
            if isKeyboardFocused && differentiateWithoutColor {
                shape.stroke(AppColor.textPrimary, style: StrokeStyle(lineWidth: AppStroke.hairline, dash: [4, 4]))
                    .padding(AppSpacing.space4)
            }
        }
    }

    @ViewBuilder
    private var routeSummary: some View {
        if usesVerticalLayout {
            VStack(alignment: .leading, spacing: AppSpacing.space12) {
                HStack(alignment: .center, spacing: AppSpacing.space12) {
                    Text(displayGrade)
                        .font(AppTypography.display)
                        .foregroundStyle(route.gradeV == nil ? AppColor.textSecondary : AppColor.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: AppSpacing.space48, minHeight: AppLayout.minimumControlHeight)
                    wallThumbnail
                }
                routeText
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        } else {
            HStack(alignment: .center, spacing: AppSpacing.space12) {
                Text(displayGrade)
                    .font(AppTypography.display)
                    .foregroundStyle(route.gradeV == nil ? AppColor.textSecondary : AppColor.textPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: AppSpacing.space48, minHeight: AppLayout.minimumControlHeight)
                wallThumbnail
                routeText
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    private var routeText: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Text(route.name)
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(route.userName ?? "Anonymous") • \(route.holds.count) holds")
                .font(AppTypography.label)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(metricsText) • \(timeAgo)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.space4) {
            Spacer(minLength: 0)
            Button(action: { onLike?() }) {
                Label((route.isLiked ?? false) ? "Unlike" : "Like", systemImage: (route.isLiked ?? false) ? "heart.fill" : "heart")
                    .labelStyle(.iconOnly)
                    .foregroundStyle((route.isLiked ?? false) ? AppColor.accentDefault : AppColor.textPrimary)
                    .frame(minWidth: AppLayout.minimumControlHeight, minHeight: AppLayout.minimumControlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onLike == nil)
            .accessibilityLabel((route.isLiked ?? false) ? "Unlike \(route.name)" : "Like \(route.name)")
            .accessibilityValue("\(route.likeCount ?? 0) likes")
            .accessibilityInputLabels([(route.isLiked ?? false) ? "Unlike" : "Like"])

            Button(action: { onLogClimb?() }) {
                Label("Log Send", systemImage: route.ascents.isEmpty ? "checkmark.circle" : "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(route.ascents.isEmpty ? AppColor.textPrimary : AppColor.accentDefault)
                    .frame(minWidth: AppLayout.minimumControlHeight, minHeight: AppLayout.minimumControlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onLogClimb == nil)
            .accessibilityLabel("Log Send for \(route.name)")
            .accessibilityValue("\(route.ascents.count) sends")
            .accessibilityInputLabels(["Log Send"])
        }
    }

    private var wallThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous).fill(AppColor.backgroundElevated)
            if let url = route.wallImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: AppColor.backgroundElevated
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: defaultWallThumbnail
                    @unknown default: defaultWallThumbnail
                    }
                }
            } else {
                defaultWallThumbnail
            }
        }
        .frame(width: AppSpacing.space48, height: AppSpacing.space48)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous).stroke(AppColor.strokeDefault, lineWidth: AppStroke.hairline) }
        .accessibilityHidden(true)
    }

    private var displayGrade: String { route.gradeV ?? "—" }
    private var defaultWallThumbnail: some View { Image("DefaultWall").resizable().scaledToFill() }

    private var accessibilityLabel: String {
        "\(route.name), grade \(route.gradeV ?? "unknown"), set by \(route.userName ?? "Anonymous"), \(route.holds.count) holds, \(metricsText)"
    }

    private var metricsText: String {
        let likes = route.likeCount ?? 0
        let sends = route.ascents.count
        return sends > 0 ? "\(likes) likes, \(sends) sends" : "\(likes) likes"
    }

    private var timeAgo: String {
        let diff = Date().timeIntervalSince(parseISO8601Date(route.createdAt) ?? Date())
        let mins = Int(diff / 60)
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        return "\(days / 7)w"
    }
}
