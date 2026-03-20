APP_NAME := WhisperOverlayApp
APP_BUNDLE := dist/WhisperOverlay.app
APP_EXECUTABLE := $(APP_BUNDLE)/Contents/MacOS/WhisperOverlayApp
INFO_PLIST := Resources/Info.plist
APP_ICON := Resources/AppIcon.icns
APP_CONFIG_TEMPLATE := Resources/AppConfig.plist.in
APP_CONFIG_OUTPUT := $(APP_BUNDLE)/Contents/Resources/AppConfig.plist
SWIFT := swift
WHISPER_DIR := whisper.cpp
WHISPER_CLI := $(WHISPER_DIR)/build/bin/whisper-cli
DEFAULT_MODEL := $(WHISPER_DIR)/models/ggml-base.bin
MODEL ?= base
LANGUAGE ?= pt
MODEL_FILE_NAME := ggml-$(MODEL).bin
MODEL_SOURCE := $(WHISPER_DIR)/models/$(MODEL_FILE_NAME)

.PHONY: build build-release run test clean whisper-cli model icon bundle open

build:
	$(SWIFT) build

build-release:
	$(SWIFT) build -c release

run: build
	$(SWIFT) run $(APP_NAME)

test:
	$(SWIFT) test

whisper-cli:
	$(MAKE) -C $(WHISPER_DIR) build

model:
	bash $(WHISPER_DIR)/models/download-ggml-model.sh $(MODEL)

icon:
	python3 Scripts/generate_app_icon.py

bundle: icon build-release
	@if [ ! -f "$(MODEL_SOURCE)" ]; then $(MAKE) model MODEL=$(MODEL); fi
	@test -x $(WHISPER_CLI) || (echo "Missing $(WHISPER_CLI). Build whisper.cpp first with 'make whisper-cli' on a machine with cmake installed." && false)
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp .build/release/$(APP_NAME) $(APP_EXECUTABLE)
	cp $(INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	cp $(APP_ICON) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp $(WHISPER_CLI) $(APP_BUNDLE)/Contents/MacOS/whisper-cli
	chmod +x $(APP_BUNDLE)/Contents/MacOS/whisper-cli
	sed -e 's|__MODEL_FILE_NAME__|$(MODEL_FILE_NAME)|g' -e 's|__LANGUAGE__|$(LANGUAGE)|g' $(APP_CONFIG_TEMPLATE) > $(APP_CONFIG_OUTPUT)
	cp $(MODEL_SOURCE) $(APP_BUNDLE)/Contents/Resources/$(MODEL_FILE_NAME)
	@if [ -d "Resources/Assets.xcassets" ]; then cp -R Resources/Assets.xcassets $(APP_BUNDLE)/Contents/Resources/; fi
	@echo "Bundled $(APP_BUNDLE)"

open: bundle
	open $(APP_BUNDLE)

clean:
	$(SWIFT) package clean
	$(MAKE) -C $(WHISPER_DIR) clean
	rm -rf dist
