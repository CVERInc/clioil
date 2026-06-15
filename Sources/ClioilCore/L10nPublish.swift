import Foundation

/// Localized strings for the `clioil publish` flow. Exhaustive per language.
extension L10n {
    public func publishInstalling() -> String {
        switch language {
        case .en:   return "Installing dependencies…"
        case .es:   return "Instalando dependencias…"
        case .ja:   return "依存関係をインストール中…"
        case .zhTW: return "正在安裝相依套件…"
        case .ko:   return "의존성 설치 중…"
        case .fr:   return "Installation des dépendances…"
        case .de:   return "Abhängigkeiten werden installiert…"
        }
    }

    public func publishTesting() -> String {
        switch language {
        case .en:   return "Running tests…"
        case .es:   return "Ejecutando pruebas…"
        case .ja:   return "テストを実行中…"
        case .zhTW: return "正在跑測試…"
        case .ko:   return "테스트 실행 중…"
        case .fr:   return "Exécution des tests…"
        case .de:   return "Tests werden ausgeführt…"
        }
    }

    public func publishTestPassed() -> String {
        switch language {
        case .en:   return "Tests passed ✅"
        case .es:   return "Pruebas superadas ✅"
        case .ja:   return "テスト成功 ✅"
        case .zhTW: return "測試通過 ✅"
        case .ko:   return "테스트 통과 ✅"
        case .fr:   return "Tests réussis ✅"
        case .de:   return "Tests bestanden ✅"
        }
    }

    public func publishTestFailed() -> String {
        switch language {
        case .en:   return "Tests failed. Publishing anyway is not recommended."
        case .es:   return "Las pruebas fallaron. No se recomienda publicar de todos modos."
        case .ja:   return "テストが失敗しました。このまま公開するのはおすすめしません。"
        case .zhTW: return "測試失敗。不建議照樣發布。"
        case .ko:   return "테스트가 실패했습니다. 그래도 배포하는 것은 권장하지 않습니다."
        case .fr:   return "Les tests ont échoué. Publier quand même n'est pas recommandé."
        case .de:   return "Tests fehlgeschlagen. Trotzdem zu veröffentlichen ist nicht empfohlen."
        }
    }

    public func publishPackPreview() -> String {
        switch language {
        case .en:   return "Files that would be published:"
        case .es:   return "Archivos que se publicarían:"
        case .ja:   return "公開されるファイル："
        case .zhTW: return "會被發布的檔案："
        case .ko:   return "배포될 파일:"
        case .fr:   return "Fichiers qui seraient publiés :"
        case .de:   return "Dateien, die veröffentlicht würden:"
        }
    }

    public func publishBumpedTo(_ ver: String) -> String {
        switch language {
        case .en:   return "Bumped to v\(ver)"
        case .es:   return "Versión subida a v\(ver)"
        case .ja:   return "v\(ver) に上げました"
        case .zhTW: return "已升版到 v\(ver)"
        case .ko:   return "v\(ver)(으)로 올림"
        case .fr:   return "Version portée à v\(ver)"
        case .de:   return "Auf v\(ver) erhöht"
        }
    }

    public func publishConfirm(_ name: String, _ ver: String) -> String {
        switch language {
        case .en:   return "Publish \(name) v\(ver) to npm? A browser will open for passkey auth. [press Enter to confirm, Ctrl+C to cancel]"
        case .es:   return "¿Publicar \(name) v\(ver) en npm? Se abrirá un navegador para la autenticación con passkey. [Enter para confirmar, Ctrl+C para cancelar]"
        case .ja:   return "\(name) v\(ver) を npm に公開しますか？ パスキー認証のためブラウザが開きます。[Enter で確定、Ctrl+C で取消]"
        case .zhTW: return "要把 \(name) v\(ver) 發布到 npm 嗎？ 會開啟瀏覽器做 passkey 驗證。[按 Enter 確認，Ctrl+C 取消]"
        case .ko:   return "\(name) v\(ver)을(를) npm에 배포할까요? 패스키 인증을 위해 브라우저가 열립니다. [Enter로 확인, Ctrl+C로 취소]"
        case .fr:   return "Publier \(name) v\(ver) sur npm ? Un navigateur s'ouvrira pour l'authentification par passkey. [Entrée pour confirmer, Ctrl+C pour annuler]"
        case .de:   return "\(name) v\(ver) auf npm veröffentlichen? Ein Browser öffnet sich zur Passkey-Authentifizierung. [Enter zum Bestätigen, Strg+C zum Abbrechen]"
        }
    }

    public func publishSuccess(_ name: String, _ ver: String) -> String {
        switch language {
        case .en:   return "Published \(name) v\(ver) 🎉"
        case .es:   return "Publicado \(name) v\(ver) 🎉"
        case .ja:   return "\(name) v\(ver) を公開しました 🎉"
        case .zhTW: return "已發布 \(name) v\(ver) 🎉"
        case .ko:   return "\(name) v\(ver) 배포 완료 🎉"
        case .fr:   return "\(name) v\(ver) publié 🎉"
        case .de:   return "\(name) v\(ver) veröffentlicht 🎉"
        }
    }

    public func publishAborted() -> String {
        switch language {
        case .en:   return "Cancelled — nothing was published."
        case .es:   return "Cancelado — no se publicó nada."
        case .ja:   return "キャンセルしました — 何も公開されていません。"
        case .zhTW: return "已取消 —— 沒有發布任何東西。"
        case .ko:   return "취소됨 — 아무것도 배포되지 않았습니다."
        case .fr:   return "Annulé — rien n'a été publié."
        case .de:   return "Abgebrochen — nichts wurde veröffentlicht."
        }
    }

