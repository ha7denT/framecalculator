import SwiftUI
import UniformTypeIdentifiers

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
        .onChange(of: appState.currentMetadata) { metadata in
            // Sync frame rate when video is loaded
            if let metadata = metadata {
                calculatorVM.frameRate = metadata.matchingFrameRate
            }
        }
        .onChange(of: appState.mode) { newMode in
            // Only resize when returning to calculator mode
            resizeWindowForMode(newMode)
        }
        .onAppear {
            // Set correct size on launch
            resizeWindowForMode(.calculator)
        }
    }

    // MARK: - Window Management

    private func resizeWindowForMode(_ mode: AppMode) {
        // Only resize when returning to calculator mode
        // Video mode sizes itself naturally via SwiftUI content sizing
        guard mode == .calculator else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else { return }

            let targetSize = NSSize(width: 320, height: 520)
            let currentFrame = window.frame
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y + currentFrame.height - targetSize.height,
                width: targetSize.width,
                height: targetSize.height
            )
            window.setFrame(newFrame, display: true, animate: true)
        }
    }

    // MARK: - Standalone Calculator

    private var standaloneCalculatorView: some View {
        CalculatorView(viewModel: calculatorVM)
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
