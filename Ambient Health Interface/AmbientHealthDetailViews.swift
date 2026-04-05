import SwiftUI

// These detail screens intentionally hold the more explicit, inspectable layer of the app.
// The main Now screen stays ambient

struct AmbientTrendsView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @AppStorage("anxietyCalmerMode") private var calmerModeEnabled = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trends")
                    .font(.title2.weight(.semibold))

                Text("A lighter weekly view of the signals behind your current mood read.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let previewState = healthStore.previewState {
                    AmbientPreviewStateCard(
                        state: previewState,
                        calmerModeEnabled: calmerModeEnabled
                    )
                } else if let trendReport = healthStore.trendReport {
                    if calmerModeEnabled {
                        AmbientCalmerTrendsView(
                            trendReport: trendReport,
                            currentState: healthStore.displayedState
                        )
                    } else {
                        // Trends are intentionally trimmed down to the few views that help explain mood,
                        // instead of trying to expose every raw signal the store knows about.
                        AmbientWeeklySummaryCard(
                            trendReport: trendReport,
                            currentState: healthStore.displayedState
                        )
                        AmbientHRVTrendCard(points: trendReport.heartRateVariability)
                        AmbientHeartTrendCard(
                            points: trendReport.restingHeartRate
                        )
                        AmbientEnergyRhythmCard(
                            steps: trendReport.steps,
                            exerciseMinutes: trendReport.exerciseMinutes
                        )
                        AmbientSleepDurationCard(points: trendReport.sleepHours)
                        AmbientSleepQualitySummaryCard(points: trendReport.sleepStages)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No trend data yet")
                            .font(.headline)

                        Text("Connect Health and refresh on your iPhone after a few days of watch data have synced.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .ambientPanel(tint: Color.white)
                }
            }
            .padding(.bottom, 40)
        }
    }
}

struct AmbientExplanationView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @AppStorage("anxietyCalmerMode") private var calmerModeEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Explanation")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 10) {
                    // A small visual marker helps the current state read faster without turning the
                    // explanation cards into a dense icon-heavy dashboard.
                    AmbientSectionHeader(
                        title: healthStore.displayedState.title,
                        symbol: symbolForState(healthStore.displayedState),
                        tint: healthStore.displayedState.color
                    )

                    let chips = healthStore.previewState.map(previewSignalChips(for:)) ?? explanationSignalChips(snapshot: healthStore.latestSnapshot)
                    if !calmerModeEnabled, !chips.isEmpty {
                        AmbientExplanationSignalRow(
                            chips: chips,
                            tint: healthStore.displayedState.color
                        )
                    }

                    if healthStore.previewState != nil {
                        Text("Preview mode is on. This page is showing an example read for the selected state, not your live health interpretation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    AmbientSectionHeader(
                        title: "What This May Mean",
                        symbol: "sparkles",
                        tint: Color(red: 0.49, green: 0.72, blue: 0.96)
                    )

                    let bullets = explanationBulletContent

                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color(red: 0.72, green: 0.77, blue: 0.82).opacity(0.95))
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

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            AmbientSectionHeader(
                                title: "Pattern Insight",
                                symbol: "text.magnifyingglass",
                                tint: Color(red: 0.49, green: 0.72, blue: 0.96)
                            )

                            Spacer()

                            AmbientInsightHistoryTrail(history: historyTrail)
                        }

                        Text(patternInsightText)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(patternInsightCaption)
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

    private var historyTrail: [ColorHealthState] {
        if let previewState = healthStore.previewState {
            return Array(repeating: previewState, count: max(healthStore.history.count, 6))
        }
        return healthStore.history
    }

    private var explanationBulletContent: [String] {
        if let previewState = healthStore.previewState {
            return calmerModeEnabled
                ? calmerGenericExplanationBullets(for: previewState)
                : genericExplanationBullets(for: previewState)
        }

        return calmerModeEnabled
            ? calmerExplanationBullets(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
            : explanationBullets(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
    }

    private var patternInsightText: String {
        if let previewState = healthStore.previewState {
            return calmerModeEnabled
                ? calmerPatternInsight(for: previewState, snapshot: nil)
                : patternInsight(for: previewState, snapshot: nil)
        }

        return calmerModeEnabled
            ? calmerPatternInsight(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
            : patternInsight(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
    }

    private var patternInsightCaption: String {
        if healthStore.previewState != nil {
            return calmerModeEnabled
                ? "A gentler example of how this state can show up."
                : "A plain-language read on how this state usually feels in the app."
        }

        return calmerModeEnabled
            ? "A softer explanation based on your recent pattern and your usual rhythm."
            : "Based on recent health patterns and how they compare to your usual rhythm."
    }
}

private struct AmbientCalmerTrendsView: View {
    let trendReport: AmbientHealthStore.TrendReport
    let currentState: ColorHealthState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCalmerTrendNoteCard(
                title: currentState.title,
                detail: calmerSummaryLine(for: currentState),
                tint: currentState.color
            )

            AmbientCalmerTrendNoteCard(
                title: "Recovery",
                detail: calmerWeeklyTrendSummary(
                    points: trendReport.heartRateVariability,
                    lowMeaning: "Recovery looks a little softer than your recent norm.",
                    highMeaning: "Recovery looks a little stronger than your recent norm.",
                    unit: "ms",
                    formatter: { Int($0).formatted() },
                    includeLatest: false
                ),
                tint: .teal
            )

            AmbientCalmerTrendNoteCard(
                title: "Resting Rhythm",
                detail: calmerInverseWeeklyTrendSummary(
                    points: trendReport.restingHeartRate,
                    lowMeaning: "Your system looks a little calmer than your recent norm.",
                    highMeaning: "Your system looks a little more activated than your recent norm.",
                    unit: "bpm",
                    formatter: { Int($0).formatted() },
                    includeLatest: false
                ),
                tint: Color(red: 1.0, green: 0.20, blue: 0.22)
            )

            AmbientCalmerTrendNoteCard(
                title: "Movement",
                detail: calmerEnergySummary(
                    steps: trendReport.steps,
                    exerciseMinutes: trendReport.exerciseMinutes
                ),
                tint: .green
            )

            AmbientCalmerTrendNoteCard(
                title: "Sleep",
                detail: calmerWeeklyTrendSummary(
                    points: trendReport.sleepHours,
                    lowMeaning: "Sleep looks a little lighter than your recent norm.",
                    highMeaning: "Sleep looks a little fuller than your recent norm.",
                    unit: "h",
                    formatter: { String(format: "%.1f", $0) },
                    includeLatest: false
                ),
                tint: Color(red: 0.73, green: 0.56, blue: 0.88)
            )

            AmbientCalmerTrendNoteCard(
                title: "Sleep Quality",
                detail: calmerSleepStageSummary(points: trendReport.sleepStages),
                tint: .blue
            )
        }
    }
}

private struct AmbientCalmerTrendNoteCard: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: tint)
    }
}

