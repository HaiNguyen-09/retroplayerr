import SwiftUI
import UIKit

struct SplitBrowserView: View {
    let page: MenuPage
    let navigationDirection: MenuNavigationDirection
    let previewImage: UIImage?
    let previewTitle: String?
    let previewSubtitle: String?

    @State private var activePage: MenuPage?
    @State private var outgoingPage: MenuPage?
    @State private var activeOffsetX: CGFloat = 0
    @State private var outgoingOffsetX: CGFloat = 0

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2.0
            let currentDisplayed = activePage ?? page

            HStack(spacing: 0) {
                // Left 50%: Synchronized Left/Right Sliding Menu Column (Strictly Clipped)
                ZStack {
                    Color.white

                    if let outgoing = outgoingPage {
                        leftMenuListPane(for: outgoing)
                            .frame(width: halfWidth, height: geo.size.height)
                            .offset(x: outgoingOffsetX)
                    }

                    leftMenuListPane(for: currentDisplayed)
                        .frame(width: halfWidth, height: geo.size.height)
                        .offset(x: activeOffsetX)
                }
                .frame(width: halfWidth, height: geo.size.height)
                .clipped()
                .zIndex(0)
                .onAppear {
                    activePage = page
                    activeOffsetX = 0
                }
                .onChange(of: page) { newPage in
                    guard let current = activePage else {
                        activePage = newPage
                        return
                    }

                    if current.id != newPage.id {
                        // Synchronized slide animation:
                        // Forward (drill in): right-to-left (+halfWidth -> 0, 0 -> -halfWidth)
                        // Backward (MENU): left-to-right (-halfWidth -> 0, 0 -> +halfWidth)
                        let isForward = (navigationDirection == .forward)
                        outgoingPage = current
                        activePage = newPage
                        outgoingOffsetX = 0
                        activeOffsetX = isForward ? halfWidth : -halfWidth

                        withAnimation(.easeInOut(duration: 0.21)) {
                            outgoingOffsetX = isForward ? -halfWidth : halfWidth
                            activeOffsetX = 0
                        }
                    } else {
                        // Same page (e.g. wheel selection index or inline setting value updated)
                        activePage = newPage
                    }
                }

                // 1px Center Split Divider (Stationary)
                Rectangle()
                    .fill(Color(hex: 0xC2C4C8))
                    .frame(width: onePixel, height: geo.size.height)
                    .zIndex(1)

                // Right 50%: Anchored Static Preview Pane (Artwork + Reflection + Metadata)
                rightPreviewPane(width: halfWidth - onePixel, height: geo.size.height)
                    .frame(width: halfWidth - onePixel, height: geo.size.height)
                    .clipped()
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .zIndex(1)
            }
            .background(Color.white)
        }
    }

    private func leftMenuListPane(for menuPage: MenuPage) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(menuPage.rows.enumerated()), id: \.element.id) { index, row in
                        let isSelected = (index == menuPage.selectedIndex)
                        menuRowView(row: row, isSelected: isSelected)
                            .id(row.id)
                    }
                }
            }
            .background(Color.white)
            .onChange(of: menuPage.selectedIndex) { _ in
                if let selectedRow = menuPage.selectedRow {
                    withAnimation(.linear(duration: 0.05)) {
                        proxy.scrollTo(selectedRow.id, anchor: nil)
                    }
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
                    .truncationMode(.tail)
                    .frame(maxWidth: 68, alignment: .trailing)
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
        let artworkSide = min(width * 0.72, height * 0.54)
        let reflectionHeight = artworkSide * 0.26

        return ZStack {
            Color.white

            VStack(spacing: 1) {
                Spacer(minLength: 6)

                // Primary square artwork or vintage monochrome disc engraving
                artworkCard(side: artworkSide)
                    .frame(width: artworkSide, height: artworkSide)
                    .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)

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
                                .init(color: .black.opacity(0.08), location: 0.55),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Spacer(minLength: 2)

                // Highlighted item metadata preview (read-only)
                VStack(spacing: 1) {
                    if let previewTitle, !previewTitle.isEmpty {
                        Text(previewTitle)
                            .font(.system(size: 10.5, weight: .bold, design: .default))
                            .foregroundColor(Color(hex: 0x1E2024))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let previewSubtitle, !previewSubtitle.isEmpty {
                        Text(previewSubtitle)
                            .font(.system(size: 9.5, weight: .medium, design: .default))
                            .foregroundColor(Color(hex: 0x5A5F68))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
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
                        .stroke(Color(hex: 0xD1D5DB), lineWidth: 1.0)
                )
        } else {
            VintageMonochromeDiscEngraving()
                .frame(width: side, height: side)
        }
    }
}
