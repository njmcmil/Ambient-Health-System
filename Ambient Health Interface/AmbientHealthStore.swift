import Foundation
import Combine
import HealthKit

@MainActor
/// Central app model for the ambient-health experience.
///
/// `AmbientHealthStore` is the boundary between raw HealthKit data and the rest of the UI:
/// - it owns HealthKit authorization
/// - loads current and trend data
/// - normalizes that data into app-friendly models
/// - classifies the latest health picture into a `ColorHealthState`
/// - exposes published values that SwiftUI views can render directly
///
/// The goal is to keep HealthKit complexity in one place so the view layer mostly consumes
/// interpreted data rather than repeating query or threshold logic.
final class AmbientHealthStore: ObservableObject {
    // These defaults are tuned for my current Apple Watch SE 3-oriented signal mix; subject to change
    struct SensitivityProfile {
        var stress: Double = 0.72
        var movement: Double = 0.48
        var recovery: Double = 0.68
        var overall: Double = 0.58

        static let `default` = SensitivityProfile()
    }

    enum SensitivityPreset: String, CaseIterable, Identifiable {
        case gentle = "Gentle"
        case recommended = "Recommended"
        case responsive = "Responsive"
        case custom = "Custom"

        var id: String { rawValue }

        var profile: SensitivityProfile {
            switch self {
            case .gentle:
                return .init(stress: 0.52, movement: 0.38, recovery: 0.56, overall: 0.45)
            case .recommended:
                return .default
            case .responsive:
                return .init(stress: 0.84, movement: 0.64, recovery: 0.80, overall: 0.72)
            case .custom:
                return .default
            }
        }
    }

    struct TrendPoint: Identifiable {
        let date: Date
        let value: Double

        var id: Date { date }
    }

    struct SleepStageTrendPoint: Identifiable {
        let date: Date
        let totalSleepHours: Double
        let deepPercent: Double
        let remPercent: Double
        let awakePercent: Double

        var id: Date { date }
    }

    struct StateTrendPoint: Identifiable {
        let date: Date
        let state: ColorHealthState

        var id: Date { date }
    }

    /// Bundles all multi-point series the UI needs after a refresh.
    ///
    /// The app intentionally derives charts and compact history surfaces from one shared report
    /// so the Now/Trends/Explanation tabs stay consistent with each other.
    struct TrendReport {
        let steps: [TrendPoint]
        let exerciseMinutes: [TrendPoint]
        let sleepHours: [TrendPoint]
        let restingHeartRate: [TrendPoint]
        let heartRateVariability: [TrendPoint]
        let sleepStages: [SleepStageTrendPoint]
        let intradayStateTrail: [StateTrendPoint]
        let stateTrail: [StateTrendPoint]
    }

    struct SleepStageBreakdown {
        let totalSleepHours: Double
        let inBedHours: Double
        let awakeHours: Double
        let coreHours: Double
        let deepHours: Double
        let remHours: Double
        let unspecifiedSleepHours: Double

        var deepPercent: Double {
            let total = coreHours + deepHours + remHours
            guard total > 0 else { return 0 }
            return (deepHours / total) * 100
        }

        var remPercent: Double {
            let total = coreHours + deepHours + remHours
            guard total > 0 else { return 0 }
            return (remHours / total) * 100
        }

        var awakePercent: Double {
            let total = coreHours + deepHours + remHours
            guard total > 0 else { return 0 }
            return (awakeHours / total) * 100
        }

        var efficiencyPercent: Double {
            guard inBedHours > 0 else { return 0 }
            return (totalSleepHours / inBedHours) * 100
        }

        var summaryLine: String {
            "Sleep \(String(format: "%.1f", totalSleepHours)) h  •  Deep \(Int(deepPercent))%  •  REM \(Int(remPercent))%  •  Awake \(Int(awakePercent))%"
        }
    }

    enum AuthorizationState {
        case unavailable
        case notDetermined
        case denied
        case partial
        case authorized

