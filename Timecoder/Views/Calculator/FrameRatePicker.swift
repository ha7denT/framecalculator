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
    }
}

/// Compact frame rate picker with glass effect styling.
struct CompactFrameRatePicker: View {
    @Binding var selection: FrameRate

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
            }
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
