import AppIntents
import Foundation

// MARK: - CaptureScreenshotIntent

@available(macOS 15.0, *)
struct CaptureScreenshotIntent: AppIntent {

    static let title: LocalizedStringResource = "Take Screenshot"
    static let description: IntentDescription = "Captures a screenshot using SnapForge."

    @Parameter(title: "Delay (seconds)", description: "Wait this many seconds before capturing.", default: 0)
    var delay: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CaptureResultEntity> {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }

        guard let appServices = AppServicesLocator.shared else {
            throw CaptureScreenshotIntentError.servicesUnavailable
        }

        let result = try await appServices.captureService.captureScreenshot(region: nil)
        let entity = CaptureResultEntity(
            id: result.id,
            captureType: result.captureType.rawValue,
            filePath: result.filePath,
            fileSize: result.fileSize,
            timestamp: result.timestamp
        )
        return .result(value: entity)
    }
}

// MARK: - CaptureResultEntity

@available(macOS 15.0, *)
struct CaptureResultEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Capture Result")
    static let defaultQuery = CaptureResultEntityQuery()

    var id: UUID
    var captureType: String
    var filePath: String
    var fileSize: Int64
    var timestamp: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(captureType.capitalized) — \(filePath.components(separatedBy: "/").last ?? filePath)",
            subtitle: "\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))"
        )
    }
}

// MARK: - CaptureResultEntityQuery

@available(macOS 15.0, *)
struct CaptureResultEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CaptureResultEntity] {
        return []
    }
}

// MARK: - Error

private enum CaptureScreenshotIntentError: Error, LocalizedError {
    case servicesUnavailable

    var errorDescription: String? {
        "SnapForge services are not available. Ensure the app is running."
    }
}

// MARK: - AppServicesLocator

@MainActor
final class AppServicesLocator: @unchecked Sendable {
    static var shared: AppServices?
}
