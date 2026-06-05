import AppKit
import Carbon.HIToolbox

final class RegionSelectionController {
    private var windows: [NSWindow] = []

    func show(onComplete: @escaping (CaptureRegion) -> Void) {
        close()
        guard !NSScreen.screens.isEmpty else { return }

        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.contentView = RegionSelectionView(
                screen: screen,
                completion: { [weak self] region in
                    self?.close()
                    onComplete(region)
                },
                cancellation: { [weak self] in
                    self?.close()
                }
            )
            return window
        }

        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSCursor.crosshair.set()
    }

    private func close() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        NSCursor.arrow.set()
    }
}

final class RegionSelectionView: NSView {
    private let screen: NSScreen
    private let completion: (CaptureRegion) -> Void
    private let cancellation: () -> Void
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    init(screen: NSScreen, completion: @escaping (CaptureRegion) -> Void, cancellation: @escaping () -> Void) {
        self.screen = screen
        self.completion = completion
        self.cancellation = cancellation
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard let selection = normalizedSelection else { return }

        NSColor.black.withAlphaComponent(0.40).setFill()
        let path = NSBezierPath(rect: bounds)
        path.append(NSBezierPath(rect: selection))
        path.windingRule = .evenOdd
        path.fill()

        NSColor.systemGreen.setStroke()
        let stroke = NSBezierPath(roundedRect: selection, xRadius: 10, yRadius: 10)
        stroke.lineWidth = 3
        stroke.stroke()

        let label = "\(Int(selection.width)) x \(Int(selection.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.58)
        ]
        label.draw(at: NSPoint(x: selection.minX + 10, y: selection.maxY + 8), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let selection = normalizedSelection, selection.width > 24, selection.height > 24 else {
            needsDisplay = true
            return
        }

        let global = CGRect(
            x: screen.frame.minX + selection.minX,
            y: screen.frame.minY + selection.minY,
            width: selection.width,
            height: selection.height
        )
        let capture = CGRect(
            x: global.minX,
            y: screen.frame.maxY - global.maxY,
            width: global.width,
            height: global.height
        )
        completion(CaptureRegion(globalRect: global, captureRect: capture))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            cancellation()
        }
    }

    private var normalizedSelection: NSRect? {
        guard let startPoint, let currentPoint else { return nil }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }
}
