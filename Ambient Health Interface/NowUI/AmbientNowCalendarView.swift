import SwiftUI

/// Weekly context card for the Now view, including today's state wheel and ambient object status.
struct AmbientNowCalendarCard: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @ObservedObject private var piController = PiController.shared
    @State private var selectedWeekOffset = 0

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

                    Text(healthStore.displayedState.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(healthStore.displayedState.color)
                }
            }

            TabView(selection: $selectedWeekOffset) {
                ForEach([2, 1, 0], id: \.self) { offset in
                    HStack(spacing: 8) {
                        ForEach(weekDates(for: offset), id: \.self) { date in
                            let isToday = calendar.isDateInToday(date)
                            let stateColor = color(for: date)

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
                                    if isToday && offset == 0 {
                                        AmbientStateWheel(
                                            points: previewWheelPoints
                                                ?? (healthStore.liveIntradayStateTrail.isEmpty
                                                    ? [AmbientHealthStore.StateTrendPoint(date: Date(), state: healthStore.displayedState)]
                                                    : healthStore.liveIntradayStateTrail)
                                        )
                                        .frame(width: 30, height: 30)
                                    } else {
                                        Circle()
                                            .fill(stateColor.opacity(0.12))
                                            .overlay {
                                                Circle()
                                                    .fill(stateColor.opacity(0.38))
                                                    .padding(5)
                                            }
                                    }

                                    Text(dayNumber(for: date))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(isToday && offset == 0 ? .white : .primary)
                                }
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            isToday && offset == 0 ? todayWheelAccentColor.opacity(0.45) : stateColor.opacity(0.22),
                                            lineWidth: isToday && offset == 0 ? 1.2 : 0.9
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
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
    }

    private var cardFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.10),
                healthStore.displayedState.color.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func weekDates(for offset: Int) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let offsetToStart = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -offsetToStart, to: today) ?? today
        let startOfWeek = calendar.date(byAdding: .day, value: -(offset * 7), to: currentWeekStart) ?? currentWeekStart
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
        calendar.component(.weekday, from: date) == calendar.component(.weekday, from: Date())
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

        if calendar.isDateInToday(date) {
            return healthStore.displayedState.color
        }

        if let trendPoint = healthStore.liveCalendarStateTrail.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return trendPoint.state.color
        }

        return Color.white
    }

    private var todayWheelAccentColor: Color {
        if let previewState = healthStore.previewState {
            return previewState.color
        }

        guard !healthStore.liveIntradayStateTrail.isEmpty else {
            return healthStore.displayedState.color
        }

        return healthStore.liveIntradayStateTrail.last?.state.color ?? healthStore.displayedState.color
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
        let sortedPoints = points.sorted { $0.date < $1.date }

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
