import SwiftUI

// Keep view-support metadata and interpretation copy here so the SwiftUI screens stay focused
// on composition rather than mixing layout with explanation logic.

enum AmbientTab: String, CaseIterable, Identifiable {
    case now = "Now"
    case trends = "Trends"
    case explanation = "Explanation"
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
    case .blue: return "Your body appears to be recovering well."
    case .green: return "Your recent pattern looks healthy and steady."
    case .yellow: return "You may benefit from a bit more movement."
    case .purple: return "Your current pattern suggests increased stress."
    case .gray: return "Your current state looks stable and neutral."
    case .red: return "Something in your recent pattern may need attention."
    case .orange: return "Your recent pattern suggests building fatigue."
    }
}

func explanationSummary(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> String {
    guard let snapshot else { return state.message }

    // Explanation copy is driven from the same snapshot as classification so the language stays grounded.
    let fragments = explanationDrivers(for: state, snapshot: snapshot)
    guard let first = fragments.first else { return state.message }

    switch state {
    case .blue:
        return "Recovery looks strong right now, led by \(first.lowercased())."
    case .green:
        return "Your recent pattern looks balanced overall, with \(first.lowercased()) helping most."
    case .yellow:
        return "Lower movement appears to be the main reason for this state, especially \(first.lowercased())."
    case .purple:
        return "Stress-related signals are leading this state, with \(first.lowercased()) standing out."
    case .gray:
        return "Nothing is dominating the signal right now; the closest driver is \(first.lowercased())."
    case .red:
        return "A stronger strain signal is standing out right now, especially \(first.lowercased())."
    case .orange:
        return "Recovery looks softer than usual, driven in part by \(first.lowercased())."
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
        return "This pattern is being driven more by inactivity than by stress or recovery strain."
    case .purple:
        if let hrv = snapshot.heartRateVariability, let resting = snapshot.restingHeartRate {
            return "This pattern suggests a stress-loaded moment, especially with HRV around \(Int(hrv)) ms and resting heart rate near \(Int(resting)) bpm."
        }
        return "This pattern suggests stress is taking up more space in your recent signals than movement or recovery."
    case .gray:
        return "This pattern looks close to baseline, with mixed but not strongly directional health signals."
    case .red:
        if let temp = snapshot.wristTemperatureCelsius, temp >= 0.8 {
            return "This pattern suggests stronger strain than usual, with wrist temperature contributing alongside recovery or cardio load."
        }
        return "This pattern suggests multiple strain-related signals are stacking rather than a single mild deviation."
    case .orange:
        if let sleepStages = snapshot.sleepStages, sleepStages.awakePercent >= 14 {
            return "This pattern looks more fatigue-driven, with overnight fragmentation reducing how restorative sleep appears."
        }
        return "This pattern suggests recovery is lagging behind your recent load, even if the signal is not fully acute."
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
        } else if sleepHours >= 8 {
            drivers.append("Sleep duration is strong at about \(String(format: "%.1f", sleepHours)) hours")
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

private func genericExplanationBullets(for state: ColorHealthState) -> [String] {
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
            "Movement may be lower than your usual baseline right now.",
            "This state can appear after longer periods of inactivity or reduced activity trends.",
            "Heart rate and recovery signals do not appear to be the main drivers here."
        ]
    case .purple:
        return [
            "Stress-related signals may be elevated relative to your normal baseline.",
            "Heart rate or HRV-related patterns may suggest more strain than usual.",
            "Recovery and sleep patterns may be contributing to this more tense state."
        ]
    case .gray:
        return [
            "Current signals appear close to your normal baseline.",
            "No strong deviation in movement, stress, heart rate, or recovery is standing out.",
            "This usually reflects a steady state without a dominant pattern."
        ]
    case .red:
        return [
            "The current pattern appears more strained than your usual baseline.",
            "Stress, heart rate, or recovery-related signals may be showing a stronger shift than normal.",
            "This state is meant to reflect a more significant change in your overall signal."
        ]
    case .orange:
        return [
            "Fatigue-related patterns may be building relative to your recent baseline.",
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
        return "This pattern may be a gentle sign that movement has been harder to maintain lately."
    case .purple:
        return "This pattern may suggest that stress has been taking up more space in your recent routine."
    case .gray:
        return "This pattern may reflect a period that feels mostly steady, without any strong shifts standing out."
    case .red:
        return "This pattern may suggest your body is dealing with more strain than usual right now."
    case .orange:
        return "This pattern may be a sign that fatigue has been building over time."
    }
}
