import SwiftUI

struct ClassicPlayerRootView: View {
    @StateObject private var viewModel = PlayerViewModel()

    var body: some View {
        let theme = viewModel.chassisTheme

        GeometryReader { geo in
            let halfHeight = geo.size.height / 2.0

            ZStack {
                // Anodized metallic faceplate background (Light, Gray, or Dark Gray)
                LinearGradient(
                    colors: theme.faceplateGradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: theme)

                // Subtle inner metallic chassis bevel border
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: theme.chassisBorderGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .padding(4)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Upper half (50% of screen height): Top Controls (Theme Finish + Hold Switch) + Strict 4:3 LCD Container
                    VStack(spacing: 10) {
                        HStack {
                            themeModeQuickToggle(theme: theme)
                            Spacer()
                            holdSwitchControl(theme: theme)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 10)

                        LCDDisplayView(viewModel: viewModel)
                            .padding(.horizontal, 24)

                        Spacer(minLength: 0)
                    }
                    .frame(width: geo.size.width, height: halfHeight)

                    // Lower half (50% of screen height): 240pt Click Wheel perfectly centered
                    ZStack {
                        ClickWheelView(
                            onRotateStep: { step in
                                viewModel.handleWheelStep(direction: step)
                            },
                            onMenuPress: {
                                viewModel.handleMenuButton()
                            },
                            onPlayPausePress: {
                                viewModel.handlePlayPauseButton()
                            },
                            onPreviousPress: {
                                viewModel.handlePreviousButton()
                            },
                            onNextPress: {
                                viewModel.handleNextButton()
                            },
                            onCenterPress: {
                                viewModel.handleCenterSelectButton()
                            }
                        )
                    }
                    .frame(width: geo.size.width, height: halfHeight, alignment: .center)
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $viewModel.isPresentingDocumentPicker) {
            DocumentImporterSheet(
                onPickURLs: { urls in
                    viewModel.handleImportedDocuments(urls: urls)
                },
                onCancel: {
                    viewModel.isPresentingDocumentPicker = false
                }
            )
            .ignoresSafeArea()
        }
        .onOpenURL { incomingURL in
            let saved = DocumentImporterSheet.Coordinator.persistFilesToDocuments([incomingURL])
            viewModel.handleImportedDocuments(urls: saved)
        }
    }

    /// Quick 3-mode finish selector (Light / Gray / Dark Gray) on top-left bezel.
    private func themeModeQuickToggle(theme: ChassisTheme) -> some View {
        Button {
            viewModel.cycleThemeFromTopBar()
        } label: {
            HStack(spacing: 5) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: 0xECEEF2))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: theme == .light ? 1.2 : 0.5))

                    Circle()
                        .fill(Color(hex: 0x8F949F))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: theme == .gray ? 1.2 : 0.4))

                    Circle()
                        .fill(Color(hex: 0x282A30))
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: theme == .darkGray ? 1.2 : 0.4))
                }

                Text(theme.displayName.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .default))
                    .tracking(0.5)
                    .foregroundColor(theme.topBarTextColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chassis Finish: \(theme.displayName)")
    }

    /// Physical-style top Hold slider switch so the user can lock/unlock the Click Wheel at any time.
    private func holdSwitchControl(theme: ChassisTheme) -> some View {
        Button {
            viewModel.toggleHoldSwitch()
        } label: {
            HStack(spacing: 5) {
                Text("HOLD")
                    .font(.system(size: 8.5, weight: .bold, design: .default))
                    .tracking(0.6)
                    .foregroundColor(theme.topBarTextColor)

                ZStack(alignment: viewModel.isHoldLocked ? .trailing : .leading) {
                    Capsule()
                        .fill(viewModel.isHoldLocked ? Color(hex: 0xEA580C) : Color(hex: 0xAEB3BC))
                        .frame(width: 26, height: 11)
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: 0x555860), lineWidth: 0.8)
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xF8F9FA), Color(hex: 0xC5C9D1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 13, height: 9)
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: 0x6D727A), lineWidth: 0.6)
                        )
                        .padding(.horizontal, 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isHoldLocked ? "Hold Switch Locked" : "Hold Switch Unlocked")
    }
}
