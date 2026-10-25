import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

/// Cyan/sky blue play triangle (#0284C7) indicator for the right side of the 6th-Gen Retro Status Bar.
struct RetroStatusPlayIndicator: View {
    let state: PlaybackState
    private let cyanBlue = Color(hex: 0x0284C7)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            switch state {
            case .playing, .stopped:
                var triangle = Path()
                triangle.move(to: CGPoint(x: 1.0, y: 1.0))
                triangle.addLine(to: CGPoint(x: w - 0.5, y: h / 2.0))
                triangle.addLine(to: CGPoint(x: 1.0, y: h - 1.0))
                triangle.closeSubpath()
                context.fill(triangle, with: .color(cyanBlue))

            case .paused:
                let barWidth: CGFloat = 2.4
                let gap: CGFloat = 2.0
                let totalW = barWidth * 2 + gap
                let startX = (w - totalW) / 2.0
                let leftBar = CGRect(x: startX, y: 1.2, width: barWidth, height: h - 2.4)
                let rightBar = CGRect(x: startX + barWidth + gap, y: 1.2, width: barWidth, height: h - 2.4)
                context.fill(Path(leftBar), with: .color(cyanBlue))
                context.fill(Path(rightBar), with: .color(cyanBlue))
            }
        }
        .frame(width: 9, height: 9)
    }
}

/// Custom retro padlock glyph displayed in the status bar when Hold is engaged.
struct RetroLockGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Padlock body
            let bodyRect = CGRect(x: 1.0, y: h * 0.45, width: w - 2.0, height: h * 0.5)
            context.fill(Path(roundedRect: bodyRect, cornerRadius: 1.0), with: .color(Color(hex: 0x333333)))

            // Shackle arch
            var arch = Path()
            let archLeft = w * 0.26
            let archRight = w * 0.74
            let archCenter = w * 0.5
            let archRadius = (archRight - archLeft) / 2.0

            arch.move(to: CGPoint(x: archLeft, y: h * 0.46))
            arch.addLine(to: CGPoint(x: archLeft, y: h * 0.28))
            arch.addArc(
                center: CGPoint(x: archCenter, y: h * 0.28),
                radius: archRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            arch.addLine(to: CGPoint(x: archRight, y: h * 0.46))
            context.stroke(arch, with: .color(Color(hex: 0x333333)), lineWidth: 1.3)
        }
        .frame(width: 9, height: 11)
    }
}

/// Glossy 6th-Gen Battery Capsule: 3D-styled pill (width: 22pt, height: 10pt) with glossy chrome border,
/// green gradient fill (#22C55E to #15803D), and subtle top white specular reflection streak.
struct RetroBatteryGlyph: View {
    let level: Float // 0.0 ... 1.0

