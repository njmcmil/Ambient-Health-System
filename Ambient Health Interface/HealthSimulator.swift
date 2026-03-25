import SwiftUI
import Combine

// This class acts as a temporary stand-in for real health data.
// lets us manually or randomly change states so we can test how the UI and now ref. react.
// will be depreciated once the healthkit connection is established next milestone..
final class HealthSimulator: ObservableObject {
    
    // The current "health state" driving the UI and ref. behavior.
    // private(set) ensures only this class can modify it directly.
    @Published private(set) var currentState: ColorHealthState = .red
    
    // Keeps a short history of recent states for simple visualization.
    @Published private(set) var history: [ColorHealthState] = [.gray, .green, .blue]

    // Updates the current state and tracks it in history.
    func setState(_ newState: ColorHealthState) {
        currentState = newState
        history.append(newState)
        
        // Limit history to avoid unbounded growth (UI stays clean).
        if history.count > 7 {
            history.removeFirst()
        }
    }

    // Randomly selects a state.
    // quickly testing how the ref. reacts to changes.
    func simulateRandomChange() {
        guard let newState = ColorHealthState.allCases.randomElement() else { return }
        setState(newState)
    }
}
