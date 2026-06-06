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
            SlidingSegment(
                selection: Binding(
                    get: { CaptureMode.allCases.firstIndex(of: app.selectedMode) ?? 0 },
                    set: { app.selectedMode = CaptureMode.allCases[$0] }
                ),
                count: CaptureMode.allCases.count,
                height: 36
            ) { index, isSelected in
                let mode = CaptureMode.allCases[index]
                VStack(spacing: 1) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 15, weight: .medium))
                    Text(mode.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(isSelected ? UI.primary : UI.secondaryText)
            }
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
            }
            .buttonStyle(RecordButtonStyle())

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
                }
                .buttonStyle(ImportButtonStyle())
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

            CopyLastButton(
                enabled: app.lastExport != nil || app.projects.contains { !$0.exports.isEmpty }
            ) {
                app.copyLastExport()
            }
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
    @State private var isHovering = false

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
                .fill(isHovering ? Color.black.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
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

// MARK: - Sliding Segment Control

struct SlidingSegment<Content: View>: View {
    @Binding var selection: Int
    let count: Int
    var height: CGFloat = 38
    @ViewBuilder let content: (Int, Bool) -> Content
    @State private var hoveredIndex: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Sliding indicator (background — only offset is animated)
            SlidingIndicator(
                selection: CGFloat(selection),
                count: count,
                height: height,
                inset: 2,
                cornerRadius: 7
            )

            // Segments (top layer — full area is clickable via contentShape + tap)
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    ZStack {
                        // Hover background
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(hoveredIndex == index && selection != index ? 0.40 : 0))

                        // Content
                        content(index, selection == index)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = index }
                    .onHover { hoveredIndex = $0 ? index : nil }
                }
            }
            .padding(2)
        }
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Animatable indicator that slides smoothly without affecting sibling views.
private struct SlidingIndicator: View {
    let selection: CGFloat
    let count: Int
    let height: CGFloat
    let inset: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let segWidth = (geo.size.width - inset * 2) / CGFloat(count)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                .frame(width: segWidth - 2, height: height)
                .offset(x: inset + selection * segWidth + 1, y: inset)
        }
        .frame(height: height + inset * 2)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selection)
    }
}

// Legacy SegmentButton kept for compatibility
struct SegmentButton<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content()
                .foregroundStyle(isSelected ? UI.primary : UI.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isSelected ? Color.white :
                            isHovering ? Color.black.opacity(0.06) : Color.clear
                        )
                        .shadow(color: .black.opacity(isSelected ? 0.10 : 0), radius: 3, y: 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

// MARK: - Copy Last Button

private struct CopyLastButton: View {
    let enabled: Bool
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Label("Copy Last", systemImage: "doc.on.doc")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 11)
            .frame(height: 30)
            .foregroundStyle(enabled ? Color.white : Color.white.opacity(0.5))
            .background(
                Capsule()
                    .fill(
                        !enabled ? UI.red.opacity(0.40) :
                        isPressed ? UI.red.opacity(0.75) :
                        isHovering ? UI.red.opacity(0.90) : UI.red
                    )
            )
            .shadow(color: UI.red.opacity(enabled ? (isHovering ? 0.30 : 0.22) : 0), radius: isHovering ? 10 : 8, y: isHovering ? 4 : 3)
            .scaleEffect(isPressed ? 0.95 : 1)
            .contentShape(Capsule())
            .onHover { isHovering = enabled ? $0 : false }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = enabled }
                    .onEnded { _ in
                        isPressed = false
                        if enabled { action() }
                    }
            )
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
    }
}
