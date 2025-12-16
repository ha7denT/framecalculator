import Foundation

/// A timecode value representing a position or duration in video.
/// Internally stored as a frame count with an associated frame rate.
/// Supports drop frame display format for 29.97 DF.
struct Timecode: Equatable, Hashable, Codable {
    /// The total frame count. Can be negative for durations.
    let frames: Int

    /// The frame rate used for display and calculations.
    let frameRate: FrameRate

    /// Creates a timecode from a frame count and frame rate.
    init(frames: Int, frameRate: FrameRate) {
        self.frames = frames
        self.frameRate = frameRate
    }

    /// Creates a timecode from individual components.
    /// For drop frame rates, the frame numbers are interpreted as drop frame display values.
    init(hours: Int, minutes: Int, seconds: Int, frames: Int, frameRate: FrameRate) {
        let totalFrames = Self.framesTotalFromComponents(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            frames: frames,
            frameRate: frameRate
        )
        self.frames = totalFrames
        self.frameRate = frameRate
    }

    // MARK: - Components

    /// Whether the timecode represents a negative duration.
    var isNegative: Bool {
        frames < 0
    }

    /// The absolute frame count (always positive).
    private var absoluteFrames: Int {
        abs(frames)
    }

    /// The components of the timecode (hours, minutes, seconds, frames).
    /// For drop frame, these are the display values with frame skipping applied.
    var components: (hours: Int, minutes: Int, seconds: Int, frames: Int) {
        componentsFromFrames(absoluteFrames, frameRate: frameRate)
    }

    /// The hours component of the timecode.
    var hours: Int { components.hours }

    /// The minutes component of the timecode (0-59).
    var minutes: Int { components.minutes }

    /// The seconds component of the timecode (0-59).
    var seconds: Int { components.seconds }

    /// The frames component of the timecode (0 to nominal frame rate - 1).
    var frameComponent: Int { components.frames }

    // MARK: - Drop Frame Calculation

    /// Number of frames dropped per minute for drop frame timecode.
    /// 29.97 DF drops 2 frames (00 and 01) at the start of each minute except every 10th.
    private static let dropFramesPerMinute = 2

    /// Converts a frame count to timecode components, handling drop frame.
    private func componentsFromFrames(_ totalFrames: Int, frameRate: FrameRate) -> (hours: Int, minutes: Int, seconds: Int, frames: Int) {
        let nominal = frameRate.nominalFrameRate

        if frameRate.isDropFrame {
            return dropFrameComponents(from: totalFrames, nominalRate: nominal)
        } else {
            return nonDropFrameComponents(from: totalFrames, nominalRate: nominal)
        }
    }

    /// Calculates timecode components for non-drop frame rates.
    private func nonDropFrameComponents(from totalFrames: Int, nominalRate: Int) -> (hours: Int, minutes: Int, seconds: Int, frames: Int) {
        let framesPerSecond = nominalRate
        let framesPerMinute = framesPerSecond * 60
        let framesPerHour = framesPerMinute * 60

        let hours = totalFrames / framesPerHour
        let remainingAfterHours = totalFrames % framesPerHour

        let minutes = remainingAfterHours / framesPerMinute
        let remainingAfterMinutes = remainingAfterHours % framesPerMinute

        let seconds = remainingAfterMinutes / framesPerSecond
        let frames = remainingAfterMinutes % framesPerSecond

        return (hours, minutes, seconds, frames)
    }

    /// Calculates timecode components for drop frame rates (29.97 DF).
    /// Drop frame skips frame numbers 00 and 01 at the start of each minute,
    /// except for every 10th minute (00, 10, 20, 30, 40, 50).
    ///
    /// Algorithm: Calculate total dropped frames, add back to get display frame number,
    /// then convert to HH:MM:SS:FF using standard NDF math.
    private func dropFrameComponents(from totalFrames: Int, nominalRate: Int) -> (hours: Int, minutes: Int, seconds: Int, frames: Int) {
        let dropFrames = Self.dropFramesPerMinute  // 2
        let framesPerSecond = nominalRate  // 30
        let framesPerMinute = framesPerSecond * 60  // 1800

        // Frames per 10-minute block (accounting for 9 drops of 2 frames each)
        let framesPerTenMinutes = framesPerMinute * 10 - dropFrames * 9  // 17982

        // Calculate how many frame numbers have been skipped by this point
        let tenMinuteBlocks = totalFrames / framesPerTenMinutes
        let remainingInBlock = totalFrames % framesPerTenMinutes

        // Drops from complete 10-minute blocks (9 drops per block)
        var totalDrops = tenMinuteBlocks * 9 * dropFrames

        // Handle drops within the current 10-minute block
        if remainingInBlock >= framesPerMinute {
            // Past the first minute (which has no drop)
            let afterFirstMinute = remainingInBlock - framesPerMinute
            let framesPerDropMinute = framesPerMinute - dropFrames  // 1798

            // Each additional minute (1-9) has a drop
            let additionalMinutes = afterFirstMinute / framesPerDropMinute
            totalDrops += (1 + additionalMinutes) * dropFrames
        }

        // Add dropped frames back to get display frame number
        let displayFrame = totalFrames + totalDrops

        // Now convert using simple NDF math
        let framesPerHour = framesPerMinute * 60

        let hours = displayFrame / framesPerHour
        let remainingAfterHours = displayFrame % framesPerHour

        let minutes = remainingAfterHours / framesPerMinute
        let remainingAfterMinutes = remainingAfterHours % framesPerMinute

        let seconds = remainingAfterMinutes / framesPerSecond
        let frames = remainingAfterMinutes % framesPerSecond

        return (hours, minutes, seconds, frames)
    }

