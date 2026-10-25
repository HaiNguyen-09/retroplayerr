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
    let isScrubbing: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            BorderlessAVPlayerViewController(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if isScrubbing {
                // Translucent HUD overlay when scrubbing video with the Click Wheel
                HStack(spacing: 8) {
                    Text(formatTime(currentTime))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    GeometryReader { geo in
                        let progress = duration > 0 ? CGFloat(min(max(0, currentTime / duration), 1.0)) : 0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.28))
                                .frame(height: 5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x1D4ED8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 5)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 10)

                    Text("-\(formatTime(max(0, duration - currentTime)))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.68))
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
