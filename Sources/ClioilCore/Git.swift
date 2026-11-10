import Foundation

/// Which tree a project row actually is. Two checkouts of one repo can carry the
/// same package name and version string while being different code, so every
/// row says its branch and whether it is the one you would publish from.
public struct Checkout: Sendable, Codable, Equatable {
    public let isRepo: Bool
    /// nil on a detached HEAD.
    public let branch: String?
    public let defaultBranch: String?
    public let dirty: Bool

    public init(isRepo: Bool, branch: String?, defaultBranch: String?, dirty: Bool) {
        self.isRepo = isRepo; self.branch = branch
        self.defaultBranch = defaultBranch; self.dirty = dirty
    }

    /// How the branch reads in a row or a prompt.
    public var branchLabel: String { branch ?? "detached HEAD" }

    /// Known to be somewhere other than the default branch. False when the
    /// default branch is unknown: no claim is better than a wrong warning.
    public var isOffDefaultBranch: Bool {
        guard isRepo, let d = defaultBranch else { return false }
        return branch != d
    }

    /// The tree a release is normally cut from: default branch, nothing uncommitted.
    public var isPublishSource: Bool {
        guard isRepo, let d = defaultBranch else { return false }
        return branch == d && !dirty
    }
}

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

    /// The checked-out branch, or nil on a detached HEAD (or outside a repo).
    public static func currentBranch(_ dir: URL) -> String? {
        let r = Shell.run(["git", "symbolic-ref", "--short", "-q", "HEAD"], cwd: dir)
        let b = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return (r.ok && !b.isEmpty) ? b : nil
    }

    /// The branch releases are cut from: what `origin/HEAD` points at, else a
    /// local `main` or `master`. nil when the repo gives no way to tell — callers
    /// then make no claim about "default" rather than guess.
    public static func defaultBranch(_ dir: URL) -> String? {
        let r = Shell.run(["git", "symbolic-ref", "--short", "-q", "refs/remotes/origin/HEAD"], cwd: dir)
        let full = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if r.ok, full.hasPrefix("origin/"), full.count > 7 { return String(full.dropFirst(7)) }
        for name in ["main", "master"]
        where Shell.run(["git", "show-ref", "--verify", "--quiet", "refs/heads/\(name)"], cwd: dir).ok {
            return name
        }
        return nil
    }

    /// Where this checkout stands — cheap (no network), safe to gather per row.
    public static func checkout(_ dir: URL) -> Checkout {
        guard isRepo(dir) else { return Checkout(isRepo: false, branch: nil, defaultBranch: nil, dirty: false) }
        return Checkout(isRepo: true, branch: currentBranch(dir),
                        defaultBranch: defaultBranch(dir), dirty: isDirty(dir))
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
