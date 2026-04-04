import SwiftUI

// These detail screens intentionally hold the more explicit, inspectable layer of the app.
// The main Now screen stays ambient

struct AmbientTrendsView: View {
    @ObservedObject var healthStore: AmbientHealthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trends")
                    .font(.title2.weight(.semibold))

                Text("A simple weekly read on the signals most connected to your current mood state.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let trendReport = healthStore.trendReport {
                    // Trends are intentionally trimmed down to the few views that help explain mood,
                    // instead of trying to expose every raw signal the store knows about.
                    AmbientWeeklySummaryCard(
                        trendReport: trendReport,
                        currentState: healthStore.currentState
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
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No trend data yet")
                            .font(.headline)

                        Text("Connect Health and refresh on your iPhone after a few days of watch data have synced.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.bottom, 40)
        }
    }
}

struct AmbientExplanationView: View {
    @ObservedObject var healthStore: AmbientHealthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Explanation")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 10) {
                    // A small visual marker helps the current state read faster without turning the
                    // explanation cards into a dense icon-heavy dashboard.
                    AmbientSectionHeader(
                        title: healthStore.currentState.title,
                        symbol: symbolForState(healthStore.currentState),
                        tint: healthStore.currentState.color
                    )

                    if !explanationSignalChips(snapshot: healthStore.latestSnapshot).isEmpty {
                        AmbientExplanationSignalRow(
                            chips: explanationSignalChips(snapshot: healthStore.latestSnapshot),
                            tint: healthStore.currentState.color
                        )
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

                    ForEach(explanationBullets(for: healthStore.currentState, snapshot: healthStore.latestSnapshot), id: \.self) { bullet in
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
                                symbol: "circle.hexagongrid.fill",
                                tint: Color(red: 0.49, green: 0.72, blue: 0.96)
                            )

                            Spacer()

                            AmbientInsightHistoryTrail(history: healthStore.history)
                        }

                        Text(patternInsight(for: healthStore.currentState, snapshot: healthStore.latestSnapshot))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("Based on recent health patterns and how they compare to your usual rhythm.")
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

            Text("A simple weekly picture of your general momentum, using steps and exercise together.")
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

