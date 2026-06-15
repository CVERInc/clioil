import Foundation

/// All user-facing strings, resolved for one ``Language``.
///
/// Every message is an exhaustive `switch` over `Language`, so the compiler
/// refuses to build until a newly added language is fully translated. Shared by
/// the CLI today and the SwiftUI app later.
public struct L10n: Sendable {
    public let language: Language
    public init(_ language: Language) { self.language = language }

    // MARK: list

    public func projectsHeader(_ count: Int) -> String {
        switch language {
        case .en:     return "Publishable projects (\(count)):"
        case .es:     return "Proyectos publicables (\(count)):"
        case .ja:     return "公開可能なプロジェクト（\(count)）："
        case .zhTW: return "可發布的專案（\(count)）："
        case .ko:     return "배포 가능한 프로젝트 (\(count)):"
        case .fr:     return "Projets publiables (\(count)) :"
        case .de:     return "Veröffentlichbare Projekte (\(count)):"
        }
    }

    public func noProjectsFound() -> String {
        switch language {
        case .en:     return "No publishable projects found. Searched:"
        case .es:     return "No se encontraron proyectos publicables. Se buscó en:"
        case .ja:     return "公開可能なプロジェクトが見つかりませんでした。検索した場所："
        case .zhTW: return "找不到可發布的專案。已掃描的位置："
        case .ko:     return "배포 가능한 프로젝트를 찾지 못했습니다. 검색한 위치:"
        case .fr:     return "Aucun projet publiable trouvé. Emplacements analysés :"
        case .de:     return "Keine veröffentlichbaren Projekte gefunden. Durchsucht:"
        }
    }

    // MARK: errors

    public func unknownCommand(_ command: String) -> String {
        switch language {
        case .en:     return "Unknown command: \(command)"
        case .es:     return "Comando desconocido: \(command)"
        case .ja:     return "不明なコマンド：\(command)"
        case .zhTW: return "未知指令：\(command)"
        case .ko:     return "알 수 없는 명령: \(command)"
        case .fr:     return "Commande inconnue : \(command)"
        case .de:     return "Unbekannter Befehl: \(command)"
        }
    }

    // MARK: help (assembled from localized parts)

    public func help() -> String {
        let codes = Language.allCases.map(\.rawValue).joined(separator: ", ")
        return """
        \(helpTagline)

        \(usageHeader)
          clioil list              \(cmdListDesc)
          clioil status [project]  \(cmdStatusDesc)
          clioil publish [project] \(cmdPublishDesc)
          clioil release [project] \(cmdReleaseDesc())
          clioil prepare [project] \(cmdPrepareDesc())
          clioil help              \(cmdHelpDesc)

        \(languageHeader)
          \(languageNote)
          \(availableLabel) \(codes)
        """
    }

    private var helpTagline: String {
        switch language {
        case .en:     return "clioil — make shipping your code to any registry simple (early skeleton)"
        case .es:     return "clioil — publicar tu código en cualquier registro, fácil (esqueleto inicial)"
        case .ja:     return "clioil — どんなレジストリへの公開も簡単に（初期スケルトン）"
        case .zhTW: return "clioil — 讓把程式碼推到任何平台變簡單（早期骨架）"
        case .ko:     return "clioil — 어떤 레지스트리에든 코드 배포를 간단하게 (초기 골격)"
        case .fr:     return "clioil — publier votre code sur n'importe quel registre, simplement (squelette initial)"
        case .de:     return "clioil — Code in jede Registry zu veröffentlichen, einfach gemacht (frühes Gerüst)"
        }
    }

    private var usageHeader: String {
        switch language {
        case .en:     return "Usage:"
        case .es:     return "Uso:"
        case .ja:     return "使い方："
        case .zhTW: return "用法："
        case .ko:     return "사용법:"
        case .fr:     return "Utilisation :"
        case .de:     return "Verwendung:"
        }
    }

