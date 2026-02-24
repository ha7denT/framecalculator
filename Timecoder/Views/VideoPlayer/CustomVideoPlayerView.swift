import SwiftUI
import AVKit

#if os(macOS)
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

#elseif os(iOS)
/// iOS video player view using AVPlayerViewController with controls hidden.
struct CustomVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.allowsPictureInPicturePlayback = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
#endif
