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
        let filters = Self.videoFilters(project: project, edit: edit, duration: duration)
        let ss = String(format: "%.3f", edit.trimStart)
        let t = String(format: "%.3f", duration)

        switch edit.format {
        case .gif:
            try Shell.run(ffmpeg, [
                "-y",
                "-ss", ss,
                "-t", t,
                "-i", project.sourceURL.path,
                "-vf", "\(filters),split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                "-loop", "0",
                destination.path
            ], cancellationToken: cancellationToken)
        case .mp4:
            try Shell.run(ffmpeg, [
                "-y",
                "-ss", ss,
                "-t", t,
                "-i", project.sourceURL.path,
                "-vf", "\(filters),format=yuv420p",
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
                "-vf", filters,
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

    private static func videoFilters(project: Project, edit: EditDecision, duration: Double) -> String {
        var filters = [
            "fps=\(edit.fps)",
            "scale=trunc(iw*\(Self.ff(edit.scale))/2)*2:trunc(ih*\(Self.ff(edit.scale))/2)*2:flags=lanczos"
        ]

        if edit.showClickHighlight {
            filters.append(contentsOf: clickHighlightFilters(project: project, edit: edit, duration: duration))
        }

        return filters.joined(separator: ",")
    }

    private static func clickHighlightFilters(project: Project, edit: EditDecision, duration: Double) -> [String] {
        project.clickEvents.compactMap { event in
            let localTime = event.time - edit.trimStart
            guard localTime >= -0.40, localTime <= duration else { return nil }

            let start = max(0, localTime)
            let end = min(duration, localTime + 0.38)
            guard end > start else { return nil }

            let color = event.button == .right ? "0x5B94FD@0.48" : "0xFF6435@0.52"
            return "drawbox=x='iw*\(ff(event.normalizedX))-18':y='ih*\(ff(event.normalizedY))-18':w=36:h=36:color=\(color):t=4:enable='between(t,\(ff(start)),\(ff(end)))'"
        }
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
