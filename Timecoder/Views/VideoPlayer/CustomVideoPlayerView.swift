import SwiftUI
import AVKit

/// Custom AVPlayerView subclass that doesn't accept first responder.
/// This prevents the video player from stealing keyboard focus.
class NonFocusablePlayerView: AVPlayerView {
    override var acceptsFirstResponder: Bool { false }
}

/// Custom video player view that hides AVKit's default controls.
/// Uses AVPlayerView directly with controlsStyle set to none.
struct CustomVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NonFocusablePlayerView {
        let playerView = NonFocusablePlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        playerView.allowsPictureInPicturePlayback = false
        return playerView
    }

    func updateNSView(_ nsView: NonFocusablePlayerView, context: Context) {
        nsView.player = player
    }
}
