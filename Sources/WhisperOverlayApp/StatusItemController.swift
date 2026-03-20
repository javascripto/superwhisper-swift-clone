import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let toggleRecording: () -> Void
    private let showWindow: () -> Void
    private let hideWindow: () -> Void
    private let openSettings: () -> Void
    private let quit: () -> Void

    init(
        onToggleRecording: @escaping () -> Void,
        onShowWindow: @escaping () -> Void,
        onHideWindow: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.toggleRecording = onToggleRecording
        self.showWindow = onShowWindow
        self.hideWindow = onHideWindow
        self.openSettings = onOpenSettings
        self.quit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
        setRecording(false)
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.image = statusImage()
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Whisper"
        button.setAccessibilityLabel("Whisper")

        let menu = NSMenu()
        let hotkeyItem = NSMenuItem(title: "Hotkey: Right Command", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Recording", action: #selector(handleToggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(handleShowWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Hide Window", action: #selector(handleHideWindow), keyEquivalent: "h"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    func setRecording(_ isRecording: Bool) {
        statusItem.button?.image = statusImage()
    }

    private func statusImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Whisper")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        image?.isTemplate = true
        return image
    }

    @objc private func handleToggleRecording() {
        toggleRecording()
    }

    @objc private func handleShowWindow() {
        showWindow()
    }

    @objc private func handleHideWindow() {
        hideWindow()
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }

    @objc private func handleQuit() {
        quit()
    }
}
