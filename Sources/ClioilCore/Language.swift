import Foundation

/// Languages clioil speaks. Adding a case forces every message in ``L10n`` to
/// be translated (the switches there are exhaustive) — so the UI can never ship
/// half-localized.
public enum Language: String, CaseIterable, Sendable {
    case en
    case es
    case ja
    case zhHant = "zh-Hant"   // 台灣華語 / Traditional Chinese
    case ko
    case fr
    case de

    /// The language's own name, for menus and `--help`.
    public var endonym: String {
        switch self {
        case .en:     return "English"
        case .es:     return "Español"
        case .ja:     return "日本語"
        case .zhHant: return "繁體中文"
        case .ko:     return "한국어"
        case .fr:     return "Français"
        case .de:     return "Deutsch"
        }
    }

    /// Parse a BCP-47 / POSIX-ish tag ("zh-Hant-TW", "zh_TW.UTF-8", "es_ES",
    /// "ja", "en_US.UTF-8"). Returns nil if we don't (yet) speak it.
    ///
    /// Any Chinese tag maps to Traditional (台灣華語) — the only Chinese clioil
    /// ships, by design.
    public static func parse(_ raw: String) -> Language? {
        let s = raw.replacingOccurrences(of: "_", with: "-").lowercased()
        if s.hasPrefix("zh") { return .zhHant }
        if s.hasPrefix("es") { return .es }
        if s.hasPrefix("ja") { return .ja }
        if s.hasPrefix("ko") { return .ko }
        if s.hasPrefix("fr") { return .fr }
        if s.hasPrefix("de") { return .de }
        if s.hasPrefix("en") { return .en }
        return nil
    }

    /// Resolve the active language. Priority: explicit override → CLIOIL_LANG →
    /// the usual POSIX locale vars → the system locale → English.
    public static func detect(
        override: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        localeIdentifier: String = Locale.current.identifier
    ) -> Language {
        let candidates: [String?] = [
            override,
            environment["CLIOIL_LANG"],
            environment["LC_ALL"],
            environment["LC_MESSAGES"],
            environment["LANG"],
            localeIdentifier,
        ]
        for case let raw? in candidates {
            if let lang = parse(raw) { return lang }
        }
        return .en
    }
}
