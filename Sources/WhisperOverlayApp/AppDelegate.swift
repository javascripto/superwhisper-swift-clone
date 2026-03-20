import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var windowController: OverlayWindowController?
    private var statusItemController: StatusItemController?
    private var hotKeyController: HotKeyController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.app.info("Application launched")
        let windowController = OverlayWindowController(appState: appState)
        self.windowController = windowController

        let settingsWindowController = SettingsWindowController(preferences: appState.preferences)
        self.settingsWindowController = settingsWindowController

        let statusItemController = StatusItemController(
            onToggleRecording: { [weak self] in
                self?.handleMenuToggle()
            },
            onShowWindow: { [weak self] in
                self?.windowController?.show()
            },
            onOpenSettings: { [weak self] in
                self?.settingsWindowController?.showWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        self.statusItemController = statusItemController

        let hotKeyController = HotKeyController(
            onPress: { [weak self] in
                self?.handleHotKeyPress()
            },
            onRelease: { [weak self] in
                self?.handleHotKeyRelease()
            }
        )
        self.hotKeyController = hotKeyController
        hotKeyController.start()

        windowController.show()
        appState.message = "Ready. Hold Right Command to record."
    }

    private func handleHotKeyPress() {
        guard !appState.isRecording else { return }
        AppLogger.app.info("Hotkey pressed")
        Task { @MainActor in
            await startRecording()
        }
    }

    private func handleHotKeyRelease() {
        guard appState.isRecording else { return }
        AppLogger.app.info("Hotkey released")
        Task { @MainActor in
            await stopAndTranscribe()
        }
    }

    private func handleMenuToggle() {
        if appState.isRecording {
            handleHotKeyRelease()
        } else {
            handleHotKeyPress()
        }
    }

    @MainActor
    private func startRecording() async {
        do {
            guard await appState.audioRecorder.requestPermissionIfNeeded() else {
                appState.message = "Microphone permission is required."
                return
            }

            let url = try await appState.audioRecorder.startRecording()
            appState.currentRecordingURL = url
            appState.isRecording = true
            appState.overlayMode = .recording
            appState.message = "Recording..."
            AppLogger.audio.info("Recording started at \(url.path, privacy: .public)")
            if appState.preferences.soundsEnabled {
                appState.soundService.playStartSound()
            }
            windowController?.show()
        } catch {
            appState.overlayMode = .error
            appState.message = "Could not start recording: \(error.localizedDescription)"
            windowController?.show()
        }
    }

    @MainActor
    private func stopAndTranscribe() async {
        do {
            appState.overlayMode = .transcribing
            appState.message = "Transcribing..."
            windowController?.show()

            guard let recordedURL = await appState.audioRecorder.stopRecording() else {
                appState.isRecording = false
                appState.overlayMode = .idle
                appState.message = "Nothing recorded."
                AppLogger.audio.warning("Stop requested but no recording was active")
                return
            }

            defer {
                appState.audioRecorder.deleteRecording(at: recordedURL)
                appState.currentRecordingURL = nil
                AppLogger.audio.info("Deleted temporary recording \(recordedURL.path, privacy: .public)")
            }

            if appState.preferences.soundsEnabled {
                appState.soundService.playStopSound()
            }
            appState.isRecording = false
            AppLogger.transcription.info("Transcribing \(recordedURL.lastPathComponent, privacy: .public)")
            let result = try await appState.transcriptionService.transcribe(audioURL: recordedURL)
            appState.lastTranscript = result.text
            appState.message = result.text.isEmpty ? "No text detected." : "Done."
            appState.overlayMode = .idle
            windowController?.show()
            AppLogger.transcription.info("Transcription completed with \(result.text.count) characters")

            if !result.text.isEmpty {
                if appState.preferences.autoInsertEnabled {
                    AppLogger.insertion.info("Inserting transcript via paste")
                    await appState.textInsertionService.copyAndPaste(result.text)
                } else {
                    AppLogger.insertion.info("Auto insert disabled; copying transcript only")
                    appState.textInsertionService.copyToClipboard(result.text)
                }
            }

        } catch {
            appState.isRecording = false
            appState.overlayMode = .error
            appState.message = "Transcription failed: \(error.localizedDescription)"
            AppLogger.transcription.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            windowController?.show()
        }
    }
}
