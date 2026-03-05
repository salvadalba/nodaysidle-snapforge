# Technical Requirements Document

## 🧭 System Context
SnapForge is a local-first macOS 15+ screen capture studio built in Swift 6 and SwiftUI 6. Single-process modular monolith with actor-isolated services communicating via async protocol interfaces. No server required for core functionality. AI inference runs on-device via Core ML and Apple Vision framework with pluggable providers (MLX, Ollama, cloud APIs). Data persisted in SwiftData with a parallel SQLite FTS5 index for OCR full-text search. Menu bar utility with NSWindow-based overlays for capture, annotation, and command palette. Metal-accelerated recording pipeline. E2E encrypted optional cloud sharing to user-provided S3-compatible storage.

## 🔌 API Contracts
### HTTP Bridge — List Capture Types
- **Method:** GET
- **Path:** /api/v1/capture/types
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** No body. Optional query param ?include_disabled=true.
- **Response:** { "types": [{ "id": "screenshot", "label": "Screenshot", "shortcut": "⌘⇧4", "enabled": true }, { "id": "scrolling", "label": "Scrolling Capture", "shortcut": "⌘⇧S", "enabled": true }, { "id": "video", "label": "Screen Recording", "shortcut": "⌘⇧5", "enabled": true }, { "id": "gif", "label": "GIF Recording", "shortcut": "⌘⇧G", "enabled": true }, { "id": "ocr", "label": "OCR Capture", "shortcut": "⌘⇧O", "enabled": true }, { "id": "pin", "label": "Pin to Screen", "shortcut": "⌘⇧P", "enabled": true }] }
- **Errors:** 401 Unauthorized — missing or invalid bearer token, 500 Internal Server Error — service initialization failure

### HTTP Bridge — Trigger Capture
- **Method:** POST
- **Path:** /api/v1/capture
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "type": "screenshot" | "scrolling" | "video" | "gif" | "ocr" | "pin", "region": { "x": 0, "y": 0, "width": 800, "height": 600 } | null, "delay_seconds": 0, "auto_action": "copy" | "save" | "annotate" | null }
- **Response:** { "capture_id": "uuid-string", "file_path": "/path/to/capture.png", "timestamp": "2026-03-05T10:30:00Z", "type": "screenshot", "status": "completed" }
- **Errors:** 400 Bad Request — invalid capture type or region, 401 Unauthorized — missing or invalid bearer token, 409 Conflict — capture already in progress, 503 Service Unavailable — ScreenCaptureKit permission not granted

### HTTP Bridge — Start Recording
- **Method:** POST
- **Path:** /api/v1/capture/record/start
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "type": "video" | "gif", "region": { "x": 0, "y": 0, "width": 1920, "height": 1080 } | null, "fps": 30, "codec": "h264" | "h265" | "prores", "bitrate": 8000000, "resolution_scale": 1.0, "auto_adjust_quality": true }
- **Response:** { "recording_id": "uuid-string", "status": "recording", "started_at": "2026-03-05T10:30:00Z" }
- **Errors:** 400 Bad Request — invalid codec or FPS value, 401 Unauthorized, 409 Conflict — recording already in progress, 503 Service Unavailable — ScreenCaptureKit permission not granted

### HTTP Bridge — Stop Recording
- **Method:** POST
- **Path:** /api/v1/capture/record/stop
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "recording_id": "uuid-string", "trim": { "start_seconds": 0.0, "end_seconds": null } | null }
- **Response:** { "recording_id": "uuid-string", "file_path": "/path/to/recording.mov", "duration_seconds": 12.5, "file_size_bytes": 15000000, "status": "completed" }
- **Errors:** 400 Bad Request — invalid recording_id or trim range, 401 Unauthorized, 404 Not Found — no active recording with that ID

### HTTP Bridge — Search Library
- **Method:** GET
- **Path:** /api/v1/library/search
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** Query params: ?q=search+text&type=screenshot|video|gif|scrolling|ocr|pin&source_app=com.apple.Safari&tag=bug&from=2026-01-01&to=2026-03-05&limit=50&offset=0&sort=timestamp_desc|relevance
- **Response:** { "results": [{ "id": "uuid", "timestamp": "2026-03-05T10:30:00Z", "type": "screenshot", "source_app_name": "Safari", "source_app_bundle_id": "com.apple.Safari", "source_domain": "github.com", "file_path": "/path/to/file.png", "thumbnail_path": "/path/to/thumb.png", "ocr_text_snippet": "matched text...", "tags": ["bug", "frontend"], "file_size_bytes": 250000 }], "total_count": 142, "offset": 0, "limit": 50 }
- **Errors:** 400 Bad Request — invalid date range or sort parameter, 401 Unauthorized

### HTTP Bridge — Get Capture Detail
- **Method:** GET
- **Path:** /api/v1/library/captures/{capture_id}
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** No body. Path param capture_id is UUID string.
- **Response:** { "id": "uuid", "timestamp": "2026-03-05T10:30:00Z", "type": "screenshot", "source_app_name": "Xcode", "source_app_bundle_id": "com.apple.dt.Xcode", "source_domain": null, "file_path": "/path/to/file.png", "thumbnail_path": "/path/to/thumb.png", "ocr_text": "full OCR text...", "tags": ["bug"], "annotations_json": "[...]", "sharing_status": "local", "file_size_bytes": 250000, "ai_conversations": [{ "id": "uuid", "prompt": "Explain this screenshot", "response": "This shows...", "provider": "coreml", "timestamp": "2026-03-05T10:31:00Z" }] }
- **Errors:** 401 Unauthorized, 404 Not Found — capture_id does not exist

### HTTP Bridge — Delete Capture
- **Method:** DELETE
- **Path:** /api/v1/library/captures/{capture_id}
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** No body. Path param capture_id is UUID string. Optional query param ?delete_file=true (default true).
- **Response:** { "deleted": true, "capture_id": "uuid" }
- **Errors:** 401 Unauthorized, 404 Not Found — capture_id does not exist

