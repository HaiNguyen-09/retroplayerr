import SwiftUI
import UIKit

struct RetroStatusBarView: View {
    let title: String
    let playbackState: PlaybackState
    let isHoldLocked: Bool
    let batteryLevel: Float

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xECECEC), Color(hex: 0xD5D5D5)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 6) {
                // Left: Tiny Play/Pause indicator icon (solid black polygon)
                RetroStatusPlayIndicator(state: playbackState)
                    .padding(.leading, 6)

                Spacer(minLength: 4)

                // Right: Current lock icon if on hold + custom retro battery glyph
                HStack(spacing: 5) {
                    if isHoldLocked {
                        RetroLockGlyph()
                    }
                    RetroBatteryGlyph(level: batteryLevel)
                }
                .padding(.trailing, 6)
            }

            // Center: Centered title "Player" in 12pt Bold Sans/Monospace
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(.black)
                .lineLimit(1)
        }
        .frame(height: 20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: 0x9B9B9B))
                .frame(height: onePixel)
        }
    }
}
