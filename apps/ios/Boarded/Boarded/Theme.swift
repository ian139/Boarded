import SwiftUI
import UIKit

// MARK: - Color system
//
// Semantic color tokens shared with the web design language. Components consume
// semantic names only; palette hex values appear nowhere outside this file.
// Boarded is dark-only: these values render regardless of system appearance.

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
    static let scrimTop = backgroundBase.opacity(0.58)
}

// MARK: - Spacing
//
// 4-point base, 8-point primary rhythm.

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

// MARK: - Shape

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24

    static func card(cornerRadius: CGFloat = AppRadius.large) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    static let control = RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
    static let sheet = RoundedRectangle(cornerRadius: AppRadius.extraLarge, style: .continuous)
}

enum AppStroke {
    static let hairline: CGFloat = 1
    static let selected: CGFloat = 1.5
    static let focusRing: CGFloat = 2
    static let focusGap: CGFloat = 2
}


enum BoardedMaterialStyle {
    case photoHUD
    case sessionFactShelf
    case floatingRail
    case contentChrome

    fileprivate var material: Material {
        switch self {
        case .photoHUD: return .ultraThinMaterial
        case .sessionFactShelf, .floatingRail: return .thinMaterial
        case .contentChrome: return .regularMaterial
        }
    }

    fileprivate var tintOpacity: Double {
        switch self {
        case .photoHUD: return 0.58
        case .sessionFactShelf, .floatingRail: return 0.64
        case .contentChrome: return 0.72
        }
    }

    fileprivate var opaqueFallback: Color {
        switch self {
        case .photoHUD, .contentChrome: return AppColor.backgroundBase
        case .sessionFactShelf, .floatingRail: return AppColor.backgroundElevated
        }
    }
}

// MARK: - Motion

enum AppMotion {
    static let instant: TimeInterval = 0.10
    static let fast: TimeInterval = 0.18
    static let standard: TimeInterval = 0.28
    static let expressive: TimeInterval = 0.42

    /// Signature route-trace duration band: 280–420 ms.
    static let routeTrace: TimeInterval = AppMotion.standard

    static func easeOut(_ duration: TimeInterval) -> Animation { .easeOut(duration: duration) }
}

// MARK: - Typography
//
// Dual-family structure: Cormorant Garamond Semibold Italic for expressive
// display moments (bundled, registered in UIAppFonts), native SF Pro through
// system text styles for everything else. The serif falls back to the italic
// system serif only when the bundled face fails to load.

enum AppTypography {
    static let serifPostScriptName = "CormorantGaramond-SemiBoldItalic"

    static func displaySerif(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if UIFont(name: serifPostScriptName, size: size) != nil {
            return .custom(serifPostScriptName, size: size, relativeTo: style)
        }
        return Font.system(size: size, weight: .semibold, design: .serif).italic()
    }

    // Display serif scale (weight 600 italic only).
    static let displayXL = displaySerif(size: 64, relativeTo: .largeTitle)
    static let displayL = displaySerif(size: 48, relativeTo: .largeTitle)
    static let displayM = displaySerif(size: 40, relativeTo: .title)
    static let displayS = displaySerif(size: 32, relativeTo: .title2)

    // Interface sans scale (SF Pro via system text styles).
    static let titleL = Font.system(.title).weight(.semibold)          // 28/34 screen title
    static let titleM = Font.system(.title2).weight(.semibold)         // 22/28 section/sheet title
    static let bodyL = Font.system(.body)                              // 17/24
    static let bodyM = Font.system(.subheadline)                       // 15/21
    static let labelL = Font.system(.subheadline).weight(.medium)      // 15/20
    static let labelM = Font.system(.footnote).weight(.medium)         // 13/18
    static let caption = Font.system(.caption)                         // 12/16

    // Tabular data styles for timers, counters, and attempt rows.
    static let dataL = Font.system(.largeTitle).monospacedDigit()      // 34/38
    static let dataM = Font.system(.title2).monospacedDigit()          // 22/28
    static let dataS = Font.system(.subheadline).monospacedDigit()     // 15/20
}

/// Uppercase tracked green eyebrow for editorial moments (TODAY, SESSION
/// COMPLETE, NEW PERSONAL RECORD). Used sparingly.
struct BoardedEyebrow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppTypography.caption.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(AppColor.accentDefault)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Layout

enum AppLayout {
    static let screenMargin: CGFloat = 20
    static let wideScreenMargin: CGFloat = 24
    static let cardPadding = AppSpacing.space16
    static let featureCardPadding = AppSpacing.space20
    static let cardGap = AppSpacing.space12
    static let contentGap = AppSpacing.space16
    static let sectionGap = AppSpacing.space32
    static let eyebrowToTitle = AppSpacing.space8
    static let titleToContent = AppSpacing.space16
    static let primaryControlHeight: CGFloat = 52
    static let minimumTarget: CGFloat = 44
    static let listRowMinHeight: CGFloat = 56
    static let chipMinHeight: CGFloat = 34
    static let attemptTimelineColumnMinWidth = minimumTarget * 2
    static let attemptTimelineCompactThreshold = 8
    static let attemptTimelineCompactColumns = 16
    static let contentMaxWidth: CGFloat = 560

    /// Horizontal margin for the current width class: 20 pt on compact
    /// iPhones, 24 pt on Pro Max / regular widths.
    static func margin(for width: CGFloat) -> CGFloat {
        width >= 428 ? wideScreenMargin : screenMargin
    }
}

// MARK: - Surface modifiers

private struct BoardedPageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppColor.backgroundBase.ignoresSafeArea())
    }
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

