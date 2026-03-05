import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "LibraryService")

// MARK: - Supporting Types

public struct LibraryFilters: Sendable {
    public var captureTypes: [String]
    public var sourceApp: String?
    public var tags: [String]
    public var fromDate: Date?
    public var toDate: Date?
    public var isStarred: Bool?

    public init(
        captureTypes: [String] = [],
        sourceApp: String? = nil,
        tags: [String] = [],
        fromDate: Date? = nil,
        toDate: Date? = nil,
        isStarred: Bool? = nil
    ) {
        self.captureTypes = captureTypes
        self.sourceApp = sourceApp
        self.tags = tags
        self.fromDate = fromDate
        self.toDate = toDate
        self.isStarred = isStarred
    }
}

public enum SortOrder: String, Sendable, Codable {
    case timestampDesc
    case timestampAsc
    case relevance
    case fileSizeDesc
    case fileSizeAsc
}

public struct SearchResults: Sendable {
    public let records: [CaptureRecordSnapshot]
    public let totalCount: Int
    public let offset: Int
    public let limit: Int
}

/// Sendable value-type snapshot of a CaptureRecord for cross-actor transfer.
public struct CaptureRecordSnapshot: Sendable {
    public let id: UUID
    public let captureType: String
    public let filePath: String
    public let thumbnailPath: String?
    public let ocrText: String?
    public let sourceAppBundleID: String?
    public let sourceAppName: String?
    public let windowTitle: String?
    public let sourceDomain: String?
    public let tags: String
    public let sharingStatus: String
    public let shareURL: String?
    public let fileSize: Int64
    public let width: Int?
    public let height: Int?
    public let duration: Double?
    public let createdAt: Date
    public let isStarred: Bool

    init(record: CaptureRecord) {
        self.id = record.id
        self.captureType = record.captureType
        self.filePath = record.filePath
        self.thumbnailPath = record.thumbnailPath
        self.ocrText = record.ocrText
        self.sourceAppBundleID = record.sourceAppBundleID
        self.sourceAppName = record.sourceAppName
        self.windowTitle = record.windowTitle
        self.sourceDomain = record.sourceDomain
        self.tags = record.tags
        self.sharingStatus = record.sharingStatus
        self.shareURL = record.shareURL
        self.fileSize = record.fileSize
        self.width = record.width
        self.height = record.height
        self.duration = record.duration
        self.createdAt = record.createdAt
        self.isStarred = record.isStarred
    }
}

public struct StorageUsageReport: Sendable {
    public let totalBytes: Int64
    public let screenshotBytes: Int64
    public let videoBytes: Int64
    public let gifBytes: Int64
    public let captureCount: Int
}

public struct CleanupRule: Sendable {
    public let olderThanDays: Int?
    public let captureTypes: [String]
    public let keepStarred: Bool
    public let maxStorageBytes: Int64?

    public init(
        olderThanDays: Int? = nil,
        captureTypes: [String] = [],
        keepStarred: Bool = true,
        maxStorageBytes: Int64? = nil
    ) {
        self.olderThanDays = olderThanDays
        self.captureTypes = captureTypes
        self.keepStarred = keepStarred
        self.maxStorageBytes = maxStorageBytes
    }
}

public struct CleanupResult: Sendable {
    public let deletedCount: Int
    public let freedBytes: Int64
}

public struct TagUsage: Sendable {
    public let tag: String
    public let count: Int
}

// MARK: - LibraryServiceProtocol

public protocol LibraryServiceProtocol: Sendable {
    func save(result: CaptureResult) async throws -> CaptureRecordSnapshot
    func search(query: String, filters: LibraryFilters, sort: SortOrder, limit: Int, offset: Int) async throws -> SearchResults
    func fetch(id: UUID) async throws -> CaptureRecordSnapshot?
    func fetchAll(filters: LibraryFilters, sort: SortOrder, limit: Int, offset: Int) async throws -> SearchResults
    func delete(id: UUID, deleteFile: Bool) async throws
    func updateTags(id: UUID, tags: [String]) async throws
    func updateOCRText(id: UUID, ocrText: String) async throws
    func storageUsage() async throws -> StorageUsageReport
    func runCleanup(rule: CleanupRule) async throws -> CleanupResult
    func allTags() async throws -> [TagUsage]
    func reindexOCR() async throws
}

// MARK: - LibraryService

