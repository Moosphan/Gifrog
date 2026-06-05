import AVFoundation
import AppKit
import Foundation

actor FrameRecorder {
    private var isRecording = false
    private var isPaused = false
    private var frameIndex = 0
    private var loopTask: Task<Void, Never>?
    private var session: RecordingSession?
    private var screenCaptureSession: ScreenCaptureRecorder?
    private var isUsingScreenCaptureKit = false

    struct RecordingSession {
        var id = UUID()
        var name: String
        var projectDir: URL
        var framesDir: URL
        var sourceURL: URL
        var region: CaptureRegion
        var fps: Int
        var startedAt = Date()
    }

    func start(region: CaptureRegion, settings: AppSettings) async throws -> RecordingSession {
        let id = UUID()
        let projectDir = AppPaths.projects.appendingPathComponent(id.uuidString, isDirectory: true)
        let framesDir = projectDir.appendingPathComponent("frames", isDirectory: true)
        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDir.appendingPathComponent("exports", isDirectory: true), withIntermediateDirectories: true)

        let timestamp = Self.fileStamp.string(from: Date())
        let session = RecordingSession(
            id: id,
            name: "Screen Recording \(timestamp)",
            projectDir: projectDir,
            framesDir: framesDir,
            sourceURL: projectDir.appendingPathComponent("source.mov"),
            region: region,
            fps: max(1, settings.defaultFPS)
        )

        self.session = session
        self.frameIndex = 0
        self.isPaused = false
        self.isRecording = true
        self.screenCaptureSession = nil
        self.isUsingScreenCaptureKit = false

        do {
            let screenCaptureSession = ScreenCaptureRecorder(session: session, settings: settings)
            try await screenCaptureSession.start()
            self.screenCaptureSession = screenCaptureSession
            self.isUsingScreenCaptureKit = true
        } catch {
            loopTask = Task { [weak self] in
                await self?.captureLoop()
            }
        }

        return session
    }

    func pause() {
        if isUsingScreenCaptureKit {
            screenCaptureSession?.pause()
            return
        }
        isPaused = true
    }

    func resume() {
        if isUsingScreenCaptureKit {
            screenCaptureSession?.resume()
            return
        }
        isPaused = false
    }

    func cancel() {
        if isUsingScreenCaptureKit {
            let activeSession = screenCaptureSession
            Task {
                await activeSession?.cancel()
            }
            screenCaptureSession = nil
            session = nil
            isUsingScreenCaptureKit = false
            return
        }

        isRecording = false
        loopTask?.cancel()
        if let session {
            try? FileManager.default.removeItem(at: session.projectDir)
        }
        session = nil
    }

    func stopAndEncode() async throws -> Project {
        if isUsingScreenCaptureKit {
            guard let activeSession = screenCaptureSession else {
                throw GifrogError.captureUnavailable
            }
            let project = try await activeSession.stopAndFinish()
            self.session = nil
            self.screenCaptureSession = nil
            self.isUsingScreenCaptureKit = false
            return project
        }

        isRecording = false
        await loopTask?.value

        guard let session else {
            throw GifrogError.noRegion
        }

        guard frameIndex > 0 else {
            throw GifrogError.noFrames
        }

        let ffmpeg = try Shell.ffmpegPath()
        let pattern = session.framesDir.appendingPathComponent("frame_%05d.png").path

        try Shell.run(ffmpeg, [
            "-y",
            "-framerate", "\(session.fps)",
            "-i", pattern,
            "-vf", "format=yuv420p",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            session.sourceURL.path
        ])

        let thumbnailURL = session.projectDir
            .appendingPathComponent("thumbnails", isDirectory: true)
            .appendingPathComponent("poster.png")
        try? FileManager.default.createDirectory(
            at: thumbnailURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let metadata = Self.metadata(for: session.sourceURL)
        Self.writeThumbnail(for: session.sourceURL, to: thumbnailURL)

        var project = Project(
            id: session.id,
            name: session.name,
            sourceType: "screenRecording",
            sourceURLString: session.sourceURL.path,
            thumbnailURLString: FileManager.default.fileExists(atPath: thumbnailURL.path) ? thumbnailURL.path : nil,
            durationSeconds: metadata.duration,
            width: metadata.width,
            height: metadata.height,
            fps: Double(session.fps),
            createdAt: session.startedAt
        )

        let projectJSON = session.projectDir.appendingPathComponent("project.json")
        let data = try JSONEncoder.pretty.encode(project)
        try data.write(to: projectJSON)

        self.session = nil
        project.exports = []
        return project
    }

    private func captureLoop() async {
        guard let session else { return }
        let delay = UInt64(1_000_000_000 / UInt64(max(session.fps, 1)))

        while isRecording {
            if !isPaused {
                let frameURL = session.framesDir.appendingPathComponent(String(format: "frame_%05d.png", frameIndex))
                do {
                    try Shell.run("/usr/sbin/screencapture", [
                        "-x",
                        "-R", session.region.captureArgument,
                        frameURL.path
                    ])
                    frameIndex += 1
                } catch {
                    // Keep the session alive; the UI will surface failure when no frames exist.
                }
            }
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    static func metadata(for url: URL) -> (duration: Double, width: Int, height: Int) {
        let semaphore = DispatchSemaphore(value: 0)
        final class MetadataBox {
            var value: (duration: Double, width: Int, height: Int) = (0, 0, 0)
        }
        let box = MetadataBox()

        Task.detached {
            let asset = AVURLAsset(url: url)
            let loadedDuration = try? await asset.load(.duration)
            let duration = loadedDuration?.seconds.isFinite == true ? loadedDuration?.seconds ?? 0 : 0
            let track = try? await asset.loadTracks(withMediaType: .video).first
            let naturalSize = (try? await track?.load(.naturalSize)) ?? .zero
            let transform = (try? await track?.load(.preferredTransform)) ?? .identity
            let size = naturalSize.applying(transform)
            box.value = (duration, Int(abs(size.width)), Int(abs(size.height)))
            semaphore.signal()
        }

        semaphore.wait()
        return box.value
    }

    static func writeThumbnail(for videoURL: URL, to destination: URL) {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: destination)
    }
}
