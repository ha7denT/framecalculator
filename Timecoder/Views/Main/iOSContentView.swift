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
    @State private var showingPhotoPicker = false
    @FocusState private var isKeyboardFocused: Bool
    @ScaledMetric(relativeTo: .body) private var scaledUnit: CGFloat = 48

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
            GeometryReader { geometry in
                let baseSize = PlatformLayout.keypadButtonSize(forWidth: geometry.size.width)
                let scale = scaledUnit / 48.0
                let buttonSize = min(max(baseSize * scale, 44), 80)
                // Larger font size to fill vertical space
                let fontSize = min(geometry.size.width * 0.12, 52)

                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    CalculatorView(
                        viewModel: calculatorVM,
                        onOpenVideoFile: nil,
                        keypadButtonSize: buttonSize,
                        timecodeFontSize: fontSize
                    )
                    .frame(maxWidth: 420)

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if appState.hasStoredSession {
                        Button {
                            onOpenVideoOrRestore()
                        } label: {
                            Image(systemName: "film.stack")
                        }
                        .tint(.timecoderTeal)
                    } else {
                        calculatorVideoImportMenu
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .videos)
        }
        .focusable()
        .focused($isKeyboardFocused)
        .onAppear {
            if horizontalSizeClass == .regular {
                isKeyboardFocused = true
            }
        }
        .onKeyPress(keys: Set("0123456789".map { KeyEquivalent(Character(String($0))) })) { press in
            if let digit = Int(String(press.key.character)) {
                calculatorVM.enterDigit(digit, fromKeyboard: true)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            calculatorVM.deleteDigit()
            return .handled
        }
        .onKeyPress(.escape) {
            calculatorVM.clearAll()
            return .handled
        }
        .onKeyPress(.return) {
            calculatorVM.executeOperation()
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: "+-*/=.cC")) { press in
            let char = press.key.character
            let hasCommand = press.modifiers.contains(.command)

            switch char {
            case "+":
                calculatorVM.selectOperation(.add)
                return .handled
            case "-":
                calculatorVM.selectOperation(.subtract)
                return .handled
            case "*":
                calculatorVM.selectOperation(.multiply)
                return .handled
            case "/":
                calculatorVM.selectOperation(.divide)
                return .handled
            case "=":
                calculatorVM.executeOperation()
                return .handled
            case ".":
                calculatorVM.insertColonShift()
                return .handled
            case "c", "C":
                if hasCommand {
                    PlatformClipboard.copy(calculatorVM.copyableString())
                } else {
                    calculatorVM.clearEntry()
                }
                return .handled
            default:
                return .ignored
            }
        }
        .onKeyPress(characters: .init(charactersIn: "vV")) { press in
            if press.modifiers.contains(.command) {
                calculatorVM.pasteFromClipboard()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Calculator Video Import Menu

    private var calculatorVideoImportMenu: some View {
        Menu {
            Button {
                onOpenVideoFile()
            } label: {
                Label("Choose File", systemImage: "folder")
            }
            Button {
                showingPhotoPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "video.badge.plus")
        }
        .tint(.timecoderTeal)
    }

    // MARK: - Video Mode

    private var videoModeView: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
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
            onSwitchToCalculator: onSwitchToCalculator,
            onOpenVideoFile: onOpenVideoFile
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
            onSwitchToCalculator: onSwitchToCalculator,
            onOpenVideoFile: onOpenVideoFile
        )
    }
}
#endif
