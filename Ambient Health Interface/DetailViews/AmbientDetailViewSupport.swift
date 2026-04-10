import SwiftUI

/// Shared styling, helper views, and summary utilities used across the detail screens.
/// Keeping these together helps the trends, explanation, and settings files stay focused
/// on their own responsibilities.

struct AmbientCalmerTrendNoteCard: View {
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

func calmerSummaryLine(for state: ColorHealthState) -> String {
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

struct AmbientSummaryRow: View {
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

struct AmbientCardHeader: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
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

struct AmbientSectionHeader: View {
    let title: String
    let symbol: String
    let tint: Color
    var animateSymbol: Bool = false
    @State private var symbolPulse = false

    var body: some View {
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
                    .scaleEffect(animateSymbol && symbolPulse ? 1.06 : 1.0)
                    .opacity(animateSymbol && symbolPulse ? 0.90 : 1.0)
            }
            .onAppear { updatePulseAnimation() }
            .onChange(of: animateSymbol) { _, _ in updatePulseAnimation() }

            Text(title)
                .font(.headline)
        }
    }

    private func updatePulseAnimation() {
        guard animateSymbol else {
            symbolPulse = false
            return
        }

        symbolPulse = false
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            symbolPulse = true
        }
    }
}

struct AmbientMiniMetric: View {
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

struct AmbientExplanationSignalRow: View {
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

struct AmbientInsightHistoryTrail: View {
    let history: [ColorHealthState]

    var body: some View {
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

struct AmbientAccessibilityToggleCard: View {
    let title: String
    let subtitle: String
    let symbol: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: symbol ?? iconForTitle(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.headline)
                }

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

    private func iconForTitle(_ title: String) -> String {
        switch title {
        case "Calmer Mode":
            return "water.waves"
        case "Reduce Motion":
            return "figure.walk.motion"
        case "Larger Text":
            return "textformat.size"
        case "Higher Contrast":
            return "circle.lefthalf.filled"
        default:
            return "accessibility"
        }
    }
}

struct AmbientSensitivityScale: View {
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
                        .offset(x: dotCenterX - 4, y: 19)
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

struct AmbientPanelModifier: ViewModifier {
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

struct AmbientSubpanelModifier: ViewModifier {
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

extension View {
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

func shortDayLabel(for date: Date) -> String {
    AmbientDateFormatting.shortWeekday.string(from: date)
}

func weeklyAverage(for points: [AmbientHealthStore.TrendPoint]) -> Double? {
    let values = points.map(\.value).filter { $0 > 0 }
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

func meaningfulTrendPoints(_ points: [AmbientHealthStore.TrendPoint]) -> [AmbientHealthStore.TrendPoint] {
    points.filter { $0.value > 0 }
}

func latestMeaningfulPoint(in points: [AmbientHealthStore.TrendPoint]) -> AmbientHealthStore.TrendPoint? {
    meaningfulTrendPoints(points).last
}

func abbreviatedSteps(_ value: Double) -> String {
    let steps = Int(value)
    if steps >= 10_000 {
        return String(format: "%.1fk", Double(steps) / 1_000)
    }
    if steps >= 1_000 {
        return "\(steps / 1_000)k"
    }
    return steps.formatted()
}

func restingHeartRateRange(for points: [AmbientHealthStore.TrendPoint]) -> ClosedRange<Double>? {
    let values = points.map(\.value).filter { $0 > 0 }
    guard let min = values.min(), let max = values.max() else { return nil }
    return min...max
}

func symbolForState(_ state: ColorHealthState) -> String {
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
        return "circle.hexagongrid.fill"
    case .red:
        return "flame.fill"
    case .orange:
        return "moon.zzz.fill"
    }
}

func weeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    averageLabel: String = "Weekly average",
    includeLatest: Bool = true,
    baseline: AmbientHealthStore.MetricBaseline? = nil
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "Not enough recent data yet."
    }

    let values = points.map(\.value).filter { $0 > 0 }
    let delta = latest - average
    let averageText = "\(formatter(average)) \(unit)"
    let latestText = "\(formatter(latest)) \(unit)"
    let rangeSpread = ((values.max() ?? average) - (values.min() ?? average))
    let rangeThreshold = max(average * 0.10, unit == "h" ? 0.45 : 3)
    let latestThreshold = max(average * 0.08, unit == "h" ? 0.35 : 2)

    if let baseline {
        let baselineDelta = average - baseline.mean
        let baselineThreshold = max(baseline.mean * 0.08, unit == "h" ? 0.35 : 2)

        if baselineDelta >= baselineThreshold {
            return includeLatest
                ? "\(averageLabel) is \(averageText). Current is \(latestText). Across this week, \(highMeaning)."
                : "\(averageLabel) is \(averageText). Across this week, \(highMeaning)."
        } else if baselineDelta <= -baselineThreshold {
            return includeLatest
                ? "\(averageLabel) is \(averageText). Current is \(latestText). Across this week, \(lowMeaning)."
                : "\(averageLabel) is \(averageText). Across this week, \(lowMeaning)."
        }
    }

