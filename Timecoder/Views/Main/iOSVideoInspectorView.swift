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

    /// Selected panel tab for iPhone layout.
    @State private var selectedPanel: PanelTab = .calculator

    /// Focus state for hardware keyboard input.
    @FocusState private var isKeyboardFocused: Bool

    /// Vertical size class for detecting iPhone landscape.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Video aspect ratio for layout calculations.
    private var videoAspectRatio: CGFloat {
        guard let metadata = appState.currentMetadata else {
            return 16.0 / 9.0
        }
        return metadata.resolution.width / metadata.resolution.height
    }

    enum PanelTab: String, CaseIterable {
        case calculator = "Calculator"
        case metadata = "Info"
        case markers = "Markers"
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
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayout: some View {
        Group {
            if verticalSizeClass == .compact {
                // iPhone landscape: side-by-side
                compactLandscapeLayout
            } else {
                // iPhone portrait: stacked
                compactPortraitLayout
            }
        }
    }

    /// iPhone portrait — stacked video + tabbed panels.
    private var compactPortraitLayout: some View {
        VStack(spacing: 0) {
            // Video player fills width, height constrained by aspect ratio
            videoPlayerArea
                .frame(maxWidth: .infinity)

            // Tabbed panels below
            panelPicker

            TabView(selection: $selectedPanel) {
                calculatorPanel
                    .tag(PanelTab.calculator)

                metadataPanel
                    .tag(PanelTab.metadata)

                markersPanel
                    .tag(PanelTab.markers)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    /// iPhone landscape — side-by-side video + compact calculator/InOut.
    private var compactLandscapeLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Video area (55%)
                videoPlayerArea
                    .frame(width: geometry.size.width * 0.55)

                Divider()

                // Right: Compact calculator + InOut
                ScrollView {
                    VStack(spacing: 0) {
                        CalculatorView(
                            viewModel: calculatorVM,
                            modeButtonIcon: "circle.grid.3x3.circle.fill",
                            modeButtonHelp: "Switch to calculator",
                            onModeButtonTapped: onSwitchToCalculator
                        )

                        if appState.currentMetadata != nil {
                            Divider().padding(.horizontal, 12)
                            InOutPanel(viewModel: playerVM)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Regular Layout (iPad)

    private var regularLayout: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            if isLandscape {
                // iPad landscape: side-by-side (65/35 split)
                HStack(alignment: .top, spacing: 0) {
                    videoPlayerArea
                        .frame(width: geometry.size.width * 0.65)

                    Divider()

                    ScrollView {
                        rightPanel
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // iPad portrait: stacked like compact mode
                VStack(spacing: 0) {
                    videoPlayerArea
                        .frame(maxWidth: .infinity)

                    panelPicker

                    TabView(selection: $selectedPanel) {
                        calculatorPanel
                            .tag(PanelTab.calculator)

                        metadataPanel
                            .tag(PanelTab.metadata)

                        markersPanel
                            .tag(PanelTab.markers)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
    }

    // MARK: - Video Player Area

    @ViewBuilder
    private var videoPlayerArea: some View {
        VStack(spacing: 0) {
            // Video display
            ZStack {
                Color.black

                if let player = appState.player {
                    CustomVideoPlayerView(player: player)
                        .aspectRatio(videoAspectRatio, contentMode: .fit)
                } else {
                    emptyPlayerState
                }
            }
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .clipped()

            // Timeline
            TimelineWithTimecode(
                viewModel: playerVM,
                markers: markerVM.sortedMarkers,
                onMarkerTapped: { marker in
                    markerVM.openEditor(for: marker)
                }
            )
            .padding(.vertical, 4)

            // Transport controls
            TransportControls(
                viewModel: playerVM,
                onPreviousMarker: goToPreviousMarker,
                onAddMarker: addMarkerAtPlayhead,
                onNextMarker: goToNextMarker,
                onExport: { isExportDialogPresented = true },
                hasPreviousMarker: markerVM.previousMarker(before: playerVM.currentFrames) != nil,
                hasNextMarker: markerVM.nextMarker(after: playerVM.currentFrames) != nil,
                hasMarkers: !markerVM.markers.isEmpty,
                isCompact: isCompact
            )
            .padding(.bottom, 4)
        }
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

    // MARK: - Panel Picker (Compact)

    private var panelPicker: some View {
        Picker("Panel", selection: $selectedPanel) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Panels

    private var calculatorPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                CalculatorView(
                    viewModel: calculatorVM,
                    modeButtonIcon: "circle.grid.3x3.circle.fill",
                    modeButtonHelp: "Switch to calculator",
                    onModeButtonTapped: onSwitchToCalculator
                )

                if appState.currentMetadata != nil {
                    Divider().padding(.horizontal, 12)
                    InOutPanel(viewModel: playerVM)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private var metadataPanel: some View {
        ScrollView {
            if let metadata = appState.currentMetadata {
                MetadataPanel(metadata: metadata)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ContentUnavailableView(
                    "No Metadata",
                    systemImage: "info.circle",
                    description: Text("Load a video to see metadata")
                )
            }
        }
    }

    private var markersPanel: some View {
        ScrollView {
            if markerVM.markers.isEmpty {
                ContentUnavailableView(
                    "No Markers",
                    systemImage: "mappin",
                    description: Text("Tap the marker button to add one")
                )
            } else {
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
        }
    }

    // MARK: - Right Panel (iPad)

    @ViewBuilder
    private var rightPanel: some View {
        VStack(spacing: 0) {
            CalculatorView(
                viewModel: calculatorVM,
                modeButtonIcon: "circle.grid.3x3.circle.fill",
                modeButtonHelp: "Switch to calculator",
                onModeButtonTapped: onSwitchToCalculator
            )

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

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
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
        isConfigured = true

        playerVM.onTimecodeChanged = { [weak calculatorVM] timecode in
            calculatorVM?.setTimecode(timecode)
        }
    }
}
#endif
