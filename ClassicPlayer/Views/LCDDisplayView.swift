import SwiftUI

struct LCDDisplayView: View {
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        ZStack {
            // Subtle outer recessed bevel bezel (corner radius: 4pt)
            RoundedRectangle(cornerRadius: 5.5)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x3A3D42), Color(hex: 0x8A8F98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner 4:3 LCD Canvas with 4px rounded corners
            ZStack {
                switch viewModel.screenMode {
                case .videoFullCanvas:
                    // Transition the entire 4:3 LCD canvas into a borderless AVPlayerViewController
                    VideoPlayerLCDView(
                        player: viewModel.playbackEngine.player,
                        currentTime: viewModel.playbackEngine.currentTime,
                        duration: viewModel.playbackEngine.duration,
                        isScrubbing: viewModel.isScrubbingInNowPlaying
                    )
                    .transition(.opacity)

                case .splitBrowser:
                    VStack(spacing: 0) {
                        RetroStatusBarView(
                            title: viewModel.statusBarTitle,
                            playbackState: viewModel.playbackEngine.playbackState,
                            isHoldLocked: viewModel.isHoldLocked,
                            batteryLevel: viewModel.batteryLevel
                        )

                        SplitBrowserView(
                            page: viewModel.currentPage,
                            previewImage: viewModel.previewImageForCurrentSelection
                        )
                    }
                    .transition(.opacity)

                case .audioNowPlaying:
                    VStack(spacing: 0) {
                        RetroStatusBarView(
                            title: viewModel.statusBarTitle,
                            playbackState: viewModel.playbackEngine.playbackState,
                            isHoldLocked: viewModel.isHoldLocked,
                            batteryLevel: viewModel.batteryLevel
                        )

                        NowPlayingLCDView(
                            item: viewModel.playbackEngine.currentItem,
                            queueIndex: viewModel.playbackEngine.queueIndex,
                            queueCount: viewModel.playbackEngine.queue.count,
                            currentTime: viewModel.playbackEngine.currentTime,
                            duration: viewModel.playbackEngine.duration,
                            isScrubbing: viewModel.isScrubbingInNowPlaying
                        )
                    }
                    .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4.0))
            .overlay(
                // Subtle inner LCD glass shadow & 1px dark frame
                RoundedRectangle(cornerRadius: 4.0)
                    .stroke(Color(hex: 0x22252A), lineWidth: 1.0)
            )
            .padding(2.5)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1)
    }
}