    public func publishCancelled() -> String {
        switch language {
        case .en:   return "Stopped — publish cancelled."
        case .es:   return "Detenido — publicación cancelada."
        case .ja:   return "停止しました — 公開をキャンセルしました。"
        case .zhTW: return "已停止 —— 取消發布。"
        case .ko:   return "중지됨 — 배포를 취소했습니다."
        case .fr:   return "Arrêté — publication annulée."
        case .de:   return "Gestoppt — Veröffentlichung abgebrochen."
        }
    }

    public func menuBarTitle() -> String {
        switch language {
        case .en:   return "Publish"
        case .es:   return "Publicar"
        case .ja:   return "公開"
        case .zhTW: return "發布"
        case .ko:   return "배포"
        case .fr:   return "Publier"
        case .de:   return "Veröffentlichen"
        }
    }

    public func menuBarPickProject() -> String {
        switch language {
        case .en:   return "Pick a project to publish:"
        case .es:   return "Elige un proyecto para publicar:"
        case .ja:   return "公開するプロジェクトを選択："
        case .zhTW: return "選一個要發布的專案："
        case .ko:   return "배포할 프로젝트를 선택하세요:"
        case .fr:   return "Choisissez un projet à publier :"
        case .de:   return "Projekt zum Veröffentlichen wählen:"
        }
    }

    public func stopButton() -> String {
        switch language {
        case .en:   return "Stop"
        case .es:   return "Detener"
        case .ja:   return "停止"
        case .zhTW: return "停止"
        case .ko:   return "중지"
        case .fr:   return "Arrêter"
        case .de:   return "Stoppen"
        }
    }

    public func quitButton() -> String {
        switch language {
        case .en:   return "Quit clioil"
        case .es:   return "Salir de clioil"
        case .ja:   return "clioil を終了"
        case .zhTW: return "結束 clioil"
        case .ko:   return "clioil 종료"
        case .fr:   return "Quitter clioil"
        case .de:   return "clioil beenden"
        }
    }

    public func publishDryRunDone() -> String {
        switch language {
        case .en:   return "Dry run only — nothing was published. Re-run without --dry-run to publish for real."
        case .es:   return "Solo simulación — no se publicó nada. Vuelve a ejecutar sin --dry-run para publicar de verdad."
        case .ja:   return "ドライランのみ — 何も公開されていません。本当に公開するには --dry-run なしで再実行してください。"
        case .zhTW: return "只是試跑 —— 沒有發布任何東西。要真的發布請拿掉 --dry-run 再跑一次。"
        case .ko:   return "드라이런만 실행 — 아무것도 배포되지 않았습니다. 실제로 배포하려면 --dry-run 없이 다시 실행하세요."
        case .fr:   return "Simulation uniquement — rien n'a été publié. Relancez sans --dry-run pour publier réellement."
        case .de:   return "Nur Probelauf — nichts wurde veröffentlicht. Ohne --dry-run erneut ausführen, um wirklich zu veröffentlichen."
        }
    }

    public func copyButton() -> String {
        switch language {
        case .en:   return "Copy"
        case .es:   return "Copiar"
        case .ja:   return "コピー"
        case .zhTW: return "複製"
        case .ko:   return "복사"
        case .fr:   return "Copier"
        case .de:   return "Kopieren"
        }
    }

    public func publishButton() -> String {
        switch language {
        case .en:   return "Publish to npm"
        case .es:   return "Publicar en npm"
        case .ja:   return "npm に公開"
        case .zhTW: return "發布到 npm"
        case .ko:   return "npm에 배포"
        case .fr:   return "Publier sur npm"
        case .de:   return "Auf npm veröffentlichen"
        }
    }

    public func publishAuthInBrowser() -> String {
        switch language {
        case .en:   return "Complete the passkey sign-in in your browser…"
        case .es:   return "Completa el inicio de sesión con passkey en tu navegador…"
        case .ja:   return "ブラウザでパスキー認証を完了してください…"
        case .zhTW: return "請在瀏覽器完成 passkey 驗證…"
        case .ko:   return "브라우저에서 패스키 로그인을 완료하세요…"
        case .fr:   return "Terminez la connexion par passkey dans votre navigateur…"
        case .de:   return "Schließe die Passkey-Anmeldung in deinem Browser ab…"
        }
    }

    public func publishAlreadyBlocked(_ ver: String) -> String {
        switch language {
        case .en:   return "v\(ver) is already on npm — bump first (e.g. `--bump patch`) or it will fail."
        case .es:   return "v\(ver) ya está en npm — sube la versión primero (p. ej. `--bump patch`) o fallará."
        case .ja:   return "v\(ver) はすでに npm にあります — 先にバージョンを上げてください（例：`--bump patch`）。そうしないと失敗します。"
        case .zhTW: return "v\(ver) 已經在 npm 上了 —— 請先升版（例如 `--bump patch`），否則會失敗。"
        case .ko:   return "v\(ver)은(는) 이미 npm에 있습니다 — 먼저 버전을 올리세요(예: `--bump patch`). 그렇지 않으면 실패합니다."
        case .fr:   return "v\(ver) est déjà sur npm — incrémentez d'abord (par ex. `--bump patch`) sinon ça échouera."
        case .de:   return "v\(ver) ist bereits auf npm — erhöhe zuerst die Version (z. B. `--bump patch`), sonst schlägt es fehl."
        }
    }
}