private struct BoardedPanelModifier: ViewModifier {
    let padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .boardedSurface(in: AppRadius.card())
    }
}

private struct BoardedMaterialModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let style: BoardedMaterialStyle
    let shape: S

    private var usesOpaqueFallback: Bool {
        if reduceTransparency { return true }
        guard contrast == .increased else { return false }
        switch style {
        case .photoHUD: return false
        case .sessionFactShelf, .floatingRail, .contentChrome: return true
        }
    }

    private var tintOpacity: Double {
        contrast == .increased ? 0.72 : style.tintOpacity
    }

    private var leadingRimOpacity: Double {
        reduceTransparency ? 0.18 : (contrast == .increased ? 0.32 : 0.18)
    }

    private var trailingRimOpacity: Double {
        reduceTransparency ? 0.08 : (contrast == .increased ? 0.14 : 0.08)
    }

    func body(content: Content) -> some View {
        content
            .background {
                if usesOpaqueFallback {
                    shape.fill(style.opaqueFallback)
                } else {
                    shape
                        .fill(style.material)
                        .overlay { shape.fill(AppColor.backgroundBase.opacity(tintOpacity)) }
                }
            }
            .overlay {
                shape
                    .stroke(
                        AppColor.textPrimary.opacity(leadingRimOpacity),
                        lineWidth: AppStroke.hairline
                    )
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0.49),
                                .init(color: .clear, location: 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                shape
                    .stroke(
                        AppColor.textPrimary.opacity(trailingRimOpacity),
                        lineWidth: AppStroke.hairline
                    )
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.49),
                                .init(color: .white, location: 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            }
    }
}

private struct BoardedFocusRingModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let isFocused: Bool
    let shape: S
    func body(content: Content) -> some View {
        content.overlay {
            if isFocused {
                shape
                    .stroke(AppColor.accentDefault, lineWidth: AppStroke.focusRing)
                    .overlay {
                        if differentiateWithoutColor {
                            shape.stroke(AppColor.textPrimary, style: StrokeStyle(lineWidth: AppStroke.hairline, dash: [4, 4]))
                        }
                    }
                    .padding(-(AppStroke.focusRing + AppStroke.focusGap))
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func boardedPageBackground() -> some View { modifier(BoardedPageBackgroundModifier()) }

    /// Card surface: 16 pt padding, card fill, hairline stroke, 16 pt radius.
    func boardedPanel(padding: CGFloat = AppLayout.cardPadding) -> some View { modifier(BoardedPanelModifier(padding: padding)) }

    func boardedSurface<S: Shape>(in shape: S, interactive: Bool = false) -> some View { modifier(BoardedSurfaceModifier(shape: shape, interactive: interactive)) }

    func boardedFocusRing<S: Shape>(isFocused: Bool, in shape: S) -> some View { modifier(BoardedFocusRingModifier(isFocused: isFocused, shape: shape)) }

    /// Bounded iOS material over visibly underlapping imagery or content.
    /// Reduce Transparency and increased-contrast dense styles resolve to the
    /// design-contract opaque fallback without changing layout.
    func boardedMaterial<S: Shape>(_ style: BoardedMaterialStyle, in shape: S) -> some View {
        modifier(BoardedMaterialModifier(style: style, shape: shape))
    }

    /// Constrains readable content width on regular size classes.
    func boardedContentWidth() -> some View { frame(maxWidth: AppLayout.contentMaxWidth) }
}

// MARK: - Shared components

struct BoardedSectionHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Text(title)
                .font(AppTypography.titleM)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.bodyM)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BoardedFilterControl: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.space8) {
                Text(title)
                if isSelected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .font(AppTypography.labelL)
            .foregroundStyle(isSelected ? AppColor.accentDefault : AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.space12)
            .frame(minHeight: AppLayout.chipMinHeight)
            .background(isSelected ? AppColor.surfaceSelected : AppColor.surfaceCard, in: AppRadius.control)
            .overlay {
                AppRadius.control.stroke(
                    isSelected ? AppColor.accentDefault.opacity(0.65) : AppColor.strokeDefault,
                    lineWidth: isSelected ? AppStroke.selected : AppStroke.hairline
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BoardedButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    let kind: Kind
    init(_ kind: Kind = .primary) { self.kind = kind }

    func makeBody(configuration: Configuration) -> some View {
        let backgroundColor: Color
        let foregroundColor: Color
        switch kind {
        case .primary:
            backgroundColor = configuration.isPressed ? AppColor.accentPressed : AppColor.accentDefault
            foregroundColor = AppColor.accentOnAccent
        case .secondary:
            backgroundColor = configuration.isPressed ? AppColor.surfaceSelected : AppColor.backgroundElevated
            foregroundColor = AppColor.textPrimary
        case .destructive:
            backgroundColor = configuration.isPressed ? AppColor.danger.opacity(0.18) : AppColor.backgroundElevated
            foregroundColor = AppColor.danger
        }
        return configuration.label
            .font(AppTypography.labelL)
            .foregroundStyle(isEnabled ? foregroundColor : AppColor.textDisabled)
            .frame(minHeight: AppLayout.primaryControlHeight)
            .frame(maxWidth: kind == .primary ? .infinity : nil)
            .padding(.horizontal, AppSpacing.space16)
            .background(backgroundColor)
            .overlay {
                AppRadius.control.stroke(
                    kind == .secondary ? AppColor.strokeDefault : (kind == .destructive ? AppColor.danger.opacity(0.5) : .clear),
                    lineWidth: AppStroke.hairline
                )
            }
            .clipShape(AppRadius.control)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : AppMotion.easeOut(AppMotion.instant), value: configuration.isPressed)
    }
}

// MARK: - Color helpers

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
