import SwiftUI

/// Compact popover view for editing a marker's color and note.
/// Designed to appear over the video player area like in an NLE.
struct MarkerEditorPopover: View {
    @ObservedObject var markerVM: MarkerListViewModel
    let frameRate: FrameRate
    let startTimecodeFrames: Int

    // Local editing state
    @State private var editedNote: String = ""
    @State private var editedColor: MarkerColor = .blue

    var body: some View {
        VStack(spacing: 12) {
            // Header with timecode and close button
            HStack {
                if let marker = markerVM.editingMarker {
                    Text(timecodeText(for: marker))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Spacer()

                Button(action: { markerVM.closeEditor() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Color picker row (all 8 colors in one row)
            HStack(spacing: 6) {
                ForEach(MarkerColor.allCases, id: \.self) { color in
                    colorButton(color)
                }
            }

            // Note text field
            TextField("Add note...", text: $editedNote, onCommit: saveMarker)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            // Action buttons
            HStack(spacing: 8) {
                Button(action: deleteMarker) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete marker")

                Spacer()

                Button("Done") {
                    saveMarker()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return)
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            loadMarkerValues()
        }
        .onChange(of: markerVM.editingMarker) { _ in
            loadMarkerValues()
        }
    }

    // MARK: - Color Picker

    private func colorButton(_ color: MarkerColor) -> some View {
        Button(action: {
            editedColor = color
            // Auto-save color change
            if var marker = markerVM.editingMarker {
                marker.color = color
                markerVM.updateMarker(marker)
            }
        }) {
            Circle()
                .fill(color.displayColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: editedColor == color ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
        .help(color.displayName)
    }

    // MARK: - Helpers

    private func timecodeText(for marker: Marker) -> String {
        let displayFrames = marker.timecodeFrames + startTimecodeFrames
        return Timecode(frames: displayFrames, frameRate: frameRate).formatted()
    }

    private func loadMarkerValues() {
        if let marker = markerVM.editingMarker {
            editedNote = marker.note
            editedColor = marker.color
        }
    }

    private func saveMarker() {
        guard var marker = markerVM.editingMarker else { return }
        marker.note = editedNote
        marker.color = editedColor
        markerVM.updateMarker(marker)
        markerVM.closeEditor()
    }

    private func deleteMarker() {
        if let marker = markerVM.editingMarker {
            markerVM.deleteMarker(id: marker.id)
            markerVM.closeEditor()
        }
    }
}

#Preview {
    let markerVM = MarkerListViewModel()
    let _ = markerVM.addMarker(at: 1440, color: .red, note: "Test note")
    if let marker = markerVM.markers.first {
        markerVM.openEditor(for: marker)
    }

    return ZStack {
        Color.black
        MarkerEditorPopover(
            markerVM: markerVM,
            frameRate: .fps24,
            startTimecodeFrames: 0
        )
    }
    .frame(width: 400, height: 300)
    .preferredColorScheme(.dark)
}
