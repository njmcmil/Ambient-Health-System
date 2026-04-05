import SwiftUI

struct AmbientBackgroundView: View {
    let state: ColorHealthState
    let reduceIntensity: Bool

    private var auraFactor: Double { reduceIntensity ? 0.62 : 1.0 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground).opacity(0.99),
                    state.color.opacity(0.018 * auraFactor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(state.color.opacity(0.06 * auraFactor))
                .frame(width: 310, height: 310)
                .blur(radius: reduceIntensity ? 54 : 64)
                .offset(x: -18, y: -156)

            Circle()
                .fill(Color.white.opacity(reduceIntensity ? 0.020 : 0.035))
                .frame(width: 190, height: 190)
                .blur(radius: reduceIntensity ? 34 : 42)
                .offset(x: 90, y: -186)

            Ellipse()
                .fill(state.color.opacity(0.028 * auraFactor))
                .frame(width: 360, height: 190)
                .blur(radius: reduceIntensity ? 62 : 76)
                .offset(x: 60, y: 292)
        }
    }
}

struct AmbientNowView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    let reduceIntensity: Bool

    var body: some View {
        // Keep *Now* intentionally sparse so the object remains the primary readout.
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            AmbientNowCalendarCard(healthStore: healthStore)
            Spacer(minLength: 10)
            AmbientReferenceView(
                state: healthStore.displayedState,
                reduceIntensity: reduceIntensity
            )
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text(healthStore.displayedState.title)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .tracking(0.2)
                    .foregroundStyle(.primary)

                if healthStore.previewState != nil {
                    Text("Preview Mode")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(healthStore.displayedState.color.opacity(0.9))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(healthStore.displayedState.color.opacity(0.12), in: Capsule())
                }

                Text(nowLine(for: healthStore.displayedState))
                    .font(.callout)
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 270)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 14)

            AmbientActionButtons(healthStore: healthStore)

            Spacer()
        }
        .safeAreaPadding(.top, 10)
    }
}

private struct AmbientNowCalendarCard: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @ObservedObject private var piController = PiController.shared

    private let calendar = Calendar.current

    var body: some View {
        // This card combines weekly state memory with a small read for today.
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

            VStack(alignment: .leading, spacing: 12) {
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
                                    // Today's wheel shows the flow of states through the day, not just a single summary color.
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
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: Date())
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE d")
        return formatter.string(from: Date())
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter.string(from: date)
    }

    private func color(for date: Date) -> Color {
        if let previewState = healthStore.previewState {
            return previewState.color
        }

        // Non-today circles stay day-based so the week row reads as a broader rhythm, not another detailed-day chart.
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

        // Match the outer ring to the most recent state in today's wheel so the day marker
        // does not look split between two unrelated moods.
        return points.last?.state.color ?? healthStore.displayedState.color
    }

    private var previewWheelPoints: [AmbientHealthStore.StateTrendPoint]? {
        guard let previewState = healthStore.previewState else { return nil }
        return (0..<6).map { index in
            AmbientHealthStore.StateTrendPoint(
                date: Calendar.current.date(byAdding: .hour, value: index * 3, to: Date()) ?? Date(),
                state: previewState
            )
        }
    }
}

private struct AmbientConnectionIndicator: View {
    let status: PiController.ConnectionStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(indicatorColor.opacity(0.92))
                .frame(width: 7, height: 7)
                .overlay {
                    Circle()
                        .stroke(indicatorColor.opacity(status == .checking ? 0.55 : 0.40), lineWidth: 3)
                        .blur(radius: 1)
                }

            Image(systemName: indicatorSymbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(indicatorColor.opacity(0.88))
        }
    }

    private var indicatorColor: Color {
        switch status {
        case .idle:
            return Color(red: 0.70, green: 0.77, blue: 0.84)
        case .checking:
            return Color(red: 0.91, green: 0.73, blue: 0.42)
        case .online:
            return .green
        case .offline:
            return Color(red: 0.92, green: 0.42, blue: 0.44)
        }
    }

    private var indicatorSymbol: String {
        switch status {
        case .idle:
            return "circle.dotted"
        case .checking:
            return "dot.radiowaves.up.forward"
        case .online:
            return "dot.radiowaves.up.forward"
        case .offline:
            return "bolt.slash.fill"
        }
    }
}

private struct AmbientStateWheel: View {
    let points: [AmbientHealthStore.StateTrendPoint]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))

            // Each wedge represents one state segment in chronological order.
            ForEach(Array(points.enumerated()), id: \.offset) { entry in
                let count = max(points.count, 1)
                let startAngle = Angle.degrees((Double(entry.offset) / Double(count)) * 360 - 90)
                let endAngle = Angle.degrees((Double(entry.offset + 1) / Double(count)) * 360 - 90)

                AmbientSector(startAngle: startAngle, endAngle: endAngle)
                    .fill(entry.element.state.color.opacity(0.58))
            }
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
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct AmbientMiniMetricChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.16),
                    tint.opacity(0.10),
                    Color.white.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private struct AmbientActionButtons: View {
    @ObservedObject var healthStore: AmbientHealthStore

    var body: some View {
        HStack(spacing: 10) {
            if healthStore.authorizationState == .unavailable {
                Text("HealthKit needs a physical iPhone")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.thinMaterial, in: Capsule())
            } else if healthStore.canRequestAuthorization {
                // Connection stays on the home screen because it is part of first-run setup, not deep settings.
                Button {
                    Task {
                        await healthStore.requestAuthorization()
                    }
                } label: {
                    Text("Connect Health")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(.borderedProminent)
            } else if healthStore.isRefreshing {
                Text("Refreshing Apple Health...")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.thinMaterial, in: Capsule())
            }

        }
        .padding(.top, 2)
    }
}
