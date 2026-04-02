import SwiftUI

struct EntityMotionProfile {
    let intensity: CGFloat
    let angularity: CGFloat
    let breatheAmplitude: CGFloat
    let breatheSpeed: CGFloat
    let rotationAmplitude: CGFloat
    let rotationSpeed: CGFloat
    let scanSpeed: CGFloat
    let glowOpacity: CGFloat
    let staticAmount: CGFloat
}

extension ColorHealthState {
    var motionProfile: EntityMotionProfile {
        switch self {
        case .blue:
            return .init(
                intensity: 0.08,
                angularity: 0.50,
                breatheAmplitude: 0.010,
                breatheSpeed: 0.70,
                rotationAmplitude: 1.2,
                rotationSpeed: 0.16,
                scanSpeed: 0.70,
                glowOpacity: 0.10,
                staticAmount: 0.01
            )
        case .green:
            return .init(
                intensity: 0.10,
                angularity: 0.58,
                breatheAmplitude: 0.012,
                breatheSpeed: 0.82,
                rotationAmplitude: 1.5,
                rotationSpeed: 0.18,
                scanSpeed: 0.85,
                glowOpacity: 0.11,
                staticAmount: 0.015
            )
        case .gray:
            return .init(
                intensity: 0.06,
                angularity: 0.42,
                breatheAmplitude: 0.008,
                breatheSpeed: 0.55,
                rotationAmplitude: 0.9,
                rotationSpeed: 0.12,
                scanSpeed: 0.55,
                glowOpacity: 0.07,
                staticAmount: 0.008
            )
        case .yellow:
            return .init(
                intensity: 0.14,
                angularity: 0.70,
                breatheAmplitude: 0.014,
                breatheSpeed: 0.95,
                rotationAmplitude: 1.8,
                rotationSpeed: 0.21,
                scanSpeed: 1.05,
                glowOpacity: 0.12,
                staticAmount: 0.02
            )
        case .orange:
            return .init(
                intensity: 0.18,
                angularity: 0.82,
                breatheAmplitude: 0.016,
                breatheSpeed: 1.08,
                rotationAmplitude: 2.1,
                rotationSpeed: 0.24,
                scanSpeed: 1.18,
                glowOpacity: 0.13,
                staticAmount: 0.025
            )
        case .purple:
            return .init(
                intensity: 0.22,
                angularity: 0.92,
                breatheAmplitude: 0.018,
                breatheSpeed: 1.18,
                rotationAmplitude: 2.4,
                rotationSpeed: 0.27,
                scanSpeed: 1.30,
                glowOpacity: 0.14,
                staticAmount: 0.03
            )
        case .red:
            return .init(
                intensity: 0.26,
                angularity: 1.02,
                breatheAmplitude: 0.020,
                breatheSpeed: 1.32,
                rotationAmplitude: 2.8,
                rotationSpeed: 0.30,
                scanSpeed: 1.45,
                glowOpacity: 0.16,
                staticAmount: 0.04
            )
        }
    }
}
