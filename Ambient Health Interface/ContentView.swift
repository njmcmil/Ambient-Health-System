import SwiftUI

struct AmbientHealthObjectView: View {
    
// --- STATE & NAVIGATION ---
    
    @StateObject private var simulator = HealthSimulator()
    @State private var selectedTab: AmbientTab = .now
    
    @State private var stressSensitivity: Double = 0.7
    @State private var movementSensitivity: Double = 0.5
    @State private var recoverySensitivity: Double = 0.6
    @State private var overallResponsiveness: Double = 0.55
    
    @GestureState private var isPressingBlob = false



    // Keeping navigation intentionally small so the app stays calm and focused.
    enum AmbientTab: String, CaseIterable, Identifiable {
        case now = "Now"
        case explanation = "Explanation"
        case sensitivity = "Sensitivity"

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
                case .sensitivity:
                    sensitivityView
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

            referenceView

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
                        .frame(height: 43)
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
            .padding(.bottom, 40)
        }
    }

    
// --- SENSITIVITY VIEW ---
    
    private var sensitivityView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sensitivity")
                    .font(.title2.weight(.semibold))

                Text("These controls are simulated for the prototype and let you adjust how responsive the system is to different health patterns.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                sensitivitySlider(
                    title: "Stress Response",
                    value: $stressSensitivity
                )

                sensitivitySlider(
                    title: "Movement Response",
                    value: $movementSensitivity
                )

                sensitivitySlider(
                    title: "Recovery Response",
                    value: $recoverySensitivity
                )

                sensitivitySlider(
                    title: "Overall Responsiveness",
                    value: $overallResponsiveness
                )
                
                Text("App Default is recommended for the average user.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                Button {
                    resetSensitivityToDefault()
                } label: {
                    Text("Reset to App Default")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                
            }
            .padding(.bottom, 40)
        }
    }

    
    
