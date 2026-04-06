import Foundation
import Combine

@MainActor
/// Manages communication with the ambient hardware bridge and exposes a small,
/// UI-friendly connection state for the Now screen.
final class PiController: ObservableObject {
    static let shared = PiController()
    struct SendLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let state: ColorHealthState
        let brightness: Int
        let statusCode: Int?
        let latencyMs: Int?
        let message: String
    }

    /// Mirrors the health of the last known connection attempt in a way that
    /// the UI can translate into a simple status indicator.
    enum ConnectionStatus {
        case idle
        case checking
        case online
        case offline
    }

    private let baseURL: String
    @Published private(set) var connectionStatus: ConnectionStatus = .idle
    @Published private(set) var sendLogs: [SendLogEntry] = []
    @Published private(set) var brightnessOverrides: [ColorHealthState: Int] = [:]
    private var monitorTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var debouncedSendTask: Task<Void, Never>?

    private init() {
        if let url = ProcessInfo.processInfo.environment["PI_BASE_URL"] {
            self.baseURL = url
        } else {
            self.baseURL = "http://127.0.0.1:8000" // fallback
        }
        self.brightnessOverrides = Self.loadBrightnessOverrides()
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
        guard let url = URL(string: "\(baseURL)/set_light") else {
            connectionStatus = .offline
            return
        }

        connectionStatus = .checking

        var request = URLRequest(url: url)
        // Probe the actual bridge route without attempting to change the light.
        request.httpMethod = "OPTIONS"
        request.timeoutInterval = 4

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard response is HTTPURLResponse else {
                connectionStatus = .offline
                return
            }
            // A real HTTP response means the bridge route is reachable, even if
            // that particular method is not supported.
            connectionStatus = .online
        } catch {
            connectionStatus = .offline
        }
    }

    func sendHealthState(_ state: ColorHealthState, brightness: Int? = nil) {
        retryTask?.cancel()
        sendHealthState(state, brightness: brightness, retryingAfterServerFailure: false)
    }

    /// Debounced send used by high-frequency controls (like sliders) so the bridge
    /// receives a settled value instead of every intermediate drag position.
    func sendHealthStateDebounced(
        _ state: ColorHealthState,
        brightness: Int? = nil,
        delayMs: Int = 320
    ) {
        debouncedSendTask?.cancel()
        debouncedSendTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(max(delayMs, 0)) * 1_000_000)
            guard !Task.isCancelled else { return }
            self.sendHealthState(state, brightness: brightness)
        }
    }

    private func sendHealthState(
        _ state: ColorHealthState,
        brightness: Int?,
        retryingAfterServerFailure: Bool
    ) {
        guard let url = URL(string: "\(baseURL)/set_light") else {
            print("Invalid baseURL:", baseURL)
            return
        }

        let resolvedBrightness = brightness ?? brightnessForState(state)
        connectionStatus = .checking
        let startedAt = Date()

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
            let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            if let error = error {
                print("Failed to send to Pi:", error)
                Task { @MainActor in
                    self.connectionStatus = .offline
                    self.recordSendLog(
                        state: state,
                        brightness: resolvedBrightness,
                        statusCode: nil,
                        latencyMs: latencyMs,
                        message: "Request failed: \(error.localizedDescription)"
                    )
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                let code = httpResponse.statusCode
                print("Sent \(state.rawValue) @ \(resolvedBrightness)% — Status: \(code)")
                Task { @MainActor in
                    self.connectionStatus = (200..<300).contains(code) ? .online : .offline
                    self.recordSendLog(
                        state: state,
                        brightness: resolvedBrightness,
                        statusCode: code,
                        latencyMs: latencyMs,
                        message: (200..<300).contains(code) ? "Sent successfully" : "Bridge returned status \(code)"
                    )
                }

                if (500...599).contains(code), !retryingAfterServerFailure {
                    self.retryTask?.cancel()
                    self.retryTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        guard !Task.isCancelled else { return }
                        self.sendHealthState(
                            state,
                            brightness: resolvedBrightness,
                            retryingAfterServerFailure: true
                        )
                    }
                }
            }
        }.resume()
    }

    private func recordSendLog(
        state: ColorHealthState,
        brightness: Int,
        statusCode: Int?,
        latencyMs: Int?,
        message: String
    ) {
        let entry = SendLogEntry(
            timestamp: Date(),
            state: state,
            brightness: brightness,
            statusCode: statusCode,
            latencyMs: latencyMs,
            message: message
        )
        sendLogs.append(entry)
        if sendLogs.count > 30 {
            sendLogs.removeFirst(sendLogs.count - 30)
        }
    }

    func brightnessForState(_ state: ColorHealthState) -> Int {
        brightnessOverrides[state] ?? state.ambientBrightness
    }

    func setBrightness(_ value: Int, for state: ColorHealthState) {
        let clamped = max(0, min(100, value))
        brightnessOverrides[state] = clamped
        persistBrightnessOverrides()
    }

    func resetBrightnessOverrides() {
        brightnessOverrides = [:]
        persistBrightnessOverrides()
    }

    private static func overrideKey(for state: ColorHealthState) -> String {
        "ambient.brightness.override.\(state.rawValue.lowercased())"
    }

    private static func loadBrightnessOverrides() -> [ColorHealthState: Int] {
        let defaults = UserDefaults.standard
        var loaded: [ColorHealthState: Int] = [:]
        for state in ColorHealthState.allCases {
            let key = overrideKey(for: state)
            if defaults.object(forKey: key) != nil {
                loaded[state] = max(0, min(100, defaults.integer(forKey: key)))
            }
        }
        return loaded
    }

    private func persistBrightnessOverrides() {
        let defaults = UserDefaults.standard
        for state in ColorHealthState.allCases {
            let key = Self.overrideKey(for: state)
            if let value = brightnessOverrides[state] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
