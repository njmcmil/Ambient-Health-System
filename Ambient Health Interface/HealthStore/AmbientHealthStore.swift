import Foundation
import Combine
import HealthKit

@MainActor
/// Central app model for the ambient-health experience.
///
/// `AmbientHealthStore` owns the live health snapshot, the baseline used to interpret it,
/// and the published state the rest of the app renders. The heavier work is split into
/// companion files so this core type stays readable:
/// - `AmbientHealthStore+Models.swift` defines app-facing models
/// - `AmbientHealthStore+Classifier.swift` turns health signals into mood states
/// - `AmbientHealthStore+Queries.swift` handles HealthKit reads and trend loading
final class AmbientHealthStore: ObservableObject {
    @Published private(set) var currentState: ColorHealthState = .gray
    @Published private(set) var previewState: ColorHealthState?
    @Published private(set) var history: [ColorHealthState] = []
    @Published private(set) var authorizationState: AuthorizationState
    @Published private(set) var latestSnapshot: Snapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var trendReport: TrendReport?
    @Published private(set) var baselineSummary: BaselineSummary?
    @Published private(set) var sensitivityProfile: SensitivityProfile = .default
    @Published private(set) var sensitivityPreset: SensitivityPreset = .recommended
    @Published private(set) var signalEntries: [HealthSignalEntry] = []
    @Published private(set) var lastRefreshAttemptAt: Date?
    @Published private(set) var lastSuccessfulHealthReadAt: Date?
    @Published private(set) var latestClassificationDebug: ClassificationDebugReport?
    @Published private(set) var isDemoModeEnabled = false
    @Published private(set) var demoDataset: DemoDataset = .grounded

    let healthStore = HKHealthStore()
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private var supplementalRefreshTask: Task<Void, Never>?
    private var refreshWatchdogTask: Task<Void, Never>?
    private var postAuthorizationRefreshTask: Task<Void, Never>?
    private var activeRefreshID = UUID()
    private var authorizationCooldownUntil: Date?
    private var preservedLiveHistoryBeforeDemo: [ColorHealthState]?
    private var preservedLiveStateBeforeDemo: ColorHealthState?

    var displayedState: ColorHealthState {
        previewState ?? currentState
    }

    // Keep the read set centralized so authorization and live refresh use the same signals.
    private let healthTypes: Set<HKObjectType> = {
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .distanceWalkingRunning,
            .flightsClimbed,
            .heartRate,
            .restingHeartRate,
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
        return Set(quantities + categories + [HKObjectType.workoutType()])
    }()

    init() {
        authorizationState = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable

        guard HKHealthStore.isHealthDataAvailable() else { return }

        Task {
            await refreshAuthorizationState()
        }
    }

    var canRequestAuthorization: Bool {
        authorizationState == .notDetermined || authorizationState == .denied
    }

