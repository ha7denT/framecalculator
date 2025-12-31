import SwiftUI
import AVKit

// MARK: - Notification for keyboard focus

extension Notification.Name {
    static let reclaimKeyboardFocus = Notification.Name("reclaimKeyboardFocus")
    static let showExportDialog = Notification.Name("showExportDialog")
}

/// The video inspection mode layout combining video player, calculator, and metadata.
struct VideoInspectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel
    @StateObject private var playerVM = VideoPlayerViewModel()
    @StateObject private var markerVM = MarkerListViewModel()

    /// Tracks whether the view has been configured with the player.
    @State private var isConfigured = false

    /// Controls export dialog presentation.
    @State private var isExportDialogPresented = false

    /// Video aspect ratio for layout calculations
    private var videoAspectRatio: CGFloat {
        guard let metadata = appState.currentMetadata else {
            return 16.0 / 9.0
        }
        return metadata.resolution.width / metadata.resolution.height
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left side: Video player with controls (top-aligned)
            videoPlayerArea
                .frame(minWidth: 500, idealWidth: 700, maxWidth: 900)

            Divider()

            // Right side: Calculator + Metadata
            rightPanel
                .frame(width: 320)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            configurePlayer()
        }
        .onChange(of: appState.player) { _ in
            configurePlayer()
        }
        .onChange(of: markerVM.isEditorPresented) { isPresented in
            if !isPresented {
                // Editor closed - post notification to reclaim keyboard focus
                NotificationCenter.default.post(name: .reclaimKeyboardFocus, object: nil)
            }
        }
        .background(
            VideoKeyboardHandler(
                playerVM: playerVM,
                calculatorVM: calculatorVM,
                markerVM: markerVM,
                onExportRequested: { isExportDialogPresented = true },
                onPreviousMarker: goToPreviousMarker,
                onNextMarker: goToNextMarker
            )
                .frame(width: 0, height: 0)
        )
        .sheet(isPresented: $isExportDialogPresented) {
            if let metadata = appState.currentMetadata {
                ExportDialogView(
                    isPresented: $isExportDialogPresented,
                    markers: markerVM.sortedMarkers,
                    frameRate: playerVM.frameRate,
                    sourceFilename: metadata.filename
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showExportDialog)) { _ in
            // Show export dialog when triggered from menu bar
            if !markerVM.markers.isEmpty {
                isExportDialogPresented = true
            }
        }
    }

    // MARK: - Video Player Area

    @ViewBuilder
    private var videoPlayerArea: some View {
        VStack(spacing: 0) {
            // Video display - responsive, maintains aspect ratio
            ZStack {
                ZStack(alignment: .topTrailing) {
                    if let player = appState.player {
                        CustomVideoPlayerView(player: player)
                            .aspectRatio(videoAspectRatio, contentMode: .fit)
                    } else {
                        Color.black
                            .aspectRatio(16.0/9.0, contentMode: .fit)
                            .overlay(emptyPlayerState)
                    }

                    // Close button overlay
                    closeButton
                        .padding(4)
                }

                // Marker editor popover (centered over video)
                if markerVM.isEditorPresented {
                    MarkerEditorPopover(
                        markerVM: markerVM,
                        frameRate: playerVM.frameRate,
                        startTimecodeFrames: playerVM.startTimecodeFrames
                    )
                }
            }

            // Timeline
            TimelineWithTimecode(
                viewModel: playerVM,
                markers: markerVM.sortedMarkers,
                onMarkerTapped: { marker in
                    markerVM.openEditor(for: marker)
                }
            )
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            // Transport controls
            TransportControls(
                viewModel: playerVM,
                onPreviousMarker: goToPreviousMarker,
                onNextMarker: goToNextMarker,
                hasPreviousMarker: markerVM.previousMarker(before: playerVM.currentFrames) != nil,
                hasNextMarker: markerVM.nextMarker(after: playerVM.currentFrames) != nil
            )
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

                Spacer()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Actions

    private func closeVideo() {
        playerVM.reset()
        markerVM.clearAllMarkers()
        appState.closeVideo()
    }

    private func addMarkerAtPlayhead() {
        markerVM.addMarker(at: playerVM.currentFrames)
    }

    private func goToPreviousMarker() {
        if let frames = markerVM.previousMarkerFrames(before: playerVM.currentFrames) {
            playerVM.seek(toFrame: frames)
        }
    }

    private func goToNextMarker() {
        if let frames = markerVM.nextMarkerFrames(after: playerVM.currentFrames) {
            playerVM.seek(toFrame: frames)
        }
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
    let markerVM: MarkerListViewModel
    var onExportRequested: (() -> Void)?
    var onPreviousMarker: (() -> Void)?
    var onNextMarker: (() -> Void)?

    func makeNSView(context: Context) -> VideoKeyboardCaptureView {
        let view = VideoKeyboardCaptureView()
        view.playerVM = playerVM
        view.calculatorVM = calculatorVM
        view.markerVM = markerVM
        view.onExportRequested = onExportRequested
        view.onPreviousMarker = onPreviousMarker
        view.onNextMarker = onNextMarker
        return view
    }

    func updateNSView(_ nsView: VideoKeyboardCaptureView, context: Context) {
        let wasEditorOpen = nsView.wasEditorOpen
        let isEditorOpen = markerVM.isEditorPresented

        nsView.playerVM = playerVM
        nsView.calculatorVM = calculatorVM
        nsView.markerVM = markerVM
        nsView.onExportRequested = onExportRequested
        nsView.onPreviousMarker = onPreviousMarker
        nsView.onNextMarker = onNextMarker
        nsView.wasEditorOpen = isEditorOpen

        // Reclaim focus when editor closes
        if wasEditorOpen && !isEditorOpen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// Custom NSView that captures keyboard events for video controls.
class VideoKeyboardCaptureView: NSView {
    var playerVM: VideoPlayerViewModel?
    var calculatorVM: CalculatorViewModel?
    var markerVM: MarkerListViewModel?
    var onExportRequested: (() -> Void)?
    var onPreviousMarker: (() -> Void)?
    var onNextMarker: (() -> Void)?
    var wasEditorOpen: Bool = false
    private var focusObserver: NSObjectProtocol?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Delay to ensure window is fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.window?.makeFirstResponder(self)
        }

        // Listen for focus reclaim notification
        focusObserver = NotificationCenter.default.addObserver(
            forName: .reclaimKeyboardFocus,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.window?.makeFirstResponder(self)
            }
        }
    }

    deinit {
        if let observer = focusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func resignFirstResponder() -> Bool {
        // Don't reclaim focus if marker editor is open (user is typing in text field)
        if markerVM?.isEditorPresented == true {
            return true
        }

        // Try to reclaim first responder status after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Don't reclaim if editor is now open
            if self?.markerVM?.isEditorPresented == true {
                return
            }
            if self?.window?.firstResponder != self {
                self?.window?.makeFirstResponder(self)
            }
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Don't intercept keyboard events when marker editor is open
        if markerVM?.isEditorPresented == true {
            super.keyDown(with: event)
            return
        }

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

        case 125: // Down arrow - next marker
            Task { @MainActor in
                self.onNextMarker?()
            }
            return true

        case 126: // Up arrow - previous marker
            Task { @MainActor in
                self.onPreviousMarker?()
            }
            return true

        case 36: // Enter/Return - seek to typed timecode
            Task { @MainActor in
                self.handleEnterKey()
            }
            return true

        case 51: // Delete key - remove selected marker
            Task { @MainActor in
                self.markerVM?.deleteSelectedMarker()
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

        // Marker control
        case "m":
            Task { @MainActor in
                self.handleMKey()
            }
            return true

        // Export markers (⌘E)
        case "e":
            if event.modifierFlags.contains(.command) {
                Task { @MainActor in
                    self.onExportRequested?()
                }
                return true
            }
            return false

        default:
            return false
        }
    }

    @MainActor
    private func handleMKey() {
        guard let playerVM = playerVM,
              let markerVM = markerVM else { return }

        let currentFrames = playerVM.currentFrames

        // Check if a marker already exists at this position (within 1 frame tolerance)
        if let existingMarker = markerVM.marker(at: currentFrames, tolerance: 1) {
            // Open editor for existing marker
            markerVM.openEditor(for: existingMarker)
        } else {
            // Add new marker and open editor
            let newMarker = markerVM.addMarker(at: currentFrames)
            markerVM.openEditor(for: newMarker)
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
                            .font(.spaceMono(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)

                        Button(action: { viewModel.seekToInPoint() }) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.timecoderTeal)
                        }
                        .buttonStyle(.plain)
                        .help("Go to In point (⇧I)")
                    } else {
                        Text("Not set")
                            .font(.spaceMono(size: 13))
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
                            .font(.spaceMono(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)

                        Button(action: { viewModel.seekToOutPoint() }) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.timecoderTeal)
                        }
                        .buttonStyle(.plain)
                        .help("Go to Out point (⇧O)")
                    } else {
                        Text("Not set")
                            .font(.spaceMono(size: 13))
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
                            .font(.spaceMono(size: 13, weight: .bold))
                            .foregroundColor(.timecoderOrange)
                            .textSelection(.enabled)

                        Text("")
                            .frame(width: 16)
                    }
                }
            }

            // Clear button (only shown when points exist)
            if viewModel.inPointFrames != nil || viewModel.outPointFrames != nil {
                HStack {
                    Spacer()
                    Button(action: { viewModel.clearInOutPoints() }) {
                        Label("Clear", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear In/Out points (⌥X)")
                }
            }
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