actor LibraryService: LibraryServiceProtocol {

    private let modelContainer: ModelContainer
    private let fts5Index: FTS5Index

    // MARK: Init

    init(modelContainer: ModelContainer, fts5Index: FTS5Index) {
        self.modelContainer = modelContainer
        self.fts5Index = fts5Index
    }

    // MARK: Save

    func save(result: CaptureResult) async throws -> CaptureRecordSnapshot {
        let context = ModelContext(modelContainer)
        let record = CaptureRecord(
            id: result.id,
            captureType: result.captureType.rawValue,
            filePath: result.filePath,
            thumbnailPath: result.thumbnailPath,
            sourceAppBundleID: result.sourceAppBundleID,
            sourceAppName: result.sourceAppName,
            windowTitle: result.windowTitle,
            fileSize: result.fileSize,
            width: Int(result.dimensions.width),
            height: Int(result.dimensions.height),
            createdAt: result.timestamp
        )
        context.insert(record)
        try context.save()

        try? fts5Index.insert(
            captureID: record.id,
            ocrText: "",
            tags: "",
            sourceApp: record.sourceAppName
        )

        logger.info("LibraryService: saved capture \(record.id)")
        return CaptureRecordSnapshot(record: record)
    }

    // MARK: Search

    func search(
        query: String,
        filters: LibraryFilters,
        sort: SortOrder,
        limit: Int,
        offset: Int
    ) async throws -> SearchResults {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try await fetchAll(filters: filters, sort: sort, limit: limit, offset: offset)
        }

        let ftsResults = try fts5Index.search(query: query, limit: limit * 3, offset: 0)
        let matchedIDs = Set(ftsResults.map(\.captureID))

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CaptureRecord>()
        let all = try context.fetch(descriptor)

        var filtered = all.filter { matchedIDs.contains($0.id) }
        filtered = applyFilters(filtered, filters: filters)

        // Preserve FTS rank order for relevance sort
        if sort == .relevance {
            let rankMap = Dictionary(uniqueKeysWithValues: ftsResults.map { ($0.captureID, $0.rank) })
            filtered.sort { rankMap[$0.id] ?? 0 < rankMap[$1.id] ?? 0 }
        } else {
            filtered = applySorting(filtered, sort: sort)
        }

        let totalCount = filtered.count
        let paged = Array(filtered.dropFirst(offset).prefix(limit))
        return SearchResults(
            records: paged.map { CaptureRecordSnapshot(record: $0) },
            totalCount: totalCount,
            offset: offset,
            limit: limit
        )
    }

    // MARK: Fetch

    func fetch(id: UUID) async throws -> CaptureRecordSnapshot? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        let results = try context.fetch(descriptor)
        return results.first.map { CaptureRecordSnapshot(record: $0) }
    }

    func fetchAll(
        filters: LibraryFilters,
        sort: SortOrder,
        limit: Int,
        offset: Int
    ) async throws -> SearchResults {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CaptureRecord>()
        let all = try context.fetch(descriptor)

        var filtered = applyFilters(all, filters: filters)
        filtered = applySorting(filtered, sort: sort)

        let totalCount = filtered.count
        let paged = Array(filtered.dropFirst(offset).prefix(limit))
        return SearchResults(
            records: paged.map { CaptureRecordSnapshot(record: $0) },
            totalCount: totalCount,
            offset: offset,
            limit: limit
        )
    }

    // MARK: Delete

    func delete(id: UUID, deleteFile: Bool) async throws {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        let results = try context.fetch(descriptor)

        guard let record = results.first else { return }

        if deleteFile {
            try? FileManager.default.removeItem(atPath: record.filePath)
            if let thumbPath = record.thumbnailPath {
                try? FileManager.default.removeItem(atPath: thumbPath)
            }
        }

        context.delete(record)
        try context.save()

        try? fts5Index.delete(captureID: id)
        logger.info("LibraryService: deleted capture \(id)")
    }

    // MARK: Update Tags

    func updateTags(id: UUID, tags: [String]) async throws {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        let results = try context.fetch(descriptor)

        guard let record = results.first else { return }
        record.setTags(tags)
        try context.save()

        try? fts5Index.update(captureID: id, ocrText: nil, tags: record.tags)
    }

    // MARK: Update OCR

    func updateOCRText(id: UUID, ocrText: String) async throws {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        let results = try context.fetch(descriptor)

        guard let record = results.first else { return }
        record.ocrText = ocrText
        try context.save()

        try? fts5Index.update(captureID: id, ocrText: ocrText, tags: nil)
    }

    // MARK: Storage Usage

    func storageUsage() async throws -> StorageUsageReport {
        let context = ModelContext(modelContainer)
        let all = try context.fetch(FetchDescriptor<CaptureRecord>())

        var total: Int64 = 0
        var screenshots: Int64 = 0
        var videos: Int64 = 0
        var gifs: Int64 = 0

        for record in all {
            total += record.fileSize
            switch record.captureType {
            case "screenshot", "scrolling", "ocr", "pin": screenshots += record.fileSize
            case "video": videos += record.fileSize
            case "gif": gifs += record.fileSize
            default: break
            }
        }

        return StorageUsageReport(
            totalBytes: total,
            screenshotBytes: screenshots,
            videoBytes: videos,
            gifBytes: gifs,
            captureCount: all.count
        )
    }

    // MARK: Cleanup

    func runCleanup(rule: CleanupRule) async throws -> CleanupResult {
        let context = ModelContext(modelContainer)
        let all = try context.fetch(FetchDescriptor<CaptureRecord>())

        var toDelete: [CaptureRecord] = []
        let now = Date()

        for record in all {
            if rule.keepStarred && record.isStarred { continue }

            if !rule.captureTypes.isEmpty && !rule.captureTypes.contains(record.captureType) { continue }

            if let days = rule.olderThanDays {
                let cutoff = now.addingTimeInterval(-TimeInterval(days * 86400))
                if record.createdAt < cutoff {
                    toDelete.append(record)
                }
            }
        }

        var freedBytes: Int64 = 0
        for record in toDelete {
            freedBytes += record.fileSize
            try? FileManager.default.removeItem(atPath: record.filePath)
            if let thumb = record.thumbnailPath {
                try? FileManager.default.removeItem(atPath: thumb)
            }
            try? fts5Index.delete(captureID: record.id)
            context.delete(record)
        }
        try context.save()

        logger.info("LibraryService: cleanup deleted \(toDelete.count) records, freed \(freedBytes) bytes")
        return CleanupResult(deletedCount: toDelete.count, freedBytes: freedBytes)
    }

    // MARK: All Tags

    func allTags() async throws -> [TagUsage] {
        let context = ModelContext(modelContainer)
        let all = try context.fetch(FetchDescriptor<CaptureRecord>())

        var tagCounts: [String: Int] = [:]
        for record in all {
            for tag in record.tagArray {
                tagCounts[tag, default: 0] += 1
            }
        }

        return tagCounts.map { TagUsage(tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: Reindex OCR

    func reindexOCR() async throws {
        try fts5Index.rebuildIndex()
        logger.info("LibraryService: FTS5 index rebuilt")
    }

    // MARK: Private Filter/Sort Helpers

    private func applyFilters(_ records: [CaptureRecord], filters: LibraryFilters) -> [CaptureRecord] {
        var result = records

        if !filters.captureTypes.isEmpty {
            result = result.filter { filters.captureTypes.contains($0.captureType) }
        }

        if let sourceApp = filters.sourceApp {
            result = result.filter { $0.sourceAppBundleID == sourceApp || $0.sourceAppName == sourceApp }
        }

        if !filters.tags.isEmpty {
            result = result.filter { record in
                let recordTags = Set(record.tagArray)
                return filters.tags.allSatisfy { recordTags.contains($0) }
            }
        }

        if let from = filters.fromDate {
            result = result.filter { $0.createdAt >= from }
        }

        if let to = filters.toDate {
            result = result.filter { $0.createdAt <= to }
        }

        if let starred = filters.isStarred {
            result = result.filter { $0.isStarred == starred }
        }

        return result
    }

    private func applySorting(_ records: [CaptureRecord], sort: SortOrder) -> [CaptureRecord] {
        switch sort {
        case .timestampDesc, .relevance:
            return records.sorted { $0.createdAt > $1.createdAt }
        case .timestampAsc:
            return records.sorted { $0.createdAt < $1.createdAt }
        case .fileSizeDesc:
            return records.sorted { $0.fileSize > $1.fileSize }
        case .fileSizeAsc:
            return records.sorted { $0.fileSize < $1.fileSize }
        }
    }
}
