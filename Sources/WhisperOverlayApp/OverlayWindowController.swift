import AppKit
import SwiftUI

final class OverlayWindowController {
    private let appState: AppState
    private let panel: PersistentOverlayPanel

    init(appState: AppState) {
        self.appState = appState
        panel = PersistentOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        let rootView = OverlayView(appState: appState) { [weak panel] in
            panel?.orderOut(nil)
        }
        let hostingView = NSHostingView(rootView: rootView)

        panel.contentView = hostingView
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        if !panel.restoreSavedOriginIfAvailable() {
            panel.centerInVisibleFrameIfNeeded()
        }
    }

    func show(activateApp: Bool = false) {
        panel.orderFrontRegardless()
        if activateApp {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }
}

struct OverlayView: View {
    @ObservedObject var appState: AppState
    let onClose: () -> Void
    @State private var pulse = false

    var body: some View {
        let colors = colorsForMode(appState.overlayMode)

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(colors.opacity(0.18))
                            .frame(width: 54, height: 54)
                            .scaleEffect(pulse ? 1.05 : 0.88)
                        Circle()
                            .strokeBorder(colors.opacity(0.45), lineWidth: 1.5)
                            .frame(width: 54, height: 54)
                        Circle()
                            .fill(colors)
                            .frame(width: 18, height: 18)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(appState.message)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                if !appState.lastTranscript.isEmpty {
                    Text(appState.lastTranscript)
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.trailing, 4)
            .accessibilityLabel("Hide window")
            .help("Hide window")
        }
        .padding(20)
        .frame(width: 420, height: 160, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.10, blue: 0.13).opacity(0.93),
                            Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        .onAppear {
            pulse = true
        }
        .onChange(of: appState.overlayMode) { _ in
            pulse = true
        }
        .animation(
            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
            value: pulse
        )
    }

    private var title: String {
        switch appState.overlayMode {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .error:
            return "Attention"
        }
    }

    private func colorsForMode(_ mode: OverlayMode) -> Color {
        switch mode {
        case .idle:
            return Color(red: 0.30, green: 0.78, blue: 0.94)
        case .recording:
            return Color(red: 0.98, green: 0.34, blue: 0.32)
        case .transcribing:
            return Color(red: 0.95, green: 0.77, blue: 0.28)
        case .error:
            return Color(red: 1.00, green: 0.46, blue: 0.60)
        }
    }
}
