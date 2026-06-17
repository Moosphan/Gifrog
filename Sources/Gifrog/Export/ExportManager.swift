import AppKit
import Foundation

struct ExportManager {
    static func export(project: Project, edit: EditDecision, savePath: URL, cancellationToken: ProcessCancellationToken? = nil) async throws -> ExportedFile {
        try FileManager.default.createDirectory(at: savePath, withIntermediateDirectories: true)

        let ffmpeg = try Shell.ffmpegPath()
        let stamp = Self.fileStamp.string(from: Date())
        let sanitizedName = project.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
        let destination = uniqueURL(
            savePath.appendingPathComponent("\(sanitizedName) \(stamp).\(edit.format.fileExtension)")
        )

        let trimEnd = edit.trimEnd > 0 ? edit.trimEnd : project.durationSeconds
        let duration = max(0.1, trimEnd - edit.trimStart)
        let visibleClicks = Self.visibleClickEvents(project: project, edit: edit, duration: duration)
        let highlightSpriteURL = try Self.makeClickHighlightSpriteIfNeeded(for: visibleClicks)
        defer {
            if let highlightSpriteURL {
                try? FileManager.default.removeItem(at: highlightSpriteURL)
            }
        }
        let filterGraph = Self.videoFilterGraph(edit: edit, clicks: visibleClicks)
        let ss = String(format: "%.3f", edit.trimStart)
        let t = String(format: "%.3f", duration)
        let clickInputs = highlightSpriteURL.map { spriteURL in
            visibleClicks.flatMap { _ in ["-loop", "1", "-i", spriteURL.path] }
        } ?? []

        switch edit.format {
        case .gif:
            try Shell.run(ffmpeg, [
                "-y",
                "-ss", ss,
                "-t", t,
                "-i", project.sourceURL.path,
            ] + clickInputs + [
                "-filter_complex", "\(filterGraph);[vout]split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                "-loop", "0",
                destination.path
            ], cancellationToken: cancellationToken)
        case .mp4:
            try Shell.run(ffmpeg, [
                "-y",
                "-ss", ss,
                "-t", t,
                "-i", project.sourceURL.path,
            ] + clickInputs + [
                "-filter_complex", "\(filterGraph);[vout]format=yuv420p[encoded]",
                "-map", "[encoded]",
                "-c:v", "libx264",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                destination.path
            ], cancellationToken: cancellationToken)
        case .webm:
            try Shell.run(ffmpeg, [
                "-y",
                "-ss", ss,
                "-t", t,
                "-i", project.sourceURL.path,
            ] + clickInputs + [
                "-filter_complex", filterGraph,
                "-map", "[vout]",
                "-c:v", "libvpx-vp9",
                "-b:v", "0",
                "-crf", edit.quality == .high ? "26" : edit.quality == .balanced ? "32" : "38",
                destination.path
            ], cancellationToken: cancellationToken)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
        let size = attrs[.size] as? Int64 ?? 0
        return ExportedFile(format: edit.format, urlString: destination.path, sizeBytes: size)
    }

    private struct VisibleClick {
        let event: ClickEvent
        let start: Double
        let duration: Double
    }

    private static func videoFilterGraph(edit: EditDecision, clicks: [VisibleClick]) -> String {
        let baseFilters = [
            "fps=\(edit.fps)",
            "scale=trunc(iw*\(Self.ff(edit.scale))/2)*2:trunc(ih*\(Self.ff(edit.scale))/2)*2:flags=lanczos"
        ]
        guard edit.showClickHighlight, !clicks.isEmpty else {
            return "[0:v]\(baseFilters.joined(separator: ","))[vout]"
        }

        var graph = "[0:v]\(baseFilters.joined(separator: ","))[v0]"
        for (index, click) in clicks.enumerated() {
            let inputIndex = index + 1
            let spriteLabel = "click\(index)"
            let nextVideoLabel = index == clicks.count - 1 ? "vout" : "v\(index + 1)"
            let x = "clip(W*\(ff(click.event.normalizedX)),w/2,W-w/2)-w/2"
            let y = "clip(H*\(ff(click.event.normalizedY)),h/2,H-h/2)-h/2"
            let fadeDuration = min(ClickHighlightStyle.fadeOutDuration, click.duration)
            let fadeStart = max(0.08, click.duration - fadeDuration)
            graph += ";[\(inputIndex):v]format=rgba,trim=duration=\(ff(click.duration)),setpts=PTS-STARTPTS+\(ff(click.start))/TB,fade=t=out:st=\(ff(fadeStart)):d=\(ff(fadeDuration)):alpha=1[\(spriteLabel)]"
            graph += ";[v\(index)][\(spriteLabel)]overlay=x='\(x)':y='\(y)':eof_action=pass:shortest=0[\(nextVideoLabel)]"
        }
        return graph
    }

    private static func visibleClickEvents(project: Project, edit: EditDecision, duration: Double) -> [VisibleClick] {
        guard edit.showClickHighlight else { return [] }
        return project.clickEvents.compactMap { event in
            let localTime = event.time - edit.trimStart
            guard localTime >= -ClickHighlightStyle.visibleDuration, localTime <= duration else { return nil }

            let start = max(0, localTime)
            let end = min(duration, localTime + ClickHighlightStyle.visibleDuration)
            guard end > start else { return nil }
            return VisibleClick(event: event, start: start, duration: end - start)
        }
    }

    private static func makeClickHighlightSpriteIfNeeded(for clicks: [VisibleClick]) throws -> URL? {
        guard !clicks.isEmpty else { return nil }

        let size = Int(ClickHighlightStyle.spriteSize.rounded())
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: size,
                pixelsHigh: size,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw GifrogError.writerNotReady
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        defer { NSGraphicsContext.restoreGraphicsState() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            throw GifrogError.writerNotReady
        }
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        let center = CGPoint(x: size / 2, y: size / 2)
        let rect = CGRect(
            x: center.x - ClickHighlightStyle.circleRadius,
            y: center.y - ClickHighlightStyle.circleRadius,
            width: ClickHighlightStyle.circleRadius * 2,
            height: ClickHighlightStyle.circleRadius * 2
        )
        context.setFillColor(NSColor.white.withAlphaComponent(ClickHighlightStyle.fillOpacity).cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(NSColor.black.withAlphaComponent(ClickHighlightStyle.contrastStrokeOpacity).cgColor)
        context.setLineWidth(ClickHighlightStyle.borderWidth + ClickHighlightStyle.contrastBorderWidth * 2)
        context.strokeEllipse(in: rect.insetBy(dx: ClickHighlightStyle.contrastBorderWidth / 2, dy: ClickHighlightStyle.contrastBorderWidth / 2))
        context.setStrokeColor(NSColor.white.withAlphaComponent(ClickHighlightStyle.strokeOpacity).cgColor)
        context.setLineWidth(ClickHighlightStyle.borderWidth)
        context.strokeEllipse(in: rect.insetBy(dx: ClickHighlightStyle.borderWidth / 2, dy: ClickHighlightStyle.borderWidth / 2))

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw GifrogError.writerNotReady
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gifrog-click-highlight-\(UUID().uuidString).png")
        try png.write(to: url)
        return url
    }

    static func estimate(project: Project, edit: EditDecision) -> String {
        let trimEnd = edit.trimEnd > 0 ? edit.trimEnd : project.durationSeconds
        let duration = max(0.1, trimEnd - edit.trimStart)
        let pixels = Double(project.width * project.height) * edit.scale * edit.scale
        let frameCount = duration * Double(edit.fps)
        let multiplier: Double
        switch edit.format {
        case .gif: multiplier = 0.000045
        case .mp4: multiplier = 0.000010
        case .webm: multiplier = 0.000008
        }
        let mb = max(0.1, pixels * frameCount * multiplier / 1024.0)
        return String(format: "%.1f MB", mb)
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    private static func uniqueURL(_ initialURL: URL) -> URL {
        guard FileManager.default.fileExists(atPath: initialURL.path) else {
            return initialURL
        }

        let directory = initialURL.deletingLastPathComponent()
        let baseName = initialURL.deletingPathExtension().lastPathComponent
        let pathExtension = initialURL.pathExtension

        for index in 2...999 {
            let candidate = directory.appendingPathComponent("\(baseName)-\(index).\(pathExtension)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent("\(baseName)-\(UUID().uuidString).\(pathExtension)")
    }

    private static func ff(_ value: Double) -> String {
        String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
