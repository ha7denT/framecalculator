import SwiftUI
import AppKit

/// Main calculator view combining display, frame rate picker, and keypad.
struct CalculatorView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    /// Icon for the mode button (top-left).
    var modeButtonIcon: String = "play.rectangle"

    /// Tooltip for the mode button.
    var modeButtonHelp: String = "Open video (⌘O)"

    /// Callback when the mode button is tapped.
    var onModeButtonTapped: (() -> Void)?

    /// Creates a calculator view with configurable mode button.
    /// - Parameters:
    ///   - viewModel: The view model to use. If nil, creates a new one internally.
    ///   - modeButtonIcon: SF Symbol name for the mode button.
    ///   - modeButtonHelp: Tooltip text for the mode button.
    ///   - onModeButtonTapped: Callback when the mode button is tapped.
    init(
        viewModel: CalculatorViewModel? = nil,
        modeButtonIcon: String = "play.rectangle",
        modeButtonHelp: String = "Open video (⌘O)",
        onModeButtonTapped: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel ?? CalculatorViewModel()
        self.modeButtonIcon = modeButtonIcon
        self.modeButtonHelp = modeButtonHelp
        self.onModeButtonTapped = onModeButtonTapped
    }

    var body: some View {
        VStack(spacing: 8) {
            // Top bar: Mode button (left) and frame rate picker (right)
            HStack {
                // Mode button (open video in calculator mode, return to calculator in logging mode)
                Button(action: { onModeButtonTapped?() }) {
                    Image(systemName: modeButtonIcon)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(.timecoderTeal)
                .clipShape(Circle())
                .help(modeButtonHelp)

                Spacer()

                CompactFrameRatePicker(selection: $viewModel.frameRate)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Error message
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            // Pending operation indicator (always reserve space to prevent layout shift)
            PendingOperationView(operation: viewModel.pendingOperation)
                .opacity(viewModel.hasPendingOperation ? 1 : 0)

            // Main timecode display
            TimecodeDisplayView(
                formattedTimecode: viewModel.formattedTimecodeString,
                frameCount: viewModel.currentFrameCount,
                displayMode: viewModel.entryMode == .frames ? .frames : .timecode,
                hasError: viewModel.errorMessage != nil,
                isPendingOperation: viewModel.hasPendingOperation,
                invalidComponents: viewModel.invalidComponents
            )
            .padding(.horizontal, 12)

            // Keypad
            KeypadView(viewModel: viewModel)
        }
        .padding(.bottom, 12)
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 340)
        .background(KeyboardHandlerView(viewModel: viewModel))
        .onCopyCommand {
            copyTimecode()
            return [NSItemProvider(object: viewModel.copyableString() as NSString)]
        }
        .onPasteCommand(of: [.plainText]) { providers in
            pasteTimecode(from: providers)
        }
    }

    // MARK: - Clipboard

    private func copyTimecode() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(viewModel.copyableString(), forType: .string)
    }

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
}

// MARK: - Keyboard Handler (NSViewRepresentable for macOS 13 compatibility)

/// NSView-based keyboard handler for macOS 13 compatibility.
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

// MARK: - Supporting Views

/// Banner showing error messages.
private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 13))

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.15))
        )
        .padding(.horizontal, 16)
    }
}

/// Shows the pending operation and stored value.
private struct PendingOperationView: View {
    let operation: CalculatorOperation?

    var body: some View {
        HStack(spacing: 4) {
            Text("Operation:")
                .foregroundColor(.secondary)
            Text(operation?.symbol ?? "+")
                .font(.spaceMono(size: 14, weight: .bold))
                .foregroundColor(.accentColor)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
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
