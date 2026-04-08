import SwiftUI

/// Paints the soft full-screen aura behind the Now experience.
struct AmbientBackgroundView: View {
    let state: ColorHealthState
    let reduceIntensity: Bool

    private var auraFactor: Double { reduceIntensity ? 0.62 : 1.0 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground).opacity(0.99),
                    state.color.opacity(0.018 * auraFactor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(state.color.opacity(0.06 * auraFactor))
                .frame(width: 310, height: 310)
                .blur(radius: reduceIntensity ? 54 : 64)
                .offset(x: -18, y: -156)

            Circle()
                .fill(Color.white.opacity(reduceIntensity ? 0.020 : 0.035))
                .frame(width: 190, height: 190)
                .blur(radius: reduceIntensity ? 34 : 42)
                .offset(x: 90, y: -186)

            Ellipse()
                .fill(state.color.opacity(0.028 * auraFactor))
                .frame(width: 360, height: 190)
                .blur(radius: reduceIntensity ? 62 : 76)
                .offset(x: 60, y: 292)
        }
    }
}

/// The primary screen of the app, designed to feel calm and legible at a glance.
struct AmbientNowView: View {
    @ObservedObject var healthStore: AmbientHealthStore
    let reduceIntensity: Bool

    private var isPreviewing: Bool {
        healthStore.previewState != nil
    }

    var body: some View {
        VStack(spacing: isPreviewing ? 8 : 12) {
            Spacer(minLength: 0)

            AmbientNowCalendarCard(healthStore: healthStore)
            Spacer(minLength: isPreviewing ? 4 : 10)
            AmbientReferenceView(
                state: healthStore.displayedState,
                reduceIntensity: reduceIntensity
            )
            .padding(.top, isPreviewing ? 2 : 8)

            VStack(spacing: 8) {
                Text(healthStore.displayedState.title)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .tracking(0.2)
                    .foregroundStyle(.primary)

                if healthStore.previewState != nil {
                    Text("Preview Mode")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(healthStore.displayedState.color.opacity(0.9))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(healthStore.displayedState.color.opacity(0.12), in: Capsule())
                }

                Text(nowLine(for: healthStore.displayedState))
                    .font(.callout)
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 270)
                    .padding(.horizontal, 24)
            }
            .padding(.top, isPreviewing ? 8 : 14)

            AmbientActionButtons(healthStore: healthStore)

            Spacer()
        }
        .offset(y: isPreviewing ? 8 : 0)
        .safeAreaPadding(.top, 10)
    }
}

private struct AmbientActionButtons: View {
    @ObservedObject var healthStore: AmbientHealthStore

    var body: some View {
        HStack(spacing: 10) {
            if healthStore.authorizationState == .unavailable {
                Text("HealthKit needs a physical iPhone")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.thinMaterial, in: Capsule())
            } else if healthStore.canRequestAuthorization {
                Button {
                    Task { await healthStore.requestAuthorization() }
                } label: {
                    Label("Connect Health", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(healthStore.displayedState.color)
            } else if healthStore.isRefreshing {
                Text("Refreshing Apple Health...")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.thinMaterial, in: Capsule())
            }

            if healthStore.previewState != nil {
                Button {
                    healthStore.setPreviewState(nil)
                } label: {
                    Label("Live State", systemImage: "wave.3.right.circle")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
