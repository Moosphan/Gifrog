# Gifrog

A lightweight macOS menu bar app for screen recording and GIF/MP4/WebM export. Capture any region, window, or full screen, then trim and export — all without leaving the menu bar.

## Features

- **Three capture modes** — Region, Window, or Full Screen
- **Multiple export formats** — GIF, MP4 (H.264), WebM (VP9)
- **Built-in editor** — Video preview, timeline trimming, live file-size estimation
- **Click highlighting** — Visual overlays for mouse clicks during recording
- **Global hotkey** — `⌥⇧G` to start/stop recording from anywhere
- **Clipboard integration** — Exported files are automatically copied to clipboard
- **Drag & drop import** — Import existing MP4, MOV, M4V, or WebM files
- **Crash recovery** — Automatically recovers incomplete recordings on launch
- **Launch at login** — Optional auto-start via macOS ServiceManagement

## Requirements

- macOS 13 (Ventura) or later
- [FFmpeg](https://ffmpeg.org/) — install via Homebrew:
  ```bash
  brew install ffmpeg
  ```
- Screen Recording permission (app will guide you on first launch)

## Installation

### Build from source

```bash
git clone git@github.com:Moosphan/Gifrog.git
cd Gifrog
swift build -c release
```

The binary will be at `.build/release/Gifrog`.

### Create .app bundle

```bash
bash scripts/build_app.sh
open dist/Gifrog.app
```

## Usage

1. Launch Gifrog — a frog icon appears in the menu bar
2. Click the icon and choose a capture mode (Region / Window / Screen)
3. Grant Screen Recording permission when prompted
4. Record your screen — use the floating toolbar to pause or stop
5. Trim and configure export in the editor window
6. Export — the file is saved and copied to clipboard

### Global hotkey

Press `⌥⇧G` anywhere to toggle recording.

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥⇧G` | Start / Stop recording |
| `Space` | Pause / Resume (during recording) |
| `Esc` | Cancel recording |

## Configuration

Open settings via the gear icon in the status bar popover. Available options:

| Setting | Default | Description |
|---------|---------|-------------|
| FPS | 15 | Recording frame rate (10 / 15 / 24 / 30) |
| Scale | 100% | Output scale (100% / 75% / 50%) |
| Format | GIF | Export format (GIF / MP4 / WebM) |
| Quality | Medium | Export quality preset |
| Countdown | 3s | Countdown before recording starts |
| Show cursor | On | Include mouse cursor in recording |
| Click highlight | On | Overlay visual indicators on clicks |
| Launch at login | Off | Auto-start Gifrog on macOS login |
| Save path | `~/Movies/Gifrog` | Default export directory |

## Architecture

```
Sources/Gifrog/
├── main.swift                    # App entry point
├── Models.swift                  # Data models
├── Controllers/                  # AppKit window & state management
│   ├── GifrogController.swift    # Central coordinator
│   ├── StatusBarController.swift # Menu bar icon & popover
│   └── ...
├── Recording/                    # Screen capture pipeline
│   ├── ScreenCaptureRecorder.swift  # ScreenCaptureKit-based
│   ├── FrameRecorder.swift          # Recording orchestrator
│   └── ClickEventRecorder.swift     # Mouse click capture
├── Export/                       # FFmpeg-based export
│   └── ExportManager.swift
├── Views/                        # SwiftUI views
└── Resources/                    # App icons
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.10 |
| Build | Swift Package Manager |
| UI | SwiftUI + AppKit |
| Capture | ScreenCaptureKit |
| Video | AVFoundation |
| Export | FFmpeg |
| Hotkeys | Carbon HIToolbox |

## License

Copyright © 2026 Gifrog. All rights reserved.
