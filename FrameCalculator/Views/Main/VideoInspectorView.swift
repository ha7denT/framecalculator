import SwiftUI
import AVKit

/// The video inspection mode layout combining video player, calculator, and metadata.
struct VideoInspectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel

    var body: some View {
        HSplitView {
            // Left side: Video player (placeholder for Sprint 4)
            videoPlayerArea
                .frame(minWidth: 400)

            // Right side: Calculator + Metadata
            rightPanel
                .frame(width: 320)
        }
    }

    // MARK: - Video Player Area

    @ViewBuilder
    private var videoPlayerArea: some View {
        ZStack {
            Color.black

            if let player = appState.player {
                VideoPlayer(player: player)
            } else {
                // Placeholder when no player
                VStack(spacing: 16) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Video Player")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Full playback controls coming in Sprint 4")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: closeVideo) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                Spacer()
            }
        }
    }

    // MARK: - Right Panel

    @ViewBuilder
    private var rightPanel: some View {
        VStack(spacing: 0) {
            // Metadata panel (when video loaded)
            if let metadata = appState.currentMetadata {
                MetadataPanel(metadata: metadata)
                    .padding()

                Divider()
            }

            // Calculator
            CalculatorView(viewModel: calculatorVM)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Actions

    private func closeVideo() {
        appState.closeVideo()
    }
}

#Preview {
    let appState = AppState()
    let calculatorVM = CalculatorViewModel()

    return VideoInspectorView(appState: appState, calculatorVM: calculatorVM)
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
