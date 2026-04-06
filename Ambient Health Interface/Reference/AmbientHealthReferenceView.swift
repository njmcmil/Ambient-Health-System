import SwiftUI

/// A clean, living ambient entity that reflects the current health state.
/// This renderer avoids harsh effects and keeps the object readable and calm.
struct AmbientReferenceView: View {
    let state: ColorHealthState
    let reduceIntensity: Bool

    @GestureState private var isPressing = false

    var body: some View {
        let isInteractive = !reduceIntensity
        let pressGesture = DragGesture(minimumDistance: 0)
            .updating($isPressing) { _, pressed, _ in
                pressed = isInteractive
            }

        TimelineView(.animation) { context in
            let rawPhase = CGFloat(context.date.timeIntervalSinceReferenceDate)
            let phase = reduceIntensity ? rawPhase * 0.30 : rawPhase
            let profile = state.motionProfile
            let touch = touchProfile(for: state)
            let character = characterProfile(for: state)

            let touchScale = isPressing ? touch.scale : 0
            let touchGlow = isPressing ? touch.glow : 0
            let basePulse = 1 + (profile.breatheAmplitude * character.breatheGain) * sin(phase * profile.breatheSpeed * character.breatheRate)
            let statePulse = moodPulse(for: state, phase: phase) * (reduceIntensity ? 0.35 : 1.0)
            let scale = (1 + profile.intensity * 0.03 + touchScale * (reduceIntensity ? 0.05 : 0.14)) * basePulse + statePulse

            let jitter = drift(for: state, phase: phase, active: isPressing)
            let motionFactor: CGFloat = reduceIntensity ? 0.28 : 1.0
            let offset = CGSize(width: jitter.width * motionFactor, height: jitter.height * motionFactor + yBias(for: state))

            let glow = ((touchGlow + moodGlow(for: state, phase: phase)) * (reduceIntensity ? 0.42 : 1.0))

            ZStack {
                Circle()
                    .fill(state.color.opacity(0.08 + glow * 0.10))
                    .frame(width: 270, height: 270)
                    .blur(radius: reduceIntensity ? 30 : 40)

                EntityLobe(
                    phase: phase * 0.75,
                    radiusScale: 1.0 * character.radiusScale,
                    variance: lobeVariance(for: state) * character.varianceGain,
                    lift: character.primaryLift
                )
                .fill(
                    RadialGradient(
                        colors: [
                            state.color.opacity(0.20 + glow * 0.18),
                            state.color.opacity(0.48 + glow * 0.10),
                            state.color.opacity(0.14)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 200 * character.widthScale, height: 212 * character.heightScale)
                .blur(radius: reduceIntensity ? 2.0 : 2.8)

                EntityLobe(
                    phase: phase * 1.06 + 1.7,
                    radiusScale: 0.90 * character.radiusScale,
                    variance: lobeVariance(for: state) * 0.84 * character.varianceGain,
                    lift: character.secondaryLift
                )
                .fill(state.color.opacity(0.19 + glow * 0.12))
                .frame(width: 174 * character.widthScale, height: 184 * character.heightScale)
                .blur(radius: 1.2)

                EntityLobe(
                    phase: phase * 1.54 + 3.9,
                    radiusScale: 0.76 * character.radiusScale,
                    variance: lobeVariance(for: state) * 0.64 * character.varianceGain,
                    lift: character.tertiaryLift
                )
                .fill(Color.white.opacity(0.16 + glow * 0.10))
                .frame(width: 140 * character.widthScale, height: 148 * character.heightScale)
                .blur(radius: 1.4)

                EntityCore(
                    phase: phase,
                    color: state.color,
                    intensity: profile.intensity,
                    glow: glow,
                    agitation: character.coreAgitation
                )
                .frame(width: character.coreSize, height: character.coreSize)

                EntityDust(
                    phase: phase,
                    color: state.color,
                    intensity: profile.intensity,
                    opacity: 0.36 + glow * 0.24,
                    count: character.dustCount
                )
            }
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: 280, height: 280)
            .contentShape(Rectangle())
            .allowsHitTesting(isInteractive)
            .gesture(pressGesture)
            .animation(touch.animation, value: isPressing)
        }
    }
}

private struct EntityLobe: Shape {
    var phase: CGFloat
    var radiusScale: CGFloat
    var variance: CGFloat
    var lift: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.43 * radiusScale
        let points = 56

        var coords: [CGPoint] = []
        coords.reserveCapacity(points)

