import Foundation
import HealthKit

/// Classification and scoring helpers for `AmbientHealthStore`.
/// This file compares live signals against the user's recent baseline to produce
/// the ambient mood state. Thresholds and scoring logic are centralized here.
extension AmbientHealthStore {

    // MARK: - Threshold Constants

    struct Thresholds {
        // Stress
        static let restingHRLow = 78.0
        static let restingHRHigh = 86.0
        static let currentHRLow = 96.0
        static let currentHRHigh = 104.0
        static let hrvLow = 26.0
        static let hrvHigh = 33.0
        static let respiratoryLow = 17.2
        static let respiratoryHigh = 19.0

        // Recovery
        static let sleepLow = 5.4
        static let sleepHigh = 6.4
        static let restingHRRecoveryHigh = 78.0
        static let restingHRRecoveryLow = 86.0
        static let hrvRecoveryLow = 20.0
        static let hrvRecoveryHigh = 28.0
        static let hrvStrongRecoveryLow = 36.0
        static let hrvStrongRecoveryHigh = 42.0

        // Movement
        static let stepsLow = 900.0
        static let stepsVeryLow = 1_600.0
        static let stepsStrongLow = 5_500.0
        static let stepsStrongHigh = 7_500.0
        static let exerciseLow = 4.0
        static let exerciseVeryLow = 8.0
        static let exerciseStrongLow = 20.0
        static let exerciseStrongHigh = 34.0
        static let activeEnergyLow = 120.0
        static let activeEnergyVeryLow = 190.0
        static let activeEnergyStrongLow = 340.0
        static let activeEnergyStrongHigh = 520.0
    }

    // MARK: - Main Classification

