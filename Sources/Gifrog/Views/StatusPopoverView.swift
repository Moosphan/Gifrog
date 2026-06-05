import SwiftUI
import UniformTypeIdentifiers

struct StatusPopoverView: View {
    @ObservedObject var app: GifrogController
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            captureModeHeader
            recordSection
            recentsSection
            footer
        }
        .frame(width: 320)
        .background(QuartzBackground(opacity: 0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
        )
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(UI.primary.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(UI.primary, lineWidth: 2)
                    )
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
            app.importDroppedFiles(providers)
        }
    }

    private var captureModeHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(CaptureMode.allCases) { mode in
                    Button {
                        app.selectedMode = mode
                    } label: {
                        VStack(spacing: 1) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 15, weight: .medium))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(app.selectedMode == mode ? UI.primary : UI.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(app.selectedMode == mode ? Color.white : Color.clear)
                                .shadow(color: .black.opacity(app.selectedMode == mode ? 0.10 : 0), radius: 3, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(12)
        .background(Color.white.opacity(0.20))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.05)).frame(height: 1)
        }
    }

    private var recordSection: some View {
        VStack(spacing: 8) {
            Button {
                app.startCaptureFlow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                    Text("Record \(app.selectedMode.rawValue)")
                    Spacer()
                    Text("\(app.settings.defaultFPS) FPS")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .opacity(0.85)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(UI.primary)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: UI.primary.opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.plain)

            if let message = app.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(UI.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var recentsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recents")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(UI.secondaryText)
                Spacer()
                Button {
                    app.importVideo()
                } label: {
                    Label("Import", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(UI.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if app.projects.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "film")
                                .font(.system(size: 24))
                                .foregroundStyle(UI.primary.opacity(0.6))
                            Text("No captures yet")
                                .font(.system(size: 13, weight: .medium))
                            Text("Start from Region, Window, or Screen.")
                                .font(.system(size: 11))
                                .foregroundStyle(UI.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        ForEach(app.projects) { project in
                            RecentProjectRow(app: app, project: project)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 224)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                app.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings")

            Button {
                app.openLibraryFolder()
            } label: {
                Image(systemName: "folder")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(IconButtonStyle())
            .help("Library Folder")

            Spacer()

            Button {
                app.copyLastExport()
            } label: {
                Label("Copy Last", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .foregroundStyle(Color.white)
                    .background(UI.red)
                    .clipShape(Capsule())
                    .shadow(color: UI.red.opacity(0.22), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(app.projects.first?.exports.isEmpty ?? true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(UI.surfaceLow.opacity(0.60))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.05)).frame(height: 1)
        }
    }
}

struct RecentProjectRow: View {
    @ObservedObject var app: GifrogController
    var project: Project

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.system(size: 13))
                    .foregroundStyle(UI.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(project.exports.first?.sizeBytes.fileSizeString ?? "\(project.width)x\(project.height)")
                    Circle().frame(width: 3, height: 3)
                    Text(timeString(project.durationSeconds))
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(UI.secondaryText.opacity(0.75))
            }
            Spacer()
            Button {
                app.openEditor(project: project)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(IconButtonStyle())
            if let exported = project.exports.first {
                Button {
                    app.copyToClipboard(exported)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(IconButtonStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.001))
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = project.thumbnailURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.05)))
        } else {
            ZStack {
                UI.surfaceLow
                Image(systemName: "photo")
                    .foregroundStyle(UI.secondaryText)
            }
            .frame(width: 48, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
