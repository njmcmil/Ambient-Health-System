import Foundation
import HealthKit

/// Classification and scoring helpers for `AmbientHealthStore`.
///
/// This file is where live signals are compared against the user's recent baseline to produce
/// the app's ambient mood state. The goal is to keep the scoring logic in one place so changes
/// to thresholds or interpretation stay consistent across the app.
extension AmbientHealthStore {
    func classify(snapshot: Snapshot, baseline: BaselineSummary? = nil) -> ColorHealthState {
        let profile = sensitivityProfile
        let steps = snapshot.stepCountToday ?? 0
        let activeEnergy = snapshot.activeEnergyToday ?? 0
        let exerciseMinutes = snapshot.exerciseMinutesToday ?? 0
        let recentWorkoutMinutes = snapshot.recentWorkoutMinutes ?? 0
        let minutesSinceRecentWorkout = snapshot.minutesSinceRecentWorkout ?? .infinity
        let currentHeartRate = snapshot.currentHeartRate ?? snapshot.restingHeartRate ?? baseline?.restingHeartRate?.mean ?? 75
        let restingHeartRate = snapshot.restingHeartRate ?? baseline?.restingHeartRate?.mean ?? 70
        let heartRateVariability = snapshot.heartRateVariability ?? baseline?.heartRateVariability?.mean ?? 40
        let respiratoryRate = snapshot.respiratoryRate ?? baseline?.respiratoryRate?.mean ?? 15
        let oxygenSaturationPercent = snapshot.oxygenSaturationPercent
        let wristTemperatureCelsius = snapshot.wristTemperatureCelsius ?? 0
        let sleepHours = snapshot.sleepHours ?? snapshot.sleepStages?.totalSleepHours ?? baseline?.sleepHours?.mean ?? 7
        let sleepStages = snapshot.sleepStages
        let mindfulMinutes = snapshot.mindfulMinutesToday ?? 0

        let deepSleepPercent = sleepStages?.deepPercent ?? baseline?.deepSleepPercent?.mean ?? 16
        let remSleepPercent = sleepStages?.remPercent ?? baseline?.remSleepPercent?.mean ?? 20
        let awakePercent = sleepStages?.awakePercent ?? baseline?.awakePercent?.mean ?? 8
        let sleepEfficiency = sleepStages?.efficiencyPercent ?? 88

        let stressWeight = normalizedSensitivity(profile.stress)
        let movementWeight = normalizedSensitivity(profile.movement)
        let recoveryWeight = normalizedSensitivity(profile.recovery)
        let overallThresholdScale = interpolate(low: 1.32, high: 0.68, factor: profile.overall)

        let moderateStressThreshold = interpolate(low: 1.50, high: 0.88, factor: stressWeight) * overallThresholdScale
        let strongStressThreshold = interpolate(low: 2.25, high: 1.32, factor: stressWeight) * overallThresholdScale
        let moderateRecoveryThreshold = interpolate(low: 1.50, high: 0.90, factor: recoveryWeight) * overallThresholdScale
        let strongRecoveryThreshold = interpolate(low: 2.20, high: 1.30, factor: recoveryWeight) * overallThresholdScale
        let moderateMovementThreshold = interpolate(low: 1.02, high: 0.56, factor: movementWeight) * overallThresholdScale

        let restingStrain = positiveDeviation(current: restingHeartRate, baseline: baseline?.restingHeartRate)
        let hrvStrain = negativeDeviation(current: heartRateVariability, baseline: baseline?.heartRateVariability)
        let respiratoryStrain = positiveDeviation(current: respiratoryRate, baseline: baseline?.respiratoryRate)
        let sleepDebt = negativeDeviation(current: sleepHours, baseline: baseline?.sleepHours)
        let deepSleepDebt = negativeDeviation(current: deepSleepPercent, baseline: baseline?.deepSleepPercent)
        let remSleepDebt = negativeDeviation(current: remSleepPercent, baseline: baseline?.remSleepPercent)
        let awakeStrain = positiveDeviation(current: awakePercent, baseline: baseline?.awakePercent)
        let sleepSurplus = positiveDeviation(current: sleepHours, baseline: baseline?.sleepHours)
        let stepDeficit = negativeDeviation(current: steps, baseline: baseline?.stepCount)
        let exerciseDeficit = negativeDeviation(current: exerciseMinutes, baseline: baseline?.exerciseMinutes)
        let stepSurplus = positiveDeviation(current: steps, baseline: baseline?.stepCount)
        let exerciseSurplus = positiveDeviation(current: exerciseMinutes, baseline: baseline?.exerciseMinutes)

        let baselineReliability = [
            baseline?.restingHeartRate,
            baseline?.heartRateVariability,
            baseline?.respiratoryRate,
            baseline?.sleepHours
        ]
        .compactMap { $0 }
        .filter(\.isReliable)
        .count

        let sleepStageStrong = deepSleepPercent >= 16 && remSleepPercent >= 19 && awakePercent <= 10 && sleepEfficiency >= 85
        let sleepStageWeak = deepSleepPercent < 10 || remSleepPercent < 15 || awakePercent >= 16 || sleepEfficiency < 80

        let fallbackStressSignals = [
            restingHeartRate >= interpolate(low: 86, high: 78, factor: stressWeight),
            heartRateVariability <= interpolate(low: 26, high: 33, factor: stressWeight),
            respiratoryRate >= interpolate(low: 19.0, high: 17.2, factor: stressWeight),
            currentHeartRate >= interpolate(low: 104, high: 96, factor: stressWeight) && steps < 2_500 && exerciseMinutes < 12
        ].filter { $0 }.count

        let workoutInProgress = recentWorkoutMinutes >= 10 && minutesSinceRecentWorkout <= 15
        let postWorkoutCooldown = recentWorkoutMinutes >= 20 && minutesSinceRecentWorkout <= 60
        let exercisePhysiologyStillElevated = currentHeartRate >= interpolate(low: 104, high: 96, factor: stressWeight)
            || respiratoryRate >= interpolate(low: 18.5, high: 17, factor: stressWeight)
        let workoutSuppressedStress = workoutInProgress || (postWorkoutCooldown && exercisePhysiologyStillElevated)

        let baselineStressSignals = [
            restingStrain >= moderateStressThreshold,
            hrvStrain >= moderateStressThreshold,
            respiratoryStrain >= moderateStressThreshold,
            sleepDebt >= moderateStressThreshold && awakeStrain >= moderateStressThreshold * 0.8
        ].filter { $0 }.count

        let strongStressSignals = [
            restingStrain >= strongStressThreshold,
            hrvStrain >= strongStressThreshold,
            respiratoryStrain >= strongStressThreshold,
            awakeStrain >= strongStressThreshold,
            sleepDebt >= strongStressThreshold
        ].filter { $0 }.count

        let layeredStressLoad = [restingStrain, hrvStrain, respiratoryStrain, max(sleepDebt, awakeStrain)]
            .sorted(by: >)
            .prefix(2)
            .reduce(0, +)

        let stressElevated = baselineReliability >= 2
            ? (baselineStressSignals >= 2 || layeredStressLoad >= moderateStressThreshold * 1.8)
            : fallbackStressSignals >= 2

        let recoverySupport = [
            negativeDeviation(current: restingHeartRate, baseline: baseline?.restingHeartRate),
            positiveDeviation(current: heartRateVariability, baseline: baseline?.heartRateVariability),
            positiveDeviation(current: sleepHours, baseline: baseline?.sleepHours),
            positiveDeviation(current: deepSleepPercent, baseline: baseline?.deepSleepPercent),
            positiveDeviation(current: remSleepPercent, baseline: baseline?.remSleepPercent)
        ]

        let strongRecoverySignals = recoverySupport.filter { $0 >= moderateRecoveryThreshold }.count
        let exceptionalRecoverySignals = recoverySupport.filter { $0 >= strongRecoveryThreshold }.count

        let recoveryWeak = baselineReliability >= 2
            ? ([sleepDebt, deepSleepDebt, remSleepDebt, awakeStrain, restingStrain, hrvStrain].filter { $0 >= moderateRecoveryThreshold }.count >= 2)
            : (sleepHours < interpolate(low: 5.4, high: 6.4, factor: recoveryWeight)
               || sleepStageWeak
               || heartRateVariability < interpolate(low: 20, high: 28, factor: recoveryWeight)
               || restingHeartRate >= interpolate(low: 86, high: 78, factor: recoveryWeight))

        let oversleepConcern = (
            sleepHours >= 9.25
            || (sleepHours >= 8.8 && sleepSurplus >= moderateRecoveryThreshold)
        ) && (
            !sleepStageStrong
            || heartRateVariability < interpolate(low: 42, high: 36, factor: recoveryWeight)
            || steps < interpolate(low: 3_600, high: 5_000, factor: movementWeight)
        )

        let recoveryStrong = strongRecoverySignals >= 3
            && exceptionalRecoverySignals >= 1
            && sleepStageStrong
            && restingHeartRate <= 75
            && !oversleepConcern

        let hourOfDay = Calendar.current.component(.hour, from: snapshot.sampledAt)
        let movementLowAbsolute = steps < interpolate(low: 1_600, high: 3_000, factor: movementWeight)
            && exerciseMinutes < interpolate(low: 8, high: 18, factor: movementWeight)
            && activeEnergy < interpolate(low: 190, high: 320, factor: movementWeight)
        let movementLowRelative = stepDeficit >= moderateMovementThreshold && exerciseDeficit >= moderateMovementThreshold * 0.75
        let movementLowEarlyDay = steps < 900 && exerciseMinutes < 4 && activeEnergy < 120
        let movementVeryLow = steps < interpolate(low: 900, high: 1_800, factor: movementWeight)
            && exerciseMinutes < interpolate(low: 4, high: 10, factor: movementWeight)
            && activeEnergy < interpolate(low: 120, high: 220, factor: movementWeight)
        let movementLow: Bool = {
            if hourOfDay < 11 {
                return false
            }

            if hourOfDay < 14 {
                return movementLowEarlyDay || movementVeryLow || (movementLowAbsolute && movementLowRelative)
            }

            if movementWeight < 0.42 {
                return movementVeryLow || (movementLowAbsolute && movementLowRelative)
            }

            return movementLowAbsolute || movementLowRelative
        }()

        let movementStrongAbsolute = steps >= interpolate(low: 7_500, high: 5_500, factor: movementWeight)
            || exerciseMinutes >= interpolate(low: 34, high: 20, factor: movementWeight)
            || activeEnergy >= interpolate(low: 520, high: 340, factor: movementWeight)
        let movementStrongRelative = stepSurplus >= moderateMovementThreshold || exerciseSurplus >= moderateMovementThreshold
        let movementStrong = movementStrongAbsolute || movementStrongRelative

        let calmingSignals = mindfulMinutes >= 10
        let oxygenConcern = oxygenSaturationPercent.map { $0 < 95 } ?? false
        let oxygenCritical = oxygenSaturationPercent.map { $0 < 94 } ?? false
        let temperatureStrain = wristTemperatureCelsius >= 0.8
            || (wristTemperatureCelsius >= 0.5 && stressElevated && recoveryWeak)
        let workoutExplainsCardioStrain = workoutSuppressedStress
            && !oxygenConcern
            && !temperatureStrain
            && sleepDebt < moderateRecoveryThreshold
            && awakeStrain < moderateStressThreshold
            && deepSleepDebt < moderateRecoveryThreshold
            && remSleepDebt < moderateRecoveryThreshold

        let severeStrain = oxygenCritical
            || strongStressSignals >= 3
            || (temperatureStrain && strongStressSignals >= 2)
            || (recoveryWeak && stressElevated && respiratoryStrain >= strongStressThreshold)
        let stressedMoodScore = restingStrain + hrvStrain + respiratoryStrain + max(sleepDebt, awakeStrain)
        let drainedMoodScore = sleepDebt + deepSleepDebt + remSleepDebt + awakeStrain + (hrvStrain * 0.7) + (restingStrain * 0.45)
            + (oversleepConcern ? 0.9 : 0)
        let lowEnergyMoodScore = stepDeficit + exerciseDeficit + max(0, moderateMovementThreshold - min(stepDeficit, moderateMovementThreshold * 0.5))
        let recoveryPatternDominant = drainedMoodScore >= stressedMoodScore + 0.45
        let drainClearlyDominant = drainedMoodScore >= lowEnergyMoodScore + 0.55
        let drainSignalCount = [sleepDebt, deepSleepDebt, remSleepDebt, awakeStrain]
            .filter { $0 >= moderateRecoveryThreshold }
            .count
        let moderateStrain = oxygenConcern
            || (drainSignalCount >= 2 && (recoveryWeak || temperatureStrain) && drainClearlyDominant)
            || (oversleepConcern && movementLow && !stressElevated && drainClearlyDominant)
            || (strongStressSignals >= 2 && recoveryPatternDominant)

        if severeStrain && !workoutExplainsCardioStrain {
            return .red
        }

        if moderateStrain && !workoutExplainsCardioStrain && (!stressElevated || recoveryPatternDominant) {
            return .orange
        }

        if stressElevated && !calmingSignals && !workoutSuppressedStress {
            return .purple
        }

        if recoveryStrong && respiratoryRate <= 17 && wristTemperatureCelsius < 0.5 {
            return .blue
        }

        if movementStrong && !recoveryWeak && strongRecoverySignals >= 2 {
            return .green
        }

        let lowEnergyAllowed = movementLow
            && !stressElevated
            && (!recoveryWeak || !drainClearlyDominant || drainSignalCount < 2)

        if lowEnergyAllowed {
            return .yellow
        }

        return .gray
    }