private func calmerSummaryLine(for state: ColorHealthState) -> String {
    switch state {
    case .blue:
        return "Your current pattern looks a little more restored and supported than usual."
    case .green:
        return "Your current pattern looks steady and relatively well supported."
    case .yellow:
        return "Your current pattern looks quieter and lower-energy than usual."
    case .purple:
        return "Your current pattern looks a little more activated than your usual baseline."
    case .gray:
        return "Your current pattern looks close to baseline."
    case .red:
        return "Your current pattern looks more intense, with several signals pulling in the same direction."
    case .orange:
        return "Your current pattern looks more worn down than activated."
    }
}

private struct AmbientWeeklySummaryCard: View {
    let trendReport: AmbientHealthStore.TrendReport
    let currentState: ColorHealthState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "This Week", symbol: "sparkles", tint: currentState.color)

            // This card is the "tell me the story first" layer for the Trends tab.
            Text("The mood read is currently \(currentState.title.lowercased()). These are the strongest weekly themes behind it.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                AmbientSummaryRow(
                    title: "Sleep",
                    detail: weeklyTrendSummary(
                        points: trendReport.sleepHours,
                        lowMeaning: "lighter sleep than your recent norm",
                        highMeaning: "more sleep than your recent norm",
                        unit: "h",
                        formatter: { String(format: "%.1f", $0) }
                    )
                )
                AmbientSummaryRow(
                    title: "Recovery",
                    detail: weeklyTrendSummary(
                        points: trendReport.heartRateVariability,
                        lowMeaning: "recovery looked softer",
                        highMeaning: "recovery looked stronger",
                        unit: "ms",
                        formatter: { Int($0).formatted() }
                    )
                )
                AmbientSummaryRow(
                    title: "Calm Load",
                    detail: inverseWeeklyTrendSummary(
                        points: trendReport.restingHeartRate,
                        lowMeaning: "your system looked calmer",
                        highMeaning: "your system looked more activated",
                        unit: "bpm",
                        formatter: { Int($0).formatted() }
                    )
                )
                AmbientSummaryRow(
                    title: "Energy",
                    detail: combinedEnergySummary(
                        steps: trendReport.steps,
                        exerciseMinutes: trendReport.exerciseMinutes
                    )
                )
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AmbientPreviewStateCard: View {
    let state: ColorHealthState
    let calmerModeEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Preview Mode", symbol: symbolForState(state), tint: state.color)

            Text("You are previewing \(state.title.lowercased()). Trends are showing an example interpretation instead of your live weekly summary.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !calmerModeEnabled {
                AmbientExplanationSignalRow(
                    chips: previewSignalChips(for: state),
                    tint: state.color
                )
            }

            Text(calmerModeEnabled ? calmerStateExampleScenario(for: state) : patternInsight(for: state, snapshot: nil))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AmbientSummaryRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AmbientEnergyRhythmCard: View {
    let steps: [AmbientHealthStore.TrendPoint]
    let exerciseMinutes: [AmbientHealthStore.TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Energy Rhythm", symbol: "figure.walk.motion", tint: .green)

            Text("A quick read on weekly movement and momentum.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let avgSteps = weeklyAverage(for: steps), let avgExercise = weeklyAverage(for: exerciseMinutes) {
                HStack(spacing: 12) {
                    AmbientMiniMetric(title: "Avg Steps", value: Int(avgSteps).formatted())
                    AmbientMiniMetric(title: "Avg Exercise", value: "\(Int(avgExercise)) min")
                }
            }

            Text(combinedEnergySummary(steps: steps, exerciseMinutes: exerciseMinutes))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            let displayPoints = Array(meaningfulTrendPoints(steps).suffix(5))
            let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { ($0.date, $0.value) })

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let exercise = exerciseMap[point.date] ?? 0
                        let intensity = energyIntensity(
                            steps: point.value,
                            exercise: exercise,
                            stepSeries: displayPoints,
                            exerciseSeries: exerciseMinutes
                        )
                        let dotSize = energyDotSize(for: intensity)
                        let haloSize = max(26, dotSize * 2.8)
                        let lineHeight = energyLineHeight(for: intensity, recencyIndex: entry.offset, totalCount: displayPoints.count)
                        let isLatest = entry.offset == displayPoints.count - 1

                        VStack(spacing: 6) {
                            ZStack {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.green.opacity(0.18 + (0.14 * intensity)),
                                                Color.green.opacity(0.035)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 7, height: lineHeight)
                                    .overlay(alignment: .top) {
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [
                                                        Color.green.opacity(0.24 + (0.12 * intensity)),
                                                        Color.green.opacity(0.08),
                                                        .clear
                                                    ],
                                                    center: .center,
                                                    startRadius: 1,
                                                    endRadius: haloSize / 2
                                                )
                                            )
                                            .frame(width: haloSize, height: haloSize)
                                            .blur(radius: 8)
                                            .overlay {
                                                Circle()
                                                    .fill(Color.green.opacity(isLatest ? 0.94 : 0.82))
                                                    .frame(width: dotSize, height: dotSize)
                                                    .overlay {
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                                                    }
                                            }
                                    }
                                    .overlay(alignment: .bottom) {
                                        if isLatest {
                                            Image(systemName: "figure.walk.motion")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color.green.opacity(0.92))
                                                .padding(.bottom, -16)
                                        }
                                    }
                            }
                            .frame(height: 58)

                            Text("\(abbreviatedSteps(point.value))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(isLatest ? "Latest" : shortDayLabel(for: point.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.green.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            } else {
                Text("Not enough recent data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .ambientPanel(tint: .green)
    }

    private func energyIntensity(
        steps: Double,
        exercise: Double,
        stepSeries: [AmbientHealthStore.TrendPoint],
        exerciseSeries: [AmbientHealthStore.TrendPoint]
    ) -> CGFloat {
        let stepValues = stepSeries.map(\.value)
        let exerciseValues = meaningfulTrendPoints(exerciseSeries).map(\.value)

        let stepScore: Double = {
            guard let minimum = stepValues.min(), let maximum = stepValues.max(), maximum - minimum >= 1 else { return 0.45 }
            return min(max((steps - minimum) / (maximum - minimum), 0), 1)
        }()

        let exerciseScore: Double = {
            guard let minimum = exerciseValues.min(), let maximum = exerciseValues.max(), maximum - minimum >= 1 else { return 0.45 }
            return min(max((exercise - minimum) / (maximum - minimum), 0), 1)
        }()

        return CGFloat((stepScore * 0.7) + (exerciseScore * 0.3))
    }

    private func energyDotSize(for normalized: CGFloat) -> CGFloat {
        let size = 8 + (normalized * 3)
        if !size.isFinite {
            return 10
        }
        return min(max(size, 8), 11)
    }

    private func energyLineHeight(for normalized: CGFloat, recencyIndex: Int, totalCount: Int) -> CGFloat {
        let recencyFactor = CGFloat(recencyIndex + 1) / CGFloat(max(totalCount, 1))
        let height = 20 + (recencyFactor * 14) + (normalized * 10)
        if !height.isFinite {
            return 28
        }
        return min(max(height, 20), 40)
    }
}