    /// Converts timecode components to a frame count, handling drop frame.
    private static func framesTotalFromComponents(
        hours: Int,
        minutes: Int,
        seconds: Int,
        frames: Int,
        frameRate: FrameRate
    ) -> Int {
        let nominal = frameRate.nominalFrameRate

        if frameRate.isDropFrame {
            return dropFrameToFrames(hours: hours, minutes: minutes, seconds: seconds, frames: frames, nominalRate: nominal)
        } else {
            return nonDropFrameToFrames(hours: hours, minutes: minutes, seconds: seconds, frames: frames, nominalRate: nominal)
        }
    }

    /// Converts non-drop frame timecode components to frame count.
    private static func nonDropFrameToFrames(
        hours: Int,
        minutes: Int,
        seconds: Int,
        frames: Int,
        nominalRate: Int
    ) -> Int {
        let framesPerSecond = nominalRate
        let framesPerMinute = framesPerSecond * 60
        let framesPerHour = framesPerMinute * 60

        return hours * framesPerHour + minutes * framesPerMinute + seconds * framesPerSecond + frames
    }

    /// Converts drop frame timecode components to frame count.
    /// Accounts for the skipped frame numbers in the display.
    private static func dropFrameToFrames(
        hours: Int,
        minutes: Int,
        seconds: Int,
        frames: Int,
        nominalRate: Int
    ) -> Int {
        let framesPerSecond = nominalRate  // 30
        let dropFrames = dropFramesPerMinute  // 2

        // Calculate total minutes
        let totalMinutes = hours * 60 + minutes

        // Number of frame drops that have occurred
        // Drops happen every minute except every 10th minute
        let totalDrops = dropFrames * (totalMinutes - totalMinutes / 10)

        // Calculate frame count as if non-drop, then subtract the drops
        let framesPerMinute = framesPerSecond * 60
        let framesPerHour = framesPerMinute * 60

        let nonDropFrames = hours * framesPerHour + minutes * framesPerMinute + seconds * framesPerSecond + frames

        return nonDropFrames - totalDrops
    }

    // MARK: - Duration in Seconds

    /// The duration represented by this timecode in seconds.
    var durationInSeconds: Double {
        Double(frames) / frameRate.framesPerSecond
    }

    /// Creates a timecode from a duration in seconds.
    static func from(seconds: Double, frameRate: FrameRate) -> Timecode {
        let frames = Int((seconds * frameRate.framesPerSecond).rounded())
        return Timecode(frames: frames, frameRate: frameRate)
    }

    // MARK: - Frame Rate Conversion

    /// Converts this timecode to a different frame rate, preserving the frame count.
    /// Use this when the underlying media is the same but you want a different display rate.
    func converting(to newRate: FrameRate) -> Timecode {
        Timecode(frames: frames, frameRate: newRate)
    }

    /// Converts this timecode to a different frame rate, preserving the duration.
    /// Use this when you want the same real-world time at a different frame rate.
    func convertingDuration(to newRate: FrameRate) -> Timecode {
        let seconds = durationInSeconds
        return .from(seconds: seconds, frameRate: newRate)
    }
}

// MARK: - Arithmetic Operators

extension Timecode {
    /// Adds two timecodes. Both must have the same frame rate.
    static func + (lhs: Timecode, rhs: Timecode) -> Timecode {
        precondition(lhs.frameRate == rhs.frameRate, "Cannot add timecodes with different frame rates")
        return Timecode(frames: lhs.frames + rhs.frames, frameRate: lhs.frameRate)
    }

    /// Subtracts one timecode from another. Both must have the same frame rate.
    static func - (lhs: Timecode, rhs: Timecode) -> Timecode {
        precondition(lhs.frameRate == rhs.frameRate, "Cannot subtract timecodes with different frame rates")
        return Timecode(frames: lhs.frames - rhs.frames, frameRate: lhs.frameRate)
    }

