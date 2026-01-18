import SwiftUI

/// Dropdown picker for selecting frame rate.
struct FrameRatePicker: View {
    @Binding var selection: FrameRate

    var body: some View {
        Picker("Frame Rate", selection: $selection) {
            ForEach(FrameRate.allStandardRates, id: \.self) { rate in
                Text(rate.displayName)
                    .tag(rate)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(minWidth: 100)
        .accessibilityLabel("Frame rate")
        .accessibilityValue(selection.accessibilityName)
        .accessibilityHint("Select frame rate for timecode calculations")
    }
}

/// Compact frame rate picker with glass effect styling.
struct CompactFrameRatePicker: View {
    @Binding var selection: FrameRate
    @State private var showCustomDialog = false

    /// Check if current selection is a custom rate
    private var isCustomRate: Bool {
        if case .custom = selection {
            return true
        }
        return false
    }

    var body: some View {
        Menu {
            ForEach(FrameRate.allStandardRates, id: \.self) { rate in
                Button(action: { selection = rate }) {
                    HStack {
                        Text(rate.displayName)
                        if rate == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityLabel(rate.accessibilityName)
            }

            Divider()

            Button(action: { showCustomDialog = true }) {
                HStack {
                    Text("Custom...")
                    if isCustomRate {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityLabel("Custom frame rate")
            .accessibilityHint("Enter a custom frame rate value")
        } label: {
            HStack(spacing: 4) {
                Text(selection.displayName)
                    .font(.spaceMono(size: 14, weight: .bold))
                Text("fps")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Frame rate")
        .accessibilityValue(selection.accessibilityName)
        .accessibilityHint("Double-tap to change frame rate")
        .sheet(isPresented: $showCustomDialog) {
            CustomFPSDialog(selection: $selection, isPresented: $showCustomDialog)
        }
    }
}

/// Dialog for entering a custom frame rate value.
struct CustomFPSDialog: View {
    @Binding var selection: FrameRate
    @Binding var isPresented: Bool
    @State private var inputText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Custom Frame Rate")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                TextField("e.g., 47.95", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .accessibilityLabel("Frame rate value")
                    .accessibilityHint("Enter frames per second as a number")

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .accessibilityLabel("Error: \(error)")
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel")
                .accessibilityHint("Closes dialog without saving")

                Button("OK") {
                    applyCustomRate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(inputText.isEmpty)
                .accessibilityLabel("OK")
                .accessibilityHint("Applies the custom frame rate")
            }
        }
        .padding(24)
        .frame(minWidth: 250)
        .onAppear {
            // Pre-fill with current custom value if one exists
            if case .custom(let value) = selection {
                inputText = String(format: "%.3g", value)
            }
        }
    }

    private func applyCustomRate() {
        guard let rate = Double(inputText) else {
            errorMessage = "Please enter a valid number"
            return
        }

        guard rate > 0 else {
            errorMessage = "Frame rate must be greater than 0"
            return
        }

        guard rate <= 1000 else {
            errorMessage = "Frame rate must be 1000 or less"
            return
        }

        selection = .custom(rate)
        isPresented = false
    }
}

#Preview("Standard Picker") {
    FrameRatePicker(selection: .constant(.fps24))
        .padding()
}

#Preview("Compact Picker") {
    CompactFrameRatePicker(selection: .constant(.fps29_97_df))
        .padding()
}
