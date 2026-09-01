import SwiftUI

struct BoardedTheme {
    var background: Color { AppColor.backgroundBase }
    var panelBackground: Color { AppColor.backgroundElevated }
    var primaryText: Color { AppColor.textPrimary }
    var secondaryText: Color { AppColor.textSecondary }
    var primary: Color { AppColor.accentDefault }
    var accent: Color { AppColor.accentDefault }
    var border: Color { AppColor.strokeDefault }
    var destructive: Color { AppColor.danger }
    var actionForeground: Color { AppColor.accentOnAccent }

    let pagePadding = AppSpacing.space20
    let panelPadding = AppSpacing.space16
    let panelCornerRadius = AppRadius.large
    let controlCornerRadius = AppRadius.medium
    let animationDuration = AppMotion.quick

    func holdColor(for type: HoldType) -> Color {
        switch type {
        case .start: return AppColor.accentDefault
        case .finish: return AppColor.textPrimary
        case .hand: return AppColor.textSecondary
        case .foot: return AppColor.textTertiary
        }
    }
}

enum AppColor {
    static let backgroundBase = Color.hex("#0A0B10")
    static let backgroundElevated = Color.hex("#171A22")
    static let surfaceCard = Color.hex("#0D0F14")
    static let surfaceSelected = Color.hex("#32D583").opacity(0.12)
    static let textPrimary = Color.hex("#F4F2EB")
    static let textSecondary = textPrimary.opacity(0.64)
    static let textTertiary = textPrimary.opacity(0.44)
    static let textDisabled = textPrimary.opacity(0.30)
    static let strokeDefault = textPrimary.opacity(0.18)
    static let strokeSubtle = textPrimary.opacity(0.10)
    static let divider = textPrimary.opacity(0.08)
    static let accentDefault = Color.hex("#32D583")
    static let accentPressed = Color.hex("#27B873")
    static let accentSoft = accentDefault.opacity(0.14)
    static let accentOnAccent = backgroundBase
    static let danger = Color.hex("#FF6B64")
    static let warning = Color.hex("#F6C85F")
    static let information = Color.hex("#69A7FF")
    static let scrim = backgroundBase.opacity(0.72)

    // Existing source compatibility. New owned code uses semantic names above.
    static let background = backgroundBase
    static let elevated = backgroundElevated
    static let surface = surfaceCard
    static let selectedSurface = surfaceSelected
    static let text = textPrimary
    static let muted = textSecondary
    static let tertiaryText = textTertiary
    static let disabledText = textDisabled
    static let primary = accentDefault
    static let pressed = accentPressed
    static let actionForeground = accentOnAccent
    static let accent = accentDefault
    static let border = strokeDefault
    static let subtleBorder = strokeSubtle
    static let destructive = danger
}

enum AppSpacing {
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space40: CGFloat = 40
    static let space48: CGFloat = 48
    static let space64: CGFloat = 64
}

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let capsule: CGFloat = 999
}

enum AppStroke {
    static let hairline: CGFloat = 1
    static let focus: CGFloat = 3
}

enum AppMotion {
    static let quick = 0.18
    static let standard = 0.28
    static let routeTrace = Animation.easeOut(duration: standard)
}

enum AppTypography {
    static let displayLarge = Font.custom("CormorantGaramond-SemiBoldItalic", size: 48, relativeTo: .largeTitle)
    static let largeTitle = Font.custom("CormorantGaramond-SemiBoldItalic", size: 40, relativeTo: .largeTitle)
    static let display = Font.custom("CormorantGaramond-SemiBoldItalic", size: 32, relativeTo: .title)
    static let title = Font.system(.title2).weight(.semibold)
    static let headline = Font.system(.headline).weight(.semibold)
    static let body = Font.system(.body)
    static let label = Font.system(.subheadline).weight(.medium)
    static let caption = Font.system(.caption)
    static let dataLarge = Font.system(.largeTitle).monospacedDigit()
    static let data = Font.system(.title2).monospacedDigit()
}

