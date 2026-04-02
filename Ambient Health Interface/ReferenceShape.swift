import SwiftUI

struct ReferenceShape: Shape {
    var phase: CGFloat
    var intensity: CGFloat
    var angularity: CGFloat
    var staticAmount: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.34
        let pointCount = 22

        var path = Path()

        for index in 0...pointCount {
            let t = CGFloat(index) / CGFloat(pointCount)
            let angle = t * .pi * 2

            let polygonPulse = sin(phase * 0.7) * 0.12
            let starPulse = max(0, sin(angle * 6 + phase * 1.3)) * intensity * 0.32
            let shardPulse = sin(angle * 3 - phase * 0.9) * angularity * 0.14
            let staticPulse = sin(angle * 22 + phase * 3.2) * staticAmount * 0.08
            let breath = sin(phase * 0.6) * 0.04
            let verticalStretch = 1.0 + 0.22 * abs(sin(angle))
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