private struct AmbientHRVTrendCard: View {
    let points: [AmbientHealthStore.TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Heart Rate Variability", symbol: "waveform.path.ecg", tint: .teal)

            Text("A softer read on recovery and tension through the week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = Array(meaningfulTrendPoints(points).suffix(5))

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let intensity = normalizedValue(for: point.value, in: displayPoints)
                        let pulseHeight = pulseHeight(for: intensity, recencyIndex: entry.offset, totalCount: displayPoints.count)
                        let haloWidth = max(18, pulseHeight * 0.95)
                        let isLatest = entry.offset == displayPoints.count - 1

                        VStack(spacing: 6) {
                            ZStack {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.teal.opacity(0.18 + (0.14 * intensity)),
                                                Color.teal.opacity(0.035)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 8, height: pulseHeight)
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    }
                                    .background {
                                        Capsule(style: .continuous)
                                            .fill(Color.teal.opacity(0.11))
                                            .frame(width: haloWidth, height: max(28, pulseHeight + 10))
                                            .blur(radius: 10)
                                    }
                                    .overlay(alignment: .top) {
                                        if isLatest {
                                            Image(systemName: "waveform.path.ecg")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color.teal.opacity(0.92))
                                                .padding(.top, -16)
                                        }
                                    }
                            }
                            .frame(height: 62)

                            Text("\(Int(point.value)) ms")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(isLatest ? "Latest" : shortDayLabel(for: point.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.teal.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            } else {
                Text("Not enough recent data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(weeklyTrendSummary(
                points: points,
                lowMeaning: "HRV has looked a bit lower than your recent norm, which can line up with more strain or less recovery",
                highMeaning: "HRV has looked stronger than your recent norm, which usually points to steadier recovery",
                unit: "ms",
                formatter: { Int($0).formatted() },
                includeLatest: false
            ))
            .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: .teal)
    }

    private func normalizedValue(for value: Double, in points: [AmbientHealthStore.TrendPoint]) -> CGFloat {
        let values = points.map(\.value)
        guard let minimum = values.min(), let maximum = values.max(), maximum - minimum >= 0.1 else { return 0.45 }
        let raw = (value - minimum) / (maximum - minimum)
        return CGFloat(min(max(raw, 0), 1))
    }

    private func pulseHeight(for normalized: CGFloat, recencyIndex: Int, totalCount: Int) -> CGFloat {
        let recencyFactor = CGFloat(recencyIndex + 1) / CGFloat(max(totalCount, 1))
        let height = 20 + (recencyFactor * 12) + (normalized * 8)
        if !height.isFinite {
            return 28
        }
        return min(max(height, 20), 40)
    }
}

private struct AmbientSleepDurationCard: View {
    let points: [AmbientHealthStore.TrendPoint]

    private let tint = Color(red: 0.73, green: 0.56, blue: 0.88)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Sleep Duration", symbol: "bed.double.fill", tint: tint)

            Text("A quiet weekly picture of how much sleep has landed each night.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = Array(meaningfulTrendPoints(points).suffix(5))

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let intensity = normalizedValue(for: point.value, in: displayPoints)
                        let moonSize = moonSize(for: intensity, recencyIndex: entry.offset, totalCount: displayPoints.count)
                        let glowSize = max(26, moonSize * 2.2)
                        let drift = moonDrift(for: intensity)
                        let isLatest = entry.offset == displayPoints.count - 1

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                tint.opacity(0.18 + (0.10 * intensity)),
                                                tint.opacity(0.06),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 1,
                                            endRadius: glowSize / 2
                                        )
                                    )
                                    .frame(width: glowSize, height: glowSize)
                                    .blur(radius: 9)

                                Image(systemName: isLatest ? "moon.zzz.fill" : "moon.stars.fill")
                                    .font(.system(size: moonSize, weight: .semibold))
                                    .foregroundStyle(tint.opacity(isLatest ? 0.96 : 0.84))
                                    .offset(x: drift * 0.35)

                                if !isLatest {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 7, weight: .semibold))
                                        .foregroundStyle(tint.opacity(0.70))
                                        .offset(x: moonSize * 0.42, y: -moonSize * 0.34)
                                }
                            }
                            .frame(height: 52)

                            Text(String(format: "%.1f h", point.value))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(isLatest ? "Latest" : shortDayLabel(for: point.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    tint.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            } else {
                Text("Not enough recent data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(weeklyTrendSummary(
                points: points,
                lowMeaning: "sleep duration has looked lighter than your recent norm",
                highMeaning: "sleep duration has looked fuller than your recent norm",
                unit: "h",
                formatter: { String(format: "%.1f", $0) },
                includeLatest: false
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: tint)
    }

    private func normalizedValue(for value: Double, in points: [AmbientHealthStore.TrendPoint]) -> CGFloat {
        let values = points.map(\.value)
        guard let minimum = values.min(), let maximum = values.max(), maximum - minimum >= 0.1 else { return 0.45 }
        let raw = (value - minimum) / (maximum - minimum)
        return CGFloat(min(max(raw, 0), 1))
    }

    private func moonSize(for normalized: CGFloat, recencyIndex: Int, totalCount: Int) -> CGFloat {
        let recencyFactor = CGFloat(recencyIndex + 1) / CGFloat(max(totalCount, 1))
        let size = 12 + (recencyFactor * 4) + (normalized * 1.5)
        if !size.isFinite {
            return 14
        }
        return min(max(size, 12), 17)
    }

    private func moonDrift(for normalized: CGFloat) -> CGFloat {
        let drift = -2 + (normalized * 2.5)
        if !drift.isFinite {
            return -1
        }
        return min(max(drift, -2), 1.5)
    }
}

