import Foundation

/// Represents video frame rates commonly used in professional video production.
/// Drop frame rates use a timecode display format that skips certain frame numbers
/// to maintain sync with real-world time.
public enum FrameRate: Hashable, Codable {
    case fps23_976
    case fps24
    case fps25
    case fps29_97_df   // Drop frame
    case fps29_97_ndf  // Non-drop frame
    case fps30
    case fps50
    case fps59_94
    case fps60
    case custom(Double)

    /// The actual frames per second as a Double value.
    public var framesPerSecond: Double {
        switch self {
        case .fps23_976:
            return 24000.0 / 1001.0  // 23.976...
        case .fps24:
            return 24.0
        case .fps25:
            return 25.0
        case .fps29_97_df, .fps29_97_ndf:
            return 30000.0 / 1001.0  // 29.97...
        case .fps30:
            return 30.0
        case .fps50:
            return 50.0
        case .fps59_94:
            return 60000.0 / 1001.0  // 59.94...
        case .fps60:
            return 60.0
        case .custom(let fps):
            return fps
        }
    }

    /// Whether this frame rate uses drop frame timecode display.
    /// Drop frame is a display format that skips frame numbers to keep
    /// timecode in sync with wall clock time for NTSC rates.
    public var isDropFrame: Bool {
        switch self {
        case .fps29_97_df:
            return true
        default:
            return false
        }
    }

    /// The nominal (integer) frame rate used for timecode display.
    /// For example, 29.97 displays as if it were 30fps.
    public var nominalFrameRate: Int {
        switch self {
        case .fps23_976:
            return 24
        case .fps24:
            return 24
        case .fps25:
            return 25
        case .fps29_97_df, .fps29_97_ndf:
            return 30
        case .fps30:
            return 30
        case .fps50:
            return 50
        case .fps59_94:
            return 60
        case .fps60:
            return 60
        case .custom(let fps):
            return Int(fps.rounded())
        }
    }

    /// Human-readable display name for the frame rate.
    public var displayName: String {
        switch self {
        case .fps23_976:
            return "23.976"
        case .fps24:
            return "24"
        case .fps25:
            return "25"
        case .fps29_97_df:
            return "29.97 DF"
        case .fps29_97_ndf:
            return "29.97 NDF"
        case .fps30:
            return "30"
        case .fps50:
            return "50"
        case .fps59_94:
            return "59.94"
        case .fps60:
            return "60"
        case .custom(let fps):
            return String(format: "%.3g", fps)
        }
    }

    /// VoiceOver-friendly name for accessibility.
    public var accessibilityName: String {
        switch self {
        case .fps23_976:
            return "23.976 frames per second"
        case .fps24:
            return "24 frames per second"
        case .fps25:
            return "25 frames per second"
        case .fps29_97_df:
            return "29.97 drop frame"
        case .fps29_97_ndf:
            return "29.97 non-drop frame"
        case .fps30:
            return "30 frames per second"
        case .fps50:
            return "50 frames per second"
        case .fps59_94:
            return "59.94 frames per second"
        case .fps60:
            return "60 frames per second"
        case .custom(let fps):
            return "\(String(format: "%.3g", fps)) frames per second, custom"
        }
    }

    /// All standard frame rates (excluding custom).
    public static var allStandardRates: [FrameRate] {
        [.fps23_976, .fps24, .fps25, .fps29_97_df, .fps29_97_ndf, .fps30, .fps50, .fps59_94, .fps60]
    }
}

// MARK: - Codable conformance for custom case

extension FrameRate {
    private enum CodingKeys: String, CodingKey {
        case type
        case customValue
    }

    private enum FrameRateType: String, Codable {
        case fps23_976, fps24, fps25, fps29_97_df, fps29_97_ndf, fps30, fps50, fps59_94, fps60, custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FrameRateType.self, forKey: .type)

        switch type {
        case .fps23_976: self = .fps23_976
        case .fps24: self = .fps24
        case .fps25: self = .fps25
        case .fps29_97_df: self = .fps29_97_df
        case .fps29_97_ndf: self = .fps29_97_ndf
        case .fps30: self = .fps30
        case .fps50: self = .fps50
        case .fps59_94: self = .fps59_94
        case .fps60: self = .fps60
        case .custom:
            let value = try container.decode(Double.self, forKey: .customValue)
            self = .custom(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .fps23_976: try container.encode(FrameRateType.fps23_976, forKey: .type)
        case .fps24: try container.encode(FrameRateType.fps24, forKey: .type)
        case .fps25: try container.encode(FrameRateType.fps25, forKey: .type)
        case .fps29_97_df: try container.encode(FrameRateType.fps29_97_df, forKey: .type)
        case .fps29_97_ndf: try container.encode(FrameRateType.fps29_97_ndf, forKey: .type)
        case .fps30: try container.encode(FrameRateType.fps30, forKey: .type)
        case .fps50: try container.encode(FrameRateType.fps50, forKey: .type)
        case .fps59_94: try container.encode(FrameRateType.fps59_94, forKey: .type)
        case .fps60: try container.encode(FrameRateType.fps60, forKey: .type)
        case .custom(let value):
            try container.encode(FrameRateType.custom, forKey: .type)
            try container.encode(value, forKey: .customValue)
        }
    }
}
