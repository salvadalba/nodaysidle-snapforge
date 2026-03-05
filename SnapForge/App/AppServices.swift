import Foundation
import Observation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "AppServices")

// MARK: - AppServices
//
// Central dependency container injected via SwiftUI @Environment.
// Each service is an actor; AppServices itself is @Observable so
// the UI can react to top-level state changes (e.g., isReady).

@Observable
@MainActor
final class AppServices {

    // MARK: - AI Providers (Task 2, created by AI agent)

    let coreMLProvider: CoreMLProvider
    let mlxProvider: MLXProvider
    let ollamaProvider: OllamaProvider

    // MARK: - Capture Services (Task 3)

    let captureService: any CaptureServiceProtocol
    let libraryService: any LibraryServiceProtocol
    let ocrIndexer: OCRIndexer
    let recordingPipeline: RecordingPipeline

    // MARK: - State

    var isReady: Bool = false

    // MARK: - Init

    init() {
        // 1. AI providers — no dependencies
        self.coreMLProvider = CoreMLProvider()
        self.mlxProvider = MLXProvider()
        self.ollamaProvider = OllamaProvider()

        // 2. OCR indexer and recording pipeline — no dependencies
        self.ocrIndexer = OCRIndexer()
        self.recordingPipeline = RecordingPipeline()

        // 3. Library layer — requires ModelContainer + FTS5Index
        let modelContainer = Self.makeModelContainer()
        let fts5Index = Self.makeFTS5Index()
        self.libraryService = LibraryService(modelContainer: modelContainer, fts5Index: fts5Index)

        // 4. Capture engine — all dependencies ready
        let captureEngine = CaptureEngine()
        self.captureService = captureEngine

        self.isReady = true
        logger.info("AppServices: all services initialized")

        // 5. Inject recording pipeline into capture engine (must be async due to actor isolation)
        Task {
            await captureEngine.setRecordingPipeline(self.recordingPipeline)
        }
    }

    // MARK: - Private Factories

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([CaptureRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SnapForge: failed to initialize ModelContainer: \(error)")
        }
    }

    private static func makeFTS5Index() -> FTS5Index {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let snapForgeDir = appSupport.appendingPathComponent("SnapForge")
            try FileManager.default.createDirectory(at: snapForgeDir, withIntermediateDirectories: true)
            let dbURL = snapForgeDir.appendingPathComponent("fts5.sqlite")
            return try FTS5Index(databasePath: dbURL.path)
        } catch {
            fatalError("SnapForge: failed to initialize FTS5Index: \(error)")
        }
    }
}
