import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppSpacing.space12) {
            Image(systemName: "figure.climbing")
                .font(.system(.title, design: .default).weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 72, height: 72)
                .background(AppColor.surfaceCard, in: Circle())
                .overlay { Circle().stroke(AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .accessibilityElement(children: .combine)
    }
}
