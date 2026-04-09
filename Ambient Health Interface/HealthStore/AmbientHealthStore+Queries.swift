import Foundation
import HealthKit

/// HealthKit loading and normalization helpers for `AmbientHealthStore`.
///
/// This file keeps the query layer separate from the classifier so it is easier to reason about
/// what came from HealthKit versus how the app interpreted it.
extension AmbientHealthStore {
    func loadSnapshot() async throws -> Snapshot {
        let now = Date()

        // MARK: - Parallel HealthKit Queries
        async let steps = totalStepCountToday()
        async let activeEnergy = totalQuantityToday(for: .activeEnergyBurned, unit: .kilocalorie())
        async let exerciseMinutes = totalQuantityToday(for: .appleExerciseTime, unit: .minute())
        async let walkingRunningDistance = totalQuantityToday(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo))
        async let flightsClimbed = totalQuantityToday(for: .flightsClimbed, unit: .count())

        async let recentWorkout = recentWorkoutContext()

        // parallelized
        async let currentHeartRate = latestQuantityValue(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            maxAgeHours: 6,
            requireTodaySample: true
        )

        async let restingHeartRate = latestQuantityValue(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            maxAgeHours: 36,
            requireTodaySample: true
        )

        async let heartRateVariability = latestQuantityValue(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            maxAgeHours: 36,
            requireTodaySample: true
        )

        async let mindfulMinutes = categoryDurationToday(for: .mindfulSession)

        // MARK: - Await Results (only once per value)
        let loadedRecentWorkout = try await recentWorkout

