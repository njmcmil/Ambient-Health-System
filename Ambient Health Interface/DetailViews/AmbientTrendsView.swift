import SwiftUI

/// The visible Trends charts should stay anchored to one true 7-day window.
private let ambientWeeklyVisibleDays = 7

/// Shows trend context behind the current state without turning the experience
/// into a dense clinical dashboard.
struct AmbientTrendsView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @AppStorage("anxietyCalmerMode") private var calmerModeEnabled = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trends")
                    .font(.title2.weight(.semibold))

                Text("A lighter weekly view of the last 7 days of signals behind your current mood read. This is a wellness interpretation, not a diagnosis.")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.78))

                if let previewState = healthStore.previewState {
                    AmbientPreviewStateCard(
                        state: previewState,
                        calmerModeEnabled: calmerModeEnabled
                    )
                } else if let trendReport = healthStore.trendReport {
                    if calmerModeEnabled {
                        AmbientCalmerTrendsView(
                            trendReport: trendReport,
                            currentState: healthStore.displayedState,
                            baseline: healthStore.baselineSummary
                        )
                    } else {
                        AmbientWeeklySummaryCard(
                            trendReport: trendReport,
                            currentState: healthStore.displayedState,
                            baseline: healthStore.baselineSummary
                        )
                        AmbientHRVTrendCard(
                            points: trendReport.heartRateVariability,
                            baseline: healthStore.baselineSummary?.heartRateVariability
                        )
                        AmbientHeartTrendCard(
                            points: trendReport.restingHeartRate,
                            baseline: healthStore.baselineSummary?.restingHeartRate
                        )
                        AmbientEnergyRhythmCard(
                            steps: trendReport.steps,
                            exerciseMinutes: trendReport.exerciseMinutes
                        )
                        AmbientSleepDurationCard(
                            points: trendReport.sleepHours,
                            latestSleepPoint: trendReport.latestSleepStage,
                            baseline: healthStore.baselineSummary?.sleepHours
                        )
                        AmbientSleepQualitySummaryCard(
                            points: trendReport.sleepStages,
                            latestSleepPoint: trendReport.latestSleepStage
                        )
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

private struct AmbientCalmerTrendsView: View {
    let trendReport: AmbientHealthStore.TrendReport
    let currentState: ColorHealthState
    let baseline: AmbientHealthStore.BaselineSummary?

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
                    includeLatest: false,
                    baseline: baseline?.heartRateVariability
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
                    includeLatest: false,
                    baseline: baseline?.restingHeartRate
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
                    includeLatest: false,
                    baseline: baseline?.sleepHours
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

private struct AmbientWeeklySummaryCard: View {
    let trendReport: AmbientHealthStore.TrendReport
    let currentState: ColorHealthState
    let baseline: AmbientHealthStore.BaselineSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "This Week", symbol: "calendar.day.timeline.leading", tint: currentState.color)

            Text("The mood read for this week is \(currentState.title.lowercased()). These are the strongest weekly themes behind it.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                AmbientSummaryRow(
                    title: "Sleep",
                    detail: weeklyTrendSummary(
                        points: trendReport.sleepHours,
                        lowMeaning: "you've slept less than your recent norm",
                        highMeaning: "you've slept more than your recent norm",
                        unit: "h",
                        formatter: { String(format: "%.1f", $0) },
                        includeLatest: false,
                        baseline: baseline?.sleepHours
                    )
                )
                AmbientSummaryRow(
                    title: "Recovery",
                    detail: weeklyTrendSummary(
                        points: trendReport.heartRateVariability,
                        lowMeaning: "recovery has looked softer",
                        highMeaning: "recovery has looked stronger",
                        unit: "ms",
                        formatter: { Int($0).formatted() },
                        averageLabel: "Weekly HRV average",
                        includeLatest: false,
                        baseline: baseline?.heartRateVariability
                    )
                )
                AmbientSummaryRow(
                    title: "Calm Load",
                    detail: inverseWeeklyTrendSummary(
                        points: trendReport.restingHeartRate,
                        lowMeaning: "your system has looked calmer",
                        highMeaning: "your system has looked more activated",
                        unit: "bpm",
                        formatter: { Int($0).formatted() },
                        averageLabel: "Weekly resting heart rate average",
                        includeLatest: false,
                        baseline: baseline?.restingHeartRate
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

private struct AmbientEnergyRhythmCard: View {
    let steps: [AmbientHealthStore.TrendPoint]
    let exerciseMinutes: [AmbientHealthStore.TrendPoint]

    var body: some View {
        let displaySteps = weeklyTrendWindowEndingToday(steps)
        let displayExercise = weeklyTrendWindowEndingToday(exerciseMinutes)

        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Energy Rhythm", symbol: "figure.walk.arrival", tint: .green)

            Text("A quick read on movement and momentum over the past week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let avgSteps = weeklyAverage(for: displaySteps), let avgExercise = weeklyAverage(for: displayExercise) {
                HStack(spacing: 12) {
                    AmbientMiniMetric(title: "Weekly Avg Steps", value: Int(avgSteps).formatted())
                    AmbientMiniMetric(title: "Weekly Avg Exercise", value: "\(Int(avgExercise)) min")
                }
            }

            Text(combinedEnergySummary(steps: displaySteps, exerciseMinutes: displayExercise))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            let displayPoints = displaySteps
            let exerciseMap = Dictionary(
                uniqueKeysWithValues: displayExercise.map { ($0.date, $0.value) }
            )

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let exercise = exerciseMap[point.date] ?? 0
                        let hasData = point.value > 0 || exercise > 0
                        let intensity = hasData
                            ? energyIntensity(
                                steps: point.value,
                                exercise: exercise,
                                stepSeries: displayPoints,
                                exerciseSeries: exerciseMinutes
                            )
                            : 0.12
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
                                                hasData ? Color.green.opacity(0.18 + (0.14 * intensity)) : Color.white.opacity(0.06),
                                                hasData ? Color.green.opacity(0.035) : Color.white.opacity(0.02)
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
                                                        hasData ? Color.green.opacity(0.24 + (0.12 * intensity)) : Color.white.opacity(0.12),
                                                        hasData ? Color.green.opacity(0.08) : Color.white.opacity(0.04),
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
                                                    .fill(hasData ? Color.green.opacity(isLatest ? 0.94 : 0.82) : Color.white.opacity(0.18))
                                                    .frame(width: dotSize, height: dotSize)
                                                    .overlay {
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                                                    }
                                            }
                                    }
                                    .overlay(alignment: .bottom) {
                                        if isLatest && hasData {
                                            Image(systemName: "figure.walk.motion")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color.green.opacity(0.92))
                                                .padding(.bottom, -16)
                                        }
                                    }
                            }
                            .frame(height: 58)

                            Text(hasData ? "\(abbreviatedSteps(point.value))" : "--")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(hasData ? .primary : .secondary)

                            Text(trendDayLabel(for: point.date))
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
        let stepValues = stepSeries.map(\.value).filter { $0 > 0 }
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
    let baseline: AmbientHealthStore.MetricBaseline?

    var body: some View {
        let displayPoints = weeklyTrendWindowEndingToday(points)

        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Heart Rate Variability", symbol: "waveform.path", tint: .teal)

            Text("A softer read on recovery and tension over the past week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let hasData = point.value > 0
                        let intensity = hasData ? normalizedValue(for: point.value, in: displayPoints) : 0.12
                        let pulseHeight = pulseHeight(for: intensity, recencyIndex: entry.offset, totalCount: displayPoints.count)
                        let haloWidth = max(18, pulseHeight * 0.95)
                        let isLatest = entry.offset == displayPoints.count - 1

                        VStack(spacing: 6) {
                            ZStack {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                hasData ? Color.teal.opacity(0.18 + (0.14 * intensity)) : Color.white.opacity(0.06),
                                                hasData ? Color.teal.opacity(0.035) : Color.white.opacity(0.02)
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
                                            .fill(hasData ? Color.teal.opacity(0.11) : Color.white.opacity(0.08))
                                            .frame(width: haloWidth, height: max(28, pulseHeight + 10))
                                            .blur(radius: 10)
                                    }
                                    .overlay(alignment: .top) {
                                        if isLatest && hasData {
                                            Image(systemName: "waveform.path.ecg")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Color.teal.opacity(0.92))
                                                .padding(.top, -16)
                                        }
                                    }
                            }
                            .frame(height: 62)

                            Text(hasData ? "\(Int(point.value)) ms" : "--")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(hasData ? .primary : .secondary)

                            Text(trendDayLabel(for: point.date))
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
                points: displayPoints,
                lowMeaning: "HRV has looked a bit lower than your recent norm, which can line up with more strain or less recovery",
                highMeaning: "HRV has looked stronger than your recent norm, which usually points to steadier recovery",
                unit: "ms",
                formatter: { Int($0).formatted() },
                includeLatest: false,
                baseline: baseline
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: .teal)
    }

    private func normalizedValue(for value: Double, in points: [AmbientHealthStore.TrendPoint]) -> CGFloat {
        let values = points.map(\.value).filter { $0 > 0 }
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
    let latestSleepPoint: AmbientHealthStore.SleepStageTrendPoint?
    let baseline: AmbientHealthStore.MetricBaseline?

    private let tint = Color(red: 0.73, green: 0.56, blue: 0.88)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Sleep Duration", symbol: "moon.zzz.fill", tint: tint)

            Text("A quiet weekly picture of how much sleep has landed across the past week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = latestAlignedSleepDurationPoints()

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let hasData = point.value > 0
                        let intensity = hasData ? normalizedValue(for: point.value, in: displayPoints) : 0.12
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
                                                hasData ? tint.opacity(0.18 + (0.10 * intensity)) : Color.white.opacity(0.10),
                                                hasData ? tint.opacity(0.06) : Color.white.opacity(0.04),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 1,
                                            endRadius: glowSize / 2
                                        )
                                    )
                                    .frame(width: glowSize, height: glowSize)
                                    .blur(radius: 9)

                                Image(systemName: hasData ? (isLatest ? "moon.zzz.fill" : "moon.stars.fill") : "moon")
                                    .font(.system(size: moonSize, weight: .semibold))
                                    .foregroundStyle(hasData ? tint.opacity(isLatest ? 0.96 : 0.84) : Color.white.opacity(0.42))
                                    .offset(x: drift * 0.35)

                                if !isLatest && hasData {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 7, weight: .semibold))
                                        .foregroundStyle(tint.opacity(0.70))
                                        .offset(x: moonSize * 0.42, y: -moonSize * 0.34)
                                }
                            }
                            .frame(height: 52)

                            Text(hasData ? String(format: "%.1f h", point.value) : "--")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(hasData ? .primary : .secondary)

                            Text(shortDayLabel(for: point.date))
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
                points: displayPoints,
                lowMeaning: "sleep duration has looked lighter than your recent norm",
                highMeaning: "sleep duration has looked fuller than your recent norm",
                unit: "h",
                formatter: { String(format: "%.1f", $0) },
                includeLatest: false,
                baseline: baseline
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: tint)
    }

    private func normalizedValue(for value: Double, in points: [AmbientHealthStore.TrendPoint]) -> CGFloat {
        let values = points.map(\.value).filter { $0 > 0 }
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

    private func latestAlignedSleepDurationPoints() -> [AmbientHealthStore.TrendPoint] {
        var recentPoints = weeklyTrendWindow(points)

        guard let latestSleepPoint, latestSleepPoint.totalSleepHours > 0 else {
            return recentPoints
        }

        let latestTrendPoint = AmbientHealthStore.TrendPoint(
            date: latestSleepPoint.date,
            value: latestSleepPoint.totalSleepHours
        )

        if let matchingIndex = recentPoints.lastIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: latestSleepPoint.date) }) {
            recentPoints[matchingIndex] = latestTrendPoint
        } else {
            recentPoints.append(latestTrendPoint)
            if recentPoints.count > ambientWeeklyVisibleDays {
                recentPoints.removeFirst(recentPoints.count - ambientWeeklyVisibleDays)
            }
        }

        return recentPoints
    }
}

