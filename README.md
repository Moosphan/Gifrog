<p align="center">
  <img src="assets/logo.png" width="128" alt="Gifrog Logo">
</p>

<h1 align="center">Gifrog</h1>

<p align="center">
  <strong>Screen recording meets GIF export — right from your menu bar.</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-macOS_13+-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.10-orange.svg" alt="Swift">
  <a href="README.zh-CN.md"><img src="https://img.shields.io/badge/文档-中文-red.svg" alt="中文文档"></a>
</p>

---

Gifrog is a macOS menu bar utility that captures any region, window, or full screen and exports it as an optimized GIF, MP4, or WebM — with built-in trimming, click highlighting, and one-click clipboard copy. No Dock icon, no clutter. Just a frog in your menu bar.

## Quick Start

```bash
# Clone and build
git clone git@github.com:Moosphan/Gifrog.git && cd Gifrog
swift build -c release

# Or build as .app bundle
bash scripts/build_app.sh && open dist/Gifrog.app
```

**Requirements:** macOS 13+, Xcode 15+ (or Swift 5.10 toolchain)

## Features

| | Feature | Description |
|---|---------|-------------|
| 🎯 | **Three capture modes** | Region selection, window picker, or full screen |
| 🎬 | **Multi-format export** | GIF (palette-optimized), MP4 (H.264), WebM (VP9) |
| ✂️ | **Built-in editor** | Video preview, timeline trimming, live size estimation |
| 🖱️ | **Click highlighting** | Visual overlays for mouse clicks in recordings |
| ⌨️ | **Global hotkey** | `⌥⇧G` to start/stop from anywhere |
| 📋 | **Clipboard ready** | Exported files auto-copied to clipboard |
| 📂 | **Drag & drop import** | Import MP4, MOV, M4V, or WebM directly |
| 🔄 | **Crash recovery** | Automatically recovers incomplete recordings |
| 🚀 | **Launch at login** | Optional auto-start on macOS login |

## Usage

1. **Launch** — a frog icon appears in your menu bar
2. **Choose mode** — click the icon → Region / Window / Screen
3. **Record** — use the floating toolbar to pause or stop
4. **Edit & export** — trim in the editor, pick format and quality, export

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥⇧G` | Start / Stop recording |
| `Space` | Pause / Resume |
| `Esc` | Cancel recording |

## Configuration

Open settings via the gear icon in the popover menu:

| Setting | Default | Options |
|---------|---------|---------|
| Frame rate | 15 fps | 10 / 15 / 24 / 30 |
| Scale | 100% | 100% / 75% / 50% |
| Format | GIF | GIF / MP4 / WebM |
| Quality | Medium | Low / Medium / High |
| Countdown | 3s | 0 / 3 / 5 seconds |
| Show cursor | On | On / Off |
| Click highlight | On | On / Off |
| Launch at login | Off | On / Off |
| Save path | `~/Movies/Gifrog` | Custom path |

## Architecture

```
Sources/Gifrog/
├── Controllers/       # AppKit window & state management
├── Recording/         # ScreenCaptureKit-based capture pipeline
├── Export/            # FFmpeg-based GIF/MP4/WebM export
├── Views/             # SwiftUI views
└── Resources/         # App icons
```

| Component | Technology |
|-----------|------------|
| Capture | ScreenCaptureKit |
| Video | AVFoundation |
| Export | FFmpeg |
| UI | SwiftUI + AppKit |
| Build | Swift Package Manager |

## License

[Apache License 2.0](LICENSE) © 2026 Gifrog
