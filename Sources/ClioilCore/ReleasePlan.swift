import Foundation
import CryptoKit

/// A *prepared* GitHub Release + Homebrew bump — everything a human needs to
/// review, then run by hand. clioil PREPARES (computes the tag, the tarball URL,
/// its SHA-256, the formula text and the exact commands); it never PUBLISHES.
/// Actually creating the release / pushing the tap is a deliberate human step,
/// so this whole file is side-effect-free except reading the source tree.
///
/// This is the "Homebrew + GitHub Releases publisher" in prepare/dry-run form:
/// the plan it returns is a faithful preview, not a stub.
public struct ReleasePlan: Sendable, Equatable, Codable {
    /// `owner/repo` parsed from the project's `origin` remote (or supplied).
    public let repoSlug: String
    /// The git tag this release would carry, e.g. `v1.2.3`.
    public let tag: String
    /// Version without the leading `v`, e.g. `1.2.3`.
    public let version: String
    /// The GitHub-generated source tarball URL for `tag`.
    public let tarballURL: String
    /// SHA-256 of the source archive (lowercase hex), if we could compute one.
    public let sha256: String?
    /// The rendered Homebrew formula (Ruby), ready to drop into a tap.
    public let formula: String
    /// The exact, copy-pasteable commands a human runs to actually publish.
    /// clioil prints these; it does NOT execute them.
    public let commands: [String]

    public init(
        repoSlug: String, tag: String, version: String,
        tarballURL: String, sha256: String?, formula: String, commands: [String]
    ) {
        self.repoSlug = repoSlug
        self.tag = tag
        self.version = version
        self.tarballURL = tarballURL
        self.sha256 = sha256
        self.formula = formula
        self.commands = commands
    }
}

/// Prepares (never executes) a GitHub Release + Homebrew formula bump.
///
/// SAFETY: every method here is read-only with respect to the world. It shells
/// out only to *read* git config and to *archive* the local tree for hashing
/// (`git archive` writes to a temp file we own). It never runs `gh`, `git push`,
/// `git tag`, `brew`, or any network mutation. The returned `commands` are text
/// for a human to run.
public struct ReleasePrep: Sendable {
    public init() {}

    // MARK: repo identity

