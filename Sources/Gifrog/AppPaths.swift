import Foundation

enum AppPaths {
    static var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gifrog", isDirectory: true)
    }

    static var projects: URL {
        support.appendingPathComponent("projects", isDirectory: true)
    }

    static var history: URL {
        support.appendingPathComponent("history.json")
    }

    static var settings: URL {
        support.appendingPathComponent("settings.json")
    }

    static var defaultSavePath: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gifrog", isDirectory: true)
            .appendingPathComponent("Captures", isDirectory: true)
    }

    static func prepare() {
        [support, projects, defaultSavePath].forEach { url in
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

struct Shell {
    static func ffmpegPath() throws -> String {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        throw GifrogError.ffmpegMissing
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String], cancellationToken: ProcessCancellationToken? = nil) throws -> String {
        if cancellationToken?.isCancelled == true {
            throw GifrogError.exportCancelled
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        cancellationToken?.attach(process)
        process.waitUntilExit()
        cancellationToken?.detach(process)

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if cancellationToken?.isCancelled == true {
            throw GifrogError.exportCancelled
        }

        guard process.terminationStatus == 0 else {
            throw GifrogError.processFailed(errorText.isEmpty ? outputText : errorText)
        }

        return outputText
    }
}

final class ProcessCancellationToken {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func attach(_ process: Process) {
        lock.lock()
        if cancelled {
            lock.unlock()
            process.terminate()
            return
        }
        self.process = process
        lock.unlock()
    }

    func detach(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let activeProcess = process
        lock.unlock()
        activeProcess?.terminate()
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var app: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension Int64 {
    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
