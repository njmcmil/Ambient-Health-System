import SwiftUI

// This shape generates the reference.
// It's not meant to be a perfect geometric object —
// Intentionally unstable, asymmetric, and evolving
// so it feels more like a presence than a UI element.
struct ReferenceShape: Shape {

    // Time-based input for animation
    var phase: CGFloat

    // Controls how aggressive/spiky the form becomes
    var intensity: CGFloat
    
    // Controls sharpness vs smoothness
    var angularity: CGFloat

    // Adds jitter/noise to break perfection (makes it feel alive/tense)
    var staticAmount: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Base size of the reference shape
        let baseRadius = min(rect.width, rect.height) * 0.34

        // Lower point count -> more angular / polygon-like
        let pointCount = 22

        var path = Path()

        for index in 0...pointCount {
            let t = CGFloat(index) / CGFloat(pointCount)
            let angle = t * .pi * 2

// --- SHAPE COMPONENTS ---

            // keeps it from feeling static
            let polygonPulse = sin(phase * 0.7) * 0.12

            // Creates outward spikes ("hostile" feature)
            let starPulse = max(0, sin(angle * 6 + phase * 1.3)) * intensity * 0.32

            // Breaks symmetry -> makes shape feel uneven
            let shardPulse = sin(angle * 3 - phase * 0.9) * angularity * 0.14

            // High-frequency noise -> subtle flicker/tension
            let staticPulse = sin(angle * 22 + phase * 3.2) * staticAmount * 0.08

            // Breathing effect
            let breath = sin(phase * 0.6) * 0.04

// --- FORM DISTORTION ---

            // Stretch vertically
            let verticalStretch = 1.0 + 0.22 * abs(sin(angle))

            // Slight horizontal compression -> avoids perfect circle look
            let horizontalTightening = 1.0 - 0.12 * abs(cos(angle))

            let radius =
                baseRadius *
                (1 + polygonPulse + starPulse + shardPulse + staticPulse + breath)

            let x = center.x + cos(angle) * radius * horizontalTightening
            let y = center.y + sin(angle) * radius * verticalStretch

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }
}
