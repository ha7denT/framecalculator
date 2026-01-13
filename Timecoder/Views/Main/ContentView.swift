import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notification for opening video from menu

extension Notification.Name {
    static let openVideoFile = Notification.Name("openVideoFile")
    static let addMarkerAtPlayhead = Notification.Name("addMarkerAtPlayhead")
}

/// Main content view that switches between calculator and video inspection modes.
struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var calculatorVM = CalculatorViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            switch appState.mode {
            case .calculator:
                standaloneCalculatorView

            case .videoInspector:
                VideoInspectorView(appState: appState, calculatorVM: calculatorVM)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.mode)
        .onDrop(of: supportedDropTypes, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay(dropOverlay)
        .overlay(loadingOverlay)
        .alert("Error Loading Video", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            if let error = appState.errorMessage {
                Text(error)
            }
        }
        .onChange(of: appState.currentMetadata) { _, metadata in
            // Sync frame rate when video is loaded
            if let metadata = metadata {
                calculatorVM.frameRate = metadata.matchingFrameRate
                // Resize window for video orientation
                let aspectRatio = metadata.resolution.width / metadata.resolution.height
                let orientation = VideoOrientation.from(aspectRatio: aspectRatio)
                resizeWindowForVideo(orientation: orientation)
            }
        }
        .onChange(of: appState.mode) { _, newMode in
            // Resize when returning to calculator mode (compact size)
            if newMode == .calculator {
                resizeWindowForCalculator()
            }
        }
        .onAppear {
            // Set correct size on launch
            resizeWindowForCalculator()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVideoFile)) { _ in
            openVideoFile()
        }
    }

    // MARK: - Window Management

    /// Resizes window to calculator-only mode (compact)
    private func resizeWindowForCalculator() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else { return }

            let targetSize = NSSize(width: 300, height: 540)
            let currentFrame = window.frame
            let newOriginY = currentFrame.origin.y + currentFrame.height - targetSize.height

            let newFrame = NSRect(
                origin: NSPoint(x: currentFrame.origin.x, y: newOriginY),
                size: targetSize
            )
            window.setFrame(newFrame, display: true, animate: true)
        }
    }

    /// Resizes window for video mode based on video orientation
    /// - Parameter orientation: The detected video orientation (landscape or portrait)
    private func resizeWindowForVideo(orientation: VideoOrientation) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else { return }

            let targetSize = orientation.windowSize
            let currentFrame = window.frame

            // Calculate new frame, keeping top-left position stable
            let newOriginY = currentFrame.origin.y + currentFrame.height - targetSize.height
            var newFrame = NSRect(
                origin: NSPoint(x: currentFrame.origin.x, y: newOriginY),
                size: targetSize
            )

            // Ensure window stays on screen
            if let screen = window.screen ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame

                // Adjust if window would go off the right edge
                if newFrame.maxX > visibleFrame.maxX {
                    newFrame.origin.x = visibleFrame.maxX - targetSize.width
                }

                // Adjust if window would go off the left edge
                if newFrame.origin.x < visibleFrame.origin.x {
                    newFrame.origin.x = visibleFrame.origin.x
                }

                // Adjust if window would go below the bottom edge
                if newFrame.origin.y < visibleFrame.origin.y {
                    newFrame.origin.y = visibleFrame.origin.y
                }

                // Adjust if window would go above the top edge
                if newFrame.maxY > visibleFrame.maxY {
                    newFrame.origin.y = visibleFrame.maxY - targetSize.height
                }
            }

            window.setFrame(newFrame, display: true, animate: true)
        }
    }

    // MARK: - Standalone Calculator

    private var standaloneCalculatorView: some View {
        CalculatorView(
            viewModel: calculatorVM,
            modeButtonIcon: "play.rectangle",
            modeButtonHelp: "Open video (⌘O)",
            onModeButtonTapped: openVideoFile
        )
    }

    // MARK: - Open Video File

    /// Opens a file picker to select a video file.
    private func openVideoFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = supportedDropTypes

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    await appState.loadVideo(from: url)
                }
            }
        }
    }

    // MARK: - Drop Handling

    private var supportedDropTypes: [UTType] {
        [.movie, .video, .quickTimeMovie, .mpeg4Movie, .mpeg2Video, .avi]
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try to load a file URL
        for type in supportedDropTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    guard let url = url, error == nil else { return }

                    // Copy to temp location since the provided URL is temporary
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension)

                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        Task { @MainActor in
                            await appState.loadVideo(from: tempURL)
                        }
                    } catch {
                        Task { @MainActor in
                            appState.clearError()
                        }
                    }
                }
                return true
            }
        }

        return false
    }

    // MARK: - Overlays

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            ZStack {
                Color.accentColor.opacity(0.15)

                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Drop video file to inspect")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if appState.isLoading {
            ZStack {
                Color.black.opacity(0.5)

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Loading video...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Drop Delegate (Alternative implementation for more control)

struct VideoDropDelegate: DropDelegate {
    let appState: AppState
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.movie, .video])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        return appState.handleDrop(providers: info.itemProviders(for: [.movie, .video]))
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
