import CoreGraphics
import Foundation

@main
struct ClickMappingVerifier {
    static func main() {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let cgWindow = CGRect(x: 178, y: 122, width: 1516, height: 980)
        let appKitWindow = OverlayGeometry.appKitWindowRect(cgWindowBounds: cgWindow, screenFrame: screen)

        guard let normalized = OverlayGeometry.normalizedPoint(
            globalPoint: CGPoint(x: 810, y: 408),
            in: appKitWindow
        ) else {
            fputs("FAIL: expected click to be inside converted window rect\n", stderr)
            exit(1)
        }

        expectClose(normalized.x * cgWindow.width, 632, "x should map into video pixel space")
        expectClose(normalized.y * cgWindow.height, 639, "y should map into video pixel space")

        let legacySavedY = CGFloat(0.523992559458609) * cgWindow.height
        guard normalized.y * cgWindow.height - legacySavedY > 100 else {
            fputs("FAIL: fixture should demonstrate legacy y offset\n", stderr)
            exit(1)
        }
    }

    private static func expectClose(_ actual: CGFloat, _ expected: CGFloat, _ message: String, tolerance: CGFloat = 1.0) {
        if abs(actual - expected) > tolerance {
            fputs("FAIL: \(message). expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }
}
