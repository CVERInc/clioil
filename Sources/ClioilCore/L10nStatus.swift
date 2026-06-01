import Foundation

/// Localized strings for `clioil status`. Kept in its own file so the headline
/// `L10n` stays readable; still exhaustive per language (compiler-enforced).
extension L10n {
    public func statusLocalVersion() -> String {
        switch language {
        case .en:   return "Local version"
        case .es:   return "Versión local"
        case .ja:   return "ローカルのバージョン"
        case .zhTW: return "本機版本"
        case .ko:   return "로컬 버전"
        case .fr:   return "Version locale"
        case .de:   return "Lokale Version"
        }
    }

    public func statusOnNpm() -> String {
        switch language {
        case .en:   return "On npm"
        case .es:   return "En npm"
        case .ja:   return "npm 上"
        case .zhTW: return "npm 上"
        case .ko:   return "npm"
        case .fr:   return "Sur npm"
        case .de:   return "Auf npm"
        }
    }

    public func statusUnpublished() -> String {
        switch language {
        case .en:   return "not published yet"
        case .es:   return "aún no publicado"
        case .ja:   return "未公開"
        case .zhTW: return "尚未發布"
        case .ko:   return "아직 배포되지 않음"
        case .fr:   return "pas encore publié"
        case .de:   return "noch nicht veröffentlicht"
        }
    }

    public func statusReadyToPublish(_ ver: String) -> String {
        switch language {
        case .en:   return "v\(ver) is new — ready to publish ✅"
        case .es:   return "v\(ver) es nueva — lista para publicar ✅"
        case .ja:   return "v\(ver) は新規 — 公開できます ✅"
        case .zhTW: return "v\(ver) 是新版本 —— 可以發布 ✅"
        case .ko:   return "v\(ver)은(는) 새 버전 — 배포 준비 완료 ✅"
        case .fr:   return "v\(ver) est nouvelle — prête à publier ✅"
        case .de:   return "v\(ver) ist neu — bereit zum Veröffentlichen ✅"
        }
    }

    public func statusAlreadyPublished(_ ver: String) -> String {
        switch language {
        case .en:   return "v\(ver) is already on npm — bump the version before publishing ⚠"
        case .es:   return "v\(ver) ya está en npm — sube la versión antes de publicar ⚠"
        case .ja:   return "v\(ver) はすでに npm にあります — 公開前にバージョンを上げてください ⚠"
        case .zhTW: return "v\(ver) 已經在 npm 上 —— 發布前請先升版 ⚠"
        case .ko:   return "v\(ver)은(는) 이미 npm에 있음 — 배포 전에 버전을 올리세요 ⚠"
        case .fr:   return "v\(ver) est déjà sur npm — incrémentez la version avant de publier ⚠"
        case .de:   return "v\(ver) ist bereits auf npm — erhöhe die Version vor dem Veröffentlichen ⚠"
        }
    }

    public func statusGitDirty() -> String {
        switch language {
        case .en:   return "Uncommitted changes — a publish would ship what's on disk right now"
        case .es:   return "Cambios sin confirmar — al publicar se enviaría lo que hay ahora en disco"
        case .ja:   return "コミットされていない変更があります — 公開すると現在ディスク上の内容が送信されます"
        case .zhTW: return "有未 commit 的變動 —— 發布會送出目前磁碟上的內容"
        case .ko:   return "커밋되지 않은 변경 사항 — 배포하면 지금 디스크의 내용이 전송됩니다"
        case .fr:   return "Modifications non validées — publier enverrait ce qui est sur le disque maintenant"
        case .de:   return "Nicht committete Änderungen — beim Veröffentlichen würde der aktuelle Stand gesendet"
        }
    }

    public func statusGitClean() -> String {
        switch language {
        case .en:   return "Working tree clean"
        case .es:   return "Árbol de trabajo limpio"
        case .ja:   return "作業ツリーはクリーンです"
        case .zhTW: return "工作目錄乾淨"
        case .ko:   return "작업 트리 깨끗함"
        case .fr:   return "Arbre de travail propre"
        case .de:   return "Arbeitsverzeichnis sauber"
        }
    }

    public func statusNotGitRepo() -> String {
        switch language {
        case .en:   return "Not a git repository"
        case .es:   return "No es un repositorio git"
        case .ja:   return "git リポジトリではありません"
        case .zhTW: return "不是 git 儲存庫"
        case .ko:   return "git 저장소가 아님"
        case .fr:   return "Pas un dépôt git"
        case .de:   return "Kein git-Repository"
        }
    }

    public func statusChangesSince(_ tag: String, _ count: Int) -> String {
        switch language {
        case .en:   return "\(count) change(s) since \(tag):"
        case .es:   return "\(count) cambio(s) desde \(tag):"
        case .ja:   return "\(tag) 以降の変更が \(count) 件："
        case .zhTW: return "自 \(tag) 以來有 \(count) 筆變更："
        case .ko:   return "\(tag) 이후 변경 \(count)건:"
        case .fr:   return "\(count) changement(s) depuis \(tag) :"
        case .de:   return "\(count) Änderung(en) seit \(tag):"
        }
    }

    public func statusNoChangesSince(_ tag: String) -> String {
        switch language {
        case .en:   return "No new commits since \(tag)"
        case .es:   return "Sin commits nuevos desde \(tag)"
        case .ja:   return "\(tag) 以降の新しいコミットはありません"
        case .zhTW: return "自 \(tag) 以來沒有新的 commit"
        case .ko:   return "\(tag) 이후 새 커밋 없음"
        case .fr:   return "Aucun nouveau commit depuis \(tag)"
        case .de:   return "Keine neuen Commits seit \(tag)"
        }
    }

    public func statusNoTag() -> String {
        switch language {
        case .en:   return "No version tag yet — nothing to compare against"
        case .es:   return "Aún no hay etiqueta de versión — nada con que comparar"
        case .ja:   return "バージョンタグがまだありません — 比較対象がありません"
        case .zhTW: return "還沒有版本 tag —— 無法跟上次發布比較"
        case .ko:   return "아직 버전 태그 없음 — 비교할 대상이 없음"
        case .fr:   return "Pas encore d'étiquette de version — rien à comparer"
        case .de:   return "Noch kein Versions-Tag — nichts zum Vergleichen"
        }
    }
}