### HTTP Bridge — AI Explain Screenshot
- **Method:** POST
- **Path:** /api/v1/ai/explain
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "capture_id": "uuid-string", "prompt": "Explain this screenshot" | null, "provider": "coreml" | "mlx" | "ollama" | "openai" | "anthropic" | null, "stream": true }
- **Response:** If stream=false: { "capture_id": "uuid", "explanation": "This screenshot shows...", "provider": "coreml", "token_count": 150, "latency_ms": 1200 }. If stream=true: SSE stream with events: data: { "chunk": "partial text", "done": false } and final data: { "chunk": "", "done": true, "token_count": 150, "latency_ms": 1200 }
- **Errors:** 400 Bad Request — invalid capture_id or provider, 401 Unauthorized, 404 Not Found — capture not found, 503 Service Unavailable — selected AI provider not available or model not loaded

### HTTP Bridge — AI Smart Region Detection
- **Method:** POST
- **Path:** /api/v1/ai/detect-regions
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "capture_id": "uuid-string" } or { "image_data": "base64-encoded-png" }
- **Response:** { "regions": [{ "label": "Navigation Bar", "bounds": { "x": 0, "y": 0, "width": 1920, "height": 48 }, "confidence": 0.95, "element_type": "navigation" }, { "label": "Main Content", "bounds": { "x": 0, "y": 48, "width": 1920, "height": 1032 }, "confidence": 0.88, "element_type": "content" }] }
- **Errors:** 400 Bad Request — neither capture_id nor image_data provided, 401 Unauthorized, 404 Not Found — capture not found, 503 Service Unavailable — Core ML model not loaded

### HTTP Bridge — Upload / Share Capture
- **Method:** POST
- **Path:** /api/v1/sharing/upload
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "capture_id": "uuid-string", "expiry_hours": 72 | null, "password": "optional-password" | null }
- **Response:** { "capture_id": "uuid", "share_url": "https://storage.example.com/s/abc123", "expiry": "2026-03-08T10:30:00Z", "encrypted": true }
- **Errors:** 400 Bad Request — invalid capture_id, 401 Unauthorized, 403 Forbidden — sharing mode is LocalOnly, 404 Not Found — capture not found, 502 Bad Gateway — storage backend unreachable

### HTTP Bridge — List AI Models
- **Method:** GET
- **Path:** /api/v1/ai/models
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** No body. Optional query param ?provider=coreml|mlx|ollama
- **Response:** { "models": [{ "id": "uuid", "name": "SnapForge-Vision-v1", "provider_type": "coreml", "file_size_bytes": 45000000, "version": "1.0", "capabilities": ["ocr", "region_detection", "explain"], "is_loaded": true, "is_bundled": true }, { "id": "uuid", "name": "llama-3.2-3b-q4", "provider_type": "mlx", "file_size_bytes": 1800000000, "version": "3.2", "capabilities": ["explain", "annotate"], "is_loaded": false, "is_bundled": false, "download_status": "available" }] }
- **Errors:** 401 Unauthorized

### HTTP Bridge — Download AI Model
- **Method:** POST
- **Path:** /api/v1/ai/models/download
- **Auth:** Bearer token from Keychain (X-SnapForge-Token header)
- **Request:** { "model_id": "uuid-string" }
- **Response:** SSE stream: data: { "model_id": "uuid", "status": "downloading", "progress": 0.45, "bytes_downloaded": 810000000, "bytes_total": 1800000000 } ... data: { "model_id": "uuid", "status": "completed", "progress": 1.0 }
- **Errors:** 400 Bad Request — invalid model_id, 401 Unauthorized, 404 Not Found — model not found in registry, 409 Conflict — download already in progress, 507 Insufficient Storage — not enough disk space

### x-callback-url — Capture
- **Method:** URL_SCHEME
- **Path:** snapforge://x-callback-url/capture?type={type}&region={x,y,w,h}&delay={seconds}
- **Auth:** None (local URL scheme, same-machine only)
- **Request:** URL parameters: type (required), region (optional comma-separated x,y,w,h), delay (optional integer seconds). x-success and x-error callback URLs supported.
- **Response:** On success: redirects to x-success URL with ?capture_id={uuid}&file_path={path}. Without x-success: opens capture in post-capture action bar.
- **Errors:** x-error callback with ?error=invalid_type, x-error callback with ?error=permission_denied, x-error callback with ?error=capture_in_progress

### x-callback-url — Search Library
- **Method:** URL_SCHEME
- **Path:** snapforge://x-callback-url/library/search?q={query}&type={type}&limit={limit}
- **Auth:** None (local URL scheme)
- **Request:** URL parameters: q (required search text), type (optional filter), limit (optional, default 10).
- **Response:** On success: redirects to x-success URL with ?results={json-encoded-array-of-capture-ids}. Without x-success: opens library view with search results.
- **Errors:** x-error callback with ?error=invalid_query

### AppIntents — CaptureScreenshotIntent
- **Method:** APP_INTENT
- **Path:** com.snapforge.intents.CaptureScreenshot
- **Auth:** System Shortcuts permission grant
- **Request:** Parameters: region (optional IntentRegion), delay (optional IntentDuration), postAction (optional enum: copy, save, annotate, pin)
- **Response:** Returns IntentFile with captured image and IntentCaptureResult with capture_id, file_path, timestamp
- **Errors:** Screen recording permission not granted, Capture failed — returns IntentError with localizedDescription

### AppIntents — SearchLibraryIntent
- **Method:** APP_INTENT
- **Path:** com.snapforge.intents.SearchLibrary
- **Auth:** System Shortcuts permission grant
- **Request:** Parameters: query (required String), captureType (optional enum), limit (optional Int, default 10)
- **Response:** Returns [IntentCaptureResult] array with matching capture IDs, thumbnails, and OCR snippets
- **Errors:** No results found — returns empty array, not an error

