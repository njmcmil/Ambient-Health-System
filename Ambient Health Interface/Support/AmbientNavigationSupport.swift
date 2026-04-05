import SwiftUI

/// Shared navigation metadata and short now-screen copy.
/// These small pieces are used across multiple surfaces, so keeping them
/// together avoids repeating simple app vocabulary in view files.
enum AmbientTab: String, CaseIterable, Identifiable {
    case now = "Now"
    case explanation = "Explanation"
    case trends = "Trends"
    case settings = "Settings"

    var id: String { rawValue }
}

func tabSymbolName(for tab: AmbientTab) -> String {
    switch tab {
    case .now:
        return "circle.hexagongrid.fill"
    case .trends:
        return "waveform.path.ecg"
    case .explanation:
        return "sparkles.rectangle.stack"
    case .settings:
        return "slider.horizontal.3"
    }
}

func nowLine(for state: ColorHealthState) -> String {
    switch state {
    case .blue: return "Your recent pattern feels more restored."
    case .green: return "Your recent pattern looks grounded and steady."
    case .yellow: return "Your recent pattern suggests lower energy and movement."
    case .purple: return "Your current pattern suggests more stress than usual."
    case .gray: return "Your current pattern looks neutral and steady."
    case .red: return "Several strain-related signals are elevated together."
    case .orange: return "Your recent pattern suggests emotional and physical drain."
    }
}
