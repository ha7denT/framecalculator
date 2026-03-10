#if os(iOS)
import SwiftUI
import AVKit
import PhotosUI

/// Frame tolerance for detecting if a marker exists at the current playhead position.
private let markerFrameTolerance = 1

/// iOS video inspection layout with adaptive sizing for iPhone and iPad.
struct iOSVideoInspectorView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel
    @ObservedObject var playerVM: VideoPlayerViewModel
    @ObservedObject var markerVM: MarkerListViewModel

    /// Whether to use compact (iPhone) or regular (iPad) layout.
    var isCompact: Bool

    /// Callback to switch to calculator mode (preserving session).
    var onSwitchToCalculator: () -> Void

    /// Callback to open the file importer for video files.
    var onOpenVideoFile: () -> Void

    /// Tracks whether the view has been configured with the player.
    @State private var isConfigured = false

    /// Selected photo library item for video import.
    @State private var selectedPhotoItem: PhotosPickerItem?

    /// Controls export dialog presentation.
    @State private var isExportDialogPresented = false

    /// Focus state for hardware keyboard input.
    @FocusState private var isKeyboardFocused: Bool

    /// Video aspect ratio for layout calculations.
    private var videoAspectRatio: CGFloat {
        guard let metadata = appState.currentMetadata else {
            return 16.0 / 9.0
        }
        return metadata.resolution.width / metadata.resolution.height
    }

    var body: some View {
        NavigationStack {
            Group {
                if isCompact {
                    compactLayout
                } else {
                    regularLayout
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onSwitchToCalculator()
                    } label: {
                        Image(systemName: "circle.grid.3x3.circle.fill")
                    }
                    .tint(.timecoderTeal)
                }

                if isCompact, let metadata = appState.currentMetadata {
                    ToolbarItem(placement: .principal) {
                        Text(metadata.filename)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if !markerVM.markers.isEmpty {
                            isExportDialogPresented = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(markerVM.markers.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    videoImportMenu
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            configurePlayer()
        }
        .onChange(of: appState.player) { _, newPlayer in
            if newPlayer != nil {
                isConfigured = false
                markerVM.clearAllMarkers()
                configurePlayer()
            }
        }
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
        .sheet(isPresented: $markerVM.isEditorPresented) {
            MarkerEditorPopover(
                markerVM: markerVM,
                frameRate: playerVM.frameRate,
                startTimecodeFrames: playerVM.startTimecodeFrames
            )
            .presentationDetents([.height(220)])
            .presentationBackgroundInteraction(.enabled(upThrough: .height(220)))
            .presentationBackground(.ultraThinMaterial)
            .ignoresSafeArea(.keyboard)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showExportDialog)) { _ in
            if !markerVM.markers.isEmpty {
                isExportDialogPresented = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addMarkerAtPlayhead)) { _ in
            addMarkerAtPlayhead()
        }
        .focusable()
        .focused($isKeyboardFocused)
        .onAppear { isKeyboardFocused = true }
        .onChange(of: markerVM.isEditorPresented) { _, isPresented in
            if !isPresented {
                isKeyboardFocused = true
            }
        }
        // MARK: - Keyboard Handling
        .onKeyPress(.space) {
            playerVM.togglePlayPause()
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            switch press.key {
            case .leftArrow:
                playerVM.stepBackward()
            case .rightArrow:
                playerVM.stepForward()
            case .upArrow:
                goToPreviousMarker()
            case .downArrow:
                goToNextMarker()
            default:
                return .ignored
            }
            return .handled
        }
        .onKeyPress(.return) {
            if calculatorVM.isEntering {
                calculatorVM.commitEntry()
            }
            playerVM.seek(to: calculatorVM.currentTimecode)
            return .handled
        }
        .onKeyPress(.delete) {
            if calculatorVM.isEntering {
                calculatorVM.deleteDigit()
            } else {
                markerVM.deleteSelectedMarker()
            }
            return .handled
        }
        .onKeyPress(keys: Set("0123456789".map { KeyEquivalent(Character(String($0))) })) { press in
            if let digit = Int(String(press.key.character)) {
                calculatorVM.enterDigit(digit, fromKeyboard: true)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: .init(charactersIn: "jklJKL")) { press in
            switch press.key.character {
            case "j", "J":
                playerVM.handleJ()
            case "k", "K":
                playerVM.handleK()
            case "l", "L":
                playerVM.handleL()
            default:
                return .ignored
            }
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "iIoO")) { press in
            let hasShift = press.modifiers.contains(.shift)
            switch press.key.character {
            case "i":
                if hasShift {
                    playerVM.seekToInPoint()
                } else {
                    playerVM.setInPoint()
                }
                return .handled
            case "I":
                playerVM.seekToInPoint()
                return .handled
            case "o":
                if hasShift {
                    playerVM.seekToOutPoint()
                } else {
                    playerVM.setOutPoint()
                }
                return .handled
            case "O":
                playerVM.seekToOutPoint()
                return .handled
            default:
                return .ignored
            }
        }
        .onKeyPress(characters: .init(charactersIn: "xX")) { press in
            if press.modifiers.contains(.option) {
                playerVM.clearInOutPoints()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: .init(charactersIn: "mM")) { _ in
            addMarkerAtPlayhead()
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: ".")) { _ in
            calculatorVM.insertColonShift()
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "eE")) { press in
            if press.modifiers.contains(.command) {
                if !markerVM.markers.isEmpty {
                    isExportDialogPresented = true
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: .init(charactersIn: "cC")) { press in
            if press.modifiers.contains(.command) {
                PlatformClipboard.copy(calculatorVM.copyableString())
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: .init(charactersIn: "vV")) { press in
            if press.modifiers.contains(.command) {
                calculatorVM.pasteFromClipboard()
                return .handled
            }
            return .ignored
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyTimecode)) { _ in
            PlatformClipboard.copy(calculatorVM.copyableString())
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadVideoFromPhotos(item: newItem)
                selectedPhotoItem = nil
            }
        }
        .onChange(of: markerVM.markers) { _, _ in
            playerVM.markers = markerVM.sortedMarkers
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayout: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                compactLandscapeVideoLayout(geometry: geometry)
            } else {
                compactPortraitLayout
            }
        }
    }

    /// iPhone portrait — single-screen layout with video, transport, timecode display,
    /// and side-by-side keypad + metadata/info panel.
    private var compactPortraitLayout: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let maxVideoHeight = totalHeight * 0.30

            // Column widths for keypad (left) and info (right)
            let leftWidth = totalWidth * 0.55
            let rightWidth = totalWidth * 0.45
            let keypadButtonSize = min(PlatformLayout.keypadButtonSize(forWidth: leftWidth, spacing: 6), 44)
            let timecodeFontSize = min(leftWidth * 0.1, 24)

            VStack(spacing: 0) {
                // Video player — below notch, respects safe area
                compactVideoOnlyView
                    .frame(width: totalWidth)
                    .frame(maxHeight: maxVideoHeight)

                // Timeline
                TimelineWithTimecode(
                    viewModel: playerVM,
                    markers: markerVM.sortedMarkers,
                    onMarkerTapped: { marker in
                        markerVM.openEditor(for: marker)
                    }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

                // Row 1: Playback controls (step back, shuttle, step forward)
                compactPlaybackRow
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)

                // Row 2: Marker + In/Out controls
                compactMarkerIORow
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)

                // Side-by-side: Timecode+Keypad (left) + Info (right)
                HStack(alignment: .top, spacing: 0) {
                    // Left column: Timecode display + Keypad
                    VStack(spacing: 4) {
                        TimecodeDisplayView(
                            formattedTimecode: calculatorVM.formattedTimecodeString,
                            frameCount: calculatorVM.currentFrameCount,
                            displayMode: calculatorVM.entryMode == .frames ? .frames : .timecode,
                            hasError: false,
                            isPendingOperation: calculatorVM.hasPendingOperation,
                            invalidComponents: calculatorVM.invalidComponents,
                            pendingOperation: calculatorVM.pendingOperation,
                            primaryFontSize: timecodeFontSize,
                            showSecondaryDisplay: false
                        )
                        .padding(.horizontal, 4)

                        KeypadView(
                            viewModel: calculatorVM,
                            buttonSize: keypadButtonSize,
                            buttonSpacing: 6
                        )
                    }
                    .frame(width: leftWidth)

                    // Right column: FPS picker + compact metadata + In/Out
                    VStack(alignment: .leading, spacing: 8) {
                        CompactFrameRatePicker(selection: $calculatorVM.frameRate)
                            .padding(.top, 4)

                        Divider()

                        if let metadata = appState.currentMetadata {
                            compactMetadataView(metadata: metadata)
                        }

                        if appState.currentMetadata != nil {
                            Divider()
                            compactInOutView
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(width: rightWidth)
                }
            }
            .frame(width: totalWidth)
        }
    }

    /// Playback controls row: step backward, shuttle (reverse/play/forward), step forward — centred.
    private var compactPlaybackRow: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)

            GlassTransportButton(
                icon: "backward.frame",
                action: playerVM.stepBackward,
                accessibilityLabelText: "Step backward",
                accessibilityHintText: "Move back one frame"
            )

            GlassEffectContainer {
                HStack(spacing: 8) {
                    GlassTransportButton(
                        icon: "backward.fill",
                        isActive: playerVM.shuttleState.rawValue < -1,
                        action: playerVM.handleJ,
                        accessibilityLabelText: "Reverse",
                        accessibilityHintText: "Play backward"
                    )
                    GlassTransportButton(
                        icon: playerVM.isPlaying ? "pause.fill" : "play.fill",
                        isActive: playerVM.isPlaying && abs(playerVM.shuttleState.rawValue) <= 1,
                        action: playerVM.togglePlayPause,
                        accessibilityLabelText: playerVM.isPlaying ? "Pause" : "Play",
                        accessibilityHintText: playerVM.isPlaying ? "Stop playback" : "Start playback"
                    )
                    GlassTransportButton(
                        icon: "forward.fill",
                        isActive: playerVM.shuttleState.rawValue > 1,
                        action: playerVM.handleL,
                        accessibilityLabelText: "Forward",
                        accessibilityHintText: "Play forward"
                    )
                }
            }

            GlassTransportButton(
                icon: "forward.frame",
                action: playerVM.stepForward,
                accessibilityLabelText: "Step forward",
                accessibilityHintText: "Move forward one frame"
            )

            Spacer(minLength: 0)
        }
    }

    /// Marker + In/Out controls row: prev marker, add marker, next marker, set in, set out — centred.
    private var compactMarkerIORow: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)

            GlassEffectContainer {
                HStack(spacing: 6) {
                    GlassTransportButton(
                        icon: "bookmark.fill",
                        isDisabled: markerVM.previousMarker(before: playerVM.currentFrames) == nil,
                        showLeftArrow: true,
                        action: { goToPreviousMarker() },
                        accessibilityLabelText: "Previous marker",
                        accessibilityHintText: "Jump to the previous marker"
                    )
                    GlassTransportButton(
                        icon: "pin.circle",
                        action: { addMarkerAtPlayhead() },
                        accessibilityLabelText: "Add marker",
                        accessibilityHintText: "Create a marker at the current playhead position"
                    )
                    GlassTransportButton(
                        icon: "bookmark.fill",
                        isDisabled: markerVM.nextMarker(after: playerVM.currentFrames) == nil,
                        showRightArrow: true,
                        action: { goToNextMarker() },
                        accessibilityLabelText: "Next marker",
                        accessibilityHintText: "Jump to the next marker"
                    )
                }
            }

            Divider()
                .frame(height: 20)

            GlassEffectContainer {
                HStack(spacing: 6) {
                    GlassTransportButton(
                        icon: "arrow.right.to.line",
                        isActive: playerVM.inPointFrames != nil,
                        action: { playerVM.setInPoint() },
                        accessibilityLabelText: "Set In point",
                        accessibilityHintText: "Mark In point at current position"
                    )
                    GlassTransportButton(
                        icon: "arrow.left.to.line",
                        isActive: playerVM.outPointFrames != nil,
                        action: { playerVM.setOutPoint() },
                        accessibilityLabelText: "Set Out point",
                        accessibilityHintText: "Mark Out point at current position"
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    /// Video display only — no timeline or transport (used in compact portrait).
    @ViewBuilder
    private var compactVideoOnlyView: some View {
        Color.black
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .overlay {
                if let player = appState.player {
                    CustomVideoPlayerView(player: player)
                } else {
                    emptyPlayerState
                }
            }
            .overlay(alignment: .topLeading) {
                if let marker = playerVM.activeMarker {
                    MarkerOverlayView(marker: marker)
                        .padding(8)
                }
            }
    }

    /// Fixed width for compact right-column panels (metadata + in/out).
    private let compactPanelWidth: CGFloat = 160

    /// Compact metadata grid for the right column.
    @ViewBuilder
    private func compactMetadataView(metadata: VideoMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 3) {
                GridRow {
                    Text("Res")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                    Text(metadata.formattedResolution)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                GridRow {
                    Text("Codec")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                    Text(metadata.codec)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                GridRow {
                    Text("Dur")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                    Text(metadata.formattedDuration)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                GridRow {
                    Text("Audio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                    Text(metadata.formattedAudioChannels)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .frame(width: compactPanelWidth, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }

    /// Compact In/Out display for the right column.
    /// Fixed width with copy buttons beside each timecode.
    @ViewBuilder
    private var compactInOutView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 3) {
                GridRow {
                    Text("In")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    if let inTC = playerVM.inPointTimecode {
                        Text(inTC.formatted())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Button(action: { PlatformClipboard.copy(inTC.formatted()) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("—")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                GridRow {
                    Text("Out")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    if let outTC = playerVM.outPointTimecode {
                        Text(outTC.formatted())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Button(action: { PlatformClipboard.copy(outTC.formatted()) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("—")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                if let duration = playerVM.inOutDuration {
                    GridRow {
                        Text("Dur")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        Text(duration.formatted())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Button(action: { PlatformClipboard.copy(duration.formatted()) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if playerVM.inPointFrames != nil || playerVM.outPointFrames != nil {
                Button(action: { playerVM.clearInOutPoints() }) {
                    Label("Clear", systemImage: "xmark.circle")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(width: compactPanelWidth, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }

    /// iPhone landscape — fullscreen video with overlay transport controls.
    /// Hides all non-video UI (metadata, keypad, in/out, timeline).
    private func compactLandscapeVideoLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Fullscreen video
            Color.black
                .overlay {
                    if let player = appState.player {
                        CustomVideoPlayerView(player: player)
                            .aspectRatio(videoAspectRatio, contentMode: .fit)
                    } else {
                        emptyPlayerState
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let marker = playerVM.activeMarker {
                        MarkerOverlayView(marker: marker)
                            .padding(8)
                    }
                }

            // Overlay transport controls
            OverlayTransportControls(
                viewModel: playerVM,
                onPreviousMarker: goToPreviousMarker,
                onAddMarker: addMarkerAtPlayhead,
                onNextMarker: goToNextMarker,
                hasPreviousMarker: markerVM.previousMarker(before: playerVM.currentFrames) != nil,
                hasNextMarker: markerVM.nextMarker(after: playerVM.currentFrames) != nil
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Regular Layout (iPad)

    private var regularLayout: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let videoWidth = isLandscape ? geometry.size.width * 0.65 : geometry.size.width * 0.55

            HStack(alignment: .top, spacing: 0) {
                // Left: Video with overlay controls + timeline
                VStack(spacing: 0) {
                    iPadVideoArea
                        .frame(width: videoWidth)

                    TimelineWithTimecode(
                        viewModel: playerVM,
                        markers: markerVM.sortedMarkers,
                        onMarkerTapped: { marker in
                            markerVM.openEditor(for: marker)
                        }
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }

                Divider()

                // Right: Calculator + In/Out + Metadata + Markers
                ScrollView {
                    iPadRightPanel
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// iPad video area with overlay transport controls (no inline transport/timeline).
    @ViewBuilder
    private var iPadVideoArea: some View {
        ZStack {
            Color.black
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .overlay {
                    if let player = appState.player {
                        CustomVideoPlayerView(player: player)
                    } else {
                        emptyPlayerState
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let marker = playerVM.activeMarker {
                        MarkerOverlayView(marker: marker)
                            .padding(8)
                    }
                }

            OverlayTransportControls(
                viewModel: playerVM,
                onPreviousMarker: goToPreviousMarker,
                onAddMarker: addMarkerAtPlayhead,
                onNextMarker: goToNextMarker,
                hasPreviousMarker: markerVM.previousMarker(before: playerVM.currentFrames) != nil,
                hasNextMarker: markerVM.nextMarker(after: playerVM.currentFrames) != nil
            )
        }
    }

    /// Right panel for iPad layout — calculator, in/out, metadata, and markers list.
    @ViewBuilder
    private var iPadRightPanel: some View {
        VStack(spacing: 0) {
            CalculatorView(viewModel: calculatorVM)

            if let metadata = appState.currentMetadata {
                Divider().padding(.horizontal, 12)

                InOutPanel(viewModel: playerVM)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider().padding(.horizontal, 12)

                MetadataPanel(metadata: metadata)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            if !markerVM.markers.isEmpty {
                Divider().padding(.horizontal, 12)

                LazyVStack(spacing: 4) {
                    ForEach(markerVM.sortedMarkers) { marker in
                        MarkerRowView(
                            marker: marker,
                            frameRate: playerVM.frameRate,
                            startTimecodeFrames: playerVM.startTimecodeFrames,
                            isSelected: markerVM.selectedMarker?.id == marker.id,
                            onTap: {
                                playerVM.seek(toFrame: marker.timecodeFrames)
                                markerVM.selectMarker(id: marker.id)
                            },
                            onDoubleTap: {
                                playerVM.seek(toFrame: marker.timecodeFrames)
                                markerVM.openEditor(for: marker)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

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

    // MARK: - Video Import Menu

    private var videoImportMenu: some View {
        Menu {
            Button {
                onOpenVideoFile()
            } label: {
                Label("Choose File", systemImage: "folder")
            }
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .videos
            ) {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "video.badge.plus")
        }
    }

    // MARK: - Photos Import

    /// Loads a video from a PhotosPickerItem by copying it to a temp file.
    private func loadVideoFromPhotos(item: PhotosPickerItem) async {
        guard let movieData = try? await item.loadTransferable(type: Data.self) else {
            appState.setError("Failed to load video from photo library.")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        do {
            try movieData.write(to: tempURL)
            await appState.loadVideo(from: tempURL)
        } catch {
            appState.setError("Failed to save video: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    private func addMarkerAtPlayhead() {
        let currentFrames = playerVM.currentFrames

        if let existingMarker = markerVM.marker(at: currentFrames, tolerance: markerFrameTolerance) {
            markerVM.openEditor(for: existingMarker)
        } else {
            let newMarker = markerVM.addMarker(at: currentFrames)
            markerVM.openEditor(for: newMarker)
        }
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
        playerVM.markers = markerVM.sortedMarkers
        isConfigured = true

        playerVM.onTimecodeChanged = { [weak calculatorVM] timecode in
            calculatorVM?.setTimecode(timecode)
        }
    }
}
#endif
