# Tasks Plan — SnapForge — AI-Powered Screen Capture Studio for macOS

## 📌 Global Assumptions
- macOS 15+ (Sequoia) is the minimum deployment target
- Apple Silicon is primary target; Intel supported with degraded AI features
- No server infrastructure required for core functionality
- User has granted Screen Recording permission via System Settings
- SwiftData and SQLite FTS5 coexist in the same app container without conflicts
- Bundled Core ML models total <100MB for app size budget
- MLX Swift framework is stable enough for production use on Apple Silicon

## ⚠️ Risks
- ScreenCaptureKit API changes or permission model tightening in future macOS updates could break capture functionality — Wrap all SCK calls behind CaptureServiceProtocol to isolate changes to one module
- MLX Swift is relatively new and may have stability or performance regressions — MLX is one of four providers; if unstable, disable and fall back to Core ML or Ollama
- FTS5 index and SwiftData operating on overlapping data could cause consistency issues — All FTS5 writes go through LibraryService actor serialization; add reindexOCR recovery command
- Metal shader compilation and GPU memory pressure during recording may cause frame drops on 8GB machines — Auto-quality adjustment reduces FPS/resolution when CPU exceeds 15%; test on base M1 8GB
- App Sandbox restrictions may limit plugin loading via dlopen and localhost HTTP server binding — Test sandbox entitlements early in Phase 1; fall back to XPC for plugins if dlopen blocked

## 🧩 Epics
## AI Backend Abstraction Layer
**Goal:** Establish a unified InferenceProvider protocol with pluggable local and cloud backends so all AI features route through a single async streaming interface.

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Define InferenceProvider protocol and core types (3 points)

Create the InferenceProvider protocol returning AsyncThrowingStream<String, Error>, plus InferenceContext, DetectedRegion, OCRResult, and AnnotationSuggestion types. All types must be Sendable.

**Acceptance Criteria**
- Protocol compiles with async throws and AsyncThrowingStream return
- All associated types conform to Sendable
- ProviderType enum covers coreml, mlx, ollama, openai, anthropic

**Dependencies**
_None_

### ✅ Implement CoreMLProvider with Vision framework OCR and region detection (8 points)

Build CoreMLProvider conforming to InferenceProvider. Use VNRecognizeTextRequest for OCR, VNGenerateAttentionBasedSaliencyImageRequest for region detection, and a bundled Core ML vision model for screenshot explanation.

**Acceptance Criteria**
- OCR extracts text from test images with >90% accuracy
- Region detection returns labeled bounding boxes with confidence scores
- Streaming explanation produces token-by-token output via AsyncThrowingStream
- Falls back to CPU inference on Intel Macs without error

**Dependencies**
- Define InferenceProvider protocol and core types

### ✅ Implement MLXProvider for local LLM inference (8 points)

Wrap MLX Swift for on-device LLM inference using pre-converted MLX SafeTensors models. Support streaming token generation with configurable context window (2048-8192).

**Acceptance Criteria**
- Loads a quantized model and generates streaming text
- Respects context window limits and throws contextWindowExceeded
- Disabled on Intel Macs with clear ProviderUnavailable error
- Token counting uses MLX tokenizer

**Dependencies**
- Define InferenceProvider protocol and core types

### ✅ Implement OllamaProvider as localhost HTTP client (5 points)

Build OllamaProvider that connects to localhost:11434 Ollama server, sends prompts via /api/generate, and parses streaming JSON responses into AsyncThrowingStream.

**Acceptance Criteria**
- Streams tokens from a running Ollama instance
- Throws providerUnavailable if Ollama is not running
- Handles network timeouts with 30s deadline
- Retries connection 3 times with exponential backoff

**Dependencies**
- Define InferenceProvider protocol and core types

### ✅ Implement CloudAPIProvider for OpenAI and Anthropic (5 points)

Build CloudAPIProvider supporting OpenAI and Anthropic REST APIs with SSE streaming response parsing. API keys stored in Keychain. Token counting via character-based approximation (÷4 rule).

**Acceptance Criteria**
- Streams SSE responses from both OpenAI and Anthropic endpoints
- API keys read from Keychain, never logged or persisted to disk
- Throws authenticationFailed on 401, rateLimited on 429 with retry-after
- Approximate token count within 20% of actual for typical prompts

**Dependencies**
- Define InferenceProvider protocol and core types

## AI Model Manager
**Goal:** Build ModelManagerService actor that handles model discovery, download with progress, caching, GPU memory-aware loading/unloading, and idle timeout eviction.

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build ModelManagerService actor with load/unload lifecycle (5 points)

Create actor conforming to ModelManagerProtocol. Track loaded models, enforce one large model (>500MB) at a time, keep Core ML vision models (<50MB) permanently loaded. Query Metal device recommendedMaxWorkingSetSize for memory budget.

