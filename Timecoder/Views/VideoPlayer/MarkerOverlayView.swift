import SwiftUI

/// Displays the active marker's text as an overlay on the video frame.
/// Positioned in the top-left corner with a semi-transparent black background
/// and a coloured dot indicating marker colour.
struct MarkerOverlayView: View {
    let marker: Marker

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(marker.color.displayColor)
                .frame(width: 8, height: 8)

            Text(marker.note.isEmpty ? marker.color.displayName : marker.note)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
