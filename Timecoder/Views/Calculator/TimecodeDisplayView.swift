import SwiftUI

/// Large timecode display with monospace font and selection support.
struct TimecodeDisplayView: View {
    let timecode: String
    let frameCount: Int
    let showFrameCount: Bool
    let hasError: Bool
    let isPendingOperation: Bool
    var invalidComponents: Set<TimecodeComponent> = []

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Main timecode display
            displayContent
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            borderColor,
                            lineWidth: 2
                        )
                )

            // Secondary frame count display
            if showFrameCount {
                Text("\(frameCount) frames")
                    .font(.spaceMono(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
        }
    }

    /// The border color based on validation state
    private var borderColor: Color {
        if hasError {
            return .red.opacity(0.7)
        } else if !invalidComponents.isEmpty {
            return .timecoderOrange.opacity(0.7)
        } else if isPendingOperation {
            return .timecoderTeal.opacity(0.5)
        }
        return .clear
    }

    /// The main display content with appropriate text selection behavior
    @ViewBuilder
    private var displayContent: some View {
        if invalidComponents.isEmpty {
            // Simple case - text selection enabled for normal display
            Text(timecode)
                .font(.spaceMono(size: 48))
                .foregroundColor(hasError ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
        } else {
            // Complex case with colored components - text selection disabled to avoid crash
            coloredTimecodeText
                .font(.spaceMono(size: 48))
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
    .frame(width: 320)
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
    .frame(width: 320)
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
    .frame(width: 320)
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
    .frame(width: 320)
}
