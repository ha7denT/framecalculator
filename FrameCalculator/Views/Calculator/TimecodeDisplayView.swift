import SwiftUI

/// Large timecode display with monospace font and selection support.
struct TimecodeDisplayView: View {
    let timecode: String
    let frameCount: Int
    let showFrameCount: Bool
    let hasError: Bool
    let isPendingOperation: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Main timecode display
            Text(timecode)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(hasError ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
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
                            isPendingOperation ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )

            // Secondary frame count display
            if showFrameCount {
                Text("\(frameCount) frames")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
        }
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
