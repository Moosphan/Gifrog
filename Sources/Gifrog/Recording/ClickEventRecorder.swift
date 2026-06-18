import AppKit
import Foundation

final class ClickEventRecorder {
    private var monitors: [Any] = []
    private var region: CaptureRegion?
    private var startedAt: Date?
    private var pausedAt: Date?
    private var pausedDuration: TimeInterval = 0
    private(set) var events: [ClickEvent] = []

    var isActive: Bool {
        startedAt != nil
    }

    func start(region: CaptureRegion) {
        stop()
        self.region = region
        self.startedAt = Date()
        self.pausedAt = nil
        self.pausedDuration = 0
        self.events = []

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] event in
            self?.record(event)
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] event in
            self?.record(event)
            return event
        }) {
            monitors.append(monitor)
        }
    }

    func pause() {
        if pausedAt == nil {
            pausedAt = Date()
        }
    }

    func resume() {
        if let pausedAt {
            pausedDuration += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        }
    }

    @discardableResult
    func stop() -> [ClickEvent] {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        region = nil
        startedAt = nil
        pausedAt = nil
        pausedDuration = 0
        let recorded = events
        events = []
        return recorded
    }

    private func record(_ event: NSEvent) {
        guard let region, let startedAt, pausedAt == nil else { return }

        let location = Self.screenLocation(for: event)
        guard let normalized = OverlayGeometry.normalizedPoint(globalPoint: location, in: region.globalRect) else { return }
        let elapsed = Date().timeIntervalSince(startedAt) - pausedDuration

        let button: ClickEvent.Button
        switch event.type {
        case .leftMouseDown: button = .left
        case .rightMouseDown: button = .right
        default: button = .other
        }

        events.append(
            ClickEvent(
                time: max(0, elapsed),
                normalizedX: min(max(Double(normalized.x), 0), 1),
                normalizedY: min(max(Double(normalized.y), 0), 1),
                button: button
            )
        )
    }

    private static func screenLocation(for event: NSEvent) -> CGPoint {
        // Global and local mouse monitors report `locationInWindow` in different
        // coordinate spaces. `mouseLocation` is consistently in AppKit screen
        // coordinates, which is the same space as CaptureRegion.globalRect.
        NSEvent.mouseLocation
    }
}
