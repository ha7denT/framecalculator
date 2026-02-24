#if os(iOS)
import SwiftUI
import AVKit

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

    /// Tracks whether the view has been configured with the player.
    @State private var isConfigured = false

    /// Controls export dialog presentation.
    @State private var isExportDialogPresented = false

    /// Selected panel tab for iPhone layout.
    @State private var selectedPanel: PanelTab = .calculator

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
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayout: some View {
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

    // MARK: - Regular Layout (iPad)

    private var regularLayout: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // Left: Video player area (~62% width)
                videoPlayerArea
                    .frame(width: geometry.size.width * 0.62)

                Divider()

                // Right: Calculator + metadata
                ScrollView {
                    rightPanel
                }
                .frame(maxWidth: .infinity)
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
                hasMarkers: !markerVM.markers.isEmpty
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
            .frame(height: 520)

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