    if rangeSpread < rangeThreshold || abs(delta) < latestThreshold {
        return includeLatest
            ? "\(averageLabel) is \(averageText). Current is \(latestText), so this week looks fairly steady."
            : "\(averageLabel) is \(averageText), and the week looks fairly steady."
    } else if delta > 0 {
        return includeLatest
            ? "\(averageLabel) is \(averageText). Current is \(latestText). Lately, \(highMeaning)."
            : "\(averageLabel) is \(averageText). Lately, \(highMeaning)."
    } else {
        return includeLatest
            ? "\(averageLabel) is \(averageText). Current is \(latestText). Lately, \(lowMeaning)."
            : "\(averageLabel) is \(averageText). Lately, \(lowMeaning)."
    }
}

func calmerWeeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    includeLatest: Bool = true,
    baseline: AmbientHealthStore.MetricBaseline? = nil
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "There is not enough recent data to describe this gently yet."
    }

    let values = points.map(\.value).filter { $0 > 0 }
    let delta = latest - average

    if let baseline {
        let baselineDelta = average - baseline.mean
        let baselineThreshold = max(baseline.mean * 0.08, unit == "h" ? 0.35 : 2)
        if baselineDelta >= baselineThreshold {
            return highMeaning
        } else if baselineDelta <= -baselineThreshold {
            return lowMeaning
        }
    }

    if ((values.max() ?? average) - (values.min() ?? average)) < max(average * 0.10, unit == "h" ? 0.45 : 3)
        || abs(delta) < max(average * 0.08, unit == "h" ? 0.35 : 2) {
        return "This part of the week looks fairly steady."
    } else if delta > 0 {
        return highMeaning
    } else {
        return lowMeaning
    }
}

func inverseWeeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    averageLabel: String = "Weekly average",
    includeLatest: Bool = true,
    baseline: AmbientHealthStore.MetricBaseline? = nil
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "Not enough recent data yet."
    }

    let values = points.map(\.value).filter { $0 > 0 }
    let delta = latest - average
    let averageText = "\(formatter(average)) \(unit)"
    let latestText = "\(formatter(latest)) \(unit)"
    let rangeSpread = ((values.max() ?? average) - (values.min() ?? average))
    let rangeThreshold = max(average * 0.08, 3)
    let latestThreshold = max(average * 0.06, 2)

    if let baseline {
        let baselineDelta = average - baseline.mean
        let baselineThreshold = max(baseline.mean * 0.06, 2)

        if baselineDelta >= baselineThreshold {
            return includeLatest
                ? "\(averageLabel) is \(averageText). Current is \(latestText). Across this week, \(highMeaning)."
                : "\(averageLabel) is \(averageText). Across this week, \(highMeaning)."
        } else if baselineDelta <= -baselineThreshold {
            return includeLatest
                ? "\(averageLabel) is \(averageText). Current is \(latestText). Across this week, \(lowMeaning)."
                : "\(averageLabel) is \(averageText). Across this week, \(lowMeaning)."
        }
    }

