import SwiftUI
import Charts

// These detail screens intentionally hold the more explicit, inspectable layer of the app.
// The main Now screen stays ambient

struct AmbientTrendsView: View {
    @ObservedObject var healthStore: AmbientHealthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trends")
                    .font(.title2.weight(.semibold))

                Text("A deeper read on the HealthKit signals shaping your ambient state over the last 7 days.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                if let trendReport = healthStore.trendReport {
                    // Every card below is driven from the same refresh cycle so the story across the
                    // charts stays aligned with the current ambient state.
                    AmbientStateTrailCard(points: trendReport.stateTrail)
                    AmbientLineTrendCard(
                        title: "Sleep Duration",
                        subtitle: "Total overnight sleep across the last 7 days.",
                        points: trendReport.sleepHours,
                        color: .blue,
                        unitLabel: "hours"
                    )
                    AmbientLineTrendCard(
                        title: "Heart Rate Variability",
                        subtitle: "Daily average HRV, a useful recovery and strain signal.",
                        points: trendReport.heartRateVariability,
                        color: .teal,
                        unitLabel: "ms",
                        valueFormatter: { Int($0).formatted() }
                    )
                    AmbientLineTrendCard(
                        title: "Resting Heart Rate",
                        subtitle: "Daily resting heart rate trend from HealthKit.",
                        points: trendReport.restingHeartRate,
                        color: .pink,
                        unitLabel: "bpm",
                        valueFormatter: { Int($0).formatted() }
                    )
                    AmbientLineTrendCard(
                        title: "Movement Signals",
                        subtitle: "Daily steps as your broad activity baseline.",
                        points: trendReport.steps,
                        color: .green,
                        unitLabel: "steps",
                        valueFormatter: { Int($0).formatted() }
                    )
                    AmbientLineTrendCard(
                        title: "Exercise Load",
                        subtitle: "Minutes of intentional exercise captured by HealthKit.",
                        points: trendReport.exerciseMinutes,
                        color: .orange,
                        unitLabel: "min",
                        valueFormatter: { Int($0).formatted() }
                    )
                    AmbientSleepStageTrendCard(points: trendReport.sleepStages)
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
                    Text(healthStore.currentState.title)
                        .font(.headline)

                    Text(explanationSummary(for: healthStore.currentState, snapshot: healthStore.latestSnapshot))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("What This May Mean")
                        .font(.headline)

                    ForEach(explanationBullets(for: healthStore.currentState, snapshot: healthStore.latestSnapshot), id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(healthStore.currentState.color.opacity(0.9))
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
                            Text("Pattern Insight")
                                .font(.headline)

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

private struct AmbientStateTrailCard: View {
    let points: [AmbientHealthStore.StateTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ambient State Trail")
                .font(.headline)

            Text("Each day is mapped into the same ambient health states the main object uses.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // "how has the ambient interpretation changed over the week?"
            HStack(spacing: 10) {
                ForEach(points) { point in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(point.state.color.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay {
                                Text(String(point.state.title.prefix(1)))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                        Text(shortDayLabel(for: point.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AmbientLineTrendCard: View {
    let title: String
    let subtitle: String
    let points: [AmbientHealthStore.TrendPoint]
    let color: Color
    let unitLabel: String
    var valueFormatter: (Double) -> String = { String(format: "%.1f", $0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Shared chart card used for any single-metric 7-day trend.
            Chart(points) { point in
                AreaMark(
                    x: .value("Day", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color.opacity(0.14))

                LineMark(
                    x: .value("Day", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Day", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(color)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDayLabel(for: date))
                        }
                    }
                }
            }
            .frame(height: 160)

            if let latest = points.last {
                Text("Latest: \(valueFormatter(latest.value)) \(unitLabel)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AmbientSleepStageTrendCard: View {
    let points: [AmbientHealthStore.SleepStageTrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sleep Stage Balance")
                .font(.headline)

            Text("Deep, REM, and awake percentages help separate long sleep from restorative sleep.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Sleep stages are separated because "slept longer" and "slept restoratively" are not the same thing.
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Deep", point.deepPercent)
                    )
                    .foregroundStyle(.blue)

                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("REM", point.remPercent)
                    )
                    .foregroundStyle(.purple)

                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Awake", point.awakePercent)
                    )
                    .foregroundStyle(.orange)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDayLabel(for: date))
                        }
                    }
                }
            }
            .frame(height: 170)

            if let latest = points.last {
                Text("Last night: \(String(format: "%.1f", latest.totalSleepHours)) h sleep, Deep \(Int(latest.deepPercent))%, REM \(Int(latest.remPercent))%, Awake \(Int(latest.awakePercent))%")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private func shortDayLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    return formatter.string(from: date)
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
    @State private var showsAdvancedSensitivity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))

                Text("Tune how strongly live HealthKit changes affect the ambient state, and review the current HealthKit connection.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Sensitivity changes how strongly the classifier reacts to HealthKit values.
                // Intentionally grouped in Settings because it changes system behavior
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sensitivity")
                        .font(.headline)

                    Text("Choose how reactive the ambient state should feel, then fine-tune only if you want more control.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker("Sensitivity Preset", selection: sensitivityPresetBinding) {
                        ForEach(AmbientHealthStore.SensitivityPreset.allCases.filter { $0 != .custom }) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                        if healthStore.sensitivityPreset == .custom {
                            Text(AmbientHealthStore.SensitivityPreset.custom.rawValue).tag(AmbientHealthStore.SensitivityPreset.custom)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(presetDescription(for: healthStore.sensitivityPreset))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Advanced Sensitivity", isExpanded: $showsAdvancedSensitivity) {
                        VStack(spacing: 12) {
                            AmbientSensitivitySlider(title: "Stress Response", value: $stressSensitivity)
                            AmbientSensitivitySlider(title: "Movement Response", value: $movementSensitivity)
                            AmbientSensitivitySlider(title: "Recovery Response", value: $recoverySensitivity)
                            AmbientSensitivitySlider(title: "Overall Responsiveness", value: $overallResponsiveness)
                        }
                        .padding(.top, 10)
                    }

                    Text("Recommended default is tuned for an Apple Watch SE 3 reading ambient movement, recovery, stress, and sleep-stage data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        resetToDefault()
                    } label: {
                        Text("Use Recommended")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                // HealthKit status lives here so operational/debug information stays out of the more atmospheric home screen
                VStack(alignment: .leading, spacing: 12) {
                    Text("HealthKit")
                        .font(.headline)

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

                                    Text("\(entry.label): \(statusLabel(for: entry.status))")
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
            return "More stable and calm. The ambient state waits for stronger HealthKit changes before shifting."
        case .recommended:
            return "Balanced for your Apple Watch SE 3 setup, with recovery and stress carrying slightly more weight."
        case .responsive:
            return "More reactive. Smaller health changes can move the ambient state sooner."
        case .custom:
            return "Fine-tuned manually using the advanced sensitivity controls."
        }
    }

    private func statusLabel(for status: AmbientHealthStore.HealthSignalStatus) -> String {
        status.title
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
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: 0...1)
                .tint(.blue)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
