import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "PromptStorageService")

// MARK: - PromptStorageService

/// Actor that manages persistence of `PromptTemplate` and `ConversationEntry`
/// records via SwiftData. All database access is serialised through the actor.
actor PromptStorageService {

    // MARK: - Properties

    private let modelContainer: ModelContainer

    // MARK: - Init

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Seeding

    /// Seeds default templates on first launch. Safe to call multiple times —
    /// checks for existing defaults before inserting.
    func seedDefaultTemplatesIfNeeded() async throws {
        let context = ModelContext(modelContainer)
        let existing = try context.fetch(
            FetchDescriptor<PromptTemplate>(
                predicate: #Predicate { $0.isDefault == true }
            )
        )
        guard existing.isEmpty else { return }

        let defaults: [(name: String, template: String, category: String)] = [
            (
                "Explain this screenshot",
                "Please explain what is shown in this screenshot.\n\n{{ocr_text}}",
                "explain"
            ),
            (
                "Summarize the text",
                "Summarize the key points from the text below:\n\n{{ocr_text}}",
                "summarize"
            ),
            (
                "Extract key information",
                "Extract all key information, data points, and actionable items from this screenshot.\n\n{{ocr_text}}",
                "explain"
            ),
            (
                "Compare with previous",
                "Compare this screenshot with the previous one and highlight any differences or changes.\n\n{{ocr_text}}",
                "custom"
            )
        ]

        for entry in defaults {
            let template = PromptTemplate(
                name: entry.name,
                template: entry.template,
                category: entry.category,
                isDefault: true
            )
            context.insert(template)
        }

        try context.save()
        logger.info("PromptStorageService: seeded \(defaults.count) default templates")
    }

    // MARK: - PromptTemplate CRUD

    /// Returns all templates sorted by usage count descending, then name ascending.
    func fetchAllTemplates() throws -> [PromptTemplate] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PromptTemplate>(
            sortBy: [
                SortDescriptor(\.usageCount, order: .reverse),
                SortDescriptor(\.name)
            ]
        )
        return try context.fetch(descriptor)
    }

    /// Returns templates matching a specific category.
    func fetchTemplates(category: String) throws -> [PromptTemplate] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.category == category },
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Inserts a new template and returns its persistent model ID.
    @discardableResult
    func createTemplate(
        name: String,
        template: String,
        category: String,
        isDefault: Bool = false
    ) throws -> PromptTemplate {
        let context = ModelContext(modelContainer)
        let newTemplate = PromptTemplate(
            name: name,
            template: template,
            category: category,
            isDefault: isDefault
        )
        context.insert(newTemplate)
        try context.save()
        logger.info("PromptStorageService: created template '\(name)'")
        return newTemplate
    }

    /// Updates an existing template's name and body, refreshing `updatedAt`.
    func updateTemplate(id: UUID, name: String, template: String, category: String) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try context.fetch(descriptor).first else {
            logger.warning("PromptStorageService: updateTemplate — template \(id) not found")
            return
        }
        existing.name = name
        existing.template = template
        existing.category = category
        existing.updatedAt = Date()
        try context.save()
    }

    /// Deletes the template with the given ID.
    func deleteTemplate(id: UUID) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try context.fetch(descriptor).first else { return }
        context.delete(existing)
        try context.save()
        logger.info("PromptStorageService: deleted template \(id)")
    }

    /// Atomically increments the usage counter for the given template.
    func incrementUsageCount(for templateID: UUID) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.id == templateID }
        )
        guard let template = try context.fetch(descriptor).first else { return }
        template.usageCount += 1
        template.updatedAt = Date()
        try context.save()
    }

    // MARK: - Placeholder Substitution

    /// Replaces `{{ocr_text}}` in a template string with the provided OCR text.
    /// The `{{image}}` placeholder is a signal to include the raw image in the
    /// inference context — it is left in place for the caller to handle.
    nonisolated func substitutePlaceholders(template: String, ocrText: String?) -> String {
        let text = ocrText ?? ""
        return template.replacingOccurrences(of: "{{ocr_text}}", with: text)
    }

    // MARK: - ConversationEntry

    /// Persists a completed prompt/response exchange.
    func saveConversation(
        captureRecordID: UUID,
        prompt: String,
        response: String,
        provider: ProviderType,
        modelName: String = "",
        tokenCount: Int = 0,
        latencyMS: Int = 0
    ) throws {
        let context = ModelContext(modelContainer)
        let entry = ConversationEntry(
            captureRecordID: captureRecordID,
            prompt: prompt,
            response: response,
            providerType: provider.rawValue,
            modelName: modelName,
            tokenCount: tokenCount,
            latencyMS: latencyMS
        )
        context.insert(entry)
        try context.save()
        logger.info("PromptStorageService: saved conversation for capture \(captureRecordID)")
    }

    /// Returns all conversation entries for a given capture record, most recent first.
    func fetchConversations(for captureRecordID: UUID) throws -> [ConversationEntry] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ConversationEntry>(
            predicate: #Predicate { $0.captureRecordID == captureRecordID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Deletes a single conversation entry by ID.
    func deleteConversation(id: UUID) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ConversationEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entry = try context.fetch(descriptor).first else { return }
        context.delete(entry)
        try context.save()
    }
}
