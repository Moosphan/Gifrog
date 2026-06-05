import AVKit
import SwiftUI

// MARK: - Timeline Thumbnail Generator

final class TimelineThumbnailGenerator {
    private static let thumbnailCount = 12
    private static let thumbnailHeight: CGFloat = 80

    static func generate(for project: Project) -> [NSImage] {
        let asset = AVURLAsset(url: project.sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: thumbnailHeight)
        generator.apertureMode = .cleanAperture

        let duration = max(0.1, project.durationSeconds)
        var images: [NSImage] = []

        for i in 0..<thumbnailCount {
            let time = CMTime(seconds: duration * Double(i) / Double(thumbnailCount), preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            images.append(NSImage(cgImage: cgImage, size: NSSize(width: 160, height: thumbnailHeight)))
        }

        return images
    }
}

// MARK: - Editor View

struct EditorView: View {
    @ObservedObject var app: GifrogController
    var project: Project

    @State private var player: AVPlayer
    @State private var edit: EditDecision
    @State private var isDropTarget = false
    @State private var thumbnails: [NSImage] = []
    @State private var playheadPosition: Double = 0
    @State private var isPlaying = false

    init(app: GifrogController, project: Project) {
        self.app = app
        self.project = project
        _player = State(initialValue: AVPlayer(url: project.sourceURL))
        _edit = State(initialValue: EditDecision.defaults(for: project, settings: app.settings))
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                topBar
                previewCanvas
                timelineSection
            }
            .frame(minWidth: 740)
            exportPanel
        }
        .background(Color(red: 0.980, green: 0.980, blue: 0.980))
        .overlay {
            if isDropTarget {
                Rectangle()
                    .fill(UI.primary.opacity(0.08))
                    .overlay(Rectangle().stroke(UI.primary, lineWidth: 3))
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
            app.importDroppedFiles(providers)
        }
        .onAppear {
            thumbnails = TimelineThumbnailGenerator.generate(for: project)
            setupPlayheadObserver()
        }
        .onDisappear {
            player.pause()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(project.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(UI.text)
            Text("\(project.width)x\(project.height)")
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Spacer()
            Button {
                player.seek(to: .zero)
                player.play()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(EditorGhostButtonStyle())
            Button {
                player.pause()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(EditorGhostButtonStyle())
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .background(Color.white.opacity(0.70))
        .overlay(alignment: .bottom) {
            Rectangle().fill(UI.outline.opacity(0.45)).frame(height: 1)
        }
    }

    // MARK: - Preview Canvas

    private var previewCanvas: some View {
        ZStack {
            checkerboard
            VideoPlayer(player: player)
                .aspectRatio(CGFloat(max(project.width, 1)) / CGFloat(max(project.height, 1)), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
                .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UI.surfaceLow)
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let square: CGFloat = 18
            for row in stride(from: CGFloat(0), through: size.height, by: square) {
                for col in stride(from: CGFloat(0), through: size.width, by: square) {
                    let isAlt = (Int(row / square) + Int(col / square)).isMultiple(of: 2)
                    context.fill(
                        Path(CGRect(x: col, y: row, width: square, height: square)),
                        with: .color(isAlt ? UI.surface : UI.outline.opacity(0.35))
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(28)
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(spacing: 0) {
            // Transport controls row
            HStack {
                Text("Timeline")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(UI.secondaryText)
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        player.seek(to: CMTime(seconds: max(0, edit.trimStart), preferredTimescale: 600))
                    } label: {
                        Image(systemName: "backward.end")
                    }
                    .buttonStyle(IconButtonStyle())
                    Button {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PrimaryCircleButtonStyle(color: UI.primary))
                    Button {
                        player.seek(to: CMTime(seconds: max(0, edit.trimEnd), preferredTimescale: 600))
                    } label: {
                        Image(systemName: "forward.end")
                    }
                    .buttonStyle(IconButtonStyle())
                    Text(timeString(edit.trimEnd - edit.trimStart))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(UI.secondaryText)
                        .frame(width: 54)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(UI.surfaceLow)
                .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
            .overlay(alignment: .bottom) {
                Rectangle().fill(UI.outline.opacity(0.35)).frame(height: 1)
            }

            // Thumbnail strip with trim handles and playhead
            VStack(spacing: 8) {
                TimelineThumbnailStrip(
                    thumbnails: thumbnails,
                    duration: project.durationSeconds,
                    trimStart: $edit.trimStart,
                    trimEnd: $edit.trimEnd,
                    playheadPosition: playheadPosition,
                    onPlayheadDrag: { fraction in
                        let time = CMTime(seconds: fraction * project.durationSeconds, preferredTimescale: 600)
                        player.seek(to: time)
                    }
                )

                // Trim sliders (fallback for precise control)
                HStack {
                    Text("Start \(timeString(edit.trimStart))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(UI.secondaryText)
                    Slider(value: $edit.trimStart, in: 0...max(edit.trimEnd - 0.1, 0.1))
                        .tint(UI.primary)
                    Spacer()
                    Text("End \(timeString(edit.trimEnd))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(UI.secondaryText)
                    Slider(value: $edit.trimEnd, in: min(edit.trimStart + 0.1, project.durationSeconds)...max(project.durationSeconds, 0.1))
                        .tint(UI.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 198)
        .background(Color.white)
    }

    // MARK: - Export Panel

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export Settings")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 24)
                .frame(height: 54, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(UI.outline.opacity(0.35)).frame(height: 1)
                }

            VStack(alignment: .leading, spacing: 22) {
                settingLabel("Format")
                HStack(spacing: 2) {
                    ForEach(ExportFormat.allCases) { format in
                        formatButton(format)
                    }
                }
                .padding(3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    settingLabel("Scale")
                    Spacer()
                    Text("\(Int(edit.scale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(UI.secondaryText)
                }
                HStack(spacing: 8) {
                    scaleButton(1.0)
                    scaleButton(0.75)
                    scaleButton(0.5)
                }

                HStack {
                    settingLabel("Framerate")
                    Spacer()
                    Text("\(edit.fps) FPS")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(UI.primaryDark)
                        .padding(.horizontal, 6)
                        .background(UI.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                HStack(spacing: 2) {
                    ForEach([10, 15, 24, 30], id: \.self) { fps in
                        fpsButton(fps)
                    }
                }
                .padding(3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Divider()
                checkRow("Optimize Colors", isOn: $edit.optimizeColors)
                checkRow("Dithering", isOn: $edit.dithering)
                checkRow("Click Highlight", isOn: $edit.showClickHighlight)
                Spacer()
            }
            .padding(24)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated Size")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(UI.secondaryText)
                        Text(ExportManager.estimate(project: project, edit: edit))
                            .font(.system(size: 20, weight: .bold))
                    }
                    Spacer()
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(UI.primary)
                }

                if app.phase == .exporting {
                    ProgressView(value: app.exportProgress)
                        .tint(UI.primary)
                }

                Button {
                    if app.phase == .exporting {
                        app.cancelExport()
                    } else {
                        app.export(project: project, edit: edit)
                    }
                } label: {
                    Label(
                        app.phase == .exporting ? "Cancel Export" : "Export \(edit.format.rawValue)",
                        systemImage: app.phase == .exporting ? "xmark.circle" : "square.and.arrow.up"
                    )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(app.phase == .exporting ? UI.red : UI.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(UI.surfaceLow)
        }
        .frame(width: 288)
        .background(Color.white)
        .overlay(alignment: .leading) {
            Rectangle().fill(UI.outline.opacity(0.35)).frame(width: 1)
        }
    }

    // MARK: - Helpers

    private func setupPlayheadObserver() {
        guard ProcessInfo.processInfo.environment["GIFROG_RENDER_QA"] != "1" else { return }
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = time.seconds
            guard seconds.isFinite, seconds >= 0 else { return }
            playheadPosition = seconds / max(project.durationSeconds, 0.1)
            isPlaying = player.rate > 0
        }
    }

    private func settingLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .textCase(.uppercase)
            .foregroundStyle(UI.secondaryText)
    }

    private func scaleButton(_ scale: Double) -> some View {
        Button {
            edit.scale = scale
        } label: {
            Text("\(Int(scale * 100))%")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundStyle(edit.scale == scale ? UI.primaryDark : UI.secondaryText)
                .background(edit.scale == scale ? UI.primary.opacity(0.12) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(edit.scale == scale ? UI.primary : UI.outline, lineWidth: edit.scale == scale ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func formatButton(_ format: ExportFormat) -> some View {
        Button {
            edit.format = format
        } label: {
            Text(format.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .foregroundStyle(edit.format == format ? UI.primaryDark : UI.secondaryText)
                .background(edit.format == format ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(edit.format == format ? 0.08 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func fpsButton(_ fps: Int) -> some View {
        Button {
            edit.fps = fps
        } label: {
            Text("\(fps)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .foregroundStyle(edit.fps == fps ? UI.primaryDark : UI.secondaryText)
                .background(edit.fps == fps ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(edit.fps == fps ? 0.08 : 0), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func checkRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? UI.primary : UI.outline)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(UI.text)
                Spacer()
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline Thumbnail Strip

struct TimelineThumbnailStrip: View {
    let thumbnails: [NSImage]
    let duration: Double
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    let playheadPosition: Double
    let onPlayheadDrag: (Double) -> Void

    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false
    @State private var isDraggingPlayhead = false
    @State private var hoveredTime: Double?

    private let trackHeight: CGFloat = 80

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            ZStack(alignment: .topLeading) {
                // Background thumbnail strip
                thumbnailRow
                    .frame(height: trackHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .opacity(0.5)

                // Selected region highlight
                let startX = fractionToX(trimStart / max(duration, 0.01), in: totalWidth)
                let endX = fractionToX(trimEnd / max(duration, 0.01), in: totalWidth)

                Rectangle()
                    .fill(UI.primary.opacity(0.08))
                    .frame(width: max(0, endX - startX), height: trackHeight)
                    .offset(x: startX)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Selected region top/bottom borders
                Rectangle()
                    .fill(UI.primary)
                    .frame(width: max(0, endX - startX), height: 2)
                    .offset(x: startX, y: 0)
                Rectangle()
                    .fill(UI.primary)
                    .frame(width: max(0, endX - startX), height: 2)
                    .offset(x: startX, y: trackHeight - 2)

                // Left trim handle
                trimHandle(isLeft: true, x: startX, totalWidth: totalWidth)

                // Right trim handle
                trimHandle(isLeft: false, x: endX, totalWidth: totalWidth)

                // Playhead
                let playheadX = fractionToX(playheadPosition, in: totalWidth)
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.392, blue: 0.208))
                    .frame(width: 2, height: trackHeight + 16)
                    .offset(x: playheadX - 1, y: -8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingPlayhead = true
                                let fraction = xToFraction(value.location.x, in: totalWidth)
                                onPlayheadDrag(max(0, min(1, fraction)))
                            }
                            .onEnded { _ in
                                isDraggingPlayhead = false
                            }
                    )

                // Playhead triangle
                Path { path in
                    path.move(to: CGPoint(x: playheadX, y: -8))
                    path.addLine(to: CGPoint(x: playheadX - 5, y: -1))
                    path.addLine(to: CGPoint(x: playheadX + 5, y: -1))
                    path.closeSubpath()
                }
                .fill(Color(red: 1.0, green: 0.392, blue: 0.208))
            }
            .frame(height: trackHeight + 16)
            .contentShape(Rectangle())
        }
        .frame(height: trackHeight + 16)
    }

    private var thumbnailRow: some View {
        HStack(spacing: 1) {
            ForEach(0..<thumbnails.count, id: \.self) { index in
                Image(nsImage: thumbnails[index])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: trackHeight)
                    .clipped()
            }
        }
    }

    @ViewBuilder
    private func trimHandle(isLeft: Bool, x: CGFloat, totalWidth: CGFloat) -> some View {
        let handleWidth: CGFloat = 14
        let handleX = isLeft ? x - handleWidth : x

        RoundedRectangle(cornerRadius: isLeft ? 4 : 4)
            .fill(UI.primary)
            .frame(width: handleWidth, height: trackHeight)
            .offset(x: handleX)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = xToFraction(value.location.x + handleX, in: totalWidth)
                        let time = fraction * duration
                        if isLeft {
                            trimStart = max(0, min(time, trimEnd - 0.1))
                        } else {
                            trimEnd = min(duration, max(time, trimStart + 0.1))
                        }
                    }
            )
            .overlay {
                // Grip indicator
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: 8)
                    }
                }
            }
    }

    private func fractionToX(_ fraction: Double, in width: CGFloat) -> CGFloat {
        CGFloat(fraction) * width
    }

    private func xToFraction(_ x: CGFloat, in width: CGFloat) -> Double {
        Double(x / max(width, 1))
    }
}