    func classify(snapshot: Snapshot, baseline: BaselineSummary? = nil) -> ColorHealthState {

        let profile = sensitivityProfile

        // MARK: Extract signals
        let steps = snapshot.stepCountToday ?? 0
        let activeEnergy = snapshot.activeEnergyToday ?? 0
        let exerciseMinutes = snapshot.exerciseMinutesToday ?? 0
        let recentWorkoutMinutes = snapshot.recentWorkoutMinutes ?? 0
        let minutesSinceRecentWorkout = snapshot.minutesSinceRecentWorkout ?? .infinity

        let currentHeartRate = snapshot.currentHeartRate
            ?? snapshot.restingHeartRate
            ?? baseline?.restingHeartRate?.mean
            ?? 75

        let restingHeartRate = snapshot.restingHeartRate
            ?? baseline?.restingHeartRate?.mean
            ?? 70

        let heartRateVariability = snapshot.heartRateVariability
            ?? baseline?.heartRateVariability?.mean
            ?? 40

        let respiratoryRate = snapshot.respiratoryRate
            ?? baseline?.respiratoryRate?.mean
            ?? 15

        let oxygenSaturationPercent = snapshot.oxygenSaturationPercent
        let wristTemperatureCelsius = snapshot.wristTemperatureCelsius ?? 0

        let sleepHours = snapshot.sleepHours
            ?? snapshot.sleepStages?.totalSleepHours
            ?? baseline?.sleepHours?.mean
            ?? 7

        let sleepStages = snapshot.sleepStages
        let mindfulMinutes = snapshot.mindfulMinutesToday ?? 0

        let deepSleepPercent = sleepStages?.deepPercent
            ?? baseline?.deepSleepPercent?.mean
            ?? 16

        let remSleepPercent = sleepStages?.remPercent
            ?? baseline?.remSleepPercent?.mean
            ?? 20

        let awakePercent = sleepStages?.awakePercent
            ?? baseline?.awakePercent?.mean
            ?? 8

        let sleepEfficiency = sleepStages?.efficiencyPercent ?? 88

        // MARK: Sensitivity weights
        let stressWeight = normalizedSensitivity(profile.stress)
        let movementWeight = normalizedSensitivity(profile.movement)
        let recoveryWeight = normalizedSensitivity(profile.recovery)
        let overallThresholdScale = interpolate(low: 1.32, high: 0.68, factor: profile.overall)

        let moderateStressThreshold = interpolate(low: 1.50, high: 0.88, factor: stressWeight) * overallThresholdScale
        let strongStressThreshold = interpolate(low: 2.25, high: 1.32, factor: stressWeight) * overallThresholdScale
        let moderateRecoveryThreshold = interpolate(low: 1.50, high: 0.90, factor: recoveryWeight) * overallThresholdScale
        let strongRecoveryThreshold = interpolate(low: 2.20, high: 1.30, factor: recoveryWeight) * overallThresholdScale
        let moderateMovementThreshold = interpolate(low: 1.02, high: 0.56, factor: movementWeight) * overallThresholdScale

        // MARK: Deviations
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

        // MARK: Baseline reliability
        let baselineReliability = [
            baseline?.restingHeartRate,
            baseline?.heartRateVariability,
            baseline?.respiratoryRate,
            baseline?.sleepHours
        ].compactMap { $0 }
         .filter(\.isReliable)
         .count

        // MARK: Sleep quality
        let sleepStageStrong = deepSleepPercent >= 16 && remSleepPercent >= 19 && awakePercent <= 10 && sleepEfficiency >= 85
        let sleepStageWeak = deepSleepPercent < 10 || remSleepPercent < 15 || awakePercent >= 16 || sleepEfficiency < 80

        // MARK: Stress signals
        let fallbackStressSignals = [
            restingHeartRate >= interpolate(low: 86, high: 78, factor: stressWeight),
            heartRateVariability <= interpolate(low: 26, high: 33, factor: stressWeight),
            respiratoryRate >= interpolate(low: 19.0, high: 17.2, factor: stressWeight),
            currentHeartRate >= interpolate(low: 104, high: 96, factor: stressWeight)
                && steps < 2_500
                && exerciseMinutes < 12
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

        // MARK: Recovery signals
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
            ? ([sleepDebt, deepSleepDebt, remSleepDebt, awakeStrain, restingStrain, hrvStrain]
                .filter { $0 >= moderateRecoveryThreshold }
                .count >= 2)
            : (sleepHours < interpolate(low: Thresholds.sleepLow, high: Thresholds.sleepHigh, factor: recoveryWeight)
               || sleepStageWeak
               || heartRateVariability < interpolate(low: Thresholds.hrvRecoveryLow, high: Thresholds.hrvRecoveryHigh, factor: recoveryWeight)
               || restingHeartRate >= interpolate(low: Thresholds.restingHRRecoveryLow, high: Thresholds.restingHRRecoveryHigh, factor: recoveryWeight))

        let oversleepConcern = (
            sleepHours >= 9.25
            || (sleepHours >= 8.8 && sleepSurplus >= moderateRecoveryThreshold)
        ) && (
            !sleepStageStrong
            || heartRateVariability < interpolate(low: Thresholds.hrvStrongRecoveryLow, high: Thresholds.hrvStrongRecoveryHigh, factor: recoveryWeight)
            || steps < interpolate(low: 3_600, high: 5_000, factor: movementWeight)
        )

        let recoveryStrong = strongRecoverySignals >= 3
            && exceptionalRecoverySignals >= 1
            && sleepStageStrong
            && restingHeartRate <= 75
            && !oversleepConcern

        // MARK: Movement
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
            if hourOfDay < 11 { return false }
            if hourOfDay < 14 { return movementLowEarlyDay || movementVeryLow || (movementLowAbsolute && movementLowRelative) }
            if movementWeight < 0.42 { return movementVeryLow || (movementLowAbsolute && movementLowRelative) }
            return movementLowAbsolute || movementLowRelative
        }()

        let movementStrongAbsolute = steps >= interpolate(low: 7_500, high: 5_500, factor: movementWeight)
            || exerciseMinutes >= interpolate(low: 34, high: 20, factor: movementWeight)
            || activeEnergy >= interpolate(low: 520, high: 340, factor: movementWeight)

        let movementStrongRelative = stepSurplus >= moderateMovementThreshold || exerciseSurplus >= moderateMovementThreshold
        let movementStrong = movementStrongAbsolute || movementStrongRelative

        // MARK: Other signals
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

        // MARK: Mood scores
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

        // MARK: Final Classification
        if severeStrain && !workoutExplainsCardioStrain { return .red }
        if moderateStrain && !workoutExplainsCardioStrain && (!stressElevated || recoveryPatternDominant) { return .orange }
        if stressElevated && !calmingSignals && !workoutSuppressedStress { return .purple }
        if recoveryStrong && respiratoryRate <= 17 && wristTemperatureCelsius < 0.5 { return .blue }
        if movementStrong && !recoveryWeak && strongRecoverySignals >= 2 { return .green }
        let lowEnergyAllowed = movementLow && !stressElevated && (!recoveryWeak || !drainClearlyDominant || drainSignalCount < 2)
        if lowEnergyAllowed { return .yellow }

        return .gray
    }

