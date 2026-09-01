import SwiftUI

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        let theme = BoardedTheme()
        let shape = RoundedRectangle(cornerRadius: theme.controlCornerRadius, style: .continuous)
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.secondaryText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(AppTypography.body)
                .foregroundStyle(theme.primaryText)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: AppLayout.minimumControlHeight, height: AppLayout.minimumControlHeight)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, AppSpacing.space12)
        .frame(minHeight: AppLayout.minimumControlHeight)
        .boardedGlassSurface(in: shape, interactive: true)
    }
}
