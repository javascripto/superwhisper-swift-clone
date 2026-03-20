import AVFoundation
import Foundation

final class AudioRecorderService {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func requestPermissionIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() async throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WhisperOverlay", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("recording-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw CocoaError(.fileWriteUnknown)
        }

        self.recorder = recorder
        self.recordingURL = url
        AppLogger.audio.info("AudioRecorder prepared \(url.path, privacy: .public)")
        return url
    }

    func stopRecording() async -> URL? {
        recorder?.stop()
        recorder = nil
        defer { recordingURL = nil }
        AppLogger.audio.info("AudioRecorder stopped")
        return recordingURL
    }

    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            AppLogger.audio.error("Failed to delete temporary recording \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
