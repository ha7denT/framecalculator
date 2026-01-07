import SwiftUI

/// Calculator keypad with numeric and operation buttons using Liquid Glass styling.
struct KeypadView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    private let buttonSpacing: CGFloat = 8
    private let buttonSize: CGFloat = 48

    /// Keypad width: 4 buttons + 3 spaces
    private var keypadWidth: CGFloat {
        buttonSize * 4 + buttonSpacing * 3
    }

    var body: some View {
        VStack(spacing: buttonSpacing) {
            // Operation mode row (centered above keypad)
            HStack(spacing: buttonSpacing) {
                // Frame/Timecode toggle button
                FrameTimecodeToggleButton(viewModel: viewModel, size: buttonSize)

                GlassButton(
                    label: "AC",
                    size: buttonSize,
                    action: { viewModel.clearAll() }
                )
                GlassButton(
                    label: "C",
                    size: buttonSize,
                    action: { viewModel.clearEntry() }
                )
            }

            // Keypad area with fixed width (ensures equals button matches)
            VStack(spacing: buttonSpacing) {
                // Number pad with operators (4 rows aligned)
                HStack(spacing: buttonSpacing) {
                    // Numbers grid
                    VStack(spacing: buttonSpacing) {
                        HStack(spacing: buttonSpacing) {
                            NumberButton(digit: 7, size: buttonSize) { viewModel.enterDigit(7) }
                            NumberButton(digit: 8, size: buttonSize) { viewModel.enterDigit(8) }
                            NumberButton(digit: 9, size: buttonSize) { viewModel.enterDigit(9) }
                        }
                        HStack(spacing: buttonSpacing) {
                            NumberButton(digit: 4, size: buttonSize) { viewModel.enterDigit(4) }
                            NumberButton(digit: 5, size: buttonSize) { viewModel.enterDigit(5) }
                            NumberButton(digit: 6, size: buttonSize) { viewModel.enterDigit(6) }
                        }
                        HStack(spacing: buttonSpacing) {
                            NumberButton(digit: 1, size: buttonSize) { viewModel.enterDigit(1) }
                            NumberButton(digit: 2, size: buttonSize) { viewModel.enterDigit(2) }
                            NumberButton(digit: 3, size: buttonSize) { viewModel.enterDigit(3) }
                        }
                        HStack(spacing: buttonSpacing) {
                            // Wide 0 button spanning two columns
                            Button(action: { viewModel.enterDigit(0) }) {
                                Text("0")
                                    .font(.system(size: 20, weight: .regular, design: .rounded))
                                    .frame(width: buttonSize * 2 + buttonSpacing, height: buttonSize)
                            }
                            .buttonStyle(.glass)
                            .clipShape(Capsule())

                            DeleteButton(size: buttonSize) { viewModel.deleteDigit() }
                        }
                    }

                    // Operators column (4 buttons to match 4 number rows) - Orange tint
                    VStack(spacing: buttonSpacing) {
                        OperatorButton(
                            symbol: "÷",
                            isSelected: viewModel.pendingOperation == .divide,
                            size: buttonSize,
                            action: { viewModel.selectOperation(.divide) }
                        )
                        OperatorButton(
                            symbol: "×",
                            isSelected: viewModel.pendingOperation == .multiply,
                            size: buttonSize,
                            action: { viewModel.selectOperation(.multiply) }
                        )
                        OperatorButton(
                            symbol: "−",
                            isSelected: viewModel.pendingOperation == .subtract,
                            size: buttonSize,
                            action: { viewModel.selectOperation(.subtract) }
                        )
                        OperatorButton(
                            symbol: "+",
                            isSelected: viewModel.pendingOperation == .add,
                            size: buttonSize,
                            action: { viewModel.selectOperation(.add) }
                        )
                    }
                    .tint(.timecoderOrange)
                }

                // Equals button (fills keypad width) - Teal accent
                Button(action: { viewModel.executeOperation() }) {
                    Text("=")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.timecoderTeal)
                .clipShape(Capsule())
            }
            .frame(width: keypadWidth)

            // Multiplier/divisor input (shown when multiply or divide is selected)
            if viewModel.pendingOperation == .multiply || viewModel.pendingOperation == .divide {
                ScalarInput(
                    value: $viewModel.multiplierText,
                    label: viewModel.pendingOperation == .divide ? "Divide by:" : "Multiply by:"
                )
            }
        }
        .padding(buttonSpacing)
    }
}

// MARK: - Button Components

/// A numeric button (0-9) with circular glass styling.
private struct NumberButton: View {
    let digit: Int
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(digit)")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .clipShape(Circle())
    }
}

/// Delete/backspace button with circular glass styling.
private struct DeleteButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "delete.backward")
                .font(.system(size: 18, weight: .regular))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .clipShape(Circle())
    }
}

/// A generic glass button with text or SF Symbol.
private struct GlassButton: View {
    var label: String? = nil
    var systemImage: String? = nil
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let label = label {
                    Text(label)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .regular))
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .clipShape(Circle())
    }
}

/// An operator button (+, -, ×, ÷) with prominent glass styling.
private struct OperatorButton: View {
    let symbol: String
    var isSelected: Bool = false
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glassProminent)
        .clipShape(Circle())
        .opacity(isSelected ? 1.0 : 0.85)
    }
}

/// Input field for multiplier/divisor value.
private struct ScalarInput: View {
    @Binding var value: String
    var label: String = "Multiply by:"

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            TextField("", text: $value)
                .textFieldStyle(.roundedBorder)
                .font(.spaceMono(size: 16))
                .frame(width: 60)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

/// Toggle button for Frame↔Timecode display modes.
private struct FrameTimecodeToggleButton: View {
    @ObservedObject var viewModel: CalculatorViewModel
    let size: CGFloat

    /// Whether we're currently showing frames
    private var isShowingFrames: Bool {
        viewModel.entryMode == .frames
    }

    var body: some View {
        Button(action: { viewModel.toggleDisplayMode() }) {
            HStack(spacing: 1) {
                Text("F")
                    .foregroundColor(isShowingFrames ? .accentColor : .primary.opacity(0.6))

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)

                Text("TC")
                    .foregroundColor(!isShowingFrames ? .accentColor : .primary.opacity(0.6))
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .clipShape(Circle())
        .help(isShowingFrames ? "Show as Timecode" : "Show as Frames")
    }
}

#Preview {
    KeypadView(viewModel: CalculatorViewModel())
        .frame(width: 300)
        .padding()
}
