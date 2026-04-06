import SwiftUI

/// State interpretation copy and ranking helpers used by explanation-style screens.
func explanationBullets(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> [String] {
    guard let snapshot else {
        return genericExplanationBullets(for: state)
    }

    let drivers = explanationDrivers(for: state, snapshot: snapshot)
    if drivers.isEmpty {
        return genericExplanationBullets(for: state)
    }

    var bullets = Array(drivers.prefix(1))

    if let hrvLine = hrvExplanationLine(from: snapshot) {
        bullets.append(hrvLine)
    }

    if let breathingLine = breathingExplanationLine(from: snapshot) {
        bullets.append(breathingLine)
    }

    if let sleepStages = snapshot.sleepStages {
        bullets.append(sleepStageInsightLine(from: sleepStages))
    } else if let sleepHours = snapshot.sleepHours {
        bullets.append("Sleep was about \(String(format: "%.1f", sleepHours)) hours.")
    }

    return Array((NSOrderedSet(array: bullets).array as? [String] ?? bullets).prefix(4))
}

func calmerExplanationBullets(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> [String] {
    guard let snapshot else {
        return calmerGenericExplanationBullets(for: state)
    }

    var bullets = calmerGenericExplanationBullets(for: state)

    if let line = sleepCalmerLine(from: snapshot) {
        bullets.append(line)
    }

    switch state {
    case .blue, .green:
        if let line = hrvCalmerLine(from: snapshot, positive: true) {
            bullets.append(line)
        }
    case .purple, .red, .orange:
        if let line = hrvCalmerLine(from: snapshot, positive: false) {
            bullets.append(line)
        }
    case .yellow, .gray:
        break
    }

    switch state {
    case .blue, .green, .gray:
        if let line = restingCalmerLine(from: snapshot, calm: true) {
            bullets.append(line)
        }
    case .purple, .red, .orange:
        if let line = restingCalmerLine(from: snapshot, calm: false) {
            bullets.append(line)
        }
    case .yellow:
        break
    }

    switch state {
    case .green, .yellow:
        if let line = movementCalmerLine(from: snapshot, active: state == .green) {
            bullets.append(line)
        }
    default:
        break
    }

    return Array(bullets.prefix(3))
}

func calmerPatternInsight(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> String {
    if snapshot != nil {
        switch state {
        case .blue:
            return "Your recent pattern looks more supported than usual, with sleep and recovery leaning gently in your favor."
        case .green:
            return "Your recent pattern looks fairly even, with no single signal pulling very hard in one direction."
        case .yellow:
            return "Your recent pattern looks quieter than usual, especially around energy and movement."
        case .purple:
            return "Your recent pattern looks more activated than usual, with a few strain-related signals lining up together."
        case .gray:
            return "Your recent pattern looks close to your own baseline, without a strong push toward another state."
        case .red:
            return "Your recent pattern looks more intense than usual, with several higher-strain signals appearing together."
        case .orange:
            return "Your recent pattern looks more worn down than activated, with recovery feeling less supported right now."
        }
    }

    return genericPatternInsight(for: state)
}

func calmerGenericExplanationBullets(for state: ColorHealthState) -> [String] {
    switch state {
    case .blue:
        return [
            "The overall pattern looks more supported than usual.",
            "Sleep and recovery appear to be helping rather than straining the system."
        ]
    case .green:
        return [
            "The overall pattern looks fairly steady.",
            "Nothing strong is pulling you far away from your usual rhythm."
        ]
    case .yellow:
        return [
            "The overall pattern looks quieter than usual.",
            "This often happens when movement and momentum feel softer."
        ]
    case .purple:
        return [
            "The overall pattern looks more activated than usual.",
            "This usually means a few stress-related signals are lining up together."
        ]
    case .gray:
        return [
            "The overall pattern looks close to baseline.",
            "The system does not see a strong reason to shift into another state."
        ]
    case .red:
        return [
            "The overall pattern looks more intense than usual.",
            "This usually means several strain-related signals are rising together."
        ]
    case .orange:
        return [
            "The overall pattern looks more worn down than usual.",
            "This often happens when recovery looks softer for a little while."
        ]
    }
}

private func sleepCalmerLine(from snapshot: AmbientHealthStore.Snapshot) -> String? {
    guard let sleepHours = snapshot.sleepHours else { return nil }
    if sleepHours >= 8.5 {
        return "Sleep has been on the fuller side lately."
    }
    if sleepHours <= 6 {
        return "Sleep has been on the lighter side lately."
    }
    return "Sleep looks fairly mid-range right now."
}

private func hrvCalmerLine(from snapshot: AmbientHealthStore.Snapshot, positive: Bool) -> String? {
    guard let hrv = snapshot.heartRateVariability else { return nil }
    if positive, hrv >= 45 {
        return "Recovery signals look a little more supportive than usual."
    }
    if !positive, hrv <= 30 {
        return "Recovery signals look a little softer than usual."
    }
    return nil
}

private func restingCalmerLine(from snapshot: AmbientHealthStore.Snapshot, calm: Bool) -> String? {
    guard let resting = snapshot.restingHeartRate else { return nil }
    if calm, resting <= 64 {
        return "Your resting rhythm looks fairly calm right now."
    }
    if !calm, resting >= 76 {
        return "Your resting rhythm looks a little more activated right now."
    }
    return nil
}

private func movementCalmerLine(from snapshot: AmbientHealthStore.Snapshot, active: Bool) -> String? {
    guard let steps = snapshot.stepCountToday else { return nil }
    if active, steps >= 7000 {
        return "Movement looks more present than usual."
    }
    if !active, steps <= 3000 {
        return "Movement looks quieter than usual."
    }
    return nil
}

private func sleepStageInsightLine(from sleepStages: AmbientHealthStore.SleepStageBreakdown) -> String {
    let awake = Int(sleepStages.awakePercent.rounded())

    if awake >= 16 {
        return "Sleep looked more broken up than usual, so recovery may have felt less complete."
    }

    if sleepStages.deepPercent <= 12 && sleepStages.remPercent <= 18 {
        return "Sleep looked lighter than usual, which can leave energy and mood feeling less restored."
    }

    if sleepStages.deepPercent >= 18 && sleepStages.remPercent >= 20 && awake <= 10 {
        return "Sleep looked fairly restorative, which usually supports steadier energy and recovery."
    }

    return "Sleep quality looked mixed, so some recovery likely happened without feeling fully restorative."
}

private func hrvExplanationLine(from snapshot: AmbientHealthStore.Snapshot) -> String? {
    guard let hrv = snapshot.heartRateVariability else { return nil }
    if hrv <= 30 {
        return "HRV looks lower than your stronger recovery range, which can happen when your body is under more strain."
    }
    if hrv >= 48 {
        return "HRV looks stronger than usual, which usually lines up with steadier recovery."
    }
    return "HRV looks fairly mid-range, so recovery does not look strongly pulled either way."
}

private func breathingExplanationLine(from snapshot: AmbientHealthStore.Snapshot) -> String? {
    guard let breathing = snapshot.respiratoryRate else { return nil }
    if breathing >= 17 {
        return "Breathing rate looks a little higher than your quieter range, which can happen when your system is more activated."
    }
    if breathing <= 13 {
        return "Breathing rate looks fairly settled, which usually fits a calmer pattern."
    }
    return "Breathing rate looks fairly mid-range, without a strong push toward calm or strain."
}

func patternInsight(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot?) -> String {
    guard let snapshot else { return genericPatternInsight(for: state) }
    return livePatternInsight(for: state, snapshot: snapshot)
}

private func explanationDrivers(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot) -> [String] {
    var drivers: [String] = []

    if let sleep = snapshot.sleepHours {
        if sleep >= 9.2 {
            drivers.append("You slept longer than usual, which can sometimes line up with slower momentum or your body still trying to recover.")
        } else if sleep <= 6 {
            drivers.append("You slept less than usual, which can make recovery feel less complete.")
        }
    }

    if let hrv = snapshot.heartRateVariability {
        if hrv <= 30 {
            drivers.append("Your recovery signals look lower than usual right now, which can happen when your body is under more strain or has not bounced back yet.")
        } else if hrv >= 48 {
            drivers.append("Your recovery signals look stronger than usual right now, which usually lines up with a steadier state.")
        }
    }

    if let breathing = snapshot.respiratoryRate {
        if breathing >= 17 {
            drivers.append("Your breathing rate is running a little higher than your quieter range right now, which can happen when your system is more activated or strained.")
        } else if breathing <= 13 {
            drivers.append("Your breathing rate looks fairly settled right now, which usually fits a calmer overall pattern.")
        }
    }

    if let resting = snapshot.restingHeartRate {
        if resting >= 78 {
            drivers.append("Your resting heart rate is running higher than your usual calm range right now, which can make your system look more activated or on edge.")
        } else if resting <= 62 {
            drivers.append("Your resting heart rate is sitting in a calmer range right now, which usually supports a steadier or more recovered read.")
        }
    }

    if let steps = snapshot.stepCountToday {
        if steps <= 3000 {
            drivers.append("Your movement has been quieter than a more active day, which can make the app lean toward lower energy.")
        } else if steps >= 7000 {
            drivers.append("Your movement has been more present than a quieter day, which supports a more grounded read.")
        }
    }

    let preferred: [String]
    switch state {
    case .blue:
        preferred = ["stronger recovery", "steadier", "restored", "calmer range", "more present"]
    case .green:
        preferred = ["steadier", "calmer range", "more present"]
    case .yellow:
        preferred = ["quiet", "low energy", "lighter than usual"]
    case .purple:
        preferred = ["activated", "strain", "elevated"]
    case .gray:
        preferred = ["steadier", "calmer range"]
    case .red:
        preferred = ["activated", "strain", "elevated", "softer recovery"]
    case .orange:
        preferred = ["softer recovery", "lighter than usual", "longer than usual"]
    }

    return ranked(drivers, preferred: preferred)
}

private func ranked(_ drivers: [String], preferred: [String]) -> [String] {
    drivers.sorted { score($0, preferred: preferred) > score($1, preferred: preferred) }
}

private func score(_ driver: String, preferred: [String]) -> Int {
    preferred.reduce(0) { partial, token in
        partial + (driver.localizedCaseInsensitiveContains(token) ? 1 : 0)
    }
}

private func livePatternInsight(for state: ColorHealthState, snapshot: AmbientHealthStore.Snapshot) -> String {
    switch state {
    case .blue:
        return hasSupportiveRecoveryPattern(snapshot)
            ? "Pattern-wise, this usually holds if sleep and recovery stay steady through the next day."
            : "Pattern-wise, this can stay restored, but it is usually the first state to fade if recovery softens."
    case .green:
        return hasActivatedPattern(snapshot)
            ? "Pattern-wise, this reads stable, but small rises in strain can push it toward stressed quickly."
            : "Pattern-wise, this is your balance state, where no single signal is clearly dominating."
    case .yellow:
        return hasRecoveryDrag(snapshot)
            ? "Pattern-wise, this often means low momentum plus mild recovery drag rather than strong stress."
            : "Pattern-wise, this is mostly a movement-momentum dip, not a high-strain state."
    case .purple:
        return "Pattern-wise, this reflects an activation cluster and usually eases only when multiple strain signals settle together."
    case .gray:
        return "Pattern-wise, this is your baseline zone where readings can shift either way depending on the next few signals."
    case .red:
        return "Pattern-wise, this is a stacked high-strain read and usually needs more than one signal to cool before it drops."
    case .orange:
        return "Pattern-wise, this is a recovery-depletion cluster, where weaker recovery outweighs movement alone."
    }
}

private func hasSupportiveRecoveryPattern(_ snapshot: AmbientHealthStore.Snapshot) -> Bool {
    let hrvSupportive = (snapshot.heartRateVariability ?? 0) >= 48
    let restingCalm = (snapshot.restingHeartRate ?? .infinity) <= 64
    let sleepSupportive = (snapshot.sleepStages.map { $0.deepPercent >= 18 && $0.remPercent >= 20 && $0.awakePercent <= 10 } ?? false)
        || ((snapshot.sleepHours ?? 0) >= 7.4 && (snapshot.sleepHours ?? 0) <= 8.8)
    return hrvSupportive || restingCalm || sleepSupportive
}

private func hasActivatedPattern(_ snapshot: AmbientHealthStore.Snapshot) -> Bool {
    (snapshot.restingHeartRate ?? 0) >= 76
        || (snapshot.respiratoryRate ?? 0) >= 17
        || (snapshot.heartRateVariability ?? .infinity) <= 32
}

private func hasRecoveryDrag(_ snapshot: AmbientHealthStore.Snapshot) -> Bool {
    (snapshot.sleepHours ?? 7) <= 6.2
        || (snapshot.sleepHours ?? 0) >= 9.2
        || (snapshot.sleepStages?.awakePercent ?? 0) >= 15
        || (snapshot.heartRateVariability ?? 100) <= 30
}

func genericExplanationBullets(for state: ColorHealthState) -> [String] {
    switch state {
    case .blue:
        return [
            "Your recent pattern looks more restored than your usual baseline.",
            "This usually happens when sleep and recovery signals both look supportive."
        ]
    case .green:
        return [
            "Your recent pattern looks grounded and steady.",
            "This usually means your signals are relatively balanced without one strain pattern dominating."
        ]
    case .yellow:
        return [
            "Your recent pattern looks lower-energy than usual.",
            "This usually means movement is quieter without strong signs of stress taking over."
        ]
    case .purple:
        return [
            "Your recent pattern looks more stressed than usual.",
            "This usually means strain-related signals are stacking without exercise fully explaining them."
        ]
    case .gray:
        return [
            "Your recent pattern looks close to baseline.",
            "The system is not seeing enough evidence to pull clearly toward another mood state."
        ]
    case .red:
        return [
            "Your recent pattern looks more overloaded than usual.",
            "This usually means several higher-strain signals are showing up together."
        ]
    case .orange:
        return [
            "Your recent pattern looks more drained than usual.",
            "This usually means recovery looks weaker and the system reads that as heavier than simple low energy."
        ]
    }
}

private func genericPatternInsight(for state: ColorHealthState) -> String {
    switch state {
    case .blue:
        return "Restored usually appears when recovery stays consistently supportive, not just from one good signal."
    case .green:
        return "Grounded usually appears when the signal mix looks balanced and stable over time."
    case .yellow:
        return "Low Energy usually appears when movement momentum is quiet without stronger stress or recovery strain taking over."
    case .purple:
        return "Stressed usually appears when activation signals cluster and workout context does not fully explain them."
    case .gray:
        return "Neutral usually appears when no state has enough combined evidence to clearly dominate."
    case .red:
        return "Overloaded usually appears when several higher-strain markers stack at the same time."
    case .orange:
        return "Drained usually appears when weaker recovery is the main story, more than simple low movement."
    }
}
