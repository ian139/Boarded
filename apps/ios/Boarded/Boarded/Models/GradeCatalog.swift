import Foundation

enum GradeSystem: String, Codable, CaseIterable, Sendable {
    case vScale = "v_scale"
    case font = "font"
    case yds = "yds"
    case custom = "custom"
}

enum ClimbDiscipline: String, Codable, CaseIterable, Sendable {
    case boulder
    case sport
    case trad
    case topRope = "top_rope"
    case board
    case other
}

/// Canonical grade ordering for every wire grade system. `custom` has no
/// intrinsic ordering and always ranks -1; its labels are preserved verbatim.
enum GradeCatalog {
    static let vGrades: [String] = [
        "VB", "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9",
        "V10", "V11", "V12", "V13", "V14", "V15", "V16", "V17"
    ]

    static let fontGrades: [String] = [
        "4", "5a", "5b", "5c", "6a", "6a+", "6b", "6b+", "6c", "6c+",
        "7a", "7a+", "7b", "7b+", "7c", "7c+", "8a", "8a+", "8b", "8b+",
        "8c", "8c+", "9a"
    ]

    static let ydsGrades: [String] = [
        "5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9",
        "5.10a", "5.10b", "5.10c", "5.10d", "5.11a", "5.11b", "5.11c", "5.11d",
        "5.12a", "5.12b", "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d",
        "5.14a", "5.14b", "5.14c", "5.14d", "5.15a", "5.15b", "5.15c", "5.15d"
    ]

    static func grades(for system: GradeSystem) -> [String] {
        switch system {
        case .vScale: return vGrades
        case .font: return fontGrades
        case .yds: return ydsGrades
        case .custom: return []
        }
    }

    /// Returns the canonical label for a grade, or nil when the label is not a
    /// member of the system's ordering. Custom labels are returned trimmed.
    static func canonical(_ label: String?, system: GradeSystem) -> String? {
        guard let label else { return nil }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch system {
        case .custom:
            return trimmed
        case .vScale, .font, .yds:
            return grades(for: system).first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
    }

    /// Zero-based rank within the system's ordering, or -1 for unknown/custom.
    static func rank(_ label: String?, system: GradeSystem) -> Int {
        guard let canonical = canonical(label, system: system) else { return -1 }
        return grades(for: system).firstIndex(of: canonical) ?? -1
    }

    static func label(forRank rank: Int, system: GradeSystem) -> String? {
        let list = grades(for: system)
        guard list.indices.contains(rank) else { return nil }
        return list[rank]
    }
}
