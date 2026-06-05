import AppKit
import Foundation

enum CaptureMode: String, CaseIterable, Codable, Identifiable {
    case region = "Region"
    case window = "Window"
    case screen = "Screen"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .region: "crop"
        case .window: "macwindow"
        case .screen: "rectangle.inset.filled"
        }
    }
}

enum ExportFormat: String, CaseIterable, Codable, Identifiable {
    case gif = "GIF"
    case mp4 = "MP4"
    case webm = "WebM"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .gif: "gif"
        case .mp4: "mp4"
        case .webm: "webm"
        }
    }
}

enum QualityPreset: String, CaseIterable, Codable, Identifiable {
    case small = "Small"
    case balanced = "Balanced"
    case high = "High"

    var id: String { rawValue }
}

enum RecordingPhase: Equatable {
    case idle
    case requestingPermission
    case ready
    case countdown
    case recording
    case paused
    case finalizing
    case finished
    case exporting
    case error
}

struct AppSettings: Codable, Equatable {
    var launchAtLogin = false
    var showMouseCursor = true
    var highlightClicks = false
    var defaultFormat: ExportFormat = .gif
    var defaultFPS = 15
    var defaultScale = 0.75
    var quality: QualityPreset = .balanced
    var countdownSeconds = 3
    var shortcut = "Option + Shift + G"
    var savePath = AppPaths.defaultSavePath.path
    var autoCheckUpdates = false
    var anonymousUsageStats = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showMouseCursor
        case highlightClicks
        case defaultFormat
        case defaultFPS
        case defaultScale
        case quality
        case countdownSeconds
        case shortcut
        case savePath
        case autoCheckUpdates
        case anonymousUsageStats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showMouseCursor = try container.decodeIfPresent(Bool.self, forKey: .showMouseCursor) ?? true
        highlightClicks = try container.decodeIfPresent(Bool.self, forKey: .highlightClicks) ?? false
        defaultFormat = try container.decodeIfPresent(ExportFormat.self, forKey: .defaultFormat) ?? .gif
        defaultFPS = try container.decodeIfPresent(Int.self, forKey: .defaultFPS) ?? 15
        defaultScale = try container.decodeIfPresent(Double.self, forKey: .defaultScale) ?? 0.75
        quality = try container.decodeIfPresent(QualityPreset.self, forKey: .quality) ?? .balanced
        countdownSeconds = try container.decodeIfPresent(Int.self, forKey: .countdownSeconds) ?? 3
        shortcut = try container.decodeIfPresent(String.self, forKey: .shortcut) ?? "Option + Shift + G"
        savePath = try container.decodeIfPresent(String.self, forKey: .savePath) ?? AppPaths.defaultSavePath.path
        autoCheckUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? false
        anonymousUsageStats = try container.decodeIfPresent(Bool.self, forKey: .anonymousUsageStats) ?? false
    }
}

struct ExportedFile: Codable, Identifiable, Equatable {
    var id = UUID()
    var format: ExportFormat
    var urlString: String
    var sizeBytes: Int64
    var createdAt = Date()

    var url: URL { URL(fileURLWithPath: urlString) }
}

struct ClickEvent: Codable, Identifiable, Equatable {
    enum Button: String, Codable {
        case left
        case right
        case other
    }

    var id = UUID()
    var time: Double
    var normalizedX: Double
    var normalizedY: Double
    var button: Button
}

struct Project: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var sourceType: String
    var sourceURLString: String
    var thumbnailURLString: String?
    var durationSeconds: Double
    var width: Int
    var height: Int
    var fps: Double
    var createdAt = Date()
    var exports: [ExportedFile] = []
    var clickEvents: [ClickEvent] = []

    var sourceURL: URL { URL(fileURLWithPath: sourceURLString) }
    var thumbnailURL: URL? {
        guard let thumbnailURLString else { return nil }
        return URL(fileURLWithPath: thumbnailURLString)
    }
}

struct CaptureRegion: Codable, Equatable {
    var globalRect: CGRect
    var captureRect: CGRect
    var windowID: UInt32?

    init(globalRect: CGRect, captureRect: CGRect, windowID: UInt32? = nil) {
        self.globalRect = globalRect
        self.captureRect = captureRect
        self.windowID = windowID
    }

    var captureArgument: String {
        let x = Int(captureRect.origin.x.rounded())
        let y = Int(captureRect.origin.y.rounded())
        let w = max(1, Int(captureRect.width.rounded()))
        let h = max(1, Int(captureRect.height.rounded()))
        return "\(x),\(y),\(w),\(h)"
    }

    var displaySize: String {
        let w = max(1, Int(globalRect.width.rounded()))
        let h = max(1, Int(globalRect.height.rounded()))
        return "\(w)x\(h)"
    }

    static func screen(_ screen: NSScreen) -> CaptureRegion {
        let frame = screen.frame
        return CaptureRegion(
            globalRect: frame,
            captureRect: CGRect(x: frame.minX, y: 0, width: frame.width, height: frame.height)
        )
    }
}

struct EditDecision: Equatable {
    var trimStart: Double = 0
    var trimEnd: Double = 0
    var format: ExportFormat = .gif
    var scale: Double = 0.75
    var fps: Int = 15
    var quality: QualityPreset = .balanced
    var optimizeColors = true
    var dithering = false
    var showClickHighlight = false

    static func defaults(for project: Project, settings: AppSettings, format: ExportFormat? = nil) -> EditDecision {
        var decision = EditDecision()
        decision.trimEnd = project.durationSeconds
        decision.format = format ?? settings.defaultFormat
        decision.scale = settings.defaultScale
        decision.fps = settings.defaultFPS
        decision.quality = settings.quality
        decision.showClickHighlight = settings.highlightClicks
        return decision
    }
}

enum GifrogError: LocalizedError, Equatable {
    case noScreen
    case noRegion
    case noFrames
    case ffmpegMissing
    case processFailed(String)
    case unsupportedFile
    case captureUnavailable
    case writerNotReady
    case exportCancelled
    case launchAtLoginFailed(String)

    var errorDescription: String? {
        switch self {
        case .noScreen: "No display is available."
        case .noRegion: "Select a recording region first."
        case .noFrames: "No frames were captured."
        case .ffmpegMissing: "FFmpeg was not found. Install it with Homebrew or bundle it with the app."
        case .processFailed(let message): message
        case .unsupportedFile: "This file format is not supported by the MVP."
        case .captureUnavailable: "ScreenCaptureKit could not create a capture stream."
        case .writerNotReady: "The video writer was not ready."
        case .exportCancelled: "Export canceled."
        case .launchAtLoginFailed(let message): "Launch at login could not be updated: \(message)"
        }
    }
}
