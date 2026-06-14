import AVFoundation
import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

final class GifrogController: NSObject, ObservableObject {
    @Published var selectedMode: CaptureMode = .region
    @Published var settings = AppSettings()
    @Published var projects: [Project] = []
    @Published var phase: RecordingPhase = .idle
    @Published var message: String?
    @Published var elapsed: TimeInterval = 0
    @Published var countdown: Int = 3
    @Published var activeProject: Project?
    @Published var exportProgress: Double = 0
    @Published var lastExport: ExportedFile?
    @Published var hasScreenRecordingPermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    private let recorder = FrameRecorder()
    private let clickRecorder = ClickEventRecorder()
    private var elapsedTimer: Timer?
    private var countdownTimer: Timer?
    private var recorderStartTask: Task<Void, Never>?
    private var recorderIsStarting = false
    private var pendingStopAfterStart = false
    private var currentRegion: CaptureRegion?
    private var currentSession: FrameRecorder.RecordingSession?
    private var exportTask: Task<Void, Never>?
    private var exportToken: ProcessCancellationToken?

    private var statusController: StatusBarController?
    private var toolbarController: RecordingToolbarController?
    private var editorController: EditorWindowController?
    private var settingsController: SettingsPanelController?
    private var permissionController: PermissionGuideController?
    private var regionSelector: RegionSelectionController?
    private var windowPicker: WindowPickerController?
    private var hotKeyController: HotKeyController?

    var activeCaptureRegion: CaptureRegion? {
        currentRegion
    }

    func setUp() {
        AppPaths.prepare()
        loadSettings()
        loadHistory()
        recoverIncompleteRecordings()

        statusController = StatusBarController(app: self)
        toolbarController = RecordingToolbarController(app: self)
        editorController = EditorWindowController(app: self)
        settingsController = SettingsPanelController(app: self)
        permissionController = PermissionGuideController(app: self)
        regionSelector = RegionSelectionController()
        windowPicker = WindowPickerController(app: self)

        hotKeyController = HotKeyController { [weak self] in
            self?.handleGlobalShortcut()
        }
        hotKeyController?.register()

        refreshPermissionStatus()

        // Refresh permissions when app becomes active (user returns from System Settings)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    func refreshPermissionStatus() {
        // CGRequestScreenCaptureAccess() is a no-op (no dialog) once granted,
        // and works reliably on unsigned debug builds unlike CGPreflightScreenCaptureAccess().
        hasScreenRecordingPermission = CGRequestScreenCaptureAccess()
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func showUIPreview(surface: String) {
        let project = makePreviewProject()
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)
        activeProject = project
        settings.highlightClicks = true

        let previewRegion = CaptureRegion(
            globalRect: CGRect(x: 320, y: 300, width: 720, height: 420),
            captureRect: CGRect(x: 320, y: 300, width: 720, height: 420)
        )

        switch surface.lowercased() {
        case "popover":
            statusController?.toggle()
        case "toolbar":
            phase = .recording
            elapsed = 14
            toolbarController?.show(near: previewRegion)
        case "editor":
            openEditor(project: project)
        case "settings":
            openSettings()
        case "permission":
            permissionController?.show()
        default:
            statusController?.toggle()
            phase = .recording
            elapsed = 14
            toolbarController?.show(near: previewRegion)
            openEditor(project: project)
        }
    }

    func renderQAPreviews(to outputDirectory: URL) {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let project = makePreviewProject()
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)
        activeProject = project
        settings.highlightClicks = true
        let previewRegion = CaptureRegion(
            globalRect: CGRect(x: 320, y: 300, width: 720, height: 420),
            captureRect: CGRect(x: 320, y: 300, width: 720, height: 420)
        )
        currentRegion = previewRegion

        phase = .idle
        render(
            StatusPopoverView(app: self),
            size: CGSize(width: StatusPopoverLayout.panelWidth, height: StatusPopoverLayout.panelHeight),
            to: outputDirectory.appendingPathComponent("status-popover.png")
        )

        phase = .recording
        elapsed = 14
        render(RecordingToolbarView(app: self), size: CGSize(width: 700, height: 86), to: outputDirectory.appendingPathComponent("recording-toolbar.png"))

        phase = .finished
        render(RecordingToolbarView(app: self), size: CGSize(width: 760, height: 86), to: outputDirectory.appendingPathComponent("recording-toolbar-finished.png"))

