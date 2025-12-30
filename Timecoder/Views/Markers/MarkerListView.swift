import SwiftUI

/// Panel displaying the list of markers with controls for adding and managing markers.
struct MarkerListView: View {
    @ObservedObject var markerVM: MarkerListViewModel
    @ObservedObject var playerVM: VideoPlayerViewModel
    let onAddMarker: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and count
            markerListHeader

            Divider()

            if markerVM.sortedMarkers.isEmpty {
                emptyState
            } else {
                // Scrollable marker list
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(markerVM.sortedMarkers) { marker in
                            MarkerRowView(
                                marker: marker,
                                frameRate: playerVM.frameRate,
                                startTimecodeFrames: playerVM.startTimecodeFrames,
                                isSelected: markerVM.selectedMarkerID == marker.id,
                                onTap: { handleMarkerTap(marker) },
                                onDoubleTap: { handleMarkerDoubleTap(marker) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            // Keyboard hints footer
            keyboardHints
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Header

    private var markerListHeader: some View {
        HStack {
            Text("Markers")
                .font(.headline)

            Text("(\(markerVM.markers.count))")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Add marker button
            Button(action: onAddMarker) {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .help("Add marker at playhead (M)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("No markers")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Press M to add a marker")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Keyboard Hints

    private var keyboardHints: some View {
        HStack(spacing: 12) {
            Text("M = Add")
            Text("Del = Remove")
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary.opacity(0.7))
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func handleMarkerTap(_ marker: Marker) {
        // Select marker and seek player to that position
        markerVM.selectMarker(id: marker.id)
        playerVM.seek(toFrame: marker.timecodeFrames)
    }

    private func handleMarkerDoubleTap(_ marker: Marker) {
        // Open editor for the marker
        markerVM.openEditor(for: marker)
    }
}

#Preview {
    let markerVM = MarkerListViewModel()
    let playerVM = VideoPlayerViewModel()

    // Add some test markers
    markerVM.addMarker(at: 0, color: .red, note: "Scene start")
    markerVM.addMarker(at: 1440, color: .blue, note: "")
    markerVM.addMarker(at: 2880, color: .green, note: "VFX shot")

    return VStack {
        MarkerListView(
            markerVM: markerVM,
            playerVM: playerVM,
            onAddMarker: {}
        )
        .frame(height: 200)
        .padding()
    }
    .frame(width: 320)
    .preferredColorScheme(.dark)
}
