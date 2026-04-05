import SwiftUI

/// Explains the current state in plain language and adapts between live and preview modes.
struct AmbientExplanationView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @AppStorage("anxietyCalmerMode") private var calmerModeEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Explanation")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 10) {
                    AmbientSectionHeader(
                        title: healthStore.displayedState.title,
                        symbol: symbolForState(healthStore.displayedState),
                        tint: healthStore.displayedState.color
                    )

                    let chips = healthStore.previewState.map(previewSignalChips(for:)) ?? explanationSignalChips(snapshot: healthStore.latestSnapshot)
                    if !calmerModeEnabled, !chips.isEmpty {
                        AmbientExplanationSignalRow(
                            chips: chips,
                            tint: healthStore.displayedState.color
                        )
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
                        symbol: "sparkles",
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
                                symbol: "text.magnifyingglass",
                                tint: Color(red: 0.49, green: 0.72, blue: 0.96)
                            )

                            Spacer()

                            AmbientInsightHistoryTrail(history: historyTrail)
                        }

                        Text(patternInsightText)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(patternInsightCaption)
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

    private var historyTrail: [ColorHealthState] {
        if let previewState = healthStore.previewState {
            return Array(repeating: previewState, count: max(healthStore.history.count, 6))
        }
        return healthStore.history
    }

    private var explanationBulletContent: [String] {
        if let previewState = healthStore.previewState {
            return calmerModeEnabled
                ? calmerGenericExplanationBullets(for: previewState)
                : genericExplanationBullets(for: previewState)
        }

        return calmerModeEnabled
            ? calmerExplanationBullets(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
            : explanationBullets(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
    }

    private var patternInsightText: String {
        if let previewState = healthStore.previewState {
            return calmerModeEnabled
                ? calmerPatternInsight(for: previewState, snapshot: nil)
                : patternInsight(for: previewState, snapshot: nil)
        }

        return calmerModeEnabled
            ? calmerPatternInsight(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
            : patternInsight(for: healthStore.displayedState, snapshot: healthStore.latestSnapshot)
    }

    private var patternInsightCaption: String {
        if healthStore.previewState != nil {
            return calmerModeEnabled
                ? "A gentler example of how this state can show up."
                : "A plain-language read on how this state usually feels in the app."
        }

        return calmerModeEnabled
            ? "A softer explanation based on your recent pattern and your usual rhythm."
            : "Based on recent health patterns and how they compare to your usual rhythm."
    }
}
