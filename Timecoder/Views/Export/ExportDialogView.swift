import SwiftUI
import AppKit

/// Dialog for selecting marker export format and saving to file.
struct ExportDialogView: View {
    @Binding var isPresented: Bool
    @State private var selectedFormat: MarkerExportFormat = .edl

    let markers: [Marker]
    let frameRate: FrameRate
    let sourceFilename: String

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Export Markers")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            // Format picker
            Picker("Format", selection: $selectedFormat) {
                ForEach(MarkerExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Export format")
            .accessibilityValue(selectedFormat.rawValue)
            .accessibilityHint("Select format for marker export")

            // Format info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target:")
                        .foregroundColor(.secondary)
                    Text(selectedFormat.targetApp)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Target application: \(selectedFormat.targetApp)")

                HStack {
                    Text("Markers:")
                        .foregroundColor(.secondary)
                    Text("\(markers.count)")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(markers.count) markers to export")

                HStack {
                    Text("Frame Rate:")
                        .foregroundColor(.secondary)
                    Text(frameRate.displayName)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Frame rate: \(frameRate.accessibilityName)")

                Text(selectedFormat.formatDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Format description: \(selectedFormat.formatDescription)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .accessibilityHidden(true)

            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel")
                .accessibilityHint("Closes dialog without exporting")

                Spacer()

                Button("Export...") {
                    exportMarkers()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(markers.isEmpty)
                .accessibilityLabel("Export")
                .accessibilityHint(markers.isEmpty ? "No markers to export" : "Opens save dialog to export \(markers.count) markers")
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    /// Shows save panel and exports markers.
    /// Note: We dismiss the sheet first, then show the save panel. NSSavePanel.runModal()
    /// doesn't work properly when called from within a SwiftUI sheet context.
    private func exportMarkers() {
        // Capture values before dismissing sheet
        let format = selectedFormat
        let filename = defaultFilename
        let markersToExport = markers
        let rate = frameRate
        let source = sourceFilename

        // Dismiss sheet first
        isPresented = false

        // Show save panel after sheet dismisses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [format.utType]
            panel.nameFieldStringValue = filename
            panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

            let response = panel.runModal()

            guard response == .OK, let url = panel.url else { return }

            // Export
            Task {
                let exporter = MarkerExporter()
                try? await exporter.export(
                    markers: markersToExport,
                    format: format,
                    to: url,
                    frameRate: rate,
                    sourceFilename: source
                )
            }
        }
    }

    /// Default filename for export.
    private var defaultFilename: String {
        let baseName = (sourceFilename as NSString).deletingPathExtension
        return "\(baseName)_markers.\(selectedFormat.fileExtension)"
    }
}

// MARK: - Preview

#if DEBUG
struct ExportDialogView_Previews: PreviewProvider {
    static var previews: some View {
        ExportDialogView(
            isPresented: .constant(true),
            markers: [
                Marker(timecodeFrames: 0, color: .red, note: "Start"),
                Marker(timecodeFrames: 1800, color: .blue, note: "Scene 2"),
                Marker(timecodeFrames: 3600, color: .green, note: "End")
            ],
            frameRate: .fps24,
            sourceFilename: "MyVideo.mov"
        )
        .preferredColorScheme(.dark)
    }
}
#endif
