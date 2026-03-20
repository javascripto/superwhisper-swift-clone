import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let toggleRecording: () -> Void
    private let showWindow: () -> Void
    private let openSettings: () -> Void
    private let quit: () -> Void

    init(
        onToggleRecording: @escaping () -> Void,
        onShowWindow: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.toggleRecording = onToggleRecording
        self.showWindow = onShowWindow
        self.openSettings = onOpenSettings
        self.quit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.title = "Whisper"

        let menu = NSMenu()
        let hotkeyItem = NSMenuItem(title: "Hotkey: Right Command", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Toggle Recording", action: #selector(handleToggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(handleShowWindow), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func handleToggleRecording() {
        toggleRecording()
    }

    @objc private func handleShowWindow() {
        showWindow()
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }

    @objc private func handleQuit() {
        quit()
    }
}
