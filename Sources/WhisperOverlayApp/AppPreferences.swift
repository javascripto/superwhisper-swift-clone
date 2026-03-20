import Foundation
import SwiftUI

final class AppPreferences: ObservableObject {
    @Published var autoInsertEnabled: Bool {
        didSet { save() }
    }

    @Published var soundsEnabled: Bool {
        didSet { save() }
    }

    @Published var language: String {
        didSet { save() }
    }

    @Published var modelFileName: String {
        didSet { save() }
    }

    private let defaults: UserDefaults

    private enum Key {
        static let autoInsertEnabled = "WhisperOverlay.autoInsertEnabled"
        static let soundsEnabled = "WhisperOverlay.soundsEnabled"
        static let language = "WhisperOverlay.language"
        static let modelFileName = "WhisperOverlay.modelFileName"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoInsertEnabled = defaults.object(forKey: Key.autoInsertEnabled) as? Bool ?? true
        self.soundsEnabled = defaults.object(forKey: Key.soundsEnabled) as? Bool ?? true
        self.language = AppPreferences.normalized(
            defaults.string(forKey: Key.language),
            fallback: "pt"
        )
        self.modelFileName = AppPreferences.normalized(
            defaults.string(forKey: Key.modelFileName),
            fallback: "ggml-base.bin"
        )
    }

    private func save() {
        defaults.set(autoInsertEnabled, forKey: Key.autoInsertEnabled)
        defaults.set(soundsEnabled, forKey: Key.soundsEnabled)
        defaults.set(language, forKey: Key.language)
        defaults.set(modelFileName, forKey: Key.modelFileName)
    }

    private static func normalized(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