**Acceptance Criteria**
- Loads and unloads models with correct state transitions
- Prevents loading two large models simultaneously
- Core ML vision models stay loaded after initial load
- Logs GPU memory usage before and after model load at .info level

**Dependencies**
- Define InferenceProvider protocol and core types

### ✅ Implement model download with progress streaming and integrity verification (5 points)

Add downloadModel returning AsyncThrowingStream<DownloadProgress, Error>. Download to ~/Library/Application Support/SnapForge/Models/{provider}/. Verify SHA-256 checksum against manifest. Delete corrupted downloads and retry.

**Acceptance Criteria**
- Streams download progress with bytes_downloaded and bytes_total
- Rejects downloads failing SHA-256 checksum verification
- Throws insufficientStorage when disk space is low
- Throws conflict when download already in progress for same model

**Dependencies**
- Build ModelManagerService actor with load/unload lifecycle

### ✅ Implement idle timeout eviction for loaded models (3 points)

After configurable idle timeout (default 5 minutes), automatically unload non-bundled models to free GPU memory. Reset timer on each inference call. MLX models use mmap for lazy page-in.

**Acceptance Criteria**
- Models unloaded after idle timeout with log at .info level
- Timer resets on each inference request
- Bundled Core ML models exempt from eviction
- Eviction cancels cleanly if new inference arrives during unload

**Dependencies**
- Build ModelManagerService actor with load/unload lifecycle

### ✅ Create AIModel SwiftData entity and model registry (3 points)

Define AIModel @Model with all fields from data model spec. Seed bundled models on first launch. Provide availableModels and loadedModels computed properties on ModelManagerService.

**Acceptance Criteria**
- AIModel persists in SwiftData with all specified fields
- Bundled models seeded on first launch with isBundled=true
- availableModels returns union of bundled and downloaded models
- downloadStatus transitions correctly through notDownloaded→downloading→downloaded

**Dependencies**
- Build ModelManagerService actor with load/unload lifecycle

### ✅ Detect GPU capabilities and configure hardware fallback (2 points)

Query MTLDevice.supportsFamily(.apple7) for Neural Engine. Disable MLX on Intel. Set Core ML computeUnits to .cpuOnly on Intel Macs. Log hardware capabilities at .info on launch.

**Acceptance Criteria**
- Apple Silicon uses GPU+NeuralEngine compute units
- Intel Macs fall back to CPU-only Core ML without crash
- MLX provider reports unavailable on Intel with clear message
- Hardware capabilities logged at app launch

**Dependencies**
_None_

## Streaming AI UI
**Goal:** Build real-time streaming UI for AI explain, region detection overlay, and annotation suggestions so users see token-by-token output and interactive region highlights.

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build Explain Screenshot streaming text view (5 points)

Create a SwiftUI view that subscribes to AsyncThrowingStream<String, Error> from any InferenceProvider and renders tokens as they arrive. Show provider name, elapsed time, and token count. Support cancel via Task cancellation.

**Acceptance Criteria**
- Tokens render incrementally without layout thrashing
- Cancel button stops the stream and shows partial result
- Provider badge and latency display update in real time
- Error states show user-facing message from AIError.localizedDescription

**Dependencies**
- Define InferenceProvider protocol and core types

### ✅ Build AI region detection overlay on capture preview (5 points)

After capture, run detectRegions and render semi-transparent labeled bounding boxes over the screenshot. User can click a detected region to crop or annotate just that area.

**Acceptance Criteria**
- Detected regions render as labeled overlays with confidence badges
- Clicking a region selects it for crop or annotation
- Regions update if user re-runs detection with different model
- Overlay dismisses cleanly on Escape key

**Dependencies**
- Implement CoreMLProvider with Vision framework OCR and region detection

### ✅ Build AI annotation preset suggestion panel (5 points)

After capture, offer a panel showing AI-suggested annotations (highlights on key UI areas). User can accept all, accept individually, or dismiss. Accepted suggestions become editable annotation objects.

**Acceptance Criteria**
- Suggestions render as preview annotations on the capture
- Accept All applies all suggestions to the annotation canvas
- Individual accept/reject per suggestion
- Dismissed suggestions do not persist

**Dependencies**
- Build AI region detection overlay on capture preview

### ✅ Integrate AI provider picker in capture detail view (3 points)

Add a dropdown in the capture detail view to select active AI provider. Show loaded status, estimated latency, and model name. Remember last-used provider in UserDefaults.

**Acceptance Criteria**
- Dropdown lists all available providers with load status
- Selecting an unloaded provider triggers model load with progress indicator
- Last-used provider persisted and restored on next launch
- Unavailable providers shown as disabled with reason tooltip

