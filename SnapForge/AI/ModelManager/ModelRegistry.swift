import Foundation
import SwiftData
import os

// MARK: - RegistryEntry

/// Lightweight value type describing a model that SnapForge knows about.
public struct RegistryEntry: Sendable {
    public let id: UUID
    public let name: String
    public let providerType: String
    public let format: String
    public let sizeBytes: Int64
    public let version: String
    public let capabilities: String
    public let contextWindowSize: Int
    public let isBundled: Bool
    public let sha256Checksum: String?

    public init(
        id: UUID,
        name: String,
        providerType: String,
        format: String,
        sizeBytes: Int64,
        version: String,
        capabilities: String,
        contextWindowSize: Int,
        isBundled: Bool,
        sha256Checksum: String? = nil
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.format = format
        self.sizeBytes = sizeBytes
        self.version = version
        self.capabilities = capabilities
        self.contextWindowSize = contextWindowSize
        self.isBundled = isBundled
        self.sha256Checksum = sha256Checksum
    }
}

// MARK: - ModelRegistry

/// Maintains the canonical list of models SnapForge supports and seeds the
/// SwiftData store with bundled entries on first launch.
public actor ModelRegistry {

    // MARK: - Singleton

    public static let shared = ModelRegistry()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.snapforge", category: "ModelRegistry")

    /// Stable UUID for the bundled CoreML vision model so we can look it up
    /// across launches without hitting the database.
    public static let bundledVisionModelID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // MARK: - Hardcoded registry

    /// Source-of-truth catalogue of all models SnapForge knows about.
    /// Add new entries here; the store is seeded/updated at launch.
    /// Declared nonisolated because it is an immutable let — safe to read from any context.
    public nonisolated let allEntries: [RegistryEntry] = [
        // Bundled CoreML vision model — ships inside the app bundle.
        RegistryEntry(
            id: bundledVisionModelID,
            name: "SnapForge Vision (Bundled)",
            providerType: "coreml",
            format: "mlmodelc",
            sizeBytes: 42 * 1_048_576,     // ~42 MB
            version: "1.0",
            capabilities: "ocr,region_detection,captioning",
            contextWindowSize: 0,           // vision-only, no text context
            isBundled: true,
            sha256Checksum: nil             // bundled — integrity checked by Gatekeeper
        ),

        // Example cloud provider entries — zero download size.
        RegistryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Claude 3.5 Sonnet",
            providerType: "anthropic",
            format: "cloud_api",
            sizeBytes: 0,
            version: "20241022",
            capabilities: "captioning,annotation,qa",
            contextWindowSize: 200_000,
            isBundled: false,
            sha256Checksum: nil
        ),

        RegistryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "GPT-4o",
            providerType: "openai",
            format: "cloud_api",
            sizeBytes: 0,
            version: "2024-08-06",
            capabilities: "captioning,annotation,qa,vision",
            contextWindowSize: 128_000,
            isBundled: false,
            sha256Checksum: nil
        ),
    ]

    // MARK: - Seeding

    /// Inserts any registry entries missing from the SwiftData store.
    /// Safe to call every launch — checks for existing records before inserting.
    public func seedIfNeeded(context: ModelContext) {
        logger.info("ModelRegistry: seeding store if needed (\(self.allEntries.count) entries in registry)")

        for entry in allEntries {
            let entryID = entry.id
            let predicate = #Predicate<AIModel> { model in model.id == entryID }
            let descriptor = FetchDescriptor<AIModel>(predicate: predicate)

            do {
                let existing = try context.fetch(descriptor)
                if existing.isEmpty {
                    let model = AIModel(
                        id: entry.id,
                        name: entry.name,
                        providerType: entry.providerType,
                        sizeBytes: entry.sizeBytes,
                        version: entry.version,
                        capabilities: entry.capabilities,
                        isBundled: entry.isBundled,
                        isLoaded: false,
                        format: entry.format,
                        contextWindowSize: entry.contextWindowSize,
                        // Bundled or cloud models start as "downloaded".
                        downloadStatus: (entry.isBundled || entry.sizeBytes == 0)
                            ? "downloaded"
                            : "notDownloaded",
                        sha256Checksum: entry.sha256Checksum
                    )
                    context.insert(model)
                    logger.info("ModelRegistry: inserted '\(entry.name)'")
                }
            } catch {
                logger.error("ModelRegistry: fetch failed for '\(entry.name)': \(error)")
            }
        }

        do {
            try context.save()
        } catch {
            logger.error("ModelRegistry: save failed: \(error)")
        }
    }

    // MARK: - Queries

    /// Returns all registry entries whose model files are present on disk
    /// (or are cloud/bundled models that need no local file).
    public nonisolated func downloadedEntryIDs() -> Set<UUID> {
        Set(
            allEntries
                .filter { $0.isBundled || $0.sizeBytes == 0 }
                .map(\.id)
        )
    }

    /// Returns the registry entry for a given ID, or nil if unknown.
    public nonisolated func entry(for id: UUID) -> RegistryEntry? {
        allEntries.first { $0.id == id }
    }
}
