import SwiftUI

struct ClickWheelView: View {
    var wheelDiameter: CGFloat = 240.0
    let onRotateStep: (Int) -> Void
    let onMenuPress: () -> Void
    let onPlayPausePress: () -> Void
    let onPreviousPress: () -> Void
    let onNextPress: () -> Void
    let onCenterPress: () -> Void

    @AppStorage("wheelSensitivity") private var wheelSensitivityRaw: String = WheelSensitivity.deg60.rawValue
    @AppStorage("chassisTheme") private var chassisThemeRaw: String = ChassisTheme.light.rawValue

    private var wheelRadius: CGFloat {
        wheelDiameter / 2.0
    }

    private var centerButtonDiameter: CGFloat {
        wheelDiameter * (88.0 / 240.0)
    }

    private var centerButtonRadius: CGFloat {
        centerButtonDiameter / 2.0
    }

    /// Active degree threshold per step — defaults to 60.0° per step.
    private var stepThresholdDegrees: Double {
        (WheelSensitivity(rawValue: wheelSensitivityRaw) ?? .deg60).degreesPerStep
    }

    private var activeTheme: ChassisTheme {
        ChassisTheme(rawValue: chassisThemeRaw) ?? .light
    }

    @State private var previousAngle: Double?
    @State private var accumulatedDegrees: Double = 0.0
    @State private var isRingGestureActive: Bool = false
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
            // Outer ring (Diameter 240pt, themed fill with subtle convex radial drop shadow)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: activeTheme.wheelRingStops),
                        center: .center,
                        startRadius: centerButtonRadius,
                        endRadius: wheelRadius
                    )
                )
                .frame(width: wheelDiameter, height: wheelDiameter)
                .shadow(color: Color.black.opacity(0.28), radius: 6, x: 0, y: 4)
                .shadow(color: Color.white.opacity(activeTheme == .light ? 0.65 : 0.18), radius: 1, x: 0, y: -1)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: activeTheme.wheelOuterStrokeColors,
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                )

            // Outer-Rim Anchored Top & Bottom Labels (leaving middle track clean for circular scrolling)
            VStack(spacing: 0) {
                // Top: "MENU" anchored ~9pt from the outer rim
                Text("MENU")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(activeTheme.wheelLabelColor)
                    .scaleEffect(pressedZone == .menuTop ? 0.95 : 1.0)
                    .padding(.top, 9)

                Spacer(minLength: 0)

                // Bottom: Play/Pause glyph anchored ~10pt from the outer rim
                WheelTransportGlyph(symbol: .playPause, glyphColor: activeTheme.wheelLabelColor)
                    .frame(width: 19, height: 12)
                    .scaleEffect(pressedZone == .playPauseBottom ? 0.94 : 1.0)
                    .padding(.bottom, 10)
            }
            .frame(width: wheelDiameter, height: wheelDiameter)
            .allowsHitTesting(false)

            // Outer-Rim Anchored Left & Right Transport Icons (~11pt from outer rim)
            HStack(spacing: 0) {
                // Left: Rewind / Previous (|◀◀)
                WheelTransportGlyph(symbol: .previous, glyphColor: activeTheme.wheelLabelColor)
                    .frame(width: 19, height: 12)
                    .scaleEffect(pressedZone == .previousLeft ? 0.94 : 1.0)
                    .padding(.leading, 11)

                Spacer(minLength: 0)

                // Right: Fast-Forward / Next (▶▶|)
                WheelTransportGlyph(symbol: .next, glyphColor: activeTheme.wheelLabelColor)
                    .frame(width: 19, height: 12)
                    .scaleEffect(pressedZone == .nextRight ? 0.94 : 1.0)
                    .padding(.trailing, 11)
            }
            .frame(width: wheelDiameter, height: wheelDiameter)
            .allowsHitTesting(false)

            // Center button (Diameter 88pt, perfectly centered in the 240pt wheel)
            Circle()
                .fill(
                    LinearGradient(
                        colors: activeTheme.centerButtonGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: centerButtonDiameter, height: centerButtonDiameter)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: activeTheme.centerButtonStrokeColors,
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )
                .scaleEffect(pressedZone == .center ? 0.97 : 1.0)
                .allowsHitTesting(false)
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

        if previousAngle == nil && !isRingGestureActive {
            let startDx = value.startLocation.x - center.x
            let startDy = value.startLocation.y - center.y
            let startRadius = hypot(startDx, startDy)

            if pressedZone == nil {
                pressedZone = detectZone(dx: startDx, dy: startDy, radius: startRadius)
            }

            guard startRadius >= centerButtonRadius && startRadius <= wheelRadius else {
                return
            }

            isRingGestureActive = true
            previousAngle = atan2(startDy, startDx) * 180.0 / .pi
        }

        let minActiveRadius = wheelRadius * (30.0 / 120.0)
        let maxActiveRadius = wheelRadius * (145.0 / 120.0)
        guard isRingGestureActive, touchRadius >= minActiveRadius && touchRadius <= maxActiveRadius else {
            previousAngle = nil
            return
        }

        let currentAngle = atan2(dy, dx) * 180.0 / .pi

        guard let prev = previousAngle else {
            previousAngle = currentAngle
            return
        }

        previousAngle = currentAngle

        var delta = currentAngle - prev
        if delta > 180.0 {
            delta -= 360.0
        } else if delta < -180.0 {
            delta += 360.0
        }

        if abs(accumulatedDegrees + delta) > 6.0 {
            pressedZone = nil
        }

        if (accumulatedDegrees > 0 && delta < -0.5) || (accumulatedDegrees < 0 && delta > 0.5) {
            accumulatedDegrees = 0.0
        }

        accumulatedDegrees += delta
        let threshold = stepThresholdDegrees

        if abs(accumulatedDegrees) >= threshold {
            let direction = accumulatedDegrees > 0 ? 1 : -1
            accumulatedDegrees -= Double(direction) * threshold
            if abs(accumulatedDegrees) >= threshold {
                accumulatedDegrees = 0.0
            }
            didTriggerRotation = true
            pressedZone = nil
            onRotateStep(direction)
        }
    }

    private func handleTouchEnded(_ value: DragGesture.Value) {
        defer {
            previousAngle = nil
            accumulatedDegrees = 0.0
            isRingGestureActive = false
            didTriggerRotation = false
            pressedZone = nil
        }

        guard !didTriggerRotation else { return }

        let dragDistance = hypot(value.translation.width, value.translation.height)
        guard dragDistance < 18.0 else { return }

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