**Dependencies**
- Build ModelManagerService actor with load/unload lifecycle
- Build Explain Screenshot streaming text view

## Prompt Templates and Conversation History
**Goal:** Persist prompt templates and per-capture AI conversation history so users can re-run explanations, refine prompts, and build a knowledge base from their captures.

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create PromptTemplate and ConversationEntry SwiftData models (3 points)

Define PromptTemplate @Model with template string supporting {{image}} and {{ocr_text}} placeholders. Define ConversationEntry @Model with many-to-one relationship to CaptureRecord via captureRecordID. Seed default templates on first launch.

**Acceptance Criteria**
- Both models persist in SwiftData with all specified fields
- Default templates seeded: Explain, Summarize, Extract Key Info, Compare
- ConversationEntry links to CaptureRecord via captureRecordID
- Orphaned ConversationEntries cleaned up by auto-cleanup rules

**Dependencies**
_None_

### ✅ Build PromptStorageService for template CRUD and placeholder substitution (3 points)

Create service actor for creating, updating, deleting, and listing prompt templates. Implement substituteePlaceholders that replaces {{image}} and {{ocr_text}} with actual capture data before sending to InferenceProvider.

**Acceptance Criteria**
- CRUD operations persist templates in SwiftData
- Placeholder substitution replaces {{ocr_text}} with actual OCR text
- Usage count increments on each template use
- Templates sortable by usage count and recency

**Dependencies**
- Create PromptTemplate and ConversationEntry SwiftData models

### ✅ Build conversation history UI in capture detail view (5 points)

Show scrollable list of past AI conversations for a capture. Each entry shows prompt, response, provider, and timestamp. User can re-run any previous prompt or start a new conversation.

**Acceptance Criteria**
- Conversation history loads for selected capture
- Re-run button sends same prompt to current provider and appends new entry
- New conversation input field at bottom of list
- Empty state shows suggestion to try Explain Screenshot

**Dependencies**
- Create PromptTemplate and ConversationEntry SwiftData models
- Build Explain Screenshot streaming text view

### ✅ Build prompt template picker and editor (3 points)

Create a sheet view for browsing, selecting, editing, and creating prompt templates. Show template preview with placeholder highlights. Integrate into the Explain Screenshot flow as an optional step before sending.

**Acceptance Criteria**
- Template list shows name, category, and usage count
- Editor highlights {{image}} and {{ocr_text}} placeholders in template text
- New template creation with category selection
- Selected template auto-fills the explain prompt field

**Dependencies**
- Build PromptStorageService for template CRUD and placeholder substitution

## Core Capture Engine and Library
**Goal:** Deliver functional screenshot, scrolling, video, and GIF capture with a searchable OCR-indexed library, forming the foundation all AI features build upon.

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement CaptureEngine actor with ScreenCaptureKit (8 points)

Build actor conforming to CaptureServiceProtocol. Wrap SCStream for screenshot and region capture. Detect source app bundle ID and window title via CGWindowListCopyWindowInfo. Emit state transitions via AsyncStream<CaptureState>.

**Acceptance Criteria**
- Screenshot capture produces PNG file at expected path
- Region capture respects specified CGRect bounds
- Source app bundle ID and name detected correctly
- State stream emits idle→selecting→capturing→completed sequence

**Dependencies**
_None_

### ✅ Build LibraryStore with SwiftData and FTS5 search index (8 points)

Create LibraryService actor managing SwiftData ModelContainer for CaptureRecord CRUD. Maintain parallel SQLite FTS5 index. Configure WAL mode, 256MB mmap, 64MB cache. Support full-text search with BM25 ranking.

**Acceptance Criteria**
- CaptureRecord persists and retrieves via SwiftData
- FTS5 index updates on insert, update, and delete
- Search returns ranked results within 200ms for 10k records
- Pagination via limit and offset works correctly

**Dependencies**
_None_

### ✅ Implement background OCR indexing pipeline (5 points)

After each capture, run VNRecognizeTextRequest in a throttled TaskGroup (max 2 concurrent). Store OCR text on CaptureRecord and update FTS5 index. Pause during active recording.

**Acceptance Criteria**
- OCR runs automatically after screenshot capture
- Max 2 concurrent OCR tasks enforced
- OCR pauses during active recording
- FTS5 index searchable immediately after OCR completes

**Dependencies**
- Implement CaptureEngine actor with ScreenCaptureKit
- Build LibraryStore with SwiftData and FTS5 search index

### ✅ Build RecordingPipeline with Metal-accelerated encoding (8 points)

Implement RecordingPipelineProtocol with configurable FPS, codec (H.264/H.265/ProRes), and bitrate. Use AVAssetWriter with hardware encoding. Monitor CPU/GPU via IOKit. Auto-adjust quality when CPU exceeds 15%.

