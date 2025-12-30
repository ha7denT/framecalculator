import SwiftUI

/// Transport controls for video playback with JKL shuttle support.
struct TransportControls: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    /// Callback to navigate to the previous marker.
    var onPreviousMarker: (() -> Void)?

    /// Callback to navigate to the next marker.
    var onNextMarker: (() -> Void)?

    /// Whether there's a previous marker to navigate to.
    var hasPreviousMarker: Bool = false

    /// Whether there's a next marker to navigate to.
    var hasNextMarker: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Frame step backward
            transportButton(
                icon: "backward.frame",
                action: viewModel.stepBackward
            )
            .help("Step backward (←)")

            // Shuttle controls group
            HStack(spacing: 8) {
                // Reverse (J key)
                transportButton(
                    icon: "backward.fill",
                    isActive: viewModel.shuttleState.rawValue < 0,
                    action: viewModel.handleJ
                )
                .help("Reverse (J)")

                // Play/Pause
                transportButton(
                    icon: viewModel.isPlaying ? "pause.fill" : "play.fill",
                    isActive: false,
                    action: viewModel.togglePlayPause
                )
                .help("Play/Pause (Space)")

                // Forward (L key)
                transportButton(
                    icon: "forward.fill",
                    isActive: viewModel.shuttleState.rawValue > 0,
                    action: viewModel.handleL
                )
                .help("Forward (L)")
            }

            // Frame step forward
            transportButton(
                icon: "forward.frame",
                action: viewModel.stepForward
            )
            .help("Step forward (→)")

            // Marker navigation (only shown if callbacks provided)
            if onPreviousMarker != nil || onNextMarker != nil {
                Divider()
                    .frame(height: 20)

                HStack(spacing: 8) {
                    // Previous marker
                    transportButton(
                        icon: "bookmark.fill",
                        isDisabled: !hasPreviousMarker,
                        showLeftArrow: true,
                        action: { onPreviousMarker?() }
                    )
                    .help("Previous marker (↑)")

                    // Next marker
                    transportButton(
                        icon: "bookmark.fill",
                        isDisabled: !hasNextMarker,
                        showRightArrow: true,
                        action: { onNextMarker?() }
                    )
                    .help("Next marker (↓)")
                }
            }

            Spacer()

            // Shuttle speed indicator
            shuttleIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
    }

    // MARK: - Subviews

    @ViewBuilder
    private func transportButton(
        icon: String,
        isActive: Bool = false,
        isDisabled: Bool = false,
        showLeftArrow: Bool = false,
        showRightArrow: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
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
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? .secondary.opacity(0.5) : (isActive ? .white : .primary))
        .disabled(isDisabled)
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

#Preview {
    TransportControls(viewModel: VideoPlayerViewModel())
        .frame(width: 500)
        .preferredColorScheme(.dark)
}
