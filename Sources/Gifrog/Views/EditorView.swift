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
            images.append(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
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
                .foregroundStyle(UI.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(UI.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Spacer()
            Button {
                playTrimmedRange()
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
            GeometryReader { geometry in
                let videoRect = OverlayGeometry.aspectFitRect(
                    contentSize: CGSize(width: max(project.width, 1), height: max(project.height, 1)),
                    containerSize: geometry.size
                )

                ZStack {
                    VideoPlayer(player: player)
                        .frame(width: videoRect.width, height: videoRect.height)

                    if edit.showClickHighlight {
                        ClickHighlightOverlay(
                            project: project,
                            currentTime: playheadPosition * max(project.durationSeconds, 0.1),
                            trimStart: edit.trimStart,
                            trimEnd: edit.trimEnd
                        )
                        .frame(width: videoRect.width, height: videoRect.height)
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: videoRect.width, height: videoRect.height)
                .position(x: videoRect.midX, y: videoRect.midY)
            }
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
                            playTrimmedRange()
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
                    onTrimChange: { start, end, isLeft in
                        seekWithinTrim(to: start)
                    },
                    onPlayheadDrag: { fraction in
                        seekWithinTrim(to: fraction * project.durationSeconds)
                    }
                )

                HStack {
                    Text("Start \(timeString(edit.trimStart))")
                    Spacer()
                    Text("End \(timeString(edit.trimEnd))")
                    Spacer()
                    Text("Duration \(timeString(edit.trimEnd - edit.trimStart))")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(UI.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 162)
        .background(Color.white)
    }

    // MARK: - Export Panel

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(UI.text)
                .padding(.horizontal, 24)
                .frame(height: 54, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(UI.outline.opacity(0.35)).frame(height: 1)
                }

            VStack(alignment: .leading, spacing: 22) {
                settingLabel("Format")
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { ExportFormat.allCases.firstIndex(of: edit.format) ?? 0 },
                        set: { edit.format = ExportFormat.allCases[$0] }
                    ),
                    labels: ExportFormat.allCases.map(\.rawValue),
                    inset: true
                )

                HStack {
                    settingLabel("Scale")
                    Spacer()
                    Text("\(Int(edit.scale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(UI.secondaryText)
                }
                let scaleOptions = [1.0, 0.75, 0.5]
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { scaleOptions.firstIndex(of: edit.scale) ?? 0 },
                        set: { edit.scale = scaleOptions[$0] }
                    ),
                    labels: scaleOptions.map { "\(Int($0 * 100))%" }
                )

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
                let fpsOptions = [10, 15, 24, 30]
                SlidingChoiceGroup(
                    selection: Binding(
                        get: { fpsOptions.firstIndex(of: edit.fps) ?? 0 },
                        set: { edit.fps = fpsOptions[$0] }
                    ),
                    labels: fpsOptions.map(String.init),
                    inset: true
                )

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
                            .foregroundStyle(UI.text)
                    }
                    Spacer()
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(UI.primary)
                }

                if app.phase == .exporting {
                    ProgressView(value: app.exportProgress)
                        .tint(UI.primary)
                }

                ExportButton(
                    title: app.phase == .exporting ? "Cancel Export" : "Export \(edit.format.rawValue)",
                    icon: app.phase == .exporting ? "xmark.circle" : "square.and.arrow.up",
                    color: app.phase == .exporting ? UI.red : UI.primary
                ) {
                    if app.phase == .exporting {
                        app.cancelExport()
                    } else {
                        app.export(project: project, edit: edit)
                    }
                }
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
            let range = TimelineTrim.clampedRange(start: edit.trimStart, end: edit.trimEnd, duration: project.durationSeconds)
            if player.rate > 0, seconds >= range.end {
                player.pause()
                player.seek(to: CMTime(seconds: range.end, preferredTimescale: 600))
                playheadPosition = TimelineTrim.fraction(forTime: range.end, duration: project.durationSeconds)
                isPlaying = false
                return
            }
            playheadPosition = TimelineTrim.fraction(forTime: seconds, duration: project.durationSeconds)
            isPlaying = player.rate > 0
        }
    }

    private func playTrimmedRange() {
        let range = TimelineTrim.clampedRange(start: edit.trimStart, end: edit.trimEnd, duration: project.durationSeconds)
        player.seek(to: CMTime(seconds: range.start, preferredTimescale: 600))
        playheadPosition = TimelineTrim.fraction(forTime: range.start, duration: project.durationSeconds)
        player.play()
    }

    private func seekWithinTrim(to seconds: Double) {
        let clamped = TimelineTrim.clampedTime(seconds, start: edit.trimStart, end: edit.trimEnd, duration: project.durationSeconds)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        playheadPosition = TimelineTrim.fraction(forTime: clamped, duration: project.durationSeconds)
    }

    private func settingLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .textCase(.uppercase)
            .foregroundStyle(UI.secondaryText)
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