    func deriveStateTrail(
        steps: [TrendPoint],
        exerciseMinutes: [TrendPoint],
        sleepStages: [SleepStageTrendPoint],
        restingHeartRate: [TrendPoint],
        heartRateVariability: [TrendPoint]
    ) -> [StateTrendPoint] {
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { ($0.date, $0.value) })
        let sleepMap = Dictionary(uniqueKeysWithValues: sleepStages.map { ($0.date, $0) })
        let restingMap = Dictionary(uniqueKeysWithValues: restingHeartRate.map { ($0.date, $0.value) })
        let hrvMap = Dictionary(uniqueKeysWithValues: heartRateVariability.map { ($0.date, $0.value) })

        return steps.map { stepPoint in
            let sleepStage = sleepMap[stepPoint.date]
            let snapshot = Snapshot(
                recentWorkoutMinutes: nil,
                minutesSinceRecentWorkout: nil,
                stepCountToday: stepPoint.value,
                activeEnergyToday: nil,
                exerciseMinutesToday: exerciseMap[stepPoint.date],
                walkingRunningDistanceToday: nil,
                flightsClimbedToday: nil,
                currentHeartRate: nil,
                restingHeartRate: restingMap[stepPoint.date],
                heartRateVariability: hrvMap[stepPoint.date],
                respiratoryRate: nil,
                oxygenSaturationPercent: nil,
                wristTemperatureCelsius: nil,
                sleepHours: sleepStage?.totalSleepHours,
                sleepStages: sleepStage.map {
                    SleepStageBreakdown(
                        totalSleepHours: $0.totalSleepHours,
                        inBedHours: $0.totalSleepHours + ($0.totalSleepHours * ($0.awakePercent / 100)),
                        awakeHours: $0.totalSleepHours * ($0.awakePercent / 100),
                        coreHours: max(0, $0.totalSleepHours * max(0, 100 - $0.deepPercent - $0.remPercent) / 100),
                        deepHours: $0.totalSleepHours * ($0.deepPercent / 100),
                        remHours: $0.totalSleepHours * ($0.remPercent / 100),
                        unspecifiedSleepHours: 0
                    )
                },
                mindfulMinutesToday: nil,
                sampledAt: stepPoint.date
            )

            return StateTrendPoint(date: stepPoint.date, state: classify(snapshot: snapshot, baseline: baselineSummary))
        }
    }

    func deriveIntradayStateTrail(
        steps: [TrendPoint],
        exerciseMinutes: [TrendPoint],
        heartRate: [TrendPoint],
        respiratoryRate: [TrendPoint],
        snapshot: Snapshot
    ) -> [StateTrendPoint] {
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { ($0.date, $0.value) })
        let heartRateMap = Dictionary(uniqueKeysWithValues: heartRate.map { ($0.date, $0.value) })
        let respiratoryRateMap = Dictionary(uniqueKeysWithValues: respiratoryRate.map { ($0.date, $0.value) })

        return steps.map { stepPoint in
            let hourlySnapshot = Snapshot(
                recentWorkoutMinutes: snapshot.recentWorkoutMinutes,
                minutesSinceRecentWorkout: snapshot.minutesSinceRecentWorkout,
                stepCountToday: stepPoint.value,
                activeEnergyToday: snapshot.activeEnergyToday,
                exerciseMinutesToday: exerciseMap[stepPoint.date] ?? snapshot.exerciseMinutesToday,
                walkingRunningDistanceToday: snapshot.walkingRunningDistanceToday,
                flightsClimbedToday: snapshot.flightsClimbedToday,
                currentHeartRate: heartRateMap[stepPoint.date] == 0 ? snapshot.currentHeartRate : heartRateMap[stepPoint.date],
                restingHeartRate: snapshot.restingHeartRate,
                heartRateVariability: snapshot.heartRateVariability,
                respiratoryRate: respiratoryRateMap[stepPoint.date] == 0 ? snapshot.respiratoryRate : respiratoryRateMap[stepPoint.date],
                oxygenSaturationPercent: snapshot.oxygenSaturationPercent,
                wristTemperatureCelsius: snapshot.wristTemperatureCelsius,
                sleepHours: snapshot.sleepHours,
                sleepStages: snapshot.sleepStages,
                mindfulMinutesToday: snapshot.mindfulMinutesToday,
                sampledAt: stepPoint.date
            )

            return StateTrendPoint(date: stepPoint.date, state: classify(snapshot: hourlySnapshot, baseline: baselineSummary))
        }
    }

    func metricBaseline(from values: [Double]) -> MetricBaseline? {
        let filtered = values.filter { $0 > 0 }
        guard filtered.count >= 3 else { return nil }

        let mean = filtered.reduce(0, +) / Double(filtered.count)
        let variance = filtered.reduce(0.0) { partialResult, value in
            let difference = value - mean
            return partialResult + (difference * difference)
        } / Double(filtered.count)

        return MetricBaseline(
            mean: mean,
            standardDeviation: max(sqrt(variance), max(mean * 0.08, 0.75)),
            sampleCount: filtered.count
        )
    }

    func positiveDeviation(current: Double, baseline: MetricBaseline?) -> Double {
        guard let baseline, baseline.standardDeviation > 0 else { return 0 }
        return max(0, (current - baseline.mean) / baseline.standardDeviation)
    }

    func negativeDeviation(current: Double, baseline: MetricBaseline?) -> Double {
        guard let baseline, baseline.standardDeviation > 0 else { return 0 }
        return max(0, (baseline.mean - current) / baseline.standardDeviation)
    }

    func preset(matching profile: SensitivityProfile) -> SensitivityPreset {
        for preset in SensitivityPreset.allCases where preset != .custom {
            let candidate = preset.profile
            if abs(candidate.stress - profile.stress) < 0.001,
               abs(candidate.movement - profile.movement) < 0.001,
               abs(candidate.recovery - profile.recovery) < 0.001,
               abs(candidate.overall - profile.overall) < 0.001 {
                return preset
            }
        }

        return .custom
    }

    nonisolated static func isNoDataError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == HKError.errorDomain,
           let code = HKError.Code(rawValue: nsError.code),
           code == .errorNoData {
            return true
        }

        return nsError.localizedDescription.localizedCaseInsensitiveContains("no data available")
    }

    func signalEntries(for snapshot: Snapshot?) -> [HealthSignalEntry] {
        let entries: [(String, Bool)] = [
            ("Recent Workout", snapshot?.recentWorkoutMinutes != nil),
            ("Steps", snapshot?.stepCountToday != nil),
            ("Active Energy", snapshot?.activeEnergyToday != nil),
            ("Exercise Time", snapshot?.exerciseMinutesToday != nil),
            ("Walking Distance", snapshot?.walkingRunningDistanceToday != nil),
            ("Flights Climbed", snapshot?.flightsClimbedToday != nil),
            ("Heart Rate", snapshot?.currentHeartRate != nil),
            ("Resting Heart Rate", snapshot?.restingHeartRate != nil),
            ("HRV", snapshot?.heartRateVariability != nil),
            ("Respiratory Rate", snapshot?.respiratoryRate != nil),
            ("Blood Oxygen", snapshot?.oxygenSaturationPercent != nil),
            ("Wrist Temperature", snapshot?.wristTemperatureCelsius != nil),
            ("Sleep", snapshot?.sleepStages != nil || snapshot?.sleepHours != nil),
            ("Mindful Minutes", snapshot?.mindfulMinutesToday != nil)
        ]

        return entries.map { label, hasValue in
            let status: HealthSignalStatus
            if snapshot == nil {
                status = .awaitingConnection
            } else {
                status = hasValue ? .readable : .noRecentData
            }

            return HealthSignalEntry(label: label, status: status)
        }
    }

    private func normalizedSensitivity(_ sliderValue: Double) -> Double {
        let clamped = min(max(sliderValue, 0), 1)
        return pow(clamped, 0.82)
    }

    private func interpolate(low: Double, high: Double, factor: Double) -> Double {
        low + (high - low) * factor
    }
}
