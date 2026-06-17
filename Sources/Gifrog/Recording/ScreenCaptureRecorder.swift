import AVFoundation
import CoreMedia
import ScreenCaptureKit

final class ScreenCaptureRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let session: FrameRecorder.RecordingSession
    private let settings: AppSettings
    private let writerQueue = DispatchQueue(label: "app.gifrog.screen-capture-writer")
    private let sampleQueue = DispatchQueue(label: "app.gifrog.screen-capture-samples")

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var firstPresentationTime: CMTime?
    private var pauseStartTime: CMTime?
    private var pausedDuration = CMTime.zero
    private var isPaused = false
    private var didAppendFrame = false
    private var finished = false

    init(session: FrameRecorder.RecordingSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
        super.init()
    }

    func start() async throws {
        let content = try await SCShareableContent.current
        guard let display = Self.bestDisplay(for: session.region, in: content.displays) else {
            throw GifrogError.noScreen
        }

        let scale = Self.backingScale(for: display)
        let window = session.region.windowID.flatMap { windowID in
            content.windows.first { $0.windowID == windowID }
        }
        let filter: SCContentFilter
        let sourceRect: CGRect

        if let window {
            filter = SCContentFilter(desktopIndependentWindow: window)
            sourceRect = CGRect(origin: .zero, size: window.frame.size)
        } else {
            let excludedApps = content.applications.filter { app in
                app.processID == getpid() || app.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApps,
                exceptingWindows: []
            )
            sourceRect = Self.sourceRect(for: session.region, display: display)
        }

        let pixelWidth = max(2, Int((sourceRect.width * scale).rounded()))
        let pixelHeight = max(2, Int((sourceRect.height * scale).rounded()))

        let configuration = SCStreamConfiguration()
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        if window == nil {
            configuration.sourceRect = sourceRect
        }
        configuration.destinationRect = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(session.fps, 1)))
        configuration.queueDepth = 4
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.scalesToFit = true
        configuration.showsCursor = settings.showMouseCursor
        if #available(macOS 13.0, *) {
            configuration.capturesAudio = false
            configuration.excludesCurrentProcessAudio = true
        }

        try prepareWriter(width: pixelWidth, height: pixelHeight)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await startCapture(stream)
        self.stream = stream
    }

    func pause() {
        writerQueue.async {
            self.isPaused = true
        }
    }

    func resume() {
        writerQueue.async {
            self.isPaused = false
        }
    }

    func cancel() async {
        if let stream {
            try? await stopCapture(stream)
        }
        writerQueue.sync {
            self.input?.markAsFinished()
            self.writer?.cancelWriting()
            self.finished = true
        }
        try? FileManager.default.removeItem(at: session.projectDir)
    }

    func stopAndFinish() async throws -> Project {
        guard let stream else {
            throw GifrogError.captureUnavailable
        }

        try await stopCapture(stream)
        try await finishWriting()

        guard didAppendFrame else {
            throw GifrogError.noFrames
        }

        let thumbnailURL = session.projectDir
            .appendingPathComponent("thumbnails", isDirectory: true)
            .appendingPathComponent("poster.png")
        try? FileManager.default.createDirectory(
            at: thumbnailURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let metadata = FrameRecorder.metadata(for: session.sourceURL)
        FrameRecorder.writeThumbnail(for: session.sourceURL, to: thumbnailURL)

        let project = Project(
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
        try JSONEncoder.pretty.encode(project).write(to: projectJSON)
        return project
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferDataIsReady(sampleBuffer) else { return }

        if !isCompleteFrame(sampleBuffer) {
            return
        }

        writerQueue.async {
            self.append(sampleBuffer)
        }
    }

    private func prepareWriter(width: Int, height: Int) throws {
        if FileManager.default.fileExists(atPath: session.sourceURL.path) {
            try FileManager.default.removeItem(at: session.sourceURL)
        }

        let writer = try AVAssetWriter(outputURL: session.sourceURL, fileType: .mov)
        let bitrate = max(3_000_000, width * height * max(session.fps, 1) / 2)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw GifrogError.writerNotReady
        }

        writer.add(input)
        self.writer = writer
        self.input = input
    }

    private func append(_ sampleBuffer: CMSampleBuffer) {
        guard !finished, let writer, let input else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard presentationTime.isValid else { return }

        if isPaused {
            if pauseStartTime == nil {
                pauseStartTime = presentationTime
            }
            return
        }

        if let pauseStartTime {
            pausedDuration = CMTimeAdd(pausedDuration, CMTimeSubtract(presentationTime, pauseStartTime))
            self.pauseStartTime = nil
        }

        if firstPresentationTime == nil {
            firstPresentationTime = presentationTime
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: .zero)
        }

        guard writer.status == .writing, input.isReadyForMoreMediaData, let firstPresentationTime else {
            return
        }

        let adjustedPresentationTime = CMTimeSubtract(
            CMTimeSubtract(presentationTime, firstPresentationTime),
            pausedDuration
        )
        let sourceDuration = CMSampleBufferGetDuration(sampleBuffer)
        let duration = sourceDuration.isValid ? sourceDuration : CMTime(value: 1, timescale: CMTimeScale(max(session.fps, 1)))

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: max(adjustedPresentationTime, .zero),
            decodeTimeStamp: .invalid
        )
        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &adjustedBuffer
        )

        guard status == noErr, let adjustedBuffer else { return }
        if input.append(adjustedBuffer) {
            didAppendFrame = true
        }
    }

    private func finishWriting() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerQueue.async {
                guard let writer = self.writer, let input = self.input else {
                    continuation.resume(throwing: GifrogError.writerNotReady)
                    return
                }

                if writer.status == .unknown {
                    writer.cancelWriting()
                    continuation.resume(throwing: GifrogError.noFrames)
                    return
                }

                input.markAsFinished()
                writer.finishWriting {
                    self.finished = true
                    if let error = writer.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let attachments = attachmentsArray.first,
            let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue)
        else {
            return true
        }

        return status == .complete
    }

    private func startCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func stopCapture(_ stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.stopCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func bestDisplay(for region: CaptureRegion, in displays: [SCDisplay]) -> SCDisplay? {
        displays.max { left, right in
            left.frame.intersection(region.globalRect).area < right.frame.intersection(region.globalRect).area
        } ?? displays.first
    }

    private static func sourceRect(for region: CaptureRegion, display: SCDisplay) -> CGRect {
        OverlayGeometry.screenCaptureSourceRect(globalRect: region.globalRect, displayFrame: display.frame)
    }

    private static func backingScale(for display: SCDisplay) -> CGFloat {
        if let screen = NSScreen.screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return id == display.displayID
        }) {
            return screen.backingScaleFactor
        }

        return CGFloat(CGDisplayPixelsWide(display.displayID)) / max(CGFloat(display.width), 1)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull && !isInfinite else { return 0 }
        return max(0, width) * max(0, height)
    }
}
