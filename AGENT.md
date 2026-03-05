# Agent Prompts — SnapForge

## Global Rules

### Do
- Use Swift 6 Structured Concurrency (async/await, actors, TaskGroup) for all concurrent work
- Use SwiftUI 6 with Observation framework (@Observable) for all view models and state
- Use SwiftData for persistence and SQLite FTS5 for full-text search via direct C API
- Make all service types actors conforming to Sendable; use AsyncStream/AsyncThrowingStream for event delivery
- Target macOS 15+ Sequoia with Apple Silicon primary, Intel CPU-only fallback

### Don't
- Do not introduce any server-side infrastructure, external databases, or non-Apple frameworks for core features
- Do not use ObservableObject/Combine/@Published — use Observation framework @Observable exclusively
- Do not substitute CoreML/Vision/Metal/ScreenCaptureKit with third-party alternatives
- Do not use UIKit or AppKit views where SwiftUI equivalents exist; use NSWindow/NSPanel only for HUD overlays
- Do not store API keys in UserDefaults or plain files — Keychain only via Security framework

---

## Task Prompts
### Task 1: AI Backend Abstraction Layer and Providers

**Role:** Expert Swift 6 Concurrency and CoreML Engineer
**Goal:** Create InferenceProvider protocol with CoreML, MLX, Ollama, and Cloud provider implementations returning streaming responses

**Context**
SnapForge routes all AI features (OCR, region detection, screenshot explanation, annotation suggestions) through a unified InferenceProvider protocol. This must be built first so capture engine and UI layers can consume any backend. Providers: CoreML+Vision (bundled), MLX Swift (Apple Silicon LLM), Ollama (localhost), OpenAI/Anthropic (cloud). All types must be Sendable. Streaming via AsyncThrowingStream<String, Error>.

**Files to Create**
- SnapForge/AI/InferenceProvider.swift
- SnapForge/AI/Types/InferenceContext.swift
- SnapForge/AI/Types/AIError.swift
- SnapForge/AI/Providers/CoreMLProvider.swift
- SnapForge/AI/Providers/MLXProvider.swift
- SnapForge/AI/Providers/OllamaProvider.swift
- SnapForge/AI/Providers/CloudAPIProvider.swift
- SnapForge/AI/Types/DetectedRegion.swift

**Files to Modify**
_None_

**Steps**
1. Define InferenceProvider protocol in InferenceProvider.swift with methods: generateStream(_:) -> AsyncThrowingStream<String, Error>, detectRegions(_:) -> [DetectedRegion], extractText(_:) -> OCRResult, suggestAnnotations(_:) -> [AnnotationSuggestion]. Add ProviderType enum (.coreml, .mlx, .ollama, .openai, .anthropic) and ProviderStatus enum. Define all associated types (InferenceContext, DetectedRegion, OCRResult, AnnotationSuggestion) as Sendable structs in the Types/ folder. Define AIError as enum with cases: modelNotLoaded, contextWindowExceeded, providerUnavailable, authenticationFailed, rateLimited, networkTimeout.
2. Implement CoreMLProvider actor conforming to InferenceProvider. Use VNRecognizeTextRequest with .accurate recognition level for extractText(). Use VNGenerateAttentionBasedSaliencyImageRequest for detectRegions() converting saliency heatmap to labeled bounding boxes with confidence > 0.3. For generateStream(), load a bundled Core ML vision model via MLModel(contentsOf:) and emit predictions token-by-token. Set computeUnits to .all on Apple Silicon, .cpuOnly on Intel via ProcessInfo check.
3. Implement MLXProvider actor wrapping MLX Swift framework. Load pre-converted SafeTensors models from ~/Library/Application Support/SnapForge/Models/mlx/. Implement generateStream() with configurable context window (2048-8192 tokens). Use MLX tokenizer for token counting. Guard init with #if arch(arm64) and throw providerUnavailable on Intel. Use mmap for lazy model page-in.
4. Implement OllamaProvider actor as localhost HTTP client to http://127.0.0.1:11434/api/generate. Parse streaming NDJSON responses into AsyncThrowingStream. Implement 3-retry exponential backoff (1s, 2s, 4s) with 30s total deadline. Throw providerUnavailable if connection refused. For detectRegions/extractText, send image as base64 with multimodal prompt.
5. Implement CloudAPIProvider actor supporting both OpenAI and Anthropic REST APIs. Read API keys from Keychain via Security framework SecItemCopyMatching. Parse SSE (text/event-stream) responses into AsyncThrowingStream. Handle 401 → authenticationFailed, 429 → rateLimited with Retry-After header parsing. Approximate token count as characterCount / 4.

