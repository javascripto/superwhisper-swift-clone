import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Whisper Settings")
                .font(.system(size: 24, weight: .semibold, design: .rounded))

            Form {
                Section("Behavior") {
                    Toggle("Insert automatically after transcription", isOn: $preferences.autoInsertEnabled)
                    Toggle("Play start/stop sounds", isOn: $preferences.soundsEnabled)
                }

                Section("Transcription") {
                    TextField("Language", text: $preferences.language)
                    TextField("Model file name", text: $preferences.modelFileName)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 6) {
                Text("Examples: `pt`, `en`, `es`")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Model file names usually look like `ggml-base.bin`, `ggml-small.bin` or `ggml-medium.bin`.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 520, height: 280)
    }
}
