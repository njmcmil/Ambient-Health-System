import SwiftUI

struct ReferenceShape: Shape {
    var phase: CGFloat
    var intensity: CGFloat
    var angularity: CGFloat
    var staticAmount: CGFloat
    var widthScale: CGFloat = 1.0
    var heightScale: CGFloat = 1.0
    var skew: CGFloat = 0.0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.33
        let pointCount = 40
        let pointiness = min(max((angularity - 0.62) / 0.44, 0), 1)

        var points: [CGPoint] = []

        for index in 0..<pointCount {
            let t = CGFloat(index) / CGFloat(pointCount)
            let angle = t * .pi * 2

            let shellPulse = sin(phase * 0.75) * 0.10
            let nodePulse = sin(angle * 5 + phase * 1.05) * intensity * 0.18
            let electricRidge = max(0, sin(angle * 8 - phase * 1.55)) * angularity * 0.20
            let flutter = sin(angle * 17 + phase * 2.7) * staticAmount * 0.09
            let spikePattern = max(0, sin(angle * 6 - phase * 0.85)) * pointiness * 0.22
            let shardPull = (index.isMultiple(of: 2) ? 1 : -0.35) * pointiness * 0.05
            let breath = sin(phase * 0.52 + angle * 0.4) * 0.035
            let verticalStretch = (1.0 + 0.18 * abs(sin(angle))) * heightScale
            let horizontalTightening = (1.0 - 0.10 * abs(cos(angle))) * widthScale

            let radius = baseRadius * (1 + shellPulse + nodePulse + electricRidge + flutter + spikePattern + shardPull + breath)
            let x = center.x + cos(angle) * radius * horizontalTightening + (sin(angle * 2 + phase * 0.3) * skew * baseRadius)
            let y = center.y + sin(angle) * radius * verticalStretch

            points.append(CGPoint(x: x, y: y))
        }

        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: first)

        for index in 0..<points.count {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let mid = CGPoint(
                x: (current.x + next.x) / 2,
                y: (current.y + next.y) / 2
            )
            if pointiness > 0.52 && index.isMultiple(of: 3) {
                path.addLine(to: current)
                path.addLine(to: mid)
            } else {
                path.addQuadCurve(to: mid, control: current)
            }
        }

        path.closeSubpath()
        return path
    }
}