private struct AmbientHeartTrendCard: View {
    let points: [AmbientHealthStore.TrendPoint]
    let baseline: AmbientHealthStore.MetricBaseline?

    var body: some View {
        let displayPoints = weeklyTrendWindowEndingToday(points)

        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Resting Heart Rate", symbol: "heart.circle.fill", tint: Color(red: 1.0, green: 0.20, blue: 0.22))

            Text("A softer view of whether your system has looked calmer or more activated over the past week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !displayPoints.isEmpty {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(displayPoints.enumerated()), id: \.element.id) { entry in
                        let point = entry.element
                        let hasData = point.value > 0
                        let intensity = hasData ? normalizedIntensity(for: point.value, in: displayPoints) : 0.12
                        let heartSize = safeHeartSize(for: intensity, recencyIndex: entry.offset, totalCount: displayPoints.count)
                        let glowColor = hasData ? heartColor(for: intensity) : Color.white.opacity(0.45)
                        let haloSize = max(24, heartSize * 2.15)
                        let isLatest = entry.offset == displayPoints.count - 1

                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                hasData ? glowColor.opacity(0.24 + (0.12 * intensity)) : Color.white.opacity(0.10),
                                                hasData ? glowColor.opacity(0.08 + (0.06 * intensity)) : Color.white.opacity(0.04),
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
                                    .fill(Color.white.opacity(hasData ? 0.04 : 0.02))
                                    .frame(width: max(20, heartSize * 1.55), height: max(20, heartSize * 1.55))

                                Image(systemName: "heart.fill")
                                    .font(.system(size: heartSize, weight: .semibold))
                                    .foregroundStyle(glowColor)
                                    .shadow(color: glowColor.opacity(hasData ? 0.24 : 0.08), radius: 8, y: 0)
                                    .scaleEffect(isLatest ? 1.03 : 1.0)
                            }
                            .frame(height: 42 + heartSize)

                            Text(hasData ? "\(Int(point.value.rounded()))" : "--")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(hasData ? .primary : .secondary)

                            Text(trendDayLabel(for: point.date))
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
                points: displayPoints,
                lowMeaning: "your resting rhythm has looked calmer than your weekly norm",
                highMeaning: "your resting rhythm has looked a little more activated than your weekly norm",
                unit: "bpm",
                formatter: { Int($0).formatted() },
                includeLatest: false,
                baseline: baseline
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

        let raw = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        if !raw.isFinite {
            return 0.45
        }
        return CGFloat(min(max(raw, 0), 1))
    }

