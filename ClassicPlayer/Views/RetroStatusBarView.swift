import SwiftUI
import UIKit

private struct TextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MarqueePlayerNameView: View {
    let text: String

    @State private var textWidth: CGFloat = 0
    @State private var phaseStartDate: Date = Date()

    private let gap: CGFloat = 28.0
    private let speedPointsPerSecond: Double = 28.0
    private let pauseSeconds: Double = 1.4

    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let needsMarquee = textWidth > containerWidth && containerWidth > 10

            ZStack(alignment: needsMarquee ? .leading : .center) {
                // Hidden sizer to accurately measure the untruncated Unicode/emoji string width
                Text(text)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .background(
                        GeometryReader { textGeo in
                            Color.clear.preference(key: TextWidthPreferenceKey.self, value: textGeo.size.width)
                        }
                    )

                if needsMarquee {
                    TimelineView(.animation) { timeline in
                        let elapsed = max(0, timeline.date.timeIntervalSince(phaseStartDate))
                        let travelDistance = Double(textWidth + gap)
                        let scrollDuration = travelDistance / speedPointsPerSecond
                        let cycleDuration = pauseSeconds + scrollDuration
                        let cycleTime = elapsed.truncatingRemainder(dividingBy: max(0.1, cycleDuration))
                        let currentOffset: CGFloat = cycleTime < pauseSeconds
                            ? 0
                            : -CGFloat((cycleTime - pauseSeconds) * speedPointsPerSecond)

                        HStack(spacing: gap) {
                            Text(text)
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(Color(hex: 0x333333))
                                .fixedSize(horizontal: true, vertical: false)

                            Text(text)
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(Color(hex: 0x333333))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .offset(x: currentOffset)
                    }
                } else {
                    Text(text)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(Color(hex: 0x333333))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(width: containerWidth, height: geo.size.height, alignment: needsMarquee ? .leading : .center)
            .clipped()
        }
        .onPreferenceChange(TextWidthPreferenceKey.self) { measured in
            if abs(textWidth - measured) > 0.5 {
                textWidth = measured
                phaseStartDate = Date()
            }
        }
        .onChange(of: text) { _ in
            phaseStartDate = Date()
        }
    }
}

struct RetroStatusBarView: View {
    let customPlayerName: String
    let playbackState: PlaybackState
    let isHoldLocked: Bool
    let batteryLevel: Float

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        ZStack {
            // Metallic gradient running from #E8E8E8 at top to #C4C4C4 at bottom
            LinearGradient(
                colors: [Color(hex: 0xE8E8E8), Color(hex: 0xC4C4C4)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 6) {
                // Left: Static text "Now Playing" in 11pt Helvetica/System Bold (#222222)
                Text("Now Playing")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(Color(hex: 0x222222))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 6)

                // Center: Custom player name (static or marquee scrolling, clipped so it never collides)
                MarqueePlayerNameView(text: customPlayerName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Right: Lock icon (if on hold) + Cyan/sky blue play triangle (#0284C7) + Glossy Battery Capsule
                HStack(spacing: 5) {
                    if isHoldLocked {
                        RetroLockGlyph()
                    }
                    RetroStatusPlayIndicator(state: playbackState)
                    RetroBatteryGlyph(level: batteryLevel)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, 6)
            }
        }
        .frame(height: 20)
        .overlay(alignment: .bottom) {
            // 1px solid bottom divider line (#8A8A8A)
            Rectangle()
                .fill(Color(hex: 0x8A8A8A))
                .frame(height: onePixel)
        }
    }
}
