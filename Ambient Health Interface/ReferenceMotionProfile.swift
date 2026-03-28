import SwiftUI

// This struct defines how the health state reference behaves visually.
// "personality settings" based on health state.

struct EntityMotionProfile {
    let intensity: CGFloat          // How aggressive / spiky the shape is
    let angularity: CGFloat         // How sharp vs smooth the edges feel
    let breatheAmplitude: CGFloat   // How much it expands/contracts (alive feeling)
    let breatheSpeed: CGFloat       // How fast it "breathes"
    let rotationAmplitude: CGFloat  // How much it drifts/rotates
    let rotationSpeed: CGFloat      // How fast that rotation happens
    let scanSpeed: CGFloat          // Internal motion speed (energy / activity level)
    let glowOpacity: CGFloat        // Strength of the outer glow
    let staticAmount: CGFloat       // Subtle jitter/noise (adds tension/instability)
}

extension ColorHealthState {
    // Maps each health state to a motion profile.
    // Instead of just changing color, the reference visually "feels" different.
    // feel free to change these..
    var motionProfile: EntityMotionProfile {
        switch self {
        case .blue:
                    return .init(
                        intensity: 0.08,        // very soft, almost no spikes
                        angularity: 0.50,       // smooth and rounded
                        breatheAmplitude: 0.010,// gentle breathing
                        breatheSpeed: 0.70,     // slow & calm rhythm
                        rotationAmplitude: 1.2, // slight drifting
                        rotationSpeed: 0.16,    // slow movement
                        scanSpeed: 0.70,        // low internal activity
                        glowOpacity: 0.10,      // soft glow
                        staticAmount: 0.01      // almost perfectly stable
                    )

                case .green:
                    return .init(
                        intensity: 0.10,        // slightly more defined shape
                        angularity: 0.58,       // still smooth, but more structure
                        breatheAmplitude: 0.012,
                        breatheSpeed: 0.82,     // steady, healthy rhythm
                        rotationAmplitude: 1.5,
                        rotationSpeed: 0.18,
                        scanSpeed: 0.85,        // moderate internal motion
                        glowOpacity: 0.11,
                        staticAmount: 0.015     // tiny bit of variation (alive, not static)
                    )

                case .gray:
                    return .init(
                        intensity: 0.06,        // very low energy
                        angularity: 0.42,       // very soft, almost blob-like
                        breatheAmplitude: 0.008,
                        breatheSpeed: 0.55,     // slowest breathing
                        rotationAmplitude: 0.9,
                        rotationSpeed: 0.12,    // barely moving
                        scanSpeed: 0.55,        // low internal activity
                        glowOpacity: 0.07,      // faint glow
                        staticAmount: 0.008     // very stable / neutral
                    )

                case .yellow:
                    return .init(
                        intensity: 0.14,        // starting to get sharper
                        angularity: 0.70,       // more edges showing
                        breatheAmplitude: 0.014,
                        breatheSpeed: 0.95,     // slightly elevated rhythm
                        rotationAmplitude: 1.8,
                        rotationSpeed: 0.21,
                        scanSpeed: 1.05,        // more internal activity
                        glowOpacity: 0.12,
                        staticAmount: 0.02      // noticeable instability
                    )

                case .orange:
                    return .init(
                        intensity: 0.18,        // clearly spiky now
                        angularity: 0.82,       // sharper edges
                        breatheAmplitude: 0.016,
                        breatheSpeed: 1.08,     // faster breathing (fatigue building)
                        rotationAmplitude: 2.1,
                        rotationSpeed: 0.24,
                        scanSpeed: 1.18,        // high internal motion
                        glowOpacity: 0.13,
                        staticAmount: 0.025     // more jitter (unstable feeling)
                    )

                case .purple:
                    return .init(
                        intensity: 0.22,        // aggressive spikes
                        angularity: 0.92,       // very sharp / tense
                        breatheAmplitude: 0.018,
                        breatheSpeed: 1.18,     // fast breathing (stress)
                        rotationAmplitude: 2.4,
                        rotationSpeed: 0.27,
                        scanSpeed: 1.30,        // high activity (overstimulated)
                        glowOpacity: 0.14,
                        staticAmount: 0.03      // strong instability/jitter
                    )

                case .red:
                    return .init(
                        intensity: 0.26,        // most aggressive / hostile
                        angularity: 1.02,       // extremely sharp
                        breatheAmplitude: 0.020,
                        breatheSpeed: 1.32,     // rapid breathing (strain)
                        rotationAmplitude: 2.8,
                        rotationSpeed: 0.30,    // most chaotic motion
                        scanSpeed: 1.45,        // very high internal energy
                        glowOpacity: 0.16,
                        staticAmount: 0.04      // highest instability (alert state)
            )
        }
    }
}