private struct AmbientHeartTrendCard: View {
    let points: [AmbientHealthStore.TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Resting Heart Rate", symbol: "heart.fill", tint: Color(red: 1.0, green: 0.20, blue: 0.22))

            Text("A softer view of whether your system has looked calmer or more activated.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = Array(meaningfulTrendPoints(points).suffix(5))

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let intensity = normalizedIntensity(for: point.value, in: displayPoints)
                        let heartSize = safeHeartSize(for: intensity, recencyIndex: entry.offset, totalCount: displayPoints.count)
                        let glowColor = heartColor(for: intensity)
                        let haloSize = max(24, heartSize * 2.15)
                        let isLatest = entry.offset == displayPoints.count - 1

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                glowColor.opacity(0.24 + (0.12 * intensity)),
                                                glowColor.opacity(0.08 + (0.06 * intensity)),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 1,
                                            endRadius: max(18, haloSize / 2)
                                        )
                                    )
                                    .frame(width: haloSize, height: haloSize)
                                    .blur(radius: 7)

                                Circle()
                                    .fill(Color.white.opacity(0.04))
                                    .frame(width: max(20, heartSize * 1.55), height: max(20, heartSize * 1.55))

                                Image(systemName: "heart.fill")
                                    .font(.system(size: heartSize, weight: .semibold))
                                    .foregroundStyle(glowColor)
                                    .shadow(color: glowColor.opacity(0.24), radius: 8, y: 0)
                                    .scaleEffect(isLatest ? 1.03 : 1.0)
                            }
                            .frame(height: 42 + heartSize)

                            Text("\(Int(point.value)) bpm")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(isLatest ? "Latest" : shortDayLabel(for: point.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color(red: 1.0, green: 0.16, blue: 0.18).opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            } else {
                Text("Not enough recent data yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(inverseWeeklyTrendSummary(
                points: points,
                lowMeaning: "your resting rhythm has looked calmer than your weekly norm",
                highMeaning: "your resting rhythm has looked a little more activated than your weekly norm",
                unit: "bpm",
                formatter: { Int($0).formatted() },
                includeLatest: false
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: Color(red: 1.0, green: 0.20, blue: 0.22))
    }

    private func normalizedIntensity(for value: Double, in points: [AmbientHealthStore.TrendPoint]) -> CGFloat {
        guard let range = restingHeartRateRange(for: points) else { return 0.45 }
        if range.upperBound - range.lowerBound < 1 {
            return 0.45
        }

        // Clamp hard here so tiny ranges or weird data never produce invalid symbol sizes.
        let raw = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        if !raw.isFinite {
            return 0.45
        }
        return CGFloat(min(max(raw, 0), 1))
    }

    private func safeHeartSize(for normalized: CGFloat, recencyIndex: Int, totalCount: Int) -> CGFloat {
        // Recency does most of the visual work; intensity adds just enough variation to show the week
        // without making the trail look noisy or clinical.
        let recencyFactor = CGFloat(recencyIndex + 1) / CGFloat(max(totalCount, 1))
        let size = 10 + (recencyFactor * 5) + (normalized * 2.5)
        if !size.isFinite {
            return 14
        }
        return min(max(size, 12), 17.5)
    }

    private func heartColor(for normalized: CGFloat) -> Color {
        let clamped = min(max(normalized, 0), 1)
        return Color(
            red: 1.0,
            green: 0.14 + (0.14 * Double(1 - clamped)),
            blue: 0.16 + (0.08 * Double(1 - clamped))
        )
    }
}

private struct AmbientSleepQualitySummaryCard: View {
    let points: [AmbientHealthStore.SleepStageTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Sleep Quality", symbol: "moon.stars.fill", tint: .blue)

            Text("A simpler read on whether sleep looked restorative, fragmented, or mixed over the last week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let latest = points.last {
                let corePercent = max(0, 100 - latest.deepPercent - latest.remPercent)
                HStack(spacing: 12) {
                    AmbientMiniMetric(title: "Core", value: "\(Int(corePercent))%")
                    AmbientMiniMetric(title: "Deep", value: "\(Int(latest.deepPercent))%")
                    AmbientMiniMetric(title: "REM", value: "\(Int(latest.remPercent))%")
                    AmbientMiniMetric(title: "Awake", value: "\(Int(latest.awakePercent))%")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(sleepStageSummary(points: points))
                    .font(.body)

                if let latest = points.last {
                    let corePercent = max(0, 100 - latest.deepPercent - latest.remPercent)
                    Text("Last night: \(String(format: "%.1f", latest.totalSleepHours)) h sleep, Core \(Int(corePercent))%, Deep \(Int(latest.deepPercent))%, REM \(Int(latest.remPercent))%, Awake \(Int(latest.awakePercent))%")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AmbientChartToggleLabel: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint.opacity(0.95))

            Spacer()
        }
    }
}

private struct AmbientCardHeader: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        // Shared header so the trend cards feel related without getting overly decorative.
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.11))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle()
                            .fill(tint.opacity(0.05))
                            .blur(radius: 5)
                    }

                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.92))
            }

            Text(title)
                .font(.headline)
        }
    }
}

private struct AmbientSectionHeader: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        // Same idea as the card header, but used in Explanation where the symbol should stay subtle.
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle()
                            .fill(tint.opacity(0.08))
                            .blur(radius: 6)
                    }

                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.92))
            }

            Text(title)
                .font(.headline)
        }
    }
}

private struct AmbientMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AmbientExplanationSignalRow: View {
    let chips: [ExplanationSignalChip]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Relevant Signals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(chips) { chip in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(tint.opacity(0.12))
                                .frame(width: 24, height: 24)

                            Image(systemName: chip.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(tint.opacity(0.92))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chip.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(chip.value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(.top, 4)
    }
}

private func shortDayLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter.string(from: date)
}

private func weeklyAverage(for points: [AmbientHealthStore.TrendPoint]) -> Double? {
    let values = points.map(\.value).filter { $0 > 0 }
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

private func meaningfulTrendPoints(_ points: [AmbientHealthStore.TrendPoint]) -> [AmbientHealthStore.TrendPoint] {
    points.filter { $0.value > 0 }
}

private func latestMeaningfulPoint(in points: [AmbientHealthStore.TrendPoint]) -> AmbientHealthStore.TrendPoint? {
    meaningfulTrendPoints(points).last
}

private func abbreviatedSteps(_ value: Double) -> String {
    let steps = Int(value)
    if steps >= 10_000 {
        return String(format: "%.1fk", Double(steps) / 1_000)
    }
    if steps >= 1_000 {
        return "\(steps / 1_000)k"
    }
    return steps.formatted()
}

private func restingHeartRateRange(for points: [AmbientHealthStore.TrendPoint]) -> ClosedRange<Double>? {
    let values = points.map(\.value).filter { $0 > 0 }
    guard let min = values.min(), let max = values.max() else { return nil }
    return min...max
}

private func symbolForState(_ state: ColorHealthState) -> String {
    switch state {
    case .blue:
        return "sparkles"
    case .green:
        return "leaf.fill"
    case .yellow:
        return "sun.min.fill"
    case .purple:
        return "bolt.fill"
    case .gray:
        return "circle.fill"
    case .red:
        return "flame.fill"
    case .orange:
        return "moon.zzz.fill"
    }
}

private func weeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    includeLatest: Bool = true
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "Not enough recent data yet."
    }

