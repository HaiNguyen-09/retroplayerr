import SwiftUI
import UIKit

struct SplitBrowserView: View {
    let page: MenuPage
    let navigationDirection: MenuNavigationDirection
    let previewImage: UIImage?
    let previewTitle: String?
    let previewSubtitle: String?

    @State private var currentBasePage: MenuPage?
    @State private var underneathParentPage: MenuPage?
    @State private var outgoingTopSubmenuPage: MenuPage?

    @State private var parallaxOffsetX: CGFloat = 0
    @State private var dimmingOpacity: Double = 0.0
    @State private var topSlideOffsetX: CGFloat = 0
    @State private var unmountTask: Task<Void, Never>?

    private let transitionDuration: Double = 0.23

    private var onePixel: CGFloat {
        1.0 / UIScreen.main.scale
    }

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2.0
            let activePage = currentBasePage ?? page

            HStack(spacing: 0) {
                // Left 50%: Parallax Layered Push/Pop Menu Column (Strictly Clipped)
                ZStack {
                    Color.white

                    if let parentUnderneath = underneathParentPage {
                        // Forward Push: Parent menu underneath sliding slower left with 0.0 -> 0.4 dimming overlay
                        ZStack {
                            lazyMenuListPane(for: parentUnderneath)
                            Color.black
                                .opacity(dimmingOpacity)
                                .allowsHitTesting(false)
                        }
                        .frame(width: halfWidth, height: geo.size.height)
                        .offset(x: parallaxOffsetX)
                        .zIndex(0)

                        // Child submenu sliding in from right to left (+halfWidth -> 0) on top
                        lazyMenuListPane(for: activePage)
                            .frame(width: halfWidth, height: geo.size.height)
                            .background(Color.white)
                            .shadow(color: .black.opacity(0.18), radius: 3, x: -1, y: 0)
                            .offset(x: topSlideOffsetX)
                            .zIndex(1)
                    } else if let outgoingTop = outgoingTopSubmenuPage {
                        // Backward Pop: Parent menu underneath (-0.32*halfWidth -> 0) with dimming fading out (0.4 -> 0.0)
                        ZStack {
                            lazyMenuListPane(for: activePage)
                            Color.black
                                .opacity(dimmingOpacity)
                                .allowsHitTesting(false)
                        }
                        .frame(width: halfWidth, height: geo.size.height)
                        .offset(x: parallaxOffsetX)
                        .zIndex(0)

                        // Outgoing submenu sliding out from left to right (0 -> +halfWidth) on top
                        lazyMenuListPane(for: outgoingTop)
                            .frame(width: halfWidth, height: geo.size.height)
                            .background(Color.white)
                            .shadow(color: .black.opacity(0.18), radius: 3, x: -1, y: 0)
                            .offset(x: topSlideOffsetX)
                            .zIndex(1)
                    } else {
                        // At rest: Only the single active menu is mounted in the render tree
                        lazyMenuListPane(for: activePage)
                            .frame(width: halfWidth, height: geo.size.height)
                            .zIndex(1)
                    }
                }
                .frame(width: halfWidth, height: geo.size.height)
                .clipped()
                .zIndex(0)
                .onAppear {
                    currentBasePage = page
                }
                .onChange(of: page) { newPage in
                    handlePageChange(to: newPage, halfWidth: halfWidth)
                }

                // 1px Center Split Divider (Completely Stationary)
                Rectangle()
                    .fill(Color(hex: 0xC2C4C8))
                    .frame(width: onePixel, height: geo.size.height)
                    .zIndex(1)

                // Right 50%: Anchored Static Preview Pane (Completely Stationary & Unaffected)
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

    private func handlePageChange(to newPage: MenuPage, halfWidth: CGFloat) {
        guard let previousPage = currentBasePage else {
            currentBasePage = newPage
            return
        }

        // If still on the same menu page (e.g. Click Wheel scrolling or inline setting toggle), update in place
        guard previousPage.id != newPage.id else {
            currentBasePage = newPage
            return
        }

        unmountTask?.cancel()
        let parallaxDistance = -halfWidth * 0.32

        if navigationDirection == .forward {
            // Drill into submenu: parent underneath slides 0 -> -32% with 0 -> 0.4 dim; child slides +100% -> 0
            var initialTransaction = Transaction()
            initialTransaction.disablesAnimations = true
            withTransaction(initialTransaction) {
                outgoingTopSubmenuPage = nil
                underneathParentPage = previousPage
                currentBasePage = newPage
                parallaxOffsetX = 0
                dimmingOpacity = 0.0
                topSlideOffsetX = halfWidth
            }

            withAnimation(.easeInOut(duration: transitionDuration)) {
                parallaxOffsetX = parallaxDistance
                dimmingOpacity = 0.4
                topSlideOffsetX = 0
            }

            unmountTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((transitionDuration + 0.015) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                var cleanup = Transaction()
                cleanup.disablesAnimations = true
                withTransaction(cleanup) {
                    underneathParentPage = nil
                    parallaxOffsetX = 0
                    dimmingOpacity = 0.0
                }
            }
        } else {
            // Return to parent menu (MENU): parent underneath slides -32% -> 0 with 0.4 -> 0 dim; submenu slides 0 -> +100%
            var initialTransaction = Transaction()
            initialTransaction.disablesAnimations = true
            withTransaction(initialTransaction) {
                underneathParentPage = nil
                outgoingTopSubmenuPage = previousPage
                currentBasePage = newPage
                parallaxOffsetX = parallaxDistance
                dimmingOpacity = 0.4
                topSlideOffsetX = 0
            }

            withAnimation(.easeInOut(duration: transitionDuration)) {
                parallaxOffsetX = 0
                dimmingOpacity = 0.0
                topSlideOffsetX = halfWidth
            }

            unmountTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((transitionDuration + 0.015) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                var cleanup = Transaction()
                cleanup.disablesAnimations = true
                withTransaction(cleanup) {
                    outgoingTopSubmenuPage = nil
                    topSlideOffsetX = 0
                }
            }
        }
    }

    /// Lazy-loaded menu list using LazyVStack + ScrollViewReader so only visible rows in the LCD viewport are allocated.
    private func lazyMenuListPane(for menuPage: MenuPage) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(menuPage.rows.enumerated()), id: \.element.id) { index, row in
                        let isSelected = (index == menuPage.selectedIndex)
                        menuRowView(row: row, isSelected: isSelected)
                            .id(row.id)
                    }
                }
            }
            .background(Color.white)
            .onAppear {
                if let selectedRow = menuPage.selectedRow {
                    proxy.scrollTo(selectedRow.id, anchor: nil)
                }
            }
            .onChange(of: menuPage.selectedIndex) { _ in
                if let selectedRow = menuPage.selectedRow {
                    proxy.scrollTo(selectedRow.id, anchor: nil)
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
