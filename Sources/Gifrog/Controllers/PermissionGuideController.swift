import AppKit
import SwiftUI

final class PermissionGuideController {
    private let app: GifrogController
    private var panel: NSPanel?

    init(app: GifrogController) {
        self.app = app
    }

    func show() {
        let panel = panel ?? NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Gifrog Permissions"
        panel.contentView = NSHostingView(rootView: PermissionGuideView(app: app))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
    }
}