### AppIntents — ExplainScreenshotIntent
- **Method:** APP_INTENT
- **Path:** com.snapforge.intents.ExplainScreenshot
- **Auth:** System Shortcuts permission grant
- **Request:** Parameters: captureID (required String UUID), customPrompt (optional String)
- **Response:** Returns IntentExplanation with explanation text, provider used, token count
- **Errors:** Capture not found — IntentError, AI model not available — IntentError with suggestion to check model settings

### Plugin Protocol — SendToPlugin
- **Method:** SWIFT_PROTOCOL
- **Path:** protocol SendToPlugin: Sendable
- **Auth:** Plugin-managed. Each plugin stores its own auth tokens in Keychain under a namespaced key.
- **Request:** func authenticate() async throws -> Bool; func upload(capture: CaptureData) async throws -> PluginUploadResult; func validate() async -> PluginStatus
- **Response:** PluginUploadResult { url: URL?, message: String, success: Bool }. PluginStatus { isConfigured: Bool, isAuthenticated: Bool, displayName: String, iconName: String }
- **Errors:** PluginError.authenticationFailed, PluginError.uploadFailed(reason: String), PluginError.networkUnavailable, PluginError.rateLimited(retryAfter: TimeInterval)

## 🧱 Modules
### CaptureEngine
- **Responsibilities:**
- Wrap ScreenCaptureKit for all capture types: screenshot, scrolling, video, GIF, timed, OCR, pin
- Manage SCStream lifecycle including creation, configuration, start, stop, and error recovery
- Provide real-time region selection overlay with pixel snapping, spacing hints, and UI element boundary detection
- Output raw capture data as SendableImage for screenshots or AsyncStream<CMSampleBuffer> for recordings
- Serialize capture state transitions via actor isolation to prevent concurrent capture conflicts
- Detect source app bundle ID and window title at capture time via CGWindowListCopyWindowInfo
- Extract source domain from browser window titles using regex patterns for Safari, Chrome, Firefox, Arc
- **Interfaces:**
- protocol CaptureServiceProtocol: Sendable — func captureScreenshot(region: CGRect?) async throws -> CaptureResult
- func captureScrolling(region: CGRect, scrollBehavior: ScrollBehavior) async throws -> CaptureResult
- func startRecording(config: RecordingConfig) async throws -> RecordingSession
- func stopRecording(session: RecordingSession, trim: TrimRange?) async throws -> CaptureResult
- func captureOCRRegion(region: CGRect?) async throws -> CaptureResult
- func pinCapture(region: CGRect) async throws -> PinSession
- var captureState: CaptureState { get } — enum CaptureState: Sendable { case idle, selecting(CaptureType), capturing, processing, completed(CaptureResult), error(CaptureError) }
- var stateStream: AsyncStream<CaptureState> { get }

### AIEngine
- **Responsibilities:**
- Define unified InferenceProvider protocol for all AI backends with AsyncThrowingStream<String, Error> return type
- Implement CoreMLProvider using Apple Vision framework for OCR and VNRecognizeTextRequest, plus Core ML models for region detection and screenshot explanation
- Implement MLXProvider wrapping MLX Swift for local LLM inference with GGUF and SafeTensors model format support
- Implement OllamaProvider as HTTP client to localhost Ollama server with streaming JSON response parsing
- Implement CloudAPIProvider for OpenAI and Anthropic REST APIs with SSE streaming response parsing
- Manage model loading, unloading, and GPU memory via ModelManagerService actor
- Store and manage prompt templates and conversation history via PromptStorageService
- Perform smart region detection by running Vision framework saliency analysis and Core ML UI element classifier
- Generate AI annotation presets by identifying key UI areas and suggesting highlight regions
- Count tokens per provider: BPE tokenizer for cloud APIs, character-based estimation for Core ML, MLX tokenizer for local LLMs
- Manage context windows: 4096 tokens for Core ML vision models, configurable for MLX (2048-8192), provider-defined for cloud APIs
- Detect GPU capabilities via Metal device properties (recommendedMaxWorkingSetSize, maxTransferRate) and fall back to CPU for Intel Macs without sufficient Metal support
- **Interfaces:**
- protocol InferenceProvider: Sendable — func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error>
- func detectRegions(in image: CGImage) async throws -> [DetectedRegion]
- func performOCR(on image: CGImage) async throws -> OCRResult
- func explainScreenshot(captureID: UUID, prompt: String?) -> AsyncThrowingStream<String, Error>
- func suggestAnnotations(for image: CGImage) async throws -> [AnnotationSuggestion]
- protocol ModelManagerProtocol: Sendable — func loadModel(id: UUID) async throws
- func unloadModel(id: UUID) async throws
- func downloadModel(id: UUID) -> AsyncThrowingStream<DownloadProgress, Error>
- var availableModels: [AIModelInfo] { get async }
- var loadedModels: [AIModelInfo] { get async }
- func estimateTokenCount(text: String, provider: ProviderType) -> Int
- func contextWindowSize(for provider: ProviderType) -> Int
- **Dependencies:**
- LibraryStore

### LibraryStore
- **Responsibilities:**
- Manage SwiftData ModelContainer and model context for all CaptureRecord CRUD operations
- Maintain parallel SQLite FTS5 index for OCR text with automatic index updates on capture insert/update/delete
- Execute full-text search queries across OCR text with relevance ranking via FTS5 rank function
- Provide filtered queries by capture type, source app, domain, date range, and tags
- Calculate storage usage per capture type and total, supporting the storage usage dashboard
- Execute auto-cleanup rules: delete captures older than N days, exceeding total size limit, or matching tag/type filters
- Run background OCR indexing as throttled TaskGroup (max 2 concurrent) after each new capture
- Generate and cache thumbnails for captures at configurable sizes
- Support pagination via FetchDescriptor with fetchLimit and fetchOffset for large libraries
- **Interfaces:**
- protocol LibraryServiceProtocol: Sendable — func save(capture: CaptureResult, ocrText: String?) async throws -> UUID
- func search(query: String, filters: LibraryFilters, sort: SortOrder, limit: Int, offset: Int) async throws -> SearchResults
- func fetch(id: UUID) async throws -> CaptureRecord
- func delete(id: UUID, deleteFile: Bool) async throws
- func updateTags(id: UUID, tags: [String]) async throws
- func storageUsage() async -> StorageUsageReport
- func runCleanup(rules: [CleanupRule]) async throws -> CleanupResult
- func allTags() async -> [TagUsage]
- func reindexOCR() async throws — rebuilds FTS5 index from all CaptureRecord ocrText fields

