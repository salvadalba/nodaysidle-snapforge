import Foundation
import CoreGraphics

// MARK: - OllamaProvider

actor OllamaProvider: @preconcurrency InferenceProvider {

    // MARK: - Constants

    private static let baseURL = URL(string: "http://127.0.0.1:11434")!
    private static let requestTimeout: TimeInterval = 30
    private static let maxRetries = 3

    // MARK: - Properties

    nonisolated let providerType: ProviderType = .ollama

    private let model: String
    private let session: URLSession

    // MARK: - Init

    init(model: String = "llama3.2") {
        self.model = model
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = OllamaProvider.requestTimeout
        config.timeoutIntervalForResource = OllamaProvider.requestTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - InferenceProvider

    var status: ProviderStatus {
        get async {
            let tagsURL = OllamaProvider.baseURL.appending(path: "api/tags")
            var request = URLRequest(url: tagsURL)
            request.timeoutInterval = 5
            do {
                let (_, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    return .unavailable(reason: "Ollama returned unexpected status")
                }
                return .ready
            } catch {
                return .unavailable(reason: "Ollama not running at \(OllamaProvider.baseURL)")
            }
        }
    }

    func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try await self.streamGenerate(prompt: prompt, context: context)
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func detectRegions(in image: CGImage) async throws -> [DetectedRegion] {
        // Ollama does not natively expose a region detection endpoint.
        return []
    }

    func performOCR(on image: CGImage) async throws -> OCRResult {
        // Ollama does not natively expose an OCR endpoint.
        return OCRResult(text: "", confidence: 0, language: nil, boundingBoxes: [])
    }

    nonisolated func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    // MARK: - Private

    private func streamGenerate(
        prompt: String,
        context: InferenceContext
    ) async throws -> AsyncThrowingStream<String, Error> {
        let url = OllamaProvider.baseURL.appending(path: "api/generate")
        let body: [String: any Sendable] = [
            "model": model,
            "prompt": prompt,
            "stream": true,
            "options": [
                "num_predict": context.maxTokens,
                "temperature": context.temperature
            ] as [String: any Sendable]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // Fully constructed let-binding before entering @Sendable closure.
        let finalRequest: URLRequest = {
            var r = URLRequest(url: url)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = bodyData
            return r
        }()

        let (asyncBytes, response) = try await withRetry(maxAttempts: OllamaProvider.maxRetries) {
            try await self.session.bytes(for: finalRequest)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIError.networkTimeout
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw AIError.authenticationFailed
        case 429:
            let retryAfter = TimeInterval(
                (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(Double.init) ?? 60
            )
            throw AIError.rateLimited(retryAfter: retryAfter)
        default:
            throw AIError.providerUnavailable(.ollama)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in asyncBytes.lines {
                        guard !line.isEmpty else { continue }
                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let token = json["response"] as? String else {
                            continue
                        }
                        continuation.yield(token)
                        if let done = json["done"] as? Bool, done {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Exponential backoff retry: 1s, 2s, 4s delays.
    private func withRetry<T: Sendable>(
        maxAttempts: Int,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch let urlError as URLError where urlError.code == .cannotConnectToHost
                                                   || urlError.code == .networkConnectionLost {
                throw AIError.providerUnavailable(.ollama)
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = TimeInterval(1 << attempt) // 1s, 2s, 4s
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        throw lastError ?? AIError.networkTimeout
    }
}
