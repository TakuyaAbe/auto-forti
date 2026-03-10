# AutoForti - Project Guide

## Build & Run

```bash
swift build              # debug build
swift build -c release   # release build
make dmg                 # build DMG for distribution
make run                 # build and run (debug)
```

## Architecture

- **Language**: Swift 6.0, AppKit (no SwiftUI, no Xcode)
- **Build**: SPM (`Package.swift`), macOS 14+
- **VPN Backend**: `openfortivpn` CLI at `/opt/homebrew/bin/openfortivpn`
- **UI**: Programmatic AppKit (NSStatusItem, NSWindow, NSMenu)
- **App Type**: Menu bar only (`LSUIElement`, `.accessory` activation policy)

## Key Design Decisions

- **Keychain**: All credentials stored as single JSON entry (`VPNCredentials` struct) under `com.auto-forti.vpn` to minimize access prompts
- **Password handling**: Temporary config file (`-c`) passed to openfortivpn, deleted on process exit. No password in process args
- **sudo**: sudoers configured on first launch via `osascript` (macOS admin dialog), cached in UserDefaults
- **Process management**: `Process` + `Pipe` with async `readabilityHandler`. State machine: disconnected → connecting → connected → disconnecting
- **Main menu**: Edit menu manually added for Cmd+C/V/X/A support (required for `.accessory` policy apps)

## File Overview

| File | Role |
|------|------|
| `main.swift` | NSApplication entry point |
| `AppDelegate.swift` | Init, sudoers check, wiring |
| `StatusBarController.swift` | NSStatusItem + menu |
| `VPNManager.swift` | openfortivpn process lifecycle |
| `KeychainManager.swift` | Security framework, single JSON entry |
| `ConfigManager.swift` | UserDefaults (port, autoConnect) |
| `SetupWindowController.swift` | Settings window (NSWindow + NSTextField) |
| `SudoersManager.swift` | Auto sudoers via osascript |
