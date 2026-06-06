import AppKit
import SwiftUI

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let app: GifrogController
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let defaultIcon: NSImage?
    private let surfaceColor = NSColor(red: 0.965, green: 0.980, blue: 0.961, alpha: 1.0)

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

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 430)
        popover.contentViewController = NSHostingController(rootView: StatusPopoverView(app: app))
        popover.delegate = self
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
        if popover.isShown {
            close()
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func close() {
        popover.performClose(nil)
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

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        guard let window = popover.contentViewController?.view.window else { return }
        window.backgroundColor = surfaceColor
        // Aggressively tint all popover chrome views to match
        if let root = window.contentView {
            tintAllSubviews(root, color: surfaceColor)
        }
    }

    private func tintAllSubviews(_ view: NSView, color: NSColor) {
        // Skip our SwiftUI content view
        if view is NSHostingView<StatusPopoverView> { return }
        // Skip the content view's direct SwiftUI hosting view
        if String(describing: type(of: view)).contains("HostingView") { return }

        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor

        if let ev = view as? NSVisualEffectView {
            ev.wantsLayer = true
            ev.layer?.backgroundColor = color.cgColor
            ev.layer?.opacity = 1.0
        }

        for sub in view.subviews {
            tintAllSubviews(sub, color: color)
        }
    }
}
