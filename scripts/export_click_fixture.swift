import Foundation

@main
struct ClickFixtureExporter {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: export_click_fixture <project.json> <output-dir>\n", stderr)
            exit(2)
        }

        let projectURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let project = try JSONDecoder.app.decode(Project.self, from: Data(contentsOf: projectURL))
        var edit = EditDecision()
        edit.trimStart = 0
        edit.trimEnd = project.durationSeconds
        edit.format = .gif
        edit.scale = 0.5
        edit.fps = 15
        edit.optimizeColors = true

        edit.showClickHighlight = false
        let plain = try await ExportManager.export(project: project, edit: edit, savePath: outputDirectory)
        print("plain=\(plain.urlString)")

        edit.showClickHighlight = true
        let highlighted = try await ExportManager.export(project: project, edit: edit, savePath: outputDirectory)
        print("highlighted=\(highlighted.urlString)")
    }
}
