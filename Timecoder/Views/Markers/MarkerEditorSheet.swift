import SwiftUI

/// Sheet view for editing a marker's color and note.
struct MarkerEditorPopover: View {
    @ObservedObject var markerVM: MarkerListViewModel
    let frameRate: FrameRate
    let startTimecodeFrames: Int

    // Local editing state
    @State private var editedNote: String = ""
    @State private var editedColor: MarkerColor = .blue

    var body: some View {
        VStack(spacing: 16) {
            // Header with timecode
            if let marker = markerVM.editingMarker {
                Text("Marker at \(timecodeText(for: marker))")
                    .font(.spaceMono(size: 14, weight: .bold))
            }

            // Color picker row (all 8 colors in one row)
            HStack(spacing: 8) {
                ForEach(MarkerColor.allCases, id: \.self) { color in
                    colorButton(color)
                }
            }

            // Note text field
            TextField("Add note...", text: $editedNote)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    saveMarker()
                }

            // Action buttons
            HStack(spacing: 12) {
                Button(role: .destructive, action: deleteMarker) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    markerVM.closeEditor()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)

                Button("Done") {
                    saveMarker()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            loadMarkerValues()
        }
        .onChange(of: markerVM.editingMarker) { _, _ in
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

    return MarkerEditorPopover(
        markerVM: markerVM,
        frameRate: .fps24,
        startTimecodeFrames: 0
    )
    .preferredColorScheme(.dark)
}
