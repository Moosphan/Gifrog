import CoreGraphics

enum OverlayGeometry {
    enum ToolbarPlacement {
        case belowSelection
        case aboveSelection
    }

    struct ToolbarLayout {
        let origin: CGPoint
        let placement: ToolbarPlacement
    }

    static let edgePadding: CGFloat = 12
    static let toolbarGap: CGFloat = 14
    static let toolbarContentHeight: CGFloat = 56
    static let popupGap: CGFloat = 8

    static func selectionGlobalRect(localSelection: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + localSelection.minX,
            y: screenFrame.minY + localSelection.minY,
            width: localSelection.width,
            height: localSelection.height
        )
    }

    static func localSelection(globalRect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: globalRect.minX - screenFrame.minX,
            y: globalRect.minY - screenFrame.minY,
            width: globalRect.width,
            height: globalRect.height
        )
    }

    static func captureRect(globalRect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: globalRect.minX,
            y: screenFrame.maxY - globalRect.maxY,
            width: globalRect.width,
            height: globalRect.height
        )
    }

    static func screenCaptureSourceRect(globalRect: CGRect, displayFrame: CGRect) -> CGRect {
        let intersection = globalRect.intersection(displayFrame)
        let source = intersection.isNull || intersection.isEmpty ? globalRect : intersection
        return CGRect(
            x: max(0, source.minX - displayFrame.minX),
            y: max(0, displayFrame.maxY - source.maxY),
            width: min(source.width, displayFrame.width),
            height: min(source.height, displayFrame.height)
        )
    }

    static func appKitWindowRect(cgWindowBounds: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: cgWindowBounds.minX,
            y: screenFrame.maxY - cgWindowBounds.maxY,
            width: cgWindowBounds.width,
            height: cgWindowBounds.height
        )
    }

    static func normalizedPoint(globalPoint: CGPoint, in region: CGRect) -> CGPoint? {
        guard region.contains(globalPoint) else { return nil }
        return CGPoint(
            x: (globalPoint.x - region.minX) / max(region.width, 1),
            y: (region.maxY - globalPoint.y) / max(region.height, 1)
        )
    }

    static func aspectFitRect(contentSize: CGSize, containerSize: CGSize) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / contentSize.width, containerSize.height / contentSize.height)
        let width = contentSize.width * scale
        let height = contentSize.height * scale
        return CGRect(
            x: (containerSize.width - width) / 2,
            y: (containerSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    static func toolbarBottomInset(panelHeight: CGFloat) -> CGFloat {
        max(0, (panelHeight - toolbarContentHeight) / 2)
    }

    static func popupOverflowBelow(panelHeight: CGFloat, popupHeight: CGFloat?) -> CGFloat {
        guard let popupHeight else { return 0 }
        return max(0, popupHeight + popupGap - toolbarBottomInset(panelHeight: panelHeight))
    }

    static func popupFrame(
        toolbarFrame: CGRect,
        width: CGFloat,
        height: CGFloat,
        placement: ToolbarPlacement,
        screenVisibleFrame: CGRect
    ) -> CGRect {
        let toolbarBottomInset = toolbarBottomInset(panelHeight: toolbarFrame.height)
        let toolbarTopInset = toolbarFrame.height - toolbarBottomInset - toolbarContentHeight
        let x = min(
            max(toolbarFrame.midX - width / 2, screenVisibleFrame.minX + edgePadding),
            screenVisibleFrame.maxX - width - edgePadding
        )

        let y: CGFloat
        switch placement {
        case .belowSelection:
            y = toolbarFrame.minY + toolbarBottomInset - height - popupGap
        case .aboveSelection:
            y = toolbarFrame.maxY - toolbarTopInset + popupGap
        }

        let clampedY = min(
            max(y, screenVisibleFrame.minY + edgePadding),
            screenVisibleFrame.maxY - height - edgePadding
        )

        return CGRect(x: x, y: clampedY, width: width, height: height)
    }

    static func toolbarPanelOrigin(
        region: CGRect,
        screenVisibleFrame: CGRect,
        panelSize: CGSize,
        popupOverflowBelow: CGFloat
    ) -> ToolbarLayout {
        let x = min(
            max(region.midX - panelSize.width / 2, screenVisibleFrame.minX + edgePadding),
            screenVisibleFrame.maxX - panelSize.width - edgePadding
        )

        let minPanelY = screenVisibleFrame.minY + edgePadding + popupOverflowBelow
        let maxPanelY = screenVisibleFrame.maxY - panelSize.height - edgePadding

        let belowY = panelOriginYBelowSelection(region: region, panelHeight: panelSize.height)
        let aboveY = panelOriginYAboveSelection(region: region, panelHeight: panelSize.height)

        let y: CGFloat
        let placement: ToolbarPlacement
        if belowY >= minPanelY {
            y = belowY
            placement = .belowSelection
        } else if aboveY <= maxPanelY {
            y = aboveY
            placement = .aboveSelection
        } else {
            y = min(max(belowY, minPanelY), maxPanelY)
            placement = y == maxPanelY ? .aboveSelection : .belowSelection
        }

        return ToolbarLayout(origin: CGPoint(x: x, y: y), placement: placement)
    }

    private static func panelOriginYBelowSelection(region: CGRect, panelHeight: CGFloat) -> CGFloat {
        let toolbarTopInset = panelHeight - toolbarBottomInset(panelHeight: panelHeight) - toolbarContentHeight
        return region.minY - toolbarGap - toolbarContentHeight - toolbarTopInset
    }

    private static func panelOriginYAboveSelection(region: CGRect, panelHeight: CGFloat) -> CGFloat {
        region.maxY + toolbarGap - toolbarBottomInset(panelHeight: panelHeight)
    }
}
