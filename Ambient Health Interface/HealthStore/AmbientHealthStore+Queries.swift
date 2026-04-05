import Foundation
import HealthKit

/// HealthKit loading and normalization helpers for `AmbientHealthStore`.
///
/// This file keeps the query layer separate from the classifier so it is easier to reason about
/// what came from HealthKit versus how the app interpreted it.
extension AmbientHealthStore {
    func loadSnapshot() async throws -> Snapshot {
        // Keep the first refresh path intentionally light. This captures the
        // movement/cardio signals the UI needs first, then the richer recovery
        // context is layered in later once the app is already stable.
        async let steps = totalStepCountToday()
        async let activeEnergy = totalQuantityToday(for: .activeEnergyBurned, unit: .kilocalorie())
        async let exerciseMinutes = totalQuantityToday(for: .appleExerciseTime, unit: .minute())
        async let recentWorkout = recentWorkoutContext()
        async let walkingRunningDistance = totalQuantityToday(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo))
        async let flightsClimbed = totalQuantityToday(for: .flightsClimbed, unit: .count())
        let currentHeartRate = try await latestQuantityValue(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            maxAgeHours: 6
        )
        let restingHeartRate = try await latestQuantityValue(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            maxAgeHours: 36
        )
        let heartRateVariability = try await latestQuantityValue(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            maxAgeHours: 36
        )
        let mindfulMinutes = try await categoryDurationToday(for: .mindfulSession)

        let loadedRecentWorkout = try await recentWorkout