    var body: some View {
        Canvas { context, size in
            let nubWidth: CGFloat = 2.0
            let bodyWidth = size.width - nubWidth - 0.5
            let bodyHeight = size.height
            let bodyRect = CGRect(x: 0.5, y: 0.5, width: bodyWidth - 1.0, height: bodyHeight - 1.0)
            let pillCornerRadius: CGFloat = 2.6

            // Recessed inner metallic background
            let pillPath = Path(roundedRect: bodyRect, cornerRadius: pillCornerRadius)
            context.fill(
                pillPath,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xD1D5DB), Color(hex: 0xF3F4F6)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: bodyHeight)
                )
            )

            // Green gradient fill (#22C55E to #15803D)
            let clamped = min(max(CGFloat(level), 0.15), 1.0)
            let inset: CGFloat = 1.1
            let maxFillW = bodyRect.width - (inset * 2.0)
            let fillRect = CGRect(
                x: bodyRect.minX + inset,
                y: bodyRect.minY + inset,
                width: max(2.0, maxFillW * clamped),
                height: bodyRect.height - (inset * 2.0)
            )
            let fillPath = Path(roundedRect: fillRect, cornerRadius: max(1.0, pillCornerRadius - 1.0))
            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x22C55E), Color(hex: 0x15803D)]),
                    startPoint: CGPoint(x: 0, y: fillRect.minY),
                    endPoint: CGPoint(x: 0, y: fillRect.maxY)
                )
            )

            // Subtle top white specular reflection streak
            let specularRect = CGRect(
                x: fillRect.minX + 0.8,
                y: fillRect.minY + 0.4,
                width: max(1.0, fillRect.width - 1.6),
                height: fillRect.height * 0.36
            )
            context.fill(
                Path(roundedRect: specularRect, cornerRadius: 1.0),
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.10)]),
                    startPoint: CGPoint(x: 0, y: specularRect.minY),
                    endPoint: CGPoint(x: 0, y: specularRect.maxY)
                )
            )

            // Glossy chrome border
            context.stroke(
                pillPath,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x6B7280), Color(hex: 0x374151)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: bodyHeight)
                ),
                lineWidth: 1.0
            )

            // Chrome positive terminal nub on right
            let nubHeight: CGFloat = 4.2
            let nubRect = CGRect(
                x: bodyRect.maxX + 0.3,
                y: (bodyHeight - nubHeight) / 2.0,
                width: nubWidth,
                height: nubHeight
            )
            context.fill(
                Path(roundedRect: nubRect, cornerRadius: 0.9),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x9CA3AF), Color(hex: 0x4B5563)]),
                    startPoint: CGPoint(x: 0, y: nubRect.minY),
                    endPoint: CGPoint(x: 0, y: nubRect.maxY)
                )
            )
        }
        .frame(width: 22, height: 10)
    }
}

/// Row of 5 star glyphs for the 6th-Gen Now Playing metadata stack.
struct RetroStarRatingRow: View {
    var rating: Int = 5

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: 9.0, weight: .regular))
                    .foregroundColor(index <= rating ? Color(hex: 0x9CA3AF) : Color(hex: 0xD1D5DB))
            }
        }
    }
}

/// Subtle 1px chevron for menu rows.
struct RetroMenuChevron: View {
    let isSelected: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 1.5, y: 1.0))
            path.addLine(to: CGPoint(x: size.width - 1.5, y: size.height / 2.0))
            path.addLine(to: CGPoint(x: 1.5, y: size.height - 1.0))
            let strokeColor: Color = isSelected ? .white : Color(hex: 0x555555)
            context.stroke(
                path,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .square, lineJoin: .miter)
            )
        }
        .frame(width: 6, height: 9)
    }
}

/// Vintage monochrome optical/vinyl disc engraving displayed when no album artwork exists.
struct VintageMonochromeDiscEngraving: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xF4F5F7), Color(hex: 0xDCDFE4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Canvas { context, size in
                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
                let outerRadius = side * 0.41

                let discRect = CGRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2.0,
                    height: outerRadius * 2.0
                )
                let discPath = Path(ellipseIn: discRect)
                context.fill(
                    discPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(hex: 0xD2D5DA),
                            Color(hex: 0xEAECEF),
                            Color(hex: 0xB8BDC6),
                            Color(hex: 0xE1E4E8)
                        ]),
                        startPoint: CGPoint(x: discRect.minX, y: discRect.minY),
                        endPoint: CGPoint(x: discRect.maxX, y: discRect.maxY)
                    )
                )

                for baseAngle in [35.0, 215.0] {
                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addArc(
                        center: center,
                        radius: outerRadius - 1.0,
                        startAngle: .degrees(baseAngle - 18),
                        endAngle: .degrees(baseAngle + 18),
                        clockwise: false
                    )
                    wedge.closeSubpath()
                    context.fill(wedge, with: .color(.white.opacity(0.45)))
                }

                let grooveRadii: [CGFloat] = [0.88, 0.78, 0.68, 0.58, 0.48]
                for factor in grooveRadii {
                    let r = outerRadius * factor
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2.0, height: r * 2.0)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color(hex: 0x7A8089).opacity(0.55)),
                        lineWidth: 0.75
                    )
                }

                context.stroke(discPath, with: .color(Color(hex: 0x686E78)), lineWidth: 1.2)

                let hubRadius = outerRadius * 0.30
                let hubRect = CGRect(
                    x: center.x - hubRadius,
                    y: center.y - hubRadius,
                    width: hubRadius * 2.0,
                    height: hubRadius * 2.0
                )
                context.fill(Path(ellipseIn: hubRect), with: .color(Color(hex: 0xCFD3D9)))
                context.stroke(Path(ellipseIn: hubRect), with: .color(Color(hex: 0x767C86)), lineWidth: 1.0)

                let holeRadius = outerRadius * 0.11
                let holeRect = CGRect(
                    x: center.x - holeRadius,
                    y: center.y - holeRadius,
                    width: holeRadius * 2.0,
                    height: holeRadius * 2.0
                )
                context.fill(Path(ellipseIn: holeRect), with: .color(Color(hex: 0xF2F3F5)))
                context.stroke(Path(ellipseIn: holeRect), with: .color(Color(hex: 0x686E78)), lineWidth: 1.0)
            }

            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: 0xD1D5DB), lineWidth: 1)
        }
    }
}

