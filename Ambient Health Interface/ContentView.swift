import SwiftUI

struct AmbientHealthObjectView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var healthStore = AmbientHealthStore()
    @State private var selectedTab: AmbientTab = .now
    @State private var sensitivityApplyTask: Task<Void, Never>?

    @State private var stressSensitivity: Double = AmbientHealthStore.SensitivityProfile.default.stress
    @State private var movementSensitivity: Double = AmbientHealthStore.SensitivityProfile.default.movement
    @State private var recoverySensitivity: Double = AmbientHealthStore.SensitivityProfile.default.recovery
    @State private var overallResponsiveness: Double = AmbientHealthStore.SensitivityProfile.default.overall

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: healthStore.currentState)

            // Keep the shell small here and push feature-specific UI into dedicated files.
            Group {
                switch selectedTab {
                case .now:
                    AmbientNowView(healthStore: healthStore)
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
                        resetToDefault: resetSensitivityToDefault
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .safeAreaInset(edge: .bottom) {
            AmbientBottomBar(selectedTab: $selectedTab)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .onAppear(perform: applySensitivityProfile)
        .onChange(of: stressSensitivity) { scheduleSensitivityApply() }
        .onChange(of: movementSensitivity) { scheduleSensitivityApply() }
        .onChange(of: recoverySensitivity) { scheduleSensitivityApply() }
        .onChange(of: overallResponsiveness) { scheduleSensitivityApply() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                await healthStore.refreshIfNeeded()
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
            // Let slider drags settle before we reclassify and push a new light state.
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            applySensitivityProfile()
        }
    }
}

#Preview {
    AmbientHealthObjectView()
}
