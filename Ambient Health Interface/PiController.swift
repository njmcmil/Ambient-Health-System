import Foundation
import Combine

@MainActor
final class PiController: ObservableObject {
    static let shared = PiController()

    enum ConnectionStatus {
        case idle
        case checking
        case online
        case offline
    }

    private let baseURL: String
    @Published private(set) var connectionStatus: ConnectionStatus = .idle
    private var monitorTask: Task<Void, Never>?

    private init() {
        if let url = ProcessInfo.processInfo.environment["PI_BASE_URL"] {
            self.baseURL = url
        } else {
            self.baseURL = "http://127.0.0.1:8000" // fallback
        }
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task {
            while !Task.isCancelled {
                await refreshConnectionStatus()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    func refreshConnectionStatus() async {
        guard let url = URL(string: baseURL) else {
            connectionStatus = .offline
            return
        }

        connectionStatus = .checking

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if response is HTTPURLResponse {
                connectionStatus = .online
            } else {
                connectionStatus = .offline
            }
        } catch {
            connectionStatus = .offline
        }
    }

    func sendHealthState(_ state: ColorHealthState, brightness: Int? = nil) {
        guard let url = URL(string: "\(baseURL)/set_light") else {
            print("Invalid baseURL:", baseURL)
            return
        }

        let resolvedBrightness = brightness ?? state.ambientBrightness
        connectionStatus = .checking

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