    private var cmdListDesc: String {
        switch language {
        case .en:     return "Scan and list publishable projects"
        case .es:     return "Escanear y listar proyectos publicables"
        case .ja:     return "公開可能なプロジェクトを検索して一覧表示"
        case .zhTW: return "掃描並列出可發布的專案"
        case .ko:     return "배포 가능한 프로젝트를 검색해 나열"
        case .fr:     return "Analyser et lister les projets publiables"
        case .de:     return "Veröffentlichbare Projekte suchen und auflisten"
        }
    }

    private var cmdPublishDesc: String {
        switch language {
        case .en:   return "Publish to npm (guided: install → test → preview → publish)"
        case .es:   return "Publicar en npm (guiado: instalar → probar → vista previa → publicar)"
        case .ja:   return "npm に公開（ガイド付き：インストール→テスト→プレビュー→公開）"
        case .zhTW: return "發布到 npm（引導式：安裝→測試→預覽→發布）"
        case .ko:   return "npm에 배포 (안내: 설치 → 테스트 → 미리보기 → 배포)"
        case .fr:   return "Publier sur npm (guidé : installer → tester → aperçu → publier)"
        case .de:   return "Auf npm veröffentlichen (geführt: Installieren → Testen → Vorschau → Veröffentlichen)"
        }
    }

    private var cmdStatusDesc: String {
        switch language {
        case .en:   return "Show a project's release readiness (read-only)"
        case .es:   return "Mostrar si un proyecto está listo para publicar (solo lectura)"
        case .ja:   return "プロジェクトの公開準備状況を表示（読み取り専用）"
        case .zhTW: return "顯示專案的發布就緒狀態（唯讀）"
        case .ko:   return "프로젝트의 배포 준비 상태 표시 (읽기 전용)"
        case .fr:   return "Afficher l'état de préparation d'un projet (lecture seule)"
        case .de:   return "Veröffentlichungsbereitschaft eines Projekts anzeigen (schreibgeschützt)"
        }
    }

    private var cmdHelpDesc: String {
        switch language {
        case .en:     return "Show this help"
        case .es:     return "Mostrar esta ayuda"
        case .ja:     return "このヘルプを表示"
        case .zhTW: return "顯示這個說明"
        case .ko:     return "이 도움말 표시"
        case .fr:     return "Afficher cette aide"
        case .de:     return "Diese Hilfe anzeigen"
        }
    }

    private var languageHeader: String {
        switch language {
        case .en:     return "Language:"
        case .es:     return "Idioma:"
        case .ja:     return "言語："
        case .zhTW: return "語言："
        case .ko:     return "언어:"
        case .fr:     return "Langue :"
        case .de:     return "Sprache:"
        }
    }

    private var languageNote: String {
        switch language {
        case .en:     return "Auto-detected from your locale. Override with --lang=<code> or CLIOIL_LANG."
        case .es:     return "Detectado según tu configuración regional. Cámbialo con --lang=<código> o CLIOIL_LANG."
        case .ja:     return "ロケールから自動判定します。--lang=<コード> または CLIOIL_LANG で変更できます。"
        case .zhTW: return "依系統語系自動判斷。可用 --lang=<代碼> 或 CLIOIL_LANG 覆寫。"
        case .ko:     return "로캘에서 자동 감지됩니다. --lang=<코드> 또는 CLIOIL_LANG으로 변경하세요."
        case .fr:     return "Détectée selon votre paramètre régional. Modifiable avec --lang=<code> ou CLIOIL_LANG."
        case .de:     return "Wird aus Ihrer Locale erkannt. Mit --lang=<Code> oder CLIOIL_LANG überschreiben."
        }
    }

    private var availableLabel: String {
        switch language {
        case .en:     return "Available:"
        case .es:     return "Disponibles:"
        case .ja:     return "対応言語："
        case .zhTW: return "可用語言："
        case .ko:     return "사용 가능:"
        case .fr:     return "Disponibles :"
        case .de:     return "Verfügbar:"
        }
    }
}
