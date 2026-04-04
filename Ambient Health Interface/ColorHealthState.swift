import SwiftUI

enum ColorHealthState: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case purple = "Purple"
    case gray = "Gray"
    case red = "Red"
    case orange = "Orange"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.49, green: 0.72, blue: 0.96)    // restored / airy blue
        case .green: return Color(red: 0.49, green: 0.72, blue: 0.62)   // grounded / muted sage
        case .yellow: return Color(red: 0.91, green: 0.73, blue: 0.42)  // low energy / soft amber
        case .purple: return Color(red: 0.73, green: 0.56, blue: 0.88)  // stressed / muted orchid
        case .gray: return Color(red: 0.70, green: 0.77, blue: 0.84)    // even / soft silver-blue
        case .red: return Color(red: 0.92, green: 0.42, blue: 0.44)     // overloaded / warm coral-red
        case .orange: return Color(red: 0.97, green: 0.62, blue: 0.20)  // drained / clearer orange
        }
    }

    var title: String {
        switch self {
        case .blue: return "Restored"
        case .green: return "Grounded"
        case .yellow: return "Low Energy"
        case .purple: return "Stressed"
        case .gray: return "Neutral"
        case .red: return "Overloaded"
        case .orange: return "Drained"
        }
    }

    var message: String {
        switch self {
        case .blue:
            return "Your recent pattern suggests you feel more restored than usual."
        case .green:
            return "Your recent health signals look balanced, steady, and supported."
        case .yellow:
            return "Your recent pattern looks lower-energy than your usual rhythm."
        case .purple:
            return "Several signals suggest a more stressed state than your baseline."
        case .gray:
            return "Nothing strongly unusual stands out right now. Your recent pattern looks more neutral."
        case .red:
            return "Multiple signals are stacked higher than usual. This can feel overloaded or overwhelmed."
        case .orange:
            return "Recovery may be trailing behind your recent load, which can feel draining."
        }
    }
}
