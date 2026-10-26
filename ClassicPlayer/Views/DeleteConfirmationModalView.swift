import SwiftUI

enum DeleteModalOption: Int, CaseIterable, Equatable, Sendable {
    case delete = 0
    case cancel = 1
}

struct DeleteConfirmationModalView: View {
    let trackTitle: String
    let selectedOption: DeleteModalOption

    var body: some View {
        ZStack {
            // Subtle dark translucent backdrop across the 4:3 LCD canvas
            Color.black.opacity(0.45)

            // Classic skeuomorphic iPod modal dialog box
            VStack(spacing: 0) {
                // Header bar with subtle top glass gloss
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x4A5160), Color(hex: 0x2C313C)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 10)
                        Spacer(minLength: 0)
                    }

                    Text("Delete Song")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
                }
                .frame(height: 24)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 0.8)
                }

                // Body message
                Text("Delete \"\(trackTitle)\" from your library?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: 0xF3F4F6))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                // Vertically stacked action options: [ Delete ] and [ Cancel ]
                VStack(spacing: 6) {
                    modalOptionButton(
                        title: "Delete",
                        isSelected: selectedOption == .delete
                    )

                    modalOptionButton(
                        title: "Cancel",
                        isSelected: selectedOption == .cancel
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 11)
            }
            .frame(width: 214)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x2B303B).opacity(0.96), Color(hex: 0x1B1F27).opacity(0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color(hex: 0xE0E0E0).opacity(0.85), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.65), radius: 8, x: 0, y: 4)
        }
    }

    private func modalOptionButton(title: String, isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                // Glossy iPod blue selection bar
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x60A5FA), Color(hex: 0x2563EB), Color(hex: 0x1D4ED8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.42), Color.white.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 10)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.8)
                    )
            } else {
                // Recessed dark translucent pill
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x373D49), Color(hex: 0x252A34)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                    )
            }

            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(isSelected ? .white : Color(hex: 0xE5E7EB))
                .shadow(color: .black.opacity(isSelected ? 0.45 : 0.25), radius: 0.8, x: 0, y: 1)
        }
        .frame(height: 22)
    }
}
