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
    private let speedPointsPerSecond: Double = 26.0
    private let pauseSeconds: Double = 1.5

    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let needsMarquee = textWidth > containerWidth && containerWidth > 10

            ZStack(alignment: needsMarquee ? .leading : .center) {
                // Hidden sizer to measure untruncated string width with matching 11pt bold font
                Text(text)
                    .font(.system(size: 11, weight: .bold, design: .default))
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
                                .font(.system(size: 11, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0x222222))
                                .fixedSize(horizontal: true, vertical: false)

                            Text(text)
                                .font(.system(size: 11, weight: .bold, design: .default))
                                .foregroundColor(Color(hex: 0x222222))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .offset(x: currentOffset)
                    }
                } else {
                    Text(text)
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: 0x222222))
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
    let leftTitle: String
    let customPlayerName: String
    let playbackState: PlaybackState
    let isHoldLocked: Bool
    let batteryLevel: Float

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        GeometryReader { geo in
            // Symmetric side reservation (84pt left, 84pt right) guarantees the center container
            // is always mathematically centered on the full LCD width and never overlaps left/right items.
            let sideReservedWidth: CGFloat = 84.0
            let centerBandWidth = max(40.0, geo.size.width - (sideReservedWidth * 2.0))

            ZStack {
                // Metallic gradient running from #E8E8E8 at top to #C4C4C4 at bottom
                LinearGradient(
                    colors: [Color(hex: 0xE8E8E8), Color(hex: 0xC4C4C4)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Left & Right anchored status items
                HStack(spacing: 0) {
                    // Left: "Now Playing" (only when actively playing) or current category title
                    Text(leftTitle)
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: 0x222222))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: sideReservedWidth - 6.0, alignment: .leading)
                        .padding(.leading, 6)

                    Spacer(minLength: 0)

                    // Right: Lock icon (if on hold) + Cyan/sky blue play triangle (#0284C7) + Glossy Battery Capsule
                    HStack(spacing: 5) {
                        if isHoldLocked {
                            RetroLockGlyph()
                        }
                        if playbackState != .stopped {
                            RetroStatusPlayIndicator(state: playbackState)
                        }
                        RetroBatteryGlyph(level: batteryLevel)
                    }
                    .frame(width: sideReservedWidth - 6.0, alignment: .trailing)
                    .padding(.trailing, 6)
                }

                // Center: Custom Player Name strictly centered relative to the entire LCD width
                MarqueePlayerNameView(text: customPlayerName)
                    .frame(width: centerBandWidth, height: geo.size.height)
                    .clipped()
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
