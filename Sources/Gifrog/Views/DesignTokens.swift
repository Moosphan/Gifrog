import AppKit
import SwiftUI

enum UI {
    static let primary = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let primaryDark = Color(red: 0.0, green: 0.318, blue: 0.212)
    static let surface = Color(red: 0.965, green: 0.980, blue: 0.961)
    static let surfaceLow = Color(red: 0.945, green: 0.961, blue: 0.937)
    static let outline = Color(red: 0.839, green: 0.859, blue: 0.839)
    static let text = Color(red: 0.098, green: 0.114, blue: 0.102)
    static let secondaryText = Color(red: 0.247, green: 0.286, blue: 0.263)
    static let red = Color(red: 1.0, green: 0.392, blue: 0.208)
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

struct QuartzBackground: View {
    var material: NSVisualEffectView.Material = .popover
    var opacity: Double = 0.94

    var body: some View {
        ZStack {
            VisualEffect(material: material)
            UI.surface.opacity(opacity)
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(UI.secondaryText)
            .background(configuration.isPressed ? Color.black.opacity(0.08) : Color.black.opacity(0.001))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct PrimaryCircleButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(color)
            .clipShape(Circle())
            .shadow(color: color.opacity(0.18), radius: 7, y: 2)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct PrimaryRoundedButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: color.opacity(0.18), radius: 7, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct EditorGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(UI.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(configuration.isPressed ? UI.surfaceLow : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

func timeString(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
