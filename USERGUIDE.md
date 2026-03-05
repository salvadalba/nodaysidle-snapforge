# SnapForge User Guide

> A privacy-first macOS screenshot and screen capture tool with on-device AI — built to replace CleanShot X.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Menu Bar Interface](#menu-bar-interface)
3. [Capture Modes](#capture-modes)
4. [Post-Capture Actions](#post-capture-actions)
5. [Library Browser](#library-browser)
6. [AI Features](#ai-features)
7. [Command Palette](#command-palette)
8. [Settings](#settings)
9. [Keyboard Shortcuts](#keyboard-shortcuts)
10. [Automation & Scripting](#automation--scripting)
11. [Siri Shortcuts](#siri-shortcuts)
12. [URL Scheme](#url-scheme)
13. [Privacy & Security](#privacy--security)
14. [Troubleshooting](#troubleshooting)
15. [Building from Source](#building-from-source)

---

## Getting Started

### Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon (arm64) Mac

### Installation

SnapForge lives in your menu bar. After launching, you will see a **hammer icon** (&#9879;) in the macOS menu bar. Click it to access all capture modes and actions.

On first launch, macOS will ask for **Screen Recording** permission:

1. A system dialog appears requesting screen recording access.
2. Click **Open System Settings** and toggle SnapForge **on** under Privacy & Security > Screen Recording.
3. You may need to restart SnapForge after granting the permission.

### Launch at Login

Open **Settings > General** and enable **Launch at Login** to start SnapForge automatically when you log in.

---

## Menu Bar Interface

Click the hammer icon in the menu bar to reveal the capture panel:

| Action              | Description                                  |
|---------------------|----------------------------------------------|
| **Screenshot**      | Capture the full screen or a selected region  |
| **Scrolling Capture** | Capture content that extends beyond the visible viewport |
| **Screen Recording** | Record video of your screen (H.265 by default) |
| **GIF Recording**   | Record an animated GIF                        |
| **OCR Capture**     | Capture text from a screen region using OCR   |
| **Open Library**    | Browse and manage all your captures           |
| **Quit SnapForge**  | Exit the application                         |

---

## Capture Modes

### Screenshot

Captures a still image of the full screen or a user-selected region. The default save format is PNG (configurable in Settings to JPEG or TIFF).

### Scrolling Capture

Automatically scrolls and stitches content that extends beyond the visible window area — useful for long web pages, documents, or chat threads.

### Screen Recording

Records video of your screen. Supports multiple codecs:

| Codec   | Use Case                          |
|---------|-----------------------------------|
| H.265   | Default. High quality, small files |
| H.264   | Maximum compatibility              |
| ProRes  | Professional editing workflows     |

Recording settings (configurable via `RecordingConfig`):
- **FPS**: 30 (default)
- **Bitrate**: 8 Mbps (default)
- **Auto-Adjust Quality**: Enabled by default — dynamically lowers FPS/bitrate when CPU load is high.
- **Max Duration**: No limit by default.

### GIF Recording

Records an animated GIF. Uses the same recording pipeline but encodes output as GIF. Ideal for quick demos, bug reports, and documentation.

### OCR Capture

Captures a screen region and extracts all visible text using Apple's Vision framework (on-device). The recognized text is available immediately for copying or searching in the Library.

### Pin

Pin a capture to float above other windows for reference while you work.

---

## Post-Capture Actions

After every capture, a floating **Action Bar** appears near the captured region. Use arrow keys or mouse to select an action:

| Action        | Icon             | Description                                     |
|---------------|------------------|-------------------------------------------------|
| **Annotate**  | Pencil           | Open the annotation editor                      |
| **Copy**      | Clipboard        | Copy the capture to the clipboard               |
| **Save**      | Download arrow   | Save to a specific location                     |
| **Share**     | Cloud upload     | Upload and generate a share link                |
| **Wallpaper** | Photo stack      | Set the capture as your desktop wallpaper        |
| **Pin**       | Pin              | Float the capture above all windows             |
| **Delete**    | Trash            | Discard the capture                             |

The Action Bar **remembers your last action** per capture type. Your most recent choice is highlighted with a gold ring on the next capture.

---

## Library Browser

Open from the menu bar (**Open Library**) or with **&#8984;L**.

The Library stores every capture with rich metadata:

- **Capture type** (screenshot, video, GIF, OCR, scrolling)
- **Source application** name and bundle ID
- **Window title** at the time of capture
- **File size** and dimensions
- **Tags** and **star** status
- **OCR-extracted text** (full-text searchable)

### Search

Type in the search bar to search across:
- File names
- Window titles
- Source application names
- OCR text content (powered by SQLite FTS5 full-text search)

### Filtering and Sorting

Filter by capture type, date range, star status, or tags. Sort by date, file size, or relevance.

---

## AI Features

SnapForge includes pluggable AI providers that run **on-device by default** for maximum privacy.

### Supported AI Providers

| Provider    | Where It Runs    | Setup                                    |
|-------------|------------------|------------------------------------------|
| **Core ML** | On-device        | Built-in, no setup required              |
| **MLX**     | On-device (GPU)  | Requires MLX Swift models                |
| **Ollama**  | Local server     | Install [Ollama](https://ollama.ai) separately |
| **OpenAI**  | Cloud            | Requires API key in Settings > AI        |
| **Anthropic** | Cloud          | Requires API key in Settings > AI        |

### AI Capabilities

- **Explain**: Ask the AI to describe or analyze a captured image using streaming responses.
- **Annotation Suggestions**: AI suggests smart annotations based on detected regions and content.
- **Region Detection**: Automatically identifies UI elements, text blocks, and salient regions in your captures.
- **Prompt Templates**: Save and reuse custom prompts for consistent AI interactions.
- **Conversation History**: Full conversation history is preserved per session.

### Provider Picker

Switch between AI providers at any time using the Provider Picker. Each provider shows its status (loaded/unloaded) and hardware compatibility.

### Model Management

The Model Registry tracks available models, their hardware requirements, and load state. Models are automatically unloaded after the idle timeout (default: 5 minutes, configurable in Settings > AI).

---

## Command Palette

A quick-access overlay for power users. Open it via keyboard shortcut to:

- Trigger any capture mode
- Search the library
- Run AI actions
- Access settings

The palette uses fuzzy matching — type a few characters of any action to find it instantly.

---

## Settings

Access via the menu bar or **&#8984;,** (Cmd+Comma).

### General

- **Launch at Login**: Start SnapForge when you log in.
- **Global Shortcut**: Customize the capture keyboard shortcut (default: &#8984;&#8679;4).

### Capture

- **Default Capture Type**: Choose between Screenshot, Region, or Scrolling as the default action.
- **Save Format**: PNG (default), JPEG, or TIFF.

### AI

- **Preferred Provider**: Core ML (default), MLX, Ollama, OpenAI, or Anthropic.
- **Model Idle Timeout**: How long (in seconds) to keep models loaded in memory after last use. Default: 300 seconds (5 minutes).

### Sharing

- **Privacy Mode**: Controls how captures are shared.
  - **Local Only** (default): Captures never leave your machine.
  - **Upload**: Automatically upload when sharing.
  - **Ask Every Time**: Prompt before each upload.

### Automation

- **Enable HTTP Bridge API**: Toggle the local REST API on/off (default: on).
- **Port**: The port number for the API (default: 48721).

---

## Keyboard Shortcuts

| Shortcut        | Action                  |
|-----------------|-------------------------|
| **&#8984;&#8679;4** | Take Screenshot          |
| **&#8984;L**    | Open Library             |
| **&#8984;Q**    | Quit SnapForge           |
| **&#8984;,**    | Open Settings            |
| **Arrow Keys**  | Navigate Action Bar      |
| **Return**      | Confirm Action Bar selection |

---

## Automation & Scripting

SnapForge exposes a **localhost REST API** (HTTP Bridge) for automation from scripts, Shortcuts, and third-party tools.

### Authentication

All API requests require a **Bearer token** stored automatically in your macOS Keychain under `com.snapforge.automation`. Retrieve it with:

```bash
security find-generic-password -s "com.snapforge.automation" -a "bearer-token" -w
```

Include the token in every request:

```
Authorization: Bearer <your-token>
```

### API Endpoints

**Base URL**: `http://localhost:48721`

| Method   | Endpoint                           | Description                     |
|----------|------------------------------------|---------------------------------|
| `GET`    | `/api/v1/capture/types`            | List available capture types     |
| `POST`   | `/api/v1/capture`                  | Trigger a screenshot capture     |
| `GET`    | `/api/v1/library/search?q=<term>`  | Search the capture library       |
| `GET`    | `/api/v1/library/captures/<uuid>`  | Fetch a specific capture by ID   |
| `DELETE` | `/api/v1/library/captures/<uuid>`  | Delete a capture by ID           |
| `POST`   | `/api/v1/sharing/upload`           | Upload a capture for sharing     |

### Examples

**Take a screenshot:**
```bash
TOKEN=$(security find-generic-password -s "com.snapforge.automation" -a "bearer-token" -w)
curl -X POST http://localhost:48721/api/v1/capture \
  -H "Authorization: Bearer $TOKEN"
```

**Search the library:**
```bash
curl http://localhost:48721/api/v1/library/search?q=safari \
  -H "Authorization: Bearer $TOKEN"
```

**Upload with expiry and password:**
```bash
curl -X POST http://localhost:48721/api/v1/sharing/upload \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"captureId":"<uuid>","expiryDays":7,"password":"optional-secret"}'
```

---

## Siri Shortcuts

SnapForge integrates with Apple Shortcuts via **AppIntents**:

### Take Screenshot

- **Action name**: "Take Screenshot"
- **Parameter**: Delay (seconds) — optionally wait before capturing.
- **Returns**: Capture result with file path, type, size, and timestamp.

### Search Library

- **Action name**: "Search SnapForge Library"
- **Parameter**: Search query text.
- **Returns**: Matching captures.

Add these actions in the **Shortcuts app** by searching for "SnapForge".

---

## URL Scheme

SnapForge registers the `snapforge://` URL scheme for deep linking:

```
snapforge://capture?type=screenshot
snapforge://capture?type=gif
snapforge://library?search=meeting+notes
```

---

## Privacy & Security

SnapForge is designed with a **local-first** philosophy:

- **All AI processing** runs on-device by default (Core ML / MLX). Cloud providers are opt-in.
- **No telemetry or analytics** are collected.
- **Screen recording data** never leaves your Mac unless you explicitly share it.
- **Full-text search index** is stored locally in SQLite with WAL mode.
- **Encryption**: Sharing uploads use AES-GCM encryption via CryptoKit. Password-protected links add an extra layer of security.
- **Keychain storage**: API bearer tokens and credentials are stored in the macOS Keychain, not in plain text files.
- **Adhoc code signing**: The app is self-signed. For distribution, use a Developer ID certificate.

---

## Troubleshooting

### "Screen recording permission denied"

1. Open **System Settings > Privacy & Security > Screen Recording**.
2. Find SnapForge in the list and toggle it **on**.
3. Restart SnapForge.

### App does not appear in the menu bar

SnapForge is a **menu bar-only app** (`LSUIElement = true`). It does not show in the Dock. Look for the hammer icon in the top-right area of the menu bar.

### Captures are blank or black

This usually means the screen recording permission was not fully applied. Try:
1. Toggle the permission **off** then **on** again in System Settings.
2. Restart SnapForge.

### AI features return errors

- **Core ML / MLX**: Ensure you have compatible models downloaded. Check Settings > AI for the model path.
- **Ollama**: Ensure the Ollama server is running (`ollama serve`).
- **Cloud providers**: Verify your API key in Settings > AI.

### HTTP Bridge API is not responding

1. Confirm it is enabled in **Settings > Automation**.
2. Check the port (default: 48721) is not in use by another process.
3. Retrieve the bearer token from Keychain (see [Automation](#automation--scripting)).

### Build warnings

When building from source, you may see deprecation warnings for:
- `AVAssetExportSession.export()` (macOS 15 deprecation)
- `copyCGImage(at:actualTime:)` (macOS 15 deprecation)

These are non-blocking and do not affect functionality. They will be resolved in a future update.

---

## Building from Source

### Prerequisites

- macOS 15.0+
- Swift 6.0+ toolchain (included with Xcode 16+ or swiftly)
- `rsvg-convert` (optional, for icon regeneration): `brew install librsvg`

### Quick Build

```bash
cd /Volumes/omarchyuser/projekti/nodaysidle-snapforge
swift build -c release
```

### Package as .app

```bash
# Build, bundle, sign, and launch:
bash Scripts/compile_and_run.sh

# Or package without launching:
SIGNING_MODE=adhoc bash Scripts/package_app.sh release
```

### Install

```bash
cp -R SnapForge.app /Applications/
```

### Run Tests

```bash
swift test
```

### Regenerate Icon

If you modify `icon.svg`:

```bash
rsvg-convert -w 1024 -h 1024 icon.svg > /tmp/icon_1024.png
mkdir -p /tmp/Icon.iconset
for size in 16 32 64 128 256 512; do
  sips -z $size $size /tmp/icon_1024.png --out /tmp/Icon.iconset/icon_${size}x${size}.png
  double=$((size * 2))
  sips -z $double $double /tmp/icon_1024.png --out /tmp/Icon.iconset/icon_${size}x${size}@2x.png
done
cp /tmp/icon_1024.png /tmp/Icon.iconset/icon_512x512@2x.png
iconutil --convert icns --output Icon.icns /tmp/Icon.iconset
```

### Universal Binary (Intel + Apple Silicon)

```bash
bash Scripts/compile_and_run.sh --release-universal
```

---

## Version

- **Version**: 1.0.0
- **Build**: 1
- **Bundle ID**: com.snapforge
- **Minimum macOS**: 15.0 (Sequoia)
- **Architecture**: arm64 (Apple Silicon)

---

*SnapForge — forging better screenshots, one capture at a time.*
