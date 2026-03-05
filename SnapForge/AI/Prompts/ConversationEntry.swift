import Foundation
import SwiftData

// MARK: - ConversationEntry

/// A single prompt/response exchange associated with a captured image record.
@Model
final class ConversationEntry {

    // MARK: - Identity

    var id: UUID

    /// References a `CaptureRecord.id` — stored as UUID rather than a SwiftData
    /// relationship so the conversation history can survive independent of the
    /// library record lifecycle.
    var captureRecordID: UUID

    // MARK: - Exchange

    var prompt: String
    var response: String

    // MARK: - Provider metadata

    /// Raw value of `ProviderType` (e.g. "coreml", "openai").
    var providerType: String
    var modelName: String

    // MARK: - Performance metrics

    var tokenCount: Int
    var latencyMS: Int

    // MARK: - Timestamp

    var timestamp: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        captureRecordID: UUID,
        prompt: String,
        response: String,
        providerType: String,
        modelName: String,
        tokenCount: Int = 0,
        latencyMS: Int = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.captureRecordID = captureRecordID
        self.prompt = prompt
        self.response = response
        self.providerType = providerType
        self.modelName = modelName
        self.tokenCount = tokenCount
        self.latencyMS = latencyMS
        self.timestamp = timestamp
    }
}
