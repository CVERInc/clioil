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
}
