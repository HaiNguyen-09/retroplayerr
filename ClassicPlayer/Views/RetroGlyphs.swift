import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

/// Solid black polygon indicator for the left side of the 20pt Retro Status Bar.
struct RetroStatusPlayIndicator: View {
    let state: PlaybackState

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            switch state {
            case .playing:
                var triangle = Path()
                triangle.move(to: CGPoint(x: 1, y: 1.5))
                triangle.addLine(to: CGPoint(x: w - 1, y: h / 2.0))
                triangle.addLine(to: CGPoint(x: 1, y: h - 1.5))
                triangle.closeSubpath()
                context.fill(triangle, with: .color(.black))

            case .paused:
                let barWidth: CGFloat = 2.4
                let gap: CGFloat = 2.2
                let totalW = barWidth * 2 + gap
                let startX = (w - totalW) / 2.0
                let leftBar = CGRect(x: startX, y: 1.5, width: barWidth, height: h - 3.0)
                let rightBar = CGRect(x: startX + barWidth + gap, y: 1.5, width: barWidth, height: h - 3.0)
                context.fill(Path(leftBar), with: .color(.black))
                context.fill(Path(rightBar), with: .color(.black))

            case .stopped:
                // Subtle paused/idle play polygon outline or tiny stop square
                var triangle = Path()
                triangle.move(to: CGPoint(x: 1.5, y: 2.0))
                triangle.addLine(to: CGPoint(x: w - 1.5, y: h / 2.0))
                triangle.addLine(to: CGPoint(x: 1.5, y: h - 2.0))
                triangle.closeSubpath()
                context.stroke(triangle, with: .color(.black.opacity(0.45)), lineWidth: 1.0)
            }
        }
        .frame(width: 10, height: 10)
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
            context.fill(Path(roundedRect: bodyRect, cornerRadius: 1.0), with: .color(.black))

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
            context.stroke(arch, with: .color(.black), lineWidth: 1.3)
        }
        .frame(width: 9, height: 11)
    }
}

/// Custom retro battery glyph: hollow black pill with internal segmented battery charge bar.
struct RetroBatteryGlyph: View {
    let level: Float // 0.0 ... 1.0
    private let segmentCount = 4

    var body: some View {
        Canvas { context, size in
            let nubWidth: CGFloat = 2.0
            let bodyWidth = size.width - nubWidth - 1.0
            let bodyHeight = size.height
            let bodyRect = CGRect(x: 0.5, y: 0.5, width: bodyWidth - 1.0, height: bodyHeight - 1.0)

            // Hollow black pill outline
            let pillPath = Path(roundedRect: bodyRect, cornerRadius: 2.0)
            context.stroke(pillPath, with: .color(.black), lineWidth: 1.0)

            // Positive terminal nub on right
            let nubHeight: CGFloat = 4.0
            let nubRect = CGRect(
                x: bodyWidth,
                y: (bodyHeight - nubHeight) / 2.0,
                width: nubWidth,
                height: nubHeight
            )
            context.fill(Path(roundedRect: nubRect, cornerRadius: 0.8), with: .color(.black))

            // Internal segmented charge bars
            let clamped = min(max(CGFloat(level), 0.0), 1.0)
            let activeSegments = max(1, Int(round(clamped * CGFloat(segmentCount))))

            let insetX: CGFloat = 2.2
            let insetY: CGFloat = 2.2
            let spacing: CGFloat = 1.2
            let availableWidth = bodyRect.width - (insetX * 2.0) - CGFloat(segmentCount - 1) * spacing
            let segmentWidth = max(1.5, availableWidth / CGFloat(segmentCount))
            let segmentHeight = bodyRect.height - (insetY * 2.0)

            for index in 0..<activeSegments {
                let x = bodyRect.minX + insetX + CGFloat(index) * (segmentWidth + spacing)
                let segRect = CGRect(x: x, y: bodyRect.minY + insetY, width: segmentWidth, height: segmentHeight)
                context.fill(Path(segRect), with: .color(.black))
            }
        }
        .frame(width: 22, height: 10)
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

                // Outer disc base fill
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

                // Diagonal reflective sheen wedges (classic engraved monochrome optical disc look)
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

                // Concentric engraved micro-grooves
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

                // Outer metallic bevel ring
                context.stroke(discPath, with: .color(Color(hex: 0x686E78)), lineWidth: 1.2)

                // Center clamping ring
                let hubRadius = outerRadius * 0.30
                let hubRect = CGRect(
                    x: center.x - hubRadius,
                    y: center.y - hubRadius,
                    width: hubRadius * 2.0,
                    height: hubRadius * 2.0
                )
                context.fill(Path(ellipseIn: hubRect), with: .color(Color(hex: 0xCFD3D9)))
                context.stroke(Path(ellipseIn: hubRect), with: .color(Color(hex: 0x767C86)), lineWidth: 1.0)

                // Spindle hole
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
                .stroke(Color(hex: 0xB0B5BD), lineWidth: 1)
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
    private let glyphColor = Color(hex: 0x4A4A4D)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h / 2.0
            let topY = h * 0.18
            let botY = h * 0.82

            switch symbol {
            case .previous:
                // |<<
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
                // >>|
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
                // > ||
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