    var authorizationSummaryLine: String {
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

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthTypes)
            authorizationState = .authorized
            signalEntries = signalEntries(for: latestSnapshot)
            authorizationCooldownUntil = Date().addingTimeInterval(3)
            schedulePostAuthorizationRefresh()
        } catch {
            authorizationState = .denied
            print("HealthKit authorization failed:", error.localizedDescription)
        }
    }

    func refresh() async {
        if isDemoModeEnabled {
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }
        guard !isRefreshing else { return }

        lastRefreshAttemptAt = Date()
        isRefreshing = true
        await refreshAuthorizationState()
        guard authorizationState != .notDetermined else {
            isRefreshing = false
            return
        }

        supplementalRefreshTask?.cancel()
        let refreshID = UUID()
        activeRefreshID = refreshID
        startRefreshWatchdog(for: refreshID)

        do {
            let loadedSnapshot = try await loadSnapshot()

            latestSnapshot = loadedSnapshot
            lastSuccessfulHealthReadAt = loadedSnapshot.sampledAt
            signalEntries = signalEntries(for: loadedSnapshot)
            authorizationState = signalEntries.contains(where: { $0.status == .readable }) ? .authorized : .partial

            setState(classify(snapshot: loadedSnapshot, baseline: baselineSummary), shouldSendToPi: true)
            latestClassificationDebug = buildClassificationDebugReport(snapshot: loadedSnapshot, baseline: baselineSummary)
            finishRefreshPhase(for: refreshID)

            supplementalRefreshTask = Task { [weak self] in
                guard let self else { return }
                await self.refreshSupplementalContext(for: loadedSnapshot, refreshID: refreshID)
            }
        } catch {
            finishRefreshPhase(for: refreshID)
            signalEntries = signalEntries(for: latestSnapshot)
            authorizationState = .partial
            print("HealthKit refresh failed:", error.localizedDescription)
        }
    }

    func refreshIfNeeded() async {
        if isDemoModeEnabled {
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard authorizationState == .authorized || authorizationState == .partial else { return }
        guard !isRefreshing else { return }
        if let authorizationCooldownUntil, Date() < authorizationCooldownUntil {
            return
        }

        let snapshotAge = latestSnapshot.map { Date().timeIntervalSince($0.sampledAt) } ?? .infinity
        let missingCoreSignals = [
            latestSnapshot?.restingHeartRate == nil,
            latestSnapshot?.heartRateVariability == nil,
            latestSnapshot?.sleepHours == nil && latestSnapshot?.sleepStages == nil
        ]
        .filter { $0 }
        .count

        let missingSleepContext = latestSnapshot?.sleepHours == nil && latestSnapshot?.sleepStages == nil

        if latestSnapshot == nil
            || snapshotAge > 60 * 20
            || missingCoreSignals >= 2
            || (missingSleepContext && snapshotAge > 60 * 5) {
            await refresh()
        }
    }

    func updateSensitivityProfile(_ profile: SensitivityProfile, shouldSendToPi: Bool = true) {
        sensitivityProfile = profile
        sensitivityPreset = preset(matching: profile)

        guard let latestSnapshot else { return }
        let evaluated = classify(snapshot: latestSnapshot, baseline: baselineSummary)
        setState(evaluated, shouldSendToPi: shouldSendToPi)
        latestClassificationDebug = buildClassificationDebugReport(snapshot: latestSnapshot, baseline: baselineSummary)
    }

    func applySensitivityPreset(_ preset: SensitivityPreset) {
        let resolvedProfile = preset.profile
        sensitivityProfile = resolvedProfile
        sensitivityPreset = preset

        guard let latestSnapshot else { return }
        let evaluated = classify(snapshot: latestSnapshot, baseline: baselineSummary)
        setState(evaluated, shouldSendToPi: true)
        latestClassificationDebug = buildClassificationDebugReport(snapshot: latestSnapshot, baseline: baselineSummary)
    }

    func setPreviewState(_ state: ColorHealthState?) {
        previewState = state

        if let state {
            PiController.shared.sendHealthState(state)
        } else {
            PiController.shared.sendHealthState(currentState)
        }
    }

    func setDemoMode(enabled: Bool) {
        guard isDemoModeEnabled != enabled else { return }
        isDemoModeEnabled = enabled

        if enabled {
            preservedLiveHistoryBeforeDemo = history
            preservedLiveStateBeforeDemo = currentState
            applyDemoDataset()
        } else {
            if let preservedState = preservedLiveStateBeforeDemo {
                currentState = preservedState
            }
            if let preservedHistory = preservedLiveHistoryBeforeDemo {
                history = preservedHistory
            }
            preservedLiveStateBeforeDemo = nil
            preservedLiveHistoryBeforeDemo = nil

            // Immediately return the ambient object to the restored live state.
            if previewState == nil {
                PiController.shared.sendHealthState(currentState)
            }

            latestSnapshot = nil
            trendReport = nil
            baselineSummary = nil
            latestClassificationDebug = nil
            Task { [weak self] in
                guard let self else { return }
                await self.refresh()
            }
        }
    }

    func setDemoDataset(_ dataset: DemoDataset) {
        demoDataset = dataset
        guard isDemoModeEnabled else { return }
        applyDemoDataset()
    }

    private func refreshAuthorizationState() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            signalEntries = []
            return
        }

        do {
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

    private func refreshSupplementalContext(for snapshot: Snapshot, refreshID: UUID) async {
        do {
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            let enrichedSnapshot = try await enrichSnapshot(snapshot)
            guard activeRefreshID == refreshID else { return }
            guard latestSnapshot?.sampledAt == snapshot.sampledAt else { return }

            latestSnapshot = enrichedSnapshot
            signalEntries = signalEntries(for: enrichedSnapshot)
            authorizationState = signalEntries.contains(where: { $0.status == .readable }) ? .authorized : .partial

            let loadedBaseline = try await loadBaselineSummary(days: 21)
            let loadedTrends = try await loadTrendReport(days: 7, snapshot: enrichedSnapshot)

            guard activeRefreshID == refreshID else { return }
            guard latestSnapshot?.sampledAt == enrichedSnapshot.sampledAt else { return }

            baselineSummary = loadedBaseline
            trendReport = loadedTrends
            let evaluated = classify(snapshot: enrichedSnapshot, baseline: loadedBaseline)
            setState(evaluated, shouldSendToPi: true)
            latestClassificationDebug = buildClassificationDebugReport(snapshot: enrichedSnapshot, baseline: loadedBaseline)
        } catch {
            print("Supplemental HealthKit refresh failed:", error.localizedDescription)
        }
    }

    private func startRefreshWatchdog(for refreshID: UUID) {
        refreshWatchdogTask?.cancel()
        refreshWatchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard let self else { return }
            guard self.activeRefreshID == refreshID else { return }
            guard self.isRefreshing else { return }
            self.isRefreshing = false
            print("HealthKit refresh watchdog cleared a long-running refresh state.")
        }
    }

    private func finishRefreshPhase(for refreshID: UUID) {
        guard activeRefreshID == refreshID else { return }
        isRefreshing = false
        refreshWatchdogTask?.cancel()
        refreshWatchdogTask = nil
    }

    private func schedulePostAuthorizationRefresh() {
        postAuthorizationRefreshTask?.cancel()
        postAuthorizationRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.refreshIfNeeded()
        }
    }

    private func setState(_ newState: ColorHealthState, shouldSendToPi: Bool) {
        guard newState != currentState else { return }

        if isDemoModeEnabled {
            currentState = newState
            if shouldSendToPi && previewState == nil {
                PiController.shared.sendHealthState(newState)
            }
            return
        }

        currentState = newState
        history.append(newState)

        if history.count > 7 {
            history.removeFirst()
        }

        if shouldSendToPi && previewState == nil {
            PiController.shared.sendHealthState(newState)
        }
    }

    func preset(matching profile: SensitivityProfile) -> SensitivityPreset {
        let presets = SensitivityPreset.allCases.filter { $0 != .custom }
        guard let closest = presets.min(by: {
            sensitivityDistance(profile, $0.profile) < sensitivityDistance(profile, $1.profile)
        }) else {
            return .custom
        }

        return sensitivityDistance(profile, closest.profile) < 0.05 ? closest : .custom
    }

    private func applyDemoDataset() {
        let calendar = Calendar.current
        let now = Date()
        let template = demoTemplate(for: demoDataset)
        let dayStarts = (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: calendar.startOfDay(for: now)) }

        let demoSnapshot = Snapshot(
            recentWorkoutMinutes: template.snapshot.recentWorkoutMinutes,
            minutesSinceRecentWorkout: template.snapshot.minutesSinceRecentWorkout,
            stepCountToday: template.snapshot.steps,
            activeEnergyToday: template.snapshot.activeEnergy,
            exerciseMinutesToday: template.snapshot.exercise,
            walkingRunningDistanceToday: template.snapshot.distance,
            flightsClimbedToday: template.snapshot.flights,
            currentHeartRate: template.snapshot.currentHR,
            restingHeartRate: template.snapshot.restingHR,
            heartRateVariability: template.snapshot.hrv,
            respiratoryRate: template.snapshot.respiratory,
            oxygenSaturationPercent: template.snapshot.oxygen,
            wristTemperatureCelsius: template.snapshot.wristTempDelta,
            sleepHours: template.snapshot.sleepHours,
            sleepStages: SleepStageBreakdown(
                totalSleepHours: template.snapshot.sleepHours,
                inBedHours: template.snapshot.sleepHours + template.snapshot.awakeHours,
                awakeHours: template.snapshot.awakeHours,
                coreHours: template.snapshot.coreHours,
                deepHours: template.snapshot.deepHours,
                remHours: template.snapshot.remHours,
                unspecifiedSleepHours: template.snapshot.unspecifiedSleepHours
            ),
            mindfulMinutesToday: template.snapshot.mindfulMinutes,
            sampledAt: now
        )

        let demoBaseline = BaselineSummary(
            windowDays: 21,
            restingHeartRate: MetricBaseline(mean: 66.8, standardDeviation: 2.5, sampleCount: 18),
            heartRateVariability: MetricBaseline(mean: 39.2, standardDeviation: 4.1, sampleCount: 17),
            respiratoryRate: MetricBaseline(mean: 14.8, standardDeviation: 0.9, sampleCount: 16),
            sleepHours: MetricBaseline(mean: 7.05, standardDeviation: 0.55, sampleCount: 20),
            deepSleepPercent: MetricBaseline(mean: 17.0, standardDeviation: 2.2, sampleCount: 14),
            remSleepPercent: MetricBaseline(mean: 19.1, standardDeviation: 2.0, sampleCount: 14),
            awakePercent: MetricBaseline(mean: 9.8, standardDeviation: 2.1, sampleCount: 14),
            stepCount: MetricBaseline(mean: 5_150, standardDeviation: 1_240, sampleCount: 20),
            exerciseMinutes: MetricBaseline(mean: 21.5, standardDeviation: 8.2, sampleCount: 20)
        )

        let stepsSeries: [TrendPoint] = zip(dayStarts, template.week.steps).map { TrendPoint(date: $0.0, value: $0.1) }
        let exerciseSeries: [TrendPoint] = zip(dayStarts, template.week.exercise).map { TrendPoint(date: $0.0, value: $0.1) }
        let sleepSeries: [TrendPoint] = zip(dayStarts, template.week.sleepHours).map { TrendPoint(date: $0.0, value: $0.1) }
        let restingSeries: [TrendPoint] = zip(dayStarts, template.week.restingHR).map { TrendPoint(date: $0.0, value: $0.1) }
        let hrvSeries: [TrendPoint] = zip(dayStarts, template.week.hrv).map { TrendPoint(date: $0.0, value: $0.1) }
        let sleepStageSeries: [SleepStageTrendPoint] = zip(dayStarts, template.week.sleepStages).map { day, value in
            SleepStageTrendPoint(date: day, totalSleepHours: value.0, deepPercent: value.1, remPercent: value.2, awakePercent: value.3)
        }

        let stateTrail: [StateTrendPoint] = zip(dayStarts, template.week.stateTrail).map { StateTrendPoint(date: $0.0, state: $0.1) }

        let intradayTrailTimes = [7, 10, 13, 16, 19, 22].compactMap { calendar.date(bySettingHour: $0, minute: 0, second: 0, of: now) }
        let intradayStateTrail: [StateTrendPoint] = zip(intradayTrailTimes, template.intradayStateTrail).map { StateTrendPoint(date: $0.0, state: $0.1) }

        let demoTrendReport = TrendReport(
            steps: stepsSeries,
            exerciseMinutes: exerciseSeries,
            sleepHours: sleepSeries,
            restingHeartRate: restingSeries,
            heartRateVariability: hrvSeries,
            sleepStages: sleepStageSeries,
            latestSleepStage: sleepStageSeries.last,
            intradayStateTrail: intradayStateTrail,
            stateTrail: stateTrail
        )

        latestSnapshot = demoSnapshot
        baselineSummary = demoBaseline
        trendReport = demoTrendReport
        lastRefreshAttemptAt = now
        lastSuccessfulHealthReadAt = now
        authorizationState = .authorized
        signalEntries = signalEntries(for: demoSnapshot)

        let state = template.targetState
        previewState = nil
        setState(state, shouldSendToPi: true)
        latestClassificationDebug = buildClassificationDebugReport(snapshot: demoSnapshot, baseline: demoBaseline)
    }

    private func demoTemplate(for dataset: DemoDataset) -> DemoTemplate {
        switch dataset {
        case .restored:
            return DemoTemplate(
                targetState: .blue,
                snapshot: .init(
                    steps: 7_100, activeEnergy: 470, exercise: 34, distance: 5_700, flights: 12,
                    currentHR: 72, restingHR: 60, hrv: 52, respiratory: 13.5, oxygen: 98.2, wristTempDelta: 0.02,
                    sleepHours: 8.2, awakeHours: 0.28, coreHours: 3.8, deepHours: 1.95, remHours: 2.0,
                    unspecifiedSleepHours: 0.45, mindfulMinutes: 12, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [6200, 6800, 7400, 7100, 7600, 6900, 7100],
                    exercise: [24, 29, 32, 31, 35, 28, 34],
                    sleepHours: [7.7, 8.0, 8.4, 8.1, 8.3, 7.9, 8.2],
                    restingHR: [63, 62, 60, 61, 60, 62, 60],
                    hrv: [45, 47, 50, 49, 52, 48, 52],
                    sleepStages: [(7.7, 18, 21, 8), (8.0, 19, 21, 8), (8.4, 20, 22, 7), (8.1, 19, 21, 8), (8.3, 20, 22, 7), (7.9, 18, 21, 8), (8.2, 20, 22, 7)],
                    stateTrail: [.green, .green, .blue, .green, .blue, .green, .blue]
                ),
                intradayStateTrail: [.green, .green, .blue, .blue, .blue, .green]
            )
        case .grounded:
            return DemoTemplate(
                targetState: .green,
                snapshot: .init(
                    steps: 5_650, activeEnergy: 355, exercise: 24, distance: 4_100, flights: 6,
                    currentHR: 76, restingHR: 63, hrv: 44, respiratory: 14.2, oxygen: 97.8, wristTempDelta: 0.08,
                    sleepHours: 7.7, awakeHours: 0.38, coreHours: 4.0, deepHours: 1.55, remHours: 1.75,
                    unspecifiedSleepHours: 0.4, mindfulMinutes: 9, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [4200, 5100, 6100, 4800, 7200, 5600, 5650],
                    exercise: [16, 20, 26, 14, 38, 22, 24],
                    sleepHours: [6.6, 7.2, 7.8, 6.9, 8.1, 7.4, 7.7],
                    restingHR: [67, 66, 64, 68, 63, 65, 63],
                    hrv: [35, 38, 41, 34, 46, 42, 44],
                    sleepStages: [(6.6, 16, 18, 12), (7.2, 17, 19, 10), (7.8, 18, 20, 9), (6.9, 14, 18, 13), (8.1, 19, 21, 8), (7.4, 17, 20, 10), (7.7, 18, 21, 9)],
                    stateTrail: [.gray, .gray, .green, .yellow, .blue, .green, .green]
                ),
                intradayStateTrail: [.yellow, .gray, .green, .green, .blue, .green]
            )
        case .neutral:
            return DemoTemplate(
                targetState: .gray,
                snapshot: .init(
                    steps: 4_600, activeEnergy: 280, exercise: 16, distance: 3_700, flights: 4,
                    currentHR: 79, restingHR: 67, hrv: 39, respiratory: 14.9, oxygen: 97.2, wristTempDelta: 0.15,
                    sleepHours: 7.1, awakeHours: 0.55, coreHours: 4.2, deepHours: 1.25, remHours: 1.25,
                    unspecifiedSleepHours: 0.4, mindfulMinutes: 6, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [4300, 4700, 4900, 4600, 5100, 4500, 4600],
                    exercise: [14, 16, 18, 15, 17, 14, 16],
                    sleepHours: [7.0, 7.2, 7.1, 6.9, 7.3, 7.0, 7.1],
                    restingHR: [67, 68, 66, 67, 66, 67, 67],
                    hrv: [38, 40, 39, 37, 41, 39, 39],
                    sleepStages: [(7.0, 16, 19, 10), (7.2, 17, 18, 10), (7.1, 16, 18, 11), (6.9, 15, 18, 12), (7.3, 17, 19, 10), (7.0, 16, 18, 11), (7.1, 16, 19, 10)],
                    stateTrail: [.gray, .gray, .gray, .green, .gray, .gray, .gray]
                ),
                intradayStateTrail: [.gray, .gray, .green, .gray, .gray, .gray]
            )
        case .lowEnergy:
            return DemoTemplate(
                targetState: .yellow,
                snapshot: .init(
                    steps: 1_250, activeEnergy: 120, exercise: 4, distance: 1_400, flights: 1,
                    currentHR: 78, restingHR: 68, hrv: 37, respiratory: 14.8, oxygen: 97.4, wristTempDelta: 0.10,
                    sleepHours: 7.0, awakeHours: 0.52, coreHours: 4.0, deepHours: 1.35, remHours: 1.2,
                    unspecifiedSleepHours: 0.45, mindfulMinutes: 4, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [1900, 1500, 1200, 1700, 1400, 1300, 1250],
                    exercise: [7, 5, 4, 8, 6, 5, 4],
                    sleepHours: [7.2, 7.0, 6.9, 7.1, 7.0, 7.3, 7.0],
                    restingHR: [68, 69, 68, 67, 69, 68, 68],
                    hrv: [37, 36, 38, 37, 36, 38, 37],
                    sleepStages: [(7.2, 16, 18, 11), (7.0, 15, 18, 11), (6.9, 15, 17, 12), (7.1, 16, 18, 11), (7.0, 15, 18, 11), (7.3, 16, 18, 10), (7.0, 15, 17, 11)],
                    stateTrail: [.yellow, .yellow, .yellow, .gray, .yellow, .yellow, .yellow]
                ),
                intradayStateTrail: [.yellow, .yellow, .yellow, .yellow, .gray, .yellow]
            )
        case .stressed:
            return DemoTemplate(
                targetState: .purple,
                snapshot: .init(
                    steps: 2_100, activeEnergy: 170, exercise: 8, distance: 2_000, flights: 2,
                    currentHR: 103, restingHR: 82, hrv: 24, respiratory: 18.2, oxygen: 96.1, wristTempDelta: 0.42,
                    sleepHours: 6.0, awakeHours: 0.82, coreHours: 3.5, deepHours: 0.95, remHours: 1.05,
                    unspecifiedSleepHours: 0.5, mindfulMinutes: 1, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [3200, 2600, 2400, 2800, 2200, 2300, 2100],
                    exercise: [14, 11, 10, 9, 8, 7, 8],
                    sleepHours: [6.6, 6.3, 6.0, 6.2, 5.9, 6.1, 6.0],
                    restingHR: [76, 79, 81, 80, 82, 81, 82],
                    hrv: [31, 29, 27, 26, 25, 24, 24],
                    sleepStages: [(6.6, 14, 17, 13), (6.3, 13, 17, 14), (6.0, 12, 16, 16), (6.2, 13, 17, 14), (5.9, 11, 16, 17), (6.1, 12, 16, 16), (6.0, 12, 16, 16)],
                    stateTrail: [.gray, .purple, .purple, .purple, .purple, .purple, .purple]
                ),
                intradayStateTrail: [.gray, .purple, .purple, .purple, .purple, .purple]
            )
        case .drained:
            return DemoTemplate(
                targetState: .orange,
                snapshot: .init(
                    steps: 2_300, activeEnergy: 160, exercise: 7, distance: 2_100, flights: 2,
                    currentHR: 88, restingHR: 80, hrv: 22, respiratory: 16.7, oxygen: 96.3, wristTempDelta: 0.45,
                    sleepHours: 9.4, awakeHours: 1.15, coreHours: 6.0, deepHours: 0.85, remHours: 1.0,
                    unspecifiedSleepHours: 0.4, mindfulMinutes: 2, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [3100, 2800, 2500, 2200, 2600, 2400, 2300],
                    exercise: [12, 10, 9, 8, 8, 7, 7],
                    sleepHours: [8.8, 9.1, 9.3, 9.0, 9.5, 9.2, 9.4],
                    restingHR: [78, 79, 80, 81, 80, 80, 80],
                    hrv: [27, 25, 24, 23, 22, 22, 22],
                    sleepStages: [(8.8, 12, 16, 15), (9.1, 11, 15, 17), (9.3, 11, 15, 18), (9.0, 12, 16, 16), (9.5, 10, 14, 19), (9.2, 11, 15, 17), (9.4, 10, 14, 18)],
                    stateTrail: [.orange, .orange, .gray, .orange, .orange, .orange, .orange]
                ),
                intradayStateTrail: [.orange, .orange, .gray, .orange, .orange, .orange]
            )
        case .overloaded:
            return DemoTemplate(
                targetState: .red,
                snapshot: .init(
                    steps: 2_000, activeEnergy: 150, exercise: 6, distance: 1_900, flights: 1,
                    currentHR: 112, restingHR: 88, hrv: 20, respiratory: 19.2, oxygen: 93.7, wristTempDelta: 0.95,
                    sleepHours: 5.3, awakeHours: 1.3, coreHours: 3.1, deepHours: 0.7, remHours: 1.0,
                    unspecifiedSleepHours: 0.5, mindfulMinutes: 0, recentWorkoutMinutes: 0, minutesSinceRecentWorkout: nil
                ),
                week: .init(
                    steps: [2800, 2400, 2200, 2100, 2300, 2000, 2000],
                    exercise: [10, 8, 7, 7, 6, 6, 6],
                    sleepHours: [6.1, 5.9, 5.6, 5.4, 5.5, 5.2, 5.3],
                    restingHR: [82, 84, 86, 87, 88, 88, 88],
                    hrv: [27, 25, 23, 22, 21, 20, 20],
                    sleepStages: [(6.1, 12, 16, 15), (5.9, 11, 15, 16), (5.6, 10, 14, 18), (5.4, 9, 14, 19), (5.5, 9, 13, 20), (5.2, 8, 13, 21), (5.3, 8, 13, 21)],
                    stateTrail: [.purple, .purple, .red, .red, .red, .red, .red]
                ),
                intradayStateTrail: [.purple, .red, .red, .red, .red, .red]
            )
        }
    }

    private struct DemoTemplate {
        struct SnapshotTemplate {
            let steps: Double
            let activeEnergy: Double
            let exercise: Double
            let distance: Double
            let flights: Double
            let currentHR: Double
            let restingHR: Double
            let hrv: Double
            let respiratory: Double
            let oxygen: Double?
            let wristTempDelta: Double?
            let sleepHours: Double
            let awakeHours: Double
            let coreHours: Double
            let deepHours: Double
            let remHours: Double
            let unspecifiedSleepHours: Double
            let mindfulMinutes: Double
            let recentWorkoutMinutes: Double?
            let minutesSinceRecentWorkout: Double?
        }

        struct WeekTemplate {
            let steps: [Double]
            let exercise: [Double]
            let sleepHours: [Double]
            let restingHR: [Double]
            let hrv: [Double]
            let sleepStages: [(Double, Double, Double, Double)]
            let stateTrail: [ColorHealthState]
        }

        let targetState: ColorHealthState
        let snapshot: SnapshotTemplate
        let week: WeekTemplate
        let intradayStateTrail: [ColorHealthState]
    }

    func signalEntries(for snapshot: Snapshot?) -> [HealthSignalEntry] {
        let labels = [
            ("Sleep", snapshot?.sleepHours != nil || snapshot?.sleepStages != nil),
            ("Resting Heart Rate", snapshot?.restingHeartRate != nil),
            ("HRV", snapshot?.heartRateVariability != nil),
            ("Breathing", snapshot?.respiratoryRate != nil),
            ("Wrist Temperature", snapshot?.wristTemperatureCelsius != nil),
            ("Steps", snapshot?.stepCountToday != nil),
            ("Exercise", snapshot?.exerciseMinutesToday != nil),
            ("Mindful Minutes", snapshot?.mindfulMinutesToday != nil)
        ]

        return labels.map { label, hasData in
            let status: HealthSignalStatus
            switch authorizationState {
            case .notDetermined, .denied:
                status = .awaitingConnection
            case .unavailable:
                status = .noRecentData
            case .partial, .authorized:
                status = hasData ? .readable : .noRecentData
            }

            return HealthSignalEntry(label: label, status: status)
        }
    }

    nonisolated static func isNoDataError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == HKError.errorDomain
            && nsError.code == HKError.Code.errorNoData.rawValue
    }

    private func sensitivityDistance(_ lhs: SensitivityProfile, _ rhs: SensitivityProfile) -> Double {
        abs(lhs.stress - rhs.stress)
            + abs(lhs.movement - rhs.movement)
            + abs(lhs.recovery - rhs.recovery)
            + abs(lhs.overall - rhs.overall)
    }
}
