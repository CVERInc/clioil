import Foundation

/// Current Claude model IDs clioil knows about. Pinned as constants so a stale
/// ID can never silently ship — the tests assert these exact strings. Use a
/// cost-appropriate model for short remediation hints (Haiku by default; Sonnet
/// when a beefier hint is warranted).
///
/// IMPORTANT: keep these in sync with the model catalog. Do NOT append date
/// suffixes to the aliases.
public enum ClaudeModel {
    /// Most capable (Opus-tier). Overkill for a one-paragraph remediation hint —
    /// here for completeness / explicit "second opinion" requests only.
    public static let opus = "claude-opus-4-8"
    /// Balanced speed/intelligence. The step-up when Haiku's hint isn't enough.
    public static let sonnet = "claude-sonnet-4-6"
    /// Fastest + cheapest. The default for short, latency-light remediation hints.
    public static let haiku = "claude-haiku-4-5-20251001"

    /// The model clioil reaches for by default when producing a remediation hint:
    /// cheap and fast, because the job is a short paragraph, not deep reasoning.
    public static let defaultRemediation = haiku
}

/// Where a remediation suggestion came from, so the UI/CLI can be honest about
/// whether AI was involved and which path produced the text.
public enum RemediationSource: String, Sendable, Equatable, Codable {
    /// Apple's on-device Foundation Models system LLM (no network, private).
    case onDevice
    /// The Claude API fallback (opt-in; only when an API key is present).
    case claude
    /// No AI ran — neither the on-device model nor a Claude key was available.
    /// The advice falls back to clioil's own deterministic ``ErrorAdvisor`` text.
    case none
}

/// A remediation suggestion for a publish failure: a short, human-readable hint
/// plus where it came from.
public struct Remediation: Sendable, Equatable, Codable {
    public let source: RemediationSource
    public let suggestion: String
    public init(source: RemediationSource, suggestion: String) {
        self.source = source
        self.suggestion = suggestion
    }
}

/// Produces a remediation suggestion when a publish fails.
///
/// Path priority, by design:
///   1. **On-device** — Apple Foundation Models (macOS 26+, Apple Intelligence
///      on). Private, no network, like glossglyph/shelfseer.
///   2. **Claude API fallback** — ONLY when an API key is present (env or a
///      caller-supplied key). Off by default; no key → never attempted, never
///      crashes.
///   3. **Deterministic** — clioil's own ``ErrorAdvisor`` guidance, always
///      available, so the user is never left with nothing.
///
/// The Claude key is read from the environment (`ANTHROPIC_API_KEY`, or
/// `CLIOIL_ANTHROPIC_API_KEY` to scope it to clioil) — never hardcoded. A nil/
/// empty key disables the fallback cleanly.
public struct RemediationAdvisor: Sendable {
    public let l10n: L10n
    /// The Claude model used if the fallback runs. Defaults to a cheap model.
    public let claudeModel: String
    /// Explicit API key override (tests / callers). When nil, the environment is
    /// consulted. An empty resolved key means "no Claude fallback".
    private let apiKeyOverride: String?
    /// Environment to read the key from (injectable for tests).
    private let environment: [String: String]

    public init(
        _ l10n: L10n,
        claudeModel: String = ClaudeModel.defaultRemediation,
        apiKey: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.l10n = l10n
        self.claudeModel = claudeModel
        self.apiKeyOverride = apiKey
        self.environment = environment
    }