        return Snapshot(
            recentWorkoutMinutes: loadedRecentWorkout?.durationMinutes,
            minutesSinceRecentWorkout: loadedRecentWorkout?.minutesSinceEnd,
            stepCountToday: try await steps,
            activeEnergyToday: try await activeEnergy,
            exerciseMinutesToday: try await exerciseMinutes,
            walkingRunningDistanceToday: try await walkingRunningDistance,
            flightsClimbedToday: try await flightsClimbed,
            currentHeartRate: currentHeartRate,
            restingHeartRate: restingHeartRate,
            heartRateVariability: heartRateVariability,
            respiratoryRate: nil,
            oxygenSaturationPercent: nil,
            wristTemperatureCelsius: nil,
            sleepHours: nil,
            sleepStages: nil,
            mindfulMinutesToday: mindfulMinutes,
            sampledAt: Date()
        )
    }

    func enrichSnapshot(_ snapshot: Snapshot) async throws -> Snapshot {
        let respiratoryRate = try await latestQuantityValue(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            maxAgeHours: 36
        )
        let oxygenSaturation = try await latestQuantityValue(
            for: .oxygenSaturation,
            unit: .percent(),
            maxAgeHours: 36
        )
        let wristTemperature = try await latestQuantityValue(
            for: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            maxAgeHours: 48,
            treatZeroAsNil: false
        )
        let sleepHours = try await sleepHoursSinceYesterdayEvening()
        let sleepStages = try await sleepStageBreakdownSinceYesterdayEvening()

        return Snapshot(
            recentWorkoutMinutes: snapshot.recentWorkoutMinutes,
            minutesSinceRecentWorkout: snapshot.minutesSinceRecentWorkout,
            stepCountToday: snapshot.stepCountToday,
            activeEnergyToday: snapshot.activeEnergyToday,
            exerciseMinutesToday: snapshot.exerciseMinutesToday,
            walkingRunningDistanceToday: snapshot.walkingRunningDistanceToday,
            flightsClimbedToday: snapshot.flightsClimbedToday,
            currentHeartRate: snapshot.currentHeartRate,
            restingHeartRate: snapshot.restingHeartRate,
            heartRateVariability: snapshot.heartRateVariability,
            respiratoryRate: respiratoryRate,
            oxygenSaturationPercent: oxygenSaturation.map { $0 * 100 },
            wristTemperatureCelsius: wristTemperature,
            sleepHours: sleepHours,
            sleepStages: sleepStages,
            mindfulMinutesToday: snapshot.mindfulMinutesToday,
            sampledAt: snapshot.sampledAt
        )
    }

    func recentWorkoutContext() async throws -> RecentWorkoutContext? {
        try await withCheckedThrowingContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let end = Date()
            let start = Calendar.current.date(byAdding: .hour, value: -8, to: end) ?? end.addingTimeInterval(-8 * 60 * 60)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
            let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                guard let workout = (samples as? [HKWorkout])?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let minutesSinceEnd = max(0, end.timeIntervalSince(workout.endDate) / 60)
                let durationMinutes = workout.duration / 60
                continuation.resume(
                    returning: RecentWorkoutContext(
                        durationMinutes: durationMinutes,
                        minutesSinceEnd: minutesSinceEnd
                    )
                )
            }

            healthStore.execute(query)
        }
    }

    func loadTrendReport(
        days: Int,
        snapshot: Snapshot
    ) async throws -> TrendReport {
        async let steps = dailyCumulativeSeries(for: .stepCount, unit: .count(), days: days)
        async let exerciseMinutes = dailyCumulativeSeries(for: .appleExerciseTime, unit: .minute(), days: days)
        async let restingHeartRate = dailyAverageSeries(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: days
        )
        async let heartRateVariability = dailyAverageSeries(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            days: days
        )
        async let sleepStages = dailySleepStageSeries(days: days)
        async let latestSleepStage = latestSleepStagePoint()
        async let hourlySteps = hourlyCumulativeSeries(for: .stepCount, unit: .count())
        async let hourlyExercise = hourlyCumulativeSeries(for: .appleExerciseTime, unit: .minute())
        async let hourlyHeartRate = hourlyAverageSeries(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let hourlyRespiratoryRate = hourlyAverageSeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )

        let loadedSteps = try await steps
        let loadedExerciseMinutes = try await exerciseMinutes
        let loadedRestingHeartRate = try await restingHeartRate
        let loadedHeartRateVariability = try await heartRateVariability
        let loadedSleepStages = try await sleepStages
        let loadedLatestSleepStage = try await latestSleepStage
        let loadedHourlySteps = try await hourlySteps
        let loadedHourlyExercise = try await hourlyExercise
        let loadedHourlyHeartRate = try await hourlyHeartRate
        let loadedHourlyRespiratoryRate = try await hourlyRespiratoryRate

        let sleepHours = loadedSleepStages.map {
            TrendPoint(date: $0.date, value: $0.totalSleepHours)
        }

        let stateTrail = deriveStateTrail(
            steps: loadedSteps,
            exerciseMinutes: loadedExerciseMinutes,
            sleepStages: loadedSleepStages,
            restingHeartRate: loadedRestingHeartRate,
            heartRateVariability: loadedHeartRateVariability
        )
        let intradayStateTrail = deriveIntradayStateTrail(
            steps: loadedHourlySteps,
            exerciseMinutes: loadedHourlyExercise,
            heartRate: loadedHourlyHeartRate,
            respiratoryRate: loadedHourlyRespiratoryRate,
            snapshot: snapshot
        )

        return TrendReport(
            steps: loadedSteps,
            exerciseMinutes: loadedExerciseMinutes,
            sleepHours: sleepHours,
            restingHeartRate: loadedRestingHeartRate,
            heartRateVariability: loadedHeartRateVariability,
            sleepStages: loadedSleepStages,
            latestSleepStage: loadedLatestSleepStage,
            intradayStateTrail: intradayStateTrail,
            stateTrail: stateTrail
        )
    }

    func loadBaselineSummary(days: Int) async throws -> BaselineSummary {
        async let steps = dailyCumulativeSeries(for: .stepCount, unit: .count(), days: days)
        async let exerciseMinutes = dailyCumulativeSeries(for: .appleExerciseTime, unit: .minute(), days: days)
        async let restingHeartRate = dailyAverageSeries(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: days
        )
        async let heartRateVariability = dailyAverageSeries(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            days: days
        )
        async let respiratoryRate = dailyAverageSeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: days
        )
        async let sleepStages = dailySleepStageSeries(days: days)

        let loadedSteps = try await steps
        let loadedExerciseMinutes = try await exerciseMinutes
        let loadedRestingHeartRate = try await restingHeartRate
        let loadedHeartRateVariability = try await heartRateVariability
        let loadedRespiratoryRate = try await respiratoryRate
        let loadedSleepStages = try await sleepStages

        return BaselineSummary(
            windowDays: days,
            restingHeartRate: metricBaseline(from: loadedRestingHeartRate.map(\.value)),
            heartRateVariability: metricBaseline(from: loadedHeartRateVariability.map(\.value)),
            respiratoryRate: metricBaseline(from: loadedRespiratoryRate.map(\.value)),
            sleepHours: metricBaseline(from: loadedSleepStages.map(\.totalSleepHours)),
            deepSleepPercent: metricBaseline(from: loadedSleepStages.map(\.deepPercent)),
            remSleepPercent: metricBaseline(from: loadedSleepStages.map(\.remPercent)),
            awakePercent: metricBaseline(from: loadedSleepStages.map(\.awakePercent)),
            stepCount: metricBaseline(from: loadedSteps.map(\.value)),
            exerciseMinutes: metricBaseline(from: loadedExerciseMinutes.map(\.value))
        )
    }

    private func totalStepCountToday() async throws -> Double? {
        try await totalQuantityToday(for: .stepCount, unit: .count())
    }

    private func totalQuantityToday(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let quantity = result?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: quantity)
            }

            healthStore.execute(query)
        }
    }

    private func dailyCumulativeSeries(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async throws -> [TrendPoint] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: Date()),
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                var points: [TrendPoint] = []
                results?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    points.append(TrendPoint(date: statistics.startDate, value: value))
                }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func dailyAverageSeries(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async throws -> [TrendPoint] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: calendar.startOfDay(for: Date()),
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                var points: [TrendPoint] = []
                results?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    let value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    points.append(TrendPoint(date: statistics.startDate, value: value))
                }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func hourlyCumulativeSeries(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> [TrendPoint] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(hour: 1)
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                var runningTotal = 0.0
                var points: [TrendPoint] = []
                results?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    runningTotal += statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    points.append(TrendPoint(date: statistics.startDate, value: runningTotal))
                }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func hourlyAverageSeries(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> [TrendPoint] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: startDate,
                intervalComponents: DateComponents(hour: 1)
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                var points: [TrendPoint] = []
                results?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    let value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    points.append(TrendPoint(date: statistics.startDate, value: value))
                }

                continuation.resume(returning: points)
            }

            healthStore.execute(query)
        }
    }

    private func latestQuantityValue(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        maxAgeHours: Double? = nil,
        treatZeroAsNil: Bool = true
    ) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let predicate: NSPredicate? = {
            guard let maxAgeHours else { return nil }
            let cutoff = Date().addingTimeInterval(-(maxAgeHours * 3600))
            return HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)
        }()

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let sample = samples?.first as? HKQuantitySample
                if let maxAgeHours,
                   let sample,
                   Date().timeIntervalSince(sample.endDate) > maxAgeHours * 3600 {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample?.quantity.doubleValue(for: unit)
                if treatZeroAsNil, let value, value <= 0 {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: value)
                }
            }

            healthStore.execute(query)
        }
    }

    private func sleepHoursSinceYesterdayEvening() async throws -> Double? {
        try await latestCompletedSleepSession()?.breakdown.totalSleepHours
    }

    private func sleepStageBreakdownSinceYesterdayEvening() async throws -> SleepStageBreakdown? {
        try await latestCompletedSleepSession()?.breakdown
    }

    private func latestCompletedSleepSession() async throws -> SleepSessionCluster? {
        let now = Date()
        let queryStart = Calendar.current.date(byAdding: .hour, value: -36, to: now) ?? now
        return try await latestSleepSessionEnding(between: queryStart, and: now)
    }

    private func latestSleepStagePoint() async throws -> SleepStageTrendPoint? {
        guard let session = try await latestCompletedSleepSession() else { return nil }
        let breakdown = session.breakdown
        return SleepStageTrendPoint(
            date: session.startDate,
            totalSleepHours: breakdown.totalSleepHours,
            deepPercent: breakdown.deepPercent,
            remPercent: breakdown.remPercent,
            awakePercent: breakdown.awakePercent
        )
    }

    private func sleepSessionEnding(
        onDayStarting dayStart: Date,
        nextDay: Date,
        windowStart: Date
    ) async throws -> SleepSessionCluster? {
        guard let session = try await latestSleepSessionEnding(between: windowStart, and: nextDay) else {
            return nil
        }

        guard session.endDate >= dayStart, session.endDate < nextDay else {
            return nil
        }

        return session
    }

    private func latestSleepSessionEnding(
        between startDate: Date,
        and endDate: Date
    ) async throws -> SleepSessionCluster? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let sessions = Self.buildSleepSessions(from: sleepSamples)
                    .filter { session in
                        session.endDate >= startDate
                            && session.endDate <= endDate
                            && session.breakdown.totalSleepHours > 0
                    }

                continuation.resume(returning: sessions.max(by: { $0.endDate < $1.endDate }))
            }

            healthStore.execute(query)
        }
    }

    private func sleepStageBreakdown(
        from startDate: Date,
        to endDate: Date
    ) async throws -> SleepStageBreakdown? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: Self.sleepBreakdown(from: sleepSamples))
            }

            healthStore.execute(query)
        }
    }


    nonisolated private static func buildSleepSessions(from samples: [HKCategorySample]) -> [SleepSessionCluster] {
        let sortedSamples = samples.sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.endDate < rhs.endDate
            }
            return lhs.startDate < rhs.startDate
        }

        guard !sortedSamples.isEmpty else { return [] }

        let sessionGap: TimeInterval = 90 * 60
        var groups: [[HKCategorySample]] = []
        var currentGroup: [HKCategorySample] = []
        var currentGroupEnd: Date?

        for sample in sortedSamples {
            if let groupEnd = currentGroupEnd,
               sample.startDate.timeIntervalSince(groupEnd) > sessionGap {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [sample]
                currentGroupEnd = sample.endDate
            } else {
                currentGroup.append(sample)
                currentGroupEnd = max(currentGroupEnd ?? sample.endDate, sample.endDate)
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups.compactMap { group in
            guard let breakdown = Self.sleepBreakdown(from: group) else { return nil }
            let startDate = group.map(\.startDate).min() ?? Date()
            let endDate = group.map(\.endDate).max() ?? startDate
            return SleepSessionCluster(startDate: startDate, endDate: endDate, breakdown: breakdown)
        }
    }

    nonisolated private static func sleepBreakdown(from sleepSamples: [HKCategorySample]) -> SleepStageBreakdown? {
        guard !sleepSamples.isEmpty else { return nil }

        var inBedSeconds = 0.0
        var awakeSeconds = 0.0
        var coreSeconds = 0.0
        var deepSeconds = 0.0
        var remSeconds = 0.0
        var unspecifiedSleepSeconds = 0.0

        for sample in sleepSamples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBedSeconds += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                unspecifiedSleepSeconds += duration
            default:
                break
            }
        }

        let totalSleepSeconds = coreSeconds + deepSeconds + remSeconds + unspecifiedSleepSeconds
        guard totalSleepSeconds > 0 else { return nil }

        return SleepStageBreakdown(
            totalSleepHours: totalSleepSeconds / 3600,
            inBedHours: inBedSeconds / 3600,
            awakeHours: awakeSeconds / 3600,
            coreHours: coreSeconds / 3600,
            deepHours: deepSeconds / 3600,
            remHours: remSeconds / 3600,
            unspecifiedSleepHours: unspecifiedSleepSeconds / 3600
        )
    }

    private func dailySleepStageSeries(days: Int) async throws -> [SleepStageTrendPoint] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
        let queryStart = calendar.date(byAdding: .hour, value: -18, to: startDate) ?? startDate
        let queryEnd = Date()
        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: .strictStartDate)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let sessions: [SleepSessionCluster] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: Self.buildSleepSessions(from: sleepSamples))
            }

            healthStore.execute(query)
        }

        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startDate)
        }

        var points: [SleepStageTrendPoint] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart

            if let sessionsForDay = sessionsByDay[dayStart], !sessionsForDay.isEmpty {
                let breakdown = combinedSleepBreakdown(for: sessionsForDay)
                points.append(
                    SleepStageTrendPoint(
                        date: dayStart,
                        totalSleepHours: breakdown.totalSleepHours,
                        deepPercent: breakdown.deepPercent,
                        remPercent: breakdown.remPercent,
                        awakePercent: breakdown.awakePercent
                    )
                )
            } else {
                points.append(
                    SleepStageTrendPoint(
                        date: dayStart,
                        totalSleepHours: 0,
                        deepPercent: 0,
                        remPercent: 0,
                        awakePercent: 0
                    )
                )
            }
        }

        return points
    }

    private func combinedSleepBreakdown(for sessions: [SleepSessionCluster]) -> SleepStageBreakdown {
        let totalSleepHours = sessions.reduce(0) { $0 + $1.breakdown.totalSleepHours }
        let inBedHours = sessions.reduce(0) { $0 + $1.breakdown.inBedHours }
        let awakeHours = sessions.reduce(0) { $0 + $1.breakdown.awakeHours }
        let coreHours = sessions.reduce(0) { $0 + $1.breakdown.coreHours + $1.breakdown.unspecifiedSleepHours }
        let deepHours = sessions.reduce(0) { $0 + $1.breakdown.deepHours }
        let remHours = sessions.reduce(0) { $0 + $1.breakdown.remHours }

        return SleepStageBreakdown(
            totalSleepHours: totalSleepHours,
            inBedHours: inBedHours,
            awakeHours: awakeHours,
            coreHours: coreHours,
            deepHours: deepHours,
            remHours: remHours,
            unspecifiedSleepHours: 0
        )
    }


    private func categoryDurationToday(
        for identifier: HKCategoryTypeIdentifier
    ) async throws -> Double? {
        guard let categoryType = HKObjectType.categoryType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                let categorySamples = (samples as? [HKCategorySample]) ?? []
                let totalMinutes = categorySamples.reduce(0.0) { partialResult, sample in
                    partialResult + sample.endDate.timeIntervalSince(sample.startDate) / 60
                }

                continuation.resume(returning: totalMinutes > 0 ? totalMinutes : nil)
            }

            healthStore.execute(query)
        }
    }
}
