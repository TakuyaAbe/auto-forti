# AutoForti

macOS メニューバーから FortiVPN にワンクリックで接続/切断できる軽量アプリ。`openfortivpn` CLI をラップし、Swift + AppKit でネイティブ実装。

## 必要環境

- macOS 14+
- `openfortivpn` (`brew install openfortivpn`)
- Swift 6.0+ (ビルドする場合)

## インストール

### DMG から (推奨)

```bash
make dmg
open .build/AutoForti.dmg
# AutoForti.app を Applications にドラッグ
```

### 直接ビルド

```bash
make release
.build/release/AutoForti
```

## 使い方

1. アプリ起動 → 初回のみ管理者パスワードを入力 (sudoers 設定)
2. 設定ウィンドウでサーバー/ユーザー名/パスワードを入力
3. メニューバーのアイコンから「接続」/「切断」

## 機能

- メニューバーからワンクリック接続/切断
- SF Symbols アイコン (`lock.shield` / `lock.shield.fill`)
- Keychain に認証情報を安全に保存 (単一エントリ)
- 一時設定ファイル経由でパスワードを渡す (プロセス一覧に非露出)
- サーバー証明書の自動取得・確認ダイアログ
- 既存 openfortivpn プロセスの自動検出
- アプリ終了時のプロセスクリーンアップ

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
└── SudoersManager.swift        # sudoers 自動設定
```

## Makefile ターゲット

| ターゲット | 説明 |
|-----------|------|
| `make build` | デバッグビルド |
| `make release` | リリースビルド |
| `make run` | ビルド & 起動 |
| `make dmg` | DMG 作成 |
| `make app-bundle` | .app バンドル作成 |
| `make setup` | sudoers 手動設定 (通常不要) |
| `make clean` | ビルド成果物削除 |
