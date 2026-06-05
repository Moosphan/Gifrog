import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var app: GifrogController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(UI.red).frame(width: 12, height: 12)
                Circle().fill(Color.yellow).frame(width: 12, height: 12)
                Circle().fill(UI.primary).frame(width: 12, height: 12)
                Spacer()
                Text("Gifrog")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Color.clear.frame(width: 50)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
            }

            VStack(spacing: 22) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white)
                        .frame(width: 96, height: 96)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    Image(systemName: "sparkles")
                        .foregroundStyle(UI.red)
                        .offset(x: 7, y: -7)
                    Image(systemName: "record.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(UI.primary)
                }

                VStack(spacing: 8) {
                    Text("Action Required")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(UI.primaryDark)
                    Text("Gifrog needs Screen Recording permission before it can capture your display.")
                        .font(.system(size: 15))
                        .foregroundStyle(UI.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                VStack(spacing: 12) {
                    permissionRow(
                        symbol: "record.circle",
                        title: "Screen Recording",
                        subtitle: "Capture video from your display",
                        state: "Required",
                        color: UI.red
                    )
                    permissionRow(
                        symbol: "keyboard",
                        title: "Accessibility",
                        subtitle: "Allow global shortcut handling",
                        state: "Optional",
                        color: UI.primary
                    )
                }

                VStack(spacing: 8) {
                    Button {
                        app.openPermissionSettings()
                    } label: {
                        Label("Open System Settings", systemImage: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(UI.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button("Recheck Permission") {
                        app.recheckPermission()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(UI.secondaryText)
                    .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 600)
        .background(QuartzBackground(opacity: 0.94))
    }

    private func permissionRow(symbol: String, title: String, subtitle: String, state: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.10))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(UI.secondaryText)
            }
            Spacer()
            Text(state)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
            Circle().fill(color).frame(width: 9, height: 9)
        }
        .padding(14)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.03)))
    }
}