/// Transport glyphs on the Click Wheel (Previous/Rewind, Next/Fast-Forward, Play/Pause).
enum WheelTransportSymbol {
    case previous
    case next
    case playPause
}

struct WheelTransportGlyph: View {
    let symbol: WheelTransportSymbol
    var glyphColor: Color = Color(hex: 0x4A4A4D)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h / 2.0
            let topY = h * 0.18
            let botY = h * 0.82

            switch symbol {
            case .previous:
                let barRect = CGRect(x: 0, y: topY, width: 2.0, height: botY - topY)
                context.fill(Path(barRect), with: .color(glyphColor))

                var tri1 = Path()
                tri1.move(to: CGPoint(x: 2.2, y: midY))
                tri1.addLine(to: CGPoint(x: w * 0.52, y: topY))
                tri1.addLine(to: CGPoint(x: w * 0.52, y: botY))
                tri1.closeSubpath()
                context.fill(tri1, with: .color(glyphColor))

                var tri2 = Path()
                tri2.move(to: CGPoint(x: w * 0.50, y: midY))
                tri2.addLine(to: CGPoint(x: w, y: topY))
                tri2.addLine(to: CGPoint(x: w, y: botY))
                tri2.closeSubpath()
                context.fill(tri2, with: .color(glyphColor))

            case .next:
                var tri1 = Path()
                tri1.move(to: CGPoint(x: 0, y: topY))
                tri1.addLine(to: CGPoint(x: w * 0.50, y: midY))
                tri1.addLine(to: CGPoint(x: 0, y: botY))
                tri1.closeSubpath()
                context.fill(tri1, with: .color(glyphColor))

                var tri2 = Path()
                tri2.move(to: CGPoint(x: w * 0.48, y: topY))
                tri2.addLine(to: CGPoint(x: w - 2.2, y: midY))
                tri2.addLine(to: CGPoint(x: w * 0.48, y: botY))
                tri2.closeSubpath()
                context.fill(tri2, with: .color(glyphColor))

                let barRect = CGRect(x: w - 2.0, y: topY, width: 2.0, height: botY - topY)
                context.fill(Path(barRect), with: .color(glyphColor))

            case .playPause:
                var playTri = Path()
                playTri.move(to: CGPoint(x: 0, y: topY))
                playTri.addLine(to: CGPoint(x: w * 0.46, y: midY))
                playTri.addLine(to: CGPoint(x: 0, y: botY))
                playTri.closeSubpath()
                context.fill(playTri, with: .color(glyphColor))

                let barW: CGFloat = 2.1
                let bar1 = CGRect(x: w * 0.62, y: topY, width: barW, height: botY - topY)
                let bar2 = CGRect(x: w * 0.62 + barW + 2.4, y: topY, width: barW, height: botY - topY)
                context.fill(Path(bar1), with: .color(glyphColor))
                context.fill(Path(bar2), with: .color(glyphColor))
            }
        }
        .frame(width: 18, height: 11)
    }
}