        var title: String {
            switch self {
            case .unavailable:
                return "Health data unavailable"
            case .notDetermined:
                return "HealthKit not connected"
            case .denied:
                return "HealthKit needs attention"
            case .partial:
                return "Connected with limited signal data"
            case .authorized:
                return "Connected to Apple Health"
            }
        }

        var detail: String {
            switch self {
            case .unavailable:
                return "Run on a physical iPhone with the Health app available to read live health data."
            case .notDetermined:
                return "Allow read access to movement, cardio, sleep, respiratory, mindfulness, and hydration signals to drive the ambient state."
            case .denied:
                return "Try reconnecting Health access, then refresh to pull live readings again."
            case .partial:
                return "HealthKit is reachable, but some of the ambient signals do not have recent readable samples yet."
            case .authorized:
                return "The ambient state now reflects recent Apple Health patterns."
            }
        }
    }

    enum HealthSignalStatus {
        case awaitingConnection
        case readable
        case noRecentData

        var title: String {
            switch self {
            case .awaitingConnection:
                return "Waiting for access"
            case .readable:
                return "Readable"
            case .noRecentData:
                return "No recent data"
            }
        }
    }

    struct HealthSignalEntry: Identifiable {
        let label: String
        let status: HealthSignalStatus

        var id: String { label }
    }

    /// A single "current health picture" used by the classifier and explanation layer.
    ///
    /// This is not a direct mirror of HealthKit objects. It is a normalized blend of:
    /// - current-day totals like steps and exercise
    /// - latest spot readings like heart rate or HRV
    /// - overnight recovery context like sleep stages
    struct Snapshot {
        let stepCountToday: Double?
        let activeEnergyToday: Double?
        let exerciseMinutesToday: Double?
        let walkingRunningDistanceToday: Double?
        let flightsClimbedToday: Double?
        let dietaryWaterTodayLiters: Double?
        let currentHeartRate: Double?
        let restingHeartRate: Double?
        let walkingHeartRateAverage: Double?
        let heartRateVariability: Double?
        let respiratoryRate: Double?
        let oxygenSaturationPercent: Double?
        let wristTemperatureCelsius: Double?
        let sleepHours: Double?
        let sleepStages: SleepStageBreakdown?
        let mindfulMinutesToday: Double?
        let sampledAt: Date
    }

    @Published private(set) var currentState: ColorHealthState = .gray
    @Published private(set) var history: [ColorHealthState] = []
    @Published private(set) var authorizationState: AuthorizationState
    @Published private(set) var latestSnapshot: Snapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var trendReport: TrendReport?
    @Published private(set) var sensitivityProfile: SensitivityProfile = .default
    @Published private(set) var sensitivityPreset: SensitivityPreset = .recommended
    @Published private(set) var signalEntries: [HealthSignalEntry] = []

    let healthStore = HKHealthStore()

    // Keep read types centralized so authorization and refresh stay in sync.
    private let healthTypes: Set<HKObjectType> = {
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .distanceWalkingRunning,
            .flightsClimbed,
            .dietaryWater,
            .heartRate,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .heartRateVariabilitySDNN,
            .respiratoryRate,
            .oxygenSaturation,
            .appleSleepingWristTemperature
        ]

