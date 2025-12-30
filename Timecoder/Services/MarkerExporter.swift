import Foundation
import UniformTypeIdentifiers

/// Export format options for markers.
enum MarkerExportFormat: String, CaseIterable, Identifiable {
    case edl = "EDL"
    case avidText = "Avid"
    case csv = "CSV"

    var id: String { rawValue }

    /// File extension for this format.
    var fileExtension: String {
        switch self {
        case .edl: return "edl"
        case .avidText: return "txt"
        case .csv: return "csv"
        }
    }

    /// UTType for file save panel.
    var utType: UTType {
        switch self {
        case .edl: return UTType(filenameExtension: "edl") ?? .plainText
        case .avidText: return .plainText
        case .csv: return .commaSeparatedText
        }
    }

    /// Human-readable description of the format.
    var formatDescription: String {
        switch self {
        case .edl: return "Edit Decision List for DaVinci Resolve timeline markers"
        case .avidText: return "Tab-delimited text for Avid Media Composer Marker Tool"
        case .csv: return "Comma-separated values for spreadsheets and other applications"
        }
    }

    /// Target application name.
    var targetApp: String {
        switch self {
        case .edl: return "DaVinci Resolve"
        case .avidText: return "Avid Media Composer"
        case .csv: return "Spreadsheets / Other"
        }
    }
}

/// Errors that can occur during marker export.
enum MarkerExportError: LocalizedError {
    case noMarkers
    case writeError(Error)

    var errorDescription: String? {
        switch self {
        case .noMarkers:
            return "No markers to export."
        case .writeError(let error):
            return "Failed to write file: \(error.localizedDescription)"
        }
    }
}

/// Service for exporting markers to various NLE formats.
actor MarkerExporter {

    init() {}

    /// Exports markers to a file in the specified format.
    /// - Parameters:
    ///   - markers: The markers to export (will be sorted by timecode).
    ///   - format: The export format (EDL, Avid, CSV).
    ///   - url: The destination file URL.
    ///   - frameRate: The frame rate for timecode display.
    ///   - sourceFilename: The name of the source video file.
    /// - Throws: MarkerExportError if export fails.
    func export(
        markers: [Marker],
        format: MarkerExportFormat,
        to url: URL,
        frameRate: FrameRate,
        sourceFilename: String
    ) async throws {
        guard !markers.isEmpty else {
            throw MarkerExportError.noMarkers
        }

        // Sort markers by timecode
        let sortedMarkers = markers.sorted { $0.timecodeFrames < $1.timecodeFrames }

        // Generate content based on format
        let content: String
        switch format {
        case .edl:
            content = generateEDL(markers: sortedMarkers, frameRate: frameRate, sourceFilename: sourceFilename)
        case .avidText:
            content = generateAvidText(markers: sortedMarkers, frameRate: frameRate)
        case .csv:
            content = generateCSV(markers: sortedMarkers, frameRate: frameRate, sourceFilename: sourceFilename)
        }

        // Write to file
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw MarkerExportError.writeError(error)
        }
    }

    // MARK: - Format Generators

    /// Generates EDL format content for DaVinci Resolve.
    /// Resolve imports this via "Timeline > Import > Timeline Markers from EDL".
    private func generateEDL(
        markers: [Marker],
        frameRate: FrameRate,
        sourceFilename: String
    ) -> String {
        var lines: [String] = []

        // Header
        lines.append("TITLE: \(sourceFilename)")
        lines.append("FCM: \(frameRate.isDropFrame ? "DROP FRAME" : "NON-DROP FRAME")")
        lines.append("")

        // Events
        for (index, marker) in markers.enumerated() {
            let eventNum = String(format: "%03d", index + 1)
            let tcIn = formatTimecode(frames: marker.timecodeFrames, frameRate: frameRate)
            // EDL requires in and out points; use 1 frame duration for markers
            let tcOut = formatTimecode(frames: marker.timecodeFrames + 1, frameRate: frameRate)

            // EDL format: EVENT# REEL TRACK TYPE IN OUT IN OUT
            lines.append("\(eventNum)  001      V     C        \(tcIn) \(tcOut) \(tcIn) \(tcOut)")
            lines.append("* FROM CLIP NAME: \(sourceFilename)")

            // Add color as a comment for reference (Resolve uses this)
            lines.append("* MARKER COLOR: \(marker.color.resolveColorName)")

            if !marker.note.isEmpty {
                // EDL comments are prefixed with *
                lines.append("* COMMENT: \(marker.note)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// Generates tab-delimited text format for Avid Media Composer.
    /// Avid imports this via "Tools > Markers > Import from File".
    private func generateAvidText(
        markers: [Marker],
        frameRate: FrameRate
    ) -> String {
        var lines: [String] = []

        for marker in markers {
            let tc = formatTimecode(frames: marker.timecodeFrames, frameRate: frameRate)
            // Use fallback color for unsupported Avid colors (orange, purple)
            let color = marker.color.avidExportColorName
            // Replace tabs in notes with spaces to preserve column structure
            let note = marker.note.replacingOccurrences(of: "\t", with: " ")

            // Avid format: Username\tTimecode\tTrack\tColor\tComment
            lines.append("FrameCalc\t\(tc)\tV1\t\(color)\t\(note)")
        }

        return lines.joined(separator: "\n")
    }

    /// Generates CSV format for spreadsheets and generic import.
    private func generateCSV(
        markers: [Marker],
        frameRate: FrameRate,
        sourceFilename: String
    ) -> String {
        var lines: [String] = []

        // Header row
        lines.append("Timecode In,Timecode Out,Color,Name,Duration,Source")

        for marker in markers {
            let tc = formatTimecode(frames: marker.timecodeFrames, frameRate: frameRate)
            let color = marker.color.resolveColorName
            let note = escapeCSV(marker.note)
            let source = escapeCSV(sourceFilename)

            // Timecode Out and Duration are empty for point markers
            lines.append("\(tc),,\(color),\(note),,\(source)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Formats a frame count as a timecode string.
    private func formatTimecode(frames: Int, frameRate: FrameRate) -> String {
        let timecode = Timecode(frames: frames, frameRate: frameRate)
        return timecode.formatted()
    }

    /// Escapes a string for CSV format (handles commas, quotes, newlines).
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            // Wrap in quotes and escape internal quotes by doubling them
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
