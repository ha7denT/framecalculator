import SwiftUI

/// A view displaying video metadata in a compact, professional format.
struct MetadataPanel: View {
    let metadata: VideoMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Filename header
            Text(metadata.filename)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("File: \(metadata.filename)")

            Divider()
                .accessibilityHidden(true)

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                MetadataRow(label: "Duration", value: metadata.formattedDuration)
                MetadataRow(label: "Resolution", value: metadata.formattedResolution)
                MetadataRow(label: "Frame Rate", value: metadata.formattedFrameRate)
                MetadataRow(label: "Codec", value: metadata.codec)

                if let bitrate = metadata.formattedBitrate {
                    MetadataRow(label: "Bitrate", value: bitrate)
                }

                if let colorSpace = metadata.colorSpace {
                    MetadataRow(label: "Color Space", value: colorSpace)
                }

                MetadataRow(label: "Audio", value: metadata.formattedAudioChannels)
                MetadataRow(label: "File Size", value: metadata.formattedFileSize)
            }

            Divider()
                .accessibilityHidden(true)

            // Timecode source indicator
            TimecodeSourceIndicator(metadata: metadata)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Video metadata")
    }
}

/// Indicator showing whether timecode is from source or elapsed time.
private struct TimecodeSourceIndicator: View {
    let metadata: VideoMetadata

    private var accessibilityDescription: String {
        if metadata.hasEmbeddedTimecode {
            return "Embedded timecode, starting at \(metadata.formattedStartTimecode)"
        } else {
            return "Elapsed time timecode, calculated from playhead position"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metadata.hasEmbeddedTimecode ? "clock.badge.checkmark" : "timer")
                .foregroundColor(metadata.hasEmbeddedTimecode ? .green : .orange)
                .font(.caption)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.timecodeSourceDescription)
                    .font(.caption)
                    .fontWeight(.medium)

                if metadata.hasEmbeddedTimecode {
                    Text("Start: \(metadata.formattedStartTimecode)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Timecode from playhead position")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timecode source")
        .accessibilityValue(accessibilityDescription)
    }
}

/// A single row in the metadata display.
private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// A compact metadata badge for minimal display.
struct MetadataBadge: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview("With Embedded TC") {
    MetadataPanel(metadata: VideoMetadata(
        url: URL(fileURLWithPath: "/path/to/Sample_Video_1080p.mov"),
        duration: 3723.5,
        codec: "ProRes 422 HQ",
        bitrate: 220_000_000,
        resolution: CGSize(width: 1920, height: 1080),
        detectedFrameRate: 23.976,
        colorSpace: "Rec. 709",
        audioChannels: 2,
        fileSize: 102_400_000_000,
        hasEmbeddedTimecode: true,
        startTimecodeFrames: 86400
    ))
    .frame(width: 280)
    .preferredColorScheme(.dark)
}

#Preview("Elapsed Time") {
    MetadataPanel(metadata: VideoMetadata(
        url: URL(fileURLWithPath: "/path/to/iPhone_Video.mp4"),
        duration: 120.5,
        codec: "H.264",
        bitrate: 25_000_000,
        resolution: CGSize(width: 1920, height: 1080),
        detectedFrameRate: 30.0,
        colorSpace: "Rec. 709",
        audioChannels: 2,
        fileSize: 375_000_000,
        hasEmbeddedTimecode: false,
        startTimecodeFrames: nil
    ))
    .frame(width: 280)
    .preferredColorScheme(.dark)
}
