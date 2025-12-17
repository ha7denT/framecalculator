import SwiftUI

/// Transport controls for video playback with JKL shuttle support.
struct TransportControls: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

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
    private func transportButton(icon: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(isActive ? .white : .primary)
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
