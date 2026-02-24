#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

/// iOS-specific content view with adaptive layout for iPhone and iPad.
struct iOSContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel
    @ObservedObject var playerVM: VideoPlayerViewModel
    @ObservedObject var markerVM: MarkerListViewModel

    /// Callback to open or restore a video session.
    var onOpenVideoOrRestore: () -> Void

    /// Callback to switch to calculator mode (preserving session).
    var onSwitchToCalculator: () -> Void

    /// Callback to open the file importer.
    var onOpenVideoFile: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingSettings = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Group {
            switch appState.mode {
            case .calculator:
                calculatorModeView

            case .videoInspector:
                videoModeView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.mode)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                PreferencesView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showingSettings = true
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadVideoFromPhotos(item: newItem)
                selectedPhotoItem = nil
            }
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

    // MARK: - Calculator Mode

    private var calculatorModeView: some View {
        NavigationStack {
            CalculatorView(
                viewModel: calculatorVM,
                modeButtonIcon: appState.hasStoredSession ? "film.stack" : "play.rectangle",
                modeButtonHelp: appState.hasStoredSession ? "Return to video" : "Open video",
                onModeButtonTapped: onOpenVideoOrRestore
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    videoImportMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
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

    // MARK: - Video Mode

    private var videoModeView: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneVideoLayout
            } else {
                iPadVideoLayout
            }
        }
    }

    // MARK: - iPhone Video Layout (Stacked)

    private var iPhoneVideoLayout: some View {
        iOSVideoInspectorView(
            appState: appState,
            calculatorVM: calculatorVM,
            playerVM: playerVM,
            markerVM: markerVM,
            isCompact: true,
            onSwitchToCalculator: onSwitchToCalculator
        )
    }

    // MARK: - iPad Video Layout (Side-by-Side)

    private var iPadVideoLayout: some View {
        iOSVideoInspectorView(
            appState: appState,
            calculatorVM: calculatorVM,
            playerVM: playerVM,
            markerVM: markerVM,
            isCompact: false,
            onSwitchToCalculator: onSwitchToCalculator
        )
    }
}
#endif
