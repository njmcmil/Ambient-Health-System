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

    let healthStore = HKHealthStore()
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private var supplementalRefreshTask: Task<Void, Never>?
    private var refreshWatchdogTask: Task<Void, Never>?
    private var postAuthorizationRefreshTask: Task<Void, Never>?
    private var activeRefreshID = UUID()
    private var authorizationCooldownUntil: Date?

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
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }
        guard !isRefreshing else { return }

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
            signalEntries = signalEntries(for: loadedSnapshot)
            authorizationState = signalEntries.contains(where: { $0.status == .readable }) ? .authorized : .partial

            setState(classify(snapshot: loadedSnapshot, baseline: baselineSummary), shouldSendToPi: true)
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
        setState(classify(snapshot: latestSnapshot, baseline: baselineSummary), shouldSendToPi: shouldSendToPi)
    }

    func applySensitivityPreset(_ preset: SensitivityPreset) {
        let resolvedProfile = preset.profile
        sensitivityProfile = resolvedProfile
        sensitivityPreset = preset

        guard let latestSnapshot else { return }
        setState(classify(snapshot: latestSnapshot, baseline: baselineSummary), shouldSendToPi: true)
    }

    func setPreviewState(_ state: ColorHealthState?) {
        previewState = state

        if let state {
            PiController.shared.sendHealthState(state)
        } else {
            PiController.shared.sendHealthState(currentState)
        }
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
            setState(classify(snapshot: enrichedSnapshot, baseline: loadedBaseline), shouldSendToPi: true)
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

    func signalEntries(for snapshot: Snapshot?) -> [HealthSignalEntry] {
        let labels = [
            ("Sleep", snapshot?.sleepHours != nil || snapshot?.sleepStages != nil),
            ("Resting Heart Rate", snapshot?.restingHeartRate != nil),
            ("HRV", snapshot?.heartRateVariability != nil),
            ("Breathing", snapshot?.respiratoryRate != nil),
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
