APP_NAME := WhisperOverlayApp
APP_BUNDLE := dist/WhisperOverlay.app
APP_EXECUTABLE := $(APP_BUNDLE)/Contents/MacOS/WhisperOverlayApp
INFO_PLIST := Resources/Info.plist
APP_ICON := Resources/AppIcon.icns
APP_CONFIG_TEMPLATE := Resources/AppConfig.plist.in
APP_CONFIG_OUTPUT := $(APP_BUNDLE)/Contents/Resources/AppConfig.plist
APP_FRAMEWORKS := $(APP_BUNDLE)/Contents/Frameworks
APP_EXPORT_CERT := dist/WhisperOverlay-LocalRootCA.cer
APP_DMG_STAGE := dist/WhisperOverlay-dmg
APP_EXPORT_DMG := dist/WhisperOverlay.dmg
SWIFT := swift
WHISPER_DIR := whisper.cpp
WHISPER_CLI := $(WHISPER_DIR)/build/bin/whisper-cli
WHISPER_LIB_DIRS := $(WHISPER_DIR)/build/src $(WHISPER_DIR)/build/ggml/src $(WHISPER_DIR)/build/ggml/src/ggml-blas $(WHISPER_DIR)/build/ggml/src/ggml-metal
WHISPER_GIT_URL ?= https://github.com/ggml-org/whisper.cpp.git
DEFAULT_MODEL := $(WHISPER_DIR)/models/ggml-base.bin
MODEL ?= base
LANGUAGE ?= pt
MODEL_FILE_NAME := ggml-$(MODEL).bin
MODEL_SOURCE := $(WHISPER_DIR)/models/$(MODEL_FILE_NAME)
SIGN_IDENTITY ?= WhisperOverlay Local Root CA
ROOT_CERT_NAME ?= WhisperOverlay Local Root CA
CODESIGN := codesign

.PHONY: build build-release run test clean whisper-prepare whisper-cli model icon bundle open sign export-cert package-transfer

build:
	$(SWIFT) build

build-release:
	$(SWIFT) build -c release

run: build
	$(SWIFT) run $(APP_NAME)

test:
	$(SWIFT) test

whisper-cli:
	@$(MAKE) whisper-prepare
	$(MAKE) -C $(WHISPER_DIR) build

model:
	bash $(WHISPER_DIR)/models/download-ggml-model.sh $(MODEL)

whisper-prepare:
	@if [ ! -d "$(WHISPER_DIR)/.git" ] && [ ! -f "$(WHISPER_CLI)" ]; then \
		if [ -f .gitmodules ] && grep -q 'path = $(WHISPER_DIR)' .gitmodules; then \
			echo "Initializing whisper.cpp submodule..."; \
			git submodule update --init --recursive -- $(WHISPER_DIR); \
		else \
			echo "whisper.cpp is missing. Clone it with:"; \
			echo "  git clone $(WHISPER_GIT_URL) $(WHISPER_DIR)"; \
			false; \
		fi; \
	fi
	@if [ ! -d "$(WHISPER_DIR)" ]; then \
		echo "whisper.cpp directory is missing."; \
		false; \
	fi
	@if [ ! -d "$(WHISPER_DIR)/.git" ] && [ ! -f .gitmodules ]; then \
		echo "whisper.cpp is present but not a submodule. If you want this repo to manage it, add it as a git submodule."; \
	fi

$(APP_ICON): Scripts/generate_app_icon.py
	python3 Scripts/generate_app_icon.py

icon: $(APP_ICON)

export-cert:
	@mkdir -p dist
	security find-certificate -c "$(ROOT_CERT_NAME)" -p ~/Library/Keychains/login.keychain-db > $(APP_EXPORT_CERT)
	@echo "Exported $(APP_EXPORT_CERT)"

