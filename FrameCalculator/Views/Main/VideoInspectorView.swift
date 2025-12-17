import SwiftUI
import AVKit

/// The video inspection mode layout combining video player, calculator, and metadata.
struct VideoInspectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel
    @StateObject private var playerVM = VideoPlayerViewModel()

    /// Tracks whether the view has been configured with the player.
    @State private var isConfigured = false

    /// Video aspect ratio for layout calculations
    private var videoAspectRatio: CGFloat {
        guard let metadata = appState.currentMetadata else {
            return 16.0 / 9.0
        }
        return metadata.resolution.width / metadata.resolution.height
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
            // Video display - fills available space maintaining aspect ratio
            GeometryReader { geometry in
                let availableHeight = geometry.size.height
                let availableWidth = geometry.size.width

                // Calculate size that fits within available space while maintaining aspect ratio
                let widthFromHeight = availableHeight * videoAspectRatio
                let heightFromWidth = availableWidth / videoAspectRatio

                let (displayWidth, displayHeight): (CGFloat, CGFloat) = {
                    if widthFromHeight <= availableWidth {
                        // Height-constrained
                        return (widthFromHeight, availableHeight)
                    } else {
                        // Width-constrained
                        return (availableWidth, heightFromWidth)
                    }
                }()

                ZStack(alignment: .topTrailing) {
                    if let player = appState.player {
                        CustomVideoPlayerView(player: player)
                            .frame(width: displayWidth, height: displayHeight)
                    } else {
                        Color.black
                            .frame(width: displayWidth, height: displayHeight)
                            .overlay(emptyPlayerState)
                    }

                    // Close button overlay
                    closeButton
                        .padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Calculator (always at top)
            CalculatorView(viewModel: calculatorVM)

            // Supplementary info below calculator (when video loaded)
            if appState.currentMetadata != nil {
                Divider()

                // In/Out panel
                InOutPanel(viewModel: playerVM)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                // Metadata panel (static file info at bottom)
                MetadataPanel(metadata: appState.currentMetadata!)
                    .padding()
            }
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

        // In/Out point controls
        case "i":
            Task { @MainActor in
                if event.modifierFlags.contains(.shift) {
                    // ⇧I - Go to In point
                    playerVM.seekToInPoint()
                } else {
                    // I - Set In point
                    playerVM.setInPoint()
                }
            }
            return true

        case "o":
            Task { @MainActor in
                if event.modifierFlags.contains(.shift) {
                    // ⇧O - Go to Out point
                    playerVM.seekToOutPoint()
                } else {
                    // O - Set Out point
                    playerVM.setOutPoint()
                }
            }
            return true

        case "x":
            if event.modifierFlags.contains(.option) {
                // ⌥X - Clear In/Out points
                Task { @MainActor in
                    playerVM.clearInOutPoints()
                }
                return true
            }
            return false

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

// MARK: - In/Out Panel

/// Panel displaying In/Out point timecodes and duration.
struct InOutPanel: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("In/Out")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Clear button (only shown when points exist)
                if viewModel.inPointFrames != nil || viewModel.outPointFrames != nil {
                    Button(action: { viewModel.clearInOutPoints() }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear In/Out points (⌥X)")
                }
            }

            // In/Out point rows
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                // In point row
                GridRow {
                    Label("In", systemImage: "arrow.right.to.line")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)

                    if let inTC = viewModel.inPointTimecode {
                        Text(inTC.formatted())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)

                        Button(action: { viewModel.seekToInPoint() }) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Go to In point (⇧I)")
                    } else {
                        Text("Not set")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("")
                            .frame(width: 16)
                    }
                }

                // Out point row
                GridRow {
                    Label("Out", systemImage: "arrow.left.to.line")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)

                    if let outTC = viewModel.outPointTimecode {
                        Text(outTC.formatted())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)

                        Button(action: { viewModel.seekToOutPoint() }) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Go to Out point (⇧O)")
                    } else {
                        Text("Not set")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("")
                            .frame(width: 16)
                    }
                }

                // Duration row (only shown when both points set)
                if let duration = viewModel.inOutDuration {
                    GridRow {
                        Label("Dur", systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)

                        Text(duration.formatted())
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.yellow)

                        Text("")
                            .frame(width: 16)
                    }
                }
            }

            // Keyboard hints
            HStack(spacing: 16) {
                Text("I = In")
                Text("O = Out")
                Text("⌥X = Clear")
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    let appState = AppState()
    let calculatorVM = CalculatorViewModel()

    return VideoInspectorView(appState: appState, calculatorVM: calculatorVM)
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
