import AppKit
import Foundation

final class SoundService {
    private let startSoundURL = URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff")
    private let stopSoundURL = URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")

    func playStartSound() {
        playSound(at: startSoundURL)
    }

    func playStopSound() {
        playSound(at: stopSoundURL)
    }

    private func playSound(at url: URL) {
        if let sound = NSSound(contentsOf: url, byReference: false) {
            sound.play()
            return
        }

        NSSound.beep()
    }
}
