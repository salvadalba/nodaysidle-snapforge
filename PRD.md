# SnapForge

## 🎯 Product Vision
An AI-powered, privacy-first screen capture studio for macOS that turns every screenshot into searchable, shareable, actionable knowledge by combining native capture speed with on-device AI intelligence and a personal media library.

## ❓ Problem Statement
Existing macOS screen capture tools like CleanShot X treat captures as ephemeral files with inconsistent post-capture flows, no searchable history, zero AI assistance, opaque cloud privacy, and limited automation — leaving power users unable to organize, search, or integrate their visual knowledge into modern workflows.

## 🎯 Goals
- Deliver a unified command palette capture launcher that replaces modal, unpredictable capture initiation with a single shortcut for all capture types
- Build an OCR-indexed capture library with full-text search, tagging, and smart filters so users never lose track of past captures
- Ship on-device AI features (smart region detection, Explain Screenshot, AI annotation presets) using Core ML and Apple Vision framework with zero data leaving the device
- Provide a consistent post-capture action bar with per-mode memory and Enter-to-repeat across all capture types
- Implement privacy-first sharing with explicit local/cloud/ask toggle, E2E encrypted uploads, and optional self-hosted storage
- Create a native automation surface with Shortcuts actions, x-callback-url, local HTTP bridge API, and a plugin system for Notion, Linear, Slack, Jira, and Figma
- Ensure complete keyboard-first accessibility throughout capture, annotation, and post-capture workflows

## 🚫 Non-Goals
- Building a server-side backend or cloud infrastructure — SnapForge is local-first with optional self-hosted or E2E encrypted cloud sync
- Supporting platforms other than macOS 15+ (Sequoia) at launch
- Replacing dedicated video editing tools — screen recording features focus on capture and basic trim, not full post-production
- Building a collaborative real-time editing experience — sharing is async via links or export
- Training custom AI models — the product uses pre-trained Core ML models and Apple Vision framework
- Supporting third-party AI API providers (OpenAI, Anthropic) at launch — on-device inference is the primary path with API fallback planned for a future release

## 👥 Target Users
- Software developers who capture bugs, document code, and share technical context dozens of times daily
- Product designers and UX researchers who annotate, compare, and archive interface screenshots for design systems and user research
- Technical writers and support engineers who explain interfaces, extract text, and create documentation from screen captures
- Content creators and marketers who produce polished social media assets, tutorials, and product demos from screen recordings

## 🧩 Core Features
- Command Palette Capture Launcher: single shortcut opens a radial/command palette for all capture types (screenshot, scrolling, video, GIF, OCR, pin) with real-time region preview, pixel snapping, and spacing hints
- Consistent Post-Capture Action Bar: fixed option order (Annotate, Copy, Save, Cloud, Background, Pin, Delete) with per-mode memory of last action and Enter-to-repeat
- OCR-Indexed Capture Library: full-text search across all past captures using SQLite FTS5, with tagging, filters by source app/domain/capture type, storage usage dashboard, and automatic cleanup rules
- On-Device AI Capture Assistant: smart region detection via Apple Vision framework that auto-suggests capture areas based on UI elements, Explain Screenshot that generates natural-language descriptions via Core ML, and AI annotation presets that auto-highlight key areas
- Keyboard-First Workflow: arrow key navigation in post-capture overlay, configurable shortcuts for annotate-last and copy-last-link, and complete keyboard accessibility throughout annotation tools
- Privacy-First Sharing: explicit toggle (Local Only / Upload / Ask Every Time), E2E encrypted cloud uploads, clear offline error states, optional self-hosted storage backend, and transparent security documentation
- Native Automation Surface: Shortcuts actions for every capture type and post-action, x-callback-url support, local HTTP bridge API, and plugin system for custom send-to targets (Notion, Linear, Slack, Jira, Figma)
- Progressive Disclosure UI: core 5-7 features prominently displayed, advanced options in collapsible drawer, first-run guided capture tour, and weekly Did You Know tips with Show Me buttons
- Metal-Accelerated Recording Pipeline: configurable FPS, resolution, codec, and bitrate per recording mode using ScreenCaptureKit + Metal + AVFoundation with real-time CPU/GPU usage indicator and automatic quality adjustment
- Local AI Model Management: download, load, and switch on-device Core ML models with GPU/MLX acceleration on Apple Silicon, streaming responses for real-time AI output, prompt template management, and usage tracking for tokens and latency

## ⚙️ Non-Functional Requirements
- Target macOS 15+ (Sequoia) with Apple Silicon optimization using NEON for OCR and AI inference
- Built with SwiftUI 6 using .ultraThinMaterial/.regularMaterial, matchedGeometryEffect, PhaseAnimator, and TimelineView for premium native feel
- Swift 6 with Structured Concurrency (async/await) and Observation framework for all state management
- SwiftData for local persistence with optional CloudKit sync
- Metal shaders for visual effects and hardware-accelerated encoding pipeline
- SQLite with FTS5 must support fast full-text queries across tens of thousands of OCR-indexed captures with minimal memory footprint
- All AI inference runs on-device via Core ML and Apple Vision framework — no data leaves the device by default
- Capture latency under 100ms from shortcut press to region selection overlay appearing
- Local-first architecture with no server required for core functionality
- NSWindow customization for premium feel with Menu bar + Settings scene support
- E2E encryption for all cloud uploads with published security documentation

## 📊 Success Metrics
- Capture-to-clipboard time under 2 seconds for the most common screenshot workflow
- 95% of captures are findable via OCR full-text search within the library
- AI smart region detection correctly identifies the intended UI element boundary 80%+ of the time
- Post-capture action bar remembers and repeats last action correctly 100% of the time per mode
- Zero captures uploaded to cloud without explicit user consent (Local Only / Upload / Ask Every Time toggle enforced)
- Library search returns results in under 200ms across 10,000+ indexed captures
- Metal-accelerated recording maintains target FPS without exceeding 15% CPU overhead on Apple Silicon Macs
- 80%+ of core workflows completable entirely via keyboard without mouse interaction

## 📌 Assumptions
- Users are running macOS 15 (Sequoia) or later on Apple Silicon or recent Intel Macs
- Apple Vision framework and Core ML provide sufficient accuracy for UI element detection and OCR without custom model training
- ScreenCaptureKit APIs remain stable and sufficient for all capture types including scrolling capture
- SwiftData and SQLite FTS5 can handle the indexing and query load for power users with tens of thousands of captures
- Users prefer on-device AI processing over cloud-based AI for privacy reasons even if accuracy is slightly lower
- The plugin system for third-party integrations (Notion, Linear, Slack, Jira, Figma) can be built using public APIs without requiring partnership agreements
- MLX/GPU acceleration on Apple Silicon provides adequate performance for real-time AI inference during capture workflows

## ❓ Open Questions
- What is the maximum practical size of the OCR-indexed capture library before SQLite FTS5 performance degrades, and should we implement pagination or archival strategies?
- Should the AI Explain Screenshot feature support multiple languages at launch, or start with English only?
- How should the self-hosted storage backend be architected — provide a Docker image, a simple S3-compatible protocol, or both?
- What is the right licensing model — one-time purchase, subscription, or freemium with AI features as premium?
- Should the local HTTP bridge API require authentication, and if so, what mechanism is appropriate for a local-only service?
- How do we handle ScreenCaptureKit permission prompts gracefully during first-run without breaking the guided tour experience?
- Should API fallback (OpenAI, Anthropic) for AI features be included in v1 or deferred to a future release?
- What is the minimum Core ML model size that achieves acceptable smart region detection accuracy, and does it fit within a reasonable app bundle size?