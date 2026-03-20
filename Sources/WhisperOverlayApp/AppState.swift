import Foundation
import SwiftUI
import AppKit

enum OverlayMode: String {
    case idle
    case recording
    case transcribing
    case error
}

final class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var overlayMode: OverlayMode = .idle
    @Published var message = "Ready."
    @Published var lastTranscript = ""
    @Published var currentRecordingURL: URL?
    @Published var recordingElapsed: TimeInterval = 0
    @Published var recordingLevel: Double = 0
    @Published var recordingTargetProcessIdentifier: pid_t?

    let preferences = AppPreferences()
    let audioRecorder = AudioRecorderService()
    let transcriptionService: TranscriptionService
    let textInsertionService = TextInsertionService()
    let soundService = SoundService()
    let mediaKeyService = MediaKeyService()

    init() {
        self.transcriptionService = WhisperCppCLITranscriptionService(configurationProvider: { [preferences] in
            AppConfiguration.current(preferences: preferences)
        })
    }
}
