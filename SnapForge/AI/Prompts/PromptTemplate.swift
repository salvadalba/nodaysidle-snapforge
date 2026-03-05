import Foundation
import SwiftData

// MARK: - PromptTemplate

/// Persisted prompt template with variable substitution support.
/// Supports `{{image}}` and `{{ocr_text}}` placeholders.
@Model
final class PromptTemplate {

    // MARK: - Identity

    var id: UUID
    var name: String

    /// Raw template string. May contain `{{image}}` and `{{ocr_text}}` placeholders.
    var template: String

    // MARK: - Classification

    /// One of: "explain" / "annotate" / "summarize" / "custom"
    var category: String

    var usageCount: Int

    // MARK: - Metadata

    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        template: String,
        category: String,
        usageCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.template = template
        self.category = category
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
    }
}