### SharingService
- **Responsibilities:**
- Enforce privacy mode (LocalOnly, Upload, AskEveryTime) before any upload operation
- E2E encrypt capture files using CryptoKit AES-256-GCM with key derived from user passphrase via HKDF
- Upload encrypted blobs to user-configured S3-compatible storage backend via AWS SDK for Swift or raw HTTP
- Generate shareable links with optional expiry and password protection
- Manage upload queue with automatic retry (exponential backoff, max 3 retries)
- Store encryption keys in Keychain, never transmit passphrase
- Provide clear offline error states when storage backend is unreachable
- Track sharing status per capture (local, uploaded, expired, deleted) in LibraryStore
- **Interfaces:**
- protocol SharingServiceProtocol: Sendable — func upload(captureID: UUID, expiry: TimeInterval?, password: String?) async throws -> ShareResult
- func deleteRemote(captureID: UUID) async throws
- func currentPrivacyMode() -> PrivacyMode
- func setPrivacyMode(_ mode: PrivacyMode) async
- func configureStorage(endpoint: URL, accessKey: String, secretKey: String, bucket: String) async throws
- func testStorageConnection() async throws -> Bool
- var uploadQueue: AsyncStream<UploadQueueEvent> { get }
- **Dependencies:**
- LibraryStore