        let categoryTypes: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .mindfulSession
        ]

        let quantities = quantityTypes.compactMap(HKObjectType.quantityType(forIdentifier:))
        let categories = categoryTypes.compactMap(HKObjectType.categoryType(forIdentifier:))
        return Set(quantities + categories)
    }()

    init() {
        authorizationState = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable

        guard HKHealthStore.isHealthDataAvailable() else { return }

        Task {
            // Do a lightweight auth check first so the app can restore gracefully on launch.
            await refreshAuthorizationState()
            if authorizationState == .authorized {
                await refresh()
            }
        }
    }

    var canRequestAuthorization: Bool {
        authorizationState == .notDetermined || authorizationState == .denied
    }

    var authorizationSummaryLine: String {
        // This summary intentionally talks about readable signal availability rather than pretending
        // we can always know a clean read-level granted/denied state for each HealthKit type.
        guard !signalEntries.isEmpty else {
            switch authorizationState {
            case .authorized:
                return "Connected. Pull to refresh and inspect the latest readable signals."
            case .partial:
                return "Some signals are readable, while others have not returned recent samples yet."
            default:
                return authorizationState.detail
            }
        }

        let readable = signalEntries.filter { $0.status == .readable }.count
        let noRecentData = signalEntries.filter { $0.status == .noRecentData }.count
        let waiting = signalEntries.count - readable - noRecentData

        if waiting > 0 {
            return "\(readable) readable  •  \(noRecentData) no recent data  •  \(waiting) waiting"
        }

        return "\(readable) readable  •  \(noRecentData) no recent data"
    }

    /// Condensed metric copy used where the app wants a quick textual summary instead of charts.
    var metricsLine: String {
        guard let snapshot = latestSnapshot else {
            return authorizationState.detail
        }

        var segments: [String] = []

        if let steps = snapshot.stepCountToday {
            segments.append("Steps \(Int(steps))")
        }

        if let activeEnergy = snapshot.activeEnergyToday {
            segments.append("Energy \(Int(activeEnergy)) kcal")
        }

        if let exerciseMinutes = snapshot.exerciseMinutesToday {
            segments.append("Exercise \(Int(exerciseMinutes)) min")
        }

        if let restingHeartRate = snapshot.restingHeartRate {
            segments.append("Resting HR \(Int(restingHeartRate)) bpm")
        }

        if let heartRateVariability = snapshot.heartRateVariability {
            segments.append("HRV \(Int(heartRateVariability)) ms")
        }

        if let respiratoryRate = snapshot.respiratoryRate {
            segments.append("Resp \(Int(respiratoryRate))/min")
        }

        if let wristTemperatureCelsius = snapshot.wristTemperatureCelsius {
            segments.append(String(format: "Wrist Temp %+0.1fC", wristTemperatureCelsius))
        }

        if let oxygenSaturationPercent = snapshot.oxygenSaturationPercent {
            segments.append("SpO2 \(Int(oxygenSaturationPercent))%")
        }

        if let sleepStages = snapshot.sleepStages {
            segments.append("Deep \(Int(sleepStages.deepPercent))%")
            segments.append("REM \(Int(sleepStages.remPercent))%")
            segments.append("Awake \(Int(sleepStages.awakePercent))%")
        } else if let sleepHours = snapshot.sleepHours {
            segments.append(String(format: "Sleep %.1f h", sleepHours))
        }

        if let mindfulMinutes = snapshot.mindfulMinutesToday, mindfulMinutes > 0 {
            segments.append("Mindful \(Int(mindfulMinutes)) min")
        }

        return segments.isEmpty ? authorizationState.detail : segments.prefix(6).joined(separator: "  •  ")
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        do {
            // We only request read access; the app is not writing samples back into Apple Health.
            try await healthStore.requestAuthorization(toShare: [], read: healthTypes)
            authorizationState = .authorized
            await refresh()
        } catch {
            authorizationState = .denied
            print("HealthKit authorization failed:", error.localizedDescription)
        }
    }

    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        // Read authorization can be ambiguous in HealthKit, pair auth status with real query results.
        await refreshAuthorizationState()

        guard authorizationState != .notDetermined else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let loadedSnapshot = try await loadSnapshot()
            let loadedTrends = try await loadTrendReport(days: 7, snapshot: loadedSnapshot)
            latestSnapshot = loadedSnapshot
            trendReport = loadedTrends
            signalEntries = signalEntries(for: loadedSnapshot)
            authorizationState = signalEntries.contains(where: { $0.status == .readable }) ? .authorized : .partial
            setState(classify(snapshot: loadedSnapshot), shouldSendToPi: true)
        } catch {
            signalEntries = signalEntries(for: latestSnapshot)
            authorizationState = .partial
            print("HealthKit refresh failed:", error.localizedDescription)
        }
    }

    func updateSensitivityProfile(_ profile: SensitivityProfile) {
        sensitivityProfile = profile
        sensitivityPreset = preset(matching: profile)

        // Re-run classification immediately so slider changes affect the live ambient state.
        guard let latestSnapshot else { return }
        setState(classify(snapshot: latestSnapshot), shouldSendToPi: true)
    }

    func applySensitivityPreset(_ preset: SensitivityPreset) {
        let resolvedProfile = preset.profile
        sensitivityProfile = resolvedProfile
        sensitivityPreset = preset

        guard let latestSnapshot else { return }
        setState(classify(snapshot: latestSnapshot), shouldSendToPi: true)
    }

    private func refreshAuthorizationState() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            signalEntries = []
            return
        }

        do {
            //  statusForAuthorizationRequest` is useful here because it tells us whether the system still expects a permission sheet
            let requestStatus = try await healthStore.statusForAuthorizationRequest(toShare: [], read: healthTypes)

            switch requestStatus {
            case .shouldRequest:
                authorizationState = .notDetermined
                signalEntries = signalEntries(for: nil)
            case .unnecessary:
                if let latestSnapshot {
                    signalEntries = signalEntries(for: latestSnapshot)
                    authorizationState = signalEntries.contains(where: { $0.status == .readable }) ? .authorized : .partial
                } else {
                    authorizationState = .authorized
                    signalEntries = []
                }
            case .unknown:
                authorizationState = .notDetermined
                signalEntries = signalEntries(for: nil)
            @unknown default:
                authorizationState = .notDetermined
                signalEntries = signalEntries(for: nil)
            }
        } catch {
            authorizationState = .notDetermined
            signalEntries = signalEntries(for: nil)
        }
    }

    private func setState(_ newState: ColorHealthState, shouldSendToPi: Bool) {
        currentState = newState
        history.append(newState)

        // This short history powers lightweight UI hints, not a permanent audit trail.
        if history.count > 7 {
            history.removeFirst()
        }

        if shouldSendToPi {
            PiController.shared.sendHealthState(newState)
        }
    }

    private func classify(snapshot: Snapshot) -> ColorHealthState {
        // The classifier blends movement, stress/load, and recovery instead of relying on any single metric.
        let profile = sensitivityProfile
        let steps = snapshot.stepCountToday ?? 0
        let activeEnergy = snapshot.activeEnergyToday ?? 0
        let exerciseMinutes = snapshot.exerciseMinutesToday ?? 0
        let waterLiters = snapshot.dietaryWaterTodayLiters ?? 0
        let currentHeartRate = snapshot.currentHeartRate ?? 75
        let restingHeartRate = snapshot.restingHeartRate ?? 70
        let walkingHeartRateAverage = snapshot.walkingHeartRateAverage ?? restingHeartRate + 10
        let heartRateVariability = snapshot.heartRateVariability ?? 40
        let respiratoryRate = snapshot.respiratoryRate ?? 15
        let oxygenSaturationPercent = snapshot.oxygenSaturationPercent
        let wristTemperatureCelsius = snapshot.wristTemperatureCelsius ?? 0
        let sleepHours = snapshot.sleepHours ?? 7
        let sleepStages = snapshot.sleepStages
        let mindfulMinutes = snapshot.mindfulMinutesToday ?? 0

        let deepSleepPercent = sleepStages?.deepPercent ?? 16
        let remSleepPercent = sleepStages?.remPercent ?? 20
        let awakePercent = sleepStages?.awakePercent ?? 8
        let sleepEfficiency = sleepStages?.efficiencyPercent ?? 88

        let stressWeight = normalizedSensitivity(profile.stress, overall: profile.overall)
        let movementWeight = normalizedSensitivity(profile.movement, overall: profile.overall)
        let recoveryWeight = normalizedSensitivity(profile.recovery, overall: profile.overall)

        let movementLowStepThreshold = interpolate(low: 1_400, high: 3_500, factor: movementWeight)
        let movementLowExerciseThreshold = interpolate(low: 6, high: 18, factor: movementWeight)
        let movementLowEnergyThreshold = interpolate(low: 180, high: 340, factor: movementWeight)

        let movementStrongStepThreshold = interpolate(low: 8_000, high: 5_000, factor: movementWeight)
        let movementStrongExerciseThreshold = interpolate(low: 36, high: 18, factor: movementWeight)
        let movementStrongEnergyThreshold = interpolate(low: 520, high: 320, factor: movementWeight)

        let sleepWeakThreshold = interpolate(low: 5.0, high: 6.6, factor: recoveryWeight)
        let hrvWeakThreshold = interpolate(low: 18, high: 30, factor: recoveryWeight)
        let restingHighThreshold = interpolate(low: 90, high: 78, factor: recoveryWeight)

        let sleepStrongThreshold = interpolate(low: 8.6, high: 7.0, factor: recoveryWeight)
        let hrvStrongThreshold = interpolate(low: 58, high: 44, factor: recoveryWeight)
        let restingStrongThreshold = interpolate(low: 60, high: 66, factor: recoveryWeight)

        let stressHeartRateThreshold = interpolate(low: 106, high: 92, factor: stressWeight)
        let stressWalkingHeartRateThreshold = interpolate(low: 126, high: 112, factor: stressWeight)
        let stressHrvThreshold = interpolate(low: 24, high: 34, factor: stressWeight)
        let stressRespThreshold = interpolate(low: 20, high: 17, factor: stressWeight)

        let cardioStrainHeartRateThreshold = interpolate(low: 118, high: 104, factor: stressWeight)
        let cardioStrainWalkingThreshold = interpolate(low: 134, high: 120, factor: stressWeight)
        let respiratoryStrainThreshold = interpolate(low: 21, high: 18.5, factor: stressWeight)
        let temperatureStrain = wristTemperatureCelsius >= interpolate(low: 0.9, high: 0.5, factor: stressWeight)
        let temperatureHigh = wristTemperatureCelsius >= interpolate(low: 1.2, high: 0.8, factor: stressWeight)

        // Movement is treated as a broad activity baseline rather than a strict workout-only signal.
        let movementLow = steps < movementLowStepThreshold && exerciseMinutes < movementLowExerciseThreshold && activeEnergy < movementLowEnergyThreshold
        let movementStrong = steps >= movementStrongStepThreshold || exerciseMinutes >= movementStrongExerciseThreshold || activeEnergy >= movementStrongEnergyThreshold
        // Sleep quality matters as much as sleep quantity for recovery-oriented states.
        let sleepStageStrong = deepSleepPercent >= interpolate(low: 18, high: 13, factor: recoveryWeight)
            && remSleepPercent >= interpolate(low: 22, high: 17, factor: recoveryWeight)
            && awakePercent <= interpolate(low: 12, high: 8, factor: recoveryWeight)
            && sleepEfficiency >= interpolate(low: 88, high: 80, factor: recoveryWeight)
        let sleepStageWeak = deepSleepPercent < interpolate(low: 8, high: 13, factor: recoveryWeight)
            || remSleepPercent < interpolate(low: 13, high: 17, factor: recoveryWeight)
            || awakePercent >= interpolate(low: 20, high: 13, factor: recoveryWeight)
            || sleepEfficiency < interpolate(low: 74, high: 82, factor: recoveryWeight)
        let recoveryStrong = sleepHours >= sleepStrongThreshold && sleepStageStrong && heartRateVariability >= hrvStrongThreshold && restingHeartRate <= restingStrongThreshold
        let recoveryWeak = sleepHours < sleepWeakThreshold || sleepStageWeak || heartRateVariability < hrvWeakThreshold || restingHeartRate >= restingHighThreshold
        let stressElevated = currentHeartRate >= stressHeartRateThreshold || walkingHeartRateAverage >= stressWalkingHeartRateThreshold || heartRateVariability < stressHrvThreshold || respiratoryRate > stressRespThreshold
        let cardioStrain = currentHeartRate >= cardioStrainHeartRateThreshold || walkingHeartRateAverage >= cardioStrainWalkingThreshold
        let respiratoryStrain = respiratoryRate >= respiratoryStrainThreshold
        let calmingSignals = mindfulMinutes >= 10 || waterLiters >= 1.5
        let oxygenConcern = oxygenSaturationPercent.map { $0 < 95 } ?? false
        let oxygenCritical = oxygenSaturationPercent.map { $0 < 94 } ?? false

        // State ordering matters. The more acute / stacked conditions are checked first so they
        // do not get swallowed by softer states like orange, purple, or yellow.
        if temperatureHigh || cardioStrain && recoveryWeak || oxygenCritical || (recoveryWeak && stressElevated && respiratoryStrain) {
            return .red
        }

        if recoveryWeak || (restingHeartRate > 82 && heartRateVariability < 28) || temperatureStrain || oxygenConcern {
            return .orange
        }

        if stressElevated && !calmingSignals {
            return .purple
        }

        if movementLow {
            return .yellow
        }

        if recoveryStrong && movementStrong && respiratoryRate <= 16 && wristTemperatureCelsius < 0.4 {
            return .blue
        }

        if movementStrong && sleepHours >= 6.5 && heartRateVariability >= 35 && restingHeartRate <= 75 {
            return .green
        }

        return .gray
    }

    private func loadSnapshot() async throws -> Snapshot {
        // Snapshot values describe "now" and intentionally mix current-day totals with latest spot readings.
        async let steps = totalStepCountToday()
        async let activeEnergy = totalQuantityToday(for: .activeEnergyBurned, unit: .kilocalorie())
        async let exerciseMinutes = totalQuantityToday(for: .appleExerciseTime, unit: .minute())
        async let walkingRunningDistance = totalQuantityToday(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo))
        async let flightsClimbed = totalQuantityToday(for: .flightsClimbed, unit: .count())
        async let dietaryWater = totalQuantityToday(for: .dietaryWater, unit: .liter())
        async let currentHeartRate = latestQuantityValue(
            for: .heartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let restingHeartRate = latestQuantityValue(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let walkingHeartRateAverage = latestQuantityValue(
            for: .walkingHeartRateAverage,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let heartRateVariability = latestQuantityValue(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli)
        )
        async let respiratoryRate = latestQuantityValue(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let oxygenSaturation = latestQuantityValue(for: .oxygenSaturation, unit: .percent())
        async let wristTemperature = latestQuantityValue(for: .appleSleepingWristTemperature, unit: .degreeCelsius())
        async let sleepHours = sleepHoursSinceYesterdayEvening()
        async let sleepStages = sleepStageBreakdownSinceYesterdayEvening()
        async let mindfulMinutes = categoryDurationToday(for: .mindfulSession)

        return try await Snapshot(
            stepCountToday: steps,
            activeEnergyToday: activeEnergy,
            exerciseMinutesToday: exerciseMinutes,
            walkingRunningDistanceToday: walkingRunningDistance,
            flightsClimbedToday: flightsClimbed,
            dietaryWaterTodayLiters: dietaryWater,
            currentHeartRate: currentHeartRate,
            restingHeartRate: restingHeartRate,
            walkingHeartRateAverage: walkingHeartRateAverage,
            heartRateVariability: heartRateVariability,
            respiratoryRate: respiratoryRate,
            oxygenSaturationPercent: oxygenSaturation.map { $0 * 100 },
            wristTemperatureCelsius: wristTemperature,
            sleepHours: sleepHours,
            sleepStages: sleepStages,
            mindfulMinutesToday: mindfulMinutes,
            sampledAt: Date()
        )
    }

    private func loadTrendReport(
        days: Int,
        snapshot: Snapshot
    ) async throws -> TrendReport {
        // Trend data powers both the charts and the compact history surfaces on the Now screen.
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
        let loadedHourlySteps = try await hourlySteps
        let loadedHourlyExercise = try await hourlyExercise
        let loadedHourlyHeartRate = try await hourlyHeartRate
        let loadedHourlyRespiratoryRate = try await hourlyRespiratoryRate

        let sleepHours = loadedSleepStages.map {
            TrendPoint(date: $0.date, value: $0.totalSleepHours)
        }

        // Derived state trails intentionally reuse the same classification model as the live object.
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
            intradayStateTrail: intradayStateTrail,
            stateTrail: stateTrail
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
                    // Optional signals should come back as nil rather than failing the whole refresh.
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
                // Missing buckets are represented as zero so charts keep a stable 7-day rhythm.
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
                // Average-based signals use zero as an empty placeholder so the UI can still render the window.
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
        unit: HKUnit
    ) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
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
                let value = sample?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func sleepHoursSinceYesterdayEvening() async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .hour, value: -18, to: startOfToday) ?? startOfToday
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
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

                let totalSeconds = sleepSamples.reduce(0.0) { partialResult, sample in
                    guard sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue else {
                        return partialResult
                    }

                    return partialResult + sample.endDate.timeIntervalSince(sample.startDate)
                }

                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }

            healthStore.execute(query)
        }
    }

    private func sleepStageBreakdownSinceYesterdayEvening() async throws -> SleepStageBreakdown? {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .hour, value: -12, to: startOfToday) ?? startOfToday
        return try await sleepStageBreakdown(from: startDate, to: now)
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
                guard !sleepSamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // HealthKit sleep samples arrive as separate stage slices that need to be re-aggregated.
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

                let totalSleepSeconds = coreSeconds + deepSeconds + remSeconds

                continuation.resume(
                    returning: SleepStageBreakdown(
                        totalSleepHours: totalSleepSeconds / 3600,
                        inBedHours: inBedSeconds / 3600,
                        awakeHours: awakeSeconds / 3600,
                        coreHours: coreSeconds / 3600,
                        deepHours: deepSeconds / 3600,
                        remHours: remSeconds / 3600,
                        unspecifiedSleepHours: unspecifiedSleepSeconds / 3600
                    )
                )
            }

            healthStore.execute(query)
        }
    }

    private func dailySleepStageSeries(days: Int) async throws -> [SleepStageTrendPoint] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        var points: [SleepStageTrendPoint] = []

        for offset in stride(from: days - 1, through: 0, by: -1) {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let windowStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart

            if let breakdown = try await sleepStageBreakdown(from: windowStart, to: nextDay) {
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
                continue
            }
        }

        return points
    }

    private func deriveStateTrail(
        steps: [TrendPoint],
        exerciseMinutes: [TrendPoint],
        sleepStages: [SleepStageTrendPoint],
        restingHeartRate: [TrendPoint],
        heartRateVariability: [TrendPoint]
    ) -> [StateTrendPoint] {
        // Daily trend states are reconstructed from the same classifier so charts and Now stay consistent.
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { ($0.date, $0.value) })
        let sleepMap = Dictionary(uniqueKeysWithValues: sleepStages.map { ($0.date, $0) })
        let restingMap = Dictionary(uniqueKeysWithValues: restingHeartRate.map { ($0.date, $0.value) })
        let hrvMap = Dictionary(uniqueKeysWithValues: heartRateVariability.map { ($0.date, $0.value) })

        return steps.map { stepPoint in
            let sleepStage = sleepMap[stepPoint.date]
            let snapshot = Snapshot(
                stepCountToday: stepPoint.value,
                activeEnergyToday: nil,
                exerciseMinutesToday: exerciseMap[stepPoint.date],
                walkingRunningDistanceToday: nil,
                flightsClimbedToday: nil,
                dietaryWaterTodayLiters: nil,
                currentHeartRate: nil,
                restingHeartRate: restingMap[stepPoint.date],
                walkingHeartRateAverage: nil,
                heartRateVariability: hrvMap[stepPoint.date],
                respiratoryRate: nil,
                oxygenSaturationPercent: nil,
                wristTemperatureCelsius: nil,
                sleepHours: sleepStage?.totalSleepHours,
                sleepStages: sleepStage.map {
                    SleepStageBreakdown(
                        totalSleepHours: $0.totalSleepHours,
                        inBedHours: $0.totalSleepHours,
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

            return StateTrendPoint(date: stepPoint.date, state: classify(snapshot: snapshot))
        }
    }

    private func deriveIntradayStateTrail(
        steps: [TrendPoint],
        exerciseMinutes: [TrendPoint],
        heartRate: [TrendPoint],
        respiratoryRate: [TrendPoint],
        snapshot: Snapshot
    ) -> [StateTrendPoint] {
        // day states reuse the current snapshot as context, then swap in hourly values where available.
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseMinutes.map { ($0.date, $0.value) })
        let heartRateMap = Dictionary(uniqueKeysWithValues: heartRate.map { ($0.date, $0.value) })
        let respiratoryRateMap = Dictionary(uniqueKeysWithValues: respiratoryRate.map { ($0.date, $0.value) })

        return steps.map { stepPoint in
            let hourlySnapshot = Snapshot(
                stepCountToday: stepPoint.value,
                activeEnergyToday: snapshot.activeEnergyToday,
                exerciseMinutesToday: exerciseMap[stepPoint.date] ?? snapshot.exerciseMinutesToday,
                walkingRunningDistanceToday: snapshot.walkingRunningDistanceToday,
                flightsClimbedToday: snapshot.flightsClimbedToday,
                dietaryWaterTodayLiters: snapshot.dietaryWaterTodayLiters,
                currentHeartRate: heartRateMap[stepPoint.date] == 0 ? snapshot.currentHeartRate : heartRateMap[stepPoint.date],
                restingHeartRate: snapshot.restingHeartRate,
                walkingHeartRateAverage: snapshot.walkingHeartRateAverage,
                heartRateVariability: snapshot.heartRateVariability,
                respiratoryRate: respiratoryRateMap[stepPoint.date] == 0 ? snapshot.respiratoryRate : respiratoryRateMap[stepPoint.date],
                oxygenSaturationPercent: snapshot.oxygenSaturationPercent,
                wristTemperatureCelsius: snapshot.wristTemperatureCelsius,
                sleepHours: snapshot.sleepHours,
                sleepStages: snapshot.sleepStages,
                mindfulMinutesToday: snapshot.mindfulMinutesToday,
                sampledAt: stepPoint.date
            )

            return StateTrendPoint(date: stepPoint.date, state: classify(snapshot: hourlySnapshot))
        }
    }

    private func normalizedSensitivity(_ sliderValue: Double, overall: Double) -> Double {
        min(max((sliderValue * 0.7) + (overall * 0.3), 0), 1)
    }

    private func interpolate(low: Double, high: Double, factor: Double) -> Double {
        low + (high - low) * factor
    }

    private func preset(matching profile: SensitivityProfile) -> SensitivityPreset {
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

    nonisolated private static func isNoDataError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Some HealthKit queries return "no data" for a window; treated as empty context.
        if nsError.domain == HKError.errorDomain,
           let code = HKError.Code(rawValue: nsError.code),
           code == .errorNoData {
            return true
        }

        return nsError.localizedDescription.localizedCaseInsensitiveContains("no data available")
    }

    private func signalEntries(for snapshot: Snapshot?) -> [HealthSignalEntry] {
        let entries: [(String, Bool)] = [
            ("Steps", snapshot?.stepCountToday != nil),
            ("Active Energy", snapshot?.activeEnergyToday != nil),
            ("Exercise Time", snapshot?.exerciseMinutesToday != nil),
            ("Walking Distance", snapshot?.walkingRunningDistanceToday != nil),
            ("Flights Climbed", snapshot?.flightsClimbedToday != nil),
            ("Hydration", snapshot?.dietaryWaterTodayLiters != nil),
            ("Heart Rate", snapshot?.currentHeartRate != nil),
            ("Resting Heart Rate", snapshot?.restingHeartRate != nil),
            ("Walking Heart Rate", snapshot?.walkingHeartRateAverage != nil),
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
