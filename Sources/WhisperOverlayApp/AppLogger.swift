import OSLog

enum AppLogger {
    static let app = Logger(subsystem: "com.codexplayground.WhisperOverlay", category: "app")
    static let audio = Logger(subsystem: "com.codexplayground.WhisperOverlay", category: "audio")
    static let transcription = Logger(subsystem: "com.codexplayground.WhisperOverlay", category: "transcription")
    static let insertion = Logger(subsystem: "com.codexplayground.WhisperOverlay", category: "insertion")
}
