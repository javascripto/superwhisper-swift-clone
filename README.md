# Whisper Overlay

MacOS app scaffold inspired by Superwhisper, built with Swift and `whisper.cpp`.

## What is in place

- Terminal-first build with `make`
- SwiftPM app target
- Floating translucent overlay window
- Starts hidden and appears while recording
- Can be shown or hidden again from the menu bar
- Global hotkey to toggle recording
- Local audio capture to WAV
- Transcription through `whisper.cpp` CLI
- Automatic insertion into the previously focused app, with clipboard fallback
- Menu bar status item with basic controls
- Settings window for language, model, sounds, and auto-insert behavior
- Custom app icon and terminal-first bundle generation
- Structured runtime logging via `os.Logger`

## Build

```bash
make build
```

## Run

```bash
make run
```

## Bundle

```bash
make bundle
open dist/WhisperOverlay.app
```

You can also choose a different local model at bundle time:

```bash
make bundle MODEL=small LANGUAGE=pt
```

The bundle copies `whisper-cli` into the app and embeds the selected model in `Contents/Resources/`.

## Transfer bundle to another Mac

To create a DMG that includes the app and the local root certificate:

```bash
make package-transfer
```

That produces:

- `dist/WhisperOverlay.dmg`
- `dist/WhisperOverlay-LocalRootCA.cer`

On the other Mac:

1. Open the DMG.
2. Open `WhisperOverlay-LocalRootCA.cer` and add it to Keychain Access.
3. Set the certificate to always trust if macOS asks.
4. Launch `WhisperOverlay.app` from the mounted DMG or copy it to `/Applications`.
5. If macOS still shows a permission prompt, re-enable Accessibility and Automation for that app once.

## Whisper.cpp setup

The app expects:

- `whisper.cpp/build/bin/whisper-cli`
- `whisper.cpp/models/ggml-base.bin` by default, or the model selected at bundle time

To build the CLI:

```bash
make whisper-cli
```

To download a model:

```bash
make model MODEL=base
```

You can also use `tiny`, `small`, `medium`, or `large-v3` depending on what you want to test.

If `whisper.cpp` is missing in a fresh clone, `make bundle` will clone it automatically and then build it before packaging.

## Permissions

The app will need:

- Microphone permission
- Accessibility permission for paste automation
- Automation permission for `System Events`

Temporary audio and transcript files are created under the system temp directory and are cleaned up automatically after transcription.

## Current architecture

- `AppDelegate` coordinates recording, transcription, overlay, and hotkey handling
- `AudioRecorderService` records 16 kHz mono WAV
- `WhisperCppCLITranscriptionService` invokes the local `whisper-cli`
- `AppConfiguration` resolves bundle resources first, then falls back to the repo checkout
- `OverlayWindowController` renders the floating window
- `TextInsertionService` activates the target app, tries direct Accessibility insertion, and falls back to clipboard paste
- `AppPreferences` stores runtime settings in `UserDefaults`
- `SettingsWindowController` and `SettingsView` provide the preferences window
- `AppLogger` writes diagnostics to the system log

## Next steps

1. Improve the overlay with waveform and recording timer.
2. Add a richer model picker instead of a plain filename field.
3. Swap the CLI runner for a direct `whisper.cpp` library binding if needed.