// MARK: - Click Highlight Preview

private struct ClickHighlightOverlay: View {
    let project: Project
    let currentTime: Double
    let trimStart: Double
    let trimEnd: Double

    var body: some View {
        GeometryReader { geometry in
            ForEach(activeClicks) { click in
                let progress = max(0, min(1, (currentTime - click.time) / ClickHighlightStyle.visibleDuration))
                TouchRippleHighlight(progress: progress)
                    .frame(width: ClickHighlightStyle.spriteSize, height: ClickHighlightStyle.spriteSize)
                    .position(
                        x: CGFloat(click.normalizedX) * geometry.size.width,
                        y: CGFloat(click.normalizedY) * geometry.size.height
                    )
            }
        }
    }

    private var activeClicks: [ClickEvent] {
        let previewEnd = trimEnd > trimStart ? trimEnd : project.durationSeconds
        return project.clickEvents.filter { click in
            click.time >= trimStart &&
            click.time <= previewEnd &&
            currentTime >= click.time &&
            currentTime <= click.time + ClickHighlightStyle.visibleDuration
        }
    }
}

private struct TouchRippleHighlight: View {
    let progress: Double

    var body: some View {
        Circle()
            .fill(Color(nsColor: ClickHighlightStyle.fillColor).opacity(ClickHighlightStyle.fillOpacity * opacity))
            .overlay(
                Circle()
                    .stroke(
                        Color(nsColor: ClickHighlightStyle.contrastStrokeColor).opacity(ClickHighlightStyle.contrastStrokeOpacity * opacity),
                        lineWidth: ClickHighlightStyle.borderWidth + ClickHighlightStyle.contrastBorderWidth * 2
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color(nsColor: ClickHighlightStyle.strokeColor).opacity(ClickHighlightStyle.strokeOpacity * opacity),
                        lineWidth: ClickHighlightStyle.borderWidth
                    )
            )
            .frame(width: ClickHighlightStyle.circleRadius * 2, height: ClickHighlightStyle.circleRadius * 2)
            .scaleEffect(1 + 0.06 * progress)
        .opacity(opacity)
    }

    private var opacity: Double {
        let fadeStart = max(0, 1 - ClickHighlightStyle.fadeOutDuration / ClickHighlightStyle.visibleDuration)
        guard progress > fadeStart else { return 1 }
        return max(0, 1 - (progress - fadeStart) / (1 - fadeStart))
    }
}

// MARK: - Timeline Thumbnail Strip

struct TimelineThumbnailStrip: View {
    let thumbnails: [NSImage]
    let duration: Double
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    let playheadPosition: Double
    let onTrimChange: (Double, Double, Bool) -> Void
    let onPlayheadDrag: (Double) -> Void

    @State private var isDraggingPlayhead = false
    @State private var activeDrag: DragState?
    @State private var hoveredTime: Double?

    private let trackHeight: CGFloat = 80
    private let trimHandleHitWidth: CGFloat = 30
    private let playheadHitWidth: CGFloat = 22

    private struct DragState {
        let target: TimelineTrim.DragTarget
        let pointerOffset: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let range = TimelineTrim.clampedRange(start: trimStart, end: trimEnd, duration: duration)
            let startX = fractionToX(TimelineTrim.fraction(forTime: range.start, duration: duration), in: totalWidth)
            let endX = fractionToX(TimelineTrim.fraction(forTime: range.end, duration: duration), in: totalWidth)
            let playheadFraction = TimelineTrim.playheadFraction(
                forTime: playheadPosition * max(duration, 0.1),
                start: trimStart,
                end: trimEnd,
                duration: duration
            )
            let playheadX = fractionToX(playheadFraction, in: totalWidth)

