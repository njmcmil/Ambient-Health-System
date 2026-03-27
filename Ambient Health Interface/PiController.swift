import Foundation
import SwiftUI

class PiController {
    static let shared = PiController()
    private let baseURL = "http://192.168.1.95:8000"
    // Pi's IP + port

    private init() {}

    func sendHealthState(_ state: ColorHealthState) {
        guard let url = URL(string: "\(baseURL)/set_color") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["color": state.rawValue.lowercased()]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to send to Pi:", error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Sent \(state.rawValue) to Pi — Status: \(httpResponse.statusCode)")
            }
        }.resume()
    }
}
