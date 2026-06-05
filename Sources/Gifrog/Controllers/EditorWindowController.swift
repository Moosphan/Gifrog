import AppKit
import SwiftUI

final class EditorWindowController {
    private let app: GifrogController
    private var window: NSWindow?

    init(app: GifrogController) {
        self.app = app
    }

    func show(project: Project) {
        let editor = EditorView(app: app, project: project)
        let window = window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Gifrog Editor"
        window.contentView = NSHostingView(rootView: editor)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }
}