    /// Parse `owner/repo` from a git remote URL (https or ssh forms), trimming a
    /// trailing `.git`. Returns nil for non-GitHub or unparseable remotes.
    public static func slug(fromRemote url: String) -> String? {
        var s = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // git@github.com:owner/repo.git  →  github.com/owner/repo.git
        if let colon = s.range(of: ":"), s.hasPrefix("git@") {
            s = "https://" + s[s.index(s.startIndex, offsetBy: 4)..<colon.lowerBound]
                + "/" + s[colon.upperBound...]
        }
        // ssh://git@github.com/owner/repo.git → strip scheme+host below via URL.
        guard let host = hostAndPath(s) else { return nil }
        guard host.host.lowercased().hasSuffix("github.com") else { return nil }
        var path = host.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.hasSuffix(".git") { path.removeLast(4) }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])/\(parts[1])"
    }

    private static func hostAndPath(_ s: String) -> (host: String, path: String)? {
        if let u = URL(string: s), let h = u.host { return (h, u.path) }
        return nil
    }

    /// The `origin` remote's `owner/repo`, read locally (read-only) from a repo.
    public static func repoSlug(of dir: URL) -> String? {
        let r = Shell.run(["git", "remote", "get-url", "origin"], cwd: dir)
        guard r.ok else { return nil }
        return slug(fromRemote: r.stdout)
    }

    // MARK: tarball + hashing (local, read-only)

    /// GitHub's deterministic source-tarball URL for a tag.
    public static func tarballURL(slug: String, tag: String) -> String {
        "https://github.com/\(slug)/archive/refs/tags/\(tag).tar.gz"
    }

    /// SHA-256 (lowercase hex) of an existing file, or nil if unreadable.
    public static func sha256(ofFile url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return hexSHA256(data)
    }

    public static func hexSHA256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Best-effort SHA-256 of the source archive **that GitHub will serve** for a
    /// tag, computed locally via `git archive` so it needs no network and no
    /// pushed release. GitHub's tarball prefixes every path with `repo-version/`,
    /// which `git archive --prefix` reproduces, so the hash matches byte-for-byte
    /// once gzipped — but gzip mtimes can differ, so we treat this as a preview
    /// aid and surface it as such (see `commands`, which always recompute from
    /// the real release artifact). Returns nil if the tag/ref isn't archivable.
    public static func localArchiveSHA256(dir: URL, tag: String, prefix: String) -> String? {
        // Archive an existing ref (tag or HEAD) to a temp file we own.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("clioil-archive-\(UUID().uuidString).tar.gz")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let ref = refExists(dir: dir, tag) ? tag : "HEAD"
        let r = Shell.run(
            ["git", "archive", "--format=tar.gz", "--prefix=\(prefix)/", "-o", tmp.path, ref],
            cwd: dir)
        guard r.ok else { return nil }
        return sha256(ofFile: tmp)
    }

    private static func refExists(dir: URL, _ ref: String) -> Bool {
        Shell.run(["git", "rev-parse", "--verify", "--quiet", ref], cwd: dir).ok
    }

    // MARK: plan assembly

    /// Build a full prepared plan. Pure given its inputs (no shelling) so it's
    /// trivially testable; the I/O variants above feed it real values.
    public static func makePlan(
        repoSlug: String, version: String, sha256: String?,
        homebrewClass: String? = nil, desc: String? = nil, license: String? = nil
    ) -> ReleasePlan {
        let tag = "v\(version)"
        let url = tarballURL(slug: repoSlug, tag: tag)
        let repoName = repoSlug.split(separator: "/").last.map(String.init) ?? repoSlug
        let formula = HomebrewFormula.render(
            className: homebrewClass ?? HomebrewFormula.className(for: repoName),
            repoName: repoName, version: version, url: url, sha256: sha256,
            desc: desc, license: license)
        let commands = publishCommands(slug: repoSlug, tag: tag, version: version)
        return ReleasePlan(
            repoSlug: repoSlug, tag: tag, version: version,
            tarballURL: url, sha256: sha256, formula: formula, commands: commands)
    }

    /// The exact commands a human runs to PUBLISH for real. clioil prints these
    /// behind a clear "you run these" banner and never executes them itself —
    /// creating the tag/release and pushing the tap are the irreversible,
    /// human-owned steps (the red line).
    public static func publishCommands(slug: String, tag: String, version: String) -> [String] {
        let url = tarballURL(slug: slug, tag: tag)
        return [
            "git tag \(tag) && git push origin \(tag)",
            "gh release create \(tag) --repo \(slug) --generate-notes",
            "shasum -a 256 <(curl -sL \(url))   # the real sha256 to paste into the formula",
            "brew bump-formula-pr --version \(version) <formula>   # or edit the tap formula by hand",
        ]
    }
}

/// Renders a minimal, valid Homebrew formula for a tarball release. Kept pure
/// and separate so it's unit-testable without any git/network.
public enum HomebrewFormula {
    /// Homebrew class name from a repo name: strip non-alphanumerics, UpperCamel.
    /// `cli-oil` → `CliOil`, `clioil` → `Clioil`.
    public static func className(for repoName: String) -> String {
        let parts = repoName.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let camel = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return camel.isEmpty ? "Formula" : camel
    }

    public static func render(
        className: String, repoName: String, version: String,
        url: String, sha256: String?, desc: String?, license: String?
    ) -> String {
        let shaLine = sha256.map { "  sha256 \"\($0)\"" }
            ?? "  sha256 \"REPLACE_WITH_SHA256\"  # run: shasum -a 256 <(curl -sL \(url))"
        let descLine = "  desc \"\(escape(desc ?? "\(repoName) — released via clioil"))\""
        let licenseLine = license.map { "  license \"\(escape($0))\"\n" } ?? ""
        return """
        # Generated by clioil (preview — review before publishing).
        class \(className) < Formula
        \(descLine)
          homepage "https://github.com/\(ownerSlugHint(url))"
          url "\(url)"
        \(shaLine)
          version "\(version)"
        \(licenseLine)
          def install
            # TODO: adjust for how this project builds/installs.
            bin.install Dir["*"]
          end

          test do
            system "true"
          end
        end
        """
    }

    private static func ownerSlugHint(_ url: String) -> String {
        // .../<owner>/<repo>/archive/... → owner/repo
        let parts = url.split(separator: "/")
        if let i = parts.firstIndex(of: "github.com"), parts.count > i + 2 {
            return "\(parts[i + 1])/\(parts[i + 2])"
        }
        return "OWNER/REPO"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
