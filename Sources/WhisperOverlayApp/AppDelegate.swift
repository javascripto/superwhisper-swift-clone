import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var windowController: OverlayWindowController?
    private var statusItemController: StatusItemController?
    private var hotKeyController: HotKeyController?
    private var settingsWindowController: SettingsWindowController?
    private var recordingTimer: Timer?

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
            onHideWindow: { [weak self] in
                self?.windowController?.hide()
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

        windowController.hide()
        statusItemController.setRecording(false)
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

            appState.recordingTargetProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if let pid = appState.recordingTargetProcessIdentifier {
                AppLogger.insertion.info("Captured frontmost target pid \(pid, privacy: .public)")
            } else {
                AppLogger.insertion.info("No frontmost target application captured")
            }

            let url = try await appState.audioRecorder.startRecording()
            appState.currentRecordingURL = url
            appState.isRecording = true
            statusItemController?.setRecording(true)
            appState.overlayMode = .recording
            appState.message = "Recording..."
            appState.lastTranscript = ""
            appState.recordingElapsed = 0
            appState.recordingLevel = 0
            if appState.preferences.pauseMediaDuringRecording {
                appState.mediaKeyService.pausePlaybackIfEnabled()
            }
            startRecordingTimer()
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
                statusItemController?.setRecording(false)
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
            if appState.preferences.pauseMediaDuringRecording {
                appState.mediaKeyService.resumePlaybackIfNeeded()
            }
            appState.isRecording = false
            statusItemController?.setRecording(false)
            stopRecordingTimer()
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
                    _ = await appState.textInsertionService.copyAndPaste(
                        result.text,
                        targetProcessIdentifier: appState.recordingTargetProcessIdentifier
                    )
                } else {
                    AppLogger.insertion.info("Auto insert disabled; copying transcript only")
                    appState.textInsertionService.copyToClipboard(result.text)
                }
            }
            appState.recordingTargetProcessIdentifier = nil

        } catch {
            appState.isRecording = false
            statusItemController?.setRecording(false)
            stopRecordingTimer()
            appState.overlayMode = .error
            appState.message = "Transcription failed: \(error.localizedDescription)"
            AppLogger.transcription.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            appState.recordingTargetProcessIdentifier = nil
            windowController?.show()
        }
    }

    private func startRecordingTimer() {
        stopRecordingTimer()
        let startDate = Date()

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard self.appState.isRecording else {
                timer.invalidate()
                return
            }

            self.appState.recordingElapsed = Date().timeIntervalSince(startDate)
            self.appState.recordingLevel = self.appState.audioRecorder.currentMeterLevel()
        }

        if let recordingTimer {
            RunLoop.main.add(recordingTimer, forMode: .common)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        appState.recordingElapsed = 0
        appState.recordingLevel = 0
    }
}
