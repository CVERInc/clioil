import Foundation

/// Localized friendly-error text for ``ErrorAdvisor``. Nested switches
/// (kind → language) keep every (kind, language) pair compiler-enforced.
extension L10n {
    public func adviceTitle(_ kind: PublishErrorKind) -> String {
        switch kind {
        case .versionExists:
            switch language {
            case .en:   return "This version is already on npm."
            case .es:   return "Esta versión ya está en npm."
            case .ja:   return "このバージョンはすでに npm にあります。"
            case .zhTW: return "這個版本已經在 npm 上了。"
            case .ko:   return "이 버전은 이미 npm에 있습니다."
            case .fr:   return "Cette version est déjà sur npm."
            case .de:   return "Diese Version ist bereits auf npm."
            }
        case .notLoggedIn:
            switch language {
            case .en:   return "You're not logged in to npm."
            case .es:   return "No has iniciado sesión en npm."
            case .ja:   return "npm にログインしていません。"
            case .zhTW: return "你還沒有登入 npm。"
            case .ko:   return "npm에 로그인되어 있지 않습니다."
            case .fr:   return "Vous n'êtes pas connecté à npm."
            case .de:   return "Du bist nicht bei npm angemeldet."
            }
        case .forbidden:
            switch language {
            case .en:   return "npm refused the publish (permission denied)."
            case .es:   return "npm rechazó la publicación (permiso denegado)."
            case .ja:   return "npm が公開を拒否しました（権限がありません）。"
            case .zhTW: return "npm 拒絕了這次發布（沒有權限）。"
            case .ko:   return "npm이 배포를 거부했습니다 (권한 없음)."
            case .fr:   return "npm a refusé la publication (permission refusée)."
            case .de:   return "npm hat die Veröffentlichung abgelehnt (keine Berechtigung)."
            }
        case .network:
            switch language {
            case .en:   return "Couldn't reach the npm registry."
            case .es:   return "No se pudo conectar con el registro de npm."
            case .ja:   return "npm レジストリに接続できませんでした。"
            case .zhTW: return "無法連線到 npm registry。"
            case .ko:   return "npm 레지스트리에 연결할 수 없습니다."
            case .fr:   return "Impossible de joindre le registre npm."
            case .de:   return "Die npm-Registry war nicht erreichbar."
            }
        case .unknown:
            switch language {
            case .en:   return "The publish failed."
            case .es:   return "La publicación falló."
            case .ja:   return "公開に失敗しました。"
            case .zhTW: return "發布失敗。"
            case .ko:   return "배포에 실패했습니다."
            case .fr:   return "La publication a échoué."
            case .de:   return "Die Veröffentlichung ist fehlgeschlagen."
            }
        }
    }

