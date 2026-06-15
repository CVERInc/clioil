import Foundation

/// Localized strings for `clioil prepare` — preparing (not executing) a PyPI or
/// crates.io publish. Exhaustive per language (compiler-enforced).
extension L10n {
    public func cmdPrepareDesc() -> String {
        switch language {
        case .en:   return "Prepare a PyPI / crates.io publish (preview + safe dry-run; never uploads)"
        case .es:   return "Preparar una publicación en PyPI / crates.io (vista previa + dry-run; nunca sube)"
        case .ja:   return "PyPI / crates.io への公開を準備（プレビュー＋安全な dry-run、アップロードはしません）"
        case .zhTW: return "準備發布到 PyPI / crates.io（預覽＋安全 dry-run；絕不上傳）"
        case .ko:   return "PyPI / crates.io 배포 준비 (미리보기 + 안전한 dry-run, 업로드 안 함)"
        case .fr:   return "Préparer une publication PyPI / crates.io (aperçu + dry-run sûr ; n'upload jamais)"
        case .de:   return "PyPI-/crates.io-Veröffentlichung vorbereiten (Vorschau + sicherer Dry-Run; lädt nie hoch)"
        }
    }

    public func prepareUnsupported(_ ecosystem: String) -> String {
        switch language {
        case .en:   return "`clioil prepare` covers PyPI and crates.io. This project is \(ecosystem) — use `clioil publish` (npm) or `clioil release` (Homebrew)."
        case .es:   return "`clioil prepare` cubre PyPI y crates.io. Este proyecto es \(ecosystem) — usa `clioil publish` (npm) o `clioil release` (Homebrew)."
        case .ja:   return "`clioil prepare` は PyPI と crates.io 用です。このプロジェクトは \(ecosystem) です — `clioil publish`（npm）か `clioil release`（Homebrew）を使ってください。"
        case .zhTW: return "`clioil prepare` 處理 PyPI 與 crates.io。這個專案是 \(ecosystem) —— 請改用 `clioil publish`（npm）或 `clioil release`（Homebrew）。"
        case .ko:   return "`clioil prepare`는 PyPI와 crates.io를 지원합니다. 이 프로젝트는 \(ecosystem)입니다 — `clioil publish`(npm) 또는 `clioil release`(Homebrew)를 사용하세요."
        case .fr:   return "`clioil prepare` couvre PyPI et crates.io. Ce projet est \(ecosystem) — utilisez `clioil publish` (npm) ou `clioil release` (Homebrew)."
        case .de:   return "`clioil prepare` deckt PyPI und crates.io ab. Dieses Projekt ist \(ecosystem) — nutze `clioil publish` (npm) oder `clioil release` (Homebrew)."
        }
    }

    public func prepareDryRunHeader() -> String {
        switch language {
        case .en:   return "Safe dry-run"
        case .es:   return "Dry-run seguro"
        case .ja:   return "安全な dry-run"
        case .zhTW: return "安全 dry-run"
        case .ko:   return "안전한 dry-run"
        case .fr:   return "Dry-run sûr"
        case .de:   return "Sicherer Dry-Run"
        }
    }

    public func prepareRunningDryRun() -> String {
        switch language {
        case .en:   return "Running the dry-run (no upload)…"
        case .es:   return "Ejecutando el dry-run (sin subir)…"
        case .ja:   return "dry-run を実行中（アップロードなし）…"
        case .zhTW: return "正在跑 dry-run（不會上傳）…"
        case .ko:   return "dry-run 실행 중 (업로드 없음)…"
        case .fr:   return "Exécution du dry-run (sans upload)…"
        case .de:   return "Dry-Run läuft (kein Upload)…"
        }
    }

    public func prepareDryRunOk() -> String {
        switch language {
        case .en:   return "✓ dry-run passed"
        case .es:   return "✓ dry-run correcto"
        case .ja:   return "✓ dry-run 成功"
        case .zhTW: return "✓ dry-run 通過"
        case .ko:   return "✓ dry-run 통과"
        case .fr:   return "✓ dry-run réussi"
        case .de:   return "✓ Dry-Run bestanden"
        }
    }

    public func prepareDryRunFailed() -> String {
        switch language {
        case .en:   return "✗ dry-run failed — fix the issues above before publishing"
        case .es:   return "✗ dry-run falló — corrige los problemas anteriores antes de publicar"
        case .ja:   return "✗ dry-run 失敗 — 公開前に上記の問題を修正してください"
        case .zhTW: return "✗ dry-run 失敗 —— 發布前請先修掉上面的問題"
        case .ko:   return "✗ dry-run 실패 — 배포 전에 위 문제를 해결하세요"
        case .fr:   return "✗ dry-run échoué — corrigez les problèmes ci-dessus avant de publier"
        case .de:   return "✗ Dry-Run fehlgeschlagen — behebe die obigen Probleme vor der Veröffentlichung"
        }
    }
}