### AutomationBridge
- **Responsibilities:**
- Register and handle all AppIntents for Shortcuts integration (one AppIntent struct per capture type and post-action)
- Parse x-callback-url schemes (snapforge://) via URLRouter mapping paths to service method calls
- Run local HTTP bridge API on localhost:48721 using NWListener with JSON request/response routing
- Generate and store bearer token in Keychain on first launch for HTTP API authentication
- Manage plugin lifecycle: discover, load, validate, and invoke SendToPlugin conforming types from plugins directory
- Route automation requests to appropriate services (CaptureEngine, LibraryStore, AIEngine, SharingService)
- **Interfaces:**
- protocol AutomationBridgeProtocol: Sendable — func startHTTPServer() async throws
- func stopHTTPServer() async
- func handleURL(_ url: URL) async -> URLHandlerResult
- func registerPlugins() async throws
- func availablePlugins() async -> [PluginInfo]
- func invokePlugin(name: String, capture: CaptureData) async throws -> PluginUploadResult
- var httpServerStatus: ServerStatus { get }
- **Dependencies:**
- CaptureEngine
- LibraryStore
- AIEngine
- SharingService

### CommonUI
- **Responsibilities:**
- Provide command palette view as floating NSPanel with radial layout for capture type selection
- Provide post-capture action bar as HUD-style NSWindow with fixed button order (Annotate, Copy, Save, Cloud, Background, Pin, Delete)
- Manage per-mode action memory and Enter-to-repeat behavior in action bar
- Provide annotation tool views (arrow, rectangle, oval, text, blur, highlight, numbering, crop) with CALayer compositing
- Implement undo/redo command pattern stack for annotation operations
- Provide library browser view with sidebar navigation (capture types, tags, smart filters)
- Implement progressive disclosure UI: collapsible advanced drawer, first-run guided tour, weekly tips with Show Me buttons
- Manage WindowManager for coordinating NSWindow/NSPanel presentation and dismissal with Structured Concurrency
- Ensure full VoiceOver accessibility labels on all interactive elements
- Implement complete keyboard navigation for all workflows including arrow key navigation in overlays
- **Interfaces:**
- CommandPaletteView — SwiftUI View presented via NSPanel
- PostCaptureActionBar — SwiftUI View presented via HUD NSWindow, binds to CaptureResult
- AnnotationCanvas — SwiftUI View with CALayer-backed tool rendering
- LibraryBrowserView — SwiftUI View with sidebar NavigationSplitView
- ProgressiveDisclosureManager — @Observable class tracking tour state, seen tips, drawer expansion
- WindowManager — actor managing NSWindow lifecycle with async present/dismiss methods
- protocol AnnotationToolProtocol — func apply(to canvas: AnnotationCanvas, at point: CGPoint)
- struct ActionMemory: Codable — stores last action per CaptureType in UserDefaults
- **Dependencies:**
- CaptureEngine
- AIEngine
- LibraryStore
- SharingService

### RecordingPipeline
- **Responsibilities:**
- Manage Metal-accelerated video and GIF recording using ScreenCaptureKit + AVFoundation + Metal
- Process frames via Metal compute shaders for real-time effects (blur regions, annotations overlay)
- Support configurable FPS (15, 24, 30, 60), resolution scaling (0.5x, 1x, 2x), codec (H.264, H.265, ProRes), and bitrate
- Monitor CPU/GPU usage via IOKit counters and expose real-time metrics via TimelineView-compatible stream
- Automatically adjust recording quality (reduce FPS, lower resolution) when CPU exceeds 15% overhead threshold
- Output to AVAssetWriter with support for post-recording trimming
- Convert video to GIF using Metal-accelerated frame extraction and palette quantization
- **Interfaces:**
- protocol RecordingPipelineProtocol: Sendable — func configure(_ config: RecordingConfig) async throws
- func startPipeline(stream: SCStream) async throws
- func stopPipeline() async throws -> URL
- func trim(file: URL, range: TrimRange) async throws -> URL
- func convertToGIF(file: URL, config: GIFConfig) async throws -> URL
- var metrics: AsyncStream<RecordingMetrics> { get } — RecordingMetrics { cpuUsage: Double, gpuUsage: Double, fps: Double, duration: TimeInterval, frameCount: Int }
- var qualityAdjustments: AsyncStream<QualityAdjustmentEvent> { get }
- **Dependencies:**
- CaptureEngine

### AppServices
- **Responsibilities:**
- Central actor managing service lifecycle, initialization order, and dependency injection
- Create and hold references to all service actors (CaptureService, AIInferenceService, ModelManagerService, LibraryService, SharingService, AutomationBridgeService, RecordingPipelineService, PreferencesService, PromptStorageService)
- Initialize services in correct dependency order: PreferencesService → LibraryStore → CaptureEngine → AIEngine → SharingService → AutomationBridge → RecordingPipeline
- Provide typed access to each service for SwiftUI views via @Environment
- Manage app lifecycle events (launch, activate, terminate, sleep, wake) and propagate to services
- **Interfaces:**
- actor AppServices — var captureService: CaptureServiceProtocol { get }
- var aiService: AIInferenceServiceProtocol { get }
- var libraryService: LibraryServiceProtocol { get }
- var sharingService: SharingServiceProtocol { get }
- var automationBridge: AutomationBridgeProtocol { get }
- var recordingPipeline: RecordingPipelineProtocol { get }
- var preferences: PreferencesServiceProtocol { get }
- func initialize() async throws
- func shutdown() async
- **Dependencies:**
- CaptureEngine
- AIEngine
- LibraryStore
- SharingService
- AutomationBridge
- CommonUI
- RecordingPipeline

## 🗃 Data Model Notes
- CaptureRecord (SwiftData @Model): id: UUID, timestamp: Date, captureType: CaptureType (enum: screenshot, scrolling, video, gif, ocr, pin), sourceAppBundleID: String?, sourceAppName: String?, sourceDomain: String?, filePath: String, thumbnailPath: String?, ocrText: String?, tags: String (comma-separated), annotationsJSON: Data?, sharingStatus: SharingStatus (enum: local, uploaded, expired, deleted), shareURL: String?, fileSize: Int64, width: Int?, height: Int?, duration: Double? (for video/gif)

- ConversationEntry (SwiftData @Model): id: UUID, captureRecordID: UUID, prompt: String, response: String, provider: String (coreml|mlx|ollama|openai|anthropic), tokenCount: Int, latencyMS: Int, timestamp: Date. Relationship: many-to-one with CaptureRecord via captureRecordID. No cascade delete — orphaned entries cleaned up by auto-cleanup rules.

- PromptTemplate (SwiftData @Model): id: UUID, name: String, template: String (supports {{image}} and {{ocr_text}} placeholders), category: PromptCategory (enum: explain, annotate, summarize, custom), usageCount: Int, averageLatencyMS: Int, createdAt: Date, updatedAt: Date

- AIModel (SwiftData @Model): id: UUID, name: String, providerType: ProviderType (enum: coreml, mlx, ollama, openai, anthropic), filePath: String?, fileSize: Int64, version: String, capabilities: String (comma-separated: ocr, region_detection, explain, annotate), isLoaded: Bool, isBundled: Bool, format: ModelFormat (enum: mlmodelc, gguf, mlx_safetensors, cloud_api), quantization: String? (e.g. q4_k_m, q8_0), contextWindowSize: Int, downloadStatus: DownloadStatus (enum: notDownloaded, downloading, downloaded, failed)

- PluginConfig (SwiftData @Model): id: UUID, name: String, bundlePath: String, isEnabled: Bool, authTokenKeychainKey: String?, lastUsed: Date?, displayName: String, iconSystemName: String

- FTS5 Index (raw SQLite, separate from SwiftData): CREATE VIRTUAL TABLE capture_fts USING fts5(capture_id UNINDEXED, ocr_text, tags, source_app_name, content='', contentless_delete=1). Populated via triggers on CaptureRecord insert/update/delete. Queried via: SELECT capture_id, rank FROM capture_fts WHERE capture_fts MATCH ? ORDER BY rank

- Schema versioning: SnapForgeSchemaV1 as initial schema. SchemaMigrationPlan with ordered stages. FTS5 index versioned separately with INTEGER version table and migration SQL scripts at app launch. All migrations additive only — new columns with defaults, new tables. No destructive migrations.

- Tags stored as comma-separated String on CaptureRecord for simplicity. Queried via FTS5 for search, LIKE for filtering. No normalized Tag entity — accepted tradeoff for simpler schema and faster writes.

- Annotations serialized as JSON Data on CaptureRecord. JSON schema: [{ "type": "arrow|rect|oval|text|blur|highlight|number|crop", "origin": {"x": 0, "y": 0}, "size": {"w": 100, "h": 50}, "color": "#FF0000", "strokeWidth": 2, "text": "optional", "number": 1 }]. Deserialized into [AnnotationElement] structs in AnnotationService.

- File storage layout: ~/Library/Application Support/SnapForge/Captures/{YYYY}/{MM}/{uuid}.{png|mov|gif}. Thumbnails: ~/Library/Application Support/SnapForge/Thumbnails/{uuid}_thumb.png. AI Models: ~/Library/Application Support/SnapForge/Models/{provider}/{model-name}/. Plugins: ~/Library/Application Support/SnapForge/Plugins/{plugin-name}.bundle

## 🔐 Validation & Security
- HTTP bridge bearer token: 256-bit random token generated via SecRandomCopyBytes on first launch, stored in Keychain under service 'com.snapforge.http-bridge'. Validated on every HTTP request. Token rotation via preferences UI regenerates and stores new token.
- E2E encryption for cloud uploads: AES-256-GCM via CryptoKit. Encryption key derived from user passphrase using HKDF-SHA256 with app-specific salt stored in Keychain. Passphrase never stored — derived key cached in memory only during active session. Each upload gets a unique 96-bit nonce. Encrypted blob format: [12-byte nonce][ciphertext][16-byte GCM tag].
- S3 storage credentials (access key, secret key, endpoint) stored in Keychain under service 'com.snapforge.storage'. Never written to UserDefaults or plist files.
- Plugin authentication tokens stored in Keychain under namespaced keys: 'com.snapforge.plugin.{plugin-name}'. Plugins cannot access other plugins' tokens.
- ScreenCaptureKit permission: check CGPreflightScreenCaptureAccess() on launch, prompt via CGRequestScreenCaptureAccess() if needed. Show clear permission explanation UI before system prompt. Gracefully disable capture features if denied.
- Input validation on HTTP bridge: all JSON request bodies validated against expected schema before processing. Region bounds clamped to screen dimensions. String inputs sanitized — no shell execution or file path traversal. Maximum request body size 10MB to prevent memory exhaustion.
- FTS5 query input sanitized to prevent FTS5 syntax injection. User search queries wrapped in double quotes for phrase matching, special characters escaped. Raw FTS5 syntax only available via HTTP bridge API for automation use cases.
- Sandbox considerations: app targets Mac App Store distribution with App Sandbox. File access via security-scoped bookmarks for user-chosen storage locations. Temporary capture files written to app container before moving to user-visible location.
- Privacy mode enforcement: SharingService checks PrivacyMode before any upload. LocalOnly mode physically prevents network calls in upload path. AskEveryTime mode presents confirmation dialog with capture preview before upload. No implicit uploads anywhere in codebase.
- Model download integrity: downloaded AI models verified via SHA-256 checksum against manifest before loading. Corrupted downloads automatically deleted and retried.

## 🧯 Error Handling Strategy
All services use Swift typed throws with domain-specific error enums conforming to LocalizedError and Sendable. Error enums: CaptureError (permissionDenied, regionInvalid, alreadyInProgress, screenCaptureKitFailure(SCStream.Error)), AIError (modelNotLoaded, providerUnavailable, inferenceTimeout, contextWindowExceeded, downloadFailed, gpuMemoryInsufficient), LibraryError (captureNotFound, ftsIndexCorrupted, storageQuotaExceeded, migrationFailed), SharingError (privacyModeBlocked, encryptionFailed, storageBucketUnreachable, uploadFailed(retryCount: Int), offlineMode), AutomationError (invalidRoute, authenticationFailed, pluginNotFound, pluginError(String)), RecordingError (codecUnsupported, metalDeviceUnavailable, encodingFailed, diskSpaceInsufficient). Services never throw raw Swift.Error — always domain-specific. UI layer maps errors to user-facing messages via LocalizedError.errorDescription. Background tasks (OCR indexing, model loading) log errors and surface them as non-blocking notifications in the menu bar status area. Critical errors (ScreenCaptureKit permission revoked, SwiftData migration failure) present modal alerts. HTTP bridge returns appropriate HTTP status codes mapped from service errors. Retry logic: network operations (cloud upload, model download, Ollama HTTP) retry 3 times with exponential backoff (1s, 2s, 4s). Non-retryable errors (permission denied, invalid input) fail immediately.

## 🔭 Observability
- **Logging:** Swift os.Logger with subsystem 'com.snapforge' and per-module categories (capture, ai, library, sharing, automation, recording, pipeline). Log levels: .debug for internal state transitions, .info for user-initiated actions and service lifecycle, .error for recoverable failures, .fault for unrecoverable state corruption. Structured logging with OSLogMessage interpolation for privacy-safe metadata (capture IDs as .public, file paths as .private, OCR text as .private). Logger instances are static properties on each service actor. No third-party logging frameworks.
- **Tracing:** No distributed tracing (local-only app). Operation correlation via UUID-based operation IDs passed through service calls. Each user-initiated action (capture, search, AI explain, upload) generates a unique operationID: UUID that appears in all related log messages across services. The HTTP bridge includes operationID in response headers (X-SnapForge-Operation-ID) for automation debugging. Long-running operations (recording, model download) log periodic heartbeat messages at .debug level with elapsed time and progress.
- **Metrics:**
- Capture latency: time from shortcut keypress (CGEvent timestamp) to region selection overlay first frame render — target <100ms, logged at .info level
- FTS5 search latency: time from query submission to result set return — target <200ms for 10k+ records, logged at .info level
- AI inference latency: time from prompt submission to first token and to completion — logged per provider at .info level with token count
- Recording CPU overhead: IOKit-sourced CPU percentage during recording — logged every 5 seconds at .debug level, logged at .error if exceeds 15%
- Recording GPU usage: Metal device utilization during recording — logged every 5 seconds at .debug level
- Model load time: time from loadModel call to model ready for inference — logged at .info level with model size
- Model GPU memory: Metal recommendedMaxWorkingSetSize usage before and after model load — logged at .info level
- Upload latency: time from upload initiation to share link generation — logged at .info level
- Library size: total capture count and storage bytes — logged at .info level on app launch and after cleanup
- OCR indexing throughput: captures indexed per second during background indexing — logged at .debug level

## ⚡ Performance Notes
- Capture overlay latency: NSPanel with SwiftUI content hosted via NSHostingView must appear within 100ms of shortcut press. Pre-create the NSPanel at app launch and toggle visibility rather than creating new windows. Use CAMetalLayer for region selection overlay rendering to bypass SwiftUI layout overhead during drag.
- FTS5 query performance: SQLite PRAGMA settings at database open — journal_mode=WAL, mmap_size=268435456 (256MB), cache_size=-64000 (64MB). FTS5 contentless table with contentless_delete=1 to avoid storing duplicate text. Queries use LIMIT and OFFSET for pagination. Prefix queries (e.g. 'err*') supported via FTS5 prefix option set to '2,3,4' at table creation.
- AI model memory management: ModelManagerService tracks loaded model memory footprint. On Apple Silicon, query Metal device recommendedMaxWorkingSetSize to determine available GPU memory. Load at most one large model (>500MB) at a time. Unload after configurable idle timeout (default 5 minutes). Core ML vision models (<50MB) stay loaded permanently. MLX models loaded via mmap for lazy page-in.
- GPU fallback logic: Check MTLDevice.supportsFamily(.apple7) for Apple Silicon Neural Engine access. For Intel Macs, fall back to CPU-only Core ML inference (slower but functional). MLX provider requires Apple Silicon — disabled on Intel with clear UI message. Ollama and cloud providers work on any hardware.
- Recording pipeline: Metal compute shaders for frame processing run on a dedicated MTLCommandQueue separate from UI rendering. AVAssetWriter configured with AVVideoCodecType.hevc and hardware-accelerated encoding on Apple Silicon. Frame dropping strategy: if encode queue exceeds 3 frames behind, drop oldest unprocessed frame and log at .debug level. GIF conversion uses temporal dithering via Metal shader for quality at small file sizes.
- OCR background indexing: TaskGroup limited to 2 concurrent VNRecognizeTextRequest operations. Each OCR task runs on .userInitiated QoS to yield to capture operations on .userInteractive. Indexing paused automatically during active recording (checked via CaptureService.captureState).
- SwiftData query optimization: FetchDescriptor with explicit propertiesToFetch for list views (only id, timestamp, thumbnailPath, tags, captureType) to avoid loading full ocrText and annotationsJSON. Relationship faulting for ConversationEntry — only fetched on capture detail view.
- Thumbnail caching: thumbnails generated at 256x256 on capture save and cached to disk. LibraryBrowserView uses AsyncImage with a custom NSCache-backed ImageLoader (max 200 thumbnails in memory, LRU eviction).
- HTTP bridge server: NWListener on localhost only, no TLS needed (loopback is secure). Connection handling via Structured Concurrency — each request spawns a child task in a TaskGroup with max 10 concurrent connections. Request timeout 30 seconds. Response streaming for SSE endpoints (AI explain, model download) via AsyncStream bridged to NWConnection.send.

## 🧪 Testing Strategy
### Unit
- CaptureEngine: test capture state machine transitions (idle → selecting → capturing → completed, idle → selecting → error). Mock SCStream via protocol wrapper to verify SCStreamConfiguration is built correctly for each capture type. Test region snapping math with edge cases (zero-size region, region exceeding screen bounds, multi-display regions).
- AIEngine: test InferenceProvider protocol with mock providers returning canned AsyncThrowingStream responses. Test CoreMLProvider OCR accuracy against known test images with expected text. Test token counting functions for each provider type. Test ModelManagerService load/unload state transitions with mock model files. Test prompt template placeholder substitution ({{image}}, {{ocr_text}}).
- LibraryStore: test CaptureRecord CRUD via in-memory SwiftData ModelContainer. Test FTS5 index insert, update, delete, and search with known OCR text. Test search ranking with multiple matches. Test auto-cleanup rule execution (age-based, size-based, tag-based). Test storage usage calculation. Test tag parsing from comma-separated string.
- SharingService: test privacy mode enforcement — verify LocalOnly mode throws on upload attempt. Test E2E encryption roundtrip (encrypt then decrypt, verify plaintext match). Test upload queue retry logic with mock network failures. Test share link generation with expiry calculation.
- AutomationBridge: test URL scheme parsing for all x-callback-url routes with valid and malformed URLs. Test HTTP route matching for all REST endpoints. Test bearer token validation (valid, missing, expired). Test plugin protocol validation with mock SendToPlugin implementations.
- RecordingPipeline: test recording configuration validation (invalid FPS, unsupported codec). Test quality auto-adjustment logic with simulated CPU metrics above threshold. Test trim range validation (start >= end, negative values, exceeding duration).
- CommonUI: test ActionMemory persistence (save last action per capture type, retrieve correctly). Test ProgressiveDisclosureManager state transitions (tour completion, tip dismissal). Test AnnotationService undo/redo stack with command pattern.
### Integration
- CaptureEngine + LibraryStore: capture a screenshot via CaptureService, verify CaptureRecord is persisted in SwiftData with correct metadata (timestamp, file path, source app), verify file exists on disk, verify thumbnail is generated.
- CaptureEngine + AIEngine + LibraryStore: capture screenshot, run OCR via AIInferenceService, verify OCR text is stored on CaptureRecord, verify FTS5 index is updated and searchable.
- AIEngine + LibraryStore: run Explain Screenshot on a stored capture, verify ConversationEntry is created with correct captureRecordID, prompt, response, provider, and latency.
- SharingService + LibraryStore: upload a capture, verify CaptureRecord sharingStatus updates to .uploaded, verify shareURL is populated. Test with mock S3 endpoint.
- AutomationBridge + CaptureEngine: send HTTP POST to /api/v1/capture, verify CaptureService is invoked and returns valid CaptureResult. Test x-callback-url scheme triggers capture and returns capture_id.
- AutomationBridge + LibraryStore: send HTTP GET to /api/v1/library/search, verify FTS5 search is executed and results match expected captures.
- RecordingPipeline + CaptureEngine: start recording via CaptureService, record 3 seconds, stop, verify output file exists with expected codec and approximate duration.
- Full post-capture flow: capture → OCR index → AI explain → annotate → save → verify all data persisted correctly in SwiftData and FTS5.
### E2E
- Command palette launch: simulate global keyboard shortcut, verify command palette NSPanel appears within 200ms, verify all capture types are listed, select screenshot, verify region selection overlay appears.
- Full capture-to-share workflow: trigger screenshot via command palette → select region → verify post-capture action bar appears with all 7 buttons in correct order → click Cloud → verify privacy mode check → confirm upload → verify share URL is generated and copied to clipboard.
- Library search: create 100 test captures with known OCR text → open library view → type search query → verify results appear within 200ms → verify results are correctly ranked by relevance → verify filters (type, date, tag) narrow results correctly.
- AI Explain Screenshot: capture a screenshot of a known UI → invoke Explain Screenshot → verify streaming text appears in UI → verify final explanation is coherent and stored in ConversationEntry.
- Keyboard-only workflow: complete full capture → annotate → save workflow using only keyboard (Tab, arrow keys, Enter, Escape). Verify focus ring is visible on all interactive elements. Verify VoiceOver announces all actions.
- Automation HTTP bridge: start app → verify HTTP server is listening on localhost:48721 → send authenticated requests to all REST endpoints → verify correct responses. Test with invalid token → verify 401 response.
- Recording with quality adjustment: start screen recording → simulate high CPU load → verify quality auto-adjusts (FPS drops or resolution decreases) → verify real-time metrics update in UI → stop recording → verify output file is valid.
- Offline resilience: disable network → attempt cloud upload → verify clear error message → verify capture is queued for retry → re-enable network → verify upload completes automatically.
- Plugin integration: install test SendToPlugin → capture screenshot → select Send To from action bar → verify plugin appears in list → invoke plugin → verify plugin receives capture data and returns result.

## 🚀 Rollout Plan
- Phase 1 — Core Capture (Weeks 1-4): Implement CaptureEngine with ScreenCaptureKit for screenshot and region capture. Build command palette NSPanel with capture type selection. Build post-capture action bar with Copy, Save, Delete actions. Implement basic LibraryStore with SwiftData CaptureRecord persistence. Set up AppServices actor and PreferencesService. Deliver: functional screenshot capture with keyboard shortcut, region selection, copy/save, and basic library list view.

- Phase 2 — Library & OCR (Weeks 5-8): Implement SQLite FTS5 index alongside SwiftData. Integrate Apple Vision framework OCR via CoreMLProvider. Build background OCR indexing pipeline with throttled TaskGroup. Build library browser view with search, filtering by type/date/app, and tag management. Implement storage usage dashboard and auto-cleanup rules. Deliver: searchable capture library with OCR text, tags, filters, and storage management.

- Phase 3 — Recording & Annotation (Weeks 9-12): Implement RecordingPipeline with Metal-accelerated encoding for video and GIF. Add scrolling capture to CaptureEngine. Build AnnotationService with full tool set (arrow, rect, oval, text, blur, highlight, numbering, crop). Implement undo/redo command stack. Add real-time recording metrics (CPU/GPU, FPS, duration) via TimelineView. Deliver: video/GIF recording with configurable quality, scrolling capture, and annotation tools.

- Phase 4 — AI Features (Weeks 13-16): Implement full AIEngine with pluggable InferenceProvider protocol. Build CoreMLProvider for smart region detection and Explain Screenshot. Implement MLXProvider for local LLM inference. Build ModelManagerService with download, cache, and GPU memory management. Implement AI annotation presets. Build PromptStorageService for template and conversation history. Deliver: on-device AI with smart regions, screenshot explanation, and model management UI.

- Phase 5 — Sharing & Privacy (Weeks 17-19): Implement SharingService with E2E encryption via CryptoKit. Build S3-compatible storage backend integration. Implement privacy mode toggle (Local/Upload/Ask). Build share link generation with expiry and password. Implement upload queue with retry logic. Deliver: encrypted cloud sharing with self-hosted storage support and explicit privacy controls.

- Phase 6 — Automation & Plugins (Weeks 20-22): Implement AutomationBridge with all AppIntents for Shortcuts. Build x-callback-url handler. Implement HTTP bridge API with NWListener on localhost. Build plugin system with SendToPlugin protocol. Implement reference plugins for Notion and Slack. Deliver: full automation surface with Shortcuts, URL scheme, HTTP API, and plugin system.

- Phase 7 — Polish & Accessibility (Weeks 23-25): Implement progressive disclosure UI with guided tour and weekly tips. Complete VoiceOver accessibility for all views. Complete keyboard navigation for all workflows. Performance optimization pass against NFR targets (100ms capture, 200ms search). Implement Ollama and cloud API providers. Deliver: accessible, polished app meeting all performance targets.

- Phase 8 — Distribution & Launch (Weeks 26-28): Set up CI/CD pipeline (Xcode Cloud or GitHub Actions). Configure notarization and Sparkle auto-update. Prepare Mac App Store submission. Write security documentation for E2E encryption. Final QA pass across Apple Silicon and Intel Macs. Deliver: shipped app via Mac App Store and direct download.

## ❓ Open Questions
- Core ML model selection: which specific pre-trained models to bundle for region detection and screenshot explanation? Options include MobileNetV3 for UI element classification and a fine-tuned vision-language model. Model size budget for the bundled app (target <100MB total for bundled models) needs final confirmation.
- MLX model format support scope: should we support both GGUF and SafeTensors format conversion at runtime, or require pre-converted MLX format only? Supporting both increases compatibility but adds ~2000 lines of conversion code.
- Self-hosted storage Docker image: is the Go/Swift minimal server in scope for v1, or should we launch with S3-compatible endpoint configuration only and ship the Docker image in a follow-up release?
- CloudKit sync scope: the ARD mentions optional CloudKit sync for CaptureRecord metadata. Should this be included in v1 or deferred? CloudKit adds entitlement complexity and iCloud account dependency.
- Plugin loading mechanism: should plugins be Swift packages compiled against a stable ABI and loaded via dlopen, or should they be script-based (AppleScript, JavaScript via JSContext) for easier third-party authoring? Swift packages offer type safety but require recompilation on SDK updates.
- Ollama provider: should we auto-detect a running Ollama instance on localhost:11434 and offer it as a provider, or require explicit configuration? Auto-detection improves UX but adds a background polling mechanism.
- Token counting accuracy: BPE tokenizer for OpenAI/Anthropic APIs adds a dependency (tiktoken or equivalent in Swift). Should we use exact tokenization or approximate by character count (÷4 rule) to keep dependencies at zero?
- FTS5 ranking: should search results use FTS5 built-in BM25 ranking only, or should we implement a custom ranking function that weighs recency, source app, and tag matches? Custom ranking improves relevance but adds query complexity.
- Intel Mac support priority: Core ML and Vision framework work on Intel, but MLX requires Apple Silicon. Should Intel support be first-class (all features work, just slower) or minimum-viable (capture and library work, AI features degraded/disabled)?
- Concurrent recording and capture: should users be able to take screenshots while a video recording is in progress? ScreenCaptureKit supports multiple SCStream instances but this doubles GPU memory usage during recording.