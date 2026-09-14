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
    /// The slope typed in percent on a keypad instead of picked on a grid.
    case numbers

    var labelKey: String {
        switch self {
        case .simple: return "custom.complexity.simple"
        case .complex: return "custom.complexity.complex"
        case .numbers: return "custom.complexity.numbers"
        }
    }
}

/// How the distance is entered. Separate from FieldComplexity because "slider
/// vs numpad" is a choice of control, not of detail level.
enum DistanceInputStyle: String, Codable, CaseIterable {
    case slider, numpad

    var labelKey: String {
        switch self {
        case .slider: return "custom.distance.slider"
        case .numpad: return "custom.distance.numpad"
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

/// How Custom mode asks for the result. `angle` records where around the hole
/// the ball stopped, to the nearest five degrees, rather than which of eight
/// sectors it fell in.
enum ResultInputStyle: String, Codable, CaseIterable {
    case simple, dartboard, angle

    var labelKey: String {
        switch self {
        case .simple: return "custom.result.style.simple"
        case .dartboard: return "custom.result.style.dartboard"
        case .angle: return "custom.result.style.angle"
        }
    }
}

struct CustomModeConfig: Codable, Equatable {
    var resultComplexity: FieldComplexity = .simple
    var fields: [CustomField] = []

    /// Optional in storage so configs written before the distance field became
    /// switchable still decode — a missing key would otherwise throw and
    /// silently reset the user's whole field layout to the default.
    private var distanceStyleRaw: DistanceInputStyle?

    var distanceStyle: DistanceInputStyle {
        get { distanceStyleRaw ?? .slider }
        set { distanceStyleRaw = newValue }
    }

    /// Optional in storage for the same reason as the distance style. A config
    /// saved before there were three styles reads its old simple/complex
    /// choice as simple/board.
    private var resultStyleRaw: ResultInputStyle?

    var resultStyle: ResultInputStyle {
        get { resultStyleRaw ?? (resultComplexity == .complex ? .dartboard : .simple) }
        set {
            resultStyleRaw = newValue
            // Both detailed styles need the record button the simple one does
            // without, so the older field keeps saying which is which.
            resultComplexity = newValue == .simple ? .simple : .complex
        }
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
