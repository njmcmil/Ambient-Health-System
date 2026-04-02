import SwiftUI

struct AmbientReferenceView: View {
    let state: ColorHealthState

    @GestureState private var isPressingBlob = false

    var body: some View {
        let pressGesture = DragGesture(minimumDistance: 0)
            .updating($isPressingBlob) { _, state, _ in
                state = true
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
            let jitterX = touchJitter(for: state, phase: phase, isActive: isPressingBlob)

            ZStack {
                ReferenceShape(
                    phase: phase * 0.7,
                    intensity: profile.intensity * 0.7 + touchBoost,
                    angularity: profile.angularity * 0.9,
                    staticAmount: profile.staticAmount * 1.1
                )
                .fill(state.color.opacity(profile.glowOpacity * 0.68 + touchGlow))
                .frame(width: 226, height: 226)
                .blur(radius: isPressingBlob ? touch.blur : 24)

                ReferenceShape(
                    phase: phase,
                    intensity: profile.intensity + touchBoost,
                    angularity: profile.angularity,
                    staticAmount: profile.staticAmount
                )
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(isPressingBlob ? 1.0 : 0.95),
                            state.color.opacity(0.72),
                            state.color.opacity(0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 164, height: 190)
                .scaleEffect(shellScale + touchScale)
                .shadow(color: state.color.opacity(isPressingBlob ? 0.28 : 0.16), radius: isPressingBlob ? 24 : 18)

                ReferenceShape(
                    phase: phase * 1.35,
                    intensity: profile.intensity * 1.1 + touchBoost,
                    angularity: profile.angularity * 1.05,
                    staticAmount: profile.staticAmount * 1.4
                )
                .stroke(.white.opacity(isPressingBlob ? touch.edgeOpacity : 0.18), lineWidth: isPressingBlob ? 1.4 : 1)
                .frame(width: 178, height: 208)

                ReferenceShape(
                    phase: phase * 1.8,
                    intensity: profile.intensity * 0.55 + touchBoost,
                    angularity: profile.angularity * 1.2,
                    staticAmount: profile.staticAmount * 1.8
                )
                .stroke(state.color.opacity(isPressingBlob ? 0.22 : 0.13), lineWidth: 1)
                .frame(width: 198, height: 222)
                .blur(radius: isPressingBlob ? 2.2 : 1.2)
            }
            .scaleEffect(breathe + touchScale * 0.25)
            .offset(x: jitterX)
            .frame(width: 240, height: 240)
            .contentShape(Rectangle())
            .gesture(pressGesture)
            .animation(touch.animation, value: isPressingBlob)
        }
    }
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
        return TouchProfile(boost: 0.02, glow: 0.04, blur: 26, scale: 0.08, edgeOpacity: 0.20, animation: .easeOut(duration: 0.24))
    case .blue:
        return TouchProfile(boost: 0.03, glow: 0.05, blur: 27, scale: 0.10, edgeOpacity: 0.22, animation: .easeOut(duration: 0.22))
    case .green:
        return TouchProfile(boost: 0.04, glow: 0.06, blur: 28, scale: 0.12, edgeOpacity: 0.24, animation: .easeOut(duration: 0.20))
    case .yellow:
        return TouchProfile(boost: 0.06, glow: 0.08, blur: 29, scale: 0.16, edgeOpacity: 0.26, animation: .easeOut(duration: 0.18))
    case .orange:
        return TouchProfile(boost: 0.08, glow: 0.10, blur: 30, scale: 0.20, edgeOpacity: 0.30, animation: .spring(response: 0.24, dampingFraction: 0.72))
    case .purple:
        return TouchProfile(boost: 0.10, glow: 0.12, blur: 31, scale: 0.22, edgeOpacity: 0.34, animation: .interactiveSpring(response: 0.18, dampingFraction: 0.55))
    case .red:
        return TouchProfile(boost: 0.13, glow: 0.16, blur: 33, scale: 0.28, edgeOpacity: 0.40, animation: .interactiveSpring(response: 0.14, dampingFraction: 0.45))
    }
}

private func touchJitter(for state: ColorHealthState, phase: CGFloat, isActive: Bool) -> CGFloat {
    guard isActive else { return 0 }

    switch state {
    case .purple:
        return sin(phase * 22) * 1.6
    case .red:
        return sin(phase * 28) * 2.2
    case .orange:
        return sin(phase * 16) * 0.8
    default:
        return 0
    }
}
