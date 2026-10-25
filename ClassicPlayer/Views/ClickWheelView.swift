import SwiftUI

struct ClickWheelView: View {
    let onRotateStep: (Int) -> Void
    let onMenuPress: () -> Void
    let onPlayPausePress: () -> Void
    let onPreviousPress: () -> Void
    let onNextPress: () -> Void
    let onCenterPress: () -> Void

    private let wheelDiameter: CGFloat = 240.0
    private let wheelRadius: CGFloat = 120.0
    private let centerButtonDiameter: CGFloat = 88.0
    private let centerButtonRadius: CGFloat = 44.0
    private let stepThresholdDegrees: Double = 18.0

    @State private var previousAngle: Double?
    @State private var accumulatedDegrees: Double = 0.0
    @State private var didTriggerRotation: Bool = false
    @State private var pressedZone: WheelZone?

    private enum WheelZone {
        case center
        case menuTop
        case playPauseBottom
        case previousLeft
        case nextRight
    }

    var body: some View {
        ZStack {
            // Outer ring (Diameter 240pt, fill #F2F2F2, subtle convex radial drop shadow)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: 0xF7F7F7), location: 0.35),
                            .init(color: Color(hex: 0xF2F2F2), location: 0.82),
                            .init(color: Color(hex: 0xE2E3E6), location: 1.0)
                        ]),
                        center: .center,
                        startRadius: centerButtonRadius,
                        endRadius: wheelRadius
                    )
                )
                .frame(width: wheelDiameter, height: wheelDiameter)
                .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 4)
                .shadow(color: Color.white.opacity(0.65), radius: 1, x: 0, y: -1)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: 0xD0D2D6), Color(hex: 0xB8BBC2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                )

            // Cardinal Button Targets around the ring (radial midpoint ~82pt from center)
            // Top: "MENU" text in dark charcoal Helvetica Bold
            Text("MENU")
                .font(.custom("Helvetica-Bold", size: 11.5))
                .tracking(0.8)
                .foregroundColor(Color(hex: 0x3E3E42))
                .scaleEffect(pressedZone == .menuTop ? 0.95 : 1.0)
                .offset(y: -84)

            // Bottom: Play/Pause icon
            WheelTransportGlyph(symbol: .playPause)
                .scaleEffect(pressedZone == .playPauseBottom ? 0.94 : 1.0)
                .offset(y: 84)

            // Left: Backward icon (track rewind/previous)
            WheelTransportGlyph(symbol: .previous)
                .scaleEffect(pressedZone == .previousLeft ? 0.94 : 1.0)
                .offset(x: -84)

            // Right: Forward icon (track fast-forward/skip)
            WheelTransportGlyph(symbol: .next)
                .scaleEffect(pressedZone == .nextRight ? 0.94 : 1.0)
                .offset(x: 84)

            // Center button (Diameter 88pt, concave metallic silver gradient)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xC9CDD4),
                            Color(hex: 0xDCE0E6),
                            Color(hex: 0xEFF1F5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: centerButtonDiameter, height: centerButtonDiameter)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: 0x9FA4AE), Color(hex: 0xCFD3DA)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )
                .scaleEffect(pressedZone == .center ? 0.97 : 1.0)
        }
        .frame(width: wheelDiameter, height: wheelDiameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleTouchChanged(value)
                }
                .onEnded { value in
                    handleTouchEnded(value)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Click Wheel")
    }

    private func handleTouchChanged(_ value: DragGesture.Value) {
        let center = CGPoint(x: wheelRadius, y: wheelRadius)
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let touchRadius = hypot(dx, dy)

        if pressedZone == nil && !didTriggerRotation {
            pressedZone = detectZone(dx: dx, dy: dy, radius: touchRadius)
        }

        // Strict radius bounds check: reject drag gestures if touch radius < 44pt or > 120pt
        guard touchRadius >= centerButtonRadius && touchRadius <= wheelRadius else {
            previousAngle = nil
            return
        }

        // Calculate angular position in degrees using atan2(y - center.y, x - center.x) * 180 / π
        let currentAngle = atan2(dy, dx) * 180.0 / .pi

        if let prev = previousAngle {
            var delta = currentAngle - prev
            // Seamless wrap-around across the -180° / +180° discontinuity
            if delta > 180.0 {
                delta -= 360.0
            } else if delta < -180.0 {
                delta += 360.0
            }

            accumulatedDegrees += delta

            // Trigger a menu navigation step every 18 degrees of rotation
            while abs(accumulatedDegrees) >= stepThresholdDegrees {
                let direction = accumulatedDegrees > 0 ? 1 : -1
                accumulatedDegrees -= Double(direction) * stepThresholdDegrees
                didTriggerRotation = true
                pressedZone = nil
                onRotateStep(direction)
            }
        } else {
            previousAngle = currentAngle
        }
    }

    private func handleTouchEnded(_ value: DragGesture.Value) {
        defer {
            previousAngle = nil
            accumulatedDegrees = 0.0
            didTriggerRotation = false
            pressedZone = nil
        }

        guard !didTriggerRotation else { return }

        let dragDistance = hypot(value.translation.width, value.translation.height)
        guard dragDistance < 16.0 else { return }

        let center = CGPoint(x: wheelRadius, y: wheelRadius)
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let touchRadius = hypot(dx, dy)

        guard let zone = detectZone(dx: dx, dy: dy, radius: touchRadius) else { return }
        switch zone {
        case .center:
            onCenterPress()
        case .menuTop:
            onMenuPress()
        case .playPauseBottom:
            onPlayPausePress()
        case .previousLeft:
            onPreviousPress()
        case .nextRight:
            onNextPress()
        }
    }

    private func detectZone(dx: CGFloat, dy: CGFloat, radius: CGFloat) -> WheelZone? {
        if radius < centerButtonRadius {
            return .center
        }
        guard radius <= wheelRadius else {
            return nil
        }

        let angle = atan2(dy, dx) * 180.0 / .pi
        if angle >= -135.0 && angle < -45.0 {
            return .menuTop
        } else if angle >= 45.0 && angle < 135.0 {
            return .playPauseBottom
        } else if angle >= -45.0 && angle < 45.0 {
            return .nextRight
        } else {
            return .previousLeft
        }
    }
}
