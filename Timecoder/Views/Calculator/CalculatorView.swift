import SwiftUI
import AppKit

/// Main calculator view combining display, frame rate picker, and keypad.
struct CalculatorView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    /// Creates a calculator view with an optional external view model.
    /// - Parameter viewModel: The view model to use. If nil, creates a new one internally.
    init(viewModel: CalculatorViewModel? = nil) {
        self.viewModel = viewModel ?? CalculatorViewModel()
    }

    var body: some View {
        VStack(spacing: 8) {
            // Frame rate picker (right-aligned)
            HStack {
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

            // Pending operation indicator
            if let operation = viewModel.pendingOperation,
               viewModel.hasPendingOperation {
                PendingOperationView(operation: operation)
            }

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
            viewModel.enterDigit(digit)
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
    let operation: CalculatorOperation

    var body: some View {
        HStack(spacing: 4) {
            Text("Operation:")
                .foregroundColor(.secondary)
            Text(operation.symbol)
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
