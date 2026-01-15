import SwiftUI

/// Calculator keypad with numeric and operation buttons.
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
            // Top row: F↔TC, AC, C, ⌫ (4 buttons)
            HStack(spacing: buttonSpacing) {
                // Frame/Timecode toggle button
                FrameTimecodeToggleButton(viewModel: viewModel, size: buttonSize)

                SecondaryButton(label: "AC", size: buttonSize) {
                    viewModel.clearAll()
                }
                SecondaryButton(label: "C", size: buttonSize) {
                    viewModel.clearEntry()
                }
                DeleteButton(size: buttonSize) {
                    viewModel.deleteDigit()
                }
            }

            // Keypad area with fixed width (ensures equals button matches)
            VStack(spacing: buttonSpacing) {
                // Number pad with operators (4 rows aligned)
                HStack(spacing: buttonSpacing) {
                    // Numbers grid
                    VStack(spacing: buttonSpacing) {
                        HStack(spacing: buttonSpacing) {
                            NumberButton(digit: 7, size: buttonSize, action: { viewModel.enterDigit(7) }, keyboardPressed: viewModel.keyboardPressedDigit == 7)
                            NumberButton(digit: 8, size: buttonSize, action: { viewModel.enterDigit(8) }, keyboardPressed: viewModel.keyboardPressedDigit == 8)
                            NumberButton(digit: 9, size: buttonSize, action: { viewModel.enterDigit(9) }, keyboardPressed: viewModel.keyboardPressedDigit == 9)
                        }
                        HStack(spacing: buttonSpacing) {
                            NumberButton(digit: 4, size: buttonSize, action: { viewModel.enterDigit(4) }, keyboardPressed: viewModel.keyboardPressedDigit == 4)
                            NumberButton(digit: 5, size: buttonSize, action: { viewModel.enterDigit(5) }, keyboardPressed: viewModel.keyboardPressedDigit == 5)
                            NumberButton(digit: 6, size: buttonSize, action: { viewModel.enterDigit(6) }, keyboardPressed: viewModel.keyboardPressedDigit == 6)
                        }
                        HStack(spacing: buttonSpacing) {
                            NumberButton(digit: 1, size: buttonSize, action: { viewModel.enterDigit(1) }, keyboardPressed: viewModel.keyboardPressedDigit == 1)
                            NumberButton(digit: 2, size: buttonSize, action: { viewModel.enterDigit(2) }, keyboardPressed: viewModel.keyboardPressedDigit == 2)
                            NumberButton(digit: 3, size: buttonSize, action: { viewModel.enterDigit(3) }, keyboardPressed: viewModel.keyboardPressedDigit == 3)
                        }
                        HStack(spacing: buttonSpacing) {
                            // Wide 0 button spanning two columns
                            WideZeroButton(size: buttonSize, spacing: buttonSpacing, action: { viewModel.enterDigit(0) }, keyboardPressed: viewModel.keyboardPressedDigit == 0)
                            ColonButton(size: buttonSize) {
                                viewModel.insertColonShift()
                            }
                        }
                    }

                    // Operators column (4 buttons to match 4 number rows)
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
                }

                // Equals button (fills keypad width)
                EqualsButton(width: keypadWidth) {
                    viewModel.executeOperation()
                }
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

/// Off-white/cream color for number buttons
private let numberButtonColor = Color(red: 0.95, green: 0.93, blue: 0.90)
private let numberButtonPressedColor = Color.white

/// A numeric button (0-9) with off-white background and black text.
private struct NumberButton: View {
    let digit: Int
    let size: CGFloat
    let action: () -> Void
    var keyboardPressed: Bool = false
    @State private var isPressed = false

    private var showPressed: Bool {
        isPressed || keyboardPressed
    }

    var body: some View {
        Text("\(digit)")
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundColor(.black)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(showPressed ? numberButtonPressedColor : numberButtonColor)
            )
            .contentShape(Circle())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Wide 0 button spanning two columns.
private struct WideZeroButton: View {
    let size: CGFloat
    let spacing: CGFloat
    let action: () -> Void
    var keyboardPressed: Bool = false
    @State private var isPressed = false

    private var showPressed: Bool {
        isPressed || keyboardPressed
    }

    var body: some View {
        Text("0")
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundColor(.black)
            .frame(width: size * 2 + spacing, height: size)
            .background(
                Capsule()
                    .fill(showPressed ? numberButtonPressedColor : numberButtonColor)
            )
            .contentShape(Capsule())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Colon button that shifts entry up one field and inserts :00.
/// Same styling as number buttons (off-white/cream background).
private struct ColonButton: View {
    let size: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Text(":")
            .font(.system(size: 24, weight: .medium, design: .rounded))
            .foregroundColor(.black)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isPressed ? numberButtonPressedColor : numberButtonColor)
            )
            .contentShape(Circle())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Color for top row buttons (lighter than BG, darker than number buttons)
private let topRowButtonColor = Color.primary.opacity(0.12)
private let topRowButtonPressedColor = Color.primary.opacity(0.2)

/// Delete/backspace button for top row.
private struct DeleteButton: View {
    let size: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Image(systemName: "delete.backward")
            .font(.system(size: 18, weight: .regular))
            .foregroundColor(.primary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isPressed ? topRowButtonPressedColor : topRowButtonColor)
            )
            .contentShape(Circle())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Secondary button (AC, C) for top row.
private struct SecondaryButton: View {
    let label: String
    let size: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(.primary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isPressed ? topRowButtonPressedColor : topRowButtonColor)
            )
            .contentShape(Circle())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// An operator button (+, -, ×, ÷) with orange background.
private struct OperatorButton: View {
    let symbol: String
    var isSelected: Bool = false
    let size: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    private var backgroundColor: Color {
        if isPressed {
            return Color.timecoderOrange.opacity(0.6)
        }
        return isSelected ? Color.timecoderOrange : Color.timecoderOrange.opacity(0.85)
    }

    var body: some View {
        Text(symbol)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .contentShape(Circle())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Equals button with teal background spanning full width.
private struct EqualsButton: View {
    let width: CGFloat
    let action: () -> Void
    @State private var isPressed = false

    private var backgroundColor: Color {
        isPressed ? Color.timecoderTeal.opacity(0.6) : Color.timecoderTeal
    }

    var body: some View {
        Text("=")
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .frame(width: width, height: 44)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .contentShape(Capsule())
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
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
    @State private var isPressed = false

    /// Whether we're currently showing frames
    private var isShowingFrames: Bool {
        viewModel.entryMode == .frames
    }

    var body: some View {
        HStack(spacing: 1) {
            Text("F")
                .foregroundColor(isShowingFrames ? .timecoderTeal : .primary.opacity(0.6))

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)

            Text("TC")
                .foregroundColor(!isShowingFrames ? .timecoderTeal : .primary.opacity(0.6))
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .frame(width: size, height: size)
        .background(
            Circle()
                .fill(isPressed ? topRowButtonPressedColor : topRowButtonColor)
        )
        .contentShape(Circle())
        .onTapGesture {
            viewModel.toggleDisplayMode()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .help(isShowingFrames ? "Show as Timecode" : "Show as Frames")
    }
}

#Preview {
    KeypadView(viewModel: CalculatorViewModel())
        .frame(width: 300)
        .padding()
        .preferredColorScheme(.dark)
}