        for i in 0..<points {
            let t = CGFloat(i) / CGFloat(points)
            let angle = t * .pi * 2

            let major = sin(angle * 3 + phase * 0.9) * variance * 0.22
            let minor = sin(angle * 7 - phase * 1.3) * variance * 0.10
            let breath = sin(phase * 0.52 + angle * 0.4) * 0.02
            let radius = baseRadius * (1 + major + minor + breath)

            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius * (1 + lift)
            coords.append(CGPoint(x: x, y: y))
        }

        guard let first = coords.first else { return Path() }
        var path = Path()
        path.move(to: first)
        for i in 0..<coords.count {
            let current = coords[i]
            let next = coords[(i + 1) % coords.count]
            let mid = CGPoint(x: (current.x + next.x) * 0.5, y: (current.y + next.y) * 0.5)
            path.addQuadCurve(to: mid, control: current)
        }
        path.closeSubpath()
        return path
    }
}

private struct EntityCore: View {
    let phase: CGFloat
    let color: Color
    let intensity: CGFloat
    let glow: Double
    let agitation: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.62 + glow * 0.10),
                            color.opacity(0.62 + glow * 0.12),
                            color.opacity(0.14)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 48
                    )
                )
                .blur(radius: 1.2)

            Circle()
                .stroke(color.opacity(0.30 + glow * 0.18), lineWidth: 1.0)
                .scaleEffect(1 + sin(phase * (0.95 + intensity * (0.35 + agitation * 0.35))) * (0.02 + agitation * 0.02))

            Circle()
                .stroke(Color.white.opacity(0.18 + glow * 0.10), lineWidth: 0.8)
                .scaleEffect(0.78 + sin(phase * (1.25 + intensity * (0.45 + agitation * 0.45))) * (0.025 + agitation * 0.02))
        }
    }
}

private struct EntityDust: View {
    let phase: CGFloat
    let color: Color
    let intensity: CGFloat
    let opacity: Double
    let count: Int

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let seed = Double(i) * 2.81
                let radius = CGFloat(52 + noise(seed + 4.2) * 24)
                let speed = CGFloat(0.22 + noise(seed + 8.8) * 0.44)
                let angle = phase * speed + CGFloat(i) * (.pi * 2 / CGFloat(max(count, 1)))
                let size = CGFloat(3.5 + noise(seed + 5.1) * 3.0)

                Circle()
                    .fill(color.opacity(opacity * (0.52 + noise(seed + 9.3) * 0.40)))
                    .frame(width: size, height: size)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius * 0.86)
                    .blur(radius: 0.2)
            }
        }
    }
}

private struct TouchProfile {
    let scale: CGFloat
    let glow: Double
    let animation: Animation
}

private struct EntityCharacterProfile {
    let widthScale: CGFloat
    let heightScale: CGFloat
    let radiusScale: CGFloat
    let varianceGain: CGFloat
    let primaryLift: CGFloat
    let secondaryLift: CGFloat
    let tertiaryLift: CGFloat
    let coreSize: CGFloat
    let coreAgitation: CGFloat
    let dustCount: Int
    let breatheGain: CGFloat
    let breatheRate: CGFloat
}

private func touchProfile(for state: ColorHealthState) -> TouchProfile {
    switch state {
    case .gray:
        return .init(scale: 0.05, glow: 0.02, animation: .easeOut(duration: 0.24))
    case .blue:
        return .init(scale: 0.06, glow: 0.03, animation: .easeOut(duration: 0.22))
    case .green:
        return .init(scale: 0.08, glow: 0.04, animation: .easeOut(duration: 0.20))
    case .yellow:
        return .init(scale: 0.09, glow: 0.05, animation: .easeOut(duration: 0.18))
    case .orange:
        return .init(scale: 0.10, glow: 0.06, animation: .spring(response: 0.30, dampingFraction: 0.84))
    case .purple:
        return .init(scale: 0.11, glow: 0.08, animation: .interactiveSpring(response: 0.18, dampingFraction: 0.55))
    case .red:
        return .init(scale: 0.12, glow: 0.10, animation: .interactiveSpring(response: 0.14, dampingFraction: 0.48))
    }
}

private func lobeVariance(for state: ColorHealthState) -> CGFloat {
    switch state {
    case .blue:
        return 0.36
    case .green:
        return 0.34
    case .gray:
        return 0.30
    case .yellow:
        return 0.40
    case .orange:
        return 0.44
    case .purple:
        return 0.48
    case .red:
        return 0.54
    }
}

