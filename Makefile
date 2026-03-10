.PHONY: build run release install setup clean app-bundle dmg icon

BINARY_NAME = AutoForti
BUILD_DIR = .build
RELEASE_BINARY = $(BUILD_DIR)/release/$(BINARY_NAME)
APP_BUNDLE = $(BUILD_DIR)/$(BINARY_NAME).app
ICNS = $(BUILD_DIR)/$(BINARY_NAME).icns
DMG_NAME = $(BINARY_NAME).dmg
DMG_PATH = $(BUILD_DIR)/$(DMG_NAME)
DMG_STAGING = $(BUILD_DIR)/dmg-staging

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

icon:
	@swift Scripts/generate-icon.swift

app-bundle: release icon
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp $(RELEASE_BINARY) "$(APP_BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	@cp $(ICNS) "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
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
	  "CFBundleIconFile": "AppIcon", \
	}; \
	import pathlib; \
	pathlib.Path("$(APP_BUNDLE)/Contents/Info.plist").write_bytes(plistlib.dumps(pl))'
	@echo "App bundle created at $(APP_BUNDLE)"

dmg: app-bundle
	@rm -rf "$(DMG_STAGING)" "$(DMG_PATH)"
	@mkdir -p "$(DMG_STAGING)"
	@cp -R "$(APP_BUNDLE)" "$(DMG_STAGING)/"
	@ln -s /Applications "$(DMG_STAGING)/Applications"
	@hdiutil create -volname "$(BINARY_NAME)" \
		-srcfolder "$(DMG_STAGING)" \
		-ov -format UDZO \
		"$(DMG_PATH)"
	@rm -rf "$(DMG_STAGING)"
	@echo "DMG created at $(DMG_PATH)"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)
