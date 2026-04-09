import SwiftUI

/// Weekly context card for the Now view, including today's state wheel and ambient object status.
struct AmbientNowCalendarCard: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @ObservedObject private var piController = PiController.shared
    @State private var selectedWeekOffset = 0
    @State private var selectedDayDetail: CalendarDayDetail?

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(dayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    AmbientConnectionIndicator(status: piController.connectionStatus)
                        .padding(.bottom, 3)

                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(currentLiveLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(currentLiveLabelColor)
                }
            }

            TabView(selection: $selectedWeekOffset) {
                ForEach([2, 1, 0], id: \.self) { offset in
                    HStack(spacing: 8) {
                        ForEach(weekDates(for: offset), id: \.self) { date in
                            let isToday = calendar.isDateInToday(date)
                            let stateColor = color(for: date)
                            let hasData = hasData(for: date)

                            VStack(spacing: 6) {
                                VStack(spacing: 1) {
                                    if isCurrentWeekdayColumn(date) {
                                        Text(labelForWeek(offset))
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary.opacity(0.8))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.4)
                                            .frame(width: 58)
                                    } else {
                                        Text(" ")
                                            .font(.caption2.weight(.medium))
                                            .opacity(0)
                                    }

                                    Text(shortWeekday(for: date))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                ZStack {
                                    if isToday && offset == 0 && hasData {
                                        AmbientStateWheel(
                                            points: previewWheelPoints
                                                ?? (healthStore.liveIntradayStateTrail.isEmpty
                                                    ? [AmbientHealthStore.StateTrendPoint(date: Date(), state: healthStore.displayedState)]
                                                    : healthStore.liveIntradayStateTrail)
                                        )
                                        .frame(width: 30, height: 30)
                                    } else if hasData {
                                        Circle()
                                            .fill(stateColor.opacity(0.12))
                                            .overlay {
                                                Circle()
                                                    .fill(stateColor.opacity(0.38))
                                                    .padding(5)
                                            }
                                    } else {
                                        Circle()
                                            .fill(Color.white.opacity(0.02))
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        Color(red: 0.66, green: 0.70, blue: 0.76).opacity(0.42),
                                                        style: StrokeStyle(lineWidth: 1.1, dash: [2.4, 2.4])
                                                    )
                                                    .padding(4)
                                            }
                                    }

                                    Text(dayNumber(for: date))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(isToday && offset == 0 ? .white : (hasData ? .primary : .secondary))
                                }
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            isToday && offset == 0 ? todayWheelAccentColor.opacity(0.45) : (hasData ? stateColor.opacity(0.22) : Color.white.opacity(0.08)),
                                            lineWidth: isToday && offset == 0 ? 1.2 : 0.9
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDayDetail = detail(for: date)
                            }
                        }
                    }
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 64)

            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8, weight: .semibold))
                Text("Swipe for earlier weeks")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 8)
        .sheet(item: $selectedDayDetail) { detail in
            AmbientCalendarDayDetailSheet(detail: detail)
                .presentationDetents([.height(detail.isToday ? 292 : 278)])
                .presentationDragIndicator(.visible)
        }
    }

    private var cardFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.10),
                healthStore.ambientVisualState.color.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func weekDates(for offset: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        let centeredCurrentWindowStart = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let startOfWeek = calendar.date(byAdding: .day, value: -(offset * 7), to: centeredCurrentWindowStart) ?? centeredCurrentWindowStart
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var monthTitle: String {
        AmbientDateFormatting.monthTitle.string(from: Date())
    }

    private var dayTitle: String {
        AmbientDateFormatting.dayTitle.string(from: Date())
    }

    private func shortWeekday(for date: Date) -> String {
        AmbientDateFormatting.shortWeekday.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        AmbientDateFormatting.dayNumber.string(from: date)
    }

    private func isCurrentWeekdayColumn(_ date: Date) -> Bool {
        let currentPageDates = weekDates(for: 0)
        guard currentPageDates.indices.contains(3) else { return false }
        return calendar.isDate(date, inSameDayAs: currentPageDates[3])
    }

    private func labelForWeek(_ offset: Int) -> String {
        switch offset {
        case 0:
            return "This Week"
        case 1:
            return "Last Week"
        default:
            return "2 Weeks Ago"
        }
    }

    private func color(for date: Date) -> Color {
        if let previewState = healthStore.previewState {
            return previewState.color
        }

        return state(for: date)?.color ?? Color(red: 0.66, green: 0.70, blue: 0.76)
    }

    private var todayWheelAccentColor: Color {
        if let previewState = healthStore.previewState {
            return previewState.color
        }

        guard !healthStore.liveIntradayStateTrail.isEmpty else {
            return healthStore.ambientVisualState.color
        }

        return healthStore.liveIntradayStateTrail.last?.state.color ?? healthStore.ambientVisualState.color
    }

    private var currentLiveLabel: String {
        if healthStore.previewState != nil || healthStore.hasMeaningfulCurrentRead {
            return healthStore.displayedState.title
        }

        return "No Data Yet"
    }

    private var currentLiveLabelColor: Color {
        if healthStore.previewState != nil || healthStore.hasMeaningfulCurrentRead {
            return healthStore.displayedState.color
        }

        return Color(red: 0.66, green: 0.70, blue: 0.76)
    }

    private var previewWheelPoints: [AmbientHealthStore.StateTrendPoint]? {
        guard let previewState = healthStore.previewState else { return nil }
        return stride(from: 0, through: 5, by: 1).map { hour in
            AmbientHealthStore.StateTrendPoint(
                date: calendar.date(byAdding: .hour, value: hour * 3, to: calendar.startOfDay(for: Date())) ?? Date(),
                state: previewState
            )
        }
    }

    private func state(for date: Date) -> ColorHealthState? {
        if calendar.isDateInToday(date) {
            return healthStore.previewState != nil || healthStore.hasMeaningfulCurrentRead
                ? healthStore.displayedState
                : nil
        }

        return healthStore.liveCalendarStateTrail.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.state
    }

    private func hasData(for date: Date) -> Bool {
        state(for: date) != nil
    }

    private func detail(for date: Date) -> CalendarDayDetail {
        let isToday = calendar.isDateInToday(date)
        let resolvedState = state(for: date)
        let normalizedDate = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: Date())

        if isToday, healthStore.previewState == nil, !healthStore.hasMeaningfulCurrentRead {
            return CalendarDayDetail(
                date: normalizedDate,
                title: "Today",
                subtitle: "No data yet",
                state: nil,
                summary: "No recent Apple Health data has landed for today yet, so no live state has been assigned from today's signals.",
                chips: [],
                isToday: true
            )
        }

        if isToday, let snapshot = healthStore.latestSnapshot, let resolvedState {
            return CalendarDayDetail(
                date: normalizedDate,
                title: "Today",
                subtitle: "Current live read",
                state: resolvedState,
                summary: nowLine(for: resolvedState),
                chips: detailChipsForToday(snapshot: snapshot, state: resolvedState),
                isToday: true
            )
        }

        guard let resolvedState else {
            return CalendarDayDetail(
                date: normalizedDate,
                title: dayDetailTitle(for: normalizedDate),
                subtitle: normalizedDate > todayStart ? "Future day" : "No data",
                state: nil,
                summary: normalizedDate > todayStart
                    ? "This day has not happened yet, so no Apple Health data or state is available for it."
                    : "No recent Apple Health data was available for this day, so no health state was assigned.",
                chips: [],
                isToday: false
            )
        }

        return CalendarDayDetail(
            date: normalizedDate,
            title: dayDetailTitle(for: normalizedDate),
            subtitle: "Most present state that day",
            state: resolvedState,
            summary: "This was the state that showed up most across that day.",
            chips: detailChips(for: normalizedDate, state: resolvedState),
            isToday: false
        )
    }

    private func detailChipsForToday(snapshot: AmbientHealthStore.Snapshot, state: ColorHealthState) -> [ExplanationSignalChip] {
        let available = availableSignalChips(
            sleepHours: snapshot.sleepHours,
            sleepStages: snapshot.sleepStages,
            hrv: snapshot.heartRateVariability,
            resting: snapshot.restingHeartRate,
            steps: snapshot.stepCountToday,
            respiratory: snapshot.respiratoryRate,
            oxygen: snapshot.oxygenSaturationPercent,
            wristTemperature: snapshot.wristTemperatureCelsius
        )

        return prioritizedChips(for: state, available: available)
    }

    private func detailChips(for date: Date, state: ColorHealthState) -> [ExplanationSignalChip] {
        guard let trendReport = healthStore.trendReport else { return [] }

        let sleepPoint = trendReport.calendarSleepHours.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
        let sleepStagePoint = trendReport.calendarSleepStages.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
        let available = availableSignalChips(
            sleepHours: sleepPoint?.value,
            sleepStages: sleepStagePoint.map {
                AmbientHealthStore.SleepStageBreakdown(
                    totalSleepHours: $0.totalSleepHours,
                    inBedHours: $0.totalSleepHours + (($0.awakePercent / 100) * max($0.totalSleepHours, 0)),
                    awakeHours: ($0.awakePercent / 100) * max($0.totalSleepHours, 0),
                    coreHours: max(0, $0.totalSleepHours * max(0, 100 - $0.deepPercent - $0.remPercent - $0.awakePercent) / 100),
                    deepHours: $0.totalSleepHours * ($0.deepPercent / 100),
                    remHours: $0.totalSleepHours * ($0.remPercent / 100),
                    unspecifiedSleepHours: 0
                )
            },
            hrv: trendReport.calendarHeartRateVariability.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.value,
            resting: trendReport.calendarRestingHeartRate.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.value,
            steps: trendReport.calendarSteps.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.value,
            respiratory: trendReport.calendarRespiratoryRate.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.value,
            oxygen: trendReport.calendarOxygenSaturationPercent.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.value,
            wristTemperature: trendReport.calendarWristTemperatureCelsius.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.value
        )

        let prioritized = prioritizedChips(for: state, available: available)
        return prioritized.isEmpty ? [.init(symbol: "tray", title: "Data", value: "No recent data")] : prioritized
    }

    private func availableSignalChips(
        sleepHours: Double?,
        sleepStages: AmbientHealthStore.SleepStageBreakdown?,
        hrv: Double?,
        resting: Double?,
        steps: Double?,
        respiratory: Double?,
        oxygen: Double?,
        wristTemperature: Double?
    ) -> [ExplanationSignalChip] {
        var chips: [ExplanationSignalChip] = []

        if let sleepHours, sleepHours > 0 {
            chips.append(.init(symbol: "moon.stars.fill", title: "Sleep", value: String(format: "%.1f h", sleepHours)))
        }

        if let sleepStages, sleepStages.totalSleepHours > 0 {
            chips.append(.init(symbol: "bed.double.fill", title: "Sleep Quality", value: "Deep \(Int(sleepStages.deepPercent.rounded()))%"))
        }

        if let hrv, hrv > 0 {
            chips.append(.init(symbol: "waveform.path.ecg", title: "HRV", value: "\(Int(hrv.rounded())) ms"))
        }

        if let resting, resting > 0 {
            chips.append(.init(symbol: "heart.fill", title: "Resting", value: "\(Int(resting.rounded())) bpm"))
        }

        if let respiratory, respiratory > 0 {
            chips.append(.init(symbol: "wind", title: "Breathing Overnight", value: String(format: "%.1f/min", respiratory)))
        }

        if let oxygen, oxygen > 0 {
            chips.append(.init(symbol: "drop.fill", title: "Oxygen", value: "\(Int(oxygen.rounded()))%"))
        }

        if let wristTemperature, abs(wristTemperature) > 0.0001 {
            chips.append(.init(symbol: "thermometer.medium", title: "Wrist Temp", value: String(format: "%+.1f C", wristTemperature)))
        }

        if let steps, steps > 0 {
            chips.append(.init(symbol: "figure.walk.motion", title: "Movement", value: movementValue(for: steps)))
        }

        return chips
    }

    private func prioritizedChips(for state: ColorHealthState, available: [ExplanationSignalChip]) -> [ExplanationSignalChip] {
        let preferredTitles: [String]
        switch state {
        case .blue:
            preferredTitles = ["Sleep", "Sleep Quality", "HRV", "Resting"]
        case .green:
            preferredTitles = ["Movement", "HRV", "Sleep", "Resting"]
        case .yellow:
            preferredTitles = ["Movement", "Sleep", "Resting", "HRV"]
        case .purple:
            preferredTitles = ["HRV", "Resting", "Breathing Overnight", "Sleep", "Oxygen", "Wrist Temp"]
        case .gray:
            preferredTitles = ["Sleep", "HRV", "Resting", "Movement"]
        case .red:
            preferredTitles = ["HRV", "Resting", "Breathing Overnight", "Oxygen", "Wrist Temp", "Sleep"]
        case .orange:
            preferredTitles = ["Sleep", "Sleep Quality", "HRV", "Resting"]
        }

        let sorted = available.sorted { lhs, rhs in
            let lhsIndex = preferredTitles.firstIndex(of: lhs.title) ?? preferredTitles.count
            let rhsIndex = preferredTitles.firstIndex(of: rhs.title) ?? preferredTitles.count
            return lhsIndex < rhsIndex
        }

        return Array(sorted.prefix(4))
    }

    private func movementValue(for steps: Double) -> String {
        steps >= 1000 ? String(format: "%.1fk", steps / 1000) : Int(steps.rounded()).formatted()
    }

    private func dayDetailTitle(for date: Date) -> String {
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return dayDetailFormatter.string(from: date)
    }

    private var dayDetailFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter
    }
}

