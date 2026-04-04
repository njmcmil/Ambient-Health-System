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
                intensity: 0.10,
                angularity: 0.54,
                breatheAmplitude: 0.012,
                breatheSpeed: 0.78,
                rotationAmplitude: 1.6,
                rotationSpeed: 0.18,
                scanSpeed: 0.82,
                glowOpacity: 0.11,
                staticAmount: 0.012
            )
        case .green:
            return .init(
                intensity: 0.12,
                angularity: 0.62,
                breatheAmplitude: 0.014,
                breatheSpeed: 0.90,
                rotationAmplitude: 1.9,
                rotationSpeed: 0.20,
                scanSpeed: 0.96,
                glowOpacity: 0.12,
                staticAmount: 0.017
            )
        case .gray:
            return .init(
                intensity: 0.08,
                angularity: 0.46,
                breatheAmplitude: 0.010,
                breatheSpeed: 0.64,
                rotationAmplitude: 1.1,
                rotationSpeed: 0.14,
                scanSpeed: 0.66,
                glowOpacity: 0.09,
                staticAmount: 0.010
            )
        case .yellow:
            return .init(
                intensity: 0.17,
                angularity: 0.76,
                breatheAmplitude: 0.016,
                breatheSpeed: 1.06,
                rotationAmplitude: 2.2,
                rotationSpeed: 0.23,
                scanSpeed: 1.16,
                glowOpacity: 0.13,
                staticAmount: 0.024
            )
        case .orange:
            return .init(
                intensity: 0.22,
                angularity: 0.88,
                breatheAmplitude: 0.014,
                breatheSpeed: 0.94,
                rotationAmplitude: 1.8,
                rotationSpeed: 0.20,
                scanSpeed: 1.02,
                glowOpacity: 0.14,
                staticAmount: 0.028
            )
        case .purple:
            return .init(
                intensity: 0.27,
                angularity: 0.98,
                breatheAmplitude: 0.020,
                breatheSpeed: 1.30,
                rotationAmplitude: 2.8,
                rotationSpeed: 0.29,
                scanSpeed: 1.40,
                glowOpacity: 0.15,
                staticAmount: 0.035
            )
        case .red:
            return .init(
                intensity: 0.35,
                angularity: 1.14,
                breatheAmplitude: 0.024,
                breatheSpeed: 1.62,
                rotationAmplitude: 3.8,
                rotationSpeed: 0.38,
                scanSpeed: 1.72,
                glowOpacity: 0.18,
                staticAmount: 0.052
            )
        }
    }
}
