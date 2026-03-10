.PHONY: build run release install setup clean app-bundle

BINARY_NAME = AutoForti
BUILD_DIR = .build
RELEASE_BINARY = $(BUILD_DIR)/release/$(BINARY_NAME)
APP_BUNDLE = $(BUILD_DIR)/$(BINARY_NAME).app

build:
	swift build

run: build
	.build/debug/$(BINARY_NAME)

release:
	swift build -c release

setup:
	sudo bash Scripts/setup-sudoers.sh

install: release
	cp $(RELEASE_BINARY) /usr/local/bin/$(BINARY_NAME)
	@echo "Installed to /usr/local/bin/$(BINARY_NAME)"

app-bundle: release
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp $(RELEASE_BINARY) "$(APP_BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	@/usr/bin/env python3 -c '\
	import plistlib; \
	pl = { \
	  "CFBundleExecutable": "AutoForti", \
	  "CFBundleIdentifier": "com.auto-forti.app", \
	  "CFBundleName": "AutoForti", \
	  "CFBundleVersion": "1.0.0", \
	  "CFBundleShortVersionString": "1.0.0", \
	  "LSUIElement": True, \
	  "CFBundlePackageType": "APPL", \
	}; \
	import pathlib; \
	pathlib.Path("$(APP_BUNDLE)/Contents/Info.plist").write_bytes(plistlib.dumps(pl))'
	@echo "App bundle created at $(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)