        return Snapshot(
            recentWorkoutMinutes: loadedRecentWorkout?.durationMinutes,
            minutesSinceRecentWorkout: loadedRecentWorkout?.minutesSinceEnd,

            stepCountToday: try await steps,
            activeEnergyToday: try await activeEnergy,
            exerciseMinutesToday: try await exerciseMinutes,
            walkingRunningDistanceToday: try await walkingRunningDistance,
            flightsClimbedToday: try await flightsClimbed,

            currentHeartRate: try await currentHeartRate,
            restingHeartRate: try await restingHeartRate,
            heartRateVariability: try await heartRateVariability,

            respiratoryRate: nil,
            oxygenSaturationPercent: nil,
            wristTemperatureCelsius: nil,

            sleepHours: nil,
            sleepStages: nil,

            mindfulMinutesToday: try await mindfulMinutes,
            sampledAt: now
        )
    }
    func enrichSnapshot(_ snapshot: Snapshot) async throws -> Snapshot {
        // MARK: - Parallel HealthKit Queries
        async let respiratoryRate = overnightAverageQuantityForToday(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )

        async let oxygenSaturation = overnightAverageQuantityForToday(
            for: .oxygenSaturation,
            unit: .percent()
        )

        async let wristTemperature = overnightAverageQuantityForToday(
            for: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            treatZeroAsNil: false
        )

        async let sleepHours = sleepHoursSinceYesterdayEvening()
        async let sleepStages = sleepStageBreakdownSinceYesterdayEvening()

        // MARK: - Build Snapshot (await once per value)
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

            respiratoryRate: try await respiratoryRate,
            oxygenSaturationPercent: try await oxygenSaturation.map { $0 * 100 },
            wristTemperatureCelsius: try await wristTemperature,

            sleepHours: try await sleepHours,
            sleepStages: try await sleepStages,

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
        snapshot: Snapshot,
        baseline: BaselineSummary?
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
        async let respiratoryRate = nightlyQuantitySeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: days
        )
        async let oxygenSaturation = nightlyQuantitySeries(
            for: .oxygenSaturation,
            unit: .percent(),
            days: days
        )
        async let wristTemperature = nightlyQuantitySeries(
            for: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            days: days,
            treatZeroAsNil: false
        )
        let calendarDays = max(days, 21)
        async let calendarSteps = dailyCumulativeSeries(for: .stepCount, unit: .count(), days: calendarDays)
        async let calendarExerciseMinutes = dailyCumulativeSeries(for: .appleExerciseTime, unit: .minute(), days: calendarDays)
        async let calendarRestingHeartRate = dailyAverageSeries(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: calendarDays
        )
        async let calendarHeartRateVariability = dailyAverageSeries(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            days: calendarDays
        )
        async let calendarRespiratoryRate = nightlyQuantitySeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: calendarDays
        )
        async let calendarOxygenSaturation = nightlyQuantitySeries(
            for: .oxygenSaturation,
            unit: .percent(),
            days: calendarDays
        )
        async let calendarWristTemperature = nightlyQuantitySeries(
            for: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            days: calendarDays,
            treatZeroAsNil: false
        )
        async let calendarSleepStages = dailySleepStageSeries(days: calendarDays)
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
        async let calendarHourlySteps = hourlyCumulativeSeries(for: .stepCount, unit: .count(), days: calendarDays)
        async let calendarHourlyExercise = hourlyCumulativeSeries(for: .appleExerciseTime, unit: .minute(), days: calendarDays)
        async let calendarHourlyHeartRate = hourlyAverageSeries(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: calendarDays
        )
        async let calendarHourlyRespiratoryRate = hourlyAverageSeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: calendarDays
        )

        let loadedSteps = try await steps
        let loadedExerciseMinutes = try await exerciseMinutes
        let loadedRestingHeartRate = try await restingHeartRate
        let loadedHeartRateVariability = try await heartRateVariability
        let loadedRespiratoryRate = try await respiratoryRate
        let loadedOxygenSaturation = try await oxygenSaturation.map { point in
            TrendPoint(date: point.date, value: point.value * 100)
        }
        let loadedWristTemperature = try await wristTemperature
        let loadedCalendarSteps = try await calendarSteps
        let loadedCalendarExerciseMinutes = try await calendarExerciseMinutes
        let loadedCalendarRestingHeartRate = try await calendarRestingHeartRate
        let loadedCalendarHeartRateVariability = try await calendarHeartRateVariability
        let loadedCalendarRespiratoryRate = try await calendarRespiratoryRate
        let loadedCalendarOxygenSaturation = try await calendarOxygenSaturation.map { point in
            TrendPoint(date: point.date, value: point.value * 100)
        }
        let loadedCalendarWristTemperature = try await calendarWristTemperature
        let loadedCalendarSleepStages = try await calendarSleepStages
        let loadedSleepStages = try await sleepStages
        let loadedLatestSleepStage = try await latestSleepStage
        let loadedHourlySteps = try await hourlySteps
        let loadedHourlyExercise = try await hourlyExercise
        let loadedHourlyHeartRate = try await hourlyHeartRate
        let loadedHourlyRespiratoryRate = try await hourlyRespiratoryRate
        let loadedCalendarHourlySteps = try await calendarHourlySteps
        let loadedCalendarHourlyExercise = try await calendarHourlyExercise
        let loadedCalendarHourlyHeartRate = try await calendarHourlyHeartRate
        let loadedCalendarHourlyRespiratoryRate = try await calendarHourlyRespiratoryRate

        let sleepHours = loadedSleepStages.map {
            TrendPoint(date: $0.date, value: $0.totalSleepHours)
        }
        let calendarSleepHours = loadedCalendarSleepStages.map {
            TrendPoint(date: $0.date, value: $0.totalSleepHours)
        }

        let stateTrail = deriveStateTrail(
            steps: loadedSteps,
            exerciseMinutes: loadedExerciseMinutes,
            sleepStages: loadedSleepStages,
            restingHeartRate: loadedRestingHeartRate,
            heartRateVariability: loadedHeartRateVariability,
            respiratoryRate: loadedRespiratoryRate,
            oxygenSaturationPercent: loadedOxygenSaturation,
            wristTemperatureCelsius: loadedWristTemperature,
            referenceBaseline: baseline
        )
        let calendarStateTrail = deriveCalendarStateTrail(
            steps: loadedCalendarSteps,
            exerciseMinutes: loadedCalendarExerciseMinutes,
            sleepStages: loadedCalendarSleepStages,
            restingHeartRate: loadedCalendarRestingHeartRate,
            heartRateVariability: loadedCalendarHeartRateVariability,
            respiratoryRate: loadedCalendarRespiratoryRate,
            oxygenSaturationPercent: loadedCalendarOxygenSaturation,
            wristTemperatureCelsius: loadedCalendarWristTemperature,
            hourlySteps: loadedCalendarHourlySteps,
            hourlyExerciseMinutes: loadedCalendarHourlyExercise,
            hourlyHeartRate: loadedCalendarHourlyHeartRate,
            hourlyRespiratoryRate: loadedCalendarHourlyRespiratoryRate,
            referenceBaseline: baseline
        )
        let intradayStateTrail = deriveIntradayStateTrail(
            steps: loadedHourlySteps,
            exerciseMinutes: loadedHourlyExercise,
            heartRate: loadedHourlyHeartRate,
            respiratoryRate: loadedHourlyRespiratoryRate,
            snapshot: snapshot,
            baseline: baseline
        )

        return TrendReport(
            steps: loadedSteps,
            exerciseMinutes: loadedExerciseMinutes,
            sleepHours: sleepHours,
            restingHeartRate: loadedRestingHeartRate,
            heartRateVariability: loadedHeartRateVariability,
            respiratoryRate: loadedRespiratoryRate,
            oxygenSaturationPercent: loadedOxygenSaturation,
            wristTemperatureCelsius: loadedWristTemperature,
            sleepStages: loadedSleepStages,
            calendarSteps: loadedCalendarSteps,
            calendarExerciseMinutes: loadedCalendarExerciseMinutes,
            calendarSleepHours: calendarSleepHours,
            calendarRestingHeartRate: loadedCalendarRestingHeartRate,
            calendarHeartRateVariability: loadedCalendarHeartRateVariability,
            calendarRespiratoryRate: loadedCalendarRespiratoryRate,
            calendarOxygenSaturationPercent: loadedCalendarOxygenSaturation,
            calendarWristTemperatureCelsius: loadedCalendarWristTemperature,
            calendarSleepStages: loadedCalendarSleepStages,
            latestSleepStage: loadedLatestSleepStage,
            intradayStateTrail: intradayStateTrail,
            stateTrail: stateTrail,
            calendarStateTrail: calendarStateTrail
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
        async let respiratoryRate = nightlyQuantitySeries(
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
            restingHeartRate: metricBaseline(from: loadedRestingHeartRate.filter { $0.value > 0 }.map(\.value)),
            heartRateVariability: metricBaseline(from: loadedHeartRateVariability.filter { $0.value > 0 }.map(\.value)),
            respiratoryRate: metricBaseline(from: loadedRespiratoryRate.filter { $0.value > 0 }.map(\.value)),
            sleepHours: metricBaseline(from: loadedSleepStages.filter { $0.totalSleepHours > 0 }.map(\.totalSleepHours)),
            deepSleepPercent: metricBaseline(from: loadedSleepStages.filter { $0.totalSleepHours > 0 }.map(\.deepPercent)),
            remSleepPercent: metricBaseline(from: loadedSleepStages.filter { $0.totalSleepHours > 0 }.map(\.remPercent)),
            awakePercent: metricBaseline(from: loadedSleepStages.filter { $0.totalSleepHours > 0 }.map(\.awakePercent)),
            stepCount: metricBaseline(from: loadedSteps.filter { $0.value > 0 }.map(\.value)),
            exerciseMinutes: metricBaseline(from: loadedExerciseMinutes.filter { $0.value > 0 }.map(\.value))
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
            options: []
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
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 12
            let anchorDate = calendar.date(from: components)!

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
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
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 12
            let anchorDate = calendar.date(from: components)!
            
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchorDate,
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
        try await hourlyCumulativeSeries(for: identifier, unit: unit, days: 1)
    }

    private func hourlyCumulativeSeries(
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
                var currentDay: Date?
                var points: [TrendPoint] = []
                results?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    let bucketDay = calendar.startOfDay(for: statistics.startDate)
                    if currentDay != bucketDay {
                        currentDay = bucketDay
                        runningTotal = 0
                    }
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
        try await hourlyAverageSeries(for: identifier, unit: unit, days: 1)
    }

    private func hourlyAverageSeries(
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
        treatZeroAsNil: Bool = true,
        requireTodaySample: Bool = false
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

                if requireTodaySample,
                   let sample,
                   !Calendar.current.isDate(sample.endDate, inSameDayAs: Date()) {
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

    private func overnightAverageQuantityForToday(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        treatZeroAsNil: Bool = true
    ) async throws -> Double? {
        guard let session = try await primarySleepSessionForToday() else { return nil }

        return try await averageQuantityDuringSession(
            for: identifier,
            unit: unit,
            session: session,
            treatZeroAsNil: treatZeroAsNil
        )
    }

    private func nightlyQuantitySeries(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int,
        treatZeroAsNil: Bool = true
    ) async throws -> [TrendPoint] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dayStarts = (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -(days - 1 - offset), to: todayStart)
        }

        let sessionsByDay = try await primarySleepSessionsByWakeDay(days: days)
        let queryStart = calendar.date(byAdding: .day, value: -(days + 3), to: todayStart) ?? todayStart
        let samples = try await quantitySamples(
            for: identifier,
            from: queryStart,
            to: Date()
        )

        return dayStarts.map { dayStart in
            let value = sessionsByDay[dayStart].flatMap {
                averageValue(from: samples, during: $0, unit: unit, treatZeroAsNil: treatZeroAsNil)
            } ?? 0

            return TrendPoint(date: dayStart, value: value)
        }
    }

    private func sleepHoursSinceYesterdayEvening() async throws -> Double? {
        try await primarySleepSessionForToday()?.breakdown.totalSleepHours
    }

    private func sleepStageBreakdownSinceYesterdayEvening() async throws -> SleepStageBreakdown? {
        try await primarySleepSessionForToday()?.breakdown
    }

    private func latestPrimarySleepSession() async throws -> SleepSessionCluster? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let sessions = try await sleepSessions(
            from: calendar.date(byAdding: .day, value: -4, to: todayStart) ?? todayStart,
            to: Date()
        )

        let recentDays = (0..<4).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: todayStart)
        }

        for dayStart in recentDays {
            if let session = primarySleepSession(forWakeDay: dayStart, sessions: sessions) {
                return session
            }
        }

        return nil
    }

    private func primarySleepSessionForToday() async throws -> SleepSessionCluster? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let sessions = try await sleepSessions(
            from: calendar.date(byAdding: .day, value: -3, to: todayStart) ?? todayStart,
            to: Date()
        )

        return primarySleepSession(forWakeDay: todayStart, sessions: sessions)
    }

    private func latestSleepStagePoint() async throws -> SleepStageTrendPoint? {
        guard let session = try await latestPrimarySleepSession() else { return nil }
        let breakdown = session.breakdown
        return SleepStageTrendPoint(
            date: Calendar.current.startOfDay(for: session.endDate),
            totalSleepHours: breakdown.totalSleepHours,
            deepPercent: breakdown.deepPercent,
            remPercent: breakdown.remPercent,
            awakePercent: breakdown.awakePercent
        )
    }

    private func primarySleepSessionsByWakeDay(days: Int) async throws -> [Date: SleepSessionCluster] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let queryStart = calendar.date(byAdding: .day, value: -(days + 3), to: todayStart) ?? todayStart
        let sessions = try await sleepSessions(from: queryStart, to: Date())

        var results: [Date: SleepSessionCluster] = [:]
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart
            if let session = primarySleepSession(forWakeDay: dayStart, sessions: sessions) {
                results[dayStart] = session
            }
        }

        return results
    }

    private func sleepSessions(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SleepSessionCluster] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
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
                        continuation.resume(returning: [])
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

                continuation.resume(returning: sessions)
            }

            healthStore.execute(query)
        }
    }

    private func quantitySamples(
        for identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
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

                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func averageQuantityDuringSession(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        session: SleepSessionCluster,
        treatZeroAsNil: Bool
    ) async throws -> Double? {
        let samples = try await quantitySamples(
            for: identifier,
            from: session.startDate,
            to: session.endDate
        )

        return averageValue(from: samples, during: session, unit: unit, treatZeroAsNil: treatZeroAsNil)
    }

    private func averageValue(
        from samples: [HKQuantitySample],
        during session: SleepSessionCluster,
        unit: HKUnit,
        treatZeroAsNil: Bool
    ) -> Double? {
        let overlappingSamples = samples.filter {
            $0.endDate > session.startDate && $0.startDate < session.endDate
        }

        guard !overlappingSamples.isEmpty else { return nil }

        var weightedTotal = 0.0
        var weightedDuration = 0.0
        var simpleValues: [Double] = []

        for sample in overlappingSamples {
            let overlapStart = max(sample.startDate, session.startDate)
            let overlapEnd = min(sample.endDate, session.endDate)
            let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
            let value = sample.quantity.doubleValue(for: unit)

            if overlapDuration > 0 {
                weightedTotal += value * overlapDuration
                weightedDuration += overlapDuration
            } else {
                simpleValues.append(value)
            }
        }

        let resolvedValue: Double?
        if weightedDuration > 0 {
            resolvedValue = weightedTotal / weightedDuration
        } else if !simpleValues.isEmpty {
            resolvedValue = simpleValues.reduce(0, +) / Double(simpleValues.count)
        } else {
            resolvedValue = nil
        }

        guard let resolvedValue else { return nil }
        if treatZeroAsNil, resolvedValue <= 0 {
            return nil
        }

        return resolvedValue
    }

    private func primarySleepSession(
        forWakeDay dayStart: Date,
        sessions: [SleepSessionCluster]
    ) -> SleepSessionCluster? {
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let sameWakeDay = sessions.filter {
            $0.endDate >= dayStart
                && $0.endDate < nextDay
                && $0.breakdown.totalSleepHours > 0
        }

        guard !sameWakeDay.isEmpty else { return nil }

        let crossesIntoWakeDay = sameWakeDay.filter { $0.startDate < dayStart }
        let earlyMorning = sameWakeDay.filter {
            calendar.component(.hour, from: $0.endDate) <= 12 && $0.breakdown.totalSleepHours >= 3
        }

        let candidates: [SleepSessionCluster]
        if !crossesIntoWakeDay.isEmpty {
            candidates = crossesIntoWakeDay
        } else if !earlyMorning.isEmpty {
            candidates = earlyMorning
        } else {
            candidates = sameWakeDay
        }

        return candidates.max { lhs, rhs in
            if lhs.breakdown.totalSleepHours == rhs.breakdown.totalSleepHours {
                return lhs.endDate < rhs.endDate
            }
            return lhs.breakdown.totalSleepHours < rhs.breakdown.totalSleepHours
        }
    }

    private func sleepStageBreakdown(
        from startDate: Date,
        to endDate: Date
    ) async throws -> SleepStageBreakdown? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
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
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let queryStart = calendar.date(byAdding: .day, value: -(days + 3), to: todayStart)!
        let sessions = try await sleepSessions(from: queryStart, to: Date())

        var points: [SleepStageTrendPoint] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart

            if let session = primarySleepSession(forWakeDay: dayStart, sessions: sessions) {
                let breakdown = session.breakdown
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