    /// The resolved Claude API key, or nil if no fallback is configured. Order:
    /// explicit override → `CLIOIL_ANTHROPIC_API_KEY` → `ANTHROPIC_API_KEY`. An
    /// empty string is treated as absent.
    public var claudeKey: String? {
        let candidates = [
            apiKeyOverride,
            environment["CLIOIL_ANTHROPIC_API_KEY"],
            environment["ANTHROPIC_API_KEY"],
        ]
        for c in candidates {
            if let c, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return c
            }
        }
        return nil
    }

    /// Whether the Claude fallback is even possible (a key is present). The
    /// on-device path is always *attempted* first regardless of this.
    public var claudeFallbackAvailable: Bool { claudeKey != nil }

    /// Produce a remediation for a raw publish failure. Classifies the output
    /// into a ``PublishErrorKind`` first (so even the no-AI path is specific),
    /// then tries on-device → Claude → deterministic.
    public func advise(stdout: String, stderr: String) async -> Remediation {
        let kind = ErrorAdvisor.classify(stdout: stdout, stderr: stderr)
        return await advise(kind: kind, rawOutput: trimmedTail(stdout, stderr))
    }

    /// Produce a remediation for an already-classified failure. `rawOutput` is
    /// optional extra context (the tail of the real error) the models can use.
    public func advise(kind: PublishErrorKind, rawOutput: String = "") async -> Remediation {
        // Deterministic guidance is always computed — it's the floor we degrade
        // to, and it seeds the prompt for the AI paths.
        let baseline = ErrorAdvisor(l10n).advise(kind)
        let prompt = Self.buildPrompt(kind: kind, baseline: baseline, rawOutput: rawOutput, l10n: l10n)

        // 1) On-device first (private, free, no network).
        if let onDevice = await onDeviceSuggestion(prompt: prompt) {
            return Remediation(source: .onDevice, suggestion: onDevice)
        }

        // 2) Claude fallback — only if a key is present. No key → skip entirely.
        if let key = claudeKey,
           let claude = await claudeSuggestion(prompt: prompt, key: key) {
            return Remediation(source: .claude, suggestion: claude)
        }

        // 3) No AI available — return the deterministic guidance with a clear,
        //    honest "no AI available" framing. Never crashes, always has text.
        return Remediation(source: .none, suggestion: Self.deterministicText(baseline, l10n: l10n))
    }

    // MARK: - on-device (Apple Foundation Models)

    /// Run the on-device model if it's available; nil otherwise (older OS, Apple
    /// Intelligence off, model not downloaded, or any generation error — all of
    /// which degrade to the next path rather than throwing).
    private func onDeviceSuggestion(prompt: String) async -> String? {
        await Self.onDeviceGenerate(instructions: Self.instructions(l10n), prompt: prompt)
    }

    // MARK: - Claude API fallback (raw HTTP — no official Swift SDK)

    /// Call Claude's Messages API for a short remediation hint. Returns nil on
    /// any error (network down, bad key, rate limit) so the advisor degrades to
    /// the deterministic path rather than failing. Never throws to the caller.
    private func claudeSuggestion(prompt: String, key: String) async -> String? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": claudeModel,
            "max_tokens": 400,
            "system": Self.instructions(l10n),
            "messages": [["role": "user", "content": prompt]],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = data

        do {
            let (respData, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return Self.extractClaudeText(respData)
        } catch {
            return nil
        }
    }

    /// Pull the first text block out of a Claude Messages API response.
    public static func extractClaudeText(_ data: Data) -> String? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else { return nil }
        for block in content {
            if block["type"] as? String == "text",
               let text = (block["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
        }
        return nil
    }

    // MARK: - prompt + deterministic text

    /// Frame the deterministic guidance as a "no AI available" answer so the user
    /// understands the suggestion is clioil's built-in guidance, not a synthesis.
    public static func deterministicText(_ advice: Advice, l10n: L10n) -> String {
        let steps = advice.steps.map { "• \($0)" }.joined(separator: "\n")
        return "\(l10n.advisorNoAI())\n\(advice.title)\n\(steps)"
    }

    /// Build the user prompt fed to whichever model runs. Includes the
    /// classification, clioil's own guidance (as grounding), and the raw tail.
    public static func buildPrompt(kind: PublishErrorKind, baseline: Advice, rawOutput: String, l10n: L10n) -> String {
        var lines = [
            "A publish failed. Classification: \(kind.rawValue).",
            "clioil's built-in guidance:",
            "  \(baseline.title)",
        ]
        for s in baseline.steps { lines.append("  - \(s)") }
        if !rawOutput.isEmpty {
            lines.append("")
            lines.append("Tail of the real error output:")
            lines.append(rawOutput)
        }
        lines.append("")
        lines.append(l10n.advisorAskInLanguage())
        return lines.joined(separator: "\n")
    }

    /// System instructions for both AI paths: short, practical, in the user's
    /// language, grounded in the failure — never invent registry behaviour.
    public static func instructions(_ l10n: L10n) -> String {
        l10n.advisorSystemPrompt()
    }

    /// Keep only the last ~1200 chars of combined output — enough context for a
    /// hint without flooding the on-device context window.
    private func trimmedTail(_ stdout: String, _ stderr: String) -> String {
        let combined = (stdout + "\n" + stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.count <= 1200 { return combined }
        return "…" + String(combined.suffix(1200))
    }
}

// MARK: - Foundation Models bridge (isolated so the rest stays portable)

#if canImport(FoundationModels)
import FoundationModels

extension RemediationAdvisor {
    /// Generate on-device with Apple's system LLM. Returns nil when the model is
    /// unavailable (older OS, Apple Intelligence off, not downloaded) or on any
    /// generation error — the caller degrades. Never throws.
    static func onDeviceGenerate(instructions: String, prompt: String) async -> String? {
        guard #available(macOS 26.0, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
}
#else
extension RemediationAdvisor {
    /// No Foundation Models on this platform/SDK — on-device is simply absent and
    /// the advisor falls through to the Claude / deterministic paths.
    static func onDeviceGenerate(instructions: String, prompt: String) async -> String? { nil }
}
#endif
