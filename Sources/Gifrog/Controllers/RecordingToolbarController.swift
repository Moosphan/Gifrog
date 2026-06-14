import AppKit
import SwiftUI

final class RecordingToolbarController {
    final class PopupOptionBarState: ObservableObject {
        @Published var labels: [String] = []
        @Published var selectedIndex: Int = 0
    }

    private let app: GifrogController
    private let popupState = PopupOptionBarState()
    private var panel: NSPanel?
    private var popupPanel: NSPanel?
    private var activePopupType: PopupType?
    private var toolbarPlacement: OverlayGeometry.ToolbarPlacement = .belowSelection
    private var eventMonitor: Any?

    init(app: GifrogController) {
        self.app = app
    }

    func show(near region: CaptureRegion) {
        let panel = ensurePanel()
        panel.contentView = NSHostingView(rootView: toolbarView)
        position(panel, near: region)
        syncPopupPosition()
        panel.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
        installKeyboardMonitor()
    }

    func showFinished(near region: CaptureRegion?) {
        guard let region else { return }
        show(near: region)
    }

    func refresh() {
        if app.phase == .recording {
            dismissPopup(refreshToolbar: false)
        }
        panel?.contentView = NSHostingView(rootView: toolbarView)
        syncPopupPosition()
    }

    func hide() {
        dismissPopup(refreshToolbar: false)
        panel?.orderOut(nil)
        removeKeyboardMonitor()
    }

    // MARK: - Popup Panel

    enum PopupType { case fps, format }

    private func togglePopup(_ type: PopupType) {
        if activePopupType == type {
            dismissPopup()
            return
        }
        presentPopup(type)
    }

    private func presentPopup(_ type: PopupType) {
        guard let toolbar = panel else { return }
        let labels: [String]
        let selectedIndex: Int
        switch type {
        case .fps:
            labels = ["10", "15", "24", "30"]
            selectedIndex = [10, 15, 24, 30].firstIndex(of: app.settings.defaultFPS) ?? 1
        case .format:
            labels = ExportFormat.allCases.map(\.rawValue)
            selectedIndex = ExportFormat.allCases.firstIndex(of: app.settings.defaultFormat) ?? 0
        }
        let popupHeight: CGFloat = 36
        let popup = ensurePopupPanel(for: type)
        popupPanel = popup
        activePopupType = type
        popupState.labels = labels
        popupState.selectedIndex = selectedIndex
        if let region = app.activeCaptureRegion {
            position(toolbar, near: region)
        }
        let popupWidth: CGFloat = CGFloat(labels.count) * 48 + 10
        popup.setFrame(popupFrame(for: toolbar.frame, width: popupWidth, height: popupHeight), display: true)
        attachPopup(popup, to: toolbar)
        popup.orderFront(nil)
        refresh()
    }

    private func dismissPopup(refreshToolbar: Bool = true) {
        if let popupPanel {
            detachPopupFromToolbar(popupPanel)
            popupPanel.orderOut(nil)
        }
        activePopupType = nil
        if refreshToolbar {
            refresh()
        }
    }

    private var toolbarView: RecordingToolbarView {
        RecordingToolbarView(
            app: app,
            activePopupType: activePopupType,
            onTogglePopup: { [weak self] type in self?.togglePopup(type) },
            onDismissPopup: { [weak self] in self?.dismissPopup() }
        )
    }

    private func syncPopupPosition() {
        guard let popupPanel, let toolbar = panel else { return }
        popupPanel.setFrame(
            popupFrame(
                for: toolbar.frame,
                width: popupPanel.frame.width,
                height: popupPanel.frame.height
            ),
            display: true
        )
    }

    private func ensurePopupPanel(for type: PopupType) -> NSPanel {
        if let popupPanel {
            popupPanel.contentView = NSHostingView(rootView: popupView(for: type))
            return popupPanel
        }

        let popup = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        popup.isOpaque = false
        popup.backgroundColor = .clear
        popup.hasShadow = false
        popup.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        popup.contentView = NSHostingView(rootView: popupView(for: type))
        popupPanel = popup
        return popup
    }

    private func popupView(for type: PopupType) -> PopupOptionBar {
        PopupOptionBar(
            state: popupState,
            onSelect: { [weak self] index in
                guard let self else { return }
                switch type {
                case .fps:
                    self.app.settings.defaultFPS = [10, 15, 24, 30][index]
                case .format:
                    self.app.settings.defaultFormat = ExportFormat.allCases[index]
                }
                self.app.saveSettings()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    self.popupState.selectedIndex = index
                }
            }
        )
    }

    private func attachPopup(_ popup: NSPanel, to toolbar: NSPanel) {
        detachPopupFromToolbar(popup)
        toolbar.addChildWindow(popup, ordered: .below)
    }

    private func detachPopupFromToolbar(_ popup: NSPanel) {
        popup.parent?.removeChildWindow(popup)
    }

    private func popupFrame(for toolbarFrame: NSRect, width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(toolbarFrame) }) ?? NSScreen.main else {
            return OverlayGeometry.popupFrame(
                toolbarFrame: toolbarFrame,
                width: width,
                height: height,
                placement: toolbarPlacement,
                screenVisibleFrame: toolbarFrame.insetBy(dx: -1000, dy: -1000)
            )
        }
        return OverlayGeometry.popupFrame(
            toolbarFrame: toolbarFrame,
            width: width,
            height: height,
            placement: toolbarPlacement,
            screenVisibleFrame: screen.visibleFrame
        )
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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
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
        let layout = OverlayGeometry.toolbarPanelOrigin(
            region: region.globalRect,
            screenVisibleFrame: screen.visibleFrame,
            panelSize: size,
            popupOverflowBelow: activePopupOverflowBelow
        )
        toolbarPlacement = layout.placement
        panel.setFrameOrigin(layout.origin)
    }

    private var activePopupOverflowBelow: CGFloat {
        OverlayGeometry.popupOverflowBelow(panelHeight: panel?.frame.height ?? 96, popupHeight: activePopupType == nil ? nil : popupPanel?.frame.height ?? 36)
    }
}
