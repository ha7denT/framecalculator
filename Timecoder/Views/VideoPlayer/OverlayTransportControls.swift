#if os(iOS)
import SwiftUI

/// Floating transport controls overlay for video playback.
/// Auto-hides after 3 seconds of inactivity. Tap anywhere on the parent to show/hide.
struct OverlayTransportControls: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var onPreviousMarker: (() -> Void)?
    var onAddMarker: (() -> Void)?
    var onNextMarker: (() -> Void)?
    var hasPreviousMarker: Bool = false
    var hasNextMarker: Bool = false

    /// Whether the controls are currently visible.
    @State private var isVisible = true

    /// Timer for auto-hide.
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Tap target to toggle visibility
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleVisibility()
                }

            if isVisible {
                controlsOverlay
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
        .onAppear {
            scheduleHide()
        }
    }

    private var controlsOverlay: some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Spacer()

                // Frame step backward
                GlassTransportButton(
                    icon: "backward.frame",
                    action: { handleAction { viewModel.stepBackward() } },
                    accessibilityLabelText: "Step backward",
                    accessibilityHintText: "Move back one frame"
                )

                // Shuttle controls
                GlassEffectContainer {
                    HStack(spacing: 8) {
                        GlassTransportButton(
                            icon: "backward.fill",
                            isActive: viewModel.shuttleState.rawValue < -1,
                            action: { handleAction { viewModel.handleJ() } },
                            accessibilityLabelText: "Reverse",
                            accessibilityHintText: "Play backward"
                        )
                        GlassTransportButton(
                            icon: viewModel.isPlaying ? "pause.fill" : "play.fill",
                            isActive: viewModel.isPlaying && abs(viewModel.shuttleState.rawValue) <= 1,
                            action: { handleAction { viewModel.togglePlayPause() } },
                            accessibilityLabelText: viewModel.isPlaying ? "Pause" : "Play",
                            accessibilityHintText: viewModel.isPlaying ? "Stop playback" : "Start playback"
                        )
                        GlassTransportButton(
                            icon: "forward.fill",
                            isActive: viewModel.shuttleState.rawValue > 1,
                            action: { handleAction { viewModel.handleL() } },
                            accessibilityLabelText: "Forward",
                            accessibilityHintText: "Play forward"
                        )
                    }
                }

                // Frame step forward
                GlassTransportButton(
                    icon: "forward.frame",
                    action: { handleAction { viewModel.stepForward() } },
                    accessibilityLabelText: "Step forward",
                    accessibilityHintText: "Move forward one frame"
                )

                // Marker controls
                if onPreviousMarker != nil || onAddMarker != nil || onNextMarker != nil {
                    Divider()
                        .frame(height: 20)

                    GlassEffectContainer {
                        HStack(spacing: 6) {
                            GlassTransportButton(
                                icon: "bookmark.fill",
                                isDisabled: !hasPreviousMarker,
                                showLeftArrow: true,
                                action: { handleAction { onPreviousMarker?() } },
                                accessibilityLabelText: "Previous marker",
                                accessibilityHintText: "Jump to the previous marker"
                            )
                            GlassTransportButton(
                                icon: "pin.circle",
                                action: { handleAction { onAddMarker?() } },
                                accessibilityLabelText: "Add marker",
                                accessibilityHintText: "Create a marker"
                            )
                            GlassTransportButton(
                                icon: "bookmark.fill",
                                isDisabled: !hasNextMarker,
                                showRightArrow: true,
                                action: { handleAction { onNextMarker?() } },
                                accessibilityLabelText: "Next marker",
                                accessibilityHintText: "Jump to the next marker"
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(.bottom, 16)
        }
    }

    private func toggleVisibility() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible.toggle()
        }
        if isVisible {
            scheduleHide()
        } else {
            cancelHide()
        }
    }

    private func handleAction(_ action: () -> Void) {
        action()
        scheduleHide()
    }

    private func scheduleHide() {
        cancelHide()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = false
                }
            }
        }
    }

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
    }
}
#endif
