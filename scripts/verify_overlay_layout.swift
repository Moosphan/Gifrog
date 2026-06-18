import CoreGraphics
import Foundation

@main
struct OverlayLayoutVerifier {
    static func main() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 835)

        let topLocal = CGRect(x: 240, y: 580, width: 480, height: 220)
        let topGlobal = OverlayGeometry.selectionGlobalRect(localSelection: topLocal, screenFrame: screen)
        assertRectEqual(topGlobal, topLocal, "top selection should keep bottom-left origin")
        assertRectEqual(
            OverlayGeometry.localSelection(globalRect: topGlobal, screenFrame: screen),
            topLocal,
            "selection roundtrip should be stable"
        )
        assertRectEqual(
            OverlayGeometry.captureRect(globalRect: topGlobal, screenFrame: screen),
            CGRect(x: 240, y: 100, width: 480, height: 220),
            "capture rect should convert to top-left coordinates"
        )
        assertRectEqual(
            OverlayGeometry.screenCaptureSourceRect(globalRect: topGlobal, displayFrame: screen),
            CGRect(x: 240, y: 100, width: 480, height: 220),
            "screen capture source rect should match display-local top-left coordinates"
        )
        guard let normalizedClick = OverlayGeometry.normalizedPoint(
            globalPoint: CGPoint(x: 360, y: 690),
            in: topGlobal
        ) else {
            fputs("Assertion failed: click should be inside selection\n", stderr)
            exit(1)
        }
        assertClose(normalizedClick.x, 0.25, "click normalized x should use selection-local horizontal position")
        assertClose(normalizedClick.y, 0.5, "click normalized y should use top-left video coordinates")

        let fittedWide = OverlayGeometry.aspectFitRect(
            contentSize: CGSize(width: 1516, height: 980),
            containerSize: CGSize(width: 1200, height: 760)
        )
        assertClose(fittedWide.width, 1175.673469387755, tolerance: 0.001, "wide video fit width should preserve aspect")
        assertClose(fittedWide.height, 760, "wide video fit height should fill container height")
        assertClose(fittedWide.minX, 12.163265306122469, tolerance: 0.001, "wide video fit should center horizontally")

        let fittedTall = OverlayGeometry.aspectFitRect(
            contentSize: CGSize(width: 960, height: 640),
            containerSize: CGSize(width: 1200, height: 500)
        )
        assertClose(fittedTall.width, 750, "tall container fit width should preserve aspect")
        assertClose(fittedTall.height, 500, "tall container fit height should fill container height")
        assertClose(fittedTall.minX, 225, "tall container fit should center horizontally")

        assertRectEqual(
            OverlayGeometry.appKitWindowRect(
                cgWindowBounds: CGRect(x: 178, y: 122, width: 1516, height: 980),
                screenFrame: CGRect(x: 0, y: 0, width: 1800, height: 1169)
            ),
            CGRect(x: 178, y: 67, width: 1516, height: 980),
            "CGWindow bounds should convert to AppKit global coordinates"
        )

        let secondaryScreen = CGRect(x: -1024, y: 120, width: 1024, height: 768)
        let secondaryLocal = CGRect(x: 120, y: 220, width: 500, height: 300)
        let secondaryGlobal = OverlayGeometry.selectionGlobalRect(localSelection: secondaryLocal, screenFrame: secondaryScreen)
        assertRectEqual(
            secondaryGlobal,
            CGRect(x: -904, y: 340, width: 500, height: 300),
            "secondary display selection should include screen origin"
        )
        assertRectEqual(
            OverlayGeometry.localSelection(globalRect: secondaryGlobal, screenFrame: secondaryScreen),
            secondaryLocal,
            "secondary display selection roundtrip should be stable"
        )
        assertRectEqual(
            OverlayGeometry.captureRect(globalRect: secondaryGlobal, screenFrame: secondaryScreen),
            CGRect(x: -904, y: 248, width: 500, height: 300),
            "fallback capture rect should preserve global x and top-left y"
        )
        assertRectEqual(
            OverlayGeometry.screenCaptureSourceRect(globalRect: secondaryGlobal, displayFrame: secondaryScreen),
            CGRect(x: 120, y: 248, width: 500, height: 300),
            "screen capture source rect should be local to the selected display"
        )

        let panelSize = CGSize(width: 700, height: 96)
        let layoutBelow = OverlayGeometry.toolbarPanelOrigin(
            region: topGlobal,
            screenVisibleFrame: visible,
            panelSize: panelSize,
            popupOverflowBelow: 0
        )
        let visibleToolbarTop = layoutBelow.origin.y + OverlayGeometry.toolbarBottomInset(panelHeight: panelSize.height) + OverlayGeometry.toolbarContentHeight
        assertClose(
            visibleToolbarTop,
            topGlobal.minY - OverlayGeometry.toolbarGap,
            "toolbar should stay below selection with fixed gap"
        )
        guard layoutBelow.placement == .belowSelection else {
            fputs("Assertion failed: toolbar should prefer below-selection placement\n", stderr)
            exit(1)
        }

        let bottomGlobal = CGRect(x: 240, y: 40, width: 480, height: 220)
        let layoutAbove = OverlayGeometry.toolbarPanelOrigin(
            region: bottomGlobal,
            screenVisibleFrame: visible,
            panelSize: panelSize,
            popupOverflowBelow: 24
        )
        let visibleToolbarBottom = layoutAbove.origin.y + OverlayGeometry.toolbarBottomInset(panelHeight: panelSize.height)
        assertClose(
            visibleToolbarBottom,
            bottomGlobal.maxY + OverlayGeometry.toolbarGap,
            "toolbar should flip above selection near screen bottom"
        )
        guard layoutAbove.placement == .aboveSelection else {
            fputs("Assertion failed: toolbar should flip above selection near bottom edge\n", stderr)
            exit(1)
        }

        let leftEdgeRegion = CGRect(x: 10, y: 300, width: 180, height: 180)
        let leftLayout = OverlayGeometry.toolbarPanelOrigin(
            region: leftEdgeRegion,
            screenVisibleFrame: visible,
            panelSize: panelSize,
            popupOverflowBelow: 0
        )
        assertClose(leftLayout.origin.x, visible.minX + OverlayGeometry.edgePadding, "toolbar should clamp to left edge")

        let rightEdgeRegion = CGRect(x: 1320, y: 300, width: 110, height: 180)
        let rightLayout = OverlayGeometry.toolbarPanelOrigin(
            region: rightEdgeRegion,
            screenVisibleFrame: visible,
            panelSize: panelSize,
            popupOverflowBelow: 0
        )
        assertClose(
            rightLayout.origin.x,
            visible.maxX - panelSize.width - OverlayGeometry.edgePadding,
            "toolbar should clamp to right edge"
        )

        let popupBelow = OverlayGeometry.popupFrame(
            toolbarFrame: CGRect(origin: layoutBelow.origin, size: panelSize),
            width: 220,
            height: 36,
            placement: layoutBelow.placement,
            screenVisibleFrame: visible
        )
        assertClose(
            popupBelow.maxY,
            layoutBelow.origin.y + OverlayGeometry.toolbarBottomInset(panelHeight: panelSize.height) - OverlayGeometry.popupGap,
            "popup below toolbar should sit outside selection side"
        )

        let popupAbove = OverlayGeometry.popupFrame(
            toolbarFrame: CGRect(origin: layoutAbove.origin, size: panelSize),
            width: 220,
            height: 36,
            placement: layoutAbove.placement,
            screenVisibleFrame: visible
        )
        let toolbarVisibleTop = layoutAbove.origin.y + panelSize.height - OverlayGeometry.toolbarBottomInset(panelHeight: panelSize.height)
        assertClose(
            popupAbove.minY,
            toolbarVisibleTop + OverlayGeometry.popupGap,
            "popup above toolbar should stay away from selection"
        )

        print("overlay layout verification passed")
    }

    static func assertClose(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.001, _ message: String) {
        guard abs(lhs - rhs) <= tolerance else {
            fputs("Assertion failed: \(message). expected \(rhs), got \(lhs)\n", stderr)
            exit(1)
        }
    }

    static func assertRectEqual(_ lhs: CGRect, _ rhs: CGRect, _ message: String) {
        assertClose(lhs.minX, rhs.minX, message + " minX")
        assertClose(lhs.minY, rhs.minY, message + " minY")
        assertClose(lhs.width, rhs.width, message + " width")
        assertClose(lhs.height, rhs.height, message + " height")
    }
}