**Validation**
`cd SnapForge && swift build 2>&1 | tail -20`

---

### Task 2: AI Model Manager and Hardware Detection

**Role:** Expert Swift 6 Actor and Metal GPU Memory Engineer
**Goal:** Build ModelManagerService actor with model download, GPU-aware loading, idle eviction, and SwiftData AIModel entity

**Context**
ModelManagerService actor handles model lifecycle: discovery, download with progress streaming, SHA-256 verification, GPU memory-aware loading (one large >500MB model at a time), idle timeout eviction (default 5min), and hardware capability detection. Core ML vision models (<50MB) stay permanently loaded. AIModel is a SwiftData @Model entity tracking all model metadata and download status.

**Files to Create**
- SnapForge/AI/ModelManager/ModelManagerService.swift
- SnapForge/AI/ModelManager/ModelManagerProtocol.swift
- SnapForge/AI/ModelManager/DownloadProgress.swift
- SnapForge/AI/ModelManager/HardwareCapabilities.swift
- SnapForge/AI/Models/AIModel.swift
- SnapForge/AI/ModelManager/ModelRegistry.swift

**Files to Modify**
- SnapForge/AI/InferenceProvider.swift

**Steps**
1. Define ModelManagerProtocol with methods: loadModel(_:) async throws, unloadModel(_:) async, downloadModel(_:) -> AsyncThrowingStream<DownloadProgress, Error>, availableModels() -> [AIModel], loadedModels() -> [AIModel]. Define DownloadProgress as Sendable struct with bytesDownloaded, bytesTotal, estimatedTimeRemaining. Define ModelState enum: notDownloaded, downloading(progress), downloaded, loading, loaded, unloading, error(String).
2. Implement ModelManagerService actor. Track loaded models in a dictionary [String: LoadedModel]. Query MTLCreateSystemDefaultDevice()!.recommendedMaxWorkingSetSize for GPU memory budget. Enforce one large model (>500MB) loaded at a time — unload existing before loading new. Keep Core ML vision models (<50MB, isBundled=true) permanently loaded. Log GPU memory at .info level via os.Logger before and after each load.
3. Add downloadModel() returning AsyncThrowingStream<DownloadProgress, Error>. Download to ~/Library/Application Support/SnapForge/Models/{provider}/. Use URLSession with delegate for progress tracking. Verify SHA-256 via CryptoKit SHA256.hash(data:) against manifest checksum. Delete file and throw integrityCheckFailed on mismatch. Throw insufficientStorage when FileManager availableCapacity < modelSize * 1.2.
4. Implement idle timeout eviction using a Task-based timer per loaded model. Default 5min from UserDefaults key modelIdleTimeout. Reset timer on each inference call via resetIdleTimer(modelId:). On timeout, call unloadModel() and log at .info. Cancel eviction task if new inference arrives during unload. Exempt isBundled models from eviction.
5. Create AIModel as @Model class for SwiftData with fields: id (UUID), name (String), providerType (ProviderType), modelPath (String), sizeBytes (Int64), isBundled (Bool), downloadStatus (ModelState), sha256Checksum (String?), contextWindowSize (Int), lastUsed (Date?). Build HardwareCapabilities struct querying MTLDevice.supportsFamily(.apple7), ProcessInfo.processInfo.processorCount, and arch(arm64). Log capabilities at launch.

