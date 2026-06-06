import AppKit
import Carbon.HIToolbox

final class RegionSelectionController {
    private var windows: [NSWindow] = []
    private var selectionViews: [RegionSelectionView] = []
    private var eventMonitor: Any?

    func show(
        initialRegion: CaptureRegion? = nil,
        onSelectionChanged: @escaping (CaptureRegion) -> Void,
        onComplete: @escaping (CaptureRegion) -> Void
    ) {
        close()
        guard !NSScreen.screens.isEmpty else { return }

        windows = NSScreen.screens.map { screen in
            let view = RegionSelectionView(
                screen: screen,
                initialRegion: initialRegion,
                onSelectionChanged: onSelectionChanged,
                onComplete: { [weak self] region in
                    self?.close()
                    onComplete(region)
                },
                onCancel: { [weak self] in
                    self?.close()
                }
            )
            selectionViews.append(view)

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.contentView = view
            return window
        }

        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSCursor.crosshair.set()

        // Notify initial selection immediately
        if let region = selectionViews.first?.currentCaptureRegion {
            onSelectionChanged(region)
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if event.keyCode == 53 { // Esc
                self.close()
            }
        }
    }

    func close() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        selectionViews.forEach { $0.stopAnimation() }
        selectionViews = []
        windows.forEach { $0.orderOut(nil) }
        windows = []
        NSCursor.arrow.set()
    }
}

// MARK: - Selection View

final class RegionSelectionView: NSView {
    private let screen: NSScreen
    private let onSelectionChanged: (CaptureRegion) -> Void
    private let onComplete: (CaptureRegion) -> Void
    private let onCancel: () -> Void

    private var selection: NSRect?
    private var isDraggingNew = false
    private var dragHandle: Handle = .none
    private var dragStart: NSPoint = .zero
    private var dragOriginalRect: NSRect = .zero

    private var marchingPhase: CGFloat = 0
    private var displayLink: CVDisplayLink?

    private let minSize: CGFloat = 40
    private let handleSize: CGFloat = 10
    private let defaultSize = NSSize(width: 480, height: 320)

    enum Handle {
        case none, move
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    init(
        screen: NSScreen,
        initialRegion: CaptureRegion?,
        onSelectionChanged: @escaping (CaptureRegion) -> Void,
        onComplete: @escaping (CaptureRegion) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screen = screen
        self.onSelectionChanged = onSelectionChanged
        self.onComplete = onComplete
        self.onCancel = onCancel
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true

        if let region = initialRegion, screen.frame.intersects(region.globalRect) {
            let local = NSRect(
                x: region.globalRect.minX - screen.frame.minX,
                y: screen.frame.maxY - region.globalRect.maxY,
                width: region.globalRect.width,
                height: region.globalRect.height
            )
            selection = local
        } else {
            let x = (frame.width - defaultSize.width) / 2
            let y = (frame.height - defaultSize.height) / 2
            selection = NSRect(x: x, y: y, width: defaultSize.width, height: defaultSize.height)
        }

        startMarchingAnts()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    deinit { stopAnimation() }

    func stopAnimation() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    /// Returns the current selection as a CaptureRegion (global coordinates)
    var currentCaptureRegion: CaptureRegion? {
        guard let sel = selection, sel.width >= minSize, sel.height >= minSize else { return nil }
        return toCaptureRegion(sel)
    }

    private func toCaptureRegion(_ sel: NSRect) -> CaptureRegion {
        let global = CGRect(
            x: screen.frame.minX + sel.minX,
            y: screen.frame.minY + (screen.frame.height - sel.maxY),
            width: sel.width,
            height: sel.height
        )
        let capture = CGRect(
            x: global.minX,
            y: screen.frame.maxY - global.maxY,
            width: global.width,
            height: global.height
        )
        return CaptureRegion(globalRect: global, captureRect: capture)
    }

    // MARK: - Marching Ants

    private func startMarchingAnts() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, context -> CVReturn in
            guard let context else { return kCVReturnSuccess }
            let view = Unmanaged<RegionSelectionView>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                view.marchingPhase += 0.5
                view.needsDisplay = true
            }
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.30).setFill()
        bounds.fill()

        guard let sel = selection else { return }

        // Clear selection area
        NSColor.black.withAlphaComponent(0.45).setFill()
        let dimPath = NSBezierPath(rect: bounds)
        dimPath.append(NSBezierPath(rect: sel))
        dimPath.windingRule = .evenOdd
        dimPath.fill()

        // Marching ants
        let borderPath = NSBezierPath(rect: sel)
        borderPath.lineWidth = 1.5
        borderPath.setLineDash([6, 4], count: 2, phase: marchingPhase)
        NSColor.white.setStroke()
        borderPath.stroke()

        // Solid inner border
        let innerPath = NSBezierPath(rect: sel)
        innerPath.lineWidth = 1
        NSColor.white.withAlphaComponent(0.4).setStroke()
        innerPath.stroke()

