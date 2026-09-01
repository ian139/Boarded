import Foundation

/// Locale-aware formatting. All user-facing dates, times, and measurements
/// flow through these helpers so the app never hardcodes formats.
enum BoardedFormat {
    /// "yesterday", "3 days ago" — locale-aware relative presentation.
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    /// Abbreviated date with short time: "Nov 14, 2026, 6:13 PM".
    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Weekday with time for meetup rows: "Tue, Nov 14, 6:13 PM".
    static func weekdayTime(_ date: Date) -> String {
        let day = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).weekday(.abbreviated))
        return day + ", " + date.formatted(date: .omitted, time: .shortened)
    }

    static func timeOnly(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Tabular elapsed duration: "1:04:09".
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// Whole-percent presentation: "67%".
    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

extension AttemptOutcome {
    var title: String {
        switch self {
        case .sent: return "Sent"
        case .fell: return "Fell"
        case .stopped: return "Stopped"
        }
    }

    /// Explicit outcome semantics: green + checkmark for sends, red + cross
    /// for falls, neutral for stops. Outcomes are never encoded by color alone.
    var systemImage: String {
        switch self {
        case .sent: return "checkmark.circle.fill"
        case .fell: return "xmark.circle.fill"
        case .stopped: return "minus.circle.fill"
        }
    }
}

extension ClimbDiscipline {
    var title: String {
        switch self {
        case .boulder: return "Boulder"
        case .sport: return "Sport"
        case .trad: return "Trad"
        case .topRope: return "Top Rope"
        case .board: return "Board"
        case .other: return "Other"
        }
    }
}

extension GradeSystem {
    var title: String {
        switch self {
        case .vScale: return "V Scale"
        case .font: return "Font"
        case .yds: return "YDS"
        case .custom: return "Custom"
        }
    }
}
