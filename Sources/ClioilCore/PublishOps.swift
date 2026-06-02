import Foundation

/// The mutating npm operations behind `clioil publish`. Each is a thin, honest
/// wrapper over the real `npm`/`git` so behaviour matches what a user would get
/// by hand — clioil adds the guidance, not magic.
public struct PublishOps: Sendable {
    public init() {}

    /// Dependencies are missing, or package.json / lockfile is newer than
    /// node_modules (so a reinstall is warranted before testing/publishing).
    public func needsInstall(_ project: Project) -> Bool {
        let fm = FileManager.default
        let dir = project.path
        let modules = dir.appendingPathComponent("node_modules")
        guard fm.fileExists(atPath: modules.path) else { return true }

        func mtime(_ url: URL) -> Date? {
            (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        }
        guard let base = mtime(modules) else { return false }
        for f in ["package.json", "package-lock.json"] {
            let p = dir.appendingPathComponent(f)
            if fm.fileExists(atPath: p.path), let t = mtime(p), t > base { return true }
        }
        return false
    }

    @discardableResult
    public func runInstall(_ project: Project) -> Int32 {
        Shell.runInteractive(["npm", "install"], cwd: project.path)
    }

    /// True when package.json has a *real* test script (not npm's placeholder).
    public func hasRealTestScript(_ project: Project) -> Bool {
        guard
            let data = try? Data(contentsOf: project.path.appendingPathComponent("package.json")),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let scripts = obj["scripts"] as? [String: Any],
            let test = scripts["test"] as? String, !test.isEmpty
        else { return false }
        return !test.lowercased().contains("no test specified")
    }

    @discardableResult
    public func runTest(_ project: Project) -> Int32 {
        Shell.runInteractive(["npm", "test"], cwd: project.path)
    }

    /// Bump package.json only (no git tag). Returns the new version, or nil on failure.
    public func bump(_ project: Project, _ level: Bump) -> String? {
        let r = Shell.run(["npm", "version", level.rawValue, "--no-git-tag-version"], cwd: project.path)
        guard r.ok else { return nil }
        let v = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.hasPrefix("v") ? String(v.dropFirst()) : (v.isEmpty ? nil : v)
    }

    /// `npm publish --dry-run`: which files would be packed (captured, for preview).
    public func packPreview(_ project: Project) -> [String] {
        let r = Shell.run(["npm", "publish", "--dry-run", "--access", "public"], cwd: project.path)
        let lines = (r.stdout + "\n" + r.stderr).split(whereSeparator: \.isNewline).map(String.init)
        return lines
            .filter { $0.contains("notice") }
            .map { $0.replacingOccurrences(of: "npm notice", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// THE real publish — interactive (browser passkey), side-effecting, irreversible.
    @discardableResult
    public func publish(_ project: Project) -> Int32 {
        Shell.runInteractive(["npm", "publish", "--auth-type=web", "--access", "public"], cwd: project.path)
    }

    public func isLoggedIn(_ project: Project) -> Bool {
        Shell.run(["npm", "whoami"], cwd: project.path).ok
    }

    // MARK: captured variants (for the GUI — output is shown in-app, not on a TTY)

    public func runInstallCaptured(_ project: Project) -> Shell.Result {
        Shell.run(["npm", "install"], cwd: project.path)
    }

    public func runTestCaptured(_ project: Project) -> Shell.Result {
        Shell.run(["npm", "test"], cwd: project.path)
    }

    /// Real publish for the GUI, output captured. Wrapped in `script` so npm
    /// runs under a pseudo-TTY — otherwise its `--auth-type=web` flow can't open
    /// the browser / poll and fails with `EOTP` in a piped context. `script`
    /// forwards the child's exit code, so `.ok` still reflects npm's result.
    public func publishCaptured(_ project: Project) -> Shell.Result {
        Shell.run(["script", "-q", "/dev/null",
                   "npm", "publish", "--auth-type=web", "--access", "public"],
                  cwd: project.path, stdin: "\n")
    }

    /// Streaming publish for the GUI. npm prints "Authenticate your account at:
    /// <url>" then polls; `onLine` lets the caller open that URL (and show a live
    /// log). Wrapped in `script` for a PTY; "\n" answers npm's ENTER prompt.
    public func publishStreaming(
        _ project: Project,
        onLine: @escaping @Sendable (_ text: String, _ transient: Bool) -> Void
    ) -> Shell.Result {
        Shell.runStreaming(
            ["script", "-q", "/dev/null",
             "npm", "publish", "--auth-type=web", "--access", "public"],
            cwd: project.path, stdin: "\n", onLine: onLine)
    }
}