    let delta = latest - average
    let latestText = "\(formatter(latest)) \(unit)"

    if abs(delta) < max(average * 0.08, unit == "h" ? 0.35 : 2) {
        return includeLatest ? "This week looks fairly steady. Latest: \(latestText)." : "This week looks fairly steady."
    } else if delta > 0 {
        return includeLatest ? "Lately \(highMeaning). Latest: \(latestText)." : "Lately \(highMeaning)."
    } else {
        return includeLatest ? "Lately \(lowMeaning). Latest: \(latestText)." : "Lately \(lowMeaning)."
    }
}

private func calmerWeeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    includeLatest: Bool = true
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "There is not enough recent data to describe this gently yet."
    }

    let delta = latest - average
    if abs(delta) < max(average * 0.08, unit == "h" ? 0.35 : 2) {
        return "This part of the week looks fairly steady."
    } else if delta > 0 {
        return highMeaning
    } else {
        return lowMeaning
    }
}

private func inverseWeeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    includeLatest: Bool = true
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "Not enough recent data yet."
    }

    let delta = latest - average
    let latestText = "\(formatter(latest)) \(unit)"

    if abs(delta) < max(average * 0.06, 2) {
        return includeLatest ? "This week looks fairly steady. Latest: \(latestText)." : "This week looks fairly steady."
    } else if delta > 0 {
        return includeLatest ? "Lately \(highMeaning). Latest: \(latestText)." : "Lately \(highMeaning)."
    } else {
        return includeLatest ? "Lately \(lowMeaning). Latest: \(latestText)." : "Lately \(lowMeaning)."
    }
}

private func calmerInverseWeeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    includeLatest: Bool = true
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "There is not enough recent data to describe this gently yet."
    }

    let delta = latest - average
    if abs(delta) < max(average * 0.06, 2) {
        return "This part of the week looks fairly steady."
    } else if delta > 0 {
        return highMeaning
    } else {
        return lowMeaning
    }
}

private func combinedEnergySummary(
    steps: [AmbientHealthStore.TrendPoint],
    exerciseMinutes: [AmbientHealthStore.TrendPoint]
) -> String {
    guard let avgSteps = weeklyAverage(for: steps), let avgExercise = weeklyAverage(for: exerciseMinutes) else {
        return "Not enough recent data yet."
    }

    let latestSteps = latestMeaningfulPoint(in: steps)?.value ?? avgSteps
    let latestExercise = latestMeaningfulPoint(in: exerciseMinutes)?.value ?? avgExercise
    let stepShift = latestSteps - avgSteps
    let exerciseShift = latestExercise - avgExercise

    if stepShift > max(avgSteps * 0.12, 900) || exerciseShift > max(avgExercise * 0.18, 8) {
        return "Your recent energy rhythm looks a little more active than your weekly norm."
    } else if stepShift < -max(avgSteps * 0.12, 900) || exerciseShift < -max(avgExercise * 0.18, 8) {
        return "Your recent energy rhythm looks softer than your weekly norm."
    } else {
        return "Your recent energy rhythm looks pretty consistent with the rest of the week."
    }
}

private func calmerEnergySummary(
    steps: [AmbientHealthStore.TrendPoint],
    exerciseMinutes: [AmbientHealthStore.TrendPoint]
) -> String {
    guard let avgSteps = weeklyAverage(for: steps), let avgExercise = weeklyAverage(for: exerciseMinutes) else {
        return "There is not enough recent data to describe movement gently yet."
    }

    let latestSteps = latestMeaningfulPoint(in: steps)?.value ?? avgSteps
    let latestExercise = latestMeaningfulPoint(in: exerciseMinutes)?.value ?? avgExercise
    let stepShift = latestSteps - avgSteps
    let exerciseShift = latestExercise - avgExercise

    if stepShift > max(avgSteps * 0.12, 900) || exerciseShift > max(avgExercise * 0.18, 8) {
        return "Movement looks a little more present than your recent norm."
    } else if stepShift < -max(avgSteps * 0.12, 900) || exerciseShift < -max(avgExercise * 0.18, 8) {
        return "Movement looks a little quieter than your recent norm."
    } else {
        return "Movement looks fairly consistent with the rest of the week."
    }
}

private func sleepStageSummary(points: [AmbientHealthStore.SleepStageTrendPoint]) -> String {
    guard !points.isEmpty else {
        return "Not enough recent sleep-stage data yet."
    }

    let averageCore = points.map { max(0, 100 - $0.deepPercent - $0.remPercent) }.reduce(0, +) / Double(points.count)
    let averageDeep = points.map(\.deepPercent).reduce(0, +) / Double(points.count)
    let averageREM = points.map(\.remPercent).reduce(0, +) / Double(points.count)
    let averageAwake = points.map(\.awakePercent).reduce(0, +) / Double(points.count)

    if averageDeep >= 15, averageREM >= 19, averageAwake <= 11 {
        return "Sleep has looked fairly restorative this week, with a healthy balance of core, deep, and REM sleep plus limited overnight awake time."
    }

    if averageAwake >= 14 {
        return "Sleep has looked more fragmented this week, with higher awake time overnight pulling against recovery."
    }

    if averageDeep < 11 || averageREM < 16 {
        return "Sleep has looked lighter than usual this week, with more time staying in core sleep and less time reaching deeper restorative stages."
    }

    if averageCore >= 66 {
        return "Sleep has leaned heavily on core sleep this week. That is not necessarily bad, but it can feel less restorative if deep and REM sleep stay modest."
    }

    return "Sleep quality looks mixed this week: not especially poor, but not strongly restorative either."
}

