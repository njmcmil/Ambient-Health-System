import SwiftUI

/// Holds the app's more explicit and inspectable settings surfaces.
/// The Now view stays ambient; this file owns the controls behind preview,
/// accessibility, sensitivity, and HealthKit status.
struct AmbientSettingsView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    @Binding var stressSensitivity: Double
    @Binding var movementSensitivity: Double
    @Binding var recoverySensitivity: Double
    @Binding var overallResponsiveness: Double
    @Binding var calmerModeEnabled: Bool
    @Binding var reduceMotionEnabled: Bool
    @Binding var largerTextEnabled: Bool
    @Binding var higherContrastEnabled: Bool
    let resetToDefault: () -> Void
    @State private var showsAccessibilitySection = false
    @State private var showsHealthKitSection = false
    @State private var showsStatePreviewSection = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))

                    Spacer()

                    Label("Scroll for more", systemImage: "arrow.up.and.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Each slider below changes how easily a specific mood shows up. Move it up if you want that mood to appear more easily. Move it down if the app is calling that mood too often.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                AmbientSensitivityControlCard(
                    preset: sensitivityPresetBinding,
                    selectedPreset: healthStore.sensitivityPreset,
                    stressSensitivity: $stressSensitivity,
                    movementSensitivity: $movementSensitivity,
                    recoverySensitivity: $recoverySensitivity,
                    overallResponsiveness: $overallResponsiveness,
                    calmerModeEnabled: calmerModeEnabled,
                    presetDescription: presetDescription(for: healthStore.sensitivityPreset),
                    resetToDefault: resetToDefault
                )

                DisclosureGroup(isExpanded: $showsAccessibilitySection) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Use this if bright glows, fast motion, or agitated states feel like too much. It softens the visual layer without changing your actual health state or the mood logic underneath.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        AmbientAccessibilityToggleCard(
                            title: "Calmer Mode",
                            subtitle: "Reduce glow, motion, and visual intensity across the app.",
                            isOn: $calmerModeEnabled
                        )

                        AmbientAccessibilityToggleCard(
                            title: "Reduce Motion",
                            subtitle: "Minimize movement and animated transitions while keeping the same data and mood logic.",
                            isOn: $reduceMotionEnabled
                        )

                        AmbientAccessibilityToggleCard(
                            title: "Larger Text",
                            subtitle: "Use larger type across screens for easier reading.",
                            isOn: $largerTextEnabled
                        )

                        AmbientAccessibilityToggleCard(
                            title: "Higher Contrast",
                            subtitle: "Increase visual contrast so labels and cards are easier to distinguish.",
                            isOn: $higherContrastEnabled
                        )

                        Text(calmerModeEnabled
                             ? "Calmer Mode is on. The app keeps the same health read, but tones down the aura, motion, and stronger distressed visuals."
                             : "Calmer Mode is off. The app uses its full ambient motion and brightness range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if reduceMotionEnabled || largerTextEnabled || higherContrastEnabled {
                            Text("Extra accessibility options are active. These only change presentation, not your health-state analysis.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility")
                            .font(.headline)

                        Text(accessibilitySummaryLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .ambientPanel(tint: Color(red: 0.49, green: 0.72, blue: 0.96))

                DisclosureGroup(isExpanded: $showsStatePreviewSection) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Preview a mood state on the phone and read the kind of health pattern that would usually create it. This does not change live data or send a fake state out.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(ColorHealthState.allCases) { state in
                                Button {
                                    healthStore.setPreviewState(healthStore.previewState == state ? nil : state)
                                } label: {
                                    Text(state.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(healthStore.previewState == state ? .primary : .secondary)
                                        .padding(.horizontal, 12)
                                        .frame(height: 34)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(healthStore.previewState == state ? state.color.opacity(0.22) : Color.white.opacity(0.08))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let previewState = healthStore.previewState {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(previewState.color)
                                        .frame(width: 8, height: 8)

                                    Text("Previewing \(previewState.title)")
                                        .font(.subheadline.weight(.semibold))
                                }

                                Text(calmerModeEnabled ? calmerStateExampleScenario(for: previewState) : patternInsight(for: previewState, snapshot: nil))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Text(sensitivityEffectLine(for: previewState, profile: healthStore.sensitivityProfile))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.primary.opacity(0.88))

                                Button("Return to Live State") {
                                    healthStore.setPreviewState(nil)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("State Preview")
                            .font(.headline)

                        Text(healthStore.previewState == nil ? "Expand to test how each mood state looks and read an example health pattern for it." : "Previewing \(healthStore.previewState?.title ?? "").")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .ambientPanel(tint: healthStore.previewState?.color ?? Color(red: 0.49, green: 0.72, blue: 0.96))

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
                .ambientPanel(tint: Color.white)
            }
            .padding(.bottom, 140)
        }
        .scrollIndicators(.visible)
        .safeAreaPadding(.bottom, 8)
    }

    private var sensitivityPresetBinding: Binding<AmbientHealthStore.SensitivityPreset> {
        Binding(
            get: { healthStore.sensitivityPreset },
            set: { preset in
                healthStore.applySensitivityPreset(preset)
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
            return "This waits for stronger evidence before a mood changes."
        case .recommended:
            return "This is the balanced starting point for most people."
        case .responsive:
            return "This lets moods show up sooner if the app feels too muted."
        case .custom:
            return "You changed the sliders yourself. Each one only affects the mood written under it."
        }
    }

    private var healthKitSectionSummary: String {
        "\(healthStore.authorizationState.title). Expand to inspect available signals and connection details."
    }

    private var accessibilitySummaryLine: String {
        var enabled: [String] = []
        if calmerModeEnabled { enabled.append("Calmer Mode") }
        if reduceMotionEnabled { enabled.append("Reduce Motion") }
        if largerTextEnabled { enabled.append("Larger Text") }
        if higherContrastEnabled { enabled.append("Higher Contrast") }

        if enabled.isEmpty {
            return "Expand for visual accessibility options that make the app easier to read and process."
        }

        return "Active: \(enabled.joined(separator: ", "))"
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

private struct AmbientSensitivityControlCard: View {
    @Binding var preset: AmbientHealthStore.SensitivityPreset
    let selectedPreset: AmbientHealthStore.SensitivityPreset
    @Binding var stressSensitivity: Double
    @Binding var movementSensitivity: Double
    @Binding var recoverySensitivity: Double
    @Binding var overallResponsiveness: Double
    let calmerModeEnabled: Bool
    let presetDescription: String
    let resetToDefault: () -> Void
    @State private var showsSensitivityGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood Sensitivity")
                        .font(.headline)

                    Text(calmerModeEnabled
                         ? "Use these only if one mood feels clearly too present or not present enough."
                         : "Each slider changes how easily that health state appears. Move it up if the app is missing that state. Move it down if the app is showing that state too often.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    resetToDefault()
                } label: {
                    Text("Recommended")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(AmbientHealthStore.SensitivityPreset.allCases.filter { $0 != .custom }) { item in
                    Button {
                        preset = item
                    } label: {
                        Text(item.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedPreset == item ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                Capsule()
                                    .fill(selectedPreset == item ? Color.white.opacity(0.58) : Color.white.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(presetDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            DisclosureGroup(isExpanded: $showsSensitivityGuide) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calmerModeEnabled
                         ? "Move a slider up if you want that mood to show more easily. Move it down if it is showing more than feels right."
                         : "Move a slider up if you want that health state to show more easily. Move it down if the app is showing that state too often.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Use the small line under each slider as a rough guide. It shows the kind of sleep, movement, or recovery pattern that slider is reacting to.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(calmerModeEnabled
                         ? "Low Energy mostly follows movement. Sleep + Recovery mostly follows sleep and recovery, especially for restored or drained states."
                         : "Low Energy mostly follows movement. Restored / Drained mostly follows sleep and recovery, especially when that story is stronger than movement.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(calmerModeEnabled
                         ? "Overall Sensitivity changes how quickly the whole app reacts. Lower feels steadier. Higher feels quicker."
                         : "Overall Sensitivity changes how quickly any mood can replace another. Lower feels steadier. Higher feels more reactive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } label: {
                Text("Quick guide")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .ambientSubpanel(tint: Color.white)

            if calmerModeEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    AmbientSensitivitySliderRow(
                        title: "Stressed",
                        subtitle: "Lower if stressed shows too often. Raise if stressed is being missed.",
                        tint: ColorHealthState.purple.color,
                        lowLabel: "Less",
                        highLabel: "More",
                        value: $stressSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                    AmbientSensitivitySliderRow(
                        title: "Low Energy",
                        subtitle: "Lower if low movement is affecting the result too much.",
                        tint: ColorHealthState.yellow.color,
                        lowLabel: "Less",
                        highLabel: "More",
                        value: $movementSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                    AmbientSensitivitySliderRow(
                        title: "Sleep + Recovery",
                        subtitle: "Lower if recovery is affecting the result too much.",
                        tint: ColorHealthState.orange.color,
                        secondaryTint: ColorHealthState.blue.color,
                        lowLabel: "Less",
                        highLabel: "More",
                        value: $recoverySensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                    AmbientSensitivitySliderRow(
                        title: "Overall Sensitivity",
                        subtitle: "Lower if every mood changes too easily. Raise if the whole app feels muted.",
                        tint: Color(red: 0.49, green: 0.72, blue: 0.96),
                        lowLabel: "Calmer",
                        highLabel: "Quicker",
                        value: $overallResponsiveness,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: true
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    AmbientSensitivitySliderRow(
                        title: "Stressed",
                        subtitle: "Use this if the app is missing stressed moments, or calling stressed too often.",
                        tint: ColorHealthState.purple.color,
                        lowLabel: "Shows less",
                        highLabel: "Shows more",
                        value: $stressSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                    AmbientSensitivitySliderRow(
                        title: "Low Energy",
                        subtitle: "Use this for low movement and quiet momentum days.",
                        tint: ColorHealthState.yellow.color,
                        lowLabel: "Shows less",
                        highLabel: "Shows more",
                        value: $movementSensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                    AmbientSensitivitySliderRow(
                        title: "Restored / Drained",
                        subtitle: "Use this for sleep and recovery states, especially Restored and Drained.",
                        tint: ColorHealthState.orange.color,
                        secondaryTint: ColorHealthState.blue.color,
                        lowLabel: "Matters less",
                        highLabel: "Matters more",
                        value: $recoverySensitivity,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                    AmbientSensitivitySliderRow(
                        title: "Overall Sensitivity",
                        subtitle: "Use this only if every mood feels too muted overall, or if the whole app changes too easily.",
                        tint: Color(red: 0.49, green: 0.72, blue: 0.96),
                        lowLabel: "Slower",
                        highLabel: "Faster",
                        value: $overallResponsiveness,
                        overallValue: overallResponsiveness,
                        calmerModeEnabled: false
                    )
                }
            }

            Text(calmerModeEnabled
                 ? "If you change something here, adjust only one slider and then give it a little time."
                 : "Change one slider at a time, then use the app for a bit before changing another.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Workout-aware stress handling is still on. Exercise only softens stress reads during active workouts and a short recovery window after.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .ambientPanel(tint: Color(red: 0.49, green: 0.72, blue: 0.96))
    }
}

private struct AmbientSensitivitySliderRow: View {
    let title: String
    let subtitle: String
    let tint: Color
    var secondaryTint: Color? = nil
    let lowLabel: String
    let highLabel: String
    @Binding var value: Double
    let overallValue: Double
    let calmerModeEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(levelLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(sliderTint)
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Text(lowLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(highLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)

                Slider(value: $value, in: 0...1)
                    .tint(sliderTint)

                AmbientSensitivityScale(
                    labels: scaleLabels,
                    currentLabel: currentScaleLabel,
                    progress: value,
                    tint: sliderTint
                )

                Text(scaleLegend)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .ambientSubpanel(tint: sliderTint)
    }

    private var sliderTint: Color {
        let clamped = min(max(value, 0), 1)
        if let secondaryTint {
            if clamped < 0.5 {
                let progress = clamped / 0.5
                return softenedColor(from: secondaryTint, amount: 1 - progress)
            } else {
                let progress = (clamped - 0.5) / 0.5
                return softenedColor(from: tint, amount: 1 - progress)
            }
        }
        return softenedColor(from: tint, amount: 1 - clamped)
    }

    private var levelLabel: String {
        switch value {
        case ..<0.30:
            return "Low"
        case ..<0.45:
            return "Light"
        case ..<0.62:
            return "Balanced"
        case ..<0.78:
            return "Stronger"
        default:
            return "Max"
        }
    }

    private var scaleLabels: [String] {
        switch title {
        case "Stressed":
            return ["86 bpm / 26 ms", "84 bpm / 28 ms", "82 bpm / 30 ms", "80 bpm / 31 ms", "78 bpm / 33 ms"]
        case "Low Energy":
            return ["1.6k / 8 min", "2.0k / 10 min", "2.3k / 13 min", "2.7k / 15 min", "3.0k / 18 min"]
        case "Restored / Drained", "Sleep + Recovery":
            return ["5.4h / 20 ms", "5.7h / 22 ms", "5.9h / 24 ms", "6.1h / 26 ms", "6.4h / 28 ms"]
        case "Overall Sensitivity":
            return calmerModeEnabled
                ? ["waits", "gentle", "balanced", "quick", "sooner"]
                : ["stricter", "gentle", "balanced", "reactive", "sooner"]
        default:
            return ["", "", "", "", ""]
        }
    }

    private var currentScaleLabel: String {
        let clamped = min(max(value, 0), 1)
        switch title {
        case "Stressed":
            let resting = Int(86 + (78 - 86) * clamped)
            let hrv = Int(26 + (33 - 26) * clamped)
            return "\(resting) bpm / \(hrv) ms"
        case "Low Energy":
            let steps = Int(1600 + (3000 - 1600) * clamped)
            let exercise = Int(8 + (18 - 8) * clamped)
            return "\(String(format: "%.1fk", Double(steps) / 1000)) / \(exercise) min"
        case "Restored / Drained", "Sleep + Recovery":
            let sleep = 5.4 + (6.4 - 5.4) * clamped
            let hrv = Int(20 + (28 - 20) * clamped)
            return "\(String(format: "%.1f", sleep))h / \(hrv) ms"
        case "Overall Sensitivity":
            switch clamped {
            case ..<0.20:
                return "very steady"
            case ..<0.40:
                return "steadier"
            case ..<0.60:
                return "balanced"
            case ..<0.80:
                return "more reactive"
            default:
                return "most reactive"
            }
        default:
            return ""
        }
    }

    private var scaleLegend: String {
        switch title {
        case "Stressed":
            return "On this line, bpm means resting heart rate and ms means heart-rate variability."
        case "Low Energy":
            return "On this line, the first number is steps and min means exercise minutes."
        case "Restored / Drained", "Sleep + Recovery":
            return "On this line, h means hours of sleep and ms means heart-rate variability."
        case "Overall Sensitivity":
            return "This line shows how steady or reactive the whole app is overall."
        default:
            return ""
        }
    }

    private func softenedColor(from base: Color, amount: Double) -> Color {
        let clamped = min(max(amount, 0), 1)
        let ui = UIColor(base)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return base.opacity(0.25 + ((1 - clamped) * 0.75))
        }

        let mix = CGFloat(clamped * 0.78)
        let softenedRed = red + ((1 - red) * mix)
        let softenedGreen = green + ((1 - green) * mix)
        let softenedBlue = blue + ((1 - blue) * mix)

        return Color(
            .sRGB,
            red: Double(softenedRed),
            green: Double(softenedGreen),
            blue: Double(softenedBlue),
            opacity: 1
        )
    }
}
