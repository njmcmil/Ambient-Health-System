import Foundation

class PiController {
    static let shared = PiController()

    private let baseURL: String

    private init() {
        if let url = ProcessInfo.processInfo.environment["PI_BASE_URL"] {
            self.baseURL = url
        } else {
            self.baseURL = "http://127.0.0.1:8000" // fallback
        }
    }

    func sendHealthState(_ state: ColorHealthState, brightness: Int = 70) {
        guard let url = URL(string: "\(baseURL)/set_light") else {
            print("Invalid baseURL:", baseURL)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "color": state.rawValue.lowercased(),
            "brightness": max(0, min(100, brightness)) // safety clamp
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Failed to encode payload")
            return
        }

        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Failed to send to Pi:", error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Sent \(state.rawValue) @ \(brightness)% — Status: \(httpResponse.statusCode)")
            }
        }.resume()
    }
}
