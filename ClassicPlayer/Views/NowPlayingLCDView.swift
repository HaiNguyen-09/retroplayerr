import SwiftUI
import UIKit

struct NowPlayingLCDView: View {
    let item: MediaItem?
    let queueIndex: Int
    let queueCount: Int
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isScrubbing: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Upper metadata + artwork area
                HStack(alignment: .top, spacing: 12) {
                    artworkWithReflection(side: min(geo.size.width * 0.36, geo.size.height * 0.56))

                    VStack(alignment: .leading, spacing: 4) {
                        if queueCount > 0 {
                            Text("\(queueIndex + 1) of \(queueCount)")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color(hex: 0x5A5F68))
                        }

                        Text(item?.title ?? "No Track Selected")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(2)

                        Text(item?.artist ?? "")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Color(hex: 0x33373E))
                            .lineLimit(1)

                        Text(item?.album ?? "")
                            .font(.system(size: 11.0, weight: .medium))
                            .foregroundColor(Color(hex: 0x666B75))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if isScrubbing {
                            Text("SCRUBBING (ROTATE WHEEL)")
                                .font(.system(size: 9.0, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: 0x1D4ED8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer(minLength: 4)

                // Lower glossy progress bar & timestamps
                VStack(spacing: 4) {
                    progressBar(width: geo.size.width - 28)

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)

                        Spacer()

                        let remaining = max(0, duration - currentTime)
                        Text("-\(formatTime(remaining))")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(
                LinearGradient(
                    colors: [Color.white, Color(hex: 0xF0F2F6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func artworkWithReflection(side: CGFloat) -> some View {
        let reflectionH = side * 0.28
        return VStack(spacing: 1) {
            artworkBox(side: side)
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)

            artworkBox(side: side)
                .frame(width: side, height: side)
                .scaleEffect(x: 1.0, y: -1.0)
                .frame(width: side, height: reflectionH, alignment: .top)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [.black.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    @ViewBuilder
    private func artworkBox(side: CGFloat) -> some View {
        if let image = item?.artworkImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(hex: 0x999EA6), lineWidth: 1.0 / UIScreen.main.scale)
                )
        } else {
            VintageMonochromeDiscEngraving()
                .frame(width: side, height: side)
        }
    }

    private func progressBar(width: CGFloat) -> some View {
        let progress: CGFloat = duration > 0 ? CGFloat(min(max(0, currentTime / duration), 1.0)) : 0.0
        let fillWidth = max(0, width * progress)

        return ZStack(alignment: .leading) {
            // Recessed metallic trough
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xC8CCD2), Color(hex: 0xE8EAEF)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: 0x8E949E), lineWidth: 1)
                )

            // Glossy blue progress fill (#3B82F6 to #1D4ED8)
            if fillWidth > 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x3B82F6), Color(hex: 0x1D4ED8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: fillWidth, height: 9)
            }

            // Diamond scrubber thumb when in scrubbing mode
            if isScrubbing {
                Rectangle()
                    .fill(Color(hex: 0x1D4ED8))
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 1)
                            .rotationEffect(.degrees(45))
                    )
                    .offset(x: min(max(0, fillWidth - 4), width - 8))
            }
        }
        .frame(width: width, height: 11)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
