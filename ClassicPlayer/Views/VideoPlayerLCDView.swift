import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Borderless AVPlayerViewController representation that fills the 4:3 LCD canvas during video (.mp4/.mov) playback.
struct BorderlessAVPlayerViewController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = false
        controller.view.backgroundColor = .black
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}

struct VideoPlayerLCDView: View {
    let player: AVPlayer
    let currentTime: TimeInterval
    let duration: TimeInterval
    let repeatMode: RepeatMode

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BorderlessAVPlayerViewController(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if repeatMode != .off {
                Text(repeatMode == .once ? "REPEAT ONCE" : "REPEAT FOREVER")
                    .font(.system(size: 9.0, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.65))
                    )
                    .padding(8)
            }
        }
    }
}
