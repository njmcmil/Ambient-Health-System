import SwiftUI

/// Weekly context card for the Now view, including today's state wheel and ambient object status.
struct AmbientNowCalendarCard: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @ObservedObject private var piController = PiController.shared

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

            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { date in
                    let isToday = calendar.isDateInToday(date)
                    let stateColor = color(for: date)

                    VStack(spacing: 6) {
                        Text(shortWeekday(for: date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ZStack {
                            if isToday {
                                AmbientStateWheel(
                                    points: previewWheelPoints ?? healthStore.trendReport?.intradayStateTrail ?? [
                                        AmbientHealthStore.StateTrendPoint(date: Date(), state: healthStore.displayedState)
                                    ]
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
                                .foregroundStyle(isToday ? .white : .primary)
                        }
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle()
                                .stroke(
                                    isToday ? todayWheelAccentColor.opacity(0.45) : stateColor.opacity(0.22),
                                    lineWidth: isToday ? 1.2 : 0.9
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
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

    private var weekDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let offsetToStart = (weekday - calendar.firstWeekday + 7) % 7
        let startOfWeek = calendar.date(byAdding: .day, value: -offsetToStart, to: today) ?? today
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

    private func color(for date: Date) -> Color {
        if let previewState = healthStore.previewState {
            return previewState.color
        }

        if let trendPoint = healthStore.trendReport?.stateTrail.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return trendPoint.state.color
        }

        if calendar.isDateInToday(date) {
            return healthStore.displayedState.color
        }

        return Color.white
    }

    private var todayWheelAccentColor: Color {
        if let previewState = healthStore.previewState {
            return previewState.color
        }

        guard let points = healthStore.trendReport?.intradayStateTrail, !points.isEmpty else {
            return healthStore.displayedState.color
        }

        return points.last?.state.color ?? healthStore.displayedState.color
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
            return "circle.dotted"
        case .checking:
            return "dot.radiowaves.left.and.right"
        case .online:
            return "dot.radiowaves.left.and.right"
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
            ForEach(Array(points.enumerated()), id: \.offset) { entry in
                AmbientSector(
                    startAngle: .degrees(Double(entry.offset) / Double(max(points.count, 1)) * 360 - 90),
                    endAngle: .degrees(Double(entry.offset + 1) / Double(max(points.count, 1)) * 360 - 90)
                )
                .fill(entry.element.state.color.opacity(0.9))
            }

            Circle()
                .fill(Color.black.opacity(0.16))
                .padding(7)
        }
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
