import Foundation

struct AppConfiguration {
    let whisperBinaryURL: URL
    let modelURL: URL
    let language: String
    let threads: Int32

    private struct RuntimeConfig {
        let modelFileName: String
        let language: String

        static let `default` = RuntimeConfig(
            modelFileName: "ggml-base.bin",
            language: "pt"
        )
    }

    static var `default`: AppConfiguration {
        let runtimeConfig = loadRuntimeConfig()
        return resolved(modelFileName: runtimeConfig.modelFileName, language: runtimeConfig.language)
    }

    static func current(preferences: AppPreferences) -> AppConfiguration {
        let runtimeConfig = loadRuntimeConfig()
        let modelFileName = trimmed(preferences.modelFileName, fallback: runtimeConfig.modelFileName)
        let language = trimmed(preferences.language, fallback: runtimeConfig.language)
        return resolved(modelFileName: modelFileName, language: language)
    }

    private static func resolved(modelFileName: String, language: String) -> AppConfiguration {
        let bundle = Bundle.main
        let isAppBundle = bundle.bundleURL.pathExtension == "app"
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let whisperBinaryURL: URL
        let modelURL: URL

        if isAppBundle, let resourceURL = bundle.resourceURL, let executableURL = bundle.executableURL {
            whisperBinaryURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("whisper-cli")
            modelURL = resourceURL
                .appendingPathComponent(modelFileName)
        } else {
            whisperBinaryURL = cwd
                .appendingPathComponent("whisper.cpp")
                .appendingPathComponent("build")
                .appendingPathComponent("bin")
                .appendingPathComponent("whisper-cli")
            modelURL = cwd
                .appendingPathComponent("whisper.cpp")
                .appendingPathComponent("models")
                .appendingPathComponent(modelFileName)
        }

        return AppConfiguration(
            whisperBinaryURL: whisperBinaryURL,
            modelURL: modelURL,
            language: language,
            threads: Int32(max(1, min(6, ProcessInfo.processInfo.processorCount - 2)))
        )
    }

    private static func loadRuntimeConfig() -> RuntimeConfig {
        let bundle = Bundle.main
        guard bundle.bundleURL.pathExtension == "app",
              let resourceURL = bundle.resourceURL else {
            return .default
        }

        let configURL = resourceURL.appendingPathComponent("AppConfig.plist")
        guard let data = try? Data(contentsOf: configURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let dict = plist as? [String: Any] else {
            return .default
        }

        let modelFileName = (dict["ModelFileName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = (dict["Language"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedModelFileName = {
            if let modelFileName, !modelFileName.isEmpty {
                return modelFileName
            }
            return RuntimeConfig.default.modelFileName
        }()
        let resolvedLanguage = {
            if let language, !language.isEmpty {
                return language
            }
            return RuntimeConfig.default.language
        }()

        return RuntimeConfig(
            modelFileName: resolvedModelFileName,
            language: resolvedLanguage
        )
    }

    private static func trimmed(_ value: String, fallback: String) -> String {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }
}
