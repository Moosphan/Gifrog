import AppKit
import SwiftUI

final class SettingsPanelController {
    private let app: GifrogController
    private var panel: NSPanel?

    init(app: GifrogController) {
        self.app = app
    }

    func show() {
        let panel = panel ?? NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Gifrog Settings"
        panel.contentView = NSHostingView(rootView: SettingsView(app: app))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.panel = panel
    }
}