private struct CalendarDayDetail: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let subtitle: String
    let state: ColorHealthState?
    let summary: String
    let chips: [ExplanationSignalChip]
    let isToday: Bool
}

private struct AmbientCalendarDayDetailSheet: View {
    let detail: CalendarDayDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(headerTint.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: headerSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(headerTint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.title)
                        .font(.headline.weight(.semibold))
                    Text(detail.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(detail.state?.title ?? "No Data")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(headerTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(headerTint.opacity(0.08), in: Capsule())
            }

            Text(detail.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !detail.chips.isEmpty {
                AmbientExplanationSignalRow(
                    chips: detail.chips,
                    tint: headerTint
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 36)
        .padding(.bottom, 14)
        .presentationBackground(.ultraThinMaterial)
    }

    private var headerTint: Color {
        detail.state?.color ?? Color(red: 0.66, green: 0.70, blue: 0.76)
    }

    private var headerSymbol: String {
        detail.state.map(symbolForState) ?? "tray"
    }
}

private struct AmbientConnectionIndicator: View {
    let status: PiController.ConnectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(color)
    }

    private var symbolName: String {
        switch status {
        case .idle:
            return "circle.dashed"
        case .checking:
            return "wifi"
        case .online:
            return "wifi"
        case .offline:
            return "wifi.slash"
        }
    }

    private var color: Color {
        switch status {
        case .idle:
            return .secondary
        case .checking:
            return .orange
        case .online:
            return .green
        case .offline:
            return .red
        }
    }
}

private struct AmbientStateWheel: View {
    let points: [AmbientHealthStore.StateTrendPoint]

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { entry in
                AmbientSector(
                    startAngle: .degrees(entry.element.startAngle - 90),
                    endAngle: .degrees(entry.element.endAngle - 90)
                )
                .fill(entry.element.state.color.opacity(0.9))
            }

            Circle()
                .fill(Color.black.opacity(0.16))
                .padding(7)
        }
    }