private func calmerSleepStageSummary(points: [AmbientHealthStore.SleepStageTrendPoint]) -> String {
    guard !points.isEmpty else {
        return "There is not enough recent sleep-stage data to describe this gently yet."
    }

    let averageCore = points.map { max(0, 100 - $0.deepPercent - $0.remPercent) }.reduce(0, +) / Double(points.count)
    let averageDeep = points.map(\.deepPercent).reduce(0, +) / Double(points.count)
    let averageREM = points.map(\.remPercent).reduce(0, +) / Double(points.count)
    let averageAwake = points.map(\.awakePercent).reduce(0, +) / Double(points.count)

    if averageDeep >= 15, averageREM >= 19, averageAwake <= 11 {
        return "Sleep quality looks fairly supportive this week."
    }

    if averageAwake >= 14 {
        return "Sleep quality looks a little more interrupted this week."
    }

    if averageDeep < 11 || averageREM < 16 {
        return "Sleep quality looks a little lighter than usual this week."
    }

    if averageCore >= 66 {
        return "Sleep looks a little more core-heavy this week, which can feel less restorative."
    }

    return "Sleep quality looks mixed, but not strongly pulled in one direction."
}

private struct AmbientInsightHistoryTrail: View {
    let history: [ColorHealthState]

    var body: some View {
        // lightweight memory of recent state outputs
        HStack(spacing: 4) {
            ForEach(Array(history.enumerated()), id: \.offset) { entry in
                let isLatest = entry.offset == history.count - 1

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(entry.element.color.opacity(isLatest ? 0.85 : 0.45))
                    .frame(width: isLatest ? 20 : 14, height: 6)
            }
        }
    }
}

