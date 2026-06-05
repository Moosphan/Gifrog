import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = GifrogController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        controller.setUp()

        if ProcessInfo.processInfo.environment["GIFROG_RENDER_QA"] == "1" {
            let outputPath = ProcessInfo.processInfo.environment["GIFROG_QA_DIR"] ?? "docs/qa/rendered"
            let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [controller] in
                controller.renderQAPreviews(to: outputURL)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if ProcessInfo.processInfo.environment["GIFROG_EXPORT_QA"] == "1" {
            let outputPath = ProcessInfo.processInfo.environment["GIFROG_QA_DIR"] ?? "docs/qa/export"
            let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
            Task { [controller] in
                _ = try? await controller.runExportQA(to: outputURL)
                await MainActor.run {
                    NSApplication.shared.terminate(nil)
                }
            }
            return
        }

        if let previewSurface = ProcessInfo.processInfo.environment["GIFROG_UI_PREVIEW"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [controller] in
                controller.showUIPreview(surface: previewSurface)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
