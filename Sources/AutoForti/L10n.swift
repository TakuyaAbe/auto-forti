import Foundation

enum L10n {
    private static let isJapanese: Bool = {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }()

    private static func localized(_ en: String, _ ja: String) -> String {
        isJapanese ? ja : en
    }

    // MARK: - VPN States

    static let disconnected = localized("Disconnected", "未接続")
    static let connecting = localized("Connecting...", "接続中...")
    static let connected = localized("Connected", "接続済み")
    static let disconnecting = localized("Disconnecting...", "切断中...")
    static func error(_ msg: String) -> String {
        localized("Error: \(msg)", "エラー: \(msg)")
    }

    // MARK: - VPN Errors

    static let credentialsNotSet = localized(
        "Credentials not configured", "認証情報が未設定です")
    static func configFileError(_ desc: String) -> String {
        localized("Config file creation failed: \(desc)", "設定ファイル作成失敗: \(desc)")
    }
    static func connectionFailed(_ status: Int32) -> String {
        localized("Connection failed (exit \(status))", "接続に失敗しました (exit \(status))")
    }
    static func processStartFailed(_ desc: String) -> String {
        localized("Process start failed: \(desc)", "プロセス起動失敗: \(desc)")
    }
    static let authFailed = localized(
        "Authentication failed", "認証に失敗しました")

    // MARK: - Certificate Dialog

    static let certDialogTitle = localized(
        "Server Certificate Verification", "サーバー証明書の確認")
    static func certDialogMessage(_ hash: String) -> String {
        localized(
            "Server certificate hash:\n\(hash)\n\nDo you trust this certificate?",
            "サーバーの証明書ハッシュ:\n\(hash)\n\nこの証明書を信頼しますか？")
    }
    static let trust = localized("Trust", "信頼する")
    static let cancel = localized("Cancel", "キャンセル")

    // MARK: - Menu Bar

    static let connect = localized("Connect", "接続")
    static let disconnect = localized("Disconnect", "切断")
    static let settings = localized("Settings...", "設定...")
    static let quit = localized("Quit", "終了")

    // MARK: - Setup Window

    static let setupTitle = localized("AutoForti Settings", "AutoForti 設定")
    static let server = localized("Server:", "サーバー:")
    static let port = localized("Port:", "ポート:")
    static let username = localized("Username:", "ユーザー名:")
    static let password = localized("Password:", "パスワード:")
    static let trustedCertPlaceholder = localized(
        "Auto-detected (optional)", "自動取得されます（空欄可）")
    static let autoConnectOnLaunch = localized(
        "Auto-connect on launch", "起動時に自動接続")
    static let save = localized("Save", "保存")
    static let inputError = localized("Input Error", "入力エラー")
    static let fieldsRequired = localized(
        "Server, username, and password are required.",
        "サーバー、ユーザー名、パスワードは必須です。")

    // MARK: - Admin Setup Dialog

    static let initialSetupTitle = localized(
        "Initial Setup", "初期設定")
    static let initialSetupMessage = localized(
        "System privileges are required for VPN connection.\nYou will be prompted for your admin password.",
        "VPN接続にはシステム権限の設定が必要です。\n管理者パスワードの入力を求められます。")
    static let configure = localized("Configure", "設定する")
    static let setupFailedTitle = localized(
        "Setup Failed", "設定に失敗しました")
    static let setupFailedMessage = localized(
        "Failed to configure admin privileges.\nThe app will quit.",
        "管理者権限の設定ができませんでした。\nアプリを終了します。")

    // MARK: - Welcome Window

    static let welcomeTitle = localized(
        "Welcome to AutoForti", "AutoForti へようこそ")
    static let welcomeDescription = localized(
        "One-click FortiVPN connection from your menu bar.",
        "FortiVPN にメニューバーからワンクリックで接続できるアプリです。")
    static let features = localized("Features:", "機能:")
    static let featureConnect = localized(
        "Connect/disconnect VPN from the menu bar",
        "メニューバーからVPN接続/切断")
    static let featureAutoConnect = localized(
        "Auto-connect on launch",
        "起動時の自動接続")
    static let featureKeychain = localized(
        "Secure credential storage with Keychain",
        "Keychainによる安全な認証情報管理")
    static let welcomeNext = localized(
        "Let's configure the required settings.",
        "まず、VPN接続に必要な設定を行います。")
    static let getStarted = localized("Get Started", "設定を始める")
}
