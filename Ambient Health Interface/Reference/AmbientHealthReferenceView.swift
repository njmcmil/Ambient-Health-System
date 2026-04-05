import SwiftUI

/// Renders the living ambient object that visually mirrors the current state.
/// The goal is not literal data visualization, but a readable mood presence that
/// still reacts differently across calmer and more distressed states.
struct AmbientReferenceView: View {
    let state: ColorHealthState
    let reduceIntensity: Bool

    @GestureState private var isPressingBlob = false

    var body: some View {
        let isInteractive = !reduceIntensity
        let pressGesture = DragGesture(minimumDistance: 0)
            .updating($isPressingBlob) { _, state, _ in
                state = isInteractive
            }

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t)
            let profile = state.motionProfile
            let touch = touchProfile(for: state)

            let breathe = 1 + profile.breatheAmplitude * sin(phase * profile.breatheSpeed)
            let shellScale = 1 + profile.intensity * 0.04
            let touchBoost = isPressingBlob ? touch.boost : 0
            let touchGlow = isPressingBlob ? touch.glow : 0
            let touchScale = isPressingBlob ? touch.scale : 0
            let motionFactor: CGFloat = reduceIntensity ? 0.70 : 1.0
            let glowFactor: Double = reduceIntensity ? 0.68 : 1.0
            let jitterX = touchJitter(for: state, phase: phase, isActive: isPressingBlob) * motionFactor
            let shellPulse = Angle.degrees(Double(sin(phase * profile.rotationSpeed) * profile.rotationAmplitude))
            let aggressiveGlowBoost = aggressiveGlow(for: state, phase: phase) * glowFactor
            let shellHeartbeat = (state == .red ? overloadedHeartbeat(for: phase) : 0) * motionFactor
            let stressedRipple = (state == .purple ? stressedRipple(for: phase) : 0) * motionFactor
            let geometry = referenceGeometry(for: state)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                state.color.opacity((0.10 + touchGlow * 0.45 + aggressiveGlowBoost * 0.18) * glowFactor),
                                state.color.opacity(0.04 * glowFactor),
                                .clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 136
                        )
                    )
                    .frame(width: 274, height: 274)
                    .blur(radius: reduceIntensity ? 28 : 34)

                ReferenceShape(
                    phase: phase * 0.7,
                    intensity: profile.intensity * 0.7 + touchBoost,
                    angularity: profile.angularity * 0.9,
                    staticAmount: profile.staticAmount * 1.1,
                    widthScale: geometry.widthScale,
                    heightScale: geometry.heightScale,
                    skew: geometry.skew * 0.7
                )
                .fill(state.color.opacity((profile.glowOpacity * 0.54 + touchGlow + aggressiveGlowBoost * 0.14) * glowFactor))
                .frame(width: 240, height: 240)
                .blur(radius: isPressingBlob ? touch.blur * motionFactor : (reduceIntensity ? 15 : 20))

                ReferenceShape(
                    phase: phase,
                    intensity: profile.intensity + touchBoost,
                    angularity: profile.angularity,
                    staticAmount: profile.staticAmount,
                    widthScale: geometry.widthScale,
                    heightScale: geometry.heightScale,
                    skew: geometry.skew
                )
                .fill(
                    RadialGradient(
                        colors: [
                            state.color.opacity(0.24 + aggressiveGlowBoost * 0.18),
                            state.color.opacity((0.54 + aggressiveGlowBoost * 0.14) * glowFactor),
                            state.color.opacity(0.22 * glowFactor),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 96
                    )
                )
                .frame(width: 180, height: 206)
                .scaleEffect(shellScale + touchScale * 0.75)
                .shadow(
                    color: state.color.opacity((isPressingBlob ? 0.18 : 0.10) * glowFactor),
                    radius: isPressingBlob ? (reduceIntensity ? 13 : 18) : (reduceIntensity ? 8 : 12)
                )
                .rotationEffect(shellPulse)

                ReferenceShape(
                    phase: phase * 1.9,
                    intensity: profile.intensity * 0.45 + touchBoost * 0.7,
                    angularity: max(0.30, profile.angularity * 0.55),
                    staticAmount: profile.staticAmount * 0.55,
                    widthScale: geometry.widthScale * 0.92,
                    heightScale: geometry.heightScale * 0.94,
                    skew: geometry.skew * 0.5
                )
                .fill(
                    RadialGradient(
                        colors: [
                            state.color.opacity((isPressingBlob ? 0.38 : 0.32) + aggressiveGlowBoost * 0.14),
                            state.color.opacity((0.18 + aggressiveGlowBoost * 0.10) * glowFactor),
                            state.color.opacity(0.12 * glowFactor),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 34
                    )
                )
                .frame(width: 82, height: 82)
                .blur(radius: reduceIntensity ? 6 : 8)

                ReferenceShape(
                    phase: phase * 1.35,
                    intensity: profile.intensity * 1.1 + touchBoost,
                    angularity: profile.angularity * 1.05,
                    staticAmount: profile.staticAmount * 1.4,
                    widthScale: geometry.widthScale,
                    heightScale: geometry.heightScale,
                    skew: geometry.skew
                )
                .stroke(.white.opacity((isPressingBlob ? touch.edgeOpacity : 0.14) * (reduceIntensity ? 0.72 : 1.0)), lineWidth: isPressingBlob ? 1.15 : 0.85)
                .frame(width: 194, height: 220)
                .blur(radius: 0.4)
                .rotationEffect(shellPulse)
            }
            .scaleEffect(breathe + touchScale * 0.16 + shellHeartbeat + stressedRipple)
            .offset(x: jitterX)
            .frame(width: 268, height: 268)
            .contentShape(Rectangle())
            .allowsHitTesting(isInteractive)
            .gesture(pressGesture)
            .animation(touch.animation, value: isPressingBlob)
        }
    }
}

