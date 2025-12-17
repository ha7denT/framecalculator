import SwiftUI

/// Timeline scrubber with playhead indicator for video navigation.
struct TimelineView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    /// Whether the user is currently dragging the playhead.
    @State private var isDragging = false

    /// The drag position during scrubbing (0.0 to 1.0).
    @State private var dragProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 4)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geometry), height: 4)

                // Playhead
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: playheadOffset(in: geometry))
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value: value, in: geometry)
                    }
                    .onEnded { value in
                        handleDragEnd(value: value, in: geometry)
                    }
            )
        }
        .frame(height: 20)
    }

    // MARK: - Layout Helpers

    private var displayProgress: Double {
        isDragging ? dragProgress : viewModel.progress
    }

    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        CGFloat(displayProgress) * geometry.size.width
    }

    private func playheadOffset(in geometry: GeometryProxy) -> CGFloat {
        let progress = CGFloat(displayProgress)
        let trackWidth = geometry.size.width
        // Center the playhead on the progress point
        return (progress * trackWidth) - 6
    }

    // MARK: - Gesture Handlers

    private func handleDrag(value: DragGesture.Value, in geometry: GeometryProxy) {
        isDragging = true

        let progress = value.location.x / geometry.size.width
        dragProgress = max(0, min(1, progress))

        // Seek while dragging for live preview
        viewModel.seek(toProgress: dragProgress)
    }

    private func handleDragEnd(value: DragGesture.Value, in geometry: GeometryProxy) {
        let progress = value.location.x / geometry.size.width
        let finalProgress = max(0, min(1, progress))

        viewModel.seek(toProgress: finalProgress)
        isDragging = false
    }
}

/// Extended timeline view with timecode display.
struct TimelineWithTimecode: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(viewModel: viewModel)

            HStack {
                // Current timecode
                Text(viewModel.currentTimecode.formatted())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                // Duration
                Text(viewModel.durationTimecode.formatted())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        TimelineView(viewModel: VideoPlayerViewModel())

        TimelineWithTimecode(viewModel: VideoPlayerViewModel())
    }
    .padding()
    .frame(width: 400)
    .preferredColorScheme(.dark)
}
