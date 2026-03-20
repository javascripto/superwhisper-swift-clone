import AppKit
import ApplicationServices
import Foundation

final class TextInsertionService {
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        AppLogger.insertion.info("Copied \(text.count) characters to clipboard")
    }

    func copyAndPaste(
        _ text: String,
        targetProcessIdentifier pid: pid_t? = nil
    ) async -> Bool {
        copyToClipboard(text)

        guard !text.isEmpty else {
            return false
        }

        logPasteContext(targetProcessIdentifier: pid, phase: "before-activate")

        if let pid {
            await activateApplication(processIdentifier: pid)
        }

        try? await Task.sleep(nanoseconds: 500_000_000)

        logPasteContext(targetProcessIdentifier: pid, phase: "before-post")

        if let pid, await insertTextUsingAccessibility(text, targetProcessIdentifier: pid) {
            AppLogger.insertion.info("Inserted text directly through Accessibility")
            return true
        }

        if let pid {
            AppLogger.insertion.warning("Accessibility insertion failed for pid \(pid, privacy: .public)")
        }

        if await pasteWithAppleScript() {
            AppLogger.insertion.info("AppleScript Command-V posted")
            return true
        }

        AppLogger.insertion.warning("AppleScript paste failed, falling back to synthetic Command-V")

        if await fallbackPaste() {
            AppLogger.insertion.info("Synthetic Command-V posted")
            return true
        }

        AppLogger.insertion.warning("Synthetic paste failed")
        return false
    }

    private func activateApplication(processIdentifier pid: pid_t) async {
        guard pid != getpid(),
              let application = NSRunningApplication(processIdentifier: pid) else {
            AppLogger.insertion.warning("Could not resolve target application for pid \(pid, privacy: .public)")
            return
        }

        let activated = application.activate(options: [.activateIgnoringOtherApps])
        AppLogger.insertion.info("Requested activation for pid \(pid, privacy: .public), success=\(activated, privacy: .public)")

        try? await Task.sleep(nanoseconds: 120_000_000)
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            AppLogger.insertion.info("Frontmost after activation: \(frontmost.localizedName ?? "unknown", privacy: .public) pid=\(frontmost.processIdentifier, privacy: .public)")
        }
    }

    private func pasteWithAppleScript() async -> Bool {
        let script = NSAppleScript(source: """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """)

        guard let script else {
            AppLogger.insertion.error("Could not create AppleScript")
            return false
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            AppLogger.insertion.error("AppleScript paste error: \(errorInfo, privacy: .public)")
            return false
        }

        return true
    }

    private func insertTextUsingAccessibility(_ text: String, targetProcessIdentifier pid: pid_t) async -> Bool {
        guard AXIsProcessTrusted() else {
            AppLogger.insertion.warning("Accessibility trust is missing for direct insertion")
            return false
        }

        let application = AXUIElementCreateApplication(pid)
        var focusedElementRef: CFTypeRef?
        let copyError = AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)

        guard copyError == .success, let focusedElement = focusedElementRef else {
            AppLogger.insertion.error("Could not resolve focused UI element for pid \(pid, privacy: .public), error=\(copyError.rawValue, privacy: .public)")
            return false
        }

        logFocusedElementDetails(focusedElement, pid: pid)

        let setError = AXUIElementSetAttributeValue(focusedElement as! AXUIElement, kAXValueAttribute as CFString, text as CFTypeRef)
        if setError == .success {
            return true
        }

        AppLogger.insertion.error("AXUIElementSetAttributeValue failed with error \(setError.rawValue, privacy: .public)")
        return false
    }

    private func fallbackPaste() async -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        guard keyDown != nil, keyUp != nil else {
            return false
        }

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        return true
    }

    private func logPasteContext(targetProcessIdentifier pid: pid_t?, phase: String) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostName = frontmost?.localizedName ?? "unknown"
        let frontmostPid = frontmost?.processIdentifier ?? 0
        let trustedAccessibility = AXIsProcessTrusted()

        if let pid {
            AppLogger.insertion.info(
                "[\(phase, privacy: .public)] target pid=\(pid, privacy: .public) frontmost=\(frontmostName, privacy: .public) frontmostPid=\(frontmostPid, privacy: .public) accessibilityTrusted=\(trustedAccessibility, privacy: .public)"
            )
        } else {
            AppLogger.insertion.info(
                "[\(phase, privacy: .public)] target pid=nil frontmost=\(frontmostName, privacy: .public) frontmostPid=\(frontmostPid, privacy: .public) accessibilityTrusted=\(trustedAccessibility, privacy: .public)"
            )
        }
    }

    private func logFocusedElementDetails(_ elementRef: CFTypeRef, pid: pid_t) {
        let element = elementRef as! AXUIElement
        var roleRef: CFTypeRef?
        var subroleRef: CFTypeRef?
        var titleRef: CFTypeRef?

        let roleError = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let subroleError = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        let titleError = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)

        let role = roleRef as? String ?? "unknown"
        let subrole = subroleRef as? String ?? "unknown"
        let title = titleRef as? String ?? "unknown"

        AppLogger.insertion.info(
            "Focused element for pid \(pid, privacy: .public): role=\(role, privacy: .public) subrole=\(subrole, privacy: .public) title=\(title, privacy: .public) roleErr=\(roleError.rawValue, privacy: .public) subroleErr=\(subroleError.rawValue, privacy: .public) titleErr=\(titleError.rawValue, privacy: .public)"
        )
    }
}