private struct ReferenceGeometryProfile {
    let widthScale: CGFloat
    let heightScale: CGFloat
    let skew: CGFloat
}

private func referenceGeometry(for state: ColorHealthState) -> ReferenceGeometryProfile {
    switch state {
    case .blue:
        return .init(widthScale: 1.02, heightScale: 0.98, skew: 0.06)
    case .green:
        return .init(widthScale: 1.04, heightScale: 0.95, skew: -0.02)
    case .gray:
        return .init(widthScale: 1.18, heightScale: 0.82, skew: -0.01)
    case .yellow:
        return .init(widthScale: 1.08, heightScale: 0.92, skew: 0.05)
    case .orange:
        return .init(widthScale: 1.00, heightScale: 1.00, skew: 0.00)
    case .purple:
        return .init(widthScale: 1.00, heightScale: 1.00, skew: 0.00)
    case .red:
        return .init(widthScale: 1.00, heightScale: 1.00, skew: 0.00)
    }
}

private func aggressiveGlow(for state: ColorHealthState, phase: CGFloat) -> Double {
    switch state {
    case .purple:
        return Double(0.20 + abs(sin(phase * 1.8)) * 0.18)
    case .red:
        return Double(0.30 + abs(sin(phase * 2.6)) * 0.26)
    default:
        return 0
    }
}

private func overloadedHeartbeat(for phase: CGFloat) -> CGFloat {
    let beat = max(0, sin(phase * 3.1))
    let echo = max(0, sin(phase * 3.1 - 0.9))
    return (beat * 0.028) + (echo * 0.014)
}

private func stressedRipple(for phase: CGFloat) -> CGFloat {
    let ripple = abs(sin(phase * 2.6))
    let flutter = abs(sin(phase * 6.2))
    return (ripple * 0.012) + (flutter * 0.006)
}

private struct TouchProfile {
    let boost: CGFloat
    let glow: Double
    let blur: CGFloat
    let scale: CGFloat
    let edgeOpacity: Double
    let animation: Animation
}

private func touchProfile(for state: ColorHealthState) -> TouchProfile {
    switch state {
    case .gray:
        return TouchProfile(boost: 0.02, glow: 0.025, blur: 22, scale: 0.08, edgeOpacity: 0.18, animation: .easeOut(duration: 0.24))
    case .blue:
        return TouchProfile(boost: 0.03, glow: 0.035, blur: 23, scale: 0.10, edgeOpacity: 0.20, animation: .easeOut(duration: 0.22))
    case .green:
        return TouchProfile(boost: 0.04, glow: 0.045, blur: 24, scale: 0.12, edgeOpacity: 0.22, animation: .easeOut(duration: 0.20))
    case .yellow:
        return TouchProfile(boost: 0.06, glow: 0.055, blur: 25, scale: 0.14, edgeOpacity: 0.24, animation: .easeOut(duration: 0.18))
    case .orange:
        return TouchProfile(boost: 0.06, glow: 0.06, blur: 24, scale: 0.12, edgeOpacity: 0.24, animation: .spring(response: 0.28, dampingFraction: 0.82))
    case .purple:
        return TouchProfile(boost: 0.11, glow: 0.095, blur: 28, scale: 0.21, edgeOpacity: 0.32, animation: .interactiveSpring(response: 0.16, dampingFraction: 0.50))
    case .red:
        return TouchProfile(boost: 0.15, glow: 0.13, blur: 31, scale: 0.26, edgeOpacity: 0.38, animation: .interactiveSpring(response: 0.12, dampingFraction: 0.42))
    }
}

private func touchJitter(for state: ColorHealthState, phase: CGFloat, isActive: Bool) -> CGFloat {
    guard isActive else { return 0 }

    switch state {
    case .purple:
        return (sin(phase * 24) * 2.1) + (sin(phase * 38) * 0.7)
    case .red:
        return (sin(phase * 30) * 2.6) + (sin(phase * 48) * 0.7)
    case .orange:
        return (sin(phase * 5.4) * 0.45) - 0.55
    default:
        return 0
    }
}
