import AppKit
import Foundation

final class HotKeyController {
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private var eventMonitor: Any?
    private var isRightCommandDown = false

    init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    deinit {
        stop()
    }

    func start() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        isRightCommandDown = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == 54 else { return }

        let rightCommandPressed = event.modifierFlags.contains(.command)
        if rightCommandPressed, !isRightCommandDown {
            isRightCommandDown = true
            onPress()
        } else if !rightCommandPressed, isRightCommandDown {
            isRightCommandDown = false
            onRelease()
        }
    }
}
