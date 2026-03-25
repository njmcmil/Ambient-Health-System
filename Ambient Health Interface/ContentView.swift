import SwiftUI

struct AmbientHealthObjectView: View {
    
// --- STATE & NAVIGATION ---
    
    @StateObject private var simulator = HealthSimulator()
    @State private var selectedTab: AmbientTab = .now

    // Keeping navigation intentionally small so the app stays calm and focused.
    enum AmbientTab: String, CaseIterable, Identifiable {
        case now = "Now"
        case explanation = "Explanation"

        var id: String { rawValue }
    }
    
// --- MAIN LAYOUT ---

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            Group {
                switch selectedTab {
                case .now:
                    nowView
                case .explanation:
                    explanationView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 110)

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
    
// --- BACKGROUND LAYER ---
    
    // Soft background wash so the current state subtly colors the screen.
    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(simulator.currentState.color.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(y: -140)
        }
    }
    
// --- NOW VIEW (GLANCEABLE) ---
    
    // Designed to be quick to read: form first, text second.
    private var nowView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            entityView

            VStack(spacing: 8) {
                Text(simulator.currentState.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(nowLine(for: simulator.currentState))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            minimalHistory
            minimalSimulateButton

            Spacer()
        }
    }
// --- EXPLANATION VIEW ---
    
    // More explicit interpretation, but still avoids dashboard-style overload.
    private var explanationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Explanation")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 10) {
                    Text(simulator.currentState.title)
                        .font(.headline)

                    Text(simulator.currentState.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                // --- BULLET INTERPRETATION ---
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("What This May Mean")
                        .font(.headline)

                    ForEach(explanationBullets(for: simulator.currentState), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(simulator.currentState.color.opacity(0.9))
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)

                            Text(bullet)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                
                // --- PROTOTYPE CONTROLS + TREND ---
                
                VStack(alignment: .leading, spacing: 16) {
                    
                    // --- STATE SELECTOR ---
                    
                    Menu {
                        ForEach(ColorHealthState.allCases) { state in
                            Button(state.rawValue) {
                                simulator.setState(state)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Prototype State")
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            Color(uiColor: .tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)

                    // --- TREND VISUALIZATION ---
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Signal Trace")
                            .font(.headline)

                        trendLineView

                        Text("A lightweight trend mockup showing how interpreted state might shift over time from HealthKit-derived patterns.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    
    
// --- REFERENCE-STATE (CORE VISUAL) ---
    
    // Animated form is layered a few times to make it feel luminous
    // https://swiftui-lab.com/swiftui-animations-part1/
    
    private var entityView: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t)
            let profile = simulator.currentState.motionProfile
            
            // --- MOTION DRIVERS ---
            
            let breathe = 1 + profile.breatheAmplitude * sin(phase * profile.breatheSpeed)
            let shellScale = 1 + profile.intensity * 0.04

            ZStack {
                
                // --- OUTER GLOW ---
                
                ReferenceShape(
                    phase: phase * 0.7,
                    intensity: profile.intensity * 0.7,
                    angularity: profile.angularity * 0.9,
                    staticAmount: profile.staticAmount * 1.1
                )
                .fill(simulator.currentState.color.opacity(profile.glowOpacity * 0.55))
                .frame(width: 250, height: 250)
                .blur(radius: 24)
                
                // --- MAIN BODY ---

                ReferenceShape(
                    phase: phase,
                    intensity: profile.intensity,
                    angularity: profile.angularity,
                    staticAmount: profile.staticAmount
                )
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.92),
                            simulator.currentState.color.opacity(0.65),
                            simulator.currentState.color.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 180, height: 210)
                .scaleEffect(shellScale)
                .shadow(color: simulator.currentState.color.opacity(0.14), radius: 18)
                
                // --- EDGE DETAIL ---
                
                ReferenceShape(
                    phase: phase * 1.35,
                    intensity: profile.intensity * 1.1,
                    angularity: profile.angularity * 1.05,
                    staticAmount: profile.staticAmount * 1.4
                )
                .stroke(.white.opacity(0.18), lineWidth: 1)
                .frame(width: 196, height: 228)

                // --- OUTER ENERGY LAYER ---
                
                ReferenceShape(
                    phase: phase * 1.8,
                    intensity: profile.intensity * 0.55,
                    angularity: profile.angularity * 1.2,
                    staticAmount: profile.staticAmount * 1.8
                )
                .stroke(simulator.currentState.color.opacity(0.10), lineWidth: 1)
                .frame(width: 220, height: 246)
                .blur(radius: 1.2)
            }
            .scaleEffect(breathe)
            .frame(width: 280, height: 280)
        }
    }
    
// --- TREND SYSTEM ---
    
    // simplified-trend view.
    // It gives a sense of movement over time without becoming a dense health chart.
    private var trendLineView: some View {
        let states = simulator.history

        return GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let points = trendPoints(for: states, size: geometry.size)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.10))

