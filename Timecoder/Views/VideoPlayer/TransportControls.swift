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
                action: viewModel.stepBackward
            )
            .help("Step backward (←)")

            // Shuttle controls group
            GlassEffectContainer {
                HStack(spacing: 8) {
                    // Reverse (J key)
                    GlassTransportButton(
                        icon: "backward.fill",
                        isActive: viewModel.shuttleState.rawValue < 0,
                        action: viewModel.handleJ
                    )
                    .help("Reverse (J)")

                    // Play/Pause
                    GlassTransportButton(
                        icon: viewModel.isPlaying ? "pause.fill" : "play.fill",
                        action: viewModel.togglePlayPause
                    )
                    .help("Play/Pause (Space)")

                    // Forward (L key)
                    GlassTransportButton(
                        icon: "forward.fill",
                        isActive: viewModel.shuttleState.rawValue > 0,
                        action: viewModel.handleL
                    )
                    .help("Forward (L)")
                }
            }

            // Frame step forward
            GlassTransportButton(
                icon: "forward.frame",
                action: viewModel.stepForward
            )
            .help("Step forward (→)")

            // Marker controls (only shown if callbacks provided)
            if onPreviousMarker != nil || onAddMarker != nil || onNextMarker != nil {
                Divider()
                    .frame(height: 20)

                HStack(spacing: 8) {
                    // Previous marker
                    GlassTransportButton(
                        icon: "bookmark.fill",
                        isDisabled: !hasPreviousMarker,
                        showLeftArrow: true,
                        action: { onPreviousMarker?() }
                    )
                    .help("Previous marker (↑)")

                    // Add marker at playhead
                    GlassTransportButton(
                        icon: "pin.circle",
                        action: { onAddMarker?() }
                    )
                    .help("Add marker (M)")

                    // Next marker
                    GlassTransportButton(
                        icon: "bookmark.fill",
                        isDisabled: !hasNextMarker,
                        showRightArrow: true,
                        action: { onNextMarker?() }
                    )
                    .help("Next marker (↓)")
                }
            }

            // Export button
            if onExport != nil {
                Divider()
                    .frame(height: 20)

                GlassTransportButton(
                    icon: "square.and.arrow.up.circle",
                    isDisabled: !hasMarkers,
                    action: { onExport?() }
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

        // Speed text
        Text(speedText)
            .font(.spaceMono(size: 12, weight: .bold))
            .foregroundColor(.secondary)
            .frame(width: 50, alignment: .trailing)
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
                return isActive ? .orange : .gray.opacity(0.3)
            } else {
                return isActive ? .green : .gray.opacity(0.3)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                if showLeftArrow {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 8, weight: .bold))
                }

                Image(systemName: icon)
                    .font(.system(size: showLeftArrow || showRightArrow ? 12 : 16, weight: .medium))

                if showRightArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .tint(isActive ? .accentColor : nil)
        .clipShape(Circle())
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
    }
}

#Preview {
    TransportControls(viewModel: VideoPlayerViewModel())
        .frame(width: 500)
        .preferredColorScheme(.dark)
}
