import SwiftUI

/// Hosts the app's top-level ambient experience and keeps shared state
/// flowing between the current mood view, explanation screens, trends,
/// settings, and the ambient object connection layer.
struct AmbientHealthObjectView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var healthStore = AmbientHealthStore()
    @StateObject private var piController = PiController.shared
    @AppStorage("anxietyCalmerMode") private var calmerModeEnabled = false
    @AppStorage("accessibilityReduceMotion") private var reduceMotionEnabled = false
    @AppStorage("accessibilityLargerText") private var largerTextEnabled = false
    @AppStorage("accessibilityHigherContrast") private var higherContrastEnabled = false
    @State private var selectedTab: AmbientTab = .now
    @State private var sensitivityApplyTask: Task<Void, Never>?

    @State private var stressSensitivity: Double = AmbientHealthStore.SensitivityProfile.default.stress
    @State private var movementSensitivity: Double = AmbientHealthStore.SensitivityProfile.default.movement
    @State private var recoverySensitivity: Double = AmbientHealthStore.SensitivityProfile.default.recovery
    @State private var overallResponsiveness: Double = AmbientHealthStore.SensitivityProfile.default.overall

    var body: some View {
        ZStack {
            AmbientBackgroundView(
                state: healthStore.displayedState,
                reduceIntensity: calmerModeEnabled || reduceMotionEnabled
            )

            Group {
                switch selectedTab {
                case .now:
                    AmbientNowView(
                        healthStore: healthStore,
                        reduceIntensity: calmerModeEnabled || reduceMotionEnabled
                    )
                case .trends:
                    AmbientTrendsView(healthStore: healthStore)
                case .explanation:
                    AmbientExplanationView(healthStore: healthStore)
                case .settings:
                    AmbientSettingsView(
                        healthStore: healthStore,
                        stressSensitivity: $stressSensitivity,
                        movementSensitivity: $movementSensitivity,
                        recoverySensitivity: $recoverySensitivity,
                        overallResponsiveness: $overallResponsiveness,
                        calmerModeEnabled: $calmerModeEnabled,
                        reduceMotionEnabled: $reduceMotionEnabled,
                        largerTextEnabled: $largerTextEnabled,
                        higherContrastEnabled: $higherContrastEnabled,
                        resetToDefault: resetSensitivityToDefault
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .modifier(AmbientLargerTextModifier(isEnabled: largerTextEnabled))
            .contrast(higherContrastEnabled ? 1.12 : 1.0)
            .transaction { transaction in
                if reduceMotionEnabled {
                    transaction.animation = nil
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            AmbientBottomBar(selectedTab: $selectedTab)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, selectedTab == .now && healthStore.previewState != nil ? 16 : 10)
        }
        .onAppear {
            applySensitivityProfile()
            piController.startMonitoring()
        }
        .onChange(of: stressSensitivity) {
            scheduleSensitivityApply()
        }
        .onChange(of: movementSensitivity) {
            scheduleSensitivityApply()
        }
        .onChange(of: recoverySensitivity) {
            scheduleSensitivityApply()
        }
        .onChange(of: overallResponsiveness) {
            scheduleSensitivityApply()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await healthStore.refreshIfNeeded()
                await piController.refreshConnectionStatus()
            }
        }
    }

    private func resetSensitivityToDefault() {
        let profile = AmbientHealthStore.SensitivityProfile.default
        stressSensitivity = profile.stress
        movementSensitivity = profile.movement
        recoverySensitivity = profile.recovery
        overallResponsiveness = profile.overall
    }

    private func applySensitivityProfile() {
        healthStore.updateSensitivityProfile(
            .init(
                stress: stressSensitivity,
                movement: movementSensitivity,
                recovery: recoverySensitivity,
                overall: overallResponsiveness
            ),
            shouldSendToPi: true
        )
    }

    private func scheduleSensitivityApply() {
        sensitivityApplyTask?.cancel()
        sensitivityApplyTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            applySensitivityProfile()
        }
    }
}

private struct AmbientLargerTextModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.dynamicTypeSize(.xLarge)
        } else {
            content
        }
    }
}
