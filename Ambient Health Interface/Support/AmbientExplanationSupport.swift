import SwiftUI

private enum ExplanationSignal: Hashable {
    case sleep
    case hrv
    case breathing
    case restingHeartRate
    case movement
}

private struct ExplanationDriver: Hashable {
    let signal: ExplanationSignal
    let text: String
}

/// State interpretation copy and ranking helpers used by explanation-style screens.
func explanationBullets(
    for state: ColorHealthState,
    snapshot: AmbientHealthStore.Snapshot?,
    baseline: AmbientHealthStore.BaselineSummary? = nil
) -> [String] {
    guard let snapshot else {
        return genericExplanationBullets(for: state)
    }

    let drivers = explanationDrivers(for: state, snapshot: snapshot, baseline: baseline)
    if drivers.isEmpty {
        return genericExplanationBullets(for: state)
    }

    var bullets: [String] = []
    var includedSignals = Set<ExplanationSignal>()

    if let primaryDriver = drivers.first {
        bullets.append(primaryDriver.text)
        includedSignals.insert(primaryDriver.signal)
    }

    if !includedSignals.contains(.hrv), let hrvLine = hrvExplanationLine(from: snapshot, baseline: baseline) {
        bullets.append(hrvLine)
        includedSignals.insert(.hrv)
    }

    if !includedSignals.contains(.breathing), let breathingLine = breathingExplanationLine(from: snapshot, baseline: baseline) {
        bullets.append(breathingLine)
        includedSignals.insert(.breathing)
    }

    if !includedSignals.contains(.restingHeartRate), let restingLine = restingHeartRateExplanationLine(from: snapshot, baseline: baseline) {
        bullets.append(restingLine)
        includedSignals.insert(.restingHeartRate)
    }

    if !includedSignals.contains(.sleep), let sleepStages = snapshot.sleepStages {
        bullets.append(sleepStageInsightLine(from: sleepStages, baseline: baseline))
        includedSignals.insert(.sleep)
    } else if !includedSignals.contains(.sleep), let sleepHours = snapshot.sleepHours {
        bullets.append(sleepHoursExplanationLine(sleepHours, baseline: baseline))
        includedSignals.insert(.sleep)
    }

    return Array((NSOrderedSet(array: bullets).array as? [String] ?? bullets).prefix(4))
}