private func characterProfile(for state: ColorHealthState) -> EntityCharacterProfile {
    switch state {
    case .blue:
        return .init(
            widthScale: 0.98,
            heightScale: 1.05,
            radiusScale: 0.98,
            varianceGain: 0.86,
            primaryLift: 0.10,
            secondaryLift: 0.02,
            tertiaryLift: -0.04,
            coreSize: 86,
            coreAgitation: 0.18,
            dustCount: 7,
            breatheGain: 0.92,
            breatheRate: 0.84
        )
    case .green:
        return .init(
            widthScale: 1.08,
            heightScale: 0.96,
            radiusScale: 1.00,
            varianceGain: 0.82,
            primaryLift: 0.04,
            secondaryLift: -0.01,
            tertiaryLift: -0.05,
            coreSize: 88,
            coreAgitation: 0.16,
            dustCount: 6,
            breatheGain: 0.90,
            breatheRate: 0.88
        )
    case .gray:
        return .init(
            widthScale: 1.02,
            heightScale: 0.98,
            radiusScale: 0.95,
            varianceGain: 0.72,
            primaryLift: 0.03,
            secondaryLift: -0.02,
            tertiaryLift: -0.06,
            coreSize: 84,
            coreAgitation: 0.12,
            dustCount: 5,
            breatheGain: 0.78,
            breatheRate: 0.76
        )
    case .yellow:
        return .init(
            widthScale: 1.10,
            heightScale: 0.94,
            radiusScale: 0.96,
            varianceGain: 0.92,
            primaryLift: 0.02,
            secondaryLift: -0.03,
            tertiaryLift: -0.07,
            coreSize: 84,
            coreAgitation: 0.24,
            dustCount: 7,
            breatheGain: 0.86,
            breatheRate: 0.80
        )
    case .orange:
        return .init(
            widthScale: 1.06,
            heightScale: 0.92,
            radiusScale: 0.98,
            varianceGain: 1.00,
            primaryLift: -0.01,
            secondaryLift: -0.06,
            tertiaryLift: -0.10,
            coreSize: 82,
            coreAgitation: 0.30,
            dustCount: 8,
            breatheGain: 0.80,
            breatheRate: 0.72
        )
    case .purple:
        return .init(
            widthScale: 1.00,
            heightScale: 1.02,
            radiusScale: 1.02,
            varianceGain: 1.18,
            primaryLift: 0.06,
            secondaryLift: -0.02,
            tertiaryLift: -0.08,
            coreSize: 90,
            coreAgitation: 0.58,
            dustCount: 11,
            breatheGain: 1.08,
            breatheRate: 1.24
        )
    case .red:
        return .init(
            widthScale: 0.98,
            heightScale: 1.06,
            radiusScale: 1.04,
            varianceGain: 1.34,
            primaryLift: 0.12,
            secondaryLift: 0.00,
            tertiaryLift: -0.10,
            coreSize: 94,
            coreAgitation: 0.86,
            dustCount: 13,
            breatheGain: 1.22,
            breatheRate: 1.42
        )
    }
}

private func moodGlow(for state: ColorHealthState, phase: CGFloat) -> Double {
    switch state {
    case .red:
        return Double(0.10 + abs(sin(phase * 2.1)) * 0.10)
    case .purple:
        return Double(0.08 + abs(sin(phase * 1.8)) * 0.08)
    case .orange:
        return 0.06
    case .yellow:
        return 0.04
    case .blue:
        return 0.04
    case .green:
        return 0.03
    case .gray:
        return 0.02
    }
}

private func moodPulse(for state: ColorHealthState, phase: CGFloat) -> CGFloat {
    switch state {
    case .red:
        let beat = max(0, sin(phase * 2.8))
        let echo = max(0, sin(phase * 2.8 - 0.8))
        return (beat * 0.012) + (echo * 0.006)
    case .purple:
        return abs(sin(phase * 2.3)) * 0.006
    default:
        return 0
    }
}

private func drift(for state: ColorHealthState, phase: CGFloat, active: Bool) -> CGSize {
    guard active else { return .zero }

    switch state {
    case .purple:
        return CGSize(width: sin(phase * 16) * 1.0 + sin(phase * 25) * 0.35, height: sin(phase * 8) * 0.30)
    case .red:
        return CGSize(width: sin(phase * 18) * 1.2 + sin(phase * 28) * 0.45, height: sin(phase * 9) * 0.35)
    case .orange:
        return CGSize(width: sin(phase * 4.2) * 0.40, height: 0.40)
    default:
        return .zero
    }
}

private func yBias(for state: ColorHealthState) -> CGFloat {
    switch state {
    case .orange:
        return 5
    case .yellow:
        return 2
    case .blue:
        return -1
    default:
        return 0
    }
}

private func noise(_ x: Double) -> Double {
    let value = sin(x * 12.9898) * 43758.5453
    return value - floor(value)
}