            let displayPoints = meaningfulTrendPoints(steps)
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
                                                Color.green.opacity(0.22 + (0.18 * intensity)),
                                                Color.green.opacity(0.05)
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
                                                        Color.green.opacity(0.32 + (0.16 * intensity)),
                                                        Color.green.opacity(0.12),
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
                                    Color.white.opacity(0.06),
                                    Color.green.opacity(0.05)
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
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            Text("A softer read on recovery, steadiness, and tension across the week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = meaningfulTrendPoints(points)

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
                                                Color.teal.opacity(0.22 + (0.18 * intensity)),
                                                Color.teal.opacity(0.05)
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
                                            .fill(Color.teal.opacity(0.16))
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
                                    Color.white.opacity(0.06),
                                    Color.teal.opacity(0.05)
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
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            Text("A quiet weekly picture of how much sleep has been landing each night.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = meaningfulTrendPoints(points)

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
                                                tint.opacity(0.22 + (0.14 * intensity)),
                                                tint.opacity(0.08),
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
                                    Color.white.opacity(0.06),
                                    tint.opacity(0.05)
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
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            Text("A softer view of whether your system has looked calmer or more activated over the last week.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            let displayPoints = meaningfulTrendPoints(points)

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
                                                glowColor.opacity(0.30 + (0.18 * intensity)),
                                                glowColor.opacity(0.12 + (0.10 * intensity)),
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
                                    .fill(Color.white.opacity(0.06))
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
                                    Color.white.opacity(0.06),
                                    Color(red: 1.0, green: 0.16, blue: 0.18).opacity(0.05)
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
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    let resetToDefault: () -> Void
    @State private var showsSensitivitySection = true
    @State private var showsHealthKitSection = false
    @State private var showsAdvancedSensitivity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                Text("Start with a mode, then only adjust the part that feels off. Each control below now changes one mood family more directly.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Sensitivity changes how strongly the classifier reacts to HealthKit values.
                // Intentionally grouped in Settings because it changes system behavior
                DisclosureGroup(isExpanded: $showsSensitivitySection) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose the overall feel first. Fine-tune only if one mood keeps showing up too often or not often enough.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(AmbientHealthStore.SensitivityPreset.allCases.filter { $0 != .custom }) { preset in
                                Button {
                                    sensitivityPresetBinding.wrappedValue = preset
                                } label: {
                                    Text(preset.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(healthStore.sensitivityPreset == preset ? .primary : .secondary)
                                        .padding(.horizontal, 12)
                                        .frame(height: 32)
                                        .background(
                                            Capsule()
                                                .fill(healthStore.sensitivityPreset == preset ? Color.white.opacity(0.64) : Color.white.opacity(0.14))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(presetDescription(for: healthStore.sensitivityPreset))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            AmbientSensitivityHintChip(title: "Stress", detail: "Only changes Stressed")
                            AmbientSensitivityHintChip(title: "Energy", detail: "Only changes Low Energy")
                            AmbientSensitivityHintChip(title: "Sleep", detail: "Mostly changes Restored / Drained")
                        }

                        DisclosureGroup("Advanced Sensitivity", isExpanded: $showsAdvancedSensitivity) {
                            VStack(spacing: 12) {
                                AmbientSensitivitySlider(
                                    title: "Stress Signals",
                                    subtitle: "Only changes how easily the app shows Stressed from heart rate, HRV, breathing, and related strain signals.",
                                    lowLabel: "Harder to call stressed",
                                    highLabel: "Easier to call stressed",
                                    value: $stressSensitivity
                                )
                                AmbientSensitivitySlider(
                                    title: "Low Energy Signals",
                                    subtitle: "Only changes how much lower movement and exercise can push the app toward Low Energy.",
                                    lowLabel: "Less likely to call low energy",
                                    highLabel: "More likely to call low energy",
                                    value: $movementSensitivity
                                )
                                AmbientSensitivitySlider(
                                    title: "Sleep + Recovery",
                                    subtitle: "Mostly changes how strongly sleep and recovery can push the app toward Restored or Drained.",
                                    lowLabel: "Sleep matters less",
                                    highLabel: "Sleep matters more",
                                    value: $recoverySensitivity
                                )
                                AmbientSensitivitySlider(
                                    title: "Overall Mood Speed",
                                    subtitle: "A light global nudge. Leave this near the middle unless the whole app feels too jumpy or too muted.",
                                    lowLabel: "Changes more slowly",
                                    highLabel: "Changes more quickly",
                                    value: $overallResponsiveness
                                )
                            }
                            .padding(.top, 10)
                        }

                        Text("Recommended is the best starting point. If the app feels random, leave Overall Mood Speed near the middle and adjust only one row at a time.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Workout-aware stress handling is on. The app softens stress detection during an active workout and a short recovery window after, so exercise does not get mistaken for emotional stress.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            Spacer()

                            Button {
                                resetToDefault()
                            } label: {
                                Text("Use Recommended")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .frame(height: 32)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sensitivity")
                            .font(.headline)

                        Text(sensitivitySectionSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

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
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.bottom, 40)
        }
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
            return "This holds onto the current mood longer and needs clearer evidence before it changes."
        case .recommended:
            return "This is the balanced mode. It should notice real shifts without jumping around."
        case .responsive:
            return "This shifts sooner. Use it if the app still feels too muted after a few days."
        case .custom:
            return "You changed the sliders yourself. Each one now maps more directly to one part of the mood read."
        }
    }

    private var sensitivitySectionSummary: String {
        "Current mode: \(healthStore.sensitivityPreset.rawValue). Expand to tune stress, energy, sleep, and overall mood speed."
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

private struct AmbientSensitivitySlider: View {
    let title: String
    let subtitle: String
    let lowLabel: String
    let highLabel: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(levelLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Slider(value: $value, in: 0...1)
                .tint(Color(red: 0.49, green: 0.72, blue: 0.96))

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color(red: 0.49, green: 0.72, blue: 0.96).opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var levelLabel: String {
        switch value {
        case ..<0.30:
            return "Low"
        case ..<0.45:
            return "Soft"
        case ..<0.62:
            return "Balanced"
        case ..<0.78:
            return "Active"
        default:
            return "High"
        }
    }
}

private struct AmbientSensitivityHintChip: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
