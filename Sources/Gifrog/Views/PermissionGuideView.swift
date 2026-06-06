import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var app: GifrogController

    var body: some View {
        VStack(spacing: 24) {
            // App logo
            if let url = Bundle.module.url(forResource: "GifrogIcon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(spacing: 8) {
                Text("Permissions Required")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(UI.text)
                Text("Gifrog needs these permissions to capture your screen and handle shortcuts.")
                    .font(.system(size: 13))
                    .foregroundStyle(UI.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            VStack(spacing: 10) {
                permissionRow(
                    symbol: "record.circle",
                    title: "Screen Recording",
                    subtitle: "Required to capture video from your display",
                    isGranted: app.hasScreenRecordingPermission
                )
                permissionRow(
                    symbol: "keyboard",
                    title: "Accessibility",
                    subtitle: "Optional — enables global shortcut (⌥⇧G)",
                    isGranted: app.hasAccessibilityPermission
                )
            }

            VStack(spacing: 8) {
                Button {
                    app.openPermissionSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(SettingsButtonStyle())

                Button {
                    app.recheckPermission()
                } label: {
                    Text("Recheck Permissions")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(RecheckButtonStyle())
            }
        }
        .padding(28)
        .frame(width: 480, height: 520)
        .background(QuartzBackground(opacity: 0.94))
    }

    private func permissionRow(symbol: String, title: String, subtitle: String, isGranted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(isGranted ? UI.primary : UI.red)
                .frame(width: 36, height: 36)
                .background((isGranted ? UI.primary : UI.red).opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UI.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(UI.secondaryText)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(isGranted ? UI.primary : UI.red)
                Text(isGranted ? "Granted" : "Required")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isGranted ? UI.primary : UI.red)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.04)))
    }
}

// MARK: - Button Styles

private struct SettingsButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        configuration.isPressed ? UI.primaryDark :
                        isHovering ? UI.primary.opacity(0.88) : UI.primary
                    )
            )
            .shadow(color: UI.primary.opacity(isHovering ? 0.25 : 0.18), radius: isHovering ? 8 : 6, y: isHovering ? 3 : 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .onHover { isHovering = $0 }
    }
}

private struct RecheckButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovering ? UI.text : UI.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.black.opacity(0.08) :
                          isHovering ? Color.black.opacity(0.05) : Color.clear)
            )
            .onHover { isHovering = $0 }
    }
}