    private func safeHeartSize(for normalized: CGFloat, recencyIndex: Int, totalCount: Int) -> CGFloat {
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

/// Keeps chart layouts stable across the week, even when some days have no data yet.
private func weeklyTrendWindow(_ points: [AmbientHealthStore.TrendPoint]) -> [AmbientHealthStore.TrendPoint] {
    Array(points.suffix(ambientWeeklyVisibleDays))
}

/// Builds a fixed 7-day strip that always ends on today for non-sleep trend cards.
///
/// This keeps HRV, resting heart rate, and movement visually anchored to the current day,
/// while still showing placeholders when today's sample has not landed yet.
private func weeklyTrendWindowEndingToday(_ points: [AmbientHealthStore.TrendPoint]) -> [AmbientHealthStore.TrendPoint] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let pointMap = Dictionary(
        uniqueKeysWithValues: points.map { (calendar.startOfDay(for: $0.date), $0.value) }
    )

    return (0..<ambientWeeklyVisibleDays).compactMap { offset in
        guard let day = calendar.date(byAdding: .day, value: offset - (ambientWeeklyVisibleDays - 1), to: today) else {
            return nil
        }

        return AmbientHealthStore.TrendPoint(
            date: day,
            value: pointMap[day] ?? 0
        )
    }
}

private struct AmbientSleepQualitySummaryCard: View {
    let points: [AmbientHealthStore.SleepStageTrendPoint]
    let latestSleepPoint: AmbientHealthStore.SleepStageTrendPoint?
    @State private var showsWeeklySleepStages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Sleep Quality", symbol: "bed.double.circle.fill", tint: .blue)