**Validation**
`cd SnapForge && swift build 2>&1 | tail -20`

---

### Task 3: Core Capture Engine, Library, and OCR Pipeline

**Role:** Expert ScreenCaptureKit and AVFoundation Engineer
**Goal:** Build capture engine with ScreenCaptureKit, OCR-indexed SwiftData library with FTS5, and Metal recording pipeline

**Context**
CaptureEngine actor wraps ScreenCaptureKit SCStream for screenshot/region/video/GIF capture. LibraryService actor manages SwiftData CaptureRecord with parallel SQLite FTS5 index for full-text OCR search. Background OCR pipeline runs VNRecognizeTextRequest in throttled TaskGroup (max 2 concurrent). RecordingPipeline uses AVAssetWriter with Metal-accelerated encoding, configurable FPS/codec/bitrate, and auto-quality adjustment when CPU > 15%. AppServices actor initializes all services in dependency order.

**Files to Create**
- SnapForge/Capture/CaptureEngine.swift
- SnapForge/Capture/CaptureServiceProtocol.swift
- SnapForge/Library/LibraryService.swift
- SnapForge/Library/Models/CaptureRecord.swift
- SnapForge/Library/FTS5Index.swift
- SnapForge/Capture/RecordingPipeline.swift
- SnapForge/App/AppServices.swift
- SnapForge/Capture/OCRIndexer.swift

**Files to Modify**
_None_

**Steps**
1. Define CaptureServiceProtocol with CaptureState enum (idle, selecting, capturing, processing, completed, error) and methods: captureScreenshot(region:) async throws -> CaptureRecord, captureScrolling(window:) async throws -> CaptureRecord, startRecording(config:) async throws, stopRecording() async throws -> CaptureRecord, captureGIF(config:) async throws -> CaptureRecord. Implement CaptureEngine actor using SCStream and SCShareableContent.excludingDesktopWindows. Detect source app via CGWindowListCopyWindowInfo. Emit CaptureState via AsyncStream.
2. Create CaptureRecord @Model with: id (UUID), captureType (CaptureType enum), filePath (String), thumbnailPath (String?), ocrText (String?), sourceAppBundleID (String?), sourceAppName (String?), windowTitle (String?), tags ([String]), createdAt (Date), fileSize (Int64), dimensions (CGSize), isStarred (Bool). Build LibraryService actor with SwiftData ModelContainer (WAL mode). Create FTS5Index class using sqlite3 C API: CREATE VIRTUAL TABLE captures_fts USING fts5(ocr_text, tags, source_app, window_title). Sync inserts/updates/deletes with SwiftData.
3. Build OCRIndexer actor with processCapture(_ record: CaptureRecord) method. Run VNRecognizeTextRequest with .accurate level. Throttle via TaskGroup with maxConcurrentTasks: 2. Update CaptureRecord.ocrText and FTS5 index. Implement isPaused flag checked by RecordingPipeline — pause OCR during active recording. Add reindexAll() for recovery that drops and rebuilds FTS5 from all CaptureRecords.
4. Implement RecordingPipeline actor conforming to RecordingPipelineProtocol. Use AVAssetWriter with AVVideoCodecType (.h264, .hevc, .proRes422). Configure via RecordingConfig struct (fps: Int, codec, bitrate, maxDuration). Stream real-time RecordingMetrics (cpuUsage, gpuUsage, currentFPS, duration, fileSize) via AsyncStream. Query CPU via ProcessInfo, GPU via IOKit IOServiceGetMatchingService. Auto-reduce FPS by 50% when CPU > 15%. Add GIF conversion via AVAssetImageGenerator + CGImageDestination with temporal dithering.
5. Create AppServices actor as @Observable. Initialize services in order: HardwareCapabilities → LibraryService → CaptureEngine → OCRIndexer → ModelManagerService → SharingService → AutomationBridge. Inject via SwiftUI @Environment(\.appServices). Handle NSApplication lifecycle: applicationDidFinishLaunching seeds bundled models, applicationWillTerminate calls shutdown on all services, NSWorkspace.willSleepNotification pauses recording.

