import Foundation
import HealthKit

/// App-facing data structures used by `AmbientHealthStore`.
///
/// Keeping these nested types together makes it easier to understand what the rest of the app
/// can rely on without digging through HealthKit query code or classification logic.
extension AmbientHealthStore {
    struct SensitivityProfile {
        var stress: Double = 0.65
        var movement: Double = 0.55
        var recovery: Double = 0.60
        var overall: Double = 0.60
        
        private func clamped(_ value: Double) -> Double {
                min(max(value, 0.0), 1.2)
            }

        var normalizedStress: Double { clamped(stress) }
        var normalizedMovement: Double { clamped(movement) }
        var normalizedRecovery: Double { clamped(recovery) }
        var normalizedOverall: Double { clamped(overall) }
        
        
        var adjustedStress: Double {
            normalizedStress * normalizedOverall
        }

        var adjustedMovement: Double {
            normalizedMovement * normalizedOverall
        }

        var adjustedRecovery: Double {
            normalizedRecovery * normalizedOverall
        }

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
                return .init(stress: 0.35, movement: 0.25, recovery: 0.40, overall: 0.30)
            case .recommended:
                return .default
            case .responsive:
                return .init(stress: 1.0, movement: 0.85, recovery: 0.95, overall: 0.90)
            case .custom:
                return SensitivityProfile()
            }
        }
    }

    /// Developer-only demo data scenarios used by Demo Mode.
    enum DemoDataset: String, CaseIterable, Identifiable {
        case restored = "Restored"
        case grounded = "Grounded"
        case neutral = "Neutral"
        case lowEnergy = "Low Energy"
        case stressed = "Stressed"
        case drained = "Drained"
        case overloaded = "Overloaded"

        var id: String { rawValue }
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

    /// One metric's recent "normal" plus how much it naturally varies.
    struct MetricBaseline {
        let mean: Double
        let standardDeviation: Double
        let sampleCount: Int

        var isReliable: Bool {
            sampleCount >= 5
        }
    }

    /// Multi-week personal reference data used to interpret today's live readings.
    struct BaselineSummary {
        let windowDays: Int
        let restingHeartRate: MetricBaseline?
        let heartRateVariability: MetricBaseline?
        let respiratoryRate: MetricBaseline?
        let sleepHours: MetricBaseline?
        let deepSleepPercent: MetricBaseline?
        let remSleepPercent: MetricBaseline?
        let awakePercent: MetricBaseline?
        let stepCount: MetricBaseline?
        let exerciseMinutes: MetricBaseline?
    }

    /// Bundles the week-level series that feed the Now, Trends, and Explanation views.
    struct TrendReport {
        let steps: [TrendPoint]
        let exerciseMinutes: [TrendPoint]
        let sleepHours: [TrendPoint]
        let restingHeartRate: [TrendPoint]
        let heartRateVariability: [TrendPoint]
        let respiratoryRate: [TrendPoint]
        let oxygenSaturationPercent: [TrendPoint]
        let wristTemperatureCelsius: [TrendPoint]
        let sleepStages: [SleepStageTrendPoint]
        let calendarSteps: [TrendPoint]
        let calendarExerciseMinutes: [TrendPoint]
        let calendarSleepHours: [TrendPoint]
        let calendarRestingHeartRate: [TrendPoint]
        let calendarHeartRateVariability: [TrendPoint]
        let calendarRespiratoryRate: [TrendPoint]
        let calendarOxygenSaturationPercent: [TrendPoint]
        let calendarWristTemperatureCelsius: [TrendPoint]
        let calendarSleepStages: [SleepStageTrendPoint]
        let latestSleepStage: SleepStageTrendPoint?
        let intradayStateTrail: [StateTrendPoint]
        let stateTrail: [StateTrendPoint]
        let calendarStateTrail: [StateTrendPoint]
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
            let total = coreHours + deepHours + remHours + unspecifiedSleepHours
            guard total > 0 else { return 0 }
            return (deepHours / total) * 100
        }

        var remPercent: Double {
            let total = coreHours + deepHours + remHours + unspecifiedSleepHours
            guard total > 0 else { return 0 }
            return (remHours / total) * 100
        }

        var awakePercent: Double {
            let total = coreHours + deepHours + remHours + unspecifiedSleepHours + awakeHours
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
                return "Allow read access to movement, cardio, sleep, respiratory, and mindfulness signals to drive the ambient state."
            case .denied:
                return "Try reconnecting Health access, then refresh to pull live readings again."
            case .partial:
                return "HealthKit is reachable, but some of the ambient signals do not have recent readable samples yet."
            case .authorized:
                return "Apple Health is connected and ready for refresh."
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

    /// A normalized current-health picture used by the classifier and explanation layer.
    ///
    /// This intentionally blends daily totals, latest spot readings, and overnight recovery data
    /// so the rest of the app can reason about one consistent model instead of raw HealthKit samples.
    struct Snapshot {
        let recentWorkoutMinutes: Double?
        let minutesSinceRecentWorkout: Double?
        let stepCountToday: Double?
        let activeEnergyToday: Double?
        let exerciseMinutesToday: Double?
        let walkingRunningDistanceToday: Double?
        let flightsClimbedToday: Double?
        let currentHeartRate: Double?
        let restingHeartRate: Double?
        let heartRateVariability: Double?
        let respiratoryRate: Double?
        let oxygenSaturationPercent: Double?
        let wristTemperatureCelsius: Double?
        let sleepHours: Double?
        let sleepStages: SleepStageBreakdown?
        let mindfulMinutesToday: Double?
        let sampledAt: Date
        
        var heartRateDelta: Double? {
            guard let current = currentHeartRate,
                  let resting = restingHeartRate else { return nil }
            return current - resting
        }
        
        var isElevatedHeartRate: Bool {
            (heartRateDelta ?? 0) > 15
        }
    }

    /// A grouped overnight session reconstructed from raw HealthKit sleep stage samples.
    ///
    /// HealthKit stores sleep as stage slices, not one clean "last night" object. This cluster lets
    /// the app reason about the latest completed session instead of guessing from a blunt time window.
    struct SleepSessionCluster {
        let startDate: Date
        let endDate: Date
        let breakdown: SleepStageBreakdown
    }

    struct RecentWorkoutContext {
        let durationMinutes: Double
        let minutesSinceEnd: Double
    }

    /// Developer-facing classifier introspection payload.
    /// Used by the debug panel in Settings to explain exactly why the state was chosen.
    struct ClassificationDebugReport {
        struct Section: Identifiable {
            let id = UUID()
            let title: String
            let lines: [String]
        }

        let selectedState: ColorHealthState
        let generatedAt: Date
        let confidenceSummary: String
        let sections: [Section]
    }
}
