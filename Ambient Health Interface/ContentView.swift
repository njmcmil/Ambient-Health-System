//
//  AmbientHealthObjectView.swift
//  Ambient Health Interface
//
//  Created by Nathan McMillan on 3/25/26.
//

import SwiftUI
import Combine

// MARK: - Ambient Color System (Mock Health States)
enum ColorHealthState: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case purple = "Purple"
    case gray = "Gray"
    case red = "Red"
    case orange = "Orange"

    var id: String { rawValue }

    // MARK: Visual representation of each state
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .purple: return .purple
        case .gray: return Color.gray.opacity(0.5)
        case .red: return .red
        case .orange: return .orange
        }
    }

    // MARK: Title for UI display
    var title: String {
        switch self {
        case .blue: return "Recovered"
        case .green: return "On Track"
        case .yellow: return "Needs Movement"
        case .purple: return "Stressed"
        case .gray: return "Steady"
        case .red: return "Warning"
        case .orange: return "Fatigue Building"
        }
    }

    // MARK: Message / Explanation for UI
    var message: String {
        switch self {
        case .blue:
            return "You seem well-rested and your body is recovering normally."
        case .green:
            return "Your activity looks healthy and consistent right now."
        case .yellow:
            return "You have been still for a while. A short walk might help."
        case .purple:
            return "Your body may be under stress. This could be a good time to slow down."
        case .gray:
            return "Nothing unusual stands out right now. You look stable."
        case .red:
            return "Something looks off. Pay attention to how you feel and consider checking in."
        case .orange:
            return "Fatigue may be building. Rest and hydration could help."
        }
    }
}

// MARK: - *Simple* Simulated Health Data Layer
final class HealthSimulator: ObservableObject {
    // Current health state (mock)
    @Published private(set) var currentState: ColorHealthState = .red
    
    // History of last states (mock)
    @Published private(set) var history: [ColorHealthState] = [.gray, .green, .blue]

    // MARK: Methods to update state
    func setState(_ newState: ColorHealthState) {
        currentState = newState
        history.append(newState)

        if history.count > 7 { //ex. keep only the last 7 for history display
            history.removeFirst()
        }
    }

    // Simulate random state changes for testing
    func simulateRandomChange() {
        guard let newState = ColorHealthState.allCases.randomElement() else { return }
        setState(newState)
    }
}

// MARK: - Front-End Prototype View
struct AmbientHealthObjectView: View {
    @StateObject private var simulator = HealthSimulator()

    var body: some View {
        VStack(spacing: 28) {
            
            // MARK: Ambient Object - Lamp ("art")
            RoundedRectangle(cornerRadius: 28)
                .fill(simulator.currentState.color.gradient)
                .frame(width: 220, height: 220)
                .shadow(color: simulator.currentState.color.opacity(0.35), radius: 24)
                .overlay {
                    VStack(spacing: 8) {
                        Text(simulator.currentState.rawValue)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))

                        Text(simulator.currentState.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: simulator.currentState)

            // MARK: Current Status / Explanation
            VStack(spacing: 8) {
                Text("Current Status")
                    .font(.headline)

                Text(simulator.currentState.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            // MARK: Minimal History View (Mock)
            VStack(spacing: 10) {
                Text("Recent states")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Array(simulator.history.enumerated()), id: \.offset) { _, state in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(state.color)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            
            // MARK : Controls for Testing / Mock Interaction
            VStack(spacing: 12) {
                Text("Try a different state")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(ColorHealthState.allCases) { state in
                        Button(state.rawValue) {
                            simulator.setState(state)
                        }
                    }
                } label: {
                    Label("Choose Health State", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button("Simulate Random Change") {
                    simulator.simulateRandomChange()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.96))
        )
        .padding()
    }
}

// MARK: - Preview
#Preview {
    AmbientHealthObjectView()
}
