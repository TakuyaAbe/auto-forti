# AutoForti

A lightweight macOS menu bar app for one-click FortiVPN connect/disconnect. Wraps the `openfortivpn` CLI with a native Swift + AppKit interface.

[日本語版 README](README_jp.md)

## Install

### From GitHub Releases (recommended)

1. Download `AutoForti.dmg` from [Releases](https://github.com/TakuyaAbe/auto-forti/releases)
2. Open the DMG and drag AutoForti.app to Applications
3. **Remove quarantine attribute before first launch** (app is not signed with Apple Developer ID):
   ```bash
   sudo xattr -cr /Applications/AutoForti.app
   ```
4. Launch the app

The DMG bundles `openfortivpn` and OpenSSL — no additional installation required.

### Build from Source

```bash
# Requires: macOS 14+, Swift 6.0+, openfortivpn (brew install openfortivpn)
make dmg
open .build/AutoForti.dmg
```

### Build Requirements

- macOS 14+
- Swift 6.0+
- `openfortivpn` (`brew install openfortivpn`)

## Usage

1. Launch the app — enter your admin password on first run (sudoers setup)
2. Enter your server, username, and password in the settings window
3. Connect/disconnect from the menu bar icon

## Features

- One-click connect/disconnect from the menu bar
- Credentials stored securely in macOS Keychain
- Password passed via temporary config file (never exposed in process list)
- Auto-detection and trust dialog for server certificates
- Automatic detection of existing openfortivpn processes
- Process cleanup on app exit
- openfortivpn + OpenSSL bundled in the app (no Homebrew needed)

## Project Structure

```
Sources/AutoForti/
├── main.swift                  # NSApplication entry point
├── AppDelegate.swift           # Initialization, sudoers check
├── StatusBarController.swift   # Menu bar management
├── VPNManager.swift            # openfortivpn process management
├── KeychainManager.swift       # Keychain CRUD (single JSON entry)
├── ConfigManager.swift         # UserDefaults settings
├── SetupWindowController.swift # Settings window
├── WelcomeWindowController.swift # First-launch welcome screen
└── SudoersManager.swift        # Automatic sudoers setup
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Debug build |
| `make release` | Release build |
| `make run` | Build & run |
| `make dmg` | Create DMG (with bundled openfortivpn) |
| `make app-bundle` | Create .app bundle |
| `make icon` | Generate app icon |
| `make setup` | Manual sudoers setup (usually not needed) |
| `make clean` | Remove build artifacts |

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

### Bundled Software

| Software | License | Source Code |
|----------|---------|-------------|
| [openfortivpn](https://github.com/adrienverge/openfortivpn) | GPL-3.0 | https://github.com/adrienverge/openfortivpn |
| [OpenSSL](https://www.openssl.org/) | Apache-2.0 | https://github.com/openssl/openssl |
