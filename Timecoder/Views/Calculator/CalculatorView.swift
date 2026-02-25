import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import PhotosUI
#endif

/// Main calculator view combining display, frame rate picker, and keypad.
struct CalculatorView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    /// Icon for the mode button (top-left).
    var modeButtonIcon: String = "play.rectangle"

    /// Tooltip for the mode button.
    var modeButtonHelp: String = "Open video (⌘O)"

    /// Callback when the mode button is tapped.
    var onModeButtonTapped: (() -> Void)?

    /// Callback to open the file importer (iOS video import menu).
    var onOpenVideoFile: (() -> Void)?

    #if os(iOS)
    /// Callback when a photo library item is selected from the mode button menu.
    var onPhotoItemSelected: ((PhotosPickerItem) -> Void)?
    #endif

    /// Optional keypad button size override. When nil, uses KeypadView default (48).
    var keypadButtonSize: CGFloat? = nil

    /// Optional timecode font size override. When nil, uses TimecodeDisplayView default (36).
    var timecodeFontSize: CGFloat? = nil

    #if os(iOS)
    /// Selected photo library item for video import from mode button menu.
    @State private var selectedPhotoItem: PhotosPickerItem?

    /// Controls presentation of the photo library picker.
    @State private var showingPhotoPicker = false
    #endif

    /// Creates a calculator view with configurable mode button.
    /// - Parameters:
    ///   - viewModel: The view model to use. If nil, creates a new one internally.
    ///   - modeButtonIcon: SF Symbol name for the mode button.
    ///   - modeButtonHelp: Tooltip text for the mode button.
    ///   - onModeButtonTapped: Callback when the mode button is tapped.
    ///   - keypadButtonSize: Optional button size for keypad (nil = default 48).
    ///   - timecodeFontSize: Optional font size for timecode display (nil = default 36).
    #if os(iOS)
    init(
        viewModel: CalculatorViewModel? = nil,
        modeButtonIcon: String = "play.rectangle",
        modeButtonHelp: String = "Open video (⌘O)",
        onModeButtonTapped: (() -> Void)? = nil,
        onOpenVideoFile: (() -> Void)? = nil,
        onPhotoItemSelected: ((PhotosPickerItem) -> Void)? = nil,
        keypadButtonSize: CGFloat? = nil,
        timecodeFontSize: CGFloat? = nil
    ) {
        self.viewModel = viewModel ?? CalculatorViewModel()
        self.modeButtonIcon = modeButtonIcon
        self.modeButtonHelp = modeButtonHelp
        self.onModeButtonTapped = onModeButtonTapped
        self.onOpenVideoFile = onOpenVideoFile
        self.onPhotoItemSelected = onPhotoItemSelected
        self.keypadButtonSize = keypadButtonSize
        self.timecodeFontSize = timecodeFontSize
    }
    #else
    init(
        viewModel: CalculatorViewModel? = nil,
        modeButtonIcon: String = "play.rectangle",
        modeButtonHelp: String = "Open video (⌘O)",
        onModeButtonTapped: (() -> Void)? = nil,
        onOpenVideoFile: (() -> Void)? = nil,
        keypadButtonSize: CGFloat? = nil,
        timecodeFontSize: CGFloat? = nil
    ) {
        self.viewModel = viewModel ?? CalculatorViewModel()
        self.modeButtonIcon = modeButtonIcon
        self.modeButtonHelp = modeButtonHelp
        self.onModeButtonTapped = onModeButtonTapped
        self.onOpenVideoFile = onOpenVideoFile
        self.keypadButtonSize = keypadButtonSize
        self.timecodeFontSize = timecodeFontSize
    }
    #endif

    var body: some View {
        VStack(spacing: 8) {
            // Top bar: Mode button (left) and frame rate picker (right)
            HStack {
                // Mode button (open video in calculator mode, return to calculator in logging mode)
                #if os(iOS)
                if let onOpenVideoFile = onOpenVideoFile {
                    // iOS calculator mode: menu with file/photo library options
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
                        Image(systemName: modeButtonIcon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.timecoderTeal)
                    .clipShape(Circle())
                    .help(modeButtonHelp)
                } else if let onModeButtonTapped = onModeButtonTapped {
                    Button(action: onModeButtonTapped) {
                        Image(systemName: modeButtonIcon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.timecoderTeal)
                    .clipShape(Circle())
                    .help(modeButtonHelp)
                }
                #else
                Button(action: { onModeButtonTapped?() }) {
                    Image(systemName: modeButtonIcon)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(.timecoderTeal)
                .clipShape(Circle())
                .help(modeButtonHelp)
                .accessibilityLabel(modeButtonIcon == "play.rectangle" ? "Open video" : "Return to calculator")
                .accessibilityHint(modeButtonIcon == "play.rectangle" ? "Opens a video file for inspection" : "Closes video and returns to calculator mode")
                #endif

                Spacer()

                CompactFrameRatePicker(selection: $viewModel.frameRate)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Main timecode display (operation indicator shown inside)
            TimecodeDisplayView(
                formattedTimecode: viewModel.formattedTimecodeString,
                frameCount: viewModel.currentFrameCount,
                displayMode: viewModel.entryMode == .frames ? .frames : .timecode,
                hasError: false,
                isPendingOperation: viewModel.hasPendingOperation,
                invalidComponents: viewModel.invalidComponents,
                pendingOperation: viewModel.pendingOperation,
                primaryFontSize: timecodeFontSize ?? 36
            )
            .padding(.horizontal, 12)

            // Keypad
            KeypadView(
                viewModel: viewModel,
                buttonSize: keypadButtonSize ?? 48,
                buttonSpacing: 8
            )
        }
        .padding(.bottom, 12)
        #if os(macOS)
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 340)
        #else
        .frame(maxWidth: .infinity)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .videos)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            onPhotoItemSelected?(newItem)
            selectedPhotoItem = nil
        }
        #endif
        #if os(macOS)
        .background(KeyboardHandlerView(viewModel: viewModel))
        .onCopyCommand {
            copyTimecode()
            return [NSItemProvider(object: viewModel.copyableString() as NSString)]
        }
        .onPasteCommand(of: [.plainText]) { providers in
            pasteTimecode(from: providers)
        }
        #endif
    }

    // MARK: - Clipboard

    private func copyTimecode() {
        PlatformClipboard.copy(viewModel.copyableString())
    }

    #if os(macOS)
    private func pasteTimecode(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let string = String(data: data, encoding: .utf8) else { return }

            DispatchQueue.main.async {
                viewModel.parseAndSetTimecode(string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
    #endif
}

#if os(macOS)
// MARK: - Keyboard Handler (NSViewRepresentable for macOS)

/// NSView-based keyboard handler for macOS.
private struct KeyboardHandlerView: NSViewRepresentable {
    let viewModel: CalculatorViewModel

    func makeNSView(context: Context) -> KeyboardCaptureView {
        let view = KeyboardCaptureView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureView, context: Context) {
        nsView.viewModel = viewModel
    }
}

/// Custom NSView that captures keyboard events.
private class KeyboardCaptureView: NSView {
    weak var viewModel: CalculatorViewModel?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        // Try to reclaim first responder status after a brief delay
        // This handles the case where user clicks on the display text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            if self.window?.firstResponder != self {
                self.window?.makeFirstResponder(self)
            }
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard let viewModel = viewModel else {
            super.keyDown(with: event)
            return
        }

        let handled = handleKeyEvent(event, viewModel: viewModel)
        if !handled {
            super.keyDown(with: event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent, viewModel: CalculatorViewModel) -> Bool {
        // Check for number keys (main keyboard and numpad)
        if let characters = event.charactersIgnoringModifiers,
           let char = characters.first,
           let digit = Int(String(char)),
           digit >= 0 && digit <= 9 {
            viewModel.enterDigit(digit, fromKeyboard: true)
            return true
        }

        // Special keys
        switch event.keyCode {
        case 51: // Delete/Backspace
            viewModel.deleteDigit()
            return true

        case 53: // Escape
            viewModel.clearAll()
            return true

        case 36, 76: // Return/Enter (main and numpad)
            viewModel.executeOperation()
            return true

        default:
            break
        }

        // Character-based operations
        if let characters = event.charactersIgnoringModifiers {
            switch characters {
            case "+":
                viewModel.selectOperation(.add)
                return true

            case "-":
                viewModel.selectOperation(.subtract)
                return true

            case "*", "x", "X":
                viewModel.selectOperation(.multiply)
                return true

            case "/":
                viewModel.selectOperation(.divide)
                return true

            case "=":
                if event.modifierFlags.contains(.shift) {
                    viewModel.selectOperation(.add) // Shift+= is +
                } else {
                    viewModel.executeOperation()
                }
                return true

            case "c", "C":
                if event.modifierFlags.isEmpty {
                    viewModel.clearEntry()
                    return true
                }

            case "v", "V":
                if event.modifierFlags.contains(.command) {
                    viewModel.pasteFromClipboard()
                    return true
                }

            case ".":
                viewModel.insertColonShift()
                return true

            default:
                break
            }
        }

        return false
    }
}
#endif

// MARK: - Supporting Views

/// Banner showing error messages.
struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 13))

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.15))
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    CalculatorView(viewModel: CalculatorViewModel())
        .frame(width: 300, height: 540)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    CalculatorView(viewModel: CalculatorViewModel())
        .frame(width: 300, height: 540)
        .preferredColorScheme(.light)
}
