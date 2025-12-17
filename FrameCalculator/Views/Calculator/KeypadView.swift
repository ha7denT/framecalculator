import SwiftUI

/// Calculator keypad with numeric and operation buttons.
struct KeypadView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    private let buttonSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: buttonSpacing) {
            // Operation mode row
            HStack(spacing: buttonSpacing) {
                OperationButton(
                    title: "F→TC",
                    isSelected: viewModel.pendingOperation == .framesToTimecode,
                    action: { viewModel.selectOperation(.framesToTimecode) }
                )
                OperationButton(
                    title: "TC→F",
                    isSelected: viewModel.pendingOperation == .timecodeToFrames,
                    action: { viewModel.selectOperation(.timecodeToFrames) }
                )
                OperationButton(
                    title: "AC",
                    style: .destructive,
                    action: { viewModel.clearAll() }
                )
                OperationButton(
                    title: "C",
                    style: .secondary,
                    action: { viewModel.clearEntry() }
                )
            }

            // Number pad with operators
            HStack(spacing: buttonSpacing) {
                // Numbers grid
                VStack(spacing: buttonSpacing) {
                    HStack(spacing: buttonSpacing) {
                        NumberButton(digit: 7) { viewModel.enterDigit(7) }
                        NumberButton(digit: 8) { viewModel.enterDigit(8) }
                        NumberButton(digit: 9) { viewModel.enterDigit(9) }
                    }
                    HStack(spacing: buttonSpacing) {
                        NumberButton(digit: 4) { viewModel.enterDigit(4) }
                        NumberButton(digit: 5) { viewModel.enterDigit(5) }
                        NumberButton(digit: 6) { viewModel.enterDigit(6) }
                    }
                    HStack(spacing: buttonSpacing) {
                        NumberButton(digit: 1) { viewModel.enterDigit(1) }
                        NumberButton(digit: 2) { viewModel.enterDigit(2) }
                        NumberButton(digit: 3) { viewModel.enterDigit(3) }
                    }
                    HStack(spacing: buttonSpacing) {
                        NumberButton(digit: 0, isWide: true) { viewModel.enterDigit(0) }
                        DeleteButton { viewModel.deleteDigit() }
                    }
                }

                // Operators column
                VStack(spacing: buttonSpacing) {
                    OperationButton(
                        title: "+",
                        isSelected: viewModel.pendingOperation == .add,
                        style: .primary,
                        action: { viewModel.selectOperation(.add) }
                    )
                    OperationButton(
                        title: "−",
                        isSelected: viewModel.pendingOperation == .subtract,
                        style: .primary,
                        action: { viewModel.selectOperation(.subtract) }
                    )
                    OperationButton(
                        title: "×",
                        isSelected: viewModel.pendingOperation == .multiply,
                        style: .primary,
                        action: { viewModel.selectOperation(.multiply) }
                    )
                    OperationButton(
                        title: "=",
                        style: .accent,
                        action: { viewModel.executeOperation() }
                    )
                }
            }

            // Multiplier input (shown when multiply is selected)
            if viewModel.pendingOperation == .multiply {
                MultiplierInput(value: $viewModel.multiplierText)
            }
        }
        .padding(buttonSpacing)
    }
}

// MARK: - Button Components

/// A numeric button (0-9).
private struct NumberButton: View {
    let digit: Int
    var isWide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(digit)")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .frame(maxWidth: isWide ? .infinity : nil)
                .frame(width: isWide ? nil : 56, height: 48)
        }
        .buttonStyle(CalculatorButtonStyle(style: .number))
    }
}

/// Delete/backspace button.
private struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "delete.left")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 56, height: 48)
        }
        .buttonStyle(CalculatorButtonStyle(style: .secondary))
    }
}

/// An operation button (+, -, ×, =, etc.).
private struct OperationButton: View {
    let title: String
    var isSelected: Bool = false
    var style: CalculatorButtonStyleType = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(CalculatorButtonStyle(style: style, isSelected: isSelected))
    }
}

/// Input field for multiplier value.
private struct MultiplierInput: View {
    @Binding var value: String

    var body: some View {
        HStack(spacing: 8) {
            Text("Multiply by:")
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

// MARK: - Button Styles

/// Style types for calculator buttons.
enum CalculatorButtonStyleType {
    case number
    case secondary
    case primary
    case accent
    case destructive
}

/// Custom button style for calculator buttons.
struct CalculatorButtonStyle: ButtonStyle {
    let style: CalculatorButtonStyleType
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch style {
        case .number:
            return .primary
        case .secondary:
            return .primary
        case .primary:
            return .white
        case .accent:
            return .white
        case .destructive:
            return .white
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        let baseColor: Color
        switch style {
        case .number:
            baseColor = Color(nsColor: .controlBackgroundColor)
        case .secondary:
            baseColor = Color(nsColor: .controlBackgroundColor).opacity(0.8)
        case .primary:
            baseColor = .accentColor.opacity(0.8)
        case .accent:
            baseColor = .accentColor
        case .destructive:
            baseColor = .red.opacity(0.8)
        }

        return isPressed ? baseColor.opacity(0.7) : baseColor
    }
}

#Preview {
    KeypadView(viewModel: CalculatorViewModel())
        .frame(width: 320)
        .padding()
}
