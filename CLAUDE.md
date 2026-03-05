# SnapForge

## Stack

**Frontend:** SwiftUI 6, .ultraThinMaterial / .regularMaterial, matchedGeometryEffect, PhaseAnimator, TimelineView
**Backend:** Swift 6, Structured Concurrency (async/await), Observation framework
**Database:** SwiftData, CloudKit (optional sync)

### Notes
- macOS 15+ (Sequoia) target
- CoreML + NaturalLanguage for on-device AI
- Metal shaders for visual effects
- Menu bar + Settings scene support
- Local-first architecture, no server required
- NSWindow customization for premium feel

## Key Rules

- Use Swift 6 Structured Concurrency (async/await, actors, TaskGroup) for all concurrent work
- Use SwiftUI 6 with Observation framework (@Observable) for all view models and state
- Use SwiftData for persistence and SQLite FTS5 for full-text search via direct C API
- Make all service types actors conforming to Sendable; use AsyncStream/AsyncThrowingStream for event delivery
- Target macOS 15+ Sequoia with Apple Silicon primary, Intel CPU-only fallback

## Do NOT

- Do not introduce any server-side infrastructure, external databases, or non-Apple frameworks for core features
- Do not use ObservableObject/Combine/@Published — use Observation framework @Observable exclusively
- Do not substitute CoreML/Vision/Metal/ScreenCaptureKit with third-party alternatives
- Do not use UIKit or AppKit views where SwiftUI equivalents exist; use NSWindow/NSPanel only for HUD overlays
- Do not store API keys in UserDefaults or plain files — Keychain only via Security framework

## Design System

**Mood:** Quietly powerful — the calm confidence of a precision instrument that doesn't need to shout. Think: the moment you pick up a well-balanced tool and it just fits. Warm enough to feel personal, sharp enough to feel professional. Intelligence is ambient, not performative.
**Typography:** SF Pro Display (marketing/headlines) at semibold 600 with -0.02em tracking for tightness; SF Pro Text (UI/body) at regular 400 with default tracking; SF Mono (code contexts, OCR results, API documentation) at medium 500. Fallback system: -apple-system for web. Size scale follows Apple's type ramp: 34/28/22/17/15/13/11. All type set with optical sizing enabled for Retina clarity.
**Primary Color:** #E8620A - Forge Orange — a deep, warm amber-orange inspired by molten metal and the creative act of forging; distinguishes from CleanShot's cool blue
**Secondary Color:** #1C1C1E - System Black — Apple's semantic dark surface color for text, toolbars, and high-contrast UI chrome
**Accent Color:** #FF9F0A - Spark Gold — Apple's system orange-gold, used for active states, AI indicators, and streaming token highlights
**Background:** #F5F5F7 - Apple Linen — the warm near-white Apple uses for marketing surfaces; avoids clinical sterility while maintaining clarity

## Documents

Read these before starting any work:

- `PRD.md` - Product Requirements
- `ARD.md` - Architecture & Design
- `TRD.md` - Technical Requirements
- `TASKS.md` - Implementation Tasks
- `AGENT.md` - Agent Instructions
- `DESIGN.md` - Visual Design Brief

## Execution Protocol

1. Read ALL documents above before writing any code
2. Scaffold the project structure based on ARD.md
3. Implement tasks from TASKS.md one by one
4. Follow the rules in AGENT.md for every decision
5. Match the visual direction from DESIGN.md
