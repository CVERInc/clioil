import Foundation

/// Localized strings for the AI remediation advisor (on-device Foundation Models
/// + Claude API fallback). Exhaustive per language (compiler-enforced).
extension L10n {
    /// System prompt for both AI paths. The model's job: one short, practical
    /// remediation paragraph, grounded in the failure, in the user's language.
    public func advisorSystemPrompt() -> String {
        switch language {
        case .en:   return "You help a developer fix a failed package publish. Give one short, concrete remediation (2-4 sentences or a tight bullet list). Stay grounded in the error and clioil's guidance shown; do not invent registry behaviour. Reply in English."
        case .es:   return "Ayudas a una persona desarrolladora a corregir una publicación de paquete fallida. Da una solución breve y concreta (2-4 frases o una lista breve). Cíñete al error y a la guía de clioil mostrada; no inventes comportamientos del registro. Responde en español."
        case .ja:   return "パッケージ公開の失敗を直す開発者を手伝います。短く具体的な対処法を 1 つ（2〜4 文か簡潔な箇条書き）で示してください。エラーと表示された clioil のガイドに沿い、レジストリの挙動を創作しないこと。日本語で答えてください。"
        case .zhTW: return "你要協助開發者修正失敗的套件發布。給出一段簡短、具體的解法（2 到 4 句或精簡條列）。緊扣錯誤訊息與顯示的 clioil 指引，不要杜撰登錄平台的行為。請用繁體中文回答。"
        case .ko:   return "패키지 배포 실패를 고치려는 개발자를 돕습니다. 짧고 구체적인 해결책 하나를(2~4문장 또는 간결한 목록) 제시하세요. 오류와 표시된 clioil 안내에 근거하고, 레지스트리 동작을 지어내지 마세요. 한국어로 답하세요."
        case .fr:   return "Vous aidez une personne à corriger une publication de paquet échouée. Donnez une seule remédiation courte et concrète (2 à 4 phrases ou une liste brève). Restez fidèle à l'erreur et au guide clioil affiché ; n'inventez pas le comportement du registre. Répondez en français."
        case .de:   return "Du hilfst, eine fehlgeschlagene Paket-Veröffentlichung zu beheben. Gib eine kurze, konkrete Lösung (2-4 Sätze oder eine knappe Liste). Bleib bei der Fehlermeldung und der gezeigten clioil-Anleitung; erfinde kein Registry-Verhalten. Antworte auf Deutsch."
        }
    }

    /// Appended to the prompt so the model answers in the user's language.
    public func advisorAskInLanguage() -> String {
        switch language {
        case .en:   return "Give me the single most useful next step."
        case .es:   return "Dame el siguiente paso más útil."
        case .ja:   return "最も役立つ次の一手を教えてください。"
        case .zhTW: return "請給我最有用的下一步。"
        case .ko:   return "가장 유용한 다음 단계를 알려주세요."
        case .fr:   return "Donnez-moi l'étape suivante la plus utile."
        case .de:   return "Nenne mir den nützlichsten nächsten Schritt."
        }
    }

    /// Prefix shown when no AI path ran and we fall back to built-in guidance.
    public func advisorNoAI() -> String {
        switch language {
        case .en:   return "(No AI available — showing clioil's built-in guidance.)"
        case .es:   return "(Sin IA disponible — mostrando la guía integrada de clioil.)"
        case .ja:   return "（AI を利用できません — clioil 内蔵のガイドを表示します。）"
        case .zhTW: return "（沒有可用的 AI —— 顯示 clioil 內建指引。）"
        case .ko:   return "(사용 가능한 AI 없음 — clioil 기본 안내를 표시합니다.)"
        case .fr:   return "(Aucune IA disponible — affichage du guide intégré de clioil.)"
        case .de:   return "(Keine KI verfügbar — zeige clioils eingebaute Anleitung.)"
        }
    }

    /// Header shown above an AI remediation hint in the CLI / app.
    public func advisorHintHeader() -> String {
        switch language {
        case .en:   return "AI suggestion"
        case .es:   return "Sugerencia de IA"
        case .ja:   return "AI の提案"
        case .zhTW: return "AI 建議"
        case .ko:   return "AI 제안"
        case .fr:   return "Suggestion de l'IA"
        case .de:   return "KI-Vorschlag"
        }
    }

    /// Short label naming where a remediation came from, for the UI/CLI.
    public func advisorSourceLabel(_ source: RemediationSource) -> String {
        switch (source, language) {
        case (.onDevice, .en):   return "On-device AI"
        case (.onDevice, .es):   return "IA en el dispositivo"
        case (.onDevice, .ja):   return "オンデバイス AI"
        case (.onDevice, .zhTW): return "裝置端 AI"
        case (.onDevice, .ko):   return "온디바이스 AI"
        case (.onDevice, .fr):   return "IA sur l'appareil"
        case (.onDevice, .de):   return "On-Device-KI"
        case (.claude, .en):     return "Claude (API)"
        case (.claude, .es):     return "Claude (API)"
        case (.claude, .ja):     return "Claude（API）"
        case (.claude, .zhTW):   return "Claude（API）"
        case (.claude, .ko):     return "Claude (API)"
        case (.claude, .fr):     return "Claude (API)"
        case (.claude, .de):     return "Claude (API)"
        case (.none, .en):       return "Built-in guidance"
        case (.none, .es):       return "Guía integrada"
        case (.none, .ja):       return "内蔵ガイド"
        case (.none, .zhTW):     return "內建指引"
        case (.none, .ko):       return "기본 안내"
        case (.none, .fr):       return "Guide intégré"
        case (.none, .de):       return "Eingebaute Anleitung"
        }
    }
}
