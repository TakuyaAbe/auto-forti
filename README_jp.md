# AutoForti

macOS メニューバーから FortiVPN にワンクリックで接続/切断できる軽量アプリ。`openfortivpn` CLI をラップし、Swift + AppKit でネイティブ実装。

[English README](README.md)

## インストール

### GitHub Releases から (推奨)

1. [Releases](https://github.com/TakuyaAbe/auto-forti/releases) から `AutoForti.dmg` をダウンロード
2. DMG を開き、AutoForti.app を Applications にドラッグ
3. **初回起動前に検疫属性を解除** (Apple Developer ID 未署名のため):
   ```bash
   sudo xattr -cr /Applications/AutoForti.app
   ```
4. アプリを起動

DMGには `openfortivpn` と OpenSSL がバンドル済みのため、別途インストールは不要です。

### ソースからビルド

```bash
# 必要: macOS 14+, Swift 6.0+, openfortivpn (brew install openfortivpn)
make dmg
open .build/AutoForti.dmg
```

### ビルドに必要な環境

- macOS 14+
- Swift 6.0+
- `openfortivpn` (`brew install openfortivpn`)

## 使い方

1. アプリ起動 → 初回のみ管理者パスワードを入力 (sudoers 設定)
2. 設定ウィンドウでサーバー/ユーザー名/パスワードを入力
3. メニューバーのアイコンから「接続」/「切断」

## 機能

- メニューバーからワンクリック接続/切断
- Keychain に認証情報を安全に保存 (単一エントリ)
- 一時設定ファイル経由でパスワードを渡す (プロセス一覧に非露出)
- サーバー証明書の自動取得・確認ダイアログ
- 既存 openfortivpn プロセスの自動検出
- アプリ終了時のプロセスクリーンアップ
- openfortivpn + OpenSSL をアプリ内にバンドル (brew不要)

## 構成

```
Sources/AutoForti/
├── main.swift                  # NSApplication 起動
├── AppDelegate.swift           # 初期化、sudoers チェック
├── StatusBarController.swift   # メニューバー管理
├── VPNManager.swift            # openfortivpn プロセス管理
├── KeychainManager.swift       # Keychain CRUD (単一 JSON エントリ)
├── ConfigManager.swift         # UserDefaults 設定
├── SetupWindowController.swift # 設定ウィンドウ
├── WelcomeWindowController.swift # 初回起動ウェルカム画面
└── SudoersManager.swift        # sudoers 自動設定
```

## Makefile ターゲット

| ターゲット | 説明 |
|-----------|------|
| `make build` | デバッグビルド |
| `make release` | リリースビルド |
| `make run` | ビルド & 起動 |
| `make dmg` | DMG 作成 (openfortivpn バンドル込み) |
| `make app-bundle` | .app バンドル作成 |
| `make icon` | アプリアイコン生成 |
| `make setup` | sudoers 手動設定 (通常不要) |
| `make clean` | ビルド成果物削除 |

## ライセンス

このプロジェクトは [GNU General Public License v3.0](LICENSE) の下で公開されています。

### バンドルされたソフトウェア

| ソフトウェア | ライセンス | ソースコード |
|-------------|-----------|-------------|
| [openfortivpn](https://github.com/adrienverge/openfortivpn) | GPL-3.0 | https://github.com/adrienverge/openfortivpn |
| [OpenSSL](https://www.openssl.org/) | Apache-2.0 | https://github.com/openssl/openssl |
