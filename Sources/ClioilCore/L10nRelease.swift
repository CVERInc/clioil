import Foundation

/// Localized strings for `clioil release` — preparing (not executing) a GitHub
/// Release + Homebrew formula bump. Exhaustive per language (compiler-enforced).
extension L10n {
    public func releaseNoSlug() -> String {
        switch language {
        case .en:   return "Couldn't determine the GitHub repo. Pass --slug owner/repo."
        case .es:   return "No se pudo determinar el repo de GitHub. Usa --slug owner/repo."
        case .ja:   return "GitHub リポジトリを特定できませんでした。--slug owner/repo を指定してください。"
        case .zhTW: return "找不到 GitHub 倉庫。請用 --slug owner/repo 指定。"
        case .ko:   return "GitHub 저장소를 확인할 수 없습니다. --slug owner/repo를 지정하세요."
        case .fr:   return "Impossible de déterminer le dépôt GitHub. Utilisez --slug owner/repo."
        case .de:   return "GitHub-Repository konnte nicht ermittelt werden. Mit --slug owner/repo angeben."
        }
    }

    public func releaseTarball() -> String {
        switch language {
        case .en:   return "Source tarball"
        case .es:   return "Tarball de origen"
        case .ja:   return "ソース tarball"
        case .zhTW: return "原始碼 tarball"
        case .ko:   return "소스 tarball"
        case .fr:   return "Archive source"
        case .de:   return "Quell-Tarball"
        }
    }

    public func releaseShaUnknown() -> String {
        switch language {
        case .en:   return "(unavailable — fill in after the release is published)"
        case .es:   return "(no disponible — complétalo tras publicar la versión)"
        case .ja:   return "（取得不可 — リリース公開後に記入してください）"
        case .zhTW: return "（取不到 —— 等 release 發布後再填）"
        case .ko:   return "(사용 불가 — 릴리스 게시 후 입력하세요)"
        case .fr:   return "(indisponible — à compléter après la publication)"
        case .de:   return "(nicht verfügbar — nach der Veröffentlichung eintragen)"
        }
    }

    public func releaseShaPreviewNote() -> String {
        switch language {
        case .en:   return "↑ local preview hash. Verify against the real release tarball before publishing the tap."
        case .es:   return "↑ hash de vista previa local. Verifícalo con el tarball real antes de publicar el tap."
        case .ja:   return "↑ ローカルのプレビュー値です。tap を公開する前に実際の tarball で検証してください。"
        case .zhTW: return "↑ 這是本機預覽用的雜湊。發布 tap 前請拿真正的 release tarball 核對。"
        case .ko:   return "↑ 로컬 미리보기 해시입니다. tap을 게시하기 전에 실제 tarball로 검증하세요."
        case .fr:   return "↑ empreinte de prévisualisation locale. Vérifiez-la avec l'archive réelle avant de publier le tap."
        case .de:   return "↑ lokaler Vorschau-Hash. Vor der Tap-Veröffentlichung mit dem echten Tarball prüfen."
        }
    }

    public func releaseFormulaHeader() -> String {
        switch language {
        case .en:   return "Homebrew formula (preview)"
        case .es:   return "Fórmula de Homebrew (vista previa)"
        case .ja:   return "Homebrew formula（プレビュー）"
        case .zhTW: return "Homebrew formula（預覽）"
        case .ko:   return "Homebrew formula (미리보기)"
        case .fr:   return "Formule Homebrew (aperçu)"
        case .de:   return "Homebrew-Formula (Vorschau)"
        }
    }

    public func releaseCommandsHeader() -> String {
        switch language {
        case .en:   return "Run these yourself to publish (clioil will NOT run them)"
        case .es:   return "Ejecuta esto tú para publicar (clioil NO lo hará)"
        case .ja:   return "公開はこれらを自分で実行してください（clioil は実行しません）"
        case .zhTW: return "要發布請自己跑這些指令（clioil 不會幫你執行）"
        case .ko:   return "배포하려면 직접 실행하세요 (clioil은 실행하지 않습니다)"
        case .fr:   return "Exécutez ceci vous-même pour publier (clioil ne le fera PAS)"
        case .de:   return "Zum Veröffentlichen selbst ausführen (clioil führt sie NICHT aus)"
        }
    }

    public func releasePrepareOnly() -> String {
        switch language {
        case .en:   return "Prepared only — no tag, release, or push was made. Publishing stays your call."
        case .es:   return "Solo preparado — no se creó etiqueta, versión ni push. Publicar es decisión tuya."
        case .ja:   return "準備のみ — タグ・リリース・push は行っていません。公開はあなたの判断です。"
        case .zhTW: return "只做了準備 —— 沒有建立 tag、release，也沒有 push。要不要發布由你決定。"
        case .ko:   return "준비만 완료 — 태그·릴리스·푸시는 하지 않았습니다. 배포는 직접 결정하세요."
        case .fr:   return "Préparé seulement — aucun tag, release ni push. La publication reste votre décision."
        case .de:   return "Nur vorbereitet — kein Tag, Release oder Push. Die Veröffentlichung bleibt deine Entscheidung."
        }
    }

    public func releaseFormulaWritten(_ path: String) -> String {
        switch language {
        case .en:   return "Formula written to \(path)"
        case .es:   return "Fórmula escrita en \(path)"
        case .ja:   return "formula を \(path) に書き出しました"
        case .zhTW: return "已把 formula 寫到 \(path)"
        case .ko:   return "formula를 \(path)에 저장했습니다"
        case .fr:   return "Formule écrite dans \(path)"
        case .de:   return "Formula nach \(path) geschrieben"
        }
    }

    public func cmdReleaseDesc() -> String {
        switch language {
        case .en:   return "Prepare a GitHub Release + Homebrew formula (preview only)"
        case .es:   return "Preparar un GitHub Release + fórmula de Homebrew (solo vista previa)"
        case .ja:   return "GitHub Release と Homebrew formula を準備（プレビューのみ）"
        case .zhTW: return "準備 GitHub Release 與 Homebrew formula（只預覽）"
        case .ko:   return "GitHub Release + Homebrew formula 준비 (미리보기만)"
        case .fr:   return "Préparer une GitHub Release + formule Homebrew (aperçu seulement)"
        case .de:   return "GitHub Release + Homebrew-Formula vorbereiten (nur Vorschau)"
        }
    }
}
