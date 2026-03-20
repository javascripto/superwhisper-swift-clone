import Foundation

struct TranscriptionResult {
    let text: String
}

protocol TranscriptionService {
    func transcribe(audioURL: URL) async throws -> TranscriptionResult
}

enum TranscriptionError: Error {
    case whisperBinaryMissing(URL)
    case modelMissing(URL)
    case transcriptionFailed(String)
}

final class WhisperCppCLITranscriptionService: TranscriptionService {
    private let configurationProvider: () -> AppConfiguration

    init(configurationProvider: @escaping () -> AppConfiguration) {
        self.configurationProvider = configurationProvider
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        let configuration = configurationProvider()
        AppLogger.transcription.info("Starting CLI transcription with model \(configuration.modelURL.lastPathComponent, privacy: .public)")
        guard FileManager.default.fileExists(atPath: configuration.whisperBinaryURL.path) else {
            throw TranscriptionError.whisperBinaryMissing(configuration.whisperBinaryURL)
        }

        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw TranscriptionError.modelMissing(configuration.modelURL)
        }

        let outputPrefix = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperOverlay")
            .appendingPathComponent("transcript-\(UUID().uuidString)")

        let process = Process()
        process.executableURL = configuration.whisperBinaryURL
        process.arguments = [
            "-m", configuration.modelURL.path,
            "-f", audioURL.path,
            "-l", configuration.language,
            "-t", String(configuration.threads),
            "-np",
            "-nt",
            "-otxt",
            "-of", outputPrefix.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let processOutput = String(decoding: data, as: UTF8.self)
        AppLogger.transcription.info("whisper.cpp finished with exit status \(process.terminationStatus)")

        guard process.terminationStatus == 0 else {
            throw TranscriptionError.transcriptionFailed(processOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let transcriptURL = outputPrefix.appendingPathExtension("txt")
        defer {
            try? FileManager.default.removeItem(at: transcriptURL)
        }

        let text: String
        if FileManager.default.fileExists(atPath: transcriptURL.path) {
            text = (try? String(contentsOf: transcriptURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            text = processOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        AppLogger.transcription.info("Transcript size: \(text.count) characters")

        return TranscriptionResult(text: text)
    }
}
