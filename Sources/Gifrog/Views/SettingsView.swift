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
                HStack(spacing: 2) {
                    ForEach(ExportFormat.allCases) { format in
                        choiceButton(format.rawValue, selected: app.settings.defaultFormat == format) {
                            app.settings.defaultFormat = format
                            app.saveSettings()
                        }
                    }
                }
                .padding(3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            optionRow("Quality") {
                HStack(spacing: 8) {
                    ForEach(QualityPreset.allCases) { preset in
                        choiceButton(preset.rawValue, selected: app.settings.quality == preset) {
                            applyQualityPreset(preset)
                        }
                    }
                }
            }

            optionRow("Default FPS") {
                HStack(spacing: 2) {
                    ForEach([10, 15, 24, 30], id: \.self) { fps in
                        choiceButton("\(fps)", selected: app.settings.defaultFPS == fps) {
                            app.settings.defaultFPS = fps
                            app.saveSettings()
                        }
                    }
                }
                .padding(3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            optionRow("Default Scale") {
                HStack(spacing: 8) {
                    ForEach([1.0, 0.75, 0.5], id: \.self) { scale in
                        choiceButton("\(Int(scale * 100))%", selected: app.settings.defaultScale == scale) {
                            app.settings.defaultScale = scale
                            app.saveSettings()
                        }
                    }
                }
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
        Button {
            tab = title
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .foregroundStyle(tab == title ? UI.primaryDark : UI.secondaryText)
                .background(tab == title ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(tab == title ? 0.08 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
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

    private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? UI.primaryDark : UI.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(selected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(selected ? UI.primary : UI.outline.opacity(0.0), lineWidth: selected ? 1.5 : 0)
                )
                .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
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