**Validation**
`cd SnapForge && swift build 2>&1 | tail -20`

---

### Task 4: Streaming AI UI, Prompts, and Conversation History

**Role:** Expert SwiftUI 6 and Observation Framework Engineer
**Goal:** Build streaming AI views, region detection overlay, prompt templates, and conversation history with SwiftData persistence

**Context**
Build SwiftUI views for streaming AI explain (token-by-token rendering), region detection overlay (labeled bounding boxes on capture), annotation suggestion panel, and AI provider picker. Create PromptTemplate and ConversationEntry SwiftData models with template CRUD service. Build conversation history UI in capture detail view and prompt template picker/editor with placeholder highlighting.

**Files to Create**
- SnapForge/UI/AI/ExplainStreamingView.swift
- SnapForge/UI/AI/RegionDetectionOverlay.swift
- SnapForge/UI/AI/AnnotationSuggestionPanel.swift
- SnapForge/UI/AI/AIProviderPicker.swift
- SnapForge/AI/Prompts/PromptTemplate.swift
- SnapForge/AI/Prompts/ConversationEntry.swift
- SnapForge/AI/Prompts/PromptStorageService.swift
- SnapForge/UI/AI/ConversationHistoryView.swift

**Files to Modify**
_None_

**Steps**
1. Build ExplainStreamingView as SwiftUI view subscribing to AsyncThrowingStream<String, Error>. Use @State var tokens: String appending each chunk. Show provider badge (Text with .caption style), elapsed time via TimelineView, and running token count. Add Cancel button calling task.cancel(). On error, display AIError.localizedDescription in red banner. Use .ultraThinMaterial background, matchedGeometryEffect for smooth appearance animation.
2. Build RegionDetectionOverlay as ZStack over capture image. Call detectRegions() on appear. Render each DetectedRegion as RoundedRectangle overlay with label (region.label) and confidence badge (region.confidence formatted as percentage). Use PhaseAnimator for fade-in. On click, set selectedRegion triggering crop/annotate mode. Dismiss on Escape via .onKeyPress(.escape). Re-run detection on model change.
3. Build AnnotationSuggestionPanel as VStack showing AI-suggested annotations as preview overlays. Each suggestion has Accept/Reject buttons. Accept All button applies all. Accepted suggestions convert to editable AnnotationObject structs. Panel uses .regularMaterial background. Build AIProviderPicker as Menu showing all providers from ModelManagerService.availableModels(). Show loaded/unloaded status, model name. Persist lastUsedProvider in UserDefaults. Trigger model load on selection of unloaded provider with ProgressView.
4. Create PromptTemplate @Model: id (UUID), name (String), template (String), category (String), usageCount (Int), createdAt (Date), isDefault (Bool). Create ConversationEntry @Model: id (UUID), captureRecordID (UUID), prompt (String), response (String), providerType (ProviderType), modelName (String), tokenCount (Int), timestamp (Date). Build PromptStorageService actor with CRUD, substitutePlaceholders replacing {{image}} and {{ocr_text}}, increment usageCount on use.
5. Build ConversationHistoryView as List within capture detail view. Each row shows prompt (truncated), response preview, provider badge, timestamp. Re-run button sends prompt to current provider, appends new ConversationEntry. New conversation TextField at bottom. Build PromptTemplatePicker as sheet with list of templates sorted by usageCount. Editor highlights {{image}} and {{ocr_text}} with AttributedString yellow background. Selected template fills explain prompt field.

**Validation**
`cd SnapForge && swift build 2>&1 | tail -20`

---

### Task 5: Sharing, Automation, Command Palette, and Library Browser