struct AmbientSettingsView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @Binding var stressSensitivity: Double
    @Binding var movementSensitivity: Double
    @Binding var recoverySensitivity: Double
    @Binding var overallResponsiveness: Double
    @Binding var calmerModeEnabled: Bool
    let resetToDefault: () -> Void
    @State private var showsAccessibilitySection = false
    @State private var showsHealthKitSection = false
    @State private var showsStatePreviewSection = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                    Spacer()

                    Label("Scroll for more", systemImage: "arrow.up.and.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Each slider below changes how easily a specific mood shows up. Move it up if you want that mood to appear more easily. Move it down if the app is calling that mood too often.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                AmbientSensitivityControlCard(
                    preset: sensitivityPresetBinding,
                    selectedPreset: healthStore.sensitivityPreset,
                    stressSensitivity: $stressSensitivity,
                    movementSensitivity: $movementSensitivity,
                    recoverySensitivity: $recoverySensitivity,
                    overallResponsiveness: $overallResponsiveness,
                    calmerModeEnabled: calmerModeEnabled,
                    presetDescription: presetDescription(for: healthStore.sensitivityPreset),
                    resetToDefault: resetToDefault
                )

                DisclosureGroup(isExpanded: $showsAccessibilitySection) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Use this if bright glows, fast motion, or agitated states feel like too much. It softens the visual layer without changing your actual health state or the mood logic underneath.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        AmbientAccessibilityToggleCard(
                            title: "Calmer Mode",
                            subtitle: "Reduce glow, motion, and visual intensity across the app.",
                            isOn: $calmerModeEnabled
                        )

                        Text(calmerModeEnabled
                             ? "Calmer Mode is on. The app keeps the same health read, but tones down the aura, motion, and stronger distressed visuals."
                             : "Calmer Mode is off. The app uses its full ambient motion and brightness range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility")
                            .font(.headline)

                        Text(calmerModeEnabled
                             ? "Calmer Mode is on. The app is using a softer visual presentation."
                             : "Expand for a lower-intensity visual mode that is easier to look at during anxious moments.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .ambientPanel(tint: Color(red: 0.49, green: 0.72, blue: 0.96))

                DisclosureGroup(isExpanded: $showsStatePreviewSection) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Preview a mood state on the phone and read the kind of health pattern that would usually create it. This does not change live data or send a fake state out.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(ColorHealthState.allCases) { state in
                                Button {
                                    healthStore.setPreviewState(healthStore.previewState == state ? nil : state)
                                } label: {
                                    Text(state.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(healthStore.previewState == state ? .primary : .secondary)
                                        .padding(.horizontal, 12)
                                        .frame(height: 34)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(healthStore.previewState == state ? state.color.opacity(0.22) : Color.white.opacity(0.08))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let previewState = healthStore.previewState {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(previewState.color)
                                        .frame(width: 8, height: 8)

                                    Text("Previewing \(previewState.title)")
                                        .font(.subheadline.weight(.semibold))
                                }

                                Text(calmerModeEnabled ? calmerStateExampleScenario(for: previewState) : patternInsight(for: previewState, snapshot: nil))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                

                                Text(sensitivityEffectLine(for: previewState, profile: healthStore.sensitivityProfile))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.primary.opacity(0.88))

                                Button("Return to Live State") {
                                    healthStore.setPreviewState(nil)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("State Preview")
                            .font(.headline)

                        Text(healthStore.previewState == nil ? "Expand to test how each mood state looks and read an example health pattern for it." : "Previewing \(healthStore.previewState?.title ?? "").")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .ambientPanel(tint: healthStore.previewState?.color ?? Color(red: 0.49, green: 0.72, blue: 0.96))

                // HealthKit status lives here so operational/debug information stays out of the more atmospheric home screen
                DisclosureGroup(isExpanded: $showsHealthKitSection) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(healthStore.authorizationState.title)
                            .font(.subheadline.weight(.semibold))

                        Text(healthStore.authorizationSummaryLine)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(healthStore.authorizationState.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !healthStore.signalEntries.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                                ForEach(healthStore.signalEntries) { entry in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(statusColor(for: entry.status))
                                            .frame(width: 8, height: 8)

                                        Text("\(entry.label): \(entry.status.title)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        if healthStore.signalEntries.isEmpty {
                            Text("Once Health is connected and refreshed, this list will show which health signals have recent readable samples.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let sleepStages = healthStore.latestSnapshot?.sleepStages {
                            Text(sleepStages.summaryLine)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HealthKit")
                            .font(.headline)

                        Text(healthKitSectionSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .ambientPanel(tint: Color.white)
            }
            .padding(.bottom, 140)
        }
        .scrollIndicators(.visible)
        .safeAreaPadding(.bottom, 8)
    }

    private var sensitivityPresetBinding: Binding<AmbientHealthStore.SensitivityPreset> {
        Binding(
            get: { healthStore.sensitivityPreset },
            set: { preset in
                healthStore.applySensitivityPreset(preset)
                // Mirror the store back into the sliders so presets and manual controls stay in sync.
                let profile = healthStore.sensitivityProfile
                stressSensitivity = profile.stress
                movementSensitivity = profile.movement
                recoverySensitivity = profile.recovery
                overallResponsiveness = profile.overall
            }
        )
    }

    private func presetDescription(for preset: AmbientHealthStore.SensitivityPreset) -> String {
        switch preset {
        case .gentle:
            return "This waits for stronger evidence before a mood changes."
        case .recommended:
            return "This is the balanced starting point for most people."
        case .responsive:
            return "This lets moods show up sooner if the app feels too muted."
        case .custom:
            return "You changed the sliders yourself. Each one only affects the mood written under it."
        }
    }

    private var healthKitSectionSummary: String {
        "\(healthStore.authorizationState.title). Expand to inspect available signals and connection details."
    }

    private func statusColor(for status: AmbientHealthStore.HealthSignalStatus) -> Color {
        switch status {
        case .readable:
            return .green
        case .noRecentData:
            return .yellow
        case .awaitingConnection:
            return .gray
        }
    }
}

private struct AmbientSensitivityControlCard: View {
    @Binding var preset: AmbientHealthStore.SensitivityPreset
    let selectedPreset: AmbientHealthStore.SensitivityPreset
    @Binding var stressSensitivity: Double
    @Binding var movementSensitivity: Double
    @Binding var recoverySensitivity: Double
    @Binding var overallResponsiveness: Double
    let calmerModeEnabled: Bool
    let presetDescription: String
    let resetToDefault: () -> Void
    @State private var showsSensitivityGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood Sensitivity")
                        .font(.headline)

                    Text(calmerModeEnabled
                         ? "Use these only if one mood feels clearly too present or not present enough."
                         : "Each slider changes how easily that health state appears. Move it up if the app is missing that state. Move it down if the app is showing that state too often.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    resetToDefault()
                } label: {
                    Text("Recommended")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(AmbientHealthStore.SensitivityPreset.allCases.filter { $0 != .custom }) { item in
                    Button {
                        preset = item
                    } label: {
                        Text(item.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedPreset == item ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                Capsule()
                                    .fill(selectedPreset == item ? Color.white.opacity(0.58) : Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(presetDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            DisclosureGroup(isExpanded: $showsSensitivityGuide) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calmerModeEnabled
                         ? "Move a slider up if you want that mood to show more easily. Move it down if it is showing more than feels right."
                         : "Move a slider up if you want that health state to show more easily. Move it down if the app is showing that state too often.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(calmerModeEnabled
                         ? "Use the small line under each slider as a rough guide. It shows the kind of sleep, movement, or recovery pattern that slider is reacting to."
                         : "Use the small line under each slider as a rough guide. It shows the kind of sleep, movement, or recovery pattern that slider is reacting to.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(calmerModeEnabled
                         ? "Low Energy mostly follows movement. Sleep + Recovery mostly follows sleep and recovery, especially for restored or drained states."
                         : "Low Energy mostly follows movement. Restored / Drained mostly follows sleep and recovery, especially when that story is stronger than movement.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(calmerModeEnabled
                         ? "Overall Sensitivity changes how quickly the whole app reacts. Lower feels steadier. Higher feels quicker."
                         : "Overall Sensitivity changes how quickly any mood can replace another. Lower feels steadier. Higher feels more reactive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } label: {
                Text("Quick guide")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .ambientSubpanel(tint: Color.white)

            if calmerModeEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    AmbientSensitivitySliderRow(
                        title: "Stressed",
                        subtitle: "Lower if stressed shows too often. Raise if stressed is being missed.",
                        tint: ColorHealthState.purple.color,
                        lowLabel: "Less",
                        highLabel: "More",
                        value: $stressSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                    AmbientSensitivitySliderRow(
                        title: "Low Energy",
                        subtitle: "Lower if low movement is affecting the result too much.",
                        tint: ColorHealthState.yellow.color,
                        lowLabel: "Less",
                        highLabel: "More",
                        value: $movementSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                    AmbientSensitivitySliderRow(
                        title: "Sleep + Recovery",
                        subtitle: "Lower if recovery is affecting the result too much.",
                        tint: ColorHealthState.orange.color,
                        secondaryTint: ColorHealthState.blue.color,
                        lowLabel: "Less",
                        highLabel: "More",
                        value: $recoverySensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                    AmbientSensitivitySliderRow(
                        title: "Overall Sensitivity",
                        subtitle: "Lower if every mood changes too easily. Raise if the whole app feels muted.",
                        tint: Color(red: 0.49, green: 0.72, blue: 0.96),
                        lowLabel: "Calmer",
                        highLabel: "Quicker",
                        value: $overallResponsiveness,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    AmbientSensitivitySliderRow(
                        title: "Stressed",
                        subtitle: "Use this if the app is missing stressed moments, or calling stressed too often.",
                        tint: ColorHealthState.purple.color,
                        lowLabel: "Shows less",
                        highLabel: "Shows more",
                        value: $stressSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                    AmbientSensitivitySliderRow(
                        title: "Low Energy",
                        subtitle: "Use this for low movement and quiet momentum days.",
                        tint: ColorHealthState.yellow.color,
                        lowLabel: "Shows less",
                        highLabel: "Shows more",
                        value: $movementSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                    AmbientSensitivitySliderRow(
                        title: "Restored / Drained",
                        subtitle: "Use this for sleep and recovery states, especially Restored and Drained.",
                        tint: ColorHealthState.orange.color,
                        secondaryTint: ColorHealthState.blue.color,
                        lowLabel: "Matters less",
                        highLabel: "Matters more",
                        value: $recoverySensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                    AmbientSensitivitySliderRow(
                        title: "Overall Sensitivity",
                        subtitle: "Use this only if every mood feels too muted overall, or if the whole app changes too easily.",
                        tint: Color(red: 0.49, green: 0.72, blue: 0.96),
                        lowLabel: "Slower",
                        highLabel: "Faster",
                        value: $overallResponsiveness,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                }
            }

            Text(calmerModeEnabled
                 ? "If you change something here, adjust only one slider and then give it a little time."
                 : "Change one slider at a time, then use the app for a bit before changing another.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Workout-aware stress handling is still on. Exercise only softens stress reads during active workouts and a short recovery window after.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .ambientPanel(tint: Color(red: 0.49, green: 0.72, blue: 0.96))
    }
}

private struct AmbientAccessibilityToggleCard: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.49, green: 0.72, blue: 0.96))
        }
        .padding(16)
        .ambientSubpanel(tint: Color(red: 0.49, green: 0.72, blue: 0.96))
    }
}

private struct AmbientSensitivitySliderRow: View {
    let title: String
    let subtitle: String
    let tint: Color
    var secondaryTint: Color? = nil
    let lowLabel: String
    let highLabel: String
    @Binding var value: Double
    let overallValue: Double
    let calmerModeEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(levelLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(sliderTint)
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Text(lowLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(highLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)

                Slider(value: $value, in: 0...1)
                    .tint(sliderTint)

                AmbientSensitivityScale(
                    labels: scaleLabels,
                    currentLabel: currentScaleLabel,
                    progress: value,
                    tint: sliderTint
                )

                Text(scaleLegend)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .ambientSubpanel(tint: sliderTint)
    }

    private var sliderTint: Color {
        let clamped = min(max(value, 0), 1)
        if let secondaryTint {
            if clamped < 0.5 {
                let progress = clamped / 0.5
                return softenedColor(from: secondaryTint, amount: 1 - progress)
            } else {
                let progress = (clamped - 0.5) / 0.5
                return softenedColor(from: tint, amount: 1 - progress)
            }
        }
        return softenedColor(from: tint, amount: 1 - clamped)
    }

    private var levelLabel: String {
        switch value {
        case ..<0.30:
            return "Low"
        case ..<0.45:
            return "Light"
        case ..<0.62:
            return "Balanced"
        case ..<0.78:
            return "Stronger"
        default:
            return "Max"
        }
    }

    private var scaleLabels: [String] {
        switch title {
        case "Stressed":
            return ["86 bpm / 26 ms", "84 bpm / 28 ms", "82 bpm / 30 ms", "80 bpm / 31 ms", "78 bpm / 33 ms"]
        case "Low Energy":
            return ["1.6k / 8 min", "2.0k / 10 min", "2.3k / 13 min", "2.7k / 15 min", "3.0k / 18 min"]
        case "Restored / Drained", "Sleep + Recovery":
            return ["5.4h / 20 ms", "5.7h / 22 ms", "5.9h / 24 ms", "6.1h / 26 ms", "6.4h / 28 ms"]
        case "Overall Sensitivity":
            return calmerModeEnabled
                ? ["waits", "gentle", "balanced", "quick", "sooner"]
                : ["stricter", "gentle", "balanced", "reactive", "sooner"]
        default:
            return ["", "", "", "", ""]
        }
    }

    private var currentScaleLabel: String {
        let clamped = min(max(value, 0), 1)
        switch title {
        case "Stressed":
            let resting = Int(86 + (78 - 86) * clamped)
            let hrv = Int(26 + (33 - 26) * clamped)
            return "\(resting) bpm / \(hrv) ms"
        case "Low Energy":
            let steps = Int(1600 + (3000 - 1600) * clamped)
            let exercise = Int(8 + (18 - 8) * clamped)
            return "\(String(format: "%.1fk", Double(steps) / 1000)) / \(exercise) min"
        case "Restored / Drained", "Sleep + Recovery":
            let sleep = 5.4 + (6.4 - 5.4) * clamped
            let hrv = Int(20 + (28 - 20) * clamped)
            return "\(String(format: "%.1f", sleep))h / \(hrv) ms"
        case "Overall Sensitivity":
            switch clamped {
            case ..<0.20:
                return "very steady"
            case ..<0.40:
                return "steadier"
            case ..<0.60:
                return "balanced"
            case ..<0.80:
                return "more reactive"
            default:
                return "most reactive"
            }
        default:
            return ""
        }
    }

    private var scaleLegend: String {
        switch title {
        case "Stressed":
            return "On this line, bpm means resting heart rate and ms means heart-rate variability."
        case "Low Energy":
            return "On this line, the first number is steps and min means exercise minutes."
        case "Restored / Drained", "Sleep + Recovery":
            return "On this line, h means hours of sleep and ms means heart-rate variability."
        case "Overall Sensitivity":
            return "This line shows how steady or reactive the whole app is overall."
        default:
            return ""
        }
    }

    private func softenedColor(from base: Color, amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        let ui = UIColor(base)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return base.opacity(0.25 + ((1 - clamped) * 0.75))
        }

        let mix = CGFloat(clamped * 0.78)
        let softenedRed = red + ((1 - red) * mix)
        let softenedGreen = green + ((1 - green) * mix)
        let softenedBlue = blue + ((1 - blue) * mix)

        return Color(
            .sRGB,
            red: Double(softenedRed),
            green: Double(softenedGreen),
            blue: Double(softenedBlue),
            opacity: 1
        )
    }
}

private struct AmbientSensitivityScale: View {
    let labels: [String]
    let currentLabel: String
    let progress: Double
    let tint: Color
    private let bubbleWidth: CGFloat = 108

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let clamped = min(max(progress, 0), 1)
                let dotCenterX = max(0, min(width, width * clamped))
                let bubbleOriginX = max(0, min(width - bubbleWidth, dotCenterX - (bubbleWidth / 2)))

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(height: 3)
                        .offset(y: 18)

                    ForEach(Array(labels.indices), id: \.self) { index in
                        let tickX = width * CGFloat(index) / CGFloat(max(labels.count - 1, 1))
                        Capsule(style: .continuous)
                            .fill(tint.opacity(index == 2 ? 0.55 : 0.28))
                            .frame(width: index == 2 ? 14 : 8, height: 3)
                            .offset(x: max(0, tickX - (index == 2 ? 7 : 4)), y: 18)
                    }

                    Text(currentLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(width: bubbleWidth)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.72), in: Capsule())
                        .offset(x: bubbleOriginX, y: 0)

                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        }
                        .offset(x: dotCenterX - 4, y: 21)
                }
            }
            .frame(height: 30)

            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(labels.indices), id: \.self) { index in
                    Text(labels[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct AmbientPanelModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                tint.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.9)
                    )
            )
    }
}

private struct AmbientSubpanelModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                tint.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                    )
            )
    }
}

private extension View {
    func ambientPanel(tint: Color) -> some View {
        modifier(AmbientPanelModifier(tint: tint))
    }

    func ambientSubpanel(tint: Color) -> some View {
        modifier(AmbientSubpanelModifier(tint: tint))
    }
}

struct AmbientBottomBar: View {
    @Binding var selectedTab: AmbientTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AmbientTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabSymbolName(for: tab))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)

                        Text(tab.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
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
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