        drawHandles(for: sel)
        drawSizeLabel(for: sel)
    }

    private func drawHandles(for rect: NSRect) {
        let points: [NSPoint] = [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.midX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.minX, y: rect.midY),
            NSPoint(x: rect.maxX, y: rect.midY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.midX, y: rect.maxY),
            NSPoint(x: rect.maxX, y: rect.maxY),
        ]
        for p in points {
            let r = NSRect(x: p.x - handleSize / 2, y: p.y - handleSize / 2, width: handleSize, height: handleSize)
            let path = NSBezierPath(roundedRect: r, xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            path.fill()
            NSColor.systemGreen.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    private func drawSizeLabel(for rect: NSRect) {
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        let lx = rect.midX - size.width / 2
        let ly = rect.maxY + 8
        let pad: CGFloat = 6
        let bg = NSRect(x: lx - pad, y: ly - 2, width: size.width + pad * 2, height: size.height + 4)
        NSBezierPath(roundedRect: bg, xRadius: 4, yRadius: 4).fill()
        (label as NSString).draw(at: NSPoint(x: lx, y: ly), withAttributes: attrs)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let sel = selection {
            dragHandle = hitTestHandle(point: point, rect: sel)
            if dragHandle == .none {
                isDraggingNew = true
                selection = NSRect(origin: point, size: .zero)
            }
            dragStart = point
            dragOriginalRect = sel
        } else {
            isDraggingNew = true
            selection = NSRect(origin: point, size: .zero)
            dragStart = point
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isDraggingNew {
            selection = NSRect(
                x: min(dragStart.x, point.x),
                y: min(dragStart.y, point.y),
                width: abs(point.x - dragStart.x),
                height: abs(point.y - dragStart.y)
            )
        } else if dragHandle != .none {
            selection = resize(rect: dragOriginalRect, handle: dragHandle, to: point)
        }
        notifySelectionChanged()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingNew = false
        if let sel = selection, (sel.width < minSize || sel.height < minSize) {
            selection = nil
        }
        let point = convert(event.locationInWindow, from: nil)
        updateCursor(point: point)
        notifySelectionChanged()
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(point: convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel()
        }
    }

    private func notifySelectionChanged() {
        guard let region = currentCaptureRegion else { return }
        onSelectionChanged(region)
    }

    // MARK: - Hit Testing & Resize

    private func hitTestHandle(point: NSPoint, rect: NSRect) -> Handle {
        let hs = handleSize * 1.5
        let handles: [(Handle, NSPoint)] = [
            (.topLeft, NSPoint(x: rect.minX, y: rect.maxY)),
            (.topRight, NSPoint(x: rect.maxX, y: rect.maxY)),
            (.bottomLeft, NSPoint(x: rect.minX, y: rect.minY)),
            (.bottomRight, NSPoint(x: rect.maxX, y: rect.minY)),
            (.top, NSPoint(x: rect.midX, y: rect.maxY)),
            (.bottom, NSPoint(x: rect.midX, y: rect.minY)),
            (.left, NSPoint(x: rect.minX, y: rect.midY)),
            (.right, NSPoint(x: rect.maxX, y: rect.midY)),
        ]
        for (handle, hp) in handles {
            if abs(point.x - hp.x) < hs && abs(point.y - hp.y) < hs {
                return handle
            }
        }
        if rect.contains(point) { return .move }
        return .none
    }

    private func resize(rect: NSRect, handle: Handle, to point: NSPoint) -> NSRect {
        var r = rect
        switch handle {
        case .topLeft:
            r.origin.x = min(point.x, rect.maxX - minSize)
            r.size.width = rect.maxX - r.origin.x
            r.origin.y = min(point.y, rect.maxY - minSize)
            r.size.height = rect.maxY - r.origin.y
        case .topRight:
            r.size.width = max(minSize, point.x - rect.minX)
            r.origin.y = min(point.y, rect.maxY - minSize)
            r.size.height = rect.maxY - r.origin.y
        case .bottomLeft:
            r.origin.x = min(point.x, rect.maxX - minSize)
            r.size.width = rect.maxX - r.origin.x
            r.size.height = max(minSize, point.y - rect.minY)
        case .bottomRight:
            r.size.width = max(minSize, point.x - rect.minX)
            r.size.height = max(minSize, point.y - rect.minY)
        case .top:
            r.origin.y = min(point.y, rect.maxY - minSize)
            r.size.height = rect.maxY - r.origin.y
        case .bottom:
            r.size.height = max(minSize, point.y - rect.minY)
        case .left:
            r.origin.x = min(point.x, rect.maxX - minSize)
            r.size.width = rect.maxX - r.origin.x
        case .right:
            r.size.width = max(minSize, point.x - rect.minX)
        case .move:
            r = NSRect(x: rect.origin.x + point.x - dragStart.x, y: rect.origin.y + point.y - dragStart.y, width: rect.width, height: rect.height)
        case .none:
            break
        }
        return r
    }

    private func updateCursor(point: NSPoint) {
        guard let sel = selection else { NSCursor.crosshair.set(); return }
        switch hitTestHandle(point: point, rect: sel) {
        case .top, .bottom: NSCursor.resizeUpDown.set()
        case .left, .right: NSCursor.resizeLeftRight.set()
        case .move: NSCursor.openHand.set()
        default: NSCursor.crosshair.set()
        }
    }
}
