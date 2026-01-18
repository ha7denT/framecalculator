import SwiftUI

/// A row displaying a single marker in the marker list.
struct MarkerRowView: View {
    let marker: Marker
    let frameRate: FrameRate
    let startTimecodeFrames: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    /// Accessibility description for the marker row
    private var accessibilityDescription: String {
        var description = "\(marker.color.displayName) marker at \(timecodeText)"
        if !marker.note.isEmpty {
            description += ", \(marker.note)"
        }
        return description
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator circle
            Circle()
                .fill(marker.color.displayColor)
                .frame(width: 10, height: 10)

            // Timecode display
            Text(timecodeText)
                .font(.spaceMono(size: 12, weight: .bold))
                .foregroundColor(.primary)

            // Note text (truncated)
            Text(marker.note.isEmpty ? "No note" : marker.note)
                .font(.system(size: 11))
                .foregroundColor(marker.note.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(count: 1, perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Tap to seek, double-tap to edit")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Formats the marker's frame position as a timecode string.
    private var timecodeText: String {
        let displayFrames = marker.timecodeFrames + startTimecodeFrames
        return Timecode(frames: displayFrames, frameRate: frameRate).formatted()
    }
}

#Preview {
    VStack(spacing: 4) {
        MarkerRowView(
            marker: Marker(timecodeFrames: 0, color: .red, note: "Scene start"),
            frameRate: .fps24,
            startTimecodeFrames: 0,
            isSelected: false,
            onTap: {},
            onDoubleTap: {}
        )

        MarkerRowView(
            marker: Marker(timecodeFrames: 1440, color: .blue, note: ""),
            frameRate: .fps24,
            startTimecodeFrames: 0,
            isSelected: true,
            onTap: {},
            onDoubleTap: {}
        )

        MarkerRowView(
            marker: Marker(timecodeFrames: 2880, color: .green, note: "VFX shot - needs cleanup and review"),
            frameRate: .fps24,
            startTimecodeFrames: 0,
            isSelected: false,
            onTap: {},
            onDoubleTap: {}
        )
    }
    .padding()
    .frame(width: 300)
    .preferredColorScheme(.dark)
}
