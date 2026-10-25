import SwiftUI

struct ClassicPlayerRootView: View {
    @StateObject private var viewModel = PlayerViewModel()

    var body: some View {
        let theme = viewModel.chassisTheme

        GeometryReader { geo in
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
                    // Top Hold Switch + Strict 4:3 LCD Container
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            holdSwitchControl(theme: theme)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 12)

                        LCDDisplayView(viewModel: viewModel)
                            .padding(.horizontal, 22)
                    }

                    // Balanced vertical centering in the lower body so the Click Wheel isn't pushed too far down
                    Spacer(minLength: 12)

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

                    Spacer(minLength: 28)
                }
                .frame(width: geo.size.width, height: geo.size.height)
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
        } message: {
            Text("Enter a custom name up to 50 characters (Unicode & emojis supported).")
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
