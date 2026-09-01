import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: AppSpacing.space8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(AppTypography.bodyL)
                .foregroundStyle(AppColor.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: AppLayout.minimumTarget, height: AppLayout.minimumTarget)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, AppSpacing.space12)
        .frame(minHeight: AppLayout.minimumTarget)
        .boardedSurface(in: AppRadius.control, interactive: true)
        .accessibilityElement(children: .contain)
    }
}
