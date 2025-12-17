import Foundation
import SwiftUI

/// Predefined marker colors matching NLE-compatible palette (DaVinci Resolve / Avid Media Composer).
enum MarkerColor: String, CaseIterable, Codable {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case pink

    /// SwiftUI Color using exact hex values from PRD for NLE compatibility.
    var displayColor: Color {
        switch self {
        case .red:    return Color(red: 1.0, green: 0.267, blue: 0.267)     // #FF4444
        case .orange: return Color(red: 1.0, green: 0.702, blue: 0.278)     // #FFB347
        case .yellow: return Color(red: 1.0, green: 0.933, blue: 0.333)     // #FFEE55
        case .green:  return Color(red: 0.333, green: 0.8, blue: 0.333)     // #55CC55
        case .cyan:   return Color(red: 0.333, green: 0.8, blue: 0.8)       // #55CCCC
        case .blue:   return Color(red: 0.333, green: 0.533, blue: 0.933)   // #5588EE
        case .purple: return Color(red: 0.667, green: 0.333, blue: 0.8)     // #AA55CC
        case .pink:   return Color(red: 1.0, green: 0.533, blue: 0.667)     // #FF88AA
        }
    }

    /// Display name for UI.
    var displayName: String {
        rawValue.capitalized
    }

    /// Export name for Avid (lowercase, with pink mapped to magenta).
    var avidColorName: String {
        switch self {
        case .pink: return "magenta"
        case .orange, .purple: return "" // Not supported in Avid
        default: return rawValue
        }
    }

    /// Export name for DaVinci Resolve (capitalized).
    var resolveColorName: String {
        rawValue.capitalized
    }

    /// Export name for Avid with fallback for unsupported colors.
    /// Orange maps to yellow, purple maps to blue.
    var avidExportColorName: String {
        if avidColorName.isEmpty {
            // Provide fallback for unsupported colors
            return self == .orange ? "yellow" : "blue"
        }
        return avidColorName
    }
}

/// A marker representing a point of interest in the video timeline.
struct Marker: Identifiable, Equatable, Codable {
    /// Unique identifier for the marker.
    let id: UUID

    /// Position in the video as a frame count (consistent with In/Out point storage).
    var timecodeFrames: Int

    /// Marker color for visual identification and export.
    var color: MarkerColor

    /// User note/comment for the marker.
    var note: String

    /// Timestamp when the marker was created.
    let createdAt: Date

    /// Creates a new marker at the specified frame position.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - timecodeFrames: Frame position in the video.
    ///   - color: Marker color (defaults to blue).
    ///   - note: Note text (defaults to empty).
    ///   - createdAt: Creation timestamp (defaults to now).
    init(
        id: UUID = UUID(),
        timecodeFrames: Int,
        color: MarkerColor = .blue,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.timecodeFrames = timecodeFrames
        self.color = color
        self.note = note
        self.createdAt = createdAt
    }
}
