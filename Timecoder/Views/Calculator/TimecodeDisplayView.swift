import SwiftUI

/// Large timecode display with monospace font, glass effect, and selection support.
struct TimecodeDisplayView: View {
    let timecode: String
    let frameCount: Int
    let showFrameCount: Bool
    let hasError: Bool
    let isPendingOperation: Bool
    var invalidComponents: Set<TimecodeComponent> = []

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Main timecode display with glass effect
            displayContent
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(in: .rect(cornerRadius: 12))
                .tint(tintColor)

            // Secondary frame count display
            if showFrameCount {
                HStack(spacing: 4) {
                    Text("\(frameCount)")
                        .font(.spaceMono(size: 12))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    Text("frames")
                        .font(.spaceMono(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.trailing, 16)
            }
        }
    }

    /// Tint color for glass effect based on state
    private var tintColor: Color? {
        if hasError {
            return .red
        } else if !invalidComponents.isEmpty {
            return .orange
        } else if isPendingOperation {
            return .accentColor
        }
        return nil
    }

    /// Whether the display is showing frame count (ends with "f")
    private var isFrameDisplay: Bool {
        timecode.hasSuffix("f")
    }

    /// The frame number portion (without the "f" suffix)
    private var frameNumber: String {
        String(timecode.dropLast())
    }

    /// The main display content with appropriate text selection behavior
    @ViewBuilder
    private var displayContent: some View {
        if isFrameDisplay {
            // Frame mode - separate number from "f" suffix for selection
            HStack(spacing: 0) {
                Text(frameNumber)
                    .font(.spaceMono(size: 36))
                    .foregroundColor(hasError ? .red : .primary)
                    .textSelection(.enabled)
                Text("f")
                    .font(.spaceMono(size: 36))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        } else if invalidComponents.isEmpty {
            // Simple case - text selection enabled for normal display
            Text(timecode)
                .font(.spaceMono(size: 36))
                .foregroundColor(hasError ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
        } else {
            // Complex case with colored components - text selection disabled to avoid crash
            coloredTimecodeText
                .font(.spaceMono(size: 36))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    /// Builds timecode with different colors for invalid components
    private var coloredTimecodeText: Text {
        // Parse timecode string (format: HH:MM:SS:FF or HH:MM:SS;FF)
        let parts = parseTimecode(timecode)

        let hoursColor: Color = invalidComponents.contains(.hours) ? .orange : .primary
        let minutesColor: Color = invalidComponents.contains(.minutes) ? .orange : .primary
        let secondsColor: Color = invalidComponents.contains(.seconds) ? .orange : .primary
        let framesColor: Color = invalidComponents.contains(.frames) ? .orange : .primary

        return Text(parts.hours).foregroundColor(hoursColor) +
               Text(":").foregroundColor(.primary) +
               Text(parts.minutes).foregroundColor(minutesColor) +
               Text(":").foregroundColor(.primary) +
               Text(parts.seconds).foregroundColor(secondsColor) +
               Text(parts.separator).foregroundColor(.primary) +
               Text(parts.frames).foregroundColor(framesColor)
    }

    /// Parses a timecode string into its components
    private func parseTimecode(_ tc: String) -> (hours: String, minutes: String, seconds: String, frames: String, separator: String) {
        // Handle both : and ; separators
        let hasSemicolon = tc.contains(";")
        let normalized = tc.replacingOccurrences(of: ";", with: ":")
        let components = normalized.split(separator: ":").map(String.init)

        guard components.count == 4 else {
            return ("00", "00", "00", "00", ":")
        }

        return (components[0], components[1], components[2], components[3], hasSemicolon ? ";" : ":")
    }
}

/// Preview for TimecodeDisplayView
#Preview("Normal") {
    TimecodeDisplayView(
        timecode: "01:23:45:12",
        frameCount: 123456,
        showFrameCount: true,
        hasError: false,
        isPendingOperation: false
    )
    .padding()
    .frame(width: 300)
}

#Preview("Error State") {
    TimecodeDisplayView(
        timecode: "01:23:45:12",
        frameCount: 0,
        showFrameCount: false,
        hasError: true,
        isPendingOperation: false
    )
    .padding()
    .frame(width: 300)
}

#Preview("Pending Operation") {
    TimecodeDisplayView(
        timecode: "01:00:00:00",
        frameCount: 86400,
        showFrameCount: true,
        hasError: false,
        isPendingOperation: true
    )
    .padding()
    .frame(width: 300)
}

#Preview("Invalid Entry") {
    TimecodeDisplayView(
        timecode: "00:06:75:30",
        frameCount: 0,
        showFrameCount: false,
        hasError: false,
        isPendingOperation: false,
        invalidComponents: [.seconds, .frames]
    )
    .padding()
    .frame(width: 300)
}
