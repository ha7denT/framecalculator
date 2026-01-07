import SwiftUI

/// Timeline scrubber with playhead indicator for video navigation.
struct TimelineView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    /// Markers to display on the timeline.
    let markers: [Marker]

    /// Callback when a marker is tapped.
    var onMarkerTapped: ((Marker) -> Void)?

    /// Whether the user is currently dragging the playhead.
    @State private var isDragging = false

    /// The drag position during scrubbing (0.0 to 1.0).
    @State private var dragProgress: Double = 0

    /// Colors for In/Out point markers
    private let inPointColor = Color.orange
    private let outPointColor = Color.orange
    private let rangeColor = Color.orange.opacity(0.2)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 4)

                // In/Out range highlight (if both points set)
                if let inProgress = viewModel.inPointProgress,
                   let outProgress = viewModel.outPointProgress {
                    let startX = CGFloat(min(inProgress, outProgress)) * geometry.size.width
                    let endX = CGFloat(max(inProgress, outProgress)) * geometry.size.width
                    Rectangle()
                        .fill(rangeColor)
                        .frame(width: endX - startX, height: 8)
                        .offset(x: startX)
                }

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geometry), height: 4)

                // In point marker
                if let inProgress = viewModel.inPointProgress {
                    InOutMarker(type: .inPoint, color: inPointColor)
                        .offset(x: CGFloat(inProgress) * geometry.size.width - 4)
                }

                // Out point marker
                if let outProgress = viewModel.outPointProgress {
                    InOutMarker(type: .outPoint, color: outPointColor)
                        .offset(x: CGFloat(outProgress) * geometry.size.width - 4)
                }

                // Markers
                ForEach(markers) { marker in
                    let markerProgress = viewModel.totalFrames > 0
                        ? Double(marker.timecodeFrames) / Double(viewModel.totalFrames)
                        : 0
                    TimelineMarkerView(marker: marker)
                        .offset(x: CGFloat(markerProgress) * geometry.size.width - 3)
                        .contentShape(Rectangle().size(width: 16, height: 20))
                        .onTapGesture {
                            onMarkerTapped?(marker)
                        }
                }

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

    /// Markers to display on the timeline.
    let markers: [Marker]

    /// Callback when a marker is tapped.
    var onMarkerTapped: ((Marker) -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(viewModel: viewModel, markers: markers, onMarkerTapped: onMarkerTapped)

            HStack {
                // Current timecode
                Text(viewModel.currentTimecode.formatted())
                    .font(.spaceMono(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                // Marker hint when no markers exist
                if markers.isEmpty {
                    Text("Press M to add marker")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }

                Spacer()

                // Duration
                Text(viewModel.durationTimecode.formatted())
                    .font(.spaceMono(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - In/Out Point Marker

/// Visual marker for In or Out point on the timeline.
struct InOutMarker: View {
    enum MarkerType {
        case inPoint
        case outPoint
    }

    let type: MarkerType
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            // Triangle indicator pointing down
            Path { path in
                switch type {
                case .inPoint:
                    // Left-facing bracket shape: |>
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 16))
                    path.addLine(to: CGPoint(x: 6, y: 8))
                    path.closeSubpath()
                case .outPoint:
                    // Right-facing bracket shape: <|
                    path.move(to: CGPoint(x: 8, y: 0))
                    path.addLine(to: CGPoint(x: 8, y: 16))
                    path.addLine(to: CGPoint(x: 2, y: 8))
                    path.closeSubpath()
                }
            }
            .fill(color)
            .frame(width: 8, height: 16)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TimelineView(viewModel: VideoPlayerViewModel(), markers: [])

        TimelineWithTimecode(viewModel: VideoPlayerViewModel(), markers: [])

        // Preview In/Out markers
        HStack(spacing: 20) {
            InOutMarker(type: .inPoint, color: .yellow)
            InOutMarker(type: .outPoint, color: .yellow)
        }

        // Preview timeline markers
        HStack(spacing: 12) {
            ForEach(MarkerColor.allCases, id: \.self) { color in
                TimelineMarkerView(marker: Marker(timecodeFrames: 0, color: color))
            }
        }
    }
    .padding()
    .frame(width: 400)
    .preferredColorScheme(.dark)
}