func calmerExplanationBullets(
    for state: ColorHealthState,
    snapshot: AmbientHealthStore.Snapshot?,
    baseline: AmbientHealthStore.BaselineSummary? = nil
) -> [String] {
    guard let snapshot else {
        return calmerGenericExplanationBullets(for: state)
    }

    var bullets = calmerGenericExplanationBullets(for: state)

    if let line = sleepCalmerLine(from: snapshot, baseline: baseline) {
        bullets.append(line)
    }

    switch state {
    case .blue, .green:
        if let line = hrvCalmerLine(from: snapshot, baseline: baseline, positive: true) {
            bullets.append(line)
        }
    case .purple, .red, .orange:
        if let line = hrvCalmerLine(from: snapshot, baseline: baseline, positive: false) {
            bullets.append(line)
        }
    case .yellow, .gray:
        break
    }

    switch state {
    case .blue, .green, .gray:
        if let line = restingCalmerLine(from: snapshot, baseline: baseline, calm: true) {
            bullets.append(line)
        }
    case .purple, .red, .orange:
        if let line = restingCalmerLine(from: snapshot, baseline: baseline, calm: false) {
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

func calmerPatternInsight(
    for state: ColorHealthState,
    snapshot: AmbientHealthStore.Snapshot?,
    baseline: AmbientHealthStore.BaselineSummary? = nil
) -> String {
    if snapshot != nil {
        switch state {
        case .blue:
            return "Your recent pattern looks more supported than your usual baseline, with sleep and recovery leaning gently in your favor."
        case .green:
            return "Your recent pattern looks fairly even, with no single signal pulling very hard in one direction."
        case .yellow:
            return "Your recent pattern looks quieter than usual, especially around energy and movement."
        case .purple:
            return "Your recent pattern looks more activated than your usual baseline, with a few strain-related signals lining up together."
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

private func sleepCalmerLine(
    from snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String? {
    guard let sleepHours = snapshot.sleepHours else { return nil }
    if isHigherThanUsual(sleepHours, baseline: baseline?.sleepHours, fallbackThreshold: 8.5, minimumSpread: 0.6) {
        return "Sleep has been on the fuller side lately."
    }
    if isLowerThanUsual(sleepHours, baseline: baseline?.sleepHours, fallbackThreshold: 6, minimumSpread: 0.6) {
        return "Sleep has been on the lighter side lately."
    }
    return "Sleep looks fairly mid-range right now."
}

private func hrvCalmerLine(
    from snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?,
    positive: Bool
) -> String? {
    guard let hrv = snapshot.heartRateVariability else { return nil }
    if positive, isHigherThanUsual(hrv, baseline: baseline?.heartRateVariability, fallbackThreshold: 45, minimumSpread: 4) {
        return "Recovery signals look a little more supportive than usual."
    }
    if !positive, isLowerThanUsual(hrv, baseline: baseline?.heartRateVariability, fallbackThreshold: 30, minimumSpread: 4) {
        return "Recovery signals look a little softer than usual."
    }
    return nil
}

private func restingCalmerLine(
    from snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?,
    calm: Bool
) -> String? {
    guard let resting = snapshot.restingHeartRate else { return nil }
    if calm, isLowerThanUsual(resting, baseline: baseline?.restingHeartRate, fallbackThreshold: 64, minimumSpread: 2) {
        return "Your resting rhythm looks fairly calm right now."
    }
    if !calm, isHigherThanUsual(resting, baseline: baseline?.restingHeartRate, fallbackThreshold: 76, minimumSpread: 2) {
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

private func sleepStageInsightLine(
    from sleepStages: AmbientHealthStore.SleepStageBreakdown,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String {
    let awake = Int(sleepStages.awakePercent.rounded())

    if isHigherThanUsual(sleepStages.awakePercent, baseline: baseline?.awakePercent, fallbackThreshold: 16, minimumSpread: 3) {
        return "Sleep looked more broken up than usual, so recovery may have felt less complete."
    }

    if isLowerThanUsual(sleepStages.deepPercent, baseline: baseline?.deepSleepPercent, fallbackThreshold: 12, minimumSpread: 3)
        && isLowerThanUsual(sleepStages.remPercent, baseline: baseline?.remSleepPercent, fallbackThreshold: 18, minimumSpread: 3) {
        return "Sleep looked lighter than usual, which can leave energy and mood feeling less restored."
    }

    if isHigherThanUsual(sleepStages.deepPercent, baseline: baseline?.deepSleepPercent, fallbackThreshold: 18, minimumSpread: 3)
        && isHigherThanUsual(sleepStages.remPercent, baseline: baseline?.remSleepPercent, fallbackThreshold: 20, minimumSpread: 3)
        && !isHigherThanUsual(sleepStages.awakePercent, baseline: baseline?.awakePercent, fallbackThreshold: 10, minimumSpread: 2) {
        return "Sleep looked fairly restorative, which usually supports steadier energy and recovery."
    }

    return "Sleep quality looked mixed, so some recovery likely happened without feeling fully restorative."
}

private func hrvExplanationLine(
    from snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String? {
    guard let hrv = snapshot.heartRateVariability else { return nil }
    if isLowerThanUsual(hrv, baseline: baseline?.heartRateVariability, fallbackThreshold: 30, minimumSpread: 4) {
        return "HRV looks lower than your stronger recovery range, which can happen when your body is under more strain."
    }
    if isHigherThanUsual(hrv, baseline: baseline?.heartRateVariability, fallbackThreshold: 48, minimumSpread: 4) {
        return "HRV looks stronger than usual, which usually lines up with steadier recovery."
    }
    return "HRV looks fairly mid-range, so recovery does not look strongly pulled either way."
}

private func breathingExplanationLine(
    from snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String? {
    guard let breathing = snapshot.respiratoryRate else { return nil }
    if isHigherThanUsual(breathing, baseline: baseline?.respiratoryRate, fallbackThreshold: 17, minimumSpread: 0.8) {
        return "Your most recent sleep breathing pattern looks a little higher than your quieter range, which can line up with a more activated or strained read."
    }
    if isLowerThanUsual(breathing, baseline: baseline?.respiratoryRate, fallbackThreshold: 13, minimumSpread: 0.8) {
        return "Your most recent sleep breathing pattern looks fairly settled, which usually fits a calmer overall read."
    }
    return "Your most recent sleep breathing pattern looks fairly mid-range, without a strong pull toward calm or strain."
}

private func restingHeartRateExplanationLine(
    from snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String? {
    guard let resting = snapshot.restingHeartRate else { return nil }
    if isHigherThanUsual(resting, baseline: baseline?.restingHeartRate, fallbackThreshold: 78, minimumSpread: 2) {
        return "Resting heart rate is running higher than your calmer range, which can make the body read as more activated or strained."
    }
    if isLowerThanUsual(resting, baseline: baseline?.restingHeartRate, fallbackThreshold: 62, minimumSpread: 2) {
        return "Resting heart rate is sitting in a calmer range, which usually supports a steadier overall read."
    }
    return "Resting heart rate looks fairly mid-range, without a strong pull toward calm or activation."
}

func patternInsight(
    for state: ColorHealthState,
    snapshot: AmbientHealthStore.Snapshot?,
    baseline: AmbientHealthStore.BaselineSummary? = nil
) -> String {
    guard let snapshot else { return genericPatternInsight(for: state) }
    return livePatternInsight(for: state, snapshot: snapshot, baseline: baseline)
}

private func explanationDrivers(
    for state: ColorHealthState,
    snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> [ExplanationDriver] {
    var drivers: [ExplanationDriver] = []

    if let sleep = snapshot.sleepHours {
        if isHigherThanUsual(sleep, baseline: baseline?.sleepHours, fallbackThreshold: 9.2, minimumSpread: 0.6) {
            drivers.append(.init(
                signal: .sleep,
                text: "You slept longer than usual, which can sometimes line up with slower momentum or your body still trying to recover."
            ))
        } else if isLowerThanUsual(sleep, baseline: baseline?.sleepHours, fallbackThreshold: 6, minimumSpread: 0.6) {
            drivers.append(.init(
                signal: .sleep,
                text: "You slept less than usual, which can make recovery feel less complete."
            ))
        }
    }

    if let hrv = snapshot.heartRateVariability {
        if isLowerThanUsual(hrv, baseline: baseline?.heartRateVariability, fallbackThreshold: 30, minimumSpread: 4) {
            drivers.append(.init(
                signal: .hrv,
                text: "Your recovery signals look lower than usual right now, which can happen when your body is under more strain or has not bounced back yet."
            ))
        } else if isHigherThanUsual(hrv, baseline: baseline?.heartRateVariability, fallbackThreshold: 48, minimumSpread: 4) {
            drivers.append(.init(
                signal: .hrv,
                text: "Your recovery signals look stronger than usual right now, which usually lines up with a steadier state."
            ))
        }
    }

    if let breathing = snapshot.respiratoryRate {
        if isHigherThanUsual(breathing, baseline: baseline?.respiratoryRate, fallbackThreshold: 17, minimumSpread: 0.8) {
            drivers.append(.init(
                signal: .breathing,
                text: "Your most recent sleep breathing pattern is running a little higher than your quieter range, which can happen when your system is more activated or strained."
            ))
        } else if isLowerThanUsual(breathing, baseline: baseline?.respiratoryRate, fallbackThreshold: 13, minimumSpread: 0.8) {
            drivers.append(.init(
                signal: .breathing,
                text: "Your most recent sleep breathing pattern looks fairly settled, which usually fits a calmer overall pattern."
            ))
        }
    }

    if let resting = snapshot.restingHeartRate {
        if isHigherThanUsual(resting, baseline: baseline?.restingHeartRate, fallbackThreshold: 78, minimumSpread: 2) {
            drivers.append(.init(
                signal: .restingHeartRate,
                text: "Your resting heart rate is running higher than your usual calm range right now, which can make your system look more activated or on edge."
            ))
        } else if isLowerThanUsual(resting, baseline: baseline?.restingHeartRate, fallbackThreshold: 62, minimumSpread: 2) {
            drivers.append(.init(
                signal: .restingHeartRate,
                text: "Your resting heart rate is sitting in a calmer range right now, which usually supports a steadier or more recovered read."
            ))
        }
    }

    if let steps = snapshot.stepCountToday {
        if steps <= 3000 {
            drivers.append(.init(
                signal: .movement,
                text: "Your movement has been quieter than a more active day, which can make the app lean toward lower energy."
            ))
        } else if steps >= 7000 {
            drivers.append(.init(
                signal: .movement,
                text: "Your movement has been more present than a quieter day, which supports a more grounded read."
            ))
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

private func ranked(_ drivers: [ExplanationDriver], preferred: [String]) -> [ExplanationDriver] {
    drivers.sorted { score($0.text, preferred: preferred) > score($1.text, preferred: preferred) }
}

private func score(_ driver: String, preferred: [String]) -> Int {
    preferred.reduce(0) { partial, token in
        partial + (driver.localizedCaseInsensitiveContains(token) ? 1 : 0)
    }
}

private func livePatternInsight(
    for state: ColorHealthState,
    snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String {
    switch state {
    case .blue:
        return hasSupportiveRecoveryPattern(snapshot, baseline: baseline)
            ? "Pattern-wise, this usually lasts when sleep and recovery stay steady into the next day."
            : "Pattern-wise, this can stay restored, but it often fades first if recovery softens."
    case .green:
        return hasActivatedPattern(snapshot, baseline: baseline)
            ? "Pattern-wise, this looks steady, but even small rises in strain can push it toward stressed fairly quickly."
            : "Pattern-wise, this is your more balanced state, where no one signal is pulling very hard."
    case .yellow:
        return hasRecoveryDrag(snapshot, baseline: baseline)
            ? "Pattern-wise, this often means lower momentum plus slightly weaker recovery, rather than strong stress."
            : "Pattern-wise, this is usually more of a low-energy dip than a high-strain state."
    case .purple:
        return "Pattern-wise, this usually means a few stress-related signals are running higher than usual at the same time."
    case .gray:
        return "Pattern-wise, this is your middle zone, where the next few signals can easily shift things either way."
    case .red:
        return "Pattern-wise, this is a stronger strain state, and it usually takes more than one signal settling before it drops."
    case .orange:
        return "Pattern-wise, this usually means weaker recovery is weighing more heavily than low movement alone."
    }
}

private func hasSupportiveRecoveryPattern(
    _ snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> Bool {
    let hrvSupportive = snapshot.heartRateVariability.map {
        isHigherThanUsual($0, baseline: baseline?.heartRateVariability, fallbackThreshold: 48, minimumSpread: 4)
    } ?? false
    let restingCalm = snapshot.restingHeartRate.map {
        isLowerThanUsual($0, baseline: baseline?.restingHeartRate, fallbackThreshold: 64, minimumSpread: 2)
    } ?? false
    let sleepSupportive = snapshot.sleepStages.map {
        !isHigherThanUsual($0.awakePercent, baseline: baseline?.awakePercent, fallbackThreshold: 10, minimumSpread: 2)
            && isHigherThanUsual($0.deepPercent, baseline: baseline?.deepSleepPercent, fallbackThreshold: 18, minimumSpread: 3)
            && isHigherThanUsual($0.remPercent, baseline: baseline?.remSleepPercent, fallbackThreshold: 20, minimumSpread: 3)
    } ?? false
        || (snapshot.sleepHours.map {
            !isLowerThanUsual($0, baseline: baseline?.sleepHours, fallbackThreshold: 7.4, minimumSpread: 0.6)
        } ?? false)
    return hrvSupportive || restingCalm || sleepSupportive
}

private func hasActivatedPattern(
    _ snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> Bool {
    (snapshot.restingHeartRate.map {
        isHigherThanUsual($0, baseline: baseline?.restingHeartRate, fallbackThreshold: 76, minimumSpread: 2)
    } ?? false)
        || (snapshot.respiratoryRate.map {
            isHigherThanUsual($0, baseline: baseline?.respiratoryRate, fallbackThreshold: 17, minimumSpread: 0.8)
        } ?? false)
        || (snapshot.heartRateVariability.map {
            isLowerThanUsual($0, baseline: baseline?.heartRateVariability, fallbackThreshold: 32, minimumSpread: 4)
        } ?? false)
}

private func hasRecoveryDrag(
    _ snapshot: AmbientHealthStore.Snapshot,
    baseline: AmbientHealthStore.BaselineSummary?
) -> Bool {
    (snapshot.sleepHours.map {
        isLowerThanUsual($0, baseline: baseline?.sleepHours, fallbackThreshold: 6.2, minimumSpread: 0.6)
            || isHigherThanUsual($0, baseline: baseline?.sleepHours, fallbackThreshold: 9.2, minimumSpread: 0.6)
    } ?? false)
        || (snapshot.sleepStages.map {
            isHigherThanUsual($0.awakePercent, baseline: baseline?.awakePercent, fallbackThreshold: 15, minimumSpread: 3)
        } ?? false)
        || (snapshot.heartRateVariability.map {
            isLowerThanUsual($0, baseline: baseline?.heartRateVariability, fallbackThreshold: 30, minimumSpread: 4)
        } ?? false)
}

private func sleepHoursExplanationLine(
    _ sleepHours: Double,
    baseline: AmbientHealthStore.BaselineSummary?
) -> String {
    if isHigherThanUsual(sleepHours, baseline: baseline?.sleepHours, fallbackThreshold: 9.2, minimumSpread: 0.6) {
        return "Sleep was longer than your usual range, which can sometimes line up with slower momentum or your body still trying to recover."
    }
    if isLowerThanUsual(sleepHours, baseline: baseline?.sleepHours, fallbackThreshold: 6, minimumSpread: 0.6) {
        return "Sleep was shorter than your usual range, which can make recovery feel less complete."
    }
    return "Sleep was about \(String(format: "%.1f", sleepHours)) hours, which looks fairly mid-range for you."
}

private func isHigherThanUsual(
    _ value: Double,
    baseline: AmbientHealthStore.MetricBaseline?,
    fallbackThreshold: Double,
    minimumSpread: Double
) -> Bool {
    guard let baseline else { return value >= fallbackThreshold }
    let spread = max(baseline.standardDeviation, minimumSpread, abs(baseline.mean) * 0.08)
    return value >= (baseline.mean + spread)
}

private func isLowerThanUsual(
    _ value: Double,
    baseline: AmbientHealthStore.MetricBaseline?,
    fallbackThreshold: Double,
    minimumSpread: Double
) -> Bool {
    guard let baseline else { return value <= fallbackThreshold }
    let spread = max(baseline.standardDeviation, minimumSpread, abs(baseline.mean) * 0.08)
    return value <= (baseline.mean - spread)
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
        return "Grounded usually appears when your signals look balanced and steady over time."
    case .yellow:
        return "Low Energy usually appears when movement stays quieter than usual without stronger stress taking over."
    case .purple:
        return "Stressed usually appears when a few strain signals rise together and exercise does not fully explain them."
    case .gray:
        return "Neutral usually appears when nothing is standing out strongly enough to pull you into another state."
    case .red:
        return "Overloaded usually appears when several stronger strain signals show up at the same time."
    case .orange:
        return "Drained usually appears when weaker recovery is the main story, more than simple low movement."
    }
}