**Acceptance Criteria**
- Video recording produces valid .mov file with specified codec
- GIF conversion produces valid .gif with temporal dithering
- Real-time metrics stream emits CPU, GPU, FPS, duration
- Quality auto-adjusts when CPU threshold exceeded

**Dependencies**
- Implement CaptureEngine actor with ScreenCaptureKit

### ✅ Build AppServices actor and service initialization (5 points)

Create central AppServices actor that initializes all services in dependency order. Inject into SwiftUI via @Environment. Handle app lifecycle events (launch, terminate, sleep, wake).

**Acceptance Criteria**
- Services initialize in correct dependency order without deadlock
- All services accessible via typed properties on AppServices
- App launch completes within 2 seconds including service init
- Shutdown propagates to all services cleanly

**Dependencies**
- Implement CaptureEngine actor with ScreenCaptureKit
- Build LibraryStore with SwiftData and FTS5 search index

## Sharing, Automation, and UI Shell
**Goal:** Wire up E2E encrypted sharing, HTTP bridge API, Shortcuts integration, command palette, and post-capture action bar to complete the user-facing experience.

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement SharingService with E2E encryption and S3 upload (8 points)

Build SharingService actor enforcing PrivacyMode before uploads. Encrypt via CryptoKit AES-256-GCM with HKDF-derived key. Upload to user-configured S3-compatible endpoint. Retry 3 times with exponential backoff.

**Acceptance Criteria**
- LocalOnly mode throws privacyModeBlocked on upload attempt
- Encrypt-then-decrypt roundtrip produces identical plaintext
- Upload retries 3 times on transient failure then surfaces error
- Share URL generated with optional expiry and password

**Dependencies**
- Build LibraryStore with SwiftData and FTS5 search index

### ✅ Build AutomationBridge with HTTP API and x-callback-url (8 points)

Implement HTTP bridge on localhost:48721 via NWListener. Route all REST endpoints from API contracts. Parse snapforge:// URL scheme. Generate bearer token in Keychain on first launch.

**Acceptance Criteria**
- All 11 HTTP endpoints respond with correct status codes
- Bearer token validated on every request, 401 on mismatch
- x-callback-url capture triggers CaptureEngine and returns capture_id
- Max 10 concurrent connections enforced

**Dependencies**
- Implement CaptureEngine actor with ScreenCaptureKit
- Build LibraryStore with SwiftData and FTS5 search index

### ✅ Build command palette and post-capture action bar (8 points)

Create command palette as floating NSPanel with radial layout for capture type selection. Build post-capture action bar as HUD NSWindow with fixed 7-button order. Implement per-mode action memory and Enter-to-repeat.

**Acceptance Criteria**
- Command palette appears within 100ms of shortcut press
- All 6 capture types selectable via keyboard or click
- Action bar shows all 7 buttons in specified order
- Enter-to-repeat invokes last action for current capture mode

**Dependencies**
- Implement CaptureEngine actor with ScreenCaptureKit

### ✅ Implement AppIntents for Shortcuts integration (5 points)

Create CaptureScreenshotIntent, SearchLibraryIntent, and ExplainScreenshotIntent conforming to AppIntent. Return typed results for Shortcuts composition.

**Acceptance Criteria**
- All three intents discoverable in Shortcuts app
- CaptureScreenshotIntent returns IntentFile with captured image
- SearchLibraryIntent returns array of matching capture results
- ExplainScreenshotIntent returns explanation text with provider info

**Dependencies**
- Implement CaptureEngine actor with ScreenCaptureKit
- Build LibraryStore with SwiftData and FTS5 search index

### ✅ Build library browser view with search and filters (8 points)

Create NavigationSplitView with sidebar for capture types, tags, and smart filters. Search bar triggers FTS5 queries. Thumbnail grid with AsyncImage and NSCache-backed loader (max 200 items, LRU eviction).

**Acceptance Criteria**
- Sidebar shows capture types with counts and tag cloud
- Search results appear within 200ms with relevance ranking
- Filters by type, date range, source app, and tag work correctly
- Thumbnail grid scrolls smoothly with 1000+ captures

**Dependencies**
- Build LibraryStore with SwiftData and FTS5 search index

## ❓ Open Questions
- Which specific Core ML models to bundle for region detection and screenshot explanation — MobileNetV3 for UI classification plus which vision-language model, within 100MB budget?
- Should plugins use compiled Swift packages via dlopen or script-based authoring (AppleScript/JSContext) for easier third-party development?
- Is self-hosted storage Docker image in scope for v1, or ship with S3-compatible endpoint config only?
- Should FTS5 ranking use built-in BM25 only, or custom ranking weighing recency and tag matches?
- Should concurrent screenshot capture during video recording be supported in v1, given doubled GPU memory usage?