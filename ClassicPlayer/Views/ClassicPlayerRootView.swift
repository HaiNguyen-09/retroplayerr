import SwiftUI

struct ClassicPlayerRootView: View {
    @StateObject private var viewModel = PlayerViewModel()

    var body: some View {
        let theme = viewModel.chassisTheme

        GeometryReader { geo in
            let targetWidth = min(geo.size.width, geo.size.height * (9.0 / 16.0))
            let targetHeight = targetWidth * (16.0 / 9.0)
            let scaleFactor = max(0.75, targetWidth / 375.0)
            let wheelDiameter = 240.0 * scaleFactor
            let horizontalPadding = 22.0 * scaleFactor

            ZStack {
                // 1. Outer Background (Pillarbox/Letterbox Fill):
                // Deep dark gray #1A1A1A fills the entire device screen (.ignoresSafeArea())
                // so the top notch / Dynamic Island and bottom Home Indicator blend naturally.
                Color(hex: 0x1A1A1A)
                    .ignoresSafeArea()

                // 2. Constrained 9:16 iPod Hardware Shell Container:
                // Centered horizontally and vertically inside the device screen.
                ZStack {
                    // Anodized metallic faceplate background (Light, Gray, or Dark Gray)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: theme.faceplateGradientColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .animation(.easeInOut(duration: 0.2), value: theme)

                    // Subtle inner metallic chassis bevel border
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: theme.chassisBorderGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(3)

                    VStack(spacing: 0) {
                        // Top Hold Switch + Strict 4:3 LCD Container scaled to the 9:16 shell width
                        VStack(spacing: 8 * scaleFactor) {
                            HStack {
                                Spacer()
                                holdSwitchControl(theme: theme)
                            }
                            .padding(.horizontal, horizontalPadding + 4)
                            .padding(.top, 14 * scaleFactor)

                            LCDDisplayView(viewModel: viewModel)
                                .padding(.horizontal, horizontalPadding)
                        }

                        // Balanced vertical centering in the lower half of the 9:16 shell
                        Spacer(minLength: 10 * scaleFactor)

                        ClickWheelView(
                            wheelDiameter: wheelDiameter,
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
                            },
                            onCenterLongPress: {
                                viewModel.handleCenterLongPress()
                            }
                        )

                        Spacer(minLength: 24 * scaleFactor)
                    }
                    .frame(width: targetWidth, height: targetHeight)
                }
                .frame(width: targetWidth, height: targetHeight)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .alert("Player Name", isPresented: $viewModel.isPresentingPlayerNameAlert) {
            TextField("My Player", text: $viewModel.draftPlayerName)
                .onChange(of: viewModel.draftPlayerName) { newValue in
                    if newValue.count > 50 {
                        viewModel.draftPlayerName = String(newValue.prefix(50))
                    }
                }
            Button("Cancel", role: .cancel) {
                viewModel.isPresentingPlayerNameAlert = false
            }
            Button("Save") {
                viewModel.saveDraftPlayerName()
            }
        }
        .onOpenURL { incomingURL in
            let saved = DocumentImporterSheet.Coordinator.persistFilesToDocuments([incomingURL])
            viewModel.handleImportedDocuments(urls: saved)
        }
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
