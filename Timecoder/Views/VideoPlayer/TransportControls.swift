import SwiftUI

/// Transport controls for video playback with JKL shuttle support and glass styling.
struct TransportControls: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    /// Callback to navigate to the previous marker.
    var onPreviousMarker: (() -> Void)?

    /// Callback to add a marker at the current playhead.
    var onAddMarker: (() -> Void)?

    /// Callback to navigate to the next marker.
    var onNextMarker: (() -> Void)?

    /// Callback to export markers.
    var onExport: (() -> Void)?

    /// Whether there's a previous marker to navigate to.
    var hasPreviousMarker: Bool = false

    /// Whether there's a next marker to navigate to.
    var hasNextMarker: Bool = false

    /// Whether there are markers to export.
    var hasMarkers: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Frame step backward
            GlassTransportButton(
                icon: "backward.frame",
                action: viewModel.stepBackward,
                accessibilityLabelText: "Step backward",
                accessibilityHintText: "Move back one frame"
            )
            .help("Step backward (←)")

            // Shuttle controls group
            GlassEffectContainer {
                HStack(spacing: 8) {
                    // Reverse (J key) - only highlight for 2x+ reverse
                    GlassTransportButton(
                        icon: "backward.fill",
                        isActive: viewModel.shuttleState.rawValue < -1,
                        action: viewModel.handleJ,
                        accessibilityLabelText: "Reverse",
                        accessibilityHintText: "Play backward, press multiple times to increase speed"
                    )
                    .help("Reverse (J)")

                    // Play/Pause - highlight when playing at 1x or stopped
                    GlassTransportButton(
                        icon: viewModel.isPlaying ? "pause.fill" : "play.fill",
                        isActive: viewModel.isPlaying && abs(viewModel.shuttleState.rawValue) <= 1,
                        action: viewModel.togglePlayPause,
                        accessibilityLabelText: viewModel.isPlaying ? "Pause" : "Play",
                        accessibilityHintText: viewModel.isPlaying ? "Stop playback" : "Start playback"
                    )
                    .help("Play/Pause (Space)")

                    // Forward (L key) - only highlight for 2x+ forward
                    GlassTransportButton(
                        icon: "forward.fill",
                        isActive: viewModel.shuttleState.rawValue > 1,
                        action: viewModel.handleL,
                        accessibilityLabelText: "Forward",
                        accessibilityHintText: "Play forward, press multiple times to increase speed"
                    )
                    .help("Forward (L)")
                }
            }

            // Frame step forward
            GlassTransportButton(
                icon: "forward.frame",
                action: viewModel.stepForward,
                accessibilityLabelText: "Step forward",
                accessibilityHintText: "Move forward one frame"
            )
            .help("Step forward (→)")

            // Marker controls (only shown if callbacks provided)
            if onPreviousMarker != nil || onAddMarker != nil || onNextMarker != nil {
                Divider()
                    .frame(height: 20)
                    .accessibilityHidden(true)

                HStack(spacing: 8) {
                    // Previous marker
                    GlassTransportButton(
                        icon: "bookmark.fill",
                        isDisabled: !hasPreviousMarker,
                        showLeftArrow: true,
                        action: { onPreviousMarker?() },
                        accessibilityLabelText: "Previous marker",
                        accessibilityHintText: hasPreviousMarker ? "Jump to the previous marker" : "No previous marker available"
                    )
                    .help("Previous marker (↑)")

                    // Add marker at playhead
                    GlassTransportButton(
                        icon: "pin.circle",
                        action: { onAddMarker?() },
                        accessibilityLabelText: "Add marker",
                        accessibilityHintText: "Create a marker at the current playhead position"
                    )
                    .help("Add marker (M)")

                    // Next marker
                    GlassTransportButton(
                        icon: "bookmark.fill",
                        isDisabled: !hasNextMarker,
                        showRightArrow: true,
                        action: { onNextMarker?() },
                        accessibilityLabelText: "Next marker",
                        accessibilityHintText: hasNextMarker ? "Jump to the next marker" : "No next marker available"
                    )
                    .help("Next marker (↓)")
                }
            }

            // Export button
            if onExport != nil {
                Divider()
                    .frame(height: 20)
                    .accessibilityHidden(true)

                GlassTransportButton(
                    icon: "square.and.arrow.up.circle",
                    isDisabled: !hasMarkers,
                    action: { onExport?() },
                    accessibilityLabelText: "Export markers",
                    accessibilityHintText: hasMarkers ? "Export markers to file" : "No markers to export"
                )
                .help("Export markers (⌘E)")
            }

            Spacer()

            // Shuttle speed indicator
            shuttleIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Shuttle Indicator

    /// Accessibility description of current playback speed
    private var shuttleAccessibilityDescription: String {
        switch viewModel.shuttleState {
        case .stopped:
            return viewModel.isPlaying ? "Playing at normal speed" : "Stopped"
        case .forward1x:
            return "Playing forward at normal speed"
        case .forward2x:
            return "Playing forward at 2 times speed"
        case .forward4x:
            return "Playing forward at 4 times speed"
        case .reverse1x:
            return "Playing backward at normal speed"
        case .reverse2x:
            return "Playing backward at 2 times speed"
        case .reverse4x:
            return "Playing backward at 4 times speed"
        }
    }

    @ViewBuilder
    private var shuttleIndicator: some View {
        HStack(spacing: 4) {
            // Speed indicator bars
            ForEach(-4...4, id: \.self) { level in
                if level != 0 {
                    speedBar(level: level)
                }
            }
        }
        .frame(width: 100)
        .accessibilityHidden(true)

        // Speed text
        Text(speedText)
            .font(.spaceMono(size: 12, weight: .bold))
            .foregroundColor(.secondary)
            .frame(width: 50, alignment: .trailing)
            .accessibilityLabel("Playback speed")
            .accessibilityValue(shuttleAccessibilityDescription)
    }

    @ViewBuilder
    private func speedBar(level: Int) -> some View {
        let isActive: Bool = {
            let current = viewModel.shuttleState.rawValue
            if level < 0 {
                return current <= level
            } else {
                return current >= level
            }
        }()

        let color: Color = {
            if level < 0 {
                return isActive ? .timecoderOrange : .gray.opacity(0.3)
            } else {
                return isActive ? .timecoderTeal : .gray.opacity(0.3)
            }
        }()

        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 4, height: 12)
    }

    private var speedText: String {
        switch viewModel.shuttleState {
        case .stopped:
            return viewModel.isPlaying ? "1×" : "0×"
        case .forward1x:
            return "1×"
        case .forward2x:
            return "2×"
        case .forward4x:
            return "4×"
        case .reverse1x:
            return "-1×"
        case .reverse2x:
            return "-2×"
        case .reverse4x:
            return "-4×"
        }
    }
}

// MARK: - Glass Transport Button

/// A transport control button with glass styling.
private struct GlassTransportButton: View {
    let icon: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    var showLeftArrow: Bool = false
    var showRightArrow: Bool = false
    let action: () -> Void

    /// Accessibility label for VoiceOver
    var accessibilityLabelText: String = ""

    /// Accessibility hint for VoiceOver
    var accessibilityHintText: String = ""

    private var iconSize: CGFloat {
        (showLeftArrow || showRightArrow) ? 12 : 16
    }

    private var accessibilityValueText: String {
        isActive ? "Active" : ""
    }

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .buttonStyle(.glass)
        .tint(isActive ? .accentColor : nil)
        .clipShape(Circle())
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
        .focusable(false)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityValue(accessibilityValueText)
    }

    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 2) {
            if showLeftArrow {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8, weight: .bold))
            }

            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))

            if showRightArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .frame(width: 36, height: 36)
    }
}

#Preview {
    TransportControls(viewModel: VideoPlayerViewModel())
        .frame(width: 500)
        .preferredColorScheme(.dark)
}
