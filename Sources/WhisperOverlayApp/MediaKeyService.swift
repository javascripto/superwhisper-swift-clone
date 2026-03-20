import AppKit
import Foundation
import Quartz

final class MediaKeyService {
    private var shouldResumeMedia = false

    func pausePlaybackIfEnabled() {
        shouldResumeMedia = sendPlayPauseMediaKey()
        if shouldResumeMedia {
            AppLogger.app.info("Sent media play/pause key to pause playback")
        } else {
            AppLogger.app.info("Could not send media play/pause key")
        }
    }

    func resumePlaybackIfNeeded() {
        guard shouldResumeMedia else {
            return
        }

        _ = sendPlayPauseMediaKey()
        AppLogger.app.info("Sent media play/pause key to resume playback")
        shouldResumeMedia = false
    }

    private func sendPlayPauseMediaKey() -> Bool {
        let key: UInt32 = 16
        let downFlags = NSEvent.ModifierFlags(rawValue: 0xA00)
        let upFlags = NSEvent.ModifierFlags(rawValue: 0xB00)

        let downEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: downFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | (0xA << 8)),
            data2: -1
        )

        let upEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: upFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | (0xB << 8)),
            data2: -1
        )

        guard let downCGEvent = downEvent?.cgEvent, let upCGEvent = upEvent?.cgEvent else {
            AppLogger.app.error("Failed to create media play/pause key event")
            return false
        }

        downCGEvent.post(tap: CGEventTapLocation.cghidEventTap)
        upCGEvent.post(tap: CGEventTapLocation.cghidEventTap)
        return true
    }
}
