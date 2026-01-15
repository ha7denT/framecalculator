import Foundation
import Combine
import AppKit

/// Operations available in the timecode calculator.
enum CalculatorOperation: String, CaseIterable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"
    case framesToTimecode = "F→TC"
    case timecodeToFrames = "TC→F"

    var symbol: String { rawValue }
}

/// Entry mode for the calculator display.
enum EntryMode {
    case timecode   // HH:MM:SS:FF entry
    case frames     // Raw frame count entry
}

/// Components of a timecode that can be validated.
enum TimecodeComponent: CaseIterable {
    case hours
    case minutes
    case seconds
    case frames
}

/// View model managing calculator state and operations.
final class CalculatorViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current timecode being displayed.
    @Published private(set) var currentTimecode: Timecode

    /// The selected frame rate for calculations.
    @Published var frameRate: FrameRate {
        didSet {
            // Update current timecode to new frame rate (preserve frame count)
            currentTimecode = currentTimecode.converting(to: frameRate)
            if let stored = storedTimecode {
                storedTimecode = stored.converting(to: frameRate)
            }
        }
    }

    /// The currently selected/pending operation.
    @Published private(set) var pendingOperation: CalculatorOperation?

    /// Whether an operation was just performed (for display feedback).
    @Published private(set) var justCalculated: Bool = false

    /// The current entry mode.
    @Published private(set) var entryMode: EntryMode = .timecode

    /// Raw digit entry buffer (for digit-by-digit entry).
    @Published private(set) var digitBuffer: String = ""

    /// Whether we're in the middle of entering a number.
    @Published private(set) var isEntering: Bool = false

    /// Error message to display, if any.
    @Published var errorMessage: String?

    /// The multiplier value for multiply operations.
    @Published var multiplierText: String = "2"

    /// The digit currently being pressed via keyboard (for visual feedback).
    /// Resets to nil after a brief delay.
    @Published private(set) var keyboardPressedDigit: Int? = nil

    // MARK: - Private Properties

    /// Stored first operand for binary operations.
    private var storedTimecode: Timecode?

    /// Whether the next digit entry should clear the display.
    private var shouldClearOnNextEntry: Bool = true

    // MARK: - Computed Properties

    /// The display string for the current value (used for clipboard operations).
    var displayString: String {
        if isEntering && !digitBuffer.isEmpty {
            return formatDigitBuffer()
        }
        if entryMode == .frames {
            return "\(currentTimecode.frames)f"
        }
        return currentTimecode.formatted()
    }

    /// Always returns the formatted timecode string (for display purposes).
    var formattedTimecodeString: String {
        if isEntering && !digitBuffer.isEmpty && entryMode == .timecode {
            return formatDigitBuffer()
        }
        return currentTimecode.formatted()
    }

    /// The frame count of the current timecode.
    var currentFrameCount: Int {
        if isEntering && !digitBuffer.isEmpty && entryMode == .frames {
            return Int(digitBuffer) ?? 0
        }
        return currentTimecode.frames
    }

    /// Whether there's a pending operation with a stored value.
    var hasPendingOperation: Bool {
        pendingOperation != nil && storedTimecode != nil
    }

    /// Returns which timecode components are currently invalid during entry.
    /// Used for visual feedback to show the user which values will fail validation.
    var invalidComponents: Set<TimecodeComponent> {
        guard isEntering && !digitBuffer.isEmpty && entryMode == .timecode else {
            return []
        }

        let components = parseDigitBuffer()
        var invalid: Set<TimecodeComponent> = []

        if components.minutes >= 60 {
            invalid.insert(.minutes)
        }
        if components.seconds >= 60 {
            invalid.insert(.seconds)
        }
        if components.frames >= frameRate.nominalFrameRate {
            invalid.insert(.frames)
        }

        return invalid
    }

    // MARK: - Initialization

    init(frameRate: FrameRate = .fps24) {
        self.frameRate = frameRate
        self.currentTimecode = .zero(at: frameRate)
    }

    // MARK: - Digit Entry

    /// Appends a digit to the current entry.
    /// - Parameters:
    ///   - digit: The digit to enter (0-9)
    ///   - fromKeyboard: If true, triggers visual feedback on the corresponding button
    func enterDigit(_ digit: Int, fromKeyboard: Bool = false) {
        guard digit >= 0 && digit <= 9 else { return }

        clearErrorIfNeeded()

        // Trigger visual feedback for keyboard input
        if fromKeyboard {
            keyboardPressedDigit = digit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.keyboardPressedDigit = nil
            }
        }

        if shouldClearOnNextEntry {
            digitBuffer = ""
            shouldClearOnNextEntry = false
            isEntering = true
            justCalculated = false
        }

        // Limit entry length (8 digits for timecode: HHMMSSFF)
        if digitBuffer.count < 8 {
            digitBuffer += String(digit)
        }
    }

    /// Removes the last entered digit.
    func deleteDigit() {
        if !digitBuffer.isEmpty {
            digitBuffer.removeLast()
        }
    }

    /// Shifts current entry up one field and fills vacated field with 00.
    /// Example: "32" (00:00:00:32) → "3200" (00:00:32:00) → "320000" (00:32:00:00)
    /// No effect if all four fields already have values (buffer length >= 7).
    func insertColonShift() {
        // Only works in timecode mode
        guard entryMode == .timecode else { return }

        // Ensure we're in entry mode
        if !isEntering {
            isEntering = true
            shouldClearOnNextEntry = false
        }

        // If buffer is 7+ digits, all fields have values - no effect
        // (7 digits means at least 1 digit in hours field after padding)
        if digitBuffer.count >= 7 {
            return
        }

        // Shift left by appending "00" (max 8 digits total)
        let newBuffer = digitBuffer + "00"
        if newBuffer.count <= 8 {
            digitBuffer = newBuffer
        } else {
            // Truncate to 8 digits (shouldn't happen given the >= 7 check above)
            digitBuffer = String(newBuffer.prefix(8))
        }
    }

    /// Clears the current entry.
    func clearEntry() {
        digitBuffer = ""
        isEntering = false
        shouldClearOnNextEntry = true
        currentTimecode = .zero(at: frameRate)
        errorMessage = nil
    }

    /// Clears everything including stored operand and pending operation.
    func clearAll() {
        clearEntry()
        storedTimecode = nil
        pendingOperation = nil
        justCalculated = false
    }

    /// Commits the digit buffer to the current timecode.
    func commitEntry() {
        guard isEntering && !digitBuffer.isEmpty else { return }

        let components = parseDigitBuffer()

        // Validate components
        if components.minutes >= 60 {
            errorMessage = "Minutes must be 0-59"
            return
        }
        if components.seconds >= 60 {
            errorMessage = "Seconds must be 0-59"
            return
        }
        if components.frames >= frameRate.nominalFrameRate {
            errorMessage = "Frames must be 0-\(frameRate.nominalFrameRate - 1)"
            return
        }

        currentTimecode = Timecode(
            hours: components.hours,
            minutes: components.minutes,
            seconds: components.seconds,
            frames: components.frames,
            frameRate: frameRate
        )

        digitBuffer = ""
        isEntering = false
        shouldClearOnNextEntry = true
    }

    // MARK: - Operations

    /// Selects an operation to perform.
    func selectOperation(_ operation: CalculatorOperation) {
        clearErrorIfNeeded()

        // Commit any pending entry (respecting current entry mode)
        if isEntering {
            if entryMode == .frames {
                commitFrameEntry()
            } else {
                commitEntry()
            }
        }

        switch operation {
        case .add, .subtract:
            // Binary operations - store current value and wait for second operand
            storedTimecode = currentTimecode
            pendingOperation = operation
            shouldClearOnNextEntry = true

        case .multiply, .divide:
            // Multiply/divide needs a scalar, handled separately
            storedTimecode = currentTimecode
            pendingOperation = operation
            shouldClearOnNextEntry = true

        case .framesToTimecode:
            // Convert frame count to timecode (already done by display)
            // This mode lets user enter raw frame count
            entryMode = .frames
            digitBuffer = ""
            isEntering = true
            shouldClearOnNextEntry = false
            pendingOperation = operation

        case .timecodeToFrames:
            // Show current timecode as frame count
            entryMode = .frames
            pendingOperation = nil
            justCalculated = true
        }
    }

    /// Executes the pending operation (equals button).
    func executeOperation() {
        // Commit any pending entry first
        if isEntering {
            if entryMode == .frames {
                commitFrameEntry()
            } else {
                commitEntry()
            }
        }

        guard let operation = pendingOperation else {
            // No pending operation, just ensure we're in timecode mode
            entryMode = .timecode
            return
        }

        switch operation {
        case .add:
            guard let stored = storedTimecode else { return }
            currentTimecode = stored + currentTimecode

        case .subtract:
            guard let stored = storedTimecode else { return }
            currentTimecode = stored - currentTimecode

        case .multiply:
            guard let multiplier = Int(multiplierText), multiplier > 0 else {
                errorMessage = "Invalid multiplier"
                return
            }
            currentTimecode = currentTimecode * multiplier

        case .divide:
            guard let divisor = Int(multiplierText), divisor > 0 else {
                errorMessage = "Invalid divisor"
                return
            }
            currentTimecode = Timecode(frames: currentTimecode.frames / divisor, frameRate: frameRate)

        case .framesToTimecode:
            // Conversion already done when frame entry was committed
            break

        case .timecodeToFrames:
            // Already showing frame count
            break
        }

        // Reset state (preserve display mode)
        storedTimecode = nil
        pendingOperation = nil
        // Don't reset entryMode - keep user's preferred display mode
        shouldClearOnNextEntry = true
        justCalculated = true
    }

    /// Commits a frame count entry.
    private func commitFrameEntry() {
        guard isEntering && !digitBuffer.isEmpty else { return }

        if let frames = Int(digitBuffer) {
            currentTimecode = Timecode(frames: frames, frameRate: frameRate)
        }

        digitBuffer = ""
        isEntering = false
        shouldClearOnNextEntry = true
        // Don't reset entryMode - stay in frame mode
    }

    /// Toggles between frames and timecode display modes.
    /// The underlying value stays the same, only the display format changes.
    func toggleDisplayMode() {
        // Commit any pending entry first
        if isEntering && !digitBuffer.isEmpty {
            if entryMode == .frames {
                // Parse as frame count
                if let frames = Int(digitBuffer) {
                    currentTimecode = Timecode(frames: frames, frameRate: frameRate)
                }
            } else {
                // Parse as timecode
                commitEntry()
            }
            digitBuffer = ""
            isEntering = false
        }

        // Toggle the display mode
        if entryMode == .frames {
            entryMode = .timecode
        } else {
            entryMode = .frames
        }

        pendingOperation = nil
        shouldClearOnNextEntry = true
    }

    // MARK: - Direct Value Setting

    /// Sets the current timecode directly (e.g., from paste).
    func setTimecode(_ timecode: Timecode) {
        currentTimecode = timecode.converting(to: frameRate)
        digitBuffer = ""
        isEntering = false
        shouldClearOnNextEntry = true
        justCalculated = false
    }

    /// Sets the current timecode from a frame count.
    func setFrames(_ frames: Int) {
        currentTimecode = Timecode(frames: frames, frameRate: frameRate)
        digitBuffer = ""
        isEntering = false
        shouldClearOnNextEntry = true
    }

    /// Parses a timecode string and sets it as current value.
    func parseAndSetTimecode(_ string: String) {
        do {
            let timecode = try Timecode(string, frameRate: frameRate)
            setTimecode(timecode)
        } catch {
            errorMessage = "Invalid timecode format"
        }
    }

    // MARK: - Clipboard

    /// Returns the current value as a copyable string.
    func copyableString() -> String {
        if entryMode == .frames {
            return "\(currentTimecode.frames)f"
        }
        return currentTimecode.formatted()
    }

    /// Pastes a value from the clipboard.
    /// Accepts timecode formats (HH:MM:SS:FF, HH:MM:SS;FF) or plain numbers (frames).
    func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespaces) else {
            return
        }

        clearErrorIfNeeded()

        // Try to parse as timecode first (contains : or ;)
        if string.contains(":") || string.contains(";") {
            // Parse timecode string
            do {
                let timecode = try Timecode(string, frameRate: frameRate)
                setTimecode(timecode)
            } catch {
                // Try parsing as just digits (user may have copied "01234567")
                let digitsOnly = string.filter { $0.isNumber }
                if !digitsOnly.isEmpty {
                    pasteDigits(digitsOnly)
                } else {
                    errorMessage = "Invalid timecode format"
                }
            }
        } else if string.hasSuffix("f") || string.hasSuffix("F") {
            // Frame count with 'f' suffix (e.g., "1234f")
            let frameString = string.dropLast()
            if let frames = Int(frameString) {
                setFrames(frames)
                entryMode = .frames
            } else {
                errorMessage = "Invalid frame count"
            }
        } else if let frames = Int(string) {
            // Plain number - treat as frame count if large, or digits if small
            if frames > 99999999 {
                // Too large for timecode digits, treat as frame count
                setFrames(frames)
                entryMode = .frames
            } else {
                // Could be timecode digits (e.g., "01234567" for 01:23:45:67)
                // or a frame count - treat as digits for timecode entry
                pasteDigits(string)
            }
        } else {
            // Try extracting just the digits
            let digitsOnly = string.filter { $0.isNumber }
            if !digitsOnly.isEmpty {
                pasteDigits(digitsOnly)
            } else {
                errorMessage = "Cannot paste: no valid number found"
            }
        }
    }

    /// Pastes a string of digits directly into the digit buffer.
    private func pasteDigits(_ digits: String) {
        // Limit to 8 digits (HHMMSSFF)
        let truncated = String(digits.suffix(8))
        digitBuffer = truncated
        isEntering = true
        shouldClearOnNextEntry = true
        entryMode = .timecode
    }

    // MARK: - Private Helpers

    /// Formats the digit buffer as a timecode string for display.
    private func formatDigitBuffer() -> String {
        if entryMode == .frames {
            return (digitBuffer.isEmpty ? "0" : digitBuffer) + "f"
        }

        // Pad to 8 digits for HH:MM:SS:FF
        let padded = String(repeating: "0", count: max(0, 8 - digitBuffer.count)) + digitBuffer
        let h = String(padded.prefix(2))
        let m = String(padded.dropFirst(2).prefix(2))
        let s = String(padded.dropFirst(4).prefix(2))
        let f = String(padded.suffix(2))

        let separator = frameRate.isDropFrame ? ";" : ":"
        return "\(h):\(m):\(s)\(separator)\(f)"
    }

    /// Parses the digit buffer into timecode components.
    private func parseDigitBuffer() -> (hours: Int, minutes: Int, seconds: Int, frames: Int) {
        let padded = String(repeating: "0", count: max(0, 8 - digitBuffer.count)) + digitBuffer

        let h = Int(padded.prefix(2)) ?? 0
        let m = Int(padded.dropFirst(2).prefix(2)) ?? 0
        let s = Int(padded.dropFirst(4).prefix(2)) ?? 0
        let f = Int(padded.suffix(2)) ?? 0

        return (h, m, s, f)
    }

    /// Clears error message if one exists.
    private func clearErrorIfNeeded() {
        if errorMessage != nil {
            errorMessage = nil
        }
    }
}
