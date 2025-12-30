import SwiftUI

/// Visual indicator for a marker on the timeline.
/// Displays as a small colored triangle pointing down with a vertical line.
struct TimelineMarkerView: View {
    let marker: Marker

    var body: some View {
        VStack(spacing: 0) {
            // Triangle indicator pointing down
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 6, y: 0))
                path.addLine(to: CGPoint(x: 3, y: 5))
                path.closeSubpath()
            }
            .fill(marker.color.displayColor)
            .frame(width: 6, height: 5)

            // Vertical line extending down
            Rectangle()
                .fill(marker.color.displayColor)
                .frame(width: 1, height: 11)
        }
        .frame(width: 6, height: 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Timeline Markers")
            .font(.headline)

        HStack(spacing: 20) {
            ForEach(MarkerColor.allCases, id: \.self) { color in
                VStack {
                    TimelineMarkerView(marker: Marker(timecodeFrames: 0, color: color))
                    Text(color.displayName)
                        .font(.caption2)
                }
            }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
