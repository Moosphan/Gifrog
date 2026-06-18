import SwiftUI

struct WindowPickerView: View {
    @ObservedObject var app: GifrogController
    var windows: [CapturableWindow]
    var preferredWindowID: UInt32?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose Window")
                .font(.system(size: 18, weight: .semibold))
                .padding(18)
            List(windows) { window in
                Button {
                    app.prepareRecording(region: window.captureRegion)
                    NSApp.keyWindow?.close()
                } label: {
                    HStack(spacing: 12) {
                        WindowThumbnailView(window: window)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(window.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text("\(Int(window.bounds.width)) x \(Int(window.bounds.height))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(UI.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background {
                        if window.id == preferredWindowID {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(UI.primary.opacity(0.10))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 420, height: 480)
    }
}

struct WindowThumbnailView: View {
    let window: CapturableWindow
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.08)))
            } else {
                ZStack {
                    UI.surfaceLow
                    Image(systemName: "macwindow")
                        .foregroundStyle(UI.secondaryText)
                }
                .frame(width: 64, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let image = window.thumbnail()
                DispatchQueue.main.async {
                    thumbnail = image
                }
            }
        }
    }
}
