import SwiftUI

/// Display mode for the timecode display.
enum TimecodeDisplayMode {
    case timecode   // Show timecode large, frame count below
    case frames     // Show frame count large, timecode below
}

/// Large timecode display with monospace font, glass effect, and selection support.
/// Shows primary value large with secondary value below (always shows both).
struct TimecodeDisplayView: View {
    let formattedTimecode: String
    let frameCount: Int
    let displayMode: TimecodeDisplayMode
    let hasError: Bool
    let isPendingOperation: Bool
    var invalidComponents: Set<TimecodeComponent> = []

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Main display with glass effect
            primaryDisplay
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(in: .rect(cornerRadius: 12))
                .tint(tintColor)

            // Secondary display (always shown)
            secondaryDisplay
                .padding(.trailing, 16)
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

    /// Primary display content based on mode
    @ViewBuilder
    private var primaryDisplay: some View {
        switch displayMode {
        case .timecode:
            timecodeText
        case .frames:
            frameCountText
        }
    }

    /// Secondary display content based on mode
    @ViewBuilder
    private var secondaryDisplay: some View {
        switch displayMode {
        case .timecode:
            // Show frame count below timecode
            HStack(spacing: 4) {
                Text("\(frameCount)")
                    .font(.spaceMono(size: 12))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                Text("frames")
                    .font(.spaceMono(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        case .frames:
            // Show timecode below frame count
            Text(formattedTimecode)
                .font(.spaceMono(size: 12))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }

    /// Large timecode display
    @ViewBuilder
    private var timecodeText: some View {
        if invalidComponents.isEmpty {
            Text(formattedTimecode)
                .font(.spaceMono(size: 36))
                .foregroundColor(hasError ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
        } else {
            coloredTimecodeText
                .font(.spaceMono(size: 36))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    /// Large frame count display
    private var frameCountText: some View {
        Text("\(frameCount)")
            .font(.spaceMono(size: 36))
            .foregroundColor(hasError ? .red : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .textSelection(.enabled)
    }

    /// Builds timecode with different colors for invalid components
    @ViewBuilder
    private var coloredTimecodeText: some View {
        let parts = parseTimecode(formattedTimecode)

        let hoursColor: Color = invalidComponents.contains(.hours) ? .orange : .primary
        let minutesColor: Color = invalidComponents.contains(.minutes) ? .orange : .primary
        let secondsColor: Color = invalidComponents.contains(.seconds) ? .orange : .primary
        let framesColor: Color = invalidComponents.contains(.frames) ? .orange : .primary

        HStack(spacing: 0) {
            Text(parts.hours).foregroundColor(hoursColor)
            Text(":").foregroundColor(.primary)
            Text(parts.minutes).foregroundColor(minutesColor)
            Text(":").foregroundColor(.primary)
            Text(parts.seconds).foregroundColor(secondsColor)
            Text(parts.separator).foregroundColor(.primary)
            Text(parts.frames).foregroundColor(framesColor)
        }
    }

    /// Parses a timecode string into its components
    private func parseTimecode(_ tc: String) -> (hours: String, minutes: String, seconds: String, frames: String, separator: String) {
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
#Preview("Timecode Mode") {
    TimecodeDisplayView(
        formattedTimecode: "01:23:45:12",
        frameCount: 123456,
        displayMode: .timecode,
        hasError: false,
        isPendingOperation: false
    )
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}

#Preview("Frames Mode") {
    TimecodeDisplayView(
        formattedTimecode: "00:00:00:06",
        frameCount: 6,
        displayMode: .frames,
        hasError: false,
        isPendingOperation: false
    )
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}

#Preview("Error State") {
    TimecodeDisplayView(
        formattedTimecode: "01:23:45:12",
        frameCount: 0,
        displayMode: .timecode,
        hasError: true,
        isPendingOperation: false
    )
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}

#Preview("Pending Operation") {
    TimecodeDisplayView(
        formattedTimecode: "01:00:00:00",
        frameCount: 86400,
        displayMode: .timecode,
        hasError: false,
        isPendingOperation: true
    )
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}

#Preview("Invalid Entry") {
    TimecodeDisplayView(
        formattedTimecode: "00:06:75:30",
        frameCount: 0,
        displayMode: .timecode,
        hasError: false,
        isPendingOperation: false,
        invalidComponents: [.seconds, .frames]
    )
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}
