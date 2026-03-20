import AppKit
import Foundation

final class TextInsertionService {
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        AppLogger.insertion.info("Copied \(text.count) characters to clipboard")
    }

    func copyAndPaste(_ text: String) async {
        copyToClipboard(text)

        guard !text.isEmpty else {
            return
        }

        if await pasteWithAppleEvents() {
            AppLogger.insertion.info("Paste request sent through Apple Events")
            return
        }

        AppLogger.insertion.warning("Apple Events paste failed, falling back to synthetic Command-V")
        await fallbackPaste()
    }

    private func pasteWithAppleEvents() async -> Bool {
        try? await Task.sleep(nanoseconds: 120_000_000)

        guard let script = NSAppleScript(source: """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """) else {
            return false
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)
        return errorInfo == nil
    }

    private func fallbackPaste() async {
        try? await Task.sleep(nanoseconds: 120_000_000)

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        AppLogger.insertion.info("Synthetic Command-V posted")
    }
}
