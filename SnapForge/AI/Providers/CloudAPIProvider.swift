import Foundation
import CoreGraphics
import Security

// MARK: - CloudAPIProvider

actor CloudAPIProvider: @preconcurrency InferenceProvider {

    // MARK: - Constants

    private static let openAIBaseURL = URL(string: "https://api.openai.com/v1")!
    private static let anthropicBaseURL = URL(string: "https://api.anthropic.com/v1")!
    private static let requestTimeout: TimeInterval = 60

    // MARK: - Properties

    nonisolated let providerType: ProviderType

    private let session: URLSession
    private let openAIModel: String
    private let anthropicModel: String

    // MARK: - Init

    init(
        provider: ProviderType,
        openAIModel: String = "gpt-4o",
        anthropicModel: String = "claude-opus-4-6"
    ) {
        precondition(
            provider == .openai || provider == .anthropic,
            "CloudAPIProvider only supports .openai or .anthropic"
        )
        self.providerType = provider
        self.openAIModel = openAIModel
        self.anthropicModel = anthropicModel

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = CloudAPIProvider.requestTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - InferenceProvider

    var status: ProviderStatus {
        get async {
            let key = keychainKey(for: providerType)
            if loadAPIKey(service: key) != nil {
                return .ready
            }
            return .unavailable(reason: "No API key found for \(providerType.rawValue). Add it in Settings.")
        }
    }

    func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    switch self.providerType {
                    case .openai:
                        let stream = try await self.openAIStream(prompt: prompt, context: context)
                        for try await chunk in stream {
                            continuation.yield(chunk)
                        }
                    case .anthropic:
                        let stream = try await self.anthropicStream(prompt: prompt, context: context)
                        for try await chunk in stream {
                            continuation.yield(chunk)
                        }
                    default:
                        throw AIError.providerUnavailable(self.providerType)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func detectRegions(in image: CGImage) async throws -> [DetectedRegion] {
        // Cloud providers: vision endpoints could be wired here.
        // For now, defer to the CoreML provider's local implementation.
        return []
    }

    func performOCR(on image: CGImage) async throws -> OCRResult {
        // Cloud providers: vision endpoints could be wired here.
        return OCRResult(text: "", confidence: 0, language: nil, boundingBoxes: [])
    }

    nonisolated func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    // MARK: - Keychain

    /// Stores an API key in the Keychain.
    func storeAPIKey(_ key: String, for provider: ProviderType) throws {
        let service = keychainKey(for: provider)
        let data = Data(key.utf8)

        // Delete existing item first to avoid errSecDuplicateItem.
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "apikey",
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AIError.authenticationFailed
        }
    }

    // MARK: - Private: OpenAI SSE streaming

    private func openAIStream(
        prompt: String,
        context: InferenceContext
    ) async throws -> AsyncThrowingStream<String, Error> {
        let apiKey = try requireAPIKey(for: .openai)

        var request = URLRequest(
            url: CloudAPIProvider.openAIBaseURL.appending(path: "chat/completions")
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: any Sendable] = [
            "model": openAIModel,
            "stream": true,
            "max_tokens": context.maxTokens,
            "temperature": context.temperature,
            "messages": [["role": "user", "content": prompt]] as [[String: String]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await session.bytes(for: request)
        try validateHTTPResponse(response, provider: .openai)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private: Anthropic SSE streaming

    private func anthropicStream(
        prompt: String,
        context: InferenceContext
    ) async throws -> AsyncThrowingStream<String, Error> {
        let apiKey = try requireAPIKey(for: .anthropic)

        var request = URLRequest(
            url: CloudAPIProvider.anthropicBaseURL.appending(path: "messages")
        )
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: any Sendable] = [
            "model": anthropicModel,
            "stream": true,
            "max_tokens": context.maxTokens,
            "temperature": context.temperature,
            "messages": [["role": "user", "content": prompt]] as [[String: String]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await session.bytes(for: request)
        try validateHTTPResponse(response, provider: .anthropic)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type_ = json["type"] as? String,
                              type_ == "content_block_delta",
                              let delta = json["delta"] as? [String: Any],
                              let text = delta["text"] as? String else {
                            continue
                        }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private: Helpers

    private func validateHTTPResponse(_ response: URLResponse, provider: ProviderType) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.networkTimeout
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw AIError.authenticationFailed
        case 429:
            let retryAfter = TimeInterval(
                http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 60
            )
            throw AIError.rateLimited(retryAfter: retryAfter)
        default:
            throw AIError.providerUnavailable(provider)
        }
    }

    private func requireAPIKey(for provider: ProviderType) throws -> String {
        let service = keychainKey(for: provider)
        guard let key = loadAPIKey(service: service) else {
            throw AIError.authenticationFailed
        }
        return key
    }

    nonisolated private func keychainKey(for provider: ProviderType) -> String {
        "com.snapforge.apikey.\(provider.rawValue)"
    }

    nonisolated private func loadAPIKey(service: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
}