bundle: $(APP_ICON) build-release
	@$(MAKE) whisper-prepare
	@if [ ! -f "$(MODEL_SOURCE)" ]; then $(MAKE) model MODEL=$(MODEL); fi
	@test -x $(WHISPER_CLI) || (echo "Missing $(WHISPER_CLI). Build whisper.cpp first with 'make whisper-cli' on a machine with cmake installed." && false)
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	mkdir -p $(APP_FRAMEWORKS)
	cp .build/release/$(APP_NAME) $(APP_EXECUTABLE)
	cp $(INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	cp $(APP_ICON) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp $(WHISPER_CLI) $(APP_BUNDLE)/Contents/MacOS/whisper-cli
	chmod +x $(APP_BUNDLE)/Contents/MacOS/whisper-cli
	for dir in $(WHISPER_LIB_DIRS); do cp -a "$$dir"/libwhisper*.dylib "$$dir"/libggml*.dylib $(APP_FRAMEWORKS)/ 2>/dev/null || true; done
	install_name_tool -delete_rpath "$(WHISPER_DIR)/build/src" $(APP_BUNDLE)/Contents/MacOS/whisper-cli || true
	install_name_tool -delete_rpath "$(WHISPER_DIR)/build/ggml/src" $(APP_BUNDLE)/Contents/MacOS/whisper-cli || true
	install_name_tool -delete_rpath "$(WHISPER_DIR)/build/ggml/src/ggml-blas" $(APP_BUNDLE)/Contents/MacOS/whisper-cli || true
	install_name_tool -delete_rpath "$(WHISPER_DIR)/build/ggml/src/ggml-metal" $(APP_BUNDLE)/Contents/MacOS/whisper-cli || true
	install_name_tool -add_rpath "@executable_path/../Frameworks" $(APP_BUNDLE)/Contents/MacOS/whisper-cli
	sed -e 's|__MODEL_FILE_NAME__|$(MODEL_FILE_NAME)|g' -e 's|__LANGUAGE__|$(LANGUAGE)|g' $(APP_CONFIG_TEMPLATE) > $(APP_CONFIG_OUTPUT)
	cp $(MODEL_SOURCE) $(APP_BUNDLE)/Contents/Resources/$(MODEL_FILE_NAME)
	@if [ -d "Resources/Assets.xcassets" ]; then cp -R Resources/Assets.xcassets $(APP_BUNDLE)/Contents/Resources/; fi
	$(MAKE) sign APP_BUNDLE="$(APP_BUNDLE)" APP_EXECUTABLE="$(APP_EXECUTABLE)"
	@echo "Bundled $(APP_BUNDLE)"

package-transfer: bundle export-cert
	@rm -rf $(APP_DMG_STAGE) $(APP_EXPORT_DMG)
	@mkdir -p $(APP_DMG_STAGE)
	cp -R $(APP_BUNDLE) $(APP_DMG_STAGE)/
	cp $(APP_EXPORT_CERT) $(APP_DMG_STAGE)/
	ln -s /Applications $(APP_DMG_STAGE)/Applications
	hdiutil create -volname "WhisperOverlay" -srcfolder $(APP_DMG_STAGE) -ov -format UDZO $(APP_EXPORT_DMG)
	@echo "Packaged $(APP_EXPORT_DMG)"

sign:
	$(CODESIGN) --force --sign "$(SIGN_IDENTITY)" "$(APP_EXECUTABLE)"
	@for dylib in $(APP_FRAMEWORKS)/*.dylib; do [ -e "$$dylib" ] || continue; $(CODESIGN) --force --sign "$(SIGN_IDENTITY)" "$$dylib"; done
	$(CODESIGN) --force --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE)/Contents/MacOS/whisper-cli"
	$(CODESIGN) --force --deep --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE)"
	$(CODESIGN) --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"

open: bundle
	open $(APP_BUNDLE)

clean:
	$(SWIFT) package clean
	$(MAKE) -C $(WHISPER_DIR) clean
	rm -rf dist
