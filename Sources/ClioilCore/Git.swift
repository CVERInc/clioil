import Foundation

/// Thin, read-only git helpers used by status/publish flows. All calls are safe
/// (they never mutate the repo) and degrade gracefully when `dir` isn't a repo.
public enum Git {
    public static func isRepo(_ dir: URL) -> Bool {
        Shell.run(["git", "rev-parse", "--is-inside-work-tree"], cwd: dir).ok
    }

    /// True when there are staged/unstaged/untracked changes.
    public static func isDirty(_ dir: URL) -> Bool {
        let r = Shell.run(["git", "status", "--porcelain"], cwd: dir)
        return r.ok && !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Most recent tag matching `match` (default `v*`), or nil if none.
    public static func lastTag(_ dir: URL, match: String = "v*") -> String? {
        let r = Shell.run(["git", "describe", "--tags", "--abbrev=0", "--match", match], cwd: dir)
        let t = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return (r.ok && !t.isEmpty) ? t : nil
    }

    /// One-line commit summaries on HEAD since `ref` (e.g. since the last tag).
    public static func commitsSince(_ ref: String, dir: URL) -> [String] {
        let r = Shell.run(["git", "log", "--oneline", "\(ref)..HEAD"], cwd: dir)
        guard r.ok else { return [] }
        return r.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
    }

    // MARK: mutating (LOCAL ONLY — used to record a version bump after a real
    // publish). These never contact a remote: clioil stages, commits and tags
    // locally; pushing a release stays a deliberate human step.

    /// Stage the given (existing) paths and commit **only those paths**.
    ///
    /// The commit is pathspec-scoped (`git commit -- <paths>`), so any unrelated
    /// changes the user already had staged are *not* swept into the "release vX"
    /// commit. Returns true on success; false (committing nothing) if none of the
    /// release paths exist on disk — we never fabricate an empty/foreign commit.
    @discardableResult
    public static func commit(_ dir: URL, message: String, paths: [String]) -> Bool {
        let fm = FileManager.default
        let present = paths.filter { fm.fileExists(atPath: dir.appendingPathComponent($0).path) }
        guard !present.isEmpty else { return false }
        for p in present { _ = Shell.run(["git", "add", p], cwd: dir) }
        // `--` then the explicit paths: commit ONLY these, ignoring other staged work.
        return Shell.run(["git", "commit", "-m", message, "--"] + present, cwd: dir).ok
    }

    @discardableResult
    public static func tag(_ dir: URL, _ name: String) -> Bool {
        Shell.run(["git", "tag", name], cwd: dir).ok
    }
}
