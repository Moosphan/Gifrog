import AppKit
import Foundation

@main
struct ClickHighlightStyleVerifier {
    static func main() {
        expectClose(ClickHighlightStyle.spriteSize, 26, "sprite canvas should be half of the previous 52pt size")
        expectClose(ClickHighlightStyle.circleRadius, 7.5, "visible circle radius should be half of the previous 15pt radius")
        expectClose(ClickHighlightStyle.circleRadius * 2, 15, "visible circle diameter should be 15pt")

        guard ClickHighlightStyle.spriteSize > ClickHighlightStyle.circleRadius * 2 else {
            fputs("FAIL: sprite canvas must leave transparent padding around the visible circle\n", stderr)
            exit(1)
        }

        let fill = rgb(ClickHighlightStyle.fillColor)
        let stroke = rgb(ClickHighlightStyle.strokeColor)
        let contrastStroke = rgb(ClickHighlightStyle.contrastStrokeColor)
        expectClose(fill.red, 1, "fill should stay white to match preview")
        expectClose(fill.green, 1, "fill should stay white to match preview")
        expectClose(fill.blue, 1, "fill should stay white to match preview")
        expectClose(stroke.red, 1, "inner stroke should stay white to match preview")
        expectClose(contrastStroke.red, 0, "outer contrast stroke should stay black")

        print("click highlight style verification passed")
    }

    private static func expectClose(_ actual: CGFloat, _ expected: CGFloat, _ message: String, tolerance: CGFloat = 0.001) {
        if abs(actual - expected) > tolerance {
            fputs("FAIL: \(message). expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }

    private static func rgb(_ color: NSColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        guard let converted = color.usingColorSpace(.sRGB) else {
            fputs("FAIL: expected color to convert to sRGB\n", stderr)
            exit(1)
        }
        return (converted.redComponent, converted.greenComponent, converted.blueComponent)
    }
}
