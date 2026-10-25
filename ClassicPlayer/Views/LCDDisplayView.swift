import SwiftUI
import UIKit

struct LCDDisplayView: View {
    @ObservedObject var viewModel: PlayerViewModel

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        ZStack {
            // Dark-gray/black inset housing bezel
            RoundedRectangle(cornerRadius: 6.0)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x18191C), Color(hex: 0x2D3036)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6.0)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.black.opacity(0.65), Color.white.opacity(0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                )

            // Inner 4:3 LCD Canvas seated inside the dark bezel with subtle 1px inner drop shadow
            ZStack {
                switch viewModel.screenMode {
                case .videoFullCanvas:
                    VideoPlayerLCDView(
                        player: viewModel.playbackEngine.player,
                        currentTime: viewModel.playbackEngine.currentTime,
                        duration: viewModel.playbackEngine.duration,
                        repeatMode: viewModel.playbackEngine.repeatMode
                    )

                case .splitBrowser:
                    VStack(spacing: 0) {
                        RetroStatusBarView(
                            customPlayerName: viewModel.customPlayerName,
                            playbackState: viewModel.playbackEngine.playbackState,
                            isHoldLocked: viewModel.isHoldLocked,
                            batteryLevel: viewModel.batteryLevel
                        )
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .zIndex(2)

                        SplitBrowserView(
                            page: viewModel.currentPage,
                            navigationDirection: viewModel.navigationDirection,
                            previewImage: viewModel.previewImageForCurrentSelection,
                            previewTitle: viewModel.previewTitleForCurrentSelection,
                            previewSubtitle: viewModel.previewSubtitleForCurrentSelection
                        )
                    }

                case .audioNowPlaying:
                    VStack(spacing: 0) {
                        RetroStatusBarView(
                            customPlayerName: viewModel.customPlayerName,
                            playbackState: viewModel.playbackEngine.playbackState,
                            isHoldLocked: viewModel.isHoldLocked,
                            batteryLevel: viewModel.batteryLevel
                        )
                        .transaction { transaction in
                            transaction.animation = nil
                        }

                        NowPlayingLCDView(
                            item: viewModel.playbackEngine.currentItem,
                            queueIndex: viewModel.playbackEngine.queueIndex,
                            queueCount: viewModel.playbackEngine.queue.count,
                            currentTime: viewModel.playbackEngine.currentTime,
                            duration: viewModel.playbackEngine.duration,
                            repeatMode: viewModel.playbackEngine.repeatMode,
                            isShuffleEnabled: viewModel.isShuffleEnabled
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4.0))
            .overlay(
                // Subtle 1px inner drop shadow along the top & edges so the white LCD panel feels physically recessed
                RoundedRectangle(cornerRadius: 4.0)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.black.opacity(0.42), Color.black.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
            )
            .padding(3.5)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
    }
}