    // MARK: - Helper Function

    func metricBaseline(from values: [Double]) -> MetricBaseline? {
        let filtered = values.filter { $0 > 0 }
        guard filtered.count >= 3 else { return nil }
        let mean = filtered.reduce(0, +) / Double(filtered.count)
        let stdDev = sqrt(filtered.map { pow($0 - mean, 2) }.reduce(0, +) / Double(filtered.count))
        return MetricBaseline(mean: mean, standardDeviation: stdDev, sampleCount: filtered.count)
    }

    func normalizedSensitivity(_ value: Double) -> Double {
        let localWeight = max(0, min(value, 1.2))
        let overallWeight = max(0, min(sensitivityProfile.overall, 1.2))
        return (localWeight * 0.95) + (overallWeight * 0.05)
    }

    func interpolate(low: Double, high: Double, factor: Double) -> Double {
        let clampedFactor = max(0, min(factor, 1.2))
        return low + ((high - low) * clampedFactor)
    }

    func positiveDeviation(current: Double, baseline: MetricBaseline?) -> Double {
        guard let baseline else { return 0 }
        let spread = max(baseline.standardDeviation, baseline.mean * 0.08, 0.75)
        return max(0, (current - baseline.mean) / spread)
    }

    func negativeDeviation(current: Double, baseline: MetricBaseline?) -> Double {
        guard let baseline else { return 0 }
        let spread = max(baseline.standardDeviation, baseline.mean * 0.08, 0.75)
        return max(0, (baseline.mean - current) / spread)
    }

    func deriveStateTrail(
        steps: [TrendPoint],
        exerciseMinutes: [TrendPoint],
        sleepStages: [SleepStageTrendPoint],
        restingHeartRate: [TrendPoint],
        heartRateVariability: [TrendPoint]
    ) -> [StateTrendPoint] {
        let calendar = Calendar.current
        let stepsByDay = Dictionary(uniqueKeysWithValues: steps.map { (calendar.startOfDay(for: $0.date), $0) })
        let exerciseByDay = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { (calendar.startOfDay(for: $0.date), $0) })
        let sleepByDay = Dictionary(uniqueKeysWithValues: sleepStages.map { (calendar.startOfDay(for: $0.date), $0) })
        let restingByDay = Dictionary(uniqueKeysWithValues: restingHeartRate.map { (calendar.startOfDay(for: $0.date), $0) })
        let hrvByDay = Dictionary(uniqueKeysWithValues: heartRateVariability.map { (calendar.startOfDay(for: $0.date), $0) })

        let allDays = Set(stepsByDay.keys)
            .union(exerciseByDay.keys)
            .union(sleepByDay.keys)
            .union(restingByDay.keys)
            .union(hrvByDay.keys)
            .sorted()

