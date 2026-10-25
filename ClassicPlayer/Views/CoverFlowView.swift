import AVFoundation
import SwiftUI
import UIKit

struct CoverFlowView: View {
    let albums: [CoverFlowAlbumGroup]
    let selectedAlbumIndex: Int
    let isFlippedToTracklist: Bool
    let selectedTrackIndex: Int

    private let cardSide: CGFloat = 104.0
    private let reflectionHeight: CGFloat = 38.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Pure black background (#000000) filling the entire 4:3 LCD area below the status bar
                Color.black

                if albums.isEmpty {
                    VStack(spacing: 6) {
                        VintageMonochromeDiscEngraving()
                            .frame(width: 72, height: 72)
                        Text("No Albums in Cover Flow")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Import audio files to browse covers")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color(hex: 0x9CA3AF))
                    }
                } else {
                    // 3D Cover Flow Carousel Stage
                    ZStack {
                        ForEach(visibleIndices, id: \.self) { index in
                            let relativeIndex = index - selectedAlbumIndex
                            let isCenter = (relativeIndex == 0)
                            let album = albums[index]

                            coverCard3D(
                                album: album,
                                relativeIndex: relativeIndex,
                                isCenter: isCenter,
                                stageWidth: geo.size.width
                            )
                            .zIndex(Double(100 - abs(relativeIndex)))
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .animation(.easeOut(duration: 0.24), value: selectedAlbumIndex)
                    .animation(.easeInOut(duration: 0.34), value: isFlippedToTracklist)

                    // Bottom Album Title (bold white) & Artist Name (gray) when viewing front covers
                    if !isFlippedToTracklist, albums.indices.contains(selectedAlbumIndex) {
                        let activeAlbum = albums[selectedAlbumIndex]
                        VStack(spacing: 2) {
                            Spacer()
                            Text(activeAlbum.albumTitle)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(activeAlbum.artistName)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Color(hex: 0x9CA3AF))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    /// Only render cards within ±4 positions of the selected center card for 60fps performance.
    private var visibleIndices: [Int] {
        guard !albums.isEmpty else { return [] }
        let lower = max(0, selectedAlbumIndex - 4)
        let upper = min(albums.count - 1, selectedAlbumIndex + 4)
        guard lower <= upper else { return [] }
        return Array(lower...upper)
    }

    private func coverCard3D(
        album: CoverFlowAlbumGroup,
        relativeIndex: Int,
        isCenter: Bool,
        stageWidth: CGFloat
    ) -> some View {
        // Calculate 3D rotation angle, scale, and horizontal offset
        let yAngle: Double = {
            if relativeIndex == 0 {
                return isFlippedToTracklist ? 180.0 : 0.0
            } else if relativeIndex < 0 {
                return 60.0
            } else {
                return -60.0
            }
        }()

        let scale: CGFloat = {
            if relativeIndex == 0 {
                return isFlippedToTracklist ? 1.38 : 1.0
            } else {
                return 0.80
            }
        }()

        let xOffset: CGFloat = {
            if relativeIndex == 0 {
                return 0
            }
            let sign: CGFloat = relativeIndex < 0 ? -1.0 : 1.0
            let steps = CGFloat(abs(relativeIndex))
            let baseSpread: CGFloat = isFlippedToTracklist ? 115.0 : 56.0
            let stepSpacing: CGFloat = 24.0
            return sign * (baseSpread + (steps - 1.0) * stepSpacing)
        }()

        let sideDimOpacity: Double = {
            if relativeIndex == 0 { return 0.0 }
            if isFlippedToTracklist { return 0.65 }
            return min(0.55, Double(abs(relativeIndex)) * 0.14)
        }()

        return ZStack {
            if isCenter && isFlippedToTracklist {
                // Back of the jewel case (pre-rotated 180° around Y so when the container flips 180°, text reads forward)
                jewelCaseTracklistBack(album: album)
                    .frame(width: 146, height: 118)
                    .rotation3DEffect(.degrees(180), axis: (x: 0.0, y: 1.0, z: 0.0))
            } else {
                // Front Album Cover + Unconstrained Downward Mirrored Reflection into Pure Black
                frontArtworkFace(album: album, dimOpacity: sideDimOpacity)
                    .frame(width: cardSide, height: cardSide)
                    .overlay(alignment: .bottom) {
                        frontArtworkFace(album: album, dimOpacity: sideDimOpacity)
                            .frame(width: cardSide, height: cardSide)
                            .scaleEffect(x: 1.0, y: -1.0)
                            .frame(width: cardSide, height: reflectionHeight, alignment: .top)
                            .clipped()
                            .mask(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.36), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .offset(y: reflectionHeight + 1.0)
                            .allowsHitTesting(false)
                    }
            }
        }
        .scaleEffect(scale)
        .rotation3DEffect(
            .degrees(yAngle),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            anchor: .center,
            perspective: 0.55
        )
        .offset(x: xOffset, y: isCenter && isFlippedToTracklist ? 0 : -12)
    }

    @ViewBuilder
    private func frontArtworkFace(album: CoverFlowAlbumGroup, dimOpacity: Double) -> some View {
        ZStack {
            if let image = album.artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardSide, height: cardSide)
                    .clipped()
            } else {
                VintageMonochromeDiscEngraving()
                    .frame(width: cardSide, height: cardSide)
            }

            if dimOpacity > 0 {
                Color.black.opacity(dimOpacity)
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.65), radius: 6, x: 0, y: 3)
    }

    /// Back of the flipped jewel case showing the album header and interactive tracklist.
    private func jewelCaseTracklistBack(album: CoverFlowAlbumGroup) -> some View {
        VStack(spacing: 0) {
            // Top Jewel Case Header
            HStack(spacing: 6) {
                if let image = album.artworkImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipped()
                } else {
                    VintageMonochromeDiscEngraving()
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(album.albumTitle)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(album.artistName)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(Color(hex: 0xD1D5DB))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x374151), Color(hex: 0x1F2937)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Rectangle()
                .fill(Color(hex: 0x4B5563))
                .frame(height: 0.8)

            // Scrollable Tracklist inside the flipped jewel case
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { idx, track in
                            let isSelected = (idx == selectedTrackIndex)
                            HStack(spacing: 4) {
                                Text("\(idx + 1).")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSelected ? .white : Color(hex: 0x9CA3AF))

                                Text(track.title)
                                    .font(.system(size: 9.0, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 2)

                                Text(formatDuration(track.duration))
                                    .font(.system(size: 8.0, weight: .medium, design: .monospaced))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : Color(hex: 0x9CA3AF))
                            }
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background {
                                if isSelected {
                                    LinearGradient(
                                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x1D4ED8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                } else {
                                    Color(hex: 0x111827)
                                }
                            }
                            .id(track.id)
                        }
                    }
                }
                .background(Color(hex: 0x111827))
                .onChange(of: selectedTrackIndex) { newIdx in
                    if album.tracks.indices.contains(newIdx) {
                        proxy.scrollTo(album.tracks[newIdx].id, anchor: nil)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.0)
        )
        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
