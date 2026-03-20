import AppKit

final class PersistentOverlayPanel: NSPanel {
    private let positionKey = "WhisperOverlayPanelOrigin"

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        saveOrigin(point)
    }

    func restoreSavedOriginIfAvailable() -> Bool {
        guard let origin = savedOrigin() else {
            return false
        }

        super.setFrameOrigin(origin)
        return true
    }

    func centerInVisibleFrameIfNeeded() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let size = frame.size
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.maxY - size.height - 48
        )
        super.setFrameOrigin(origin)
        saveOrigin(origin)
    }

    private func savedOrigin() -> NSPoint? {
        let defaults = UserDefaults.standard
        let xKey = "\(positionKey).x"
        let yKey = "\(positionKey).y"

        guard defaults.object(forKey: xKey) != nil,
              defaults.object(forKey: yKey) != nil else {
            return nil
        }

        return NSPoint(
            x: defaults.double(forKey: xKey),
            y: defaults.double(forKey: yKey)
        )
    }

    private func saveOrigin(_ point: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(point.x, forKey: "\(positionKey).x")
        defaults.set(point.y, forKey: "\(positionKey).y")
    }
}
