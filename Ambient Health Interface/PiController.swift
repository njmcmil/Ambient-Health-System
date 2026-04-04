import Foundation
import Combine

@MainActor
final class PiController: ObservableObject {
    static let shared = PiController()

    enum ConnectionStatus {
        case idle
        case sending
        case online
        case offline
    }

    private let baseURL: String
    @Published private(set) var connectionStatus: ConnectionStatus = .idle

    private init() {
        if let url = ProcessInfo.processInfo.environment["PI_BASE_URL"] {
            self.baseURL = url
        } else {
            self.baseURL = "http://127.0.0.1:8000" // fallback
        }
    }

    func sendHealthState(_ state: ColorHealthState, brightness: Int? = nil) {
        guard let url = URL(string: "\(baseURL)/set_light") else {
            print("Invalid baseURL:", baseURL)
            return
        }

        connectionStatus = .sending
        let resolvedBrightness = brightness ?? state.ambientBrightness

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "color": state.rawValue.lowercased(),
            "brightness": max(0, min(100, resolvedBrightness)) // safety clamp
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Failed to encode payload")
            return
        }

        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Failed to send to Pi:", error)
                Task { @MainActor in
                    self.connectionStatus = .offline
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Sent \(state.rawValue) @ \(resolvedBrightness)% — Status: \(httpResponse.statusCode)")
                Task { @MainActor in
                    self.connectionStatus = (200..<300).contains(httpResponse.statusCode) ? .online : .offline
                }
            }
        }.resume()
    }
}
