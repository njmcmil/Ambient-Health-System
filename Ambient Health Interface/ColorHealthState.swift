import SwiftUI

// Represents simplified health states using color as the primary signal.
// Each state maps to:
// - a visual color (for the ref.)
// - a short label (UI)
// - a message (feedback)
enum ColorHealthState: String, CaseIterable, Identifiable {

    // Each case represents a different physiological pattern or condition.
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case purple = "Purple"
    case gray = "Gray"
    case red = "Red"
    case orange = "Orange"

    var id: String { rawValue }

    // Visual identity of each state.
    // Tuned colors for a softer & more ambient feel.
    var color: Color {
        switch self {
        case .blue: return Color(red: 0.35, green: 0.66, blue: 1.0)     // calm / recovery
        case .green: return Color(red: 0.28, green: 0.83, blue: 0.56)   // healthy / balanced
        case .yellow: return Color(red: 1.0, green: 0.80, blue: 0.30)   // low movement warning
        case .purple: return Color(red: 0.67, green: 0.48, blue: 1.0)   // stress signal
        case .gray: return Color.gray.opacity(0.65)                     // neutral baseline
        case .red: return Color(red: 1.0, green: 0.36, blue: 0.36)      // alert / strain
        case .orange: return Color(red: 1.0, green: 0.58, blue: 0.24)   // fatigue building
        }
    }

    // Short label
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

    // Slightly longer explanation for the user.
    // meant to not be overwhelming.
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
            return "Something looks off. Pay attention to how you feel."
        case .orange:
            return "Fatigue may be building. Rest and hydration could help."
        }
    }
}