                // Very faint guide lines so the chart has structure
                // without pulling too much attention.
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                        Spacer()
                    }
                }
                .padding(.vertical, 12)

                if points.count > 1 {
                    trendAreaPath(points: points, size: geometry.size)
                        .fill(
                            LinearGradient(
                                colors: [
                                    simulator.currentState.color.opacity(0.18),
                                    simulator.currentState.color.opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    trendCurvePath(points: points)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    simulator.currentState.color.opacity(0.95),
                                    simulator.currentState.color.opacity(0.60)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                }

                ForEach(Array(points.enumerated()), id: \.offset) { entry in
                    let state = states[entry.offset]

                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .fill(state.color)
                                .frame(width: 7, height: 7)
                        }
                        .position(entry.element)
                }

                HStack {
                    ForEach(Array(states.enumerated()), id: \.offset) { entry in
                        Text(shortLabel(for: entry.element))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 4)
            }
            .frame(width: width, height: height)
        }
        .frame(height: 150)
    }
// --- HISTORY + CONTROLS ---
    
    // Simple small recent history strip for the "Now" screen.
    // Keeps some memory of old states, important not to become a another trend view
    private var minimalHistory: some View {
        VStack(spacing: 8) {
            Text("Recent tone")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(simulator.history.enumerated()), id: \.offset) { entry in
                    let isLatest = entry.offset == simulator.history.indices.last

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    entry.element.color.opacity(0.95),
                                    entry.element.color.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: isLatest ? 34 : 26, height: isLatest ? 12 : 10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.22), lineWidth: 0.6)
                        }
                        .shadow(
                            color: entry.element.color.opacity(isLatest ? 0.22 : 0.10),
                            radius: isLatest ? 8 : 4
                        )
                }
            }
        }
        .padding(.top, 6)
    }
    
// --- SIMULATE BUTTON ---
    // Prototype-only control: state changes can be demonstrated quickly.
    private var minimalSimulateButton: some View {
        Button {
            simulator.simulateRandomChange()
        } label: {
            Text("Simulate")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(simulator.currentState.color)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    
// --- BOTTOM BAR ---
    private var bottomBar: some View {
        HStack(spacing: 8) {
            ForEach(AmbientTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.7))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // --- TREND-POINTS ---
    private func trendPoints(for states: [ColorHealthState], size: CGSize) -> [CGPoint] {
        guard !states.isEmpty else { return [] }

        let horizontalPadding: CGFloat = 12
        let topPadding: CGFloat = 18
        let bottomPadding: CGFloat = 26

        let usableWidth = size.width - horizontalPadding * 2
        let usableHeight = size.height - topPadding - bottomPadding
        let stepX = states.count > 1 ? usableWidth / CGFloat(states.count - 1) : 0

        return states.enumerated().map { index, state in
            let x = horizontalPadding + CGFloat(index) * stepX
            let normalized = trendValue(for: state)
            let y = topPadding + (1 - normalized) * usableHeight
            return CGPoint(x: x, y: y)
        }
    }
    
    // --- TREND-CURVE ---
    // Smooths the state history into a softer trace so it feels less like a harsh data-intensive graph.
    private func trendCurvePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2

            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }

        return path
    }

    // --- TREND-PATH ---
    private func trendAreaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = trendCurvePath(points: points)
        guard let first = points.first, let last = points.last else { return path }

        path.addLine(to: CGPoint(x: last.x, y: size.height - 26))
        path.addLine(to: CGPoint(x: first.x, y: size.height - 26))
        path.closeSubpath()

        return path
    }

    // --- DATA MAPPING HELPERS ---
    
    // Maps each symbolic state to a relative..vertical position for the mock trend.
    private func trendValue(for state: ColorHealthState) -> CGFloat {
        switch state {
        case .gray: return 0.20
        case .blue: return 0.40
        case .green: return 0.50
        case .yellow: return 0.64
        case .orange: return 0.74
        case .purple: return 0.84
        case .red: return 0.94
        }
    }

    // --- TEXT HELPERS ---
    
    private func shortLabel(for state: ColorHealthState) -> String {
        switch state {
        case .blue: return "Rec"
        case .green: return "On"
        case .yellow: return "Move"
        case .purple: return "Stress"
        case .gray: return "Steady"
        case .red: return "Warn"
        case .orange: return "Tired"
        }
    }

    private func nowLine(for state: ColorHealthState) -> String {
        switch state {
        case .blue: return "Your body appears to be recovering well."
        case .green: return "Your recent pattern looks healthy and steady."
        case .yellow: return "You may benefit from a bit more movement."
        case .purple: return "Your current pattern suggests increased stress."
        case .gray: return "Your current state looks stable and neutral."
        case .red: return "Something in your recent pattern may need attention."
        case .orange: return "Your recent pattern suggests building fatigue."
        }
    }

    private func explanationBullets(for state: ColorHealthState) -> [String] {
        switch state {
        case .blue:
            return [
                "Your body is recovering well.",
                "You look well-rested.",
                "Keep doing what you're doing."
            ]
        case .green:
            return [
                "Your activity level looks healthy.",
                "Your routine is consistent.",
                "You're in a good rhythm."
            ]
        case .yellow:
            return [
                "You've been inactive for a while.",
                "Try to move a bit.",
                "Even a short walk can help."
            ]
        case .purple:
            return [
                "Your stress level looks high.",
                "Your body may need a break.",
                "Try to slow down and reset."
            ]
        case .gray:
            return [
                "Everything looks normal.",
                "No strong signals detected.",
                "You're stable right now."
            ]
        case .red:
            return [
                "Something looks off.",
                "Your body is under strain.",
                "Pay attention to how you feel."
            ]
        case .orange:
            return [
                "Fatigue is building up.",
                "You may need rest soon.",
                "Consider taking a break."
            ]
        }
    }
}

#Preview {
    AmbientHealthObjectView()
}
