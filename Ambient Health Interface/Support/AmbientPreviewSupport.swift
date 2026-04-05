import SwiftUI

/// Preview examples and small signal summaries used by settings and explanation screens.
func stateExampleScenario(for state: ColorHealthState) -> String {
    switch state {
    case .blue:
        return "Example: sleep 7.8-8.4 h, deep sleep about 16-22%, REM about 20-26%, HRV about 50-60 ms, resting heart rate about 56-62 bpm."
    case .green:
        return "Example: sleep 7.0-7.8 h, HRV about 42-50 ms, resting heart rate about 62-68 bpm, steps 6.5k-9k, exercise 20-35 min."
    case .yellow:
        return "Example: sleep and cardio stay near baseline, but later-day movement stays low, like steps 2k-3.5k and exercise under 12 min."
    case .purple:
        return "Example: HRV about 24-30 ms, resting heart rate about 78-84 bpm, breathing about 17-19/min, and no workout explaining the strain."
    case .gray:
        return "Example: sleep, HRV, resting heart rate, breathing, and movement all sit close to your own baseline without one pattern standing out."
    case .red:
        return "Example: HRV under about 22 ms, resting heart rate about 84-92 bpm, breathing about 19-21/min, plus temperature or oxygen concerns."
    case .orange:
        return "Example: sleep about 5.2-6.0 h or fragmented for a few nights, awake time about 14-20%, HRV about 24-34 ms, resting heart rate about 72-80 bpm."
    }
}

func calmerStateExampleScenario(for state: ColorHealthState) -> String {
    switch state {
    case .blue:
        return "Example: sleep and recovery both look a little more supportive than usual, so the overall pattern feels more restored."
    case .green:
        return "Example: sleep, movement, and recovery all look fairly steady without one signal pulling too hard."
    case .yellow:
        return "Example: movement looks quieter than usual later in the day, so the pattern leans more low-energy than stressed."
    case .purple:
        return "Example: a few signals look more activated than your normal baseline, with no workout clearly explaining it."
    case .gray:
        return "Example: most signals stay close to baseline and the system does not see a strong pull toward another state."
    case .red:
        return "Example: several strain-related signals rise together, so the system treats the overall pattern as more intense."
    case .orange:
        return "Example: sleep and recovery both look less supportive for a bit, so the pattern leans more drained than activated."
    }
}

func sensitivityEffectLine(
    for state: ColorHealthState,
    profile: AmbientHealthStore.SensitivityProfile
) -> String {
    let relevant: Double = {
        switch state {
        case .blue, .orange:
            return profile.recovery
        case .green, .gray:
            return profile.overall
        case .yellow:
            return profile.movement
        case .purple, .red:
            return profile.stress
        }
    }()

    let combined = (relevant * 0.82) + (profile.overall * 0.18)

    switch state {
    case .blue:
        if combined >= 0.72 {
            return "With your current sensitivity, restored would be recognized a little sooner."
        } else if combined <= 0.44 {
            return "With your current sensitivity, restored would need clearer recovery before it appears."
        } else {
            return "With your current sensitivity, restored is being judged at a balanced level."
        }
    case .green:
        if combined >= 0.72 {
            return "With your current sensitivity, grounded would be recognized a little sooner."
        } else if combined <= 0.44 {
            return "With your current sensitivity, grounded would need steadier support before it appears."
        } else {
            return "With your current sensitivity, grounded is being judged at a balanced level."
        }
    case .yellow:
        if combined >= 0.72 {
            return "With your current sensitivity, low energy would be called a little sooner from lower movement."
        } else if combined <= 0.44 {
            return "With your current sensitivity, low energy would need quieter movement before it appears."
        } else {
            return "With your current sensitivity, low energy is being judged at a balanced level."
        }
    case .purple:
        if combined >= 0.72 {
            return "With your current sensitivity, stressed would be called a little sooner."
        } else if combined <= 0.44 {
            return "With your current sensitivity, stressed would need stronger strain signals before it appears."
        } else {
            return "With your current sensitivity, stressed is being judged at a balanced level."
        }
    case .gray:
        if profile.overall >= 0.72 {
            return "With your current sensitivity, neutral is less likely to hold for long before another mood takes over."
        } else if profile.overall <= 0.44 {
            return "With your current sensitivity, neutral is more likely to hold while changes settle."
        } else {
            return "With your current sensitivity, neutral is being held at a balanced level."
        }
    case .red:
        if combined >= 0.72 {
            return "With your current sensitivity, overloaded would be called a little sooner when high-strain markers stack."
        } else if combined <= 0.44 {
            return "With your current sensitivity, overloaded would need clearer stacked strain before it appears."
        } else {
            return "With your current sensitivity, overloaded is being judged at a balanced level."
        }
    case .orange:
        if combined >= 0.72 {
            return "With your current sensitivity, drained would be called a little sooner from weaker recovery."
        } else if combined <= 0.44 {
            return "With your current sensitivity, drained would need more obvious recovery lag before it appears."
        } else {
            return "With your current sensitivity, drained is being judged at a balanced level."
        }
    }
}

