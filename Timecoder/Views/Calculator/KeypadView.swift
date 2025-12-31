import SwiftUI

/// Calculator keypad with numeric and operation buttons.
struct KeypadView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    private let buttonSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: buttonSpacing) {
            // Operation mode row
            HStack(spacing: buttonSpacing) {
                // Frame/Timecode toggle button
                FrameTimecodeToggleButton(viewModel: viewModel)

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

            // Number pad with operators (4 rows aligned)
            HStack(spacing: buttonSpacing) {
                // Numbers grid with grid lines
                NumberPadGrid(viewModel: viewModel, buttonSpacing: buttonSpacing)

                // Operators column (4 buttons to match 4 number rows)
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
                        title: "÷",
                        isSelected: viewModel.pendingOperation == .divide,
                        style: .primary,
                        action: { viewModel.selectOperation(.divide) }
                    )
                }
            }

            // Equals button (full width, orange)
            Button(action: { viewModel.executeOperation() }) {
                Text("=")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(CalculatorButtonStyle(style: .destructive))

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

/// Number pad grid with subtle grid lines between buttons.
private struct NumberPadGrid: View {
    @ObservedObject var viewModel: CalculatorViewModel
    let buttonSpacing: CGFloat

    private let gridLineColor = Color.primary.opacity(0.1)
    private let buttonWidth: CGFloat = 56
    private let buttonHeight: CGFloat = 48

    var body: some View {
        ZStack {
            // Grid lines background
            gridLines

            // Buttons
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
        }
    }

    @ViewBuilder
    private var gridLines: some View {
        let totalWidth = buttonWidth * 3 + buttonSpacing * 2
        let totalHeight = buttonHeight * 4 + buttonSpacing * 3

        Canvas { context, size in
            // Vertical grid lines (between columns)
            for i in 1..<3 {
                let x = CGFloat(i) * (buttonWidth + buttonSpacing) - buttonSpacing / 2
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: totalHeight))
                context.stroke(path, with: .color(gridLineColor), lineWidth: 1)
            }

            // Horizontal grid lines (between rows)
            for i in 1..<4 {
                let y = CGFloat(i) * (buttonHeight + buttonSpacing) - buttonSpacing / 2
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: totalWidth, y: y))
                context.stroke(path, with: .color(gridLineColor), lineWidth: 1)
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .allowsHitTesting(false)
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

    /// Whether we're currently showing frames
    private var isShowingFrames: Bool {
        viewModel.entryMode == .frames
    }

    var body: some View {
        Button(action: { viewModel.toggleDisplayMode() }) {
            HStack(spacing: 4) {
                Text("F")
                    .foregroundColor(isShowingFrames ? .timecoderTeal : .primary)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                Text("TC")
                    .foregroundColor(!isShowingFrames ? .timecoderTeal : .primary)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(CalculatorButtonStyle(style: .secondary, isSelected: true))
        .help(isShowingFrames ? "Show as Timecode" : "Show as Frames")
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
                        isSelected ? Color.timecoderTeal : Color.clear,
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
            baseColor = .timecoderButtonBackground
        case .secondary:
            baseColor = .timecoderButtonBackground.opacity(0.8)
        case .primary:
            baseColor = .timecoderTeal.opacity(0.85)
        case .accent:
            baseColor = .timecoderTeal
        case .destructive:
            baseColor = .timecoderOrange.opacity(0.9)
        }

        return isPressed ? baseColor.opacity(0.7) : baseColor
    }
}

#Preview {
    KeypadView(viewModel: CalculatorViewModel())
        .frame(width: 320)
        .padding()
}