    private var segments: [(state: ColorHealthState, startAngle: Double, endAngle: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        let sortedPoints = mergedTimelinePoints(points.sorted { $0.date < $1.date })

        guard !sortedPoints.isEmpty else { return [] }

        var timeline = sortedPoints.filter { $0.date <= now }

        if timeline.isEmpty, let first = sortedPoints.first {
            timeline = [.init(date: dayStart, state: first.state)]
        } else if let first = timeline.first, first.date > dayStart {
            timeline.insert(.init(date: dayStart, state: first.state), at: 0)
        }

        let totalDuration = max(now.timeIntervalSince(dayStart), 1)
        var angleCursor = 0.0
        var built: [(state: ColorHealthState, startAngle: Double, endAngle: Double)] = []

        for index in timeline.indices {
            let start = max(timeline[index].date, dayStart)
            let nextDate = index + 1 < timeline.count ? min(timeline[index + 1].date, now) : now
            let duration = max(nextDate.timeIntervalSince(start), 0)
            guard duration > 0 || index == timeline.indices.last else { continue }
            let fraction = duration / totalDuration
            let sweep = fraction * 360
            let startAngle = angleCursor
            let endAngle = min(360, angleCursor + sweep)
            built.append((timeline[index].state, startAngle, endAngle))
            angleCursor = endAngle
        }

        if let lastIndex = built.indices.last, built[lastIndex].endAngle < 360 {
            let lastSegment = built[lastIndex]
            built[lastIndex] = (lastSegment.state, lastSegment.startAngle, 360)
        }

        return built
    }

    private func mergedTimelinePoints(_ points: [AmbientHealthStore.StateTrendPoint]) -> [AmbientHealthStore.StateTrendPoint] {
        var merged: [AmbientHealthStore.StateTrendPoint] = []

        for point in points {
            if let last = merged.last, last.state == point.state {
                continue
            }
            merged.append(point)
        }

        return merged
    }
}

private struct AmbientSector: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
