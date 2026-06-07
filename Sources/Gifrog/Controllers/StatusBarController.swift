import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let app: GifrogController
    private let statusItem: NSStatusItem
    private var panel: NSPanel?
    private let defaultIcon: NSImage?
    private var eventMonitor: Any?

    init(app: GifrogController) {
        self.app = app
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let url = Bundle.module.url(forResource: "GifrogIconTemplate", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 22, height: 22)
            img.isTemplate = true
            defaultIcon = img
        } else {
            defaultIcon = nil
        }

        super.init()

        if let button = statusItem.button {
            button.image = defaultIcon ?? NSImage(systemSymbolName: "film.stack", accessibilityDescription: "Gifrog")
            button.image?.isTemplate = true
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Gifrog", action: #selector(quitApp), keyEquivalent: "q"))
        menu.item(at: 0)?.target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let p = ensurePanel()
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        // Position below the status bar icon
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 430
        let spacing: CGFloat = 6

        var x = buttonFrame.midX - panelWidth / 2
        let y = buttonFrame.minY - panelHeight - spacing

        // Keep on screen
        if let screen = NSScreen.main {
            x = max(screen.visibleFrame.minX + 8, min(x, screen.visibleFrame.maxX - panelWidth - 8))
        }

        p.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        p.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Close when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        panel?.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 430),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.contentView = NSHostingView(rootView: StatusPopoverView(app: app))
        self.panel = p
        return p
    }

    func refresh() {
        guard let button = statusItem.button else { return }
        switch app.phase {
        case .recording:
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.image?.isTemplate = true
        case .paused:
            button.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Paused")
            button.image?.isTemplate = true
        case .exporting, .finalizing:
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Working")
            button.image?.isTemplate = true
        case .requestingPermission:
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Permission Required")
            button.image?.isTemplate = true
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
            button.image?.isTemplate = true
        default:
            button.image = defaultIcon ?? NSImage(systemSymbolName: "film.stack", accessibilityDescription: "Gifrog")
            button.image?.isTemplate = true
        }
    }
}