    public func adviceSteps(_ kind: PublishErrorKind) -> [String] {
        switch kind {
        case .versionExists:
            switch language {
            case .en:   return ["Bump the version (patch / minor / major), then publish again.",
                                "Each version number can only be published once."]
            case .es:   return ["Sube la versión (patch / minor / major) y vuelve a publicar.",
                                "Cada número de versión solo se puede publicar una vez."]
            case .ja:   return ["バージョンを上げて（patch / minor / major）から、もう一度公開してください。",
                                "同じバージョン番号は一度しか公開できません。"]
            case .zhTW: return ["先升版（patch / minor / major），再發布一次。",
                                "每個版本號只能發布一次。"]
            case .ko:   return ["버전을 올린 뒤(patch / minor / major) 다시 배포하세요.",
                                "같은 버전 번호는 한 번만 배포할 수 있습니다."]
            case .fr:   return ["Incrémentez la version (patch / minor / major), puis republiez.",
                                "Chaque numéro de version ne peut être publié qu'une seule fois."]
            case .de:   return ["Erhöhe die Version (patch / minor / major) und veröffentliche erneut.",
                                "Jede Versionsnummer kann nur einmal veröffentlicht werden."]
            }
        case .notLoggedIn:
            switch language {
            case .en:   return ["Run `npm login` (or `npm login --auth-type=web`), then try again.",
                                "Check who you are with `npm whoami`."]
            case .es:   return ["Ejecuta `npm login` (o `npm login --auth-type=web`) y vuelve a intentarlo.",
                                "Comprueba tu identidad con `npm whoami`."]
            case .ja:   return ["`npm login`（または `npm login --auth-type=web`）を実行してから、もう一度お試しください。",
                                "`npm whoami` で現在のアカウントを確認できます。"]
            case .zhTW: return ["執行 `npm login`（或 `npm login --auth-type=web`）後再試一次。",
                                "用 `npm whoami` 確認目前登入的帳號。"]
            case .ko:   return ["`npm login`(또는 `npm login --auth-type=web`)을 실행한 뒤 다시 시도하세요.",
                                "`npm whoami`로 현재 계정을 확인하세요."]
            case .fr:   return ["Lancez `npm login` (ou `npm login --auth-type=web`), puis réessayez.",
                                "Vérifiez votre identité avec `npm whoami`."]
            case .de:   return ["Führe `npm login` (oder `npm login --auth-type=web`) aus und versuche es erneut.",
                                "Prüfe mit `npm whoami`, wer du bist."]
            }
        case .forbidden:
            switch language {
            case .en:   return ["Make sure you own this package name or are a maintainer.",
                                "For a scoped package, the first publish needs `--access public`.",
                                "Confirm you're logged in as the right account (`npm whoami`)."]
            case .es:   return ["Asegúrate de ser el dueño del nombre del paquete o un mantenedor.",
                                "Para un paquete con scope, la primera publicación necesita `--access public`.",
                                "Confirma que has iniciado sesión con la cuenta correcta (`npm whoami`)."]
            case .ja:   return ["このパッケージ名の所有者またはメンテナーであることを確認してください。",
                                "スコープ付きパッケージの初回公開には `--access public` が必要です。",
                                "正しいアカウントでログインしているか確認してください（`npm whoami`）。"]
            case .zhTW: return ["確認你是這個套件名稱的擁有者或維護者。",
                                "scoped 套件第一次發布需要加 `--access public`。",
                                "確認你登入的是正確的帳號（`npm whoami`）。"]
            case .ko:   return ["이 패키지 이름의 소유자이거나 관리자인지 확인하세요.",
                                "스코프 패키지의 첫 배포에는 `--access public`이 필요합니다.",
                                "올바른 계정으로 로그인했는지 확인하세요(`npm whoami`)."]
            case .fr:   return ["Assurez-vous d'être propriétaire du nom du paquet ou mainteneur.",
                                "Pour un paquet scopé, la première publication nécessite `--access public`.",
                                "Vérifiez que vous êtes connecté avec le bon compte (`npm whoami`)."]
            case .de:   return ["Stelle sicher, dass dir der Paketname gehört oder du Maintainer bist.",
                                "Bei einem scoped Paket braucht die erste Veröffentlichung `--access public`.",
                                "Prüfe, dass du mit dem richtigen Konto angemeldet bist (`npm whoami`)."]
            }
        case .network:
            switch language {
            case .en:   return ["Check your internet connection and try again.",
                                "If you use a proxy/VPN or a custom registry, make sure it's reachable."]
            case .es:   return ["Comprueba tu conexión a internet y vuelve a intentarlo.",
                                "Si usas un proxy/VPN o un registro personalizado, asegúrate de que sea accesible."]
            case .ja:   return ["インターネット接続を確認して、もう一度お試しください。",
                                "プロキシ/VPN やカスタムレジストリを使っている場合は、到達できるか確認してください。"]
            case .zhTW: return ["檢查你的網路連線後再試一次。",
                                "如果你用 proxy/VPN 或自訂 registry，確認它連得到。"]
            case .ko:   return ["인터넷 연결을 확인한 뒤 다시 시도하세요.",
                                "프록시/VPN이나 커스텀 레지스트리를 사용한다면 접근 가능한지 확인하세요."]
            case .fr:   return ["Vérifiez votre connexion internet et réessayez.",
                                "Si vous utilisez un proxy/VPN ou un registre personnalisé, vérifiez qu'il est accessible."]
            case .de:   return ["Prüfe deine Internetverbindung und versuche es erneut.",
                                "Wenn du Proxy/VPN oder eine eigene Registry nutzt, stelle sicher, dass sie erreichbar ist."]
            }
        case .unknown:
            switch language {
            case .en:   return ["Read npm's error output above for the specific reason.",
                                "Re-running the same command shows whether it was just transient."]
            case .es:   return ["Lee el mensaje de error de npm de arriba para ver la causa concreta.",
                                "Volver a ejecutar el mismo comando indica si fue algo temporal."]
            case .ja:   return ["上の npm のエラー出力で具体的な原因を確認してください。",
                                "同じコマンドを再実行すると、一時的な問題かどうかわかります。"]
            case .zhTW: return ["看上面 npm 的錯誤訊息找出具體原因。",
                                "重跑一次同樣的指令，可以判斷是不是暫時性問題。"]
            case .ko:   return ["위의 npm 오류 출력에서 구체적인 원인을 확인하세요.",
                                "같은 명령을 다시 실행하면 일시적인 문제인지 알 수 있습니다."]
            case .fr:   return ["Lisez la sortie d'erreur de npm ci-dessus pour la raison précise.",
                                "Relancer la même commande montre si c'était juste temporaire."]
            case .de:   return ["Lies die npm-Fehlerausgabe oben für den genauen Grund.",
                                "Den gleichen Befehl erneut auszuführen zeigt, ob es nur vorübergehend war."]
            }
        }
    }
}
