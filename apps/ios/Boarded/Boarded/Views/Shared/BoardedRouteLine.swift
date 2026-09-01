import SwiftUI

/// Sparse diagrammatic climbing trace: one continuous Chalk line from Start to
/// Top with green nodes. Never map-like, never decorative loops.
struct RouteLineShape: Shape {
    /// Normalized waypoints, bottom (start) to top.
    static let waypoints: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.94),
        CGPoint(x: 0.44, y: 0.76),
        CGPoint(x: 0.30, y: 0.56),
        CGPoint(x: 0.64, y: 0.42),
        CGPoint(x: 0.54, y: 0.22),
        CGPoint(x: 0.88, y: 0.06),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Self.waypoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

/// The signature Boarded motion: a route trace drawing from Start to Top over
/// 280–420 ms. Reduce Motion renders the completed trace statically.
struct BoardedRouteLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var lineWidth: CGFloat = 2
    var drawsOnAppear = true

    @State private var trimEnd: CGFloat = 0

    private var drawn: CGFloat { drawsOnAppear ? trimEnd : 1 }

    var body: some View {
        ZStack {
            RouteLineShape()
                .stroke(AppColor.textTertiary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            RouteLineShape()
                .trim(from: 0, to: drawn)
                .stroke(AppColor.textPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            nodes
        }
        .accessibilityHidden(true)
        .onAppear {
            guard drawsOnAppear else { trimEnd = 1; return }
            if reduceMotion {
                trimEnd = 1
            } else {
                withAnimation(AppMotion.easeOut(AppMotion.expressive)) { trimEnd = 1 }
            }
        }
    }

    private var nodes: some View {
        GeometryReader { proxy in
            ForEach(Array(RouteLineShape.waypoints.enumerated()), id: \.offset) { index, waypoint in
                let isTop = index == RouteLineShape.waypoints.count - 1
                Circle()
                    .fill(isTop ? AppColor.accentDefault : AppColor.textPrimary)
                    .frame(width: isTop ? 8 : 6, height: isTop ? 8 : 6)
                    .opacity(drawn >= CGFloat(index) / CGFloat(RouteLineShape.waypoints.count - 1) ? 1 : 0)
                    .position(x: proxy.size.width * waypoint.x, y: proxy.size.height * waypoint.y)
            }
        }
    }
}

/// Identity avatar: initials on a Slate disc with a hairline stroke.
struct BoardedAvatar: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(AppColor.backgroundElevated)
            Circle().stroke(AppColor.strokeDefault, lineWidth: AppStroke.hairline)
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