    if rangeSpread < rangeThreshold || abs(delta) < latestThreshold {
        return includeLatest
            ? "\(averageLabel) is \(averageText). Current is \(latestText), so this week looks fairly steady."
            : "\(averageLabel) is \(averageText), and the week looks fairly steady."
    } else if delta > 0 {
        return includeLatest
            ? "\(averageLabel) is \(averageText). Current is \(latestText). Lately, \(highMeaning)."
            : "\(averageLabel) is \(averageText). Lately, \(highMeaning)."
    } else {
        return includeLatest
            ? "\(averageLabel) is \(averageText). Current is \(latestText). Lately, \(lowMeaning)."
            : "\(averageLabel) is \(averageText). Lately, \(lowMeaning)."
    }
}

func calmerInverseWeeklyTrendSummary(
    points: [AmbientHealthStore.TrendPoint],
    lowMeaning: String,
    highMeaning: String,
    unit: String,
    formatter: (Double) -> String,
    includeLatest: Bool = true,
    baseline: AmbientHealthStore.MetricBaseline? = nil
) -> String {
    guard let average = weeklyAverage(for: points), let latest = latestMeaningfulPoint(in: points)?.value else {
        return "There is not enough recent data to describe this gently yet."
    }

    let values = points.map(\.value).filter { $0 > 0 }
    let delta = latest - average

    if let baseline {
        let baselineDelta = average - baseline.mean
        let baselineThreshold = max(baseline.mean * 0.06, 2)
        if baselineDelta >= baselineThreshold {
            return highMeaning
        } else if baselineDelta <= -baselineThreshold {
            return lowMeaning
        }
    }

    if ((values.max() ?? average) - (values.min() ?? average)) < max(average * 0.08, 3)
        || abs(delta) < max(average * 0.06, 2) {
        return "This part of the week looks fairly steady."
    } else if delta > 0 {
        return highMeaning
    } else {
        return lowMeaning
    }
}

func combinedEnergySummary(
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

func calmerEnergySummary(
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

func sleepStageSummary(points: [AmbientHealthStore.SleepStageTrendPoint]) -> String {
    let meaningfulPoints = points.filter { $0.totalSleepHours > 0.05 }

    guard !meaningfulPoints.isEmpty else {
        return "Not enough recent sleep-stage data yet."
    }

    let averageScore = meaningfulPoints.map(\.sleepScore).reduce(0, +) / Double(meaningfulPoints.count)
    let averageCore = meaningfulPoints.map { max(0, 100 - $0.deepPercent - $0.remPercent - $0.awakePercent) }.reduce(0, +) / Double(meaningfulPoints.count)
    let averageDeep = meaningfulPoints.map(\.deepPercent).reduce(0, +) / Double(meaningfulPoints.count)
    let averageREM = meaningfulPoints.map(\.remPercent).reduce(0, +) / Double(meaningfulPoints.count)
    let averageAwake = meaningfulPoints.map(\.awakePercent).reduce(0, +) / Double(meaningfulPoints.count)

    if averageScore >= 82 {
        return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep has looked fairly restorative this week, with duration and overnight sleep quality landing in a stronger range."
    }

    if averageScore <= 68 {
        return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep has looked softer this week, which usually means duration, stage balance, or interruptions have been less supportive."
    }

    if averageDeep >= 15, averageREM >= 19, averageAwake <= 11 {
        return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep has looked fairly restorative this week, with a healthy balance of core, deep, and REM sleep plus limited overnight awake time."
    }

    if averageAwake >= 14 {
        return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep has looked more broken up this week, with more awake time overnight. That usually means sleep happened, but recovery may have felt less complete."
    }

    if averageDeep < 11 || averageREM < 16 {
        return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep has looked lighter this week, with less time reaching deeper or dream-heavy stages. That can leave energy and mood feeling less restored, even if total sleep was okay."
    }

    if averageCore >= 66 {
        return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep has leaned heavily on core sleep this week. That is not automatically bad, but it can feel less restoring when deep and REM sleep stay on the lower side."
    }

    return "Weekly sleep score is \(Int(averageScore.rounded())). Sleep quality looks mixed this week: not especially poor, but not strongly restorative either."
}

func calmerSleepStageSummary(points: [AmbientHealthStore.SleepStageTrendPoint]) -> String {
    let meaningfulPoints = points.filter { $0.totalSleepHours > 0.05 }

    guard !meaningfulPoints.isEmpty else {
        return "There is not enough recent sleep-stage data to describe this gently yet."
    }

    let averageScore = meaningfulPoints.map(\.sleepScore).reduce(0, +) / Double(meaningfulPoints.count)
    let averageCore = meaningfulPoints.map { max(0, 100 - $0.deepPercent - $0.remPercent - $0.awakePercent) }.reduce(0, +) / Double(meaningfulPoints.count)
    let averageDeep = meaningfulPoints.map(\.deepPercent).reduce(0, +) / Double(meaningfulPoints.count)
    let averageREM = meaningfulPoints.map(\.remPercent).reduce(0, +) / Double(meaningfulPoints.count)
    let averageAwake = meaningfulPoints.map(\.awakePercent).reduce(0, +) / Double(meaningfulPoints.count)

    if averageScore >= 82 {
        return "Weekly sleep score is \(Int(averageScore.rounded())), which points to fairly supportive sleep this week."
    }

    if averageScore <= 68 {
        return "Weekly sleep score is \(Int(averageScore.rounded())), which points to sleep feeling a little less supportive this week."
    }

    if averageDeep >= 15, averageREM >= 19, averageAwake <= 11 {
        return "Sleep quality looks fairly supportive this week."
    }

    if averageAwake >= 14 {
        return "Sleep quality looks a little more interrupted this week, with more time waking up overnight."
    }

    if averageDeep < 11 || averageREM < 16 {
        return "Sleep quality looks a little lighter than usual this week, with less deeper and dream-heavy sleep."
    }

    if averageCore >= 66 {
        return "Sleep looks a little more core-heavy this week, which can feel less restorative."
    }

    return "Sleep quality looks mixed, but not strongly pulled in one direction."
}
