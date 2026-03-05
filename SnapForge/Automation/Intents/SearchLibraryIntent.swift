import AppIntents
import Foundation

// MARK: - SearchLibraryIntent

@available(macOS 15.0, *)
struct SearchLibraryIntent: AppIntent {

    static let title: LocalizedStringResource = "Search SnapForge Library"
    static let description: IntentDescription = "Searches captures by text, tags, or OCR content."

    @Parameter(title: "Query", description: "Search query (text, tag, or OCR content).")
    var query: String

    @Parameter(title: "Limit", description: "Maximum number of results to return.", default: 20)
    var limit: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[LibrarySearchResultEntity]> {
        guard let appServices = AppServicesLocator.shared else {
            throw SearchLibraryIntentError.servicesUnavailable
        }

        let safeLimit = max(1, min(limit, 100))

        let results = try await appServices.libraryService.search(
            query: query,
            filters: LibraryFilters(),
            sort: .relevance,
            limit: safeLimit,
            offset: 0
        )

        let entities = results.records.map { snap in
            LibrarySearchResultEntity(
                id: snap.id,
                captureType: snap.captureType,
                filePath: snap.filePath,
                fileSize: snap.fileSize,
                windowTitle: snap.windowTitle,
                sourceAppName: snap.sourceAppName,
                tags: snap.tags,
                createdAt: snap.createdAt,
                isStarred: snap.isStarred
            )
        }

        return .result(value: entities)
    }
}

// MARK: - LibrarySearchResultEntity

@available(macOS 15.0, *)
struct LibrarySearchResultEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Library Search Result")
    static let defaultQuery = LibrarySearchResultEntityQuery()

    var id: UUID
    var captureType: String
    var filePath: String
    var fileSize: Int64
    var windowTitle: String?
    var sourceAppName: String?
    var tags: String
    var createdAt: Date
    var isStarred: Bool

    var displayRepresentation: DisplayRepresentation {
        let filename = filePath.components(separatedBy: "/").last ?? filePath
        let subtitle = windowTitle ?? sourceAppName ?? captureType.capitalized
        return DisplayRepresentation(
            title: "\(filename)",
            subtitle: "\(subtitle) · \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))"
        )
    }
}

// MARK: - LibrarySearchResultEntityQuery

@available(macOS 15.0, *)
struct LibrarySearchResultEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [LibrarySearchResultEntity] {
        guard let appServices = await AppServicesLocator.shared else { return [] }
        var entities: [LibrarySearchResultEntity] = []
        for id in identifiers {
            if let snap = try? await appServices.libraryService.fetch(id: id) {
                entities.append(LibrarySearchResultEntity(
                    id: snap.id,
                    captureType: snap.captureType,
                    filePath: snap.filePath,
                    fileSize: snap.fileSize,
                    windowTitle: snap.windowTitle,
                    sourceAppName: snap.sourceAppName,
                    tags: snap.tags,
                    createdAt: snap.createdAt,
                    isStarred: snap.isStarred
                ))
            }
        }
        return entities
    }
}

// MARK: - Error

private enum SearchLibraryIntentError: Error, LocalizedError {
    case servicesUnavailable

    var errorDescription: String? {
        "SnapForge services are not available. Ensure the app is running."
    }
}