    /// Multiplies a timecode duration by an integer factor.
    static func * (lhs: Timecode, rhs: Int) -> Timecode {
        Timecode(frames: lhs.frames * rhs, frameRate: lhs.frameRate)
    }

    /// Multiplies a timecode duration by an integer factor.
    static func * (lhs: Int, rhs: Timecode) -> Timecode {
        rhs * lhs
    }

    /// Negates a timecode (useful for representing negative durations).
    static prefix func - (timecode: Timecode) -> Timecode {
        Timecode(frames: -timecode.frames, frameRate: timecode.frameRate)
    }
}

// MARK: - Comparable

extension Timecode: Comparable {
    static func < (lhs: Timecode, rhs: Timecode) -> Bool {
        precondition(lhs.frameRate == rhs.frameRate, "Cannot compare timecodes with different frame rates")
        return lhs.frames < rhs.frames
    }
}

// MARK: - String Formatting

extension Timecode: CustomStringConvertible {
    /// The timecode formatted as a string (e.g., "01:02:03:04" or "01:02:03;04" for DF).
    var description: String {
        formatted()
    }

    /// Formats the timecode as a string.
    /// - Parameter alwaysShowSign: If true, shows "+" for positive timecodes.
    func formatted(alwaysShowSign: Bool = false) -> String {
        let sign: String
        if isNegative {
            sign = "-"
        } else if alwaysShowSign {
            sign = "+"
        } else {
            sign = ""
        }

        let (h, m, s, f) = components
        let separator = frameRate.isDropFrame ? ";" : ":"

        return String(format: "%@%02d:%02d:%02d%@%02d", sign, h, m, s, separator, f)
    }
}

// MARK: - String Parsing

extension Timecode {
    /// Error thrown when parsing an invalid timecode string.
    enum ParseError: Error, LocalizedError {
        case invalidFormat
        case invalidComponent(String)
        case componentOutOfRange(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid timecode format. Expected HH:MM:SS:FF or HH:MM:SS;FF"
            case .invalidComponent(let component):
                return "Invalid timecode component: \(component)"
            case .componentOutOfRange(let message):
                return "Timecode component out of range: \(message)"
            }
        }
    }

    /// Creates a timecode by parsing a string.
    /// Accepts formats: "HH:MM:SS:FF", "HH:MM:SS;FF" (drop frame), or just frame count.
    /// - Parameters:
    ///   - string: The timecode string to parse.
    ///   - frameRate: The frame rate to use. If the string uses ";" separator, 29.97 DF is inferred.
    init(_ string: String, frameRate: FrameRate) throws {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Check for negative
        let isNegative = trimmed.hasPrefix("-")
        let unsigned = isNegative ? String(trimmed.dropFirst()) : trimmed

        // Check if it's just a frame number
        if let frameCount = Int(unsigned) {
            let frames = isNegative ? -frameCount : frameCount
            self.init(frames: frames, frameRate: frameRate)
            return
        }

        // Parse timecode format
        // Accept : or ; as the final separator (before frames)
        let pattern = #"^(\d{1,2}):(\d{1,2}):(\d{1,2})[:;](\d{1,2})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: unsigned, range: NSRange(unsigned.startIndex..., in: unsigned)) else {
            throw ParseError.invalidFormat
        }

        guard let hoursRange = Range(match.range(at: 1), in: unsigned),
              let minutesRange = Range(match.range(at: 2), in: unsigned),
              let secondsRange = Range(match.range(at: 3), in: unsigned),
              let framesRange = Range(match.range(at: 4), in: unsigned) else {
            throw ParseError.invalidFormat
        }

        guard let hours = Int(unsigned[hoursRange]),
              let minutes = Int(unsigned[minutesRange]),
              let seconds = Int(unsigned[secondsRange]),
              let frames = Int(unsigned[framesRange]) else {
            throw ParseError.invalidFormat
        }

        // Validate ranges
        if minutes >= 60 {
            throw ParseError.componentOutOfRange("minutes must be 0-59")
        }
        if seconds >= 60 {
            throw ParseError.componentOutOfRange("seconds must be 0-59")
        }
        if frames >= frameRate.nominalFrameRate {
            throw ParseError.componentOutOfRange("frames must be 0-\(frameRate.nominalFrameRate - 1)")
        }

        let totalFrames = Self.framesTotalFromComponents(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            frames: frames,
            frameRate: frameRate
        )

        self.init(frames: isNegative ? -totalFrames : totalFrames, frameRate: frameRate)
    }
}

// MARK: - Zero Timecode

extension Timecode {
    /// A zero timecode at the given frame rate.
    static func zero(at frameRate: FrameRate) -> Timecode {
        Timecode(frames: 0, frameRate: frameRate)
    }
}
