import SwiftUI
import AVKit

/// The video inspection mode layout combining video player, calculator, and metadata.
struct VideoInspectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel
    @StateObject private var playerVM = VideoPlayerViewModel()

    /// Tracks whether the view has been configured with the player.
    @State private var isConfigured = false

    /// Calculate video display size based on video dimensions
    private var videoDisplaySize: CGSize {
        guard let metadata = appState.currentMetadata else {
            return CGSize(width: 400, height: 300)
        }

        let videoWidth = metadata.resolution.width
        let videoHeight = metadata.resolution.height

        // Use a reasonable max height, then calculate width from aspect ratio
        let maxHeight: CGFloat = 700
        let aspectRatio = videoWidth / videoHeight

        let displayHeight = min(videoHeight, maxHeight)
        let displayWidth = displayHeight * aspectRatio

        return CGSize(width: displayWidth, height: displayHeight)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Video player with controls
            videoPlayerArea

            Divider()

            // Right side: Calculator + Metadata
            rightPanel
                .frame(width: 320)
        }
        .onAppear {
            configurePlayer()
        }
        .onChange(of: appState.player) { _ in
            configurePlayer()
        }
        .background(
            VideoKeyboardHandler(playerVM: playerVM, calculatorVM: calculatorVM)
                .frame(width: 0, height: 0)
        )
    }

    // MARK: - Video Player Area

    @ViewBuilder
    private var videoPlayerArea: some View {
        VStack(spacing: 0) {
            // Video display - explicitly sized to video dimensions
            ZStack(alignment: .topTrailing) {
                if let player = appState.player {
                    CustomVideoPlayerView(player: player)
                        .frame(width: videoDisplaySize.width, height: videoDisplaySize.height)
                } else {
                    Color.black
                        .frame(width: 400, height: 300)
                        .overlay(emptyPlayerState)
                }

                // Close button overlay
                closeButton
                    .padding(4)
            }

            // Timeline
            TimelineWithTimecode(viewModel: playerVM)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

            // Transport controls
            TransportControls(viewModel: playerVM)
        }
    }

    @ViewBuilder
    private var emptyPlayerState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Video Loaded")
                .font(.headline)
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        Button(action: closeVideo) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .padding(8)
        .help("Close video")
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
        playerVM.reset()
        appState.closeVideo()
    }

    private func configurePlayer() {
        guard let player = appState.player,
              let metadata = appState.currentMetadata,
              !isConfigured else {
            return
        }

        playerVM.configure(with: player, metadata: metadata)
        isConfigured = true

        // Set up bidirectional sync: player → calculator
        playerVM.onTimecodeChanged = { [weak calculatorVM] timecode in
            calculatorVM?.setTimecode(timecode)
        }
    }
}

// MARK: - Video Keyboard Handler

/// NSViewRepresentable that captures keyboard events for video controls.
struct VideoKeyboardHandler: NSViewRepresentable {
    let playerVM: VideoPlayerViewModel
    let calculatorVM: CalculatorViewModel

    func makeNSView(context: Context) -> VideoKeyboardCaptureView {
        let view = VideoKeyboardCaptureView()
        view.playerVM = playerVM
        view.calculatorVM = calculatorVM
        return view
    }

    func updateNSView(_ nsView: VideoKeyboardCaptureView, context: Context) {
        nsView.playerVM = playerVM
        nsView.calculatorVM = calculatorVM
    }
}

/// Custom NSView that captures keyboard events for video controls.
class VideoKeyboardCaptureView: NSView {
    var playerVM: VideoPlayerViewModel?
    var calculatorVM: CalculatorViewModel?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Delay to ensure window is fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func resignFirstResponder() -> Bool {
        // Try to reclaim first responder status after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.window?.firstResponder != self {
                self?.window?.makeFirstResponder(self)
            }
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard let playerVM = playerVM else {
            super.keyDown(with: event)
            return
        }

        let handled = handleKeyEvent(event, playerVM: playerVM)

        if !handled {
            super.keyDown(with: event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent, playerVM: VideoPlayerViewModel) -> Bool {
        // Check for special keys first
        switch event.keyCode {
        case 49: // Space
            Task { @MainActor in
                playerVM.togglePlayPause()
            }
            return true

        case 123: // Left arrow
            Task { @MainActor in
                playerVM.stepBackward()
            }
            return true

        case 124: // Right arrow
            Task { @MainActor in
                playerVM.stepForward()
            }
            return true

        case 36: // Enter/Return - seek to typed timecode
            Task { @MainActor in
                self.handleEnterKey()
            }
            return true

        default:
            break
        }

        // Check for character keys
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        switch characters {
        case "j":
            Task { @MainActor in
                playerVM.handleJ()
            }
            return true

        case "k":
            Task { @MainActor in
                playerVM.handleK()
            }
            return true

        case "l":
            Task { @MainActor in
                playerVM.handleL()
            }
            return true

        // Pass number keys to calculator
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            if let digit = Int(characters) {
                Task { @MainActor in
                    self.calculatorVM?.enterDigit(digit)
                }
            }
            return true

        default:
            return false
        }
    }

    @MainActor
    private func handleEnterKey() {
        guard let playerVM = playerVM,
              let calculatorVM = calculatorVM else { return }

        // If user has entered a timecode, commit it first
        if calculatorVM.isEntering {
            calculatorVM.commitEntry()
        }

        // Seek player to current calculator timecode
        playerVM.seek(to: calculatorVM.currentTimecode)
    }
}

#Preview {
    let appState = AppState()
    let calculatorVM = CalculatorViewModel()

    return VideoInspectorView(appState: appState, calculatorVM: calculatorVM)
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