        return allDays.map { day in
            let sleepPoint = sleepByDay[day]
            let sleepBreakdown = sleepPoint.map {
                SleepStageBreakdown(
                    totalSleepHours: $0.totalSleepHours,
                    inBedHours: $0.totalSleepHours + (($0.awakePercent / 100) * max($0.totalSleepHours, 0)),
                    awakeHours: ($0.awakePercent / 100) * max($0.totalSleepHours, 0),
                    coreHours: max(0, $0.totalSleepHours * max(0, 100 - $0.deepPercent - $0.remPercent - $0.awakePercent) / 100),
                    deepHours: $0.totalSleepHours * ($0.deepPercent / 100),
                    remHours: $0.totalSleepHours * ($0.remPercent / 100),
                    unspecifiedSleepHours: 0
                )
            }

            let snapshot = Snapshot(
                recentWorkoutMinutes: nil,
                minutesSinceRecentWorkout: nil,
                stepCountToday: stepsByDay[day]?.value,
                activeEnergyToday: nil,
                exerciseMinutesToday: exerciseByDay[day]?.value,
                walkingRunningDistanceToday: nil,
                flightsClimbedToday: nil,
                currentHeartRate: restingByDay[day]?.value,
                restingHeartRate: restingByDay[day]?.value,
                heartRateVariability: hrvByDay[day]?.value,
                respiratoryRate: nil,
                oxygenSaturationPercent: nil,
                wristTemperatureCelsius: nil,
                sleepHours: sleepPoint?.totalSleepHours,
                sleepStages: sleepBreakdown,
                mindfulMinutesToday: nil,
                sampledAt: day
            )

            return StateTrendPoint(date: day, state: classify(snapshot: snapshot, baseline: baselineSummary))
        }
    }

    func deriveIntradayStateTrail(
        steps: [TrendPoint],
        exerciseMinutes: [TrendPoint],
        heartRate: [TrendPoint],
        respiratoryRate: [TrendPoint],
        snapshot: Snapshot
    ) -> [StateTrendPoint] {
        let calendar = Calendar.current
        let stepsByHour = Dictionary(uniqueKeysWithValues: steps.map { ($0.date, $0) })
        let exerciseByHour = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { ($0.date, $0) })
        let heartRateByHour = Dictionary(uniqueKeysWithValues: heartRate.map { ($0.date, $0) })
        let respiratoryByHour = Dictionary(uniqueKeysWithValues: respiratoryRate.map { ($0.date, $0) })

        let allHours = Set(stepsByHour.keys)
            .union(exerciseByHour.keys)
            .union(heartRateByHour.keys)
            .union(respiratoryByHour.keys)
            .sorted()

        return allHours.map { hour in
            let reconstructed = Snapshot(
                recentWorkoutMinutes: snapshot.recentWorkoutMinutes,
                minutesSinceRecentWorkout: snapshot.minutesSinceRecentWorkout,
                stepCountToday: stepsByHour[hour]?.value,
                activeEnergyToday: snapshot.activeEnergyToday,
                exerciseMinutesToday: exerciseByHour[hour]?.value,
                walkingRunningDistanceToday: snapshot.walkingRunningDistanceToday,
                flightsClimbedToday: snapshot.flightsClimbedToday,
                currentHeartRate: heartRateByHour[hour]?.value ?? snapshot.currentHeartRate,
                restingHeartRate: snapshot.restingHeartRate,
                heartRateVariability: snapshot.heartRateVariability,
                respiratoryRate: respiratoryByHour[hour]?.value ?? snapshot.respiratoryRate,
                oxygenSaturationPercent: snapshot.oxygenSaturationPercent,
                wristTemperatureCelsius: snapshot.wristTemperatureCelsius,
                sleepHours: snapshot.sleepHours,
                sleepStages: snapshot.sleepStages,
                mindfulMinutesToday: snapshot.mindfulMinutesToday,
                sampledAt: calendar.date(bySettingHour: calendar.component(.hour, from: hour), minute: 0, second: 0, of: snapshot.sampledAt) ?? hour
            )

            return StateTrendPoint(date: hour, state: classify(snapshot: reconstructed, baseline: baselineSummary))
        }
    }

    /// Builds a detailed, developer-facing explanation of classifier behavior for a given snapshot.
    /// This mirrors the same decision logic used by `classify(snapshot:baseline:)`.
    func buildClassificationDebugReport(
        snapshot: Snapshot,
        baseline: BaselineSummary?
    ) -> ClassificationDebugReport {
        let profile = sensitivityProfile

        let steps = snapshot.stepCountToday ?? 0
        let activeEnergy = snapshot.activeEnergyToday ?? 0
        let exerciseMinutes = snapshot.exerciseMinutesToday ?? 0
        let recentWorkoutMinutes = snapshot.recentWorkoutMinutes ?? 0
        let minutesSinceRecentWorkout = snapshot.minutesSinceRecentWorkout ?? .infinity

        let currentHeartRate = snapshot.currentHeartRate
            ?? snapshot.restingHeartRate
            ?? baseline?.restingHeartRate?.mean
            ?? 75

        let restingHeartRate = snapshot.restingHeartRate
            ?? baseline?.restingHeartRate?.mean
            ?? 70

        let heartRateVariability = snapshot.heartRateVariability
            ?? baseline?.heartRateVariability?.mean
            ?? 40

        let respiratoryRate = snapshot.respiratoryRate
            ?? baseline?.respiratoryRate?.mean
            ?? 15

        let oxygenSaturationPercent = snapshot.oxygenSaturationPercent
        let wristTemperatureCelsius = snapshot.wristTemperatureCelsius ?? 0

        let sleepHours = snapshot.sleepHours
            ?? snapshot.sleepStages?.totalSleepHours
            ?? baseline?.sleepHours?.mean
            ?? 7

        let sleepStages = snapshot.sleepStages
        let mindfulMinutes = snapshot.mindfulMinutesToday ?? 0

        let deepSleepPercent = sleepStages?.deepPercent
            ?? baseline?.deepSleepPercent?.mean
            ?? 16

        let remSleepPercent = sleepStages?.remPercent
            ?? baseline?.remSleepPercent?.mean
            ?? 20

        let awakePercent = sleepStages?.awakePercent
            ?? baseline?.awakePercent?.mean
            ?? 8

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
        ].compactMap { $0 }
            .filter(\.isReliable)
            .count

        let sleepStageStrong = deepSleepPercent >= 16 && remSleepPercent >= 19 && awakePercent <= 10 && sleepEfficiency >= 85
        let sleepStageWeak = deepSleepPercent < 10 || remSleepPercent < 15 || awakePercent >= 16 || sleepEfficiency < 80

        let fallbackStressSignals = [
            restingHeartRate >= interpolate(low: 86, high: 78, factor: stressWeight),
            heartRateVariability <= interpolate(low: 26, high: 33, factor: stressWeight),
            respiratoryRate >= interpolate(low: 19.0, high: 17.2, factor: stressWeight),
            currentHeartRate >= interpolate(low: 104, high: 96, factor: stressWeight)
                && steps < 2_500
                && exerciseMinutes < 12
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
            ? ([sleepDebt, deepSleepDebt, remSleepDebt, awakeStrain, restingStrain, hrvStrain]
                .filter { $0 >= moderateRecoveryThreshold }
                .count >= 2)
            : (sleepHours < interpolate(low: Thresholds.sleepLow, high: Thresholds.sleepHigh, factor: recoveryWeight)
               || sleepStageWeak
               || heartRateVariability < interpolate(low: Thresholds.hrvRecoveryLow, high: Thresholds.hrvRecoveryHigh, factor: recoveryWeight)
               || restingHeartRate >= interpolate(low: Thresholds.restingHRRecoveryLow, high: Thresholds.restingHRRecoveryHigh, factor: recoveryWeight))

        let oversleepConcern = (
            sleepHours >= 9.25
            || (sleepHours >= 8.8 && sleepSurplus >= moderateRecoveryThreshold)
        ) && (
            !sleepStageStrong
            || heartRateVariability < interpolate(low: Thresholds.hrvStrongRecoveryLow, high: Thresholds.hrvStrongRecoveryHigh, factor: recoveryWeight)
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
            if hourOfDay < 11 { return false }
            if hourOfDay < 14 { return movementLowEarlyDay || movementVeryLow || (movementLowAbsolute && movementLowRelative) }
            if movementWeight < 0.42 { return movementVeryLow || (movementLowAbsolute && movementLowRelative) }
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

        let selectedState: ColorHealthState
        let decisionReason: String
        if severeStrain && !workoutExplainsCardioStrain {
            selectedState = .red
            decisionReason = "Selected Overloaded because severe strain rules matched and workout suppression did not cancel them."
        } else if moderateStrain && !workoutExplainsCardioStrain && (!stressElevated || recoveryPatternDominant) {
            selectedState = .orange
            decisionReason = "Selected Drained because moderate strain was present with recovery-leaning drag."
        } else if stressElevated && !calmingSignals && !workoutSuppressedStress {
            selectedState = .purple
            decisionReason = "Selected Stressed because stress-elevated conditions were true without calming/workout suppression."
        } else if recoveryStrong && respiratoryRate <= 17 && wristTemperatureCelsius < 0.5 {
            selectedState = .blue
            decisionReason = "Selected Restored because strong recovery criteria were satisfied with calm respiratory/temperature context."
        } else if movementStrong && !recoveryWeak && strongRecoverySignals >= 2 {
            selectedState = .green
            decisionReason = "Selected Grounded because movement was strong and recovery context was not weak."
        } else {
            let lowEnergyAllowed = movementLow && !stressElevated && (!recoveryWeak || !drainClearlyDominant || drainSignalCount < 2)
            if lowEnergyAllowed {
                selectedState = .yellow
                decisionReason = "Selected Low Energy because movement was low without dominant stress strain."
            } else {
                selectedState = .gray
                decisionReason = "Selected Neutral because no higher-priority state gate was satisfied."
            }
        }

        func f1(_ value: Double) -> String { String(format: "%.1f", value) }
        func f2(_ value: Double) -> String { String(format: "%.2f", value) }
        func bool(_ value: Bool) -> String { value ? "YES" : "NO" }
        func baselineLine(_ name: String, _ baseline: MetricBaseline?) -> String {
            guard let baseline else { return "\(name): missing baseline" }
            return "\(name): mean \(f1(baseline.mean)), sd \(f2(baseline.standardDeviation)), n \(baseline.sampleCount), reliable \(bool(baseline.isReliable))"
        }

        let confidenceScore: Double = {
            var score: Double
            switch selectedState {
            case .red:
                score = severeStrain ? 0.90 : 0.72
            case .orange:
                score = moderateStrain ? 0.84 : 0.68
            case .purple:
                score = stressElevated ? 0.80 : 0.64
            case .blue:
                score = recoveryStrong ? 0.82 : 0.62
            case .green:
                score = movementStrong ? 0.78 : 0.60
            case .yellow:
                score = movementLow ? 0.74 : 0.58
            case .gray:
                score = 0.56
            }

            score += min(0.08, Double(baselineReliability) * 0.015)
            let scoreSpread = abs(stressedMoodScore - drainedMoodScore) + abs(drainedMoodScore - lowEnergyMoodScore)
            score += min(0.07, scoreSpread * 0.02)
            return min(max(score, 0.45), 0.97)
        }()

        let confidenceBand: String = {
            switch confidenceScore {
            case 0.84...: return "High"
            case 0.68...: return "Moderate"
            default: return "Low"
            }
        }()

        let confidenceSummary = "Classifier confidence: \(confidenceBand) (\(f2(confidenceScore)))"

        let sections: [ClassificationDebugReport.Section] = [
            .init(
                title: "Final Decision",
                lines: [
                    "Chosen state: \(selectedState.title)",
                    decisionReason,
                    "Workout suppression active: \(bool(workoutSuppressedStress))",
                    "Workout explains cardio strain: \(bool(workoutExplainsCardioStrain))"
                ]
            ),
            .init(
                title: "Raw Inputs Used",
                lines: [
                    "Sampled at: \(snapshot.sampledAt.formatted(date: .abbreviated, time: .standard))",
                    "Steps: \(Int(steps))",
                    "Active energy: \(f1(activeEnergy))",
                    "Exercise minutes: \(f1(exerciseMinutes))",
                    "Current HR: \(f1(currentHeartRate))",
                    "Resting HR: \(f1(restingHeartRate))",
                    "HRV: \(f1(heartRateVariability))",
                    "Respiratory: \(f1(respiratoryRate))",
                    "Sleep hours: \(f2(sleepHours))",
                    "Sleep stages deep/rem/awake: \(f1(deepSleepPercent)) / \(f1(remSleepPercent)) / \(f1(awakePercent))",
                    "Sleep efficiency: \(f1(sleepEfficiency))",
                    "Mindful minutes: \(f1(mindfulMinutes))",
                    "Oxygen saturation: \(oxygenSaturationPercent.map { f1($0) } ?? "missing")",
                    "Wrist temperature delta: \(snapshot.wristTemperatureCelsius.map { f2($0) } ?? "missing")"
                ]
            ),
            .init(
                title: "Baseline Context",
                lines: [
                    baselineLine("Resting HR baseline", baseline?.restingHeartRate),
                    baselineLine("HRV baseline", baseline?.heartRateVariability),
                    baselineLine("Respiratory baseline", baseline?.respiratoryRate),
                    baselineLine("Sleep hours baseline", baseline?.sleepHours),
                    baselineLine("Steps baseline", baseline?.stepCount),
                    baselineLine("Exercise baseline", baseline?.exerciseMinutes),
                    "Baseline reliability count: \(baselineReliability)"
                ]
            ),
            .init(
                title: "Sensitivity + Thresholds",
                lines: [
                    "Profile stress/movement/recovery/overall: \(f2(profile.stress)) / \(f2(profile.movement)) / \(f2(profile.recovery)) / \(f2(profile.overall))",
                    "Normalized weights stress/movement/recovery: \(f2(stressWeight)) / \(f2(movementWeight)) / \(f2(recoveryWeight))",
                    "Overall threshold scale: \(f2(overallThresholdScale))",
                    "Moderate stress threshold: \(f2(moderateStressThreshold))",
                    "Strong stress threshold: \(f2(strongStressThreshold))",
                    "Moderate recovery threshold: \(f2(moderateRecoveryThreshold))",
                    "Strong recovery threshold: \(f2(strongRecoveryThreshold))",
                    "Moderate movement threshold: \(f2(moderateMovementThreshold))"
                ]
            ),
            .init(
                title: "Deviation Scores (Z-like)",
                lines: [
                    "Resting strain: \(f2(restingStrain))",
                    "HRV strain: \(f2(hrvStrain))",
                    "Respiratory strain: \(f2(respiratoryStrain))",
                    "Sleep debt: \(f2(sleepDebt))",
                    "Deep sleep debt: \(f2(deepSleepDebt))",
                    "REM sleep debt: \(f2(remSleepDebt))",
                    "Awake strain: \(f2(awakeStrain))",
                    "Sleep surplus: \(f2(sleepSurplus))",
                    "Step deficit/surplus: \(f2(stepDeficit)) / \(f2(stepSurplus))",
                    "Exercise deficit/surplus: \(f2(exerciseDeficit)) / \(f2(exerciseSurplus))"
                ]
            ),
            .init(
                title: "Derived Gates + Flags",
                lines: [
                    "sleepStageStrong: \(bool(sleepStageStrong))",
                    "sleepStageWeak: \(bool(sleepStageWeak))",
                    "stressElevated: \(bool(stressElevated))",
                    "recoveryWeak: \(bool(recoveryWeak))",
                    "recoveryStrong: \(bool(recoveryStrong))",
                    "movementLow: \(bool(movementLow))",
                    "movementStrong: \(bool(movementStrong))",
                    "oversleepConcern: \(bool(oversleepConcern))",
                    "oxygenConcern / oxygenCritical: \(bool(oxygenConcern)) / \(bool(oxygenCritical))",
                    "temperatureStrain: \(bool(temperatureStrain))",
                    "calmingSignals: \(bool(calmingSignals))"
                ]
            ),
            .init(
                title: "Rule Inputs and Comparisons",
                lines: [
                    "fallbackStressSignals: \(fallbackStressSignals)",
                    "baselineStressSignals: \(baselineStressSignals)",
                    "strongStressSignals: \(strongStressSignals)",
                    "layeredStressLoad: \(f2(layeredStressLoad))",
                    "strongRecoverySignals: \(strongRecoverySignals)",
                    "exceptionalRecoverySignals: \(exceptionalRecoverySignals)",
                    "drainSignalCount: \(drainSignalCount)",
                    "recoveryPatternDominant: \(bool(recoveryPatternDominant))",
                    "drainClearlyDominant: \(bool(drainClearlyDominant))",
                    "severeStrain: \(bool(severeStrain))",
                    "moderateStrain: \(bool(moderateStrain))",
                    "hourOfDay gate: \(hourOfDay)",
                    "movementLowAbsolute/Relative/VeryLow: \(bool(movementLowAbsolute)) / \(bool(movementLowRelative)) / \(bool(movementVeryLow))"
                ]
            ),
            .init(
                title: "Mood Score Layer",
                lines: [
                    "stressedMoodScore: \(f2(stressedMoodScore))",
                    "drainedMoodScore: \(f2(drainedMoodScore))",
                    "lowEnergyMoodScore: \(f2(lowEnergyMoodScore))"
                ]
            )
        ]

        return ClassificationDebugReport(
            selectedState: selectedState,
            generatedAt: Date(),
            confidenceSummary: confidenceSummary,
            sections: sections
        )
    }
}
