import Foundation

public enum AIError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case contextWindowExceeded(limit: Int, requested: Int)
    case providerUnavailable(ProviderType)
    case authenticationFailed
    case rateLimited(retryAfter: TimeInterval)
    case networkTimeout
    case inferenceTimeout
    case downloadFailed(reason: String)
    case gpuMemoryInsufficient
    case integrityCheckFailed
    case insufficientStorage

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The AI model has not been loaded. Please ensure the model is downloaded and initialized."
        case .contextWindowExceeded(let limit, let requested):
            return "Context window exceeded: requested \(requested) tokens but the limit is \(limit)."
        case .providerUnavailable(let provider):
            return "The AI provider '\(provider.rawValue)' is currently unavailable."
        case .authenticationFailed:
            return "Authentication failed. Please check your API key in Settings."
        case .rateLimited(let retryAfter):
            let seconds = Int(retryAfter)
            return "Rate limit reached. Please retry after \(seconds) second\(seconds == 1 ? "" : "s")."
        case .networkTimeout:
            return "The network request timed out. Please check your connection and try again."
        case .inferenceTimeout:
            return "AI inference timed out. The model may be overloaded or the input too large."
        case .downloadFailed(let reason):
            return "Model download failed: \(reason)"
        case .gpuMemoryInsufficient:
            return "Insufficient GPU memory to run inference. Try closing other applications."
        case .integrityCheckFailed:
            return "Model integrity check failed. The model file may be corrupted. Please re-download."
        case .insufficientStorage:
            return "Insufficient storage space to download the model."
        }
    }
}