            Text("A weekly read on how restorative your sleep looked across the past week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let latest = latestSleepPoint {
                VStack(alignment: .leading, spacing: 10) {
                    AmbientSleepStageMetricPanel(
                        title: "Latest • \(shortDayLabel(for: latest.date))",
                        subtitle: "\(String(format: "%.1f", latest.totalSleepHours)) h asleep",
                        corePercent: displayedCorePercent(for: latest),
                        deepPercent: latest.deepPercent,
                        remPercent: latest.remPercent,
                        awakePercent: latest.awakePercent,
                        tint: Color(red: 0.64, green: 0.78, blue: 1.0)
                    )

                    let calendar = Calendar.current
                    let weeklyPoints = Array(
                        points
                            .filter { $0.id != latest.id && !calendar.isDateInToday($0.date) }
                            .suffix(ambientWeeklyVisibleDays)
                    )

                    if !weeklyPoints.isEmpty {
                        DisclosureGroup(isExpanded: $showsWeeklySleepStages) {
                            VStack(alignment: .leading, spacing: 10) {
                                AmbientSleepStageLegend()
                                AmbientSleepQualityWeekList(points: weeklyPoints)
                            }
                                .padding(.top, 8)
                        } label: {
                            HStack {
                                Text("Show the rest of the week")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .padding(14)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
                        }
                    }

                }
            }

            Text(sleepStageSummary(points: points))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .ambientPanel(tint: .blue)
    }

}

private struct AmbientSleepStageLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            AmbientSleepLegendChip(title: "Core", color: Color.blue.opacity(0.55))
            AmbientSleepLegendChip(title: "Deep", color: Color.blue.opacity(0.95))
            AmbientSleepLegendChip(title: "REM", color: Color.cyan.opacity(0.85))
            AmbientSleepLegendChip(title: "Awake", color: Color.white.opacity(0.8))
        }
    }
}

