import SwiftUI

// Keep view-support metadata and interpretation copy here so the SwiftUI screens stay focused
// on composition rather than mixing layout with explanation logic.

enum AmbientTab: String, CaseIterable, Identifiable {
    case now = "Now"
    case explanation = "Explanation"
    case trends = "Trends"
    case settings = "Settings"

    var id: String { rawValue }
}

func tabSymbolName(for tab: AmbientTab) -> String {
    switch tab {
    case .now:
        return "circle.hexagongrid.fill"
    case .trends:
        return "waveform.path.ecg"
    case .explanation:
        return "sparkles.rectangle.stack"
    case .settings:
        return "slider.horizontal.3"
    }
}

func nowLine(for state: ColorHealthState) -> String {
    switch state {
    case .blue: return "Your recent pattern feels more restored."
    case .green: return "Your recent pattern looks grounded and steady."
    case .yellow: return "Your recent pattern suggests lower energy and movement."
    case .purple: return "Your current pattern suggests more stress than usual."
    case .gray: return "Your current pattern looks neutral and steady."
    case .red: return "Several strain-related signals are elevated together."
    case .orange: return "Your recent pattern suggests emotional and physical drain."
    }
}

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

func explanationBullets(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> [String] {
    guard let snapshot else {
        return genericExplanationBullets(for: state)
    }

    let drivers = explanationDrivers(for: state, snapshot: snapshot)
    if drivers.isEmpty {
        return genericExplanationBullets(for: state)
    }

    var bullets = Array(drivers.prefix(3))

    if let sleepStages = snapshot.sleepStages {
        bullets.append(
            "Sleep staging shows Deep \(Int(sleepStages.deepPercent))%, REM \(Int(sleepStages.remPercent))%, and Awake \(Int(sleepStages.awakePercent))% for the current overnight window."
        )
    } else if let sleepHours = snapshot.sleepHours {
        bullets.append("Recent overnight sleep totals about \(String(format: "%.1f", sleepHours)) hours.")
    }

    return Array(bullets.prefix(3))
}

func calmerExplanationBullets(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> [String] {
    guard let snapshot else {
        return calmerGenericExplanationBullets(for: state)
    }

    switch state {
    case .blue:
        return [
            "Your recent signals look a little more supported and settled than usual.",
            sleepCalmerLine(from: snapshot) ?? "Sleep looks like it may be giving your system some room to recover.",
            hrvCalmerLine(from: snapshot, positive: true) ?? "Recovery signals look fairly supportive right now."
        ]
    case .green:
        return [
            "Nothing looks especially demanding right now, and the overall pattern seems fairly steady.",
            movementCalmerLine(from: snapshot, active: true) ?? "Movement looks reasonably supportive without pulling too hard.",
            "This kind of pattern often lines up with feeling more steady than pushed."
        ]
    case .yellow:
        return [
            "The current pattern looks quieter and lower-momentum than your usual rhythm.",
            movementCalmerLine(from: snapshot, active: false) ?? "Movement looks lighter today, which can make the day feel flatter.",
            "This reads more like low momentum than sharp stress."
        ]
    case .purple:
        return [
            "A few signals look more activated than your usual baseline, so the app is reading this as a more stressed moment.",
            hrvCalmerLine(from: snapshot, positive: false) ?? "Recovery signals look a little more strained than usual.",
            restingCalmerLine(from: snapshot, calm: false) ?? "Your resting rhythm also looks a bit more activated."
        ]
    case .gray:
        return [
            "The current pattern is staying close to your usual baseline.",
            "Nothing strongly stands out in one direction right now.",
            "This usually means the system does not see a strong pull toward another mood state."
        ]
    case .red:
        return [
            "Several signals are landing on the more intense side at once, so the app is treating this as a higher-strain state.",
            hrvCalmerLine(from: snapshot, positive: false) ?? "Recovery signals look more strained than usual.",
            "If this keeps showing up, it may be worth slowing down and checking in with yourself."
        ]
    case .orange:
        return [
            "The current pattern looks more worn down than sharply activated.",
            sleepCalmerLine(from: snapshot) ?? "Sleep may not be feeling as restorative as usual.",
            "This often lines up with feeling more depleted, flat, or behind on recovery."
        ]
    }
}

func calmerPatternInsight(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> String {
    guard let snapshot else {
        switch state {
        case .blue:
            return "This looks like a more settled and replenished pattern than usual."
        case .green:
            return "This looks like a fairly steady pattern without much strain pulling on it."
        case .yellow:
            return "This looks like a quieter, lower-momentum stretch rather than a strongly stressed one."
        case .purple:
            return "This looks a little more activated than your usual baseline."
        case .gray:
            return "This looks close to your normal baseline."
        case .red:
            return "This looks like a higher-strain pattern with several signals pulling in the same direction."
        case .orange:
            return "This looks more depleted than activated."
        }
    }

    switch state {
    case .blue:
        return "Recent sleep and recovery signals look supportive, which is why the app is reading this as more restored."
    case .green:
        return "Your recent pattern looks fairly steady and supported, without one signal standing out too strongly."
    case .yellow:
        return "The pattern looks quieter and less active than your normal rhythm, which is why it is landing closer to low energy."
    case .purple:
        return "A few signals are running a little more activated than usual, so the app is leaning toward stressed rather than neutral."
    case .gray:
        return "Your recent signals are staying fairly close to baseline, so the app is holding a neutral read."
    case .red:
        return "Several signals are stacking together on the high-strain side, which is why the app is reading this as overloaded."
    case .orange:
        return "Recovery looks like it may be lagging behind recent demand, so the pattern is leaning toward drained."
    }
}

func calmerGenericExplanationBullets(for state: ColorHealthState) -> [String] {
    switch state {
    case .blue:
        return [
            "Your pattern looks a little more restored than usual.",
            "Sleep and recovery appear to be supporting you right now.",
            "The app is reading this as a steadier, more replenished state."
        ]
    case .green:
        return [
            "Your pattern looks steady and fairly well supported.",
            "No one signal seems to be pulling too hard.",
            "The app is reading this as grounded rather than strained."
        ]
    case .yellow:
        return [
            "Your pattern looks quieter and lower-energy than usual.",
            "Movement may be lighter than your normal rhythm.",
            "The app is reading this as low energy, not high stress."
        ]
    case .purple:
        return [
            "A few signals look more activated than your baseline.",
            "The app is reading this as stressed because the pattern is leaning away from steadiness.",
            "This does not necessarily mean something is wrong, just that your system looks more loaded than usual."
        ]
    case .gray:
        return [
            "Your pattern looks close to baseline.",
            "Nothing strongly directional stands out right now.",
            "The app is reading this as neutral."
        ]
    case .red:
        return [
            "Several signals look more intense than usual at the same time.",
            "The app is reading this as a stronger high-strain pattern.",
            "If this keeps appearing, it may help to slow down and check in."
        ]
    case .orange:
        return [
            "Your pattern looks more worn down than activated.",
            "Sleep or recovery may not be feeling as supportive as usual.",
            "The app is reading this as drained."
        ]
    }
}

private func sleepCalmerLine(from snapshot: AmbientHealthStore.Snapshot) -> String? {
    if let sleepStages = snapshot.sleepStages, sleepStages.awakePercent >= 14 {
        return "Sleep looks more interrupted than usual, which can make the day feel heavier."
    }
    if let sleepHours = snapshot.sleepHours, sleepHours < 6 {
        return "Sleep looks a bit short, which can make the overall pattern feel less supported."
    }
    if let sleepHours = snapshot.sleepHours, sleepHours >= 7.5, sleepHours < 9.2 {
        return "Sleep looks fairly supportive right now."
    }
    if let sleepHours = snapshot.sleepHours, sleepHours >= 9.2 {
        return "Sleep ran longer than usual, which can sometimes point to lower momentum or ongoing recovery instead of feeling fully restored."
    }
    return nil
}

private func hrvCalmerLine(from snapshot: AmbientHealthStore.Snapshot, positive: Bool) -> String? {
    guard let hrv = snapshot.heartRateVariability else { return nil }
    if positive, hrv >= 45 {
        return "Recovery signals look reasonably supportive right now."
    }
    if !positive, hrv < 34 {
        return "Recovery signals are sitting a little lower, which can happen when your system is under more strain."
    }
    return nil
}

private func restingCalmerLine(from snapshot: AmbientHealthStore.Snapshot, calm: Bool) -> String? {
    guard let resting = snapshot.restingHeartRate else { return nil }
    if calm, resting <= 64 {
        return "Your resting rhythm looks fairly calm right now."
    }
    if !calm, resting >= 76 {
        return "Your resting rhythm also looks a little more activated."
    }
    return nil
}

private func movementCalmerLine(from snapshot: AmbientHealthStore.Snapshot, active: Bool) -> String? {
    guard let steps = snapshot.stepCountToday else { return nil }
    if active, steps >= 6_000 {
        return "Movement looks reasonably present today."
    }
    if !active, steps < 3_500 {
        return "Movement looks lighter today than usual."
    }
    return nil
}

func explanationSignalChips(snapshot: AmbientHealthStore.Snapshot?) -> [ExplanationSignalChip] {
    guard let snapshot else { return [] }

    var chips: [ExplanationSignalChip] = []

    if let sleepStages = snapshot.sleepStages {
        chips.append(
            ExplanationSignalChip(
                symbol: "moon.stars.fill",
                title: "Sleep",
                value: "\(String(format: "%.1f", sleepStages.totalSleepHours)) h"
            )
        )
    } else if let sleepHours = snapshot.sleepHours {
        chips.append(
            ExplanationSignalChip(
                symbol: "moon.stars.fill",
                title: "Sleep",
                value: "\(String(format: "%.1f", sleepHours)) h"
            )
        )
    }

    if let hrv = snapshot.heartRateVariability {
        chips.append(
            ExplanationSignalChip(
                symbol: "waveform.path.ecg",
                title: "HRV",
                value: "\(Int(hrv)) ms"
            )
        )
    }

    if let resting = snapshot.restingHeartRate {
        chips.append(
            ExplanationSignalChip(
                symbol: "heart.fill",
                title: "Resting",
                value: "\(Int(resting)) bpm"
            )
        )
    }

    if let steps = snapshot.stepCountToday {
        chips.append(
            ExplanationSignalChip(
                symbol: "figure.walk.motion",
                title: "Movement",
                value: Int(steps).formatted()
            )
        )
    }

    return Array(chips.prefix(4))
}

struct ExplanationSignalChip: Identifiable {
    let symbol: String
    let title: String
    let value: String

    var id: String { title }
}

func patternInsight(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> String {
    guard let snapshot else {
        return genericPatternInsight(for: state)
    }

    // Pattern insight is intentionally phrased one level above the bullet list. It should feel like
    // an interpreted read on the pattern, not a repeated dump of the same raw metrics.
    switch state {
    case .blue:
        if let sleepStages = snapshot.sleepStages, sleepStages.deepPercent >= 16, sleepStages.awakePercent <= 10 {
            return "This pattern looks more restorative than usual, with solid deep sleep balance and low overnight fragmentation."
        }
        return "This pattern suggests your body has had enough room to recover and your recovery signals are holding up well."
    case .green:
        if let steps = snapshot.stepCountToday, let exercise = snapshot.exerciseMinutesToday, steps >= 6_000 || exercise >= 20 {
            return "This pattern looks supported by consistent movement and a fairly steady recovery profile."
        }
        return "This pattern reflects a relatively steady routine without any one signal pulling too hard."
    case .yellow:
        return "This pattern looks more low-energy and low-movement than stressed, often showing up when activity and momentum both soften."
    case .purple:
        return "This pattern suggests stress is taking up more space in your recent signals than steadiness or recovery."
    case .gray:
        return "This pattern looks close to baseline, with mixed but not strongly directional health signals."
    case .red:
        if let temp = snapshot.wristTemperatureCelsius, temp >= 0.8 {
            return "This pattern suggests stronger strain than usual, with wrist temperature contributing alongside recovery or cardio load."
        }
        return "This pattern suggests multiple strain-related signals are stacking rather than a single mild deviation."
    case .orange:
        if let sleepStages = snapshot.sleepStages, sleepStages.awakePercent >= 14 {
            return "This pattern looks more drained than acute, with overnight fragmentation reducing how restorative sleep appears."
        }
        return "This pattern suggests recovery is lagging behind your recent load, which can leave the overall mood feeling flatter or more worn down."
    }
}

private func explanationDrivers(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot) -> [String] {
    // Drivers are intentionally phrased as human-readable reasons, not raw rule outputs.
    var drivers: [String] = []

    if let sleepStages = snapshot.sleepStages {
        if sleepStages.deepPercent < 10 {
            drivers.append("Deep sleep was lower than the app's recovery target")
        }
        if sleepStages.remPercent < 15 {
            drivers.append("REM sleep was lighter than expected")
        }
        if sleepStages.awakePercent >= 16 {
            drivers.append("Awake time overnight was elevated, which can make sleep feel more fragmented")
        }
        if sleepStages.deepPercent >= 16, sleepStages.remPercent >= 20, sleepStages.awakePercent <= 10 {
            drivers.append("Sleep staging looks more restorative than average")
        }
    }

    if let sleepHours = snapshot.sleepHours {
        if sleepHours < 5.8 {
            drivers.append("Sleep duration is short at about \(String(format: "%.1f", sleepHours)) hours")
        } else if sleepHours >= 8, sleepHours < 9.2 {
            drivers.append("Sleep duration is strong at about \(String(format: "%.1f", sleepHours)) hours")
        } else if sleepHours >= 9.2 {
            drivers.append("Sleep duration is longer than usual at about \(String(format: "%.1f", sleepHours)) hours, which can sometimes go with lower momentum or ongoing recovery")
        }
    }

    if let hrv = snapshot.heartRateVariability {
        if hrv < 24 {
            drivers.append("HRV is low at about \(Int(hrv)) ms, which often lines up with strain or weaker recovery")
        } else if hrv >= 50 {
            drivers.append("HRV is solid at about \(Int(hrv)) ms, supporting recovery")
        }
    }

    if let resting = snapshot.restingHeartRate {
        if resting >= 84 {
            drivers.append("Resting heart rate is elevated at about \(Int(resting)) bpm")
        } else if resting <= 63 {
            drivers.append("Resting heart rate is calm at about \(Int(resting)) bpm")
        }
    }

    if let respiratory = snapshot.respiratoryRate, respiratory >= 19 {
        drivers.append("Respiratory rate is elevated at about \(Int(respiratory)) breaths per minute")
    }

    if let temperature = snapshot.wristTemperatureCelsius, temperature >= 0.7 {
        drivers.append(String(format: "Sleeping wrist temperature is elevated by about %+0.1fC", temperature))
    }

    if let steps = snapshot.stepCountToday, let exercise = snapshot.exerciseMinutesToday {
        if steps < 2_500, exercise < 12 {
            drivers.append("Movement is low today with about \(Int(steps)) steps and \(Int(exercise)) exercise minutes")
        } else if steps >= 6_500 || exercise >= 28 {
            drivers.append("Movement looks strong today with about \(Int(steps)) steps and \(Int(exercise)) exercise minutes")
        }
    }

    if let mindful = snapshot.mindfulMinutesToday, mindful >= 10 {
        drivers.append("Mindful minutes are present today, which helps soften stress signals")
    }

    switch state {
    case .blue:
        return ranked(drivers, preferred: ["restorative", "strong", "solid", "calm"])
    case .green:
        return ranked(drivers, preferred: ["strong", "solid", "calm", "movement"])
    case .yellow:
        return ranked(drivers, preferred: ["movement is low", "sleep"])
    case .purple:
        return ranked(drivers, preferred: ["HRV is low", "resting heart rate is elevated", "respiratory rate is elevated", "temperature"])
    case .gray:
        return ranked(drivers, preferred: ["movement", "sleep", "HRV"])
    case .red:
        return ranked(drivers, preferred: ["temperature", "respiratory rate is elevated", "resting heart rate is elevated", "HRV is low"])
    case .orange:
        return ranked(drivers, preferred: ["sleep", "awake time overnight", "HRV is low", "resting heart rate is elevated"])
    }
}

private func ranked(_ drivers: [String], preferred: [String]) -> [String] {
    drivers.sorted { lhs, rhs in
        score(lhs, preferred: preferred) > score(rhs, preferred: preferred)
    }
}

private func score(_ driver: String, preferred: [String]) -> Int {
    for (index, token) in preferred.enumerated() where driver.localizedCaseInsensitiveContains(token) {
        return preferred.count - index
    }
    return 0
}

func genericExplanationBullets(for state: ColorHealthState) -> [String] {
    switch state {
    case .blue:
        return [
            "Recovery-related signals appear steadier than your usual baseline.",
            "Sleep and heart rate patterns suggest your body may be recovering well.",
            "No strong stress or fatigue-related deviation is standing out right now."
        ]
    case .green:
        return [
            "Movement, sleep, and recovery patterns appear fairly consistent.",
            "Your recent health signals look stable relative to your normal baseline.",
            "No major shift in stress, heart rate, or activity is standing out."
        ]
    case .yellow:
        return [
            "Energy, movement, and outward momentum may be lower than your usual baseline right now.",
            "This state can appear after longer periods of inactivity or reduced activity trends.",
            "Stress and recovery signals do not appear to be the main drivers here."
        ]
    case .purple:
        return [
            "Stress-related signals may be elevated relative to your normal baseline.",
            "Heart rate or HRV-related patterns may suggest a more stressed or keyed-up state than usual.",
            "Recovery and sleep patterns may be contributing to this more stressed state."
        ]
    case .gray:
        return [
            "Current signals appear close to your normal baseline.",
            "No strong deviation in movement, stress, heart rate, or recovery is standing out.",
            "This usually reflects a more neutral state without one dominant pattern taking over."
        ]
    case .red:
        return [
            "The current pattern appears more strained than your usual baseline.",
            "Several stress, cardio, or recovery-related signals may be shifting together rather than one noisy reading standing alone.",
            "This state is meant to reflect a more significant change in your overall signal."
        ]
    case .orange:
        return [
            "Drain-related patterns may be building relative to your recent baseline.",
            "Recovery may be lagging behind physical or physiological load.",
            "Sleep, heart rate, or ongoing strain may be contributing to this state."
        ]
    }
}

private func genericPatternInsight(for state: ColorHealthState) -> String {
    switch state {
    case .blue:
        return "This pattern may suggest your body has had more room to recover recently."
    case .green:
        return "This pattern may reflect a routine that feels relatively steady and well-supported."
    case .yellow:
        return "This pattern may be a gentle sign that your energy or drive has been lower lately."
    case .purple:
        return "This pattern may suggest that stress has been taking up more space in your recent routine."
    case .gray:
        return "This pattern may reflect a more neutral stretch, without any strong shifts standing out."
    case .red:
        return "This pattern may suggest your body is dealing with more strain than usual right now."
    case .orange:
        return "This pattern may be a sign that drain or fatigue has been building over time."
    }
}