        render(SettingsView(app: self, initialTab: "General"), size: CGSize(width: 420, height: 520), to: outputDirectory.appendingPathComponent("settings.png"))
        render(SettingsView(app: self, initialTab: "Shortcuts"), size: CGSize(width: 420, height: 520), to: outputDirectory.appendingPathComponent("settings-shortcuts.png"))
        render(SettingsView(app: self, initialTab: "Advanced"), size: CGSize(width: 420, height: 520), to: outputDirectory.appendingPathComponent("settings-advanced.png"))
        render(PermissionGuideView(app: self), size: CGSize(width: 520, height: 600), to: outputDirectory.appendingPathComponent("permission-guide.png"))
        render(EditorView(app: self, project: project), size: CGSize(width: 1120, height: 760), to: outputDirectory.appendingPathComponent("editor.png"))
    }

    func runExportQA(to outputDirectory: URL) async throws -> ExportedFile {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let project = makePreviewProject()
        var edit = EditDecision()
        edit.trimStart = 0
        edit.trimEnd = min(2.0, project.durationSeconds)
        edit.format = .gif
        edit.scale = 0.5
        edit.fps = 10
        edit.quality = .small
        edit.optimizeColors = true
        edit.showClickHighlight = true
        return try await ExportManager.export(project: project, edit: edit, savePath: outputDirectory)
    }

    func toggleStatusPanel() {
        statusController?.toggle()
    }

    func closeStatusPanel() {
        statusController?.close()
    }

    func handleGlobalShortcut() {
        switch phase {
        case .recording:
            stopRecording()
        case .paused:
            resumeRecording()
        default:
            startCaptureFlow()
        }
    }

    func startCaptureFlow() {
        closeStatusPanel()

        guard hasScreenRecordingPermission else {
            phase = .requestingPermission
            permissionController?.show()
            return
        }

        switch selectedMode {
        case .region:
            regionSelector?.show(
                initialRegion: settings.lastRegion,
                onSelectionChanged: { [weak self] region in
                    guard let self else { return }
                    self.currentRegion = region
                    if self.phase != .ready {
                        self.phase = .ready
                    }
                    self.toolbarController?.show(near: region)
                },
                onComplete: { [weak self] region in
                    self?.settings.lastRegion = region
                    self?.saveSettings()
                    self?.prepareRecording(region: region)
                }
            )
        case .screen:
            guard let screen = NSScreen.main else {
                fail(GifrogError.noScreen)
                return
            }
            prepareRecording(region: CaptureRegion.screen(screen))
        case .window:
            windowPicker?.show()
        }
    }

    func prepareRecording(region: CaptureRegion) {
        currentRegion = region
        phase = .ready
        elapsed = 0
        toolbarController?.show(near: region)
        statusController?.refresh()
    }


    func repeatLastRegion() {
        guard let currentRegion else {
            startCaptureFlow()
            return
        }
        prepareRecording(region: currentRegion)
    }

    func startCountdown() {
        guard currentRegion != nil else {
            fail(GifrogError.noRegion)
            return
        }

        countdownTimer?.invalidate()
        countdown = max(0, settings.countdownSeconds)

        if countdown == 0 {
            beginRecording()
            return
        }

        phase = .countdown
        toolbarController?.refresh()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned self] timer in
            self.countdown -= 1
            self.toolbarController?.refresh()
            if self.countdown <= 0 {
                timer.invalidate()
                self.beginRecording()
            }
        }
    }

    func beginRecording() {
        guard let currentRegion else {
            fail(GifrogError.noRegion)
            return
        }

        countdownTimer?.invalidate()
        regionSelector?.close()
        elapsed = 0
        phase = .recording
        recorderIsStarting = true
        pendingStopAfterStart = false
        startElapsedTimer()
        toolbarController?.refresh()
        statusController?.refresh()

        recorderStartTask?.cancel()
        recorderStartTask = Task {
            do {
                let session = try await recorder.start(region: currentRegion, settings: settings)
                let shouldAbort = await MainActor.run { () -> Bool in
                    self.currentSession = session
                    self.recorderIsStarting = false
                    if Task.isCancelled || self.phase != .recording {
                        self.pendingStopAfterStart = false
                        self.recorderStartTask = nil
                        return true
                    }
                    return false
                }
                if shouldAbort {
                    await MainActor.run {
                        self.currentSession = nil
                    }
                    await recorder.cancel()
                    return
                }
                await MainActor.run {
                    self.recorderStartTask = nil
                    if self.settings.highlightClicks {
                        self.clickRecorder.start(region: currentRegion)
                    }
                    if self.pendingStopAfterStart {
                        self.pendingStopAfterStart = false
                        self.stopRecording()
                    }
                }
            } catch {
                await MainActor.run {
                    self.recorderIsStarting = false
                    self.recorderStartTask = nil
                    self.elapsedTimer?.invalidate()
                    if self.phase == .idle || Task.isCancelled {
                        self.currentSession = nil
                        return
                    }
                    self.fail(error)
                }
            }
        }
    }

    func pauseRecording() {
        guard phase == .recording else { return }
        phase = .paused
        elapsedTimer?.invalidate()
        clickRecorder.pause()
        Task { await recorder.pause() }
        toolbarController?.refresh()
        statusController?.refresh()
    }

    func resumeRecording() {
        guard phase == .paused else { return }
        phase = .recording
        clickRecorder.resume()
        Task { await recorder.resume() }
        startElapsedTimer()
        toolbarController?.refresh()
        statusController?.refresh()
    }

    func stopRecording() {
        if phase == .countdown {
            cancelRecording()
            return
        }
        guard phase == .recording || phase == .paused else { return }

        if recorderIsStarting {
            pendingStopAfterStart = true
            return
        }

        countdownTimer?.invalidate()
        elapsedTimer?.invalidate()
        phase = .finalizing
        toolbarController?.refresh()
        statusController?.refresh()

        Task {
            do {
                let project = try await recorder.stopAndEncode()
                let clickEvents = self.clickRecorder.stop()
                await MainActor.run {
                    var completedProject = project
                    completedProject.clickEvents = clickEvents
                    self.persistProject(completedProject)
                    self.addProject(completedProject)
                    self.activeProject = completedProject
                    self.phase = .finished
                    self.toolbarController?.showFinished(near: self.currentRegion)
                    self.openEditor(project: completedProject)
                    self.statusController?.refresh()
                }
            } catch {
                await MainActor.run {
                    self.fail(error)
                }
            }
        }
    }

    func cancelRecording() {
        countdownTimer?.invalidate()
        elapsedTimer?.invalidate()
        recorderStartTask?.cancel()
        recorderStartTask = nil
        recorderIsStarting = false
        pendingStopAfterStart = false
        _ = clickRecorder.stop()
        Task { await recorder.cancel() }
        phase = .idle
        currentRegion = nil
        toolbarController?.hide()
        regionSelector?.close()
        statusController?.refresh()
    }

    func openEditor(project: Project) {
        activeProject = project
        editorController?.show(project: project)
    }

    func openSettings() {
        settingsController?.show()
    }

    func openLibraryFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: settings.savePath))
    }

    func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func recheckPermission() {
        refreshPermissionStatus()
        if hasScreenRecordingPermission {
            permissionController?.close()
            phase = .idle
            message = "Permission granted. Start a new recording from the status panel."
        } else {
            message = "Screen Recording permission is still missing."
        }
    }

    func importVideo() {
        closeStatusPanel()

        let panel = NSOpenPanel()
        panel.title = "Import Video"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "m4v") ?? .movie,
            UTType(filenameExtension: "webm") ?? .movie
        ]

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.importVideo(from: url)
        }
    }

    func importVideo(from url: URL) {
        closeStatusPanel()
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        createProjectFromImportedVideo(url)
    }

    func importDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard let provider = fileProviders.first else {
            fail(GifrogError.unsupportedFile)
            return false
        }

        if providers.count > 1 {
            message = "Only the first dropped video was imported."
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            guard let self else { return }
            guard error == nil, let url = Self.fileURL(from: item) else {
                DispatchQueue.main.async {
                    self.fail(GifrogError.unsupportedFile)
                }
                return
            }

            DispatchQueue.main.async {
                self.importVideo(from: url)
            }
        }

        return true
    }

    func export(project: Project, edit: EditDecision) {
        exportTask?.cancel()
        exportToken?.cancel()

        let token = ProcessCancellationToken()
        exportToken = token
        phase = .exporting
        exportProgress = 0.18
        statusController?.refresh()

        exportTask = Task {
            do {
                let exported = try await ExportManager.export(
                    project: project,
                    edit: edit,
                    savePath: URL(fileURLWithPath: settings.savePath),
                    cancellationToken: token
                )
                await MainActor.run {
                    guard self.exportToken === token else { return }
                    self.exportTask = nil
                    self.exportToken = nil
                    self.exportProgress = 1
                    self.lastExport = exported
                    self.phase = .finished
                    self.attach(exported: exported, to: project)
                    self.copyToClipboard(exported)
                    self.message = "Exported \(exported.format.rawValue): \(exported.sizeBytes.fileSizeString)"
                    self.statusController?.refresh()
                }
            } catch {
                await MainActor.run {
                    guard self.exportToken === token else { return }
                    self.exportTask = nil
                    self.exportToken = nil
                    if token.isCancelled || (error as? GifrogError) == .exportCancelled {
                        self.exportProgress = 0
                        self.phase = .finished
                        self.message = "Export canceled."
                        self.statusController?.refresh()
                    } else {
                        self.fail(error)
                    }
                }
            }
        }
    }

    func quickExportActiveProject(as format: ExportFormat) {
        guard let project = activeProject ?? projects.first else {
            message = "No recent project to export."
            statusController?.refresh()
            return
        }
        export(project: project, edit: EditDecision.defaults(for: project, settings: settings, format: format))
    }

    func cancelExport() {
        exportToken?.cancel()
        exportTask?.cancel()
        exportTask = nil
        exportToken = nil
        exportProgress = 0
        phase = .finished
        message = "Export canceled."
        statusController?.refresh()
    }

    func copyLastExport() {
        guard let file = lastExport ?? projects.lazy.compactMap(\.exports.first).first else { return }
        copyToClipboard(file)
        message = "Copied \(file.format.rawValue) to clipboard."
    }

    func copyToClipboard(_ exported: ExportedFile) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([exported.url as NSURL])
    }

    func openInFinder(_ exported: ExportedFile) {
        NSWorkspace.shared.activateFileViewerSelecting([exported.url])
    }

    func saveSettings() {
        AppPaths.prepare()
        if let data = try? JSONEncoder.pretty.encode(settings) {
            try? data.write(to: AppPaths.settings)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                settings.launchAtLogin = enabled
                saveSettings()
            } catch {
                settings.launchAtLogin = false
                saveSettings()
                message = GifrogError.launchAtLoginFailed(error.localizedDescription).errorDescription
            }
        } else {
            settings.launchAtLogin = false
            saveSettings()
            message = "Launch at login requires macOS 13 or later."
        }
    }

    // MARK: - Crash Recovery

    private func recoverIncompleteRecordings() {
        let projectsDir = AppPaths.projects
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for dir in contents {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let projectJSON = dir.appendingPathComponent("project.json")
            let sourceMOV = dir.appendingPathComponent("source.mov")

            // Skip if project.json already exists (normal project)
            if FileManager.default.fileExists(atPath: projectJSON.path) { continue }

            // Skip if no source file or it's empty
            guard FileManager.default.fileExists(atPath: sourceMOV.path),
                  let attrs = try? FileManager.default.attributesOfItem(atPath: sourceMOV.path),
                  (attrs[.size] as? Int64 ?? 0) > 0 else {
                // Clean up empty project dirs
                try? FileManager.default.removeItem(at: dir)
                continue
            }

            // Recover: create project.json from the source video
            let metadata = FrameRecorder.metadata(for: sourceMOV)
            guard metadata.duration > 0, metadata.width > 0 else {
                try? FileManager.default.removeItem(at: dir)
                continue
            }

            let thumbnailURL = dir.appendingPathComponent("thumbnails/poster.png")
            try? FileManager.default.createDirectory(at: thumbnailURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FrameRecorder.writeThumbnail(for: sourceMOV, to: thumbnailURL)

            let recoveredName = "Recovered Recording \(dir.lastPathComponent.prefix(8))"
            let project = Project(
                id: UUID(uuidString: dir.lastPathComponent) ?? UUID(),
                name: recoveredName,
                sourceType: "screenRecording",
                sourceURLString: sourceMOV.path,
                thumbnailURLString: FileManager.default.fileExists(atPath: thumbnailURL.path) ? thumbnailURL.path : nil,
                durationSeconds: metadata.duration,
                width: metadata.width,
                height: metadata.height,
                fps: 15,
                createdAt: Date()
            )

            if let data = try? JSONEncoder.pretty.encode(project) {
                try? data.write(to: projectJSON)
            }

            addProject(project)
        }
    }

    // MARK: - Private Helpers

    private func createProjectFromImportedVideo(_ url: URL) {
        let supported = ["mp4", "mov", "m4v", "webm"]
        guard supported.contains(url.pathExtension.lowercased()) else {
            fail(GifrogError.unsupportedFile)
            return
        }

        do {
            let id = UUID()
            let projectDir = AppPaths.projects.appendingPathComponent(id.uuidString, isDirectory: true)
            let exportsDir = projectDir.appendingPathComponent("exports", isDirectory: true)
            let thumbnailsDir = projectDir.appendingPathComponent("thumbnails", isDirectory: true)
            try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)

            let destination = projectDir.appendingPathComponent("source.\(url.pathExtension.lowercased())")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)

            let metadata = FrameRecorder.metadata(for: destination)
            let thumbnailURL = thumbnailsDir.appendingPathComponent("poster.png")
            FrameRecorder.writeThumbnail(for: destination, to: thumbnailURL)

            let project = Project(
                id: id,
                name: url.deletingPathExtension().lastPathComponent,
                sourceType: "importedVideo",
                sourceURLString: destination.path,
                thumbnailURLString: FileManager.default.fileExists(atPath: thumbnailURL.path) ? thumbnailURL.path : nil,
                durationSeconds: metadata.duration,
                width: metadata.width,
                height: metadata.height,
                fps: Double(settings.defaultFPS),
                createdAt: Date()
            )

            let projectJSON = projectDir.appendingPathComponent("project.json")
            try JSONEncoder.pretty.encode(project).write(to: projectJSON)
            addProject(project)
            if metadata.duration > 60 {
                message = "Imported video is over 60 seconds. Trim before exporting GIF."
            }
            openEditor(project: project)
        } catch {
            fail(error)
        }
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let url = item as? NSURL {
            return url as URL
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            return URL(string: string) ?? URL(fileURLWithPath: string)
        }
        return nil
    }

    private func makePreviewProject() -> Project {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-00000000F00D") ?? UUID()
        let projectDir = AppPaths.projects.appendingPathComponent("ui-preview", isDirectory: true)
        let thumbnailsDir = projectDir.appendingPathComponent("thumbnails", isDirectory: true)
        let sourceURL = projectDir.appendingPathComponent("source.mov")
        let thumbnailURL = thumbnailsDir.appendingPathComponent("poster.png")

        try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: projectDir.appendingPathComponent("exports", isDirectory: true), withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: sourceURL.path),
           let ffmpeg = try? Shell.ffmpegPath() {
            _ = try? Shell.run(ffmpeg, [
                "-y",
                "-f", "lavfi",
                "-i", "testsrc2=size=1280x720:rate=30:duration=4",
                "-vf", "format=yuv420p",
                "-c:v", "libx264",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                sourceURL.path
            ])
        }

        if FileManager.default.fileExists(atPath: sourceURL.path) {
            FrameRecorder.writeThumbnail(for: sourceURL, to: thumbnailURL)
        }

        var project = Project(
            id: projectID,
            name: "Screen Recording 2026-06-05",
            sourceType: "screenRecording",
            sourceURLString: sourceURL.path,
            thumbnailURLString: FileManager.default.fileExists(atPath: thumbnailURL.path) ? thumbnailURL.path : nil,
            durationSeconds: 4,
            width: 1280,
            height: 720,
            fps: 30,
            createdAt: Date()
        )
        project.clickEvents = [
            ClickEvent(time: 0.55, normalizedX: 0.35, normalizedY: 0.48, button: .left),
            ClickEvent(time: 1.45, normalizedX: 0.62, normalizedY: 0.58, button: .right),
            ClickEvent(time: 2.65, normalizedX: 0.50, normalizedY: 0.32, button: .left)
        ]
        project.exports = [
            ExportedFile(format: .gif, urlString: AppPaths.defaultSavePath.appendingPathComponent("Preview Export.gif").path, sizeBytes: 4_200_000)
        ]
        return project
    }

    private func render<V: View>(_ view: V, size: CGSize, to url: URL) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layoutSubtreeIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return
        }
        try? data.write(to: url)
    }

    private func startElapsedTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.elapsedTimer?.invalidate()
            self.elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.elapsed += 0.25
            }
        }
    }

    private func addProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)
        projects = Array(projects.prefix(20))
        persistHistory()
    }

    private func persistProject(_ project: Project) {
        let projectDir = project.sourceURL.deletingLastPathComponent()
        let projectJSON = projectDir.appendingPathComponent("project.json")
        if let data = try? JSONEncoder.pretty.encode(project) {
            try? data.write(to: projectJSON)
        }
    }

    private func attach(exported: ExportedFile, to project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].exports.insert(exported, at: 0)
        persistProject(projects[index])
        if activeProject?.id == project.id {
            activeProject = projects[index]
        }
        persistHistory()
    }

    private func loadSettings() {
        if let data = try? Data(contentsOf: AppPaths.settings),
           let settings = try? JSONDecoder.app.decode(AppSettings.self, from: data) {
            self.settings = settings
        }
    }

    private func loadHistory() {
        if let data = try? Data(contentsOf: AppPaths.history),
           let projects = try? JSONDecoder.app.decode([Project].self, from: data) {
            self.projects = projects
        }
    }

    private func persistHistory() {
        if let data = try? JSONEncoder.pretty.encode(projects) {
            try? data.write(to: AppPaths.history)
        }
    }

    private func fail(_ error: Error) {
        phase = .error
        message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        toolbarController?.hide()
        statusController?.refresh()
    }
}