enum AppLayout {
    static let cornerRadius = AppRadius.large
    static let controlCornerRadius = AppRadius.medium
    static let horizontalPadding = AppSpacing.space20
    static let verticalPadding = AppSpacing.space12
    static let minimumControlHeight: CGFloat = 44
    static let primaryControlHeight: CGFloat = 52
    static let contentMaxWidth: CGFloat = 560
    static let editorMaxWidth: CGFloat = 760
    static let defaultWallAspectRatio: CGFloat = 3001.0 / 2733.0
}

private struct BoardedPageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View { content.background(AppColor.backgroundBase.ignoresSafeArea()) }
}

private struct BoardedSurfaceModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let interactive: Bool
    func body(content: Content) -> some View {
        content
            .background(reduceTransparency ? AppColor.backgroundElevated : AppColor.surfaceCard, in: shape)
            .overlay { shape.stroke(interactive ? AppColor.strokeDefault : AppColor.strokeSubtle, lineWidth: AppStroke.hairline) }
    }
}

private struct BoardedFocusRingModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let isFocused: Bool
    let shape: S
    func body(content: Content) -> some View {
        content.overlay {
            if isFocused {
                shape.stroke(AppColor.accentDefault, lineWidth: AppStroke.focus)
                    .overlay {
                        if differentiateWithoutColor {
                            shape.stroke(AppColor.textPrimary, style: StrokeStyle(lineWidth: AppStroke.hairline, dash: [4, 4]))
                        }
                    }
                    .padding(-AppSpacing.space4)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct BoardedGlassContainer<Content: View>: View {
    private let content: () -> Content
    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View { content() }
}

private struct BoardedPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(AppSpacing.space16)
            .boardedGlassSurface(in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}

extension View {
    func boardedPageBackground() -> some View { modifier(BoardedPageBackgroundModifier()) }
    func boardedPanel() -> some View { modifier(BoardedPanelModifier()) }
    func boardedGlassSurface<S: Shape>(in shape: S, interactive: Bool = false) -> some View { modifier(BoardedSurfaceModifier(shape: shape, interactive: interactive)) }
    func boardedFocusRing<S: Shape>(isFocused: Bool, in shape: S) -> some View { modifier(BoardedFocusRingModifier(isFocused: isFocused, shape: shape)) }
}

struct BoardedSectionHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Text(title).font(AppTypography.headline).foregroundStyle(AppColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            if let subtitle { Text(subtitle).font(AppTypography.body).foregroundStyle(AppColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BoardedFilterControl: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
        Button(action: action) {
            HStack(spacing: AppSpacing.space8) {
                Text(title)
                if isSelected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .font(AppTypography.label).foregroundStyle(isSelected ? AppColor.accentDefault : AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.space12).frame(minHeight: AppLayout.minimumControlHeight)
            .background(isSelected ? AppColor.surfaceSelected : AppColor.surfaceCard, in: shape)
            .overlay { shape.stroke(isSelected ? AppColor.accentDefault : AppColor.strokeDefault, lineWidth: AppStroke.hairline) }
        }.buttonStyle(.plain).accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BoardedButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    let kind: Kind
    init(_ kind: Kind = .primary) { self.kind = kind }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .foregroundStyle(!isEnabled ? AppColor.textDisabled : kind == .primary ? AppColor.accentOnAccent : AppColor.textPrimary)
            .frame(minHeight: AppLayout.primaryControlHeight).padding(.horizontal, AppSpacing.space16)
            .background(kind == .primary ? (configuration.isPressed ? AppColor.accentPressed : AppColor.accentDefault) : AppColor.backgroundElevated)
            .overlay { RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous).stroke(kind == .secondary ? AppColor.strokeDefault : .clear, lineWidth: AppStroke.hairline) }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : .easeOut(duration: AppMotion.quick), value: configuration.isPressed)
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case dark
    var id: String { rawValue }
    var title: String { "Dark" }
    var colorScheme: ColorScheme? { .dark }
}

private func hexToRGB(_ value: String) -> (r: Double, g: Double, b: Double) {
    let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var hex: UInt64 = 0
    guard Scanner(string: cleaned).scanHexInt64(&hex) else { return (0, 0, 0) }
    return (Double((hex >> 16) & 0xff) / 255, Double((hex >> 8) & 0xff) / 255, Double(hex & 0xff) / 255)
}

extension Color {
    static func hex(_ value: String) -> Color {
        let rgb = hexToRGB(value)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