func previewSignalChips(for state: ColorHealthState) -> [ExplanationSignalChip] {
    switch state {
    case .blue:
        return [
            .init(symbol: "moon.stars.fill", title: "Sleep", value: "7.8-8.4 h"),
            .init(symbol: "waveform.path.ecg", title: "HRV", value: "50-60 ms"),
            .init(symbol: "heart.fill", title: "Resting", value: "56-62 bpm")
        ]
    case .green:
        return [
            .init(symbol: "moon.stars.fill", title: "Sleep", value: "7.0-7.8 h"),
            .init(symbol: "figure.walk.motion", title: "Movement", value: "6.5k-9k"),
            .init(symbol: "waveform.path.ecg", title: "HRV", value: "42-50 ms")
        ]
    case .yellow:
        return [
            .init(symbol: "figure.walk.motion", title: "Movement", value: "2k-3.5k"),
            .init(symbol: "figure.run", title: "Exercise", value: "<12 min"),
            .init(symbol: "moon.stars.fill", title: "Sleep", value: "Near baseline")
        ]
    case .purple:
        return [
            .init(symbol: "waveform.path.ecg", title: "HRV", value: "24-30 ms"),
            .init(symbol: "heart.fill", title: "Resting", value: "78-84 bpm"),
            .init(symbol: "wind", title: "Breathing", value: "17-19/min")
        ]
    case .gray:
        return [
            .init(symbol: "moon.stars.fill", title: "Sleep", value: "Baseline"),
            .init(symbol: "waveform.path.ecg", title: "HRV", value: "Baseline"),
            .init(symbol: "heart.fill", title: "Resting", value: "Baseline")
        ]
    case .red:
        return [
            .init(symbol: "waveform.path.ecg", title: "HRV", value: "<22 ms"),
            .init(symbol: "heart.fill", title: "Resting", value: "84-92 bpm"),
            .init(symbol: "wind", title: "Breathing", value: "19-21/min")
        ]
    case .orange:
        return [
            .init(symbol: "moon.stars.fill", title: "Sleep", value: "5.2-6.0 h"),
            .init(symbol: "waveform.path.ecg", title: "HRV", value: "24-34 ms"),
            .init(symbol: "heart.fill", title: "Resting", value: "72-80 bpm")
        ]
    }
}

struct ExplanationSignalChip: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let value: String
}

func explanationSignalChips(snapshot: AmbientHealthStore.Snapshot?) -> [ExplanationSignalChip] {
    guard let snapshot else { return [] }

    var chips: [ExplanationSignalChip] = []

    if let sleepHours = snapshot.sleepHours {
        chips.append(.init(symbol: "moon.stars.fill", title: "Sleep", value: String(format: "%.1f h", sleepHours)))
    }

    if let hrv = snapshot.heartRateVariability {
        chips.append(.init(symbol: "waveform.path.ecg", title: "HRV", value: "\(Int(hrv)) ms"))
    }

    if let resting = snapshot.restingHeartRate {
        chips.append(.init(symbol: "heart.fill", title: "Resting", value: "\(Int(resting)) bpm"))
    }

    if let respiratory = snapshot.respiratoryRate {
        chips.append(.init(symbol: "wind", title: "Breathing", value: String(format: "%.1f/min", respiratory)))
    }

    if let steps = snapshot.stepCountToday {
        let value = steps >= 1000 ? String(format: "%.1fk", steps / 1000) : Int(steps).formatted()
        chips.append(.init(symbol: "figure.walk.motion", title: "Movement", value: value))
    }

    return Array(chips.prefix(4))
}
