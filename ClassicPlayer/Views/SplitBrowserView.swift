import SwiftUI
import UIKit

struct SplitBrowserView: View {
    let page: MenuPage
    let previewImage: UIImage?

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2.0

            HStack(spacing: 0) {
                // Left 50%: Hierarchical Menu List
                leftMenuListPane
                    .frame(width: halfWidth, height: geo.size.height)

                // 1px Center Split Divider
                Rectangle()
                    .fill(Color(hex: 0xC2C4C8))
                    .frame(width: onePixel, height: geo.size.height)

                // Right 50%: Artwork / Video Thumbnail Preview + Horizontal Reflection
                rightPreviewPane(width: halfWidth - onePixel, height: geo.size.height)
                    .frame(width: halfWidth - onePixel, height: geo.size.height)
            }
            .background(Color.white)
        }
    }

    private var leftMenuListPane: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(page.rows.enumerated()), id: \.element.id) { index, row in
                        let isSelected = (index == page.selectedIndex)
                        menuRowView(row: row, isSelected: isSelected)
                            .id(row.id)
                    }
                }
            }
            .onChange(of: page.selectedIndex) { _ in
                if let selectedRow = page.selectedRow {
                    withAnimation(.linear(duration: 0.06)) {
                        proxy.scrollTo(selectedRow.id, anchor: nil)
                    }
                }
            }
            .onChange(of: page.id) { _ in
                if let selectedRow = page.selectedRow {
                    proxy.scrollTo(selectedRow.id, anchor: .top)
                }
            }
        }
    }

    private func menuRowView(row: MenuRowItem, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Text(row.title)
                .font(.system(size: 12.5, weight: .bold, design: .default))
                .foregroundColor(isSelected ? .white : .black)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if let valueText = row.valueText {
                Text(valueText)
                    .font(.system(size: 11.5, weight: .bold, design: .default))
                    .foregroundColor(isSelected ? .white.opacity(0.92) : Color(hex: 0x555555))
                    .lineLimit(1)
            }

            if row.showsChevron {
                RetroMenuChevron(isSelected: isSelected)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 23)
        .background {
            if isSelected {
                // Deep glossy blue selection banner (#3B82F6 to #1D4ED8)
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x1D4ED8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Subtle top glossy highlight strip
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 9)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Color.white
            }
        }
    }

    private func rightPreviewPane(width: CGFloat, height: CGFloat) -> some View {
        let artworkSide = min(width * 0.78, height * 0.64)
        let reflectionHeight = artworkSide * 0.34

        return ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFFFFFF), Color(hex: 0xECEEF2)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 1) {
                Spacer(minLength: 8)

                // Primary square artwork or vintage monochrome disc engraving
                artworkCard(side: artworkSide)
                    .frame(width: artworkSide, height: artworkSide)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)

                // Smooth subtle horizontal reflection beneath the preview
                artworkCard(side: artworkSide)
                    .frame(width: artworkSide, height: artworkSide)
                    .scaleEffect(x: 1.0, y: -1.0, anchor: .center)
                    .frame(width: artworkSide, height: reflectionHeight, alignment: .top)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.32), location: 0.0),
                                .init(color: .black.opacity(0.10), location: 0.55),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Spacer(minLength: 4)
            }
        }
    }

    @ViewBuilder
    private func artworkCard(side: CGFloat) -> some View {
        if let image = previewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(hex: 0x999EA6), lineWidth: onePixel)
                )
        } else {
            VintageMonochromeDiscEngraving()
                .frame(width: side, height: side)
        }
    }
}
