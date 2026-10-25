import SwiftUI
import UIKit

struct NowPlayingLCDView: View {
    let item: MediaItem?
    let queueIndex: Int
    let queueCount: Int
    let currentTime: TimeInterval
    let duration: TimeInterval
    let repeatMode: RepeatMode
    let isShuffleEnabled: Bool

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Main Body: Left Artwork (105x105 + 35pt reflection) & Right Metadata Stack
                HStack(alignment: .top, spacing: 12) {
                    artworkWithReflection
                        .padding(.top, 12)
                        .padding(.leading, 12)

                    VStack(alignment: .leading, spacing: 3) {
                        // 1. Track Title: Bold, 13pt system font, primary black (#000000), line limit 2
                        Text(item?.title ?? "No Track Selected")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: 0x000000))
                            .lineLimit(2)

                        // 2. Artist Name: Regular, 11pt, neutral dark gray (#4B5563)
                        Text(item?.artist ?? "Unknown Artist")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(hex: 0x4B5563))
                            .lineLimit(1)

                        // 3. Album Name: Regular, 11pt, neutral dark gray (#4B5563)
                        Text(displayAlbumName)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(hex: 0x4B5563))
                            .lineLimit(1)

                        // 4. Rating: Row of 5 star glyphs (+ Repeat/Shuffle indicator if active)
                        HStack(spacing: 5) {
                            RetroStarRatingRow(rating: 5)

                            if repeatMode != .off {
                                Text(repeatMode == .once ? "1" : "∞")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 0.5)
                                    .background(
                                        Capsule().fill(Color(hex: 0x2563EB))
                                    )
                            }

                            if isShuffleEnabled {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(Color(hex: 0x2563EB))
                            }
                        }
                        .padding(.top, 2)

                        // 5. Track Count: "X of Y" placed strictly at the BOTTOM of the text stack in 10pt regular (#374151)
                        Text(queueCount > 0 ? "\(queueIndex + 1) of \(queueCount)" : "0 of 0")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color(hex: 0x374151))
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                }

                Spacer(minLength: 0)

                // Skeuomorphic Aqua Scrubber Bar with Time Labels level with the bar + mirrored reflection below
                HStack(alignment: .top, spacing: 7) {
                    // Left: Elapsed time in 10pt bold monospace (#111827), level with scrubber bar
                    Text(formatTime(currentTime))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: 0x111827))
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(y: -1.5)

                    // Center: Skeuomorphic Aqua Capsule + soft downward reflection
                    GeometryReader { barGeo in
                        let barW = max(10, barGeo.size.width)
                        VStack(spacing: 1) {
                            aquaScrubberCapsule(width: barW)
                            aquaScrubberCapsule(width: barW)
                                .scaleEffect(x: 1.0, y: -1.0)
                                .frame(height: 5, alignment: .top)
                                .clipped()
                                .mask(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.26), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .frame(height: 15)

                    // Right: Remaining time with minus sign in 10pt bold monospace (#111827), level with scrubber bar
                    let remaining = max(0, duration - currentTime)
                    Text("-\(formatTime(remaining))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: 0x111827))
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(y: -1.5)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color(hex: 0xFFFFFF))
        }
    }

    private var displayAlbumName: String {
        guard let album = item?.album, !album.isEmpty else {
            return "Unknown Album"
        }
        return album
    }

    private var artworkWithReflection: some View {
        let side: CGFloat = 105.0
        let reflectionHeight: CGFloat = 35.0

        return VStack(spacing: 0) {
            artworkSquare(side: side)
                .frame(width: side, height: side)

            artworkSquare(side: side)
                .frame(width: side, height: side)
                .scaleEffect(x: 1.0, y: -1.0)
                .frame(width: side, height: reflectionHeight, alignment: .top)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), Color.black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: side, height: side + reflectionHeight, alignment: .top)
    }

    @ViewBuilder
    private func artworkSquare(side: CGFloat) -> some View {
        if let image = item?.artworkImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(Color(hex: 0xD1D5DB), lineWidth: 1.0)
                )
        } else {
            VintageMonochromeDiscEngraving()
                .frame(width: side, height: side)
                .overlay(
                    Rectangle()
                        .stroke(Color(hex: 0xD1D5DB), lineWidth: 1.0)
                )
        }
    }

    private func aquaScrubberCapsule(width: CGFloat) -> some View {
        let progress: CGFloat = duration > 0 ? CGFloat(min(max(0, currentTime / duration), 1.0)) : 0.0
        let fillWidth = max(0, width * progress)

        return ZStack(alignment: .leading) {
            // Track (Background): Height 8pt, rounded capsule shape, recessed metallic gradient (#E5E7EB to #D1D5DB)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xE5E7EB), Color(hex: 0xD1D5DB)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: 8)
                .overlay(
                    Capsule()
                        .stroke(Color(hex: 0x9CA3AF), lineWidth: 0.8)
                )

            // Fill (Progress): Glossy aqua-blue gradient (#60A5FA -> #2563EB -> #1D4ED8) + upper-third white highlight rod
            if fillWidth > 0 {
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(hex: 0x60A5FA), location: 0.0),
                                    .init(color: Color(hex: 0x2563EB), location: 0.52),
                                    .init(color: Color(hex: 0x1D4ED8), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: fillWidth, height: 8)

                    // Cylindrical glass rod specular highlight on the upper third
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.75), Color.white.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(0, fillWidth - 3), height: 2.4)
                        .padding(.top, 1.0)
                }
                .clipShape(Capsule())
            }
        }
        .frame(width: width, height: 8)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