// --- REFERENCE-STATE (CORE VISUAL) ---
    
    // Animated form is layered a few times to make it feel luminous
    // https://swiftui-lab.com/swiftui-animations-part1/
    private var referenceView: some View {
        
        // --- TOUCH GESTURE ---
        
        let pressGesture = DragGesture(minimumDistance: 0)
            .updating($isPressingBlob) { _, state, _ in
                state = true
            }

        return TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t)
            let profile = simulator.currentState.motionProfile
            let touch = touchProfile(for: simulator.currentState)
            
            // --- MOTION DRIVERS ---
            
            let breathe = 1 + profile.breatheAmplitude * sin(phase * profile.breatheSpeed)
            let shellScale = 1 + profile.intensity * 0.04
            
            // --- TOUCH RESPONSE VALUES ---
            
            let touchBoost = isPressingBlob ? touch.boost : 0
            let touchGlow = isPressingBlob ? touch.glow : 0
            let touchScale = isPressingBlob ? touch.scale : 0
            let jitterX = touchJitter(for: simulator.currentState, phase: phase, isActive: isPressingBlob)

            ZStack {
                
                // --- OUTER GLOW ---
                
                ReferenceShape(
                    phase: phase * 0.7,
                    intensity: profile.intensity * 0.7 + touchBoost,
                    angularity: profile.angularity * 0.9,
                    staticAmount: profile.staticAmount * 1.1
                )
                .fill(simulator.currentState.color.opacity(profile.glowOpacity * 0.55 + touchGlow))
                .frame(width: 250, height: 250)
                .blur(radius: isPressingBlob ? touch.blur : 24)
                
                // --- MAIN BODY ---

                ReferenceShape(
                    phase: phase,
                    intensity: profile.intensity + touchBoost,
                    angularity: profile.angularity,
                    staticAmount: profile.staticAmount
                )
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(isPressingBlob ? 0.98 : 0.92),
                            simulator.currentState.color.opacity(0.65),
                            simulator.currentState.color.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 180, height: 210)
                .scaleEffect(shellScale + touchScale)
                .shadow(color: simulator.currentState.color.opacity(isPressingBlob ? 0.24 : 0.14), radius: isPressingBlob ? 24 : 18)
                
                // --- EDGE DETAIL ---
                
                ReferenceShape(
                    phase: phase * 1.35,
                    intensity: profile.intensity * 1.1 + touchBoost,
                    angularity: profile.angularity * 1.05,
                    staticAmount: profile.staticAmount * 1.4
                )
                .stroke(.white.opacity(isPressingBlob ? touch.edgeOpacity : 0.18), lineWidth: isPressingBlob ? 1.4 : 1)
                .frame(width: 196, height: 228)

                // --- OUTER ENERGY LAYER ---
                
                ReferenceShape(
                    phase: phase * 1.8,
                    intensity: profile.intensity * 0.55 + touchBoost,
                    angularity: profile.angularity * 1.2,
                    staticAmount: profile.staticAmount * 1.8
                )
                .stroke(simulator.currentState.color.opacity(isPressingBlob ? 0.18 : 0.10), lineWidth: 1)
                .frame(width: 220, height: 246)
                .blur(radius: isPressingBlob ? 2.2 : 1.2)
            }
            
            // --- FINAL TRANSFORMS ---
            
            .scaleEffect(breathe + touchScale * 0.25)
            .offset(x: jitterX)
            .frame(width: 280, height: 280)
            .contentShape(Rectangle())
            .gesture(pressGesture)
            .animation(touch.animation, value: isPressingBlob)
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
        HStack(spacing: 10) {
            ForEach(Array(simulator.history.enumerated()), id: \.offset) { entry in
                let progress = CGFloat(entry.offset) / CGFloat(max(simulator.history.count - 1, 1))
                let size = 16 + (progress * 14)
                let opacity = 0.22 + (progress * 0.55)
                let blur = 4 - (progress * 2)
                let isLatest = entry.offset == simulator.history.count - 1

                Circle()
                    .fill(entry.element.color.opacity(opacity))
                    .frame(width: size, height: size)
                    .blur(radius: blur)
                    .overlay {
                        if isLatest {
                            Circle()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                                .frame(width: size + 4, height: size + 4)
                        }
                    }
            }
        }
        .frame(height: 34)
        .padding(.top, 2)
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
                "Recovery-related signals appear steadier than your usual baseline.",
                "Sleep and heart rate patterns suggest your body may be recovering well.",
                "No strong stress or fatigue-related deviation is standing out right now."
            ]
        case .green:
            return [
                "Movement, sleep, and recovery patterns appear fairly consistent.",
                "Your recent health signals look stable relative to your normal baseline.",
                "No major shift in stress, heart rate, or activity is standing out."
            ]
        case .yellow:
            return [
                "Movement may be lower than your usual baseline right now.",
                "This state can appear after longer periods of inactivity or reduced activity trends.",
                "Heart rate and recovery signals do not appear to be the main drivers here."
            ]
        case .purple:
            return [
                "Stress-related signals may be elevated relative to your normal baseline.",
                "Heart rate or HRV-related patterns may suggest more strain than usual.",
                "Recovery and sleep patterns may be contributing to this more tense state."
            ]
        case .gray:
            return [
                "Current signals appear close to your normal baseline.",
                "No strong deviation in movement, stress, heart rate, or recovery is standing out.",
                "This usually reflects a steady state without a dominant pattern."
            ]
        case .red:
            return [
                "The current pattern appears more strained than your usual baseline.",
                "Stress, heart rate, or recovery-related signals may be showing a stronger shift than normal.",
                "This state is meant to reflect a more significant change in your overall signal."
            ]
        case .orange:
            return [
                "Fatigue-related patterns may be building relative to your recent baseline.",
                "Recovery may be lagging behind physical or physiological load.",
                "Sleep, heart rate, or ongoing strain may be contributing to this state."
            ]
        }
    }

    private func resetSensitivityToDefault() {
        stressSensitivity = 0.7
        movementSensitivity = 0.5
        recoverySensitivity = 0.6
        overallResponsiveness = 0.55
    }

    private func sensitivitySlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: 0...1)
                .tint(.blue)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        return TouchProfile(
            boost: 0.02,
            glow: 0.04,
            blur: 26,
            scale: 0.08,
            edgeOpacity: 0.20,
            animation: .easeOut(duration: 0.24)
        )
    case .blue:
        return TouchProfile(
            boost: 0.03,
            glow: 0.05,
            blur: 27,
            scale: 0.10,
            edgeOpacity: 0.22,
            animation: .easeOut(duration: 0.22)
        )
    case .green:
        return TouchProfile(
            boost: 0.04,
            glow: 0.06,
            blur: 28,
            scale: 0.12,
            edgeOpacity: 0.24,
            animation: .easeOut(duration: 0.20)
        )
    case .yellow:
        return TouchProfile(
            boost: 0.06,
            glow: 0.08,
            blur: 29,
            scale: 0.16,
            edgeOpacity: 0.26,
            animation: .easeOut(duration: 0.18)
        )
    case .orange:
        return TouchProfile(
            boost: 0.08,
            glow: 0.10,
            blur: 30,
            scale: 0.20,
            edgeOpacity: 0.30,
            animation: .spring(response: 0.24, dampingFraction: 0.72)
        )
    case .purple:
        return TouchProfile(
            boost: 0.10,
            glow: 0.12,
            blur: 31,
            scale: 0.22,
            edgeOpacity: 0.34,
            animation: .interactiveSpring(response: 0.18, dampingFraction: 0.55)
        )
    case .red:
        return TouchProfile(
            boost: 0.13,
            glow: 0.16,
            blur: 33,
            scale: 0.28,
            edgeOpacity: 0.40,
            animation: .interactiveSpring(response: 0.14, dampingFraction: 0.45)
        )
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




#Preview {
    AmbientHealthObjectView()
}
