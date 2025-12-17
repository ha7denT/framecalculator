import SwiftUI
import AVKit

/// Custom video player view that hides AVKit's default controls.
/// Uses AVPlayerView directly with controlsStyle set to none.
struct CustomVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        playerView.allowsPictureInPicturePlayback = false
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
