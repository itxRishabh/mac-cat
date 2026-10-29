import Foundation

/// Streaming client for the Anthropic Messages API.
@MainActor
final class AIEngine: ObservableObject {

    @Published var lastError: String? = nil

    private var task: URLSessionDataTask?
    private var buffer = ""
    private var onPartial: @MainActor (String) -> Void = { _ in }
    private var onFinish: @MainActor (Result<String, Error>) -> Void = { _ in }

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Stream a completion. `onPartial` receives the accumulating full text.
    func stream(messages: [[String: String]],
                system: String,
                memories: [String],
                reminders: [String],
                onPartial: @escaping @MainActor (String) -> Void,
                result: @escaping @MainActor (Result<String, Error>) -> Void) {
        self.onPartial = onPartial
        self.onFinish = result
        buffer = ""

        guard let key = KeychainHelper.read(), !key.isEmpty else {
            result(.failure(APIError(message: "No API key set. Add one in Settings.")))
            return
        }

        var sys = system
        if !memories.isEmpty {
            sys += "\n\nThings you remember:\n" + memories.map { "- \($0)" }.joined(separator: "\n")
        }
        if !reminders.isEmpty {
            sys += "\n\nYour reminders:\n" + reminders.map { "- \($0)" }.joined(separator: "\n")
        }

        var payload: [String: Any] = [
            "model": ModelCatalog.current,
            "max_tokens": 1024,
            "stream": true,
            "system": sys,
            "messages": messages.map { m in
                ["role": m["role"] ?? "user", "content": m["content"] ?? ""]
            }
        ]
        // Tools let the pet create reminders and remember facts on its own.
        payload["tools"] = ToolSchemas.tools
        payload["tool_choice"] = ["type": "auto"]

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            result(.failure(APIError(message: "Could not encode request.")))
            return
        }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("application/json", forHTTPHeaderField: "accept")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.httpBody = data

        let session = URLSession.shared
        task = session.dataTask(with: req) { [weak self] data, response, error in
            if let error {
                Task { @MainActor in self?.finish(.failure(error)) }
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                Task { @MainActor in
                    self?.finish(.failure(APIError(message: "HTTP \(http.statusCode): \(body.prefix(400))")))
                }
                return
            }
            guard let data else {
                Task { @MainActor in self?.finish(.failure(APIError(message: "Empty response."))) }
                return
            }
            // Non-streaming fallback: parse whole body.
            Task { @MainActor in
                self?.handleSSE(data)
            }
        }
        task?.resume()
    }

    private func handleSSE(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            finish(.failure(APIError(message: "Unreadable response.")))
            return
        }
        var full = ""
        for line in text.split(separator: "\n") {
            let l = String(line)
            guard l.hasPrefix("data:") else { continue }
            let payload = l.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { continue }
            guard let d = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }

            if let delta = obj["delta"] as? [String: Any],
               let partial = delta["text"] as? String {
                full += partial
                onPartial(full)
            }
            if let type = obj["type"] as? String, type == "message_stop" {
                // fall through, finalised below
            }
        }
        if full.isEmpty {
            finish(.failure(APIError(message: "No text in response.")))
        } else {
            finish(.success(full))
        }
    }

    private func finish(_ r: Result<String, Error>) {
        if case .failure(let e) = r { lastError = e.localizedDescription }
        onFinish(r)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

enum ModelCatalog {
    static let current = "claude-sonnet-5-5"
    static let options = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
}

enum ToolSchemas {
    static let tools: [[String: Any]] = [
        [
            "name": "remember",
            "description": "Store a durable fact about the user so you remember it later.",
            "input_schema": [
                "type": "object",
                "properties": ["fact": ["type": "string"]],
                "required": ["fact"]
            ]
        ],
        [
            "name": "set_reminder",
            "description": "Create a reminder for the user.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "minutes_from_now": ["type": "number"]
                ],
                "required": ["title", "minutes_from_now"]
            ]
        ]
    ]
}

// MARK: - Keychain

import Security

enum KeychainHelper {
    private static let service = "com.pccat.apikey"

    static func save(_ value: String) {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apikey"
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apikey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func delete() {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apikey"
        ]
        SecItemDelete(base as CFDictionary)
    }
}
