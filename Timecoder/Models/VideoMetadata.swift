import Foundation
import AVFoundation

/// Represents metadata extracted from a video file.
public struct VideoMetadata: Equatable {

    /// The source file URL.
    public let url: URL

    /// Video duration in seconds.
    public let duration: Double

    /// Video codec name (e.g., "H.264", "ProRes 422").
    public let codec: String

    /// Video bitrate in bits per second, if available.
    public let bitrate: Int?

    /// Video frame dimensions.
    public let resolution: CGSize

    /// Detected frame rate in frames per second.
    public let detectedFrameRate: Double

    /// Color space (e.g., "Rec. 709", "Rec. 2020").
    public let colorSpace: String?

    /// Number of audio channels.
    public let audioChannels: Int

    /// File size in bytes.
    public let fileSize: Int64

    /// Whether the video has embedded timecode.
    /// If false, timecode will be calculated from elapsed time starting at 00:00:00:00.
    public let hasEmbeddedTimecode: Bool

    /// The start timecode if embedded timecode exists (in frames).
    public let startTimecodeFrames: Int?

    // MARK: - Computed Properties

    /// Filename without path.
    public var filename: String {
        url.lastPathComponent
    }

    /// File size formatted for display (KB, MB, GB).
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Bitrate formatted for display (Mbps).
    public var formattedBitrate: String? {
        guard let bitrate = bitrate else { return nil }
        let mbps = Double(bitrate) / 1_000_000.0
        return String(format: "%.1f Mbps", mbps)
    }

    /// Resolution formatted as "Width × Height".
    public var formattedResolution: String {
        "\(Int(resolution.width)) × \(Int(resolution.height))"
    }

    /// Frame rate formatted for display.
    public var formattedFrameRate: String {
        // Check for common frame rates and display appropriately
        let fps = detectedFrameRate

        if abs(fps - 23.976) < 0.01 {
            return "23.976 fps"
        } else if abs(fps - 24.0) < 0.01 {
            return "24 fps"
        } else if abs(fps - 25.0) < 0.01 {
            return "25 fps"
        } else if abs(fps - 29.97) < 0.01 {
            return "29.97 fps"
        } else if abs(fps - 30.0) < 0.01 {
            return "30 fps"
        } else if abs(fps - 50.0) < 0.01 {
            return "50 fps"
        } else if abs(fps - 59.94) < 0.01 {
            return "59.94 fps"
        } else if abs(fps - 60.0) < 0.01 {
            return "60 fps"
        } else {
            return String(format: "%.2f fps", fps)
        }
    }

    /// Duration formatted as timecode string at detected frame rate.
    public var formattedDuration: String {
        let frameRate = matchingFrameRate
        let totalFrames = Int(duration * frameRate.framesPerSecond)
        let timecode = Timecode(frames: totalFrames, frameRate: frameRate)
        return timecode.formatted()
    }

    /// Description of the timecode source for UI display.
    public var timecodeSourceDescription: String {
        hasEmbeddedTimecode ? "Source Timecode" : "Elapsed Time"
    }

    /// Start timecode formatted, or "00:00:00:00" if using elapsed time.
    public var formattedStartTimecode: String {
        let frameRate = matchingFrameRate
        if let startFrames = startTimecodeFrames {
            let timecode = Timecode(frames: startFrames, frameRate: frameRate)
            return timecode.formatted()
        }
        return Timecode.zero(at: frameRate).formatted()
    }

    /// Audio channels formatted for display.
    public var formattedAudioChannels: String {
        switch audioChannels {
        case 0:
            return "No Audio"
        case 1:
            return "Mono"
        case 2:
            return "Stereo"
        case 6:
            return "5.1 Surround"
        case 8:
            return "7.1 Surround"
        default:
            return "\(audioChannels) channels"
        }
    }

    /// Maps the detected frame rate to the closest FrameRate enum value.
    public var matchingFrameRate: FrameRate {
        let fps = detectedFrameRate

        // Match to standard rates with tolerance
        if abs(fps - 23.976) < 0.01 || abs(fps - (24000.0 / 1001.0)) < 0.001 {
            return .fps23_976
        } else if abs(fps - 24.0) < 0.01 {
            return .fps24
        } else if abs(fps - 25.0) < 0.01 {
            return .fps25
        } else if abs(fps - 29.97) < 0.01 || abs(fps - (30000.0 / 1001.0)) < 0.001 {
            // Default to NDF for 29.97 (user can change to DF if needed)
            return .fps29_97_ndf
        } else if abs(fps - 30.0) < 0.01 {
            return .fps30
        } else if abs(fps - 50.0) < 0.01 {
            return .fps50
        } else if abs(fps - 59.94) < 0.01 || abs(fps - (60000.0 / 1001.0)) < 0.001 {
            return .fps59_94
        } else if abs(fps - 60.0) < 0.01 {
            return .fps60
        } else {
            return .custom(fps)
        }
    }
}
