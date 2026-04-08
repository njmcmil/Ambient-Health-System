import SwiftUI

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

                Text("A lighter weekly view of the average signals behind your current mood read.")
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
                            currentState: healthStore.displayedState
                        )
                    } else {
                        AmbientWeeklySummaryCard(
                            trendReport: trendReport,
                            currentState: healthStore.displayedState
                        )
                        AmbientHRVTrendCard(points: trendReport.heartRateVariability)
                        AmbientHeartTrendCard(points: trendReport.restingHeartRate)
                        AmbientEnergyRhythmCard(
                            steps: trendReport.steps,
                            exerciseMinutes: trendReport.exerciseMinutes
                        )
                        AmbientSleepDurationCard(
                            points: trendReport.sleepHours,
                            latestSleepPoint: trendReport.latestSleepStage
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

private struct AmbientWeeklySummaryCard: View {
    let trendReport: AmbientHealthStore.TrendReport
    let currentState: ColorHealthState

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
                        includeLatest: false
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
                        includeLatest: false
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
                        includeLatest: false
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
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Energy Rhythm", symbol: "figure.walk.arrival", tint: .green)

            Text("A quick read on weekly movement and momentum.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let avgSteps = weeklyAverage(for: steps), let avgExercise = weeklyAverage(for: exerciseMinutes) {
                HStack(spacing: 12) {
                    AmbientMiniMetric(title: "Weekly Avg Steps", value: Int(avgSteps).formatted())
                    AmbientMiniMetric(title: "Weekly Avg Exercise", value: "\(Int(avgExercise)) min")
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

                            Text(isLatest ? "Today" : shortDayLabel(for: point.date))
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
            AmbientCardHeader(title: "Heart Rate Variability", symbol: "waveform.path", tint: .teal)

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

                            Text(isLatest ? "Today" : shortDayLabel(for: point.date))
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
    let latestSleepPoint: AmbientHealthStore.SleepStageTrendPoint?

    private let tint = Color(red: 0.73, green: 0.56, blue: 0.88)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Sleep Duration", symbol: "moon.zzz.fill", tint: tint)

            Text("A quiet weekly picture of how much sleep has landed each night.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = latestAlignedSleepDurationPoints()

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

    private func latestAlignedSleepDurationPoints() -> [AmbientHealthStore.TrendPoint] {
        var recentPoints = Array(meaningfulTrendPoints(points).suffix(5))

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
            if recentPoints.count > 5 {
                recentPoints.removeFirst(recentPoints.count - 5)
            }
        }

        return recentPoints
    }
}

private struct AmbientHeartTrendCard: View {
    let points: [AmbientHealthStore.TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Resting Heart Rate", symbol: "heart.circle.fill", tint: Color(red: 1.0, green: 0.20, blue: 0.22))

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

                            Text(isLatest ? "Today" : shortDayLabel(for: point.date))
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

private struct AmbientSleepQualitySummaryCard: View {
    let points: [AmbientHealthStore.SleepStageTrendPoint]
    let latestSleepPoint: AmbientHealthStore.SleepStageTrendPoint?
    @State private var showsWeeklySleepStages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AmbientCardHeader(title: "Sleep Quality", symbol: "bed.double.circle.fill", tint: .blue)

            Text("A weekly read on how restorative your sleep looked, compared with the latest night.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let latest = latestSleepPoint {
                VStack(alignment: .leading, spacing: 10) {
                    AmbientSleepStageLegend()

                    let calendar = Calendar.current
                    let weeklyPoints = Array(
                        points
                            .filter { $0.id != latest.id && !calendar.isDateInToday($0.date) }
                            .suffix(7)
                    )

                    if !weeklyPoints.isEmpty {
                        DisclosureGroup(isExpanded: $showsWeeklySleepStages) {
                            AmbientSleepQualityWeekList(points: weeklyPoints)
                                .padding(.top, 8)
                        } label: {
                            HStack {
                                Text("Show weekly sleep stages")
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

                    AmbientSleepStageMetricPanel(
                        title: "Latest • \(shortDayLabel(for: latest.date))",
                        subtitle: "\(String(format: "%.1f", latest.totalSleepHours)) h asleep",
                        corePercent: displayedCorePercent(for: latest),
                        deepPercent: latest.deepPercent,
                        remPercent: latest.remPercent,
                        awakePercent: latest.awakePercent,
                        tint: Color(red: 0.64, green: 0.78, blue: 1.0)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(sleepStageSummary(points: points))
                    .font(.body)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