private func trendDayLabel(for date: Date) -> String {
    Calendar.current.isDateInToday(date) ? "Today" : shortDayLabel(for: date)
}

private struct AmbientSleepLegendChip: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                }

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct AmbientSleepStageMetricPanel: View {
    let title: String
    let subtitle: String?
    let corePercent: Double
    let deepPercent: Double
    let remPercent: Double
    let awakePercent: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                AmbientMiniMetric(title: "Core", value: "\(Int(corePercent.rounded()))%")
                AmbientMiniMetric(title: "Deep", value: "\(Int(deepPercent.rounded()))%")
                AmbientMiniMetric(title: "REM", value: "\(Int(remPercent.rounded()))%")
                AmbientMiniMetric(title: "Awake", value: "\(Int(awakePercent.rounded()))%")
            }
        }
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct AmbientSleepQualityWeekList: View {
    let points: [AmbientHealthStore.SleepStageTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(points) { point in
                if point.totalSleepHours > 0.05 {
                    let core = displayedCorePercent(for: point)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(shortDayLabel(for: point.date))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(String(format: "%.1f", point.totalSleepHours)) h asleep")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geometry in
                            let totalWidth = geometry.size.width
                            let coreWidth = segmentWidth(totalWidth: totalWidth, percent: core)
                            let deepWidth = segmentWidth(totalWidth: totalWidth, percent: point.deepPercent)
                            let remWidth = segmentWidth(totalWidth: totalWidth, percent: point.remPercent)
                            let awakeWidth = segmentWidth(totalWidth: totalWidth, percent: point.awakePercent)

                            HStack(spacing: 0) {
                                Rectangle().fill(Color.blue.opacity(0.55)).frame(width: coreWidth)
                                Rectangle().fill(Color.blue.opacity(0.95)).frame(width: deepWidth)
                                Rectangle().fill(Color.cyan.opacity(0.85)).frame(width: remWidth)
                                Rectangle().fill(Color.white.opacity(0.75)).frame(width: awakeWidth)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .frame(height: 14)

                        HStack(spacing: 8) {
                            AmbientMiniMetric(title: "Core", value: "\(Int(core.rounded()))%")
                            AmbientMiniMetric(title: "Deep", value: "\(Int(point.deepPercent.rounded()))%")
                            AmbientMiniMetric(title: "REM", value: "\(Int(point.remPercent.rounded()))%")
                            AmbientMiniMetric(title: "Awake", value: "\(Int(point.awakePercent.rounded()))%")
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Text(shortDayLabel(for: point.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("No data")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func segmentWidth(totalWidth: CGFloat, percent: Double) -> CGFloat {
        max(8, totalWidth * CGFloat(max(percent, 0) / 100))
    }
}

private func displayedCorePercent(for point: AmbientHealthStore.SleepStageTrendPoint) -> Double {
    guard point.totalSleepHours > 0.05 else { return 0 }
    return max(0, 100 - point.deepPercent - point.remPercent - point.awakePercent)
}
