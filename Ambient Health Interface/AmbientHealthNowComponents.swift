import SwiftUI

struct AmbientBackgroundView: View {
    let state: ColorHealthState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(state.color.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(y: -140)
        }
    }
}

struct AmbientNowView: View {
    @ObservedObject var healthStore: AmbientHealthStore

    var body: some View {
        // Keep *Now* intentionally sparse so the object remains the primary readout.
        VStack(spacing: 14) {
            Spacer(minLength: 10)

            AmbientNowCalendarCard(healthStore: healthStore)
            AmbientReferenceView(state: healthStore.currentState)

            VStack(spacing: 8) {
                Text(healthStore.currentState.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(nowLine(for: healthStore.currentState))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }

            AmbientActionButtons(healthStore: healthStore)

            Spacer()
        }
        .safeAreaPadding(.top, 18)
    }
}

private struct AmbientNowCalendarCard: View {
    @ObservedObject var healthStore: AmbientHealthStore

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
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(healthStore.currentState.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(healthStore.currentState.color)
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
                                        points: healthStore.trendReport?.intradayStateTrail ?? [
                                            AmbientHealthStore.StateTrendPoint(date: Date(), state: healthStore.currentState)
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
                                        isToday ? healthStore.currentState.color.opacity(0.45) : stateColor.opacity(0.22),
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 8)
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
        // Non-today circles stay day-based so the week row reads as a broader rhythm, not another detailed-day chart.
        if let trendPoint = healthStore.trendReport?.stateTrail.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return trendPoint.state.color
        }

        if calendar.isDateInToday(date) {
            return healthStore.currentState.color
        }

        return Color.white
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
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            } else {
                Button {
                    Task {
                        // Refresh pulls a fresh snapshot and recomputes the ambient state from live Health data.
                        await healthStore.refresh()
                    }
                } label: {
                    Text(healthStore.isRefreshing ? "Refreshing..." : "Refresh")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(.borderedProminent)
                .disabled(healthStore.isRefreshing)
            }

        }
        .padding(.top, 2)
    }
}
