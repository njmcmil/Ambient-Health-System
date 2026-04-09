import SwiftUI

/// Explains the current state in plain language and adapts between live and preview modes.
struct AmbientExplanationView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @AppStorage("anxietyCalmerMode") private var calmerModeEnabled = false
    @AppStorage("accessibilityReduceMotion") private var reduceMotionEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Explanation")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 10) {
                    AmbientSectionHeader(
                        title: explanationHeaderTitle,
                        symbol: explanationHeaderSymbol,
                        tint: explanationHeaderTint,
                        animateSymbol: !reduceMotionEnabled
                    )

                    let chips = healthStore.previewState.map(previewSignalChips(for:))
                        ?? (healthStore.hasMeaningfulCurrentRead
                            ? explanationSignalChips(snapshot: healthStore.latestSnapshot, state: healthStore.displayedState)
                            : [])
                    if !calmerModeEnabled {
                        if !chips.isEmpty {
                            AmbientExplanationSignalRow(
                                chips: chips,
                                tint: healthStore.displayedState.color
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Most Relevant Signals")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text("No recent data yet for today's read.")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.top, 4)
                        }

                        if healthStore.previewState == nil {
                            Text(currentReadFootnote)
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.78))
                        }
                    }

                    if healthStore.previewState != nil {
                        Text("Preview mode is on. This page is showing an example read for the selected state, not your live health interpretation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    AmbientSectionHeader(
                        title: "What This May Mean",
                        symbol: "text.bubble.fill",
                        tint: Color(red: 0.49, green: 0.72, blue: 0.96)
                    )

                    let bullets = explanationBulletContent

                    ForEach(bullets, id: \.self) { bullet in
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
                                symbol: "brain.head.profile",
                                tint: Color(red: 0.49, green: 0.72, blue: 0.96)
                            )

                            Spacer()

                            AmbientInsightHistoryTrail(history: historyTrail)
                        }

                        Text(patternInsightText)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("Based on your recent pattern (weekly context).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    }
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.bottom, 40)
        }
    }

    private var historyTrail: [ColorHealthState] {
        if let previewState = healthStore.previewState {
            return Array(repeating: previewState, count: max(healthStore.history.count, 6))
        }
        if !healthStore.liveCalendarStateTrail.isEmpty {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let currentDayStart = healthStore.hasMeaningfulCurrentRead ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

            let states = (0..<7).compactMap { offset -> ColorHealthState? in
                let day = calendar.date(byAdding: .day, value: -(6 - offset), to: currentDayStart) ?? currentDayStart
                if healthStore.hasMeaningfulCurrentRead, calendar.isDateInToday(day) {
                    return healthStore.displayedState
                }
                return healthStore.liveCalendarStateTrail.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.state
            }

            if !states.isEmpty {
                return states
            }
        }
        return healthStore.history
    }

    private var explanationBulletContent: [String] {
        if let previewState = healthStore.previewState {
            return calmerModeEnabled
                ? calmerGenericExplanationBullets(for: previewState)
                : genericExplanationBullets(for: previewState)
        }

        if !healthStore.hasMeaningfulCurrentRead {
            return [
                "No recent Apple Health data has landed for today yet, so the app is waiting for today's first meaningful signals before interpreting a live state."
            ]
        }

        return calmerModeEnabled
            ? calmerExplanationBullets(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot, baseline: healthStore.baselineSummary)
            : explanationBullets(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot, baseline: healthStore.baselineSummary)
    }

    private var patternInsightText: String {
        if let previewState = healthStore.previewState {
            return calmerModeEnabled
                ? calmerPatternInsight(for: previewState, snapshot: nil)
                : patternInsight(for: previewState, snapshot: nil)
        }

        if !healthStore.hasMeaningfulCurrentRead {
            return "No recent data yet for today's live read. Weekly context is still visible, but today's state will settle once new signals arrive."
        }

        return calmerModeEnabled
            ? calmerPatternInsight(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot, baseline: healthStore.baselineSummary)
            : patternInsight(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot, baseline: healthStore.baselineSummary)
    }

    private var currentReadFootnote: String {
        guard let snapshot = healthStore.latestSnapshot else {
            return "No recent data yet for today's read."
        }

        let missingCoreSignals = [
            snapshot.sleepHours == nil && snapshot.sleepStages == nil,
            snapshot.heartRateVariability == nil,
            snapshot.restingHeartRate == nil,
            snapshot.respiratoryRate == nil
        ]
        .filter { $0 }
        .count

        if missingCoreSignals >= 3 {
            return "No recent data yet for most of today's read, so this state is based on limited signals so far."
        }

        if missingCoreSignals >= 1 {
            return "Some recent data for today has not arrived yet, so this read is based on limited signals so far."
        }

        return "Based on your current read."
    }

    private var explanationHeaderTitle: String {
        if healthStore.previewState != nil || healthStore.hasMeaningfulCurrentRead {
            return healthStore.displayedState.title
        }

        return "No Data Yet"
    }

    private var explanationHeaderSymbol: String {
        if healthStore.previewState != nil || healthStore.hasMeaningfulCurrentRead {
            return symbolForState(healthStore.displayedState)
        }

        return "tray"
    }

    private var explanationHeaderTint: Color {
        if healthStore.previewState != nil || healthStore.hasMeaningfulCurrentRead {
            return healthStore.displayedState.color
        }

        return Color(red: 0.66, green: 0.70, blue: 0.76)
    }

}
