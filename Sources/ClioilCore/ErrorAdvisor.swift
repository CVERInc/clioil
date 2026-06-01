import Foundation

/// Known npm publish failure modes we can give friendly, specific guidance for.
public enum PublishErrorKind: String, Sendable, CaseIterable, Codable {
    case versionExists
    case notLoggedIn
    case forbidden
    case network
    case unknown
}

/// Plain-language explanation of a failure plus concrete next steps.
public struct Advice: Sendable, Equatable, Codable {
    public let kind: PublishErrorKind
    public let title: String
    public let steps: [String]

    public init(kind: PublishErrorKind, title: String, steps: [String]) {
        self.kind = kind
        self.title = title
        self.steps = steps
    }
}

/// Turns raw npm output into friendly, localized guidance. This is the heart of
/// "considerate to beginners": no one should have to decode an `E403` stack.
public struct ErrorAdvisor: Sendable {
    public let l10n: L10n
    public init(_ l10n: L10n) { self.l10n = l10n }

    /// Classify npm's combined output into a failure mode.
    ///
    /// Order matters: "you cannot publish over the previously published
    /// versions" is delivered as an HTTP 403, so the version-exists check must
    /// run before the generic forbidden check.
    public static func classify(stdout: String, stderr: String) -> PublishErrorKind {
        let s = (stdout + "\n" + stderr).lowercased()
        func has(_ needles: [String]) -> Bool { needles.contains(where: s.contains) }

        if has(["cannot publish over", "previously published versions",
                "epublishconflict", "version already exists"]) {
            return .versionExists
        }
        if has(["eneedauth", "need auth", "requires you to be logged in",
                "authentication required", "log in to publish"]) {
            return .notLoggedIn
        }
        if has(["e403", "403 forbidden", "forbidden",
                "you do not have permission", "not allowed to publish"]) {
            return .forbidden
        }
        if has(["enotfound", "etimedout", "eai_again", "econnrefused",
                "network", "request to https", "fetch failed"]) {
            return .network
        }
        return .unknown
    }

    /// Friendly advice for raw npm output.
    public func advise(stdout: String, stderr: String) -> Advice {
        advise(Self.classify(stdout: stdout, stderr: stderr))
    }

    /// Friendly advice for an already-classified failure mode.
    public func advise(_ kind: PublishErrorKind) -> Advice {
        Advice(kind: kind, title: l10n.adviceTitle(kind), steps: l10n.adviceSteps(kind))
    }
}
