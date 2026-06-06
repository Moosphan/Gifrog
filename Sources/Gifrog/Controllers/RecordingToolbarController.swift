import AppKit
import SwiftUI

final class RecordingToolbarController {
    private let app: GifrogController
    private var panel: NSPanel?
    private var eventMonitor: Any?

    init(app: GifrogController) {
        self.app = app
    }

    func show(near region: CaptureRegion) {
        let panel = ensurePanel()
        panel.contentView = NSHostingView(rootView: RecordingToolbarView(app: app))
        position(panel, near: region)
        panel.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
        installKeyboardMonitor()
    }


    func showFinished(near region: CaptureRegion?) {
        guard let region else { return }
        show(near: region)
    }

    func refresh() {
        panel?.contentView = NSHostingView(rootView: RecordingToolbarView(app: app))
    }

    func hide() {
        panel?.orderOut(nil)
        removeKeyboardMonitor()
    }

    private func installKeyboardMonitor() {
        removeKeyboardMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let phase = app.phase

        switch event.keyCode {
        case 49: // Space
            switch phase {
            case .ready:
                app.startCountdown()
                return true
            case .recording:
                app.pauseRecording()
                return true
            case .paused:
                app.resumeRecording()
                return true
            default:
                return false
            }
        case 36: // Enter/Return
            if phase == .recording || phase == .paused || phase == .countdown {
                app.stopRecording()
                return true
            }
            return false
        case 53: // Esc
            if phase == .recording || phase == .paused || phase == .countdown || phase == .ready {
                app.cancelRecording()
                return true
            }
            return false
        default:
            return false
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, near region: CaptureRegion) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(region.globalRect) }) ?? NSScreen.main else {
            return
        }

        let size = panel.frame.size
        var x = region.globalRect.midX - size.width / 2
        x = min(max(x, screen.visibleFrame.minX + 12), screen.visibleFrame.maxX - size.width - 12)

        let belowY = region.globalRect.minY - size.height - 14
        let aboveY = region.globalRect.maxY + 14
        let y = belowY > screen.visibleFrame.minY ? belowY : min(aboveY, screen.visibleFrame.maxY - size.height - 12)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
