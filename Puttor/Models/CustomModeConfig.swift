//
//  CustomModeConfig.swift
//  Puttor
//
//  User-configurable field list for the Custom input mode. Distance and
//  Result are always present (Result's complexity is configurable); every
//  other field is optional, addable, removable, and reorderable from
//  Settings. Persisted as JSON in UserDefaults since it's a single global
//  app preference, not per-round data.
//

import Foundation

enum FieldComplexity: String, Codable, CaseIterable {
    case simple, complex

    var labelKey: String {
        switch self {
        case .simple: return "custom.complexity.simple"
        case .complex: return "custom.complexity.complex"
        }
    }
}

enum CustomFieldKind: String, Codable, CaseIterable, Identifiable {
    case puttForCategory
    case slope
    case doubleBreak
    case missReasons

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .puttForCategory: return "custom.field.puttFor"
        case .slope: return "custom.field.slope"
        case .doubleBreak: return "custom.field.doubleBreak"
        case .missReasons: return "custom.field.missReasons"
        }
    }

    var descKey: String {
        switch self {
        case .puttForCategory: return "custom.field.puttFor.desc"
        case .slope: return "custom.field.slope.desc"
        case .doubleBreak: return "custom.field.doubleBreak.desc"
        case .missReasons: return "custom.field.missReasons.desc"
        }
    }

    var icon: String {
        switch self {
        case .puttForCategory: return "flag.fill"
        case .slope: return "square.grid.3x3.fill"
        case .doubleBreak: return "arrow.triangle.branch"
        case .missReasons: return "exclamationmark.triangle.fill"
        }
    }

    /// Only the slope field offers a simple/complex sub-choice.
    var supportsComplexity: Bool { self == .slope }
}

struct CustomField: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: CustomFieldKind
    var complexity: FieldComplexity = .simple
}

struct CustomModeConfig: Codable, Equatable {
    var resultComplexity: FieldComplexity = .simple
    var fields: [CustomField] = []

    /// Optional in storage so configs written before the distance field gained
    /// a complexity setting still decode — a missing key would otherwise throw
    /// and silently reset the user's whole field layout to the default.
    private var distanceComplexityRaw: FieldComplexity?

    var distanceComplexity: FieldComplexity {
        get { distanceComplexityRaw ?? .simple }
        set { distanceComplexityRaw = newValue }
    }

    static let defaultConfig = CustomModeConfig(
        resultComplexity: .simple,
        fields: [CustomField(kind: .puttForCategory)]
    )

    static func load() -> CustomModeConfig {
        guard let data = UserDefaults.standard.data(forKey: AppStorageKeys.customModeConfig),
              let decoded = try? JSONDecoder().decode(CustomModeConfig.self, from: data) else {
            return .defaultConfig
        }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: AppStorageKeys.customModeConfig)
    }
}