**Role:** Expert macOS AppKit Integration and Network Framework Engineer
**Goal:** Build E2E encrypted sharing, HTTP bridge API, command palette, Shortcuts intents, and library browser UI

**Context**
SharingService actor handles E2E encrypted (AES-256-GCM via CryptoKit) upload to S3-compatible endpoints with PrivacyMode enforcement. AutomationBridge provides localhost HTTP API on port 48721 via NWListener with bearer token auth, plus snapforge:// URL scheme. Command palette is floating NSPanel with radial layout. Post-capture action bar is HUD NSWindow with 7 fixed buttons. AppIntents for Shortcuts. Library browser is NavigationSplitView with FTS5 search and thumbnail grid.

**Files to Create**
- SnapForge/Sharing/SharingService.swift
- SnapForge/Automation/AutomationBridge.swift
- SnapForge/UI/CommandPalette/CommandPalettePanel.swift
- SnapForge/UI/PostCapture/ActionBarWindow.swift
- SnapForge/Automation/Intents/CaptureScreenshotIntent.swift
- SnapForge/UI/Library/LibraryBrowserView.swift
- SnapForge/Sharing/EncryptionService.swift
- SnapForge/Automation/Intents/SearchLibraryIntent.swift

**Files to Modify**
- SnapForge/App/AppServices.swift

**Steps**
1. Build EncryptionService with encrypt(data:) and decrypt(data:key:) using CryptoKit AES.GCM.seal/open with HKDF-derived key from SymmetricKey. Build SharingService actor with PrivacyMode enum (.localOnly, .upload, .askEveryTime) from UserDefaults. Throw privacyModeBlocked if .localOnly. Upload to S3-compatible endpoint via URLSession multipart PUT with encrypted payload. Retry 3 times (1s, 2s, 4s backoff). Generate share URL with optional expiry (TimeInterval) and password (String?).
2. Build AutomationBridge actor using Network.framework NWListener on port 48721. Generate bearer token via SecRandomCopyBytes stored in Keychain on first launch. Parse HTTP requests, validate Authorization: Bearer header (401 on mismatch). Route endpoints: POST /capture, GET /library/search, GET /capture/{id}, POST /capture/{id}/explain, DELETE /capture/{id}. Max 10 concurrent connections via DispatchSemaphore. Parse snapforge:// URL scheme via NSAppleEventManager for x-callback-url support.
3. Build CommandPalettePanel as NSPanel subclass with .nonactivatingPanel style, level .floating. SwiftUI hosting view with radial layout showing 6 capture types (Screenshot, Region, Scrolling, Video, GIF, OCR) as circular buttons with SF Symbols. Animate in with PhaseAnimator scale+opacity. Keyboard navigation via arrow keys and number keys 1-6. Dismiss on Escape or selection. Appear within 100ms of global shortcut (registered via CGEvent.tapCreate).
4. Build ActionBarWindow as NSPanel HUD with 7 buttons in fixed order: Annotate, Copy, Save, Cloud, Background, Pin, Delete. Store lastAction per CaptureType in UserDefaults. Enter key repeats last action. Arrow key navigation between buttons. Build CaptureScreenshotIntent and SearchLibraryIntent conforming to AppIntent. CaptureScreenshotIntent returns IntentFile. SearchLibraryIntent accepts query String parameter, returns [CaptureResultEntity]. Add ExplainScreenshotIntent returning explanation String.
5. Build LibraryBrowserView as NavigationSplitView. Sidebar: List sections for capture types with counts, tag cloud, smart filters (Today, This Week, Starred). Detail: LazyVGrid of thumbnails via AsyncImage with NSCache-backed ThumbnailLoader (max 200 items LRU). Search bar bound to FTS5 query via LibraryService.search(). Filters: capture type, date range (DatePicker), source app (Picker), tags. Results update within 200ms. Wire SharingService and AutomationBridge into AppServices initialization.

**Validation**
`cd SnapForge && swift build 2>&1 | tail -20`