            ZStack(alignment: .topLeading) {
                // Background thumbnail strip
                thumbnailRow(width: totalWidth)
                    .frame(height: trackHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Rectangle()
                    .fill(Color.white.opacity(0.62))
                    .frame(width: startX, height: trackHeight)
                    .offset(x: 0)
                Rectangle()
                    .fill(Color.white.opacity(0.62))
                    .frame(width: max(0, totalWidth - endX), height: trackHeight)
                    .offset(x: endX)

                Rectangle()
                    .fill(UI.primary.opacity(0.08))
                    .frame(width: max(0, endX - startX), height: trackHeight)
                    .offset(x: startX)
                Rectangle()
                    .fill(UI.primary)
                    .frame(width: max(0, endX - startX), height: 3)
                    .offset(x: startX)
                Rectangle()
                    .fill(UI.primary)
                    .frame(width: max(0, endX - startX), height: 3)
                    .offset(x: startX, y: trackHeight - 3)

                // Left trim handle
                trimHandle(isLeft: true, x: startX, totalWidth: totalWidth)

                // Right trim handle
                trimHandle(isLeft: false, x: endX, totalWidth: totalWidth)

                // Playhead
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.392, blue: 0.208))
                    .frame(width: 2, height: trackHeight + 16)
                    .offset(x: playheadX - 1, y: -8)

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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleTimelineDrag(
                            value,
                            startX: startX,
                            endX: endX,
                            playheadX: playheadX,
                            totalWidth: totalWidth
                        )
                    }
                    .onEnded { _ in
                        activeDrag = nil
                        isDraggingPlayhead = false
                    }
            )
        }
        .frame(height: trackHeight + 16)
    }

    private func thumbnailRow(width: CGFloat) -> some View {
        let spacing: CGFloat = 1
        let tileWidth = CGFloat(TimelineTrim.thumbnailTileWidth(
            totalWidth: Double(width),
            count: thumbnails.count,
            spacing: Double(spacing)
        ))

        return HStack(spacing: spacing) {
            ForEach(0..<thumbnails.count, id: \.self) { index in
                Image(nsImage: thumbnails[index])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: tileWidth, height: trackHeight)
                    .clipped()
            }
        }
        .frame(width: width, height: trackHeight, alignment: .leading)
    }

    @ViewBuilder
    private func trimHandle(isLeft: Bool, x: CGFloat, totalWidth: CGFloat) -> some View {
        let handleWidth: CGFloat = 14
        let hitWidth = trimHandleHitWidth
        let hitX = min(max(x - hitWidth / 2, 0), max(0, totalWidth - hitWidth))
        let visibleX = min(max(x - hitX - handleWidth / 2, 0), hitWidth - handleWidth)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: hitWidth, height: trackHeight)

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(UI.primary)

                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: 8)
                    }
                }
            }
                .frame(width: handleWidth, height: trackHeight)
                .offset(x: visibleX)
        }
            .frame(width: hitWidth, height: trackHeight)
            .offset(x: hitX)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
    }

    private func handleTimelineDrag(
        _ value: DragGesture.Value,
        startX: CGFloat,
        endX: CGFloat,
        playheadX: CGFloat,
        totalWidth: CGFloat
    ) {
        let pointerX = value.location.x

        if activeDrag == nil {
            guard let target = TimelineTrim.dragTarget(
                x: Double(pointerX),
                startX: Double(startX),
                endX: Double(endX),
                playheadX: Double(playheadX),
                handleHitWidth: Double(trimHandleHitWidth),
                playheadHitWidth: Double(playheadHitWidth)
            ) else { return }

            let anchorX: CGFloat
            switch target {
            case .start:
                anchorX = startX
            case .end:
                anchorX = endX
            case .playhead:
                anchorX = playheadX
            }
            activeDrag = DragState(target: target, pointerOffset: pointerX - anchorX)
        }

        guard let activeDrag else { return }
        let targetX = pointerX - activeDrag.pointerOffset
        let fraction = xToFraction(targetX, in: totalWidth)
        let time = TimelineTrim.time(forFraction: fraction, duration: duration)

        switch activeDrag.target {
        case .start:
            let range = TimelineTrim.updatedRange(
                moving: .start,
                to: time,
                start: trimStart,
                end: trimEnd,
                duration: duration
            )
            trimStart = range.start
            trimEnd = range.end
            onTrimChange(trimStart, trimEnd, true)
        case .end:
            let range = TimelineTrim.updatedRange(
                moving: .end,
                to: time,
                start: trimStart,
                end: trimEnd,
                duration: duration
            )
            trimStart = range.start
            trimEnd = range.end
            onTrimChange(trimStart, trimEnd, false)
        case .playhead:
            isDraggingPlayhead = true
            onPlayheadDrag(fraction)
        }
    }

    private func fractionToX(_ fraction: Double, in width: CGFloat) -> CGFloat {
        CGFloat(fraction) * width
    }

    private func xToFraction(_ x: CGFloat, in width: CGFloat) -> Double {
        TimelineTrim.fraction(forX: Double(x), width: Double(width))
    }
}

// MARK: - Export Button

private struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isPressed ? color.opacity(0.80) : isHovering ? color.opacity(0.90) : color)
            )
            .shadow(color: color.opacity(isHovering ? 0.30 : 0.22), radius: isHovering ? 10 : 8, y: isHovering ? 5 : 4)
            .scaleEffect(isPressed ? 0.97 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
    }
}
