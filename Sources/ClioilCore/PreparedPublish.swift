import Foundation

/// A *prepared* publish for a registry that clioil does not yet execute on the
/// user's behalf — PyPI and crates.io today. Mirrors ``ReleasePlan``'s
/// prepare/dry-run philosophy: clioil computes the exact commands a human runs
/// (and a safe dry-run/preview it CAN run), but never performs the real,
/// irreversible upload itself.
///
/// SAFETY: the `publishCommands` are TEXT for a human to run. The `dryRunCommand`
/// is the one command clioil may actually execute, and it is — by construction —
/// the tool's own non-mutating preview mode (`twine check`, `cargo publish
/// --dry-run`). Nothing here uploads.
public struct PreparedPublish: Sendable, Equatable, Codable {
    /// Which ecosystem this plan targets, e.g. `"pypi"` / `"crates"`.
    public let ecosystem: String
    /// Package name as declared in the manifest.
    public let name: String
    /// Version being prepared.
    public let version: String
    /// The exact, copy-pasteable commands a human runs to actually publish.
    /// clioil prints these; it does NOT execute them.
    public let publishCommands: [String]
    /// A single non-mutating command clioil may run to preview/validate the
    /// build without uploading anything (the dry-run path).
    public let dryRunCommand: [String]
    /// Short, human-readable note about what the dry run does.
    public let dryRunNote: String

    public init(
        ecosystem: String, name: String, version: String,
        publishCommands: [String], dryRunCommand: [String], dryRunNote: String
    ) {
        self.ecosystem = ecosystem
        self.name = name
        self.version = version
        self.publishCommands = publishCommands
        self.dryRunCommand = dryRunCommand
        self.dryRunNote = dryRunNote
    }
}

/// The outcome of running the (safe) dry-run preview.
public struct DryRunResult: Sendable, Equatable, Codable {
    public let ok: Bool
    public let output: [String]
    public init(ok: Bool, output: [String]) {
        self.ok = ok
        self.output = output
    }
}

/// Prepares (never executes) a PyPI publish. Build + upload are the human's
/// irreversible steps; clioil computes the commands and offers `twine check`
/// (validate the built artifacts — does not touch the network) as the dry run.
///
/// Detection lives in ``ProjectScanner`` (pyproject.toml / setup.py); this type
/// owns the command generation and the safe preview, so the logic is pure and
/// unit-testable without a real Python toolchain.
public struct PyPIPublisher: Publisher {
    public let id = "pypi"
    public init() {}

    // Read-only registry queries via PyPI's public JSON API (no auth, no upload).
    public func latestPublishedVersion(of project: Project) -> String? {
        let r = Shell.run(
            ["curl", "-fsSL", "https://pypi.org/pypi/\(project.name)/json"],
            cwd: project.path)
        guard r.ok, let data = r.stdout.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let info = obj["info"] as? [String: Any],
              let v = info["version"] as? String, !v.isEmpty
        else { return nil }
        return v
    }

    public func versionExists(_ version: String, of project: Project) -> Bool {
        let r = Shell.run(
            ["curl", "-fsSL", "-o", "/dev/null", "-w", "%{http_code}",
             "https://pypi.org/pypi/\(project.name)/\(version)/json"],
            cwd: project.path)
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "200"
    }

    /// Build the prepared plan. Pure given its inputs — no shelling — so it's
    /// trivially testable.
    public static func prepare(name: String, version: String) -> PreparedPublish {
        PreparedPublish(
            ecosystem: "pypi",
            name: name,
            version: version,
            publishCommands: [
                "python -m build",
                "python -m twine upload dist/*",
            ],
            dryRunCommand: ["python", "-m", "twine", "check", "dist/*"],
            dryRunNote: "validates built artifacts — no upload, no network mutation")
    }

    /// Run the safe dry-run preview (`twine check`). This NEVER uploads. If the
    /// project hasn't been built yet there's nothing to check — that surfaces as
    /// a non-ok result with twine's own message, which is honest, not a crash.
    public func dryRun(_ project: Project) -> DryRunResult {
        let r = Shell.run(["python", "-m", "twine", "check", "dist/*"], cwd: project.path)
        let lines = (r.stdout + "\n" + r.stderr)
            .split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return DryRunResult(ok: r.ok, output: lines)
    }
}

/// Prepares (never executes) a crates.io publish. `cargo publish` is the human's
/// irreversible step; clioil computes it and offers `cargo publish --dry-run`
/// (packages + verifies the crate without uploading) as the safe preview.
public struct CratesPublisher: Publisher {
    public let id = "crates"
    public init() {}

    // Read-only registry query via crates.io's public API.
    public func latestPublishedVersion(of project: Project) -> String? {
        let r = Shell.run(
            ["curl", "-fsSL", "https://crates.io/api/v1/crates/\(project.name)"],
            cwd: project.path)
        guard r.ok, let data = r.stdout.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let crate = obj["crate"] as? [String: Any],
              let v = crate["max_version"] as? String, !v.isEmpty
        else { return nil }
        return v
    }

    public func versionExists(_ version: String, of project: Project) -> Bool {
        let r = Shell.run(
            ["curl", "-fsSL", "-o", "/dev/null", "-w", "%{http_code}",
             "https://crates.io/api/v1/crates/\(project.name)/\(version)"],
            cwd: project.path)
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "200"
    }

    /// Build the prepared plan. Pure given its inputs.
    public static func prepare(name: String, version: String) -> PreparedPublish {
        PreparedPublish(
            ecosystem: "crates",
            name: name,
            version: version,
            publishCommands: [
                "cargo publish",
            ],
            dryRunCommand: ["cargo", "publish", "--dry-run"],
            dryRunNote: "packages + verifies the crate — no upload to crates.io")
    }

    /// Run the safe dry-run preview (`cargo publish --dry-run`). Cargo's own
    /// `--dry-run` builds and verifies the package but stops short of uploading.
    public func dryRun(_ project: Project) -> DryRunResult {
        let r = Shell.run(["cargo", "publish", "--dry-run"], cwd: project.path)
        let lines = (r.stdout + "\n" + r.stderr)
            .split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return DryRunResult(ok: r.ok, output: lines)
    }
}
