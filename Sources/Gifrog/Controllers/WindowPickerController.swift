import AppKit
import CoreGraphics
import SwiftUI

struct CapturableWindow: Identifiable {
    var id: UInt32
    var owner: String
    var title: String
    var bounds: CGRect
    var screenFrame: CGRect

    var displayName: String {
        title.isEmpty ? owner : "\(owner) - \(title)"
    }

    var captureRegion: CaptureRegion {
        CaptureRegion(
            globalRect: OverlayGeometry.appKitWindowRect(cgWindowBounds: bounds, screenFrame: screenFrame),
            captureRect: bounds,
            windowID: id
        )
    }

    static func list() -> [CapturableWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windows.compactMap { info in
            guard
                let number = info[kCGWindowNumber as String] as? UInt32,
                let owner = info[kCGWindowOwnerName as String] as? String,
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                bounds.width > 120,
                bounds.height > 80,
                (info[kCGWindowLayer as String] as? Int ?? 0) == 0
            else {
                return nil
            }

            guard let screenFrame = Self.screenFrame(for: bounds) else { return nil }
            let title = info[kCGWindowName as String] as? String ?? ""
            return CapturableWindow(id: number, owner: owner, title: title, bounds: bounds, screenFrame: screenFrame)
        }
        .prefix(40)
        .map { $0 }
    }

    private static func screenFrame(for bounds: CGRect) -> CGRect? {
        NSScreen.screens.max { left, right in
            left.frame.intersection(bounds).area < right.frame.intersection(bounds).area
        }?.frame
    }

    func thumbnail() -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(id),
            [.boundsIgnoreFraming]
        ) else { return nil }

        let size = NSSize(width: 64, height: 48)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(origin: .zero, size: size)
        NSImage(cgImage: cgImage, size: NSSize(width: bounds.width, height: bounds.height))
            .draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        image.unlockFocus()
        return image
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull && !isInfinite else { return 0 }
        return max(0, width) * max(0, height)
    }
}

final class WindowPickerController {
    private let app: GifrogController
    private var panel: NSPanel?

    init(app: GifrogController) {
        self.app = app
    }

    func show(preferredWindowID: UInt32? = nil) {
        let windows = Self.sortedWindows(preferredWindowID: preferredWindowID)
        let panel = panel ?? NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Choose Window"
        panel.contentView = NSHostingView(
            rootView: WindowPickerView(app: app, windows: windows, preferredWindowID: preferredWindowID)
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    private static func sortedWindows(preferredWindowID: UInt32?) -> [CapturableWindow] {
        let windows = CapturableWindow.list()
        guard let preferredWindowID else { return windows }
        return windows.sorted { lhs, rhs in
            if lhs.id == preferredWindowID { return true }
            if rhs.id == preferredWindowID { return false }
            return false
        }
    }
}
