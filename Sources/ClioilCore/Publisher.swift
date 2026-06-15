import Foundation

/// The plugin seam. Each ecosystem (npm today; PyPI, crates, GitHub Releases,
/// Homebrew next) is one `Publisher`. The CLI and the future menu-bar app talk
/// only to this protocol, never to a specific registry's quirks.
public protocol Publisher: Sendable {
    /// Stable id, e.g. `"npm"`.
    var id: String { get }

    /// The most recently published version on the registry, if reachable.
    func latestPublishedVersion(of project: Project) -> String?

    /// Whether `version` already exists on the registry (a publish would fail).
    func versionExists(_ version: String, of project: Project) -> Bool
}

extension Publisher where Self == NpmPublisher {
    /// The right read-only ``Publisher`` for a project's ecosystem. Keeps the
    /// registry-query side uniform across npm / PyPI / crates so callers
    /// (StatusService, the CLI, the app) don't hard-wire npm.
    public static func forEcosystem(_ ecosystem: String) -> any Publisher {
        switch ecosystem {
        case "pypi":   return PyPIPublisher()
        case "crates": return CratesPublisher()
        default:        return NpmPublisher()
        }
    }
}

/// npm implementation. Read-only queries are wired up; the mutating publish flow
/// is intentionally still owned by the audited `.command` prototype until the
/// engine grows a confirmation/auth layer (see ROADMAP in README).
public struct NpmPublisher: Publisher {
    public let id = "npm"

    public init() {}

    public func latestPublishedVersion(of project: Project) -> String? {
        let r = Shell.run(["npm", "view", project.name, "version"], cwd: project.path)
        let v = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return (r.ok && !v.isEmpty) ? v : nil
    }

    public func versionExists(_ version: String, of project: Project) -> Bool {
        let r = Shell.run(["npm", "view", "\(project.name)@\(version)", "version"], cwd: project.path)
        return r.ok && !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
