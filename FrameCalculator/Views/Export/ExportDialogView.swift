import SwiftUI
import AppKit

/// Dialog for selecting marker export format and saving to file.
struct ExportDialogView: View {
    @Binding var isPresented: Bool
    @State private var selectedFormat: MarkerExportFormat = .edl
    @State private var isExporting = false
    @State private var exportError: String?

    let markers: [Marker]
    let frameRate: FrameRate
    let sourceFilename: String

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Export Markers")
                .font(.headline)

            // Format picker
            Picker("Format", selection: $selectedFormat) {
                ForEach(MarkerExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Format info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Target:")
                        .foregroundColor(.secondary)
                    Text(selectedFormat.targetApp)
                }

                HStack {
                    Text("Markers:")
                        .foregroundColor(.secondary)
                    Text("\(markers.count)")
                }

                HStack {
                    Text("Frame Rate:")
                        .foregroundColor(.secondary)
                    Text(frameRate.displayName)
                }

                Text(selectedFormat.formatDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Error message
            if let error = exportError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export...") {
                    exportMarkers()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(markers.isEmpty || isExporting)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    /// Shows save panel and exports markers.
    private func exportMarkers() {
        isExporting = true
        exportError = nil

        // Capture values for use in Task
        let format = selectedFormat
        let filename = defaultFilename
        let markersToExport = markers
        let rate = frameRate
        let source = sourceFilename

        Task { @MainActor in
            // Show save panel on main thread
            let panel = NSSavePanel()
            panel.allowedContentTypes = [format.utType]
            panel.nameFieldStringValue = filename
            panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

            let response = panel.runModal()

            guard response == .OK, let url = panel.url else {
                isExporting = false
                return
            }

            // Export
            do {
                let exporter = MarkerExporter()
                try await exporter.export(
                    markers: markersToExport,
                    format: format,
                    to: url,
                    frameRate: rate,
                    sourceFilename: source
                )

                isExporting = false
                isPresented = false
            } catch {
                isExporting = false
                exportError = error.localizedDescription
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
