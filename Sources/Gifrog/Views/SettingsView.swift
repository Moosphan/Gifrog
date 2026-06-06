import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: GifrogController
    @State private var tab: String

    init(app: GifrogController, initialTab: String = "General") {
        self.app = app
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                tabButton("General", "slider.horizontal.3")
                tabButton("Shortcuts", "keyboard")
                tabButton("Advanced", "terminal")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
            }

            ScrollView {
                currentTab
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 420, height: 520)
        .background(QuartzBackground(opacity: 0.94))
    }

    @ViewBuilder
    private var currentTab: some View {
        switch tab {
        case "Shortcuts":
            shortcutsTab
        case "Advanced":
            advancedTab
        default:
            generalTab
        }
    }

    private var generalTab: some View {
        VStack(spacing: 18) {
            settingsCheckRow("Launch at login", isOn: Binding(
                get: { app.settings.launchAtLogin },
                set: { app.setLaunchAtLogin($0) }
            ))
            settingsCheckRow("Show mouse cursor", isOn: Binding(
                get: { app.settings.showMouseCursor },
                set: { app.settings.showMouseCursor = $0; app.saveSettings() }
            ))
            settingsCheckRow("Highlight clicks", isOn: Binding(
                get: { app.settings.highlightClicks },
                set: { app.settings.highlightClicks = $0; app.saveSettings() }
            ))

            Divider()
            savePathSection
        }
    }

    private var shortcutsTab: some View {
        VStack(spacing: 18) {
            valueRow("Global shortcut", value: app.settings.shortcut, symbol: "keyboard")
            stepperRow(
                title: "Countdown",
                value: app.settings.countdownSeconds,
                unit: "s",
                range: 0...10
            ) { value in
                app.settings.countdownSeconds = value
                app.saveSettings()
            }
        }
    }

    private var advancedTab: some View {
        VStack(spacing: 18) {
            optionRow("Default Format") {
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { ExportFormat.allCases.firstIndex(of: app.settings.defaultFormat) ?? 0 },
                        set: { app.settings.defaultFormat = ExportFormat.allCases[$0]; app.saveSettings() }
                    ),
                    labels: ExportFormat.allCases.map(\.rawValue),
                    inset: true
                )
            }

            optionRow("Quality") {
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { QualityPreset.allCases.firstIndex(of: app.settings.quality) ?? 0 },
                        set: { applyQualityPreset(QualityPreset.allCases[$0]) }
                    ),
                    labels: QualityPreset.allCases.map(\.rawValue),
                    inset: false
                )
            }

            optionRow("Default FPS") {
                let fpsOptions = [10, 15, 24, 30]
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { fpsOptions.firstIndex(of: app.settings.defaultFPS) ?? 0 },
                        set: { app.settings.defaultFPS = fpsOptions[$0]; app.saveSettings() }
                    ),
                    labels: fpsOptions.map(String.init),
                    inset: true
                )
            }

            optionRow("Default Scale") {
                let scaleOptions = [1.0, 0.75, 0.5]
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { scaleOptions.firstIndex(of: app.settings.defaultScale) ?? 0 },
                        set: { app.settings.defaultScale = scaleOptions[$0]; app.saveSettings() }
                    ),
                    labels: scaleOptions.map { "\(Int($0 * 100))%" },
                    inset: false
                )
            }

            Divider()
            settingsCheckRow("Auto check updates", isOn: Binding(
                get: { app.settings.autoCheckUpdates },
                set: { app.settings.autoCheckUpdates = $0; app.saveSettings() }
            ))
            settingsCheckRow("Anonymous usage stats", isOn: Binding(
                get: { app.settings.anonymousUsageStats },
                set: { app.settings.anonymousUsageStats = $0; app.saveSettings() }
            ))
        }
    }

    private var savePathSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save path")
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(UI.secondaryText)
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                        .foregroundStyle(UI.secondaryText)
                    Text(app.settings.savePath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(UI.text)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(UI.outline))
                Button {
                    chooseSavePath()
                } label: {
                    Text("Browse...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UI.text)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(UI.outline))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tabButton(_ title: String, _ symbol: String) -> some View {
        SettingsTabButton(title: title, symbol: symbol, isActive: tab == title) {
            tab = title
        }
    }

    private func settingsCheckRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? UI.primary : UI.outline)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(UI.text)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
        }
        .buttonStyle(.plain)
    }

    private func valueRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(UI.primary)
                .frame(width: 28, height: 28)
                .background(UI.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(UI.text)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(UI.secondaryText)
        }
        .frame(height: 34)
    }

    private func stepperRow(title: String, value: Int, unit: String, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(UI.text)
            Spacer()
            HStack(spacing: 8) {
                Button {
                    onChange(max(range.lowerBound, value - 1))
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(IconButtonStyle())
                Text("\(value)\(unit)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(UI.primaryDark)
                    .frame(width: 44)
                Button {
                    onChange(min(range.upperBound, value + 1))
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(IconButtonStyle())
            }
        }
        .frame(height: 34)
    }

    private func optionRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(UI.secondaryText)
            content()
        }
    }

    private func applyQualityPreset(_ preset: QualityPreset) {
        app.settings.quality = preset
        switch preset {
        case .small:
            app.settings.defaultFPS = 10
            app.settings.defaultScale = 0.5
        case .balanced:
            app.settings.defaultFPS = 15
            app.settings.defaultScale = 0.75
        case .high:
            app.settings.defaultFPS = 30
            app.settings.defaultScale = 1.0
        }
        app.saveSettings()
    }

    private func chooseSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                app.settings.savePath = url.path
                app.saveSettings()
            }
        }
    }
}

// MARK: - Sliding Choice Group

struct SlidingChoiceGroup: View {
    @Binding var selection: Int
    let labels: [String]
    var inset: Bool = false
    var height: CGFloat = 30
    var cornerRadius: CGFloat = 6

    private var spacing: CGFloat { inset ? 2 : 8 }

    var body: some View {
        let group = ZStack(alignment: .topLeading) {
            // Sliding indicator (background — only offset is animated)
            ChoiceIndicator(
                selection: CGFloat(selection),
                count: labels.count,
                spacing: spacing,
                height: height,
                cornerRadius: cornerRadius
            )

            // Choices (top layer — full area is clickable)
            HStack(spacing: spacing) {
                ForEach(labels.indices, id: \.self) { index in
                    Text(labels[index])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == index ? UI.primaryDark : UI.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = index }
                }
            }
        }
        .contentShape(Rectangle())

        if inset {
            group
                .padding(3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            group
        }
    }
}

private struct ChoiceIndicator: View {
    let selection: CGFloat
    let count: Int
    let spacing: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let n = CGFloat(count)
            let segWidth = (geo.size.width - spacing * (n - 1)) / n

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(UI.primary, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                .frame(width: segWidth, height: height)
                .offset(x: selection * (segWidth + spacing))
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selection)
    }
}

// MARK: - Settings Tab Button

private struct SettingsTabButton: View {
    let title: String
    let symbol: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .foregroundStyle(isActive ? UI.primaryDark : UI.secondaryText)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isActive ? Color.white :
                            isHovering ? Color.black.opacity(0.06) : Color.clear
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(isActive ? 0.08 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
