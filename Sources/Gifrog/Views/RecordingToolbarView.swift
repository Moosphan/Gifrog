import SwiftUI

struct RecordingToolbarView: View {
    @ObservedObject var app: GifrogController
    var activePopupType: RecordingToolbarController.PopupType?
    var onTogglePopup: (RecordingToolbarController.PopupType) -> Void = { _ in }
    var onDismissPopup: () -> Void = {}
    @State private var dotPulse = false
    @State private var timerTick = false

    var body: some View {
        HStack(spacing: 14) {
            dragHandle
            statusBlock
            parameterCapsule
            controls
            Divider()
                .frame(height: 26)
            Button {
                app.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(IconButtonStyle())
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(UI.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        .frame(height: 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            if app.phase == .recording {
                timerTick.toggle()
            }
        }
    }

    private var dragHandle: some View {
        VStack(spacing: 2) {
            Circle().frame(width: 4, height: 4)
            Circle().frame(width: 4, height: 4)
            Circle().frame(width: 4, height: 4)
        }
        .foregroundStyle(UI.secondaryText.opacity(0.45))
    }

    private var statusBlock: some View {
        HStack(spacing: 7) {
            if app.phase == .recording {
                Circle()
                    .fill(UI.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: UI.red.opacity(dotPulse ? 0.60 : 0.20), radius: dotPulse ? 6 : 2)
                    .opacity(dotPulse ? 1.0 : 0.6)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            dotPulse = true
                        }
                    }
                    .onDisappear { dotPulse = false }
            } else if app.phase == .countdown {
                Text("\(app.countdown)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(UI.red)
                    .frame(width: 26)
            } else {
                Circle()
                    .stroke(UI.primary, lineWidth: 2)
                    .frame(width: 11, height: 11)
            }

            Text(toolbarTime)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(UI.text)
                .frame(width: 66, alignment: .leading)
        }
    }

    private var parameterCapsule: some View {
        HStack(spacing: 10) {
            Label(captureSize, systemImage: "aspectratio")
            separator
            popupTrigger(type: .fps) {
                HStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                    Text("\(app.settings.defaultFPS)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            separator
            popupTrigger(type: .format) {
                HStack(spacing: 3) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 10))
                    Text(app.settings.defaultFormat.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(UI.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 0.5))
    }

    private func popupTrigger<Content: View>(
        type: RecordingToolbarController.PopupType,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = activePopupType == type

        return content()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isActive ? UI.primary.opacity(0.14) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? UI.primary.opacity(0.28) : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture { onTogglePopup(type) }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.black.opacity(0.10))
            .frame(width: 1, height: 13)
    }

    private var controls: some View {
        HStack(spacing: 5) {
            switch app.phase {
            case .ready:
                Button {
                    app.startCountdown()
                } label: {
                    Label("Record", systemImage: "record.circle")
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(PrimaryCircleButtonStyle(color: UI.red))
                Button {
                    app.cancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
            case .countdown:
                Button {
                    app.cancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
            case .recording:
                Button {
                    app.pauseRecording()
                } label: {
                    Image(systemName: "pause.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                Button {
                    app.stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PrimaryCircleButtonStyle(color: UI.primaryDark))
            case .paused:
                Button {
                    app.resumeRecording()
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                Button {
                    app.stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PrimaryCircleButtonStyle(color: UI.primaryDark))
            case .finalizing:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 34, height: 34)
            case .finished:
                Button {
                    if let project = app.activeProject {
                        app.openEditor(project: project)
                    }
                } label: {
                    Image(systemName: "play.rectangle")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                Button {
                    app.quickExportActiveProject(as: .gif)
                } label: {
                    Text("GIF")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(PrimaryRoundedButtonStyle(color: UI.primary))
                Button {
                    app.quickExportActiveProject(as: .mp4)
                } label: {
                    Text("MP4")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 38, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                Button {
                    app.copyLastExport()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                Button {
                    app.repeatLastRegion()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
            default:
                EmptyView()
            }
        }
    }

    private var captureSize: String {
        if let region = app.activeCaptureRegion {
            return region.displaySize
        }
        if let project = app.activeProject {
            return "\(project.width)x\(project.height)"
        }
        return "Region"
    }

    private var toolbarTime: String {
        if app.phase == .countdown { return "Ready" }
        return timeString(app.elapsed)
    }
}

// MARK: - Popup Option Bar

struct PopupOptionBar: View {
    @ObservedObject var state: RecordingToolbarController.PopupOptionBarState
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            PopupSlidingIndicator(selection: CGFloat(state.selectedIndex), count: state.labels.count)

            HStack(spacing: 0) {
                ForEach(state.labels.indices, id: \.self) { index in
                    Text(state.labels[index])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(state.selectedIndex == index ? Color.white : UI.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(index) }
                }
            }
        }
        .padding(3)
        .background(UI.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}

private struct PopupSlidingIndicator: View {
    let selection: CGFloat
    let count: Int

    var body: some View {
        GeometryReader { geo in
            let segWidth = geo.size.width / CGFloat(max(count, 1))

            Capsule()
                .fill(UI.primary)
                .frame(width: segWidth, height: 28)
                .offset(x: selection * segWidth)
        }
        .frame(height: 28)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selection)
    }
}
