import Foundation
import SwiftData

// MARK: - CaptureRecord

@Model
final class CaptureRecord {

    // MARK: Identity

    var id: UUID
    var captureType: String
    var filePath: String
    var thumbnailPath: String?

    // MARK: Content

    var ocrText: String?
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var windowTitle: String?
    var sourceDomain: String?

    // MARK: Organization

    /// Comma-separated tag list, e.g. "bug,frontend,design".
    var tags: String
    var annotationsJSON: Data?

    // MARK: Sharing

    /// One of: "local", "uploaded", "expired", "deleted"
    var sharingStatus: String
    var shareURL: String?

    // MARK: Media Properties

    var fileSize: Int64
    var width: Int?
    var height: Int?
    /// Duration in seconds (for video/GIF captures).
    var duration: Double?

    // MARK: Metadata

    var createdAt: Date
    var isStarred: Bool

    // MARK: Init

    init(
        id: UUID = UUID(),
        captureType: String,
        filePath: String,
        thumbnailPath: String? = nil,
        ocrText: String? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        windowTitle: String? = nil,
        sourceDomain: String? = nil,
        tags: String = "",
        annotationsJSON: Data? = nil,
        sharingStatus: String = "local",
        shareURL: String? = nil,
        fileSize: Int64 = 0,
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil,
        createdAt: Date = Date(),
        isStarred: Bool = false
    ) {
        self.id = id
        self.captureType = captureType
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.ocrText = ocrText
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.windowTitle = windowTitle
        self.sourceDomain = sourceDomain
        self.tags = tags
        self.annotationsJSON = annotationsJSON
        self.sharingStatus = sharingStatus
        self.shareURL = shareURL
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.duration = duration
        self.createdAt = createdAt
        self.isStarred = isStarred
    }
}

// MARK: - Convenience

extension CaptureRecord {

    /// Returns the tag list as a sorted array, deduplicated.
    var tagArray: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// Replaces the tag list from an array.
    func setTags(_ newTags: [String]) {
        tags = newTags
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }
}
