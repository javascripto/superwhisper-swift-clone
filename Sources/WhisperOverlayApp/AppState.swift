import Foundation
import SwiftUI

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

    let preferences = AppPreferences()
    let audioRecorder = AudioRecorderService()
    let transcriptionService: TranscriptionService
    let textInsertionService = TextInsertionService()
    let soundService = SoundService()

    init() {
        self.transcriptionService = WhisperCppCLITranscriptionService(configurationProvider: { [preferences] in
            AppConfiguration.current(preferences: preferences)
        })
    }
}
