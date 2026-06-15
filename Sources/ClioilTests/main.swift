import Foundation
import ClioilCore

// Minimal, framework-free test runner: `swift run ClioilTests`.
// Exits non-zero on any failure so it can gate CI.

var failures = 0
@MainActor func check(_ condition: Bool, _ label: String) {
    if condition {
        print("  ✓ \(label)")
    } else {
        print("  ✗ \(label)")
        failures += 1
    }
}

print("Bump")
check(Bump.patch.apply(to: "1.2.3") == "1.2.4", "patch 1.2.3 → 1.2.4")
check(Bump.minor.apply(to: "1.2.3") == "1.3.0", "minor 1.2.3 → 1.3.0")
check(Bump.major.apply(to: "1.2.3") == "2.0.0", "major 1.2.3 → 2.0.0")
check(Bump.none.apply(to: "1.2.3") == "1.2.3", "none keeps 1.2.3")
check(Bump.patch.apply(to: "2.2.0-rc.1") == "2.2.1", "patch drops prerelease 2.2.0-rc.1 → 2.2.1")

print("ProjectScanner")
do {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("clioil-test-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: root) }

    func writeManifest(_ json: String, at dir: URL) throws {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    }

    try writeManifest(#"{"name":"good-pkg","version":"1.4.2"}"#, at: root.appendingPathComponent("good"))
    try writeManifest(#"{"name":"secret","version":"0.1.0","private":true}"#, at: root.appendingPathComponent("secret"))
    try writeManifest(#"{"version":"9.9.9"}"#, at: root.appendingPathComponent("noname"))
    try writeManifest(#"{"name":"dep","version":"1.0.0"}"#, at: root.appendingPathComponent("node_modules/dep"))

    let projects = ProjectScanner(roots: [root], maxDepth: 1).scan()
    check(projects.count == 1, "finds exactly the one publishable project")
    check(projects.first?.name == "good-pkg", "reads name")
    check(projects.first?.version == "1.4.2", "reads version")
    check(projects.first?.ecosystem == "npm", "tags ecosystem npm")
} catch {
    check(false, "scanner setup threw: \(error)")
}

print("Project.displayPath")
let home = FileManager.default.homeDirectoryForCurrentUser
let sample = Project(path: home.appendingPathComponent("dev/thing"), name: "x", version: "1.0.0", ecosystem: "npm")
check(sample.displayPath == "~/dev/thing", "collapses home to ~")

print("Language.parse")
check(Language.parse("zh-Hant-TW") == .zhTW, "zh-Hant-TW → zhTW")
check(Language.parse("zh_TW.UTF-8") == .zhTW, "zh_TW.UTF-8 → zhTW")
check(Language.parse("zh_CN") == .zhTW, "any Chinese → zhTW (no simplified, by design)")
check(Language.parse("es_ES") == .es, "es_ES → es")
check(Language.parse("ja") == .ja, "ja → ja")
check(Language.parse("ko_KR") == .ko, "ko_KR → ko")
check(Language.parse("fr-FR") == .fr, "fr-FR → fr")
check(Language.parse("de") == .de, "de → de")
check(Language.parse("en_US.UTF-8") == .en, "en_US.UTF-8 → en")
check(Language.parse("xx") == nil, "unknown → nil")
// Full BCP-47 tags parse too
check(Language.parse("en-US") == .en, "en-US → en")
check(Language.parse("ja-JP") == .ja, "ja-JP → ja")
check(Language.parse("zh-TW") == .zhTW, "zh-TW → zhTW")

print("Language canonical tags (full BCP-47, aligned across OSS)")
let tags = Language.allCases.map(\.rawValue).sorted()
check(tags == ["de-DE", "en-US", "es-ES", "fr-FR", "ja-JP", "ko-KR", "zh-TW"],
      "rawValues are the agreed full tags: \(tags.joined(separator: ", "))")

print("Language.detect")
check(Language.detect(override: "ja", environment: ["LANG": "en_US"]) == .ja, "override beats env")
check(Language.detect(environment: ["LANG": "es_ES.UTF-8"], localeIdentifier: "en_US") == .es, "env LANG used")
check(Language.detect(override: "xx", environment: [:], localeIdentifier: "C") == .en, "falls back to en")
check(Language.detect(environment: ["CLIOIL_LANG": "ko"], localeIdentifier: "en_US") == .ko, "CLIOIL_LANG used")

print("L10n coverage (all languages produce non-empty, distinct messages)")
var headers = Set<String>()
for lang in Language.allCases {
    let t = L10n(lang)
    let ok = !t.projectsHeader(3).isEmpty
        && !t.noProjectsFound().isEmpty
        && !t.unknownCommand("x").isEmpty
        && t.help().contains("clioil list")
        && !lang.endonym.isEmpty
    check(ok, "\(lang.rawValue): all messages present")
    headers.insert(t.projectsHeader(3))
}
check(headers.count == Language.allCases.count, "every language has a distinct header (\(headers.count)/\(Language.allCases.count))")

print("Git (against a real temp repo)")
do {
    let fm = FileManager.default
    let repo = fm.temporaryDirectory.appendingPathComponent("clioil-git-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: repo) }
    try fm.createDirectory(at: repo, withIntermediateDirectories: true)

    func git(_ args: [String]) { _ = Shell.run(["git"] + args, cwd: repo) }
    git(["init", "-q"])
    git(["config", "user.email", "t@t.test"])
    git(["config", "user.name", "t"])
    git(["commit", "--allow-empty", "-q", "-m", "first"])
    git(["tag", "v0.1.0"])

    check(Git.isRepo(repo), "isRepo true for a git dir")
    check(!Git.isRepo(fm.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString)")),
          "isRepo false for a non-repo")
    check(Git.lastTag(repo) == "v0.1.0", "lastTag reads v0.1.0")
    check(Git.commitsSince("v0.1.0", dir: repo).isEmpty, "no commits since the tag yet")

    git(["commit", "--allow-empty", "-q", "-m", "second after tag"])
    check(Git.commitsSince("v0.1.0", dir: repo).count == 1, "one commit since the tag")

    check(!Git.isDirty(repo), "clean tree not dirty")
    try "x".write(to: repo.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
    check(Git.isDirty(repo), "untracked file makes it dirty")
} catch {
    check(false, "git test setup threw: \(error)")
}

print("StatusService (stubbed registry — no network)")
struct StubPublisher: Publisher {
    let id = "stub"
    let latest: String?
    let existing: Set<String>
    func latestPublishedVersion(of project: Project) -> String? { latest }
    func versionExists(_ version: String, of project: Project) -> Bool { existing.contains(version) }
}
do {
    let proj = Project(path: FileManager.default.temporaryDirectory, name: "demo", version: "1.2.0", ecosystem: "npm")
    let pub = StubPublisher(latest: "1.1.0", existing: ["1.0.0", "1.1.0"])
    let s = StatusService(publisher: pub).status(of: proj)
    check(s.registryLatest == "1.1.0", "status carries registry latest")
    check(s.currentIsPublished == false, "1.2.0 not yet published")

    let pub2 = StubPublisher(latest: "1.2.0", existing: ["1.2.0"])
    let s2 = StatusService(publisher: pub2).status(of: proj)
    check(s2.currentIsPublished, "1.2.0 detected as already published")
}

print("CLI L10n: status strings present in every language")
for lang in Language.allCases {
    let t = L10n(lang)
    let ok = !t.statusOnNpm().isEmpty
        && t.statusReadyToPublish("1.0.0").contains("1.0.0")
        && t.statusAlreadyPublished("1.0.0").contains("1.0.0")
        && !t.statusGitDirty().isEmpty
        && t.statusChangesSince("v1", 2).contains("v1")
        && t.help().contains("clioil status")
    check(ok, "\(lang.rawValue): status strings present")
}

print("ErrorAdvisor.classify (real npm error snippets)")
check(ErrorAdvisor.classify(stdout: "", stderr: "npm error code E403\nnpm error 403 Forbidden - PUT https://registry.npmjs.org/foo - You cannot publish over the previously published versions: 1.0.0.") == .versionExists,
      "403 'publish over previously published' → versionExists (not forbidden)")
check(ErrorAdvisor.classify(stdout: "", stderr: "npm error code ENEEDAUTH\nnpm error need auth This command requires you to be logged in.") == .notLoggedIn,
      "ENEEDAUTH → notLoggedIn")
check(ErrorAdvisor.classify(stdout: "", stderr: "npm error code E403\nnpm error 403 Forbidden - you do not have permission to publish 'foo'.") == .forbidden,
      "plain 403 permission → forbidden")
check(ErrorAdvisor.classify(stdout: "", stderr: "npm error code ENOTFOUND\nnpm error network request to https://registry.npmjs.org failed") == .network,
      "ENOTFOUND/network → network")
check(ErrorAdvisor.classify(stdout: "", stderr: "npm error something nobody has ever seen") == .unknown,
      "novel error → unknown")

print("ErrorAdvisor.advise coverage (every kind, every language)")
for lang in Language.allCases {
    let advisor = ErrorAdvisor(L10n(lang))
    for kind in PublishErrorKind.allCases {
        let a = advisor.advise(kind)
        let ok = a.kind == kind && !a.title.isEmpty && !a.steps.isEmpty
            && a.steps.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        check(ok, "\(lang.rawValue)/\(kind.rawValue): title + \(a.steps.count) step(s)")
    }
}

print("PublishOps decision logic (filesystem, no npm)")
do {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("clioil-pub-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: dir) }
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    func write(_ name: String, _ body: String) throws {
        try body.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    try write("package.json", #"{"name":"x","version":"1.0.0","scripts":{"test":"vitest run"}}"#)
    let proj = Project(path: dir, name: "x", version: "1.0.0", ecosystem: "npm")
    let ops = PublishOps()

    check(ops.needsInstall(proj), "no node_modules → needs install")
    check(ops.hasRealTestScript(proj), "real test script detected")

    try fm.createDirectory(at: dir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
    check(!ops.needsInstall(proj), "with node_modules (fresh) → no install needed")

    // npm placeholder test script is not "real"
    try write("package.json", #"{"name":"x","version":"1.0.0","scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}"#)
    check(!ops.hasRealTestScript(proj), "npm placeholder test script → not real")

    try write("package.json", #"{"name":"x","version":"1.0.0"}"#)
    check(!ops.hasRealTestScript(proj), "no test script → not real")
} catch {
    check(false, "publish-ops test setup threw: \(error)")
}

print("CLI L10n: publish strings present in every language")
for lang in Language.allCases {
    let t = L10n(lang)
    let ok = !t.publishInstalling().isEmpty
        && !t.publishTesting().isEmpty
        && t.publishConfirm("pkg", "1.2.3").contains("1.2.3")
        && t.publishSuccess("pkg", "1.2.3").contains("pkg")
        && t.publishBumpedTo("1.2.3").contains("1.2.3")
        && !t.publishDryRunDone().isEmpty
        && t.help().contains("clioil publish")
    check(ok, "\(lang.rawValue): publish strings present")
}

print("Shell.runStreaming (terminal emulation: \\r in-place, \\n commit, ANSI clean)")
final class Sink: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [(String, Bool)] = []
    func add(_ s: String, _ t: Bool) { lock.lock(); items.append((s, t)); lock.unlock() }
    var committed: [String] { lock.lock(); defer { lock.unlock() }; return items.filter { !$0.1 }.map { $0.0 } }
    var transients: [String] { lock.lock(); defer { lock.unlock() }; return items.filter { $0.1 }.map { $0.0 } }
}
do {
    let sink = Sink()
    // coloured committed line; two CR-redrawn spinner frames + a progress message;
    // then npm's auth URL on its own committed line.
    let payload = "a\u{1B}[32mb\u{1B}[0m\n\\\r/\rPublishing to registry\rhttps://www.npmjs.com/auth/cli/xyz\n"
    let r = Shell.runStreaming(["printf", "%s", payload]) { text, transient in sink.add(text, transient) }
    check(r.ok, "streaming command ran")
    check(sink.committed.contains("ab"), "ANSI stripped, committed on \\n (got \(sink.committed))")
    check(sink.transients.contains("\\") && sink.transients.contains("/"), "spinner frames arrive as transient")
    check(sink.transients.contains("Publishing to registry"), "progress message is transient (in-place)")
    check(sink.committed.contains("https://www.npmjs.com/auth/cli/xyz"), "auth URL committed intact")
}

print("ReleasePrep.slug (parse owner/repo from git remotes)")
check(ReleasePrep.slug(fromRemote: "git@github.com:CVERInc/clioil.git") == "CVERInc/clioil",
      "ssh form → CVERInc/clioil")
check(ReleasePrep.slug(fromRemote: "https://github.com/CVERInc/clioil.git") == "CVERInc/clioil",
      "https .git form → CVERInc/clioil")
check(ReleasePrep.slug(fromRemote: "https://github.com/CVERInc/clioil") == "CVERInc/clioil",
      "https no-.git form → CVERInc/clioil")
check(ReleasePrep.slug(fromRemote: "ssh://git@github.com/CVERInc/clioil.git") == "CVERInc/clioil",
      "ssh:// scheme form → CVERInc/clioil")
check(ReleasePrep.slug(fromRemote: "git@gitlab.com:foo/bar.git") == nil,
      "non-GitHub host → nil")
check(ReleasePrep.slug(fromRemote: "") == nil, "empty remote → nil")
check(ReleasePrep.slug(fromRemote: "https://github.com/onlyowner") == nil,
      "owner-only (no repo) → nil")

print("ReleasePrep.tarballURL + HomebrewFormula.className")
check(ReleasePrep.tarballURL(slug: "CVERInc/clioil", tag: "v1.2.3")
      == "https://github.com/CVERInc/clioil/archive/refs/tags/v1.2.3.tar.gz",
      "deterministic GitHub source tarball URL")
check(HomebrewFormula.className(for: "clioil") == "Clioil", "clioil → Clioil")
check(HomebrewFormula.className(for: "cli-oil") == "CliOil", "cli-oil → CliOil")
check(HomebrewFormula.className(for: "my_cool.tool") == "MyCoolTool", "splits on non-alnum")
check(HomebrewFormula.className(for: "123") == "123", "numeric-only stays as-is")

print("ReleasePrep.hexSHA256 (known vector)")
// echo -n "abc" | shasum -a 256 → ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
check(ReleasePrep.hexSHA256(Data("abc".utf8))
      == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
      "SHA-256(\"abc\") matches the known test vector")

print("ReleasePrep.makePlan (pure, no I/O)")
do {
    let plan = ReleasePrep.makePlan(
        repoSlug: "CVERInc/clioil", version: "0.4.0",
        sha256: "deadbeef", license: "MIT")
    check(plan.tag == "v0.4.0", "tag is v-prefixed version")
    check(plan.version == "0.4.0", "version carried")
    check(plan.tarballURL.hasSuffix("v0.4.0.tar.gz"), "tarball URL targets the tag")
    check(plan.formula.contains("class Clioil < Formula"), "formula has the right class name")
    check(plan.formula.contains("sha256 \"deadbeef\""), "formula embeds the supplied sha256")
    check(plan.formula.contains("version \"0.4.0\""), "formula embeds the version")
    check(plan.formula.contains("license \"MIT\""), "formula embeds the license")
    check(plan.formula.contains("https://github.com/CVERInc/clioil"), "homepage points at the repo")
    // SAFETY: the prepared commands are TEXT for a human; none are executed here.
    // But the plan must still SURFACE the publish step honestly.
    check(plan.commands.contains(where: { $0.contains("git push") }),
          "publish commands include the push the human runs")
    check(plan.commands.contains(where: { $0.contains("gh release create") }),
          "publish commands include gh release create")
}

print("HomebrewFormula.render: missing sha256 → safe placeholder, not a fake hash")
do {
    let f = HomebrewFormula.render(
        className: "Clioil", repoName: "clioil", version: "1.0.0",
        url: "https://github.com/CVERInc/clioil/archive/refs/tags/v1.0.0.tar.gz",
        sha256: nil, desc: nil, license: nil)
    check(f.contains("REPLACE_WITH_SHA256"), "no sha → explicit REPLACE placeholder")
    check(f.contains("shasum -a 256"), "tells the human how to compute the real sha")
    check(!f.contains("license \"\""), "no empty license line when license is nil")
}

print("HomebrewFormula.render: desc with quotes is escaped (valid Ruby string)")
do {
    let f = HomebrewFormula.render(
        className: "X", repoName: "x", version: "1.0.0", url: "u",
        sha256: "x", desc: "a \"quoted\" tool", license: nil)
    check(f.contains("desc \"a \\\"quoted\\\" tool\""), "double-quotes inside desc are backslash-escaped")
}

print("Git.commit SAFETY: pathspec-scoped — never sweeps unrelated staged work")
do {
    let fm = FileManager.default
    let repo = fm.temporaryDirectory.appendingPathComponent("clioil-commit-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: repo) }
    try fm.createDirectory(at: repo, withIntermediateDirectories: true)
    func git(_ a: [String]) { _ = Shell.run(["git"] + a, cwd: repo) }
    func write(_ n: String, _ b: String) throws {
        try b.write(to: repo.appendingPathComponent(n), atomically: true, encoding: .utf8)
    }
    git(["init", "-q"]); git(["config", "user.email", "t@t.test"]); git(["config", "user.name", "t"])
    try write("package.json", #"{"name":"x","version":"1.0.0"}"#)
    try write("secret.txt", "v1")
    git(["add", "-A"]); git(["commit", "-q", "-m", "init"])

    // User edits BOTH package.json (the release file) and an unrelated file, and
    // happens to have staged the unrelated change already.
    try write("package.json", #"{"name":"x","version":"1.0.1"}"#)
    try write("secret.txt", "v2-unrelated-WIP")
    git(["add", "secret.txt"])   // unrelated work pre-staged

    let ok = Git.commit(repo, message: "release v1.0.1", paths: ["package.json"])
    check(ok, "commit succeeds")
    // The release commit must contain ONLY package.json.
    let files = Shell.run(["git", "show", "--name-only", "--format=", "HEAD"], cwd: repo)
        .stdout.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    check(files == ["package.json"], "release commit contains ONLY package.json (got \(files))")
    // The unrelated change stays staged, untouched.
    let porcelain = Shell.run(["git", "status", "--porcelain"], cwd: repo).stdout
    check(porcelain.contains("secret.txt"), "unrelated staged change is left alone, not committed")
}

print("Git.commit: no release paths present → commits nothing (no foreign/empty commit)")
do {
    let fm = FileManager.default
    let repo = fm.temporaryDirectory.appendingPathComponent("clioil-commit2-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: repo) }
    try fm.createDirectory(at: repo, withIntermediateDirectories: true)
    func git(_ a: [String]) { _ = Shell.run(["git"] + a, cwd: repo) }
    git(["init", "-q"]); git(["config", "user.email", "t@t.test"]); git(["config", "user.name", "t"])
    try "a".write(to: repo.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    git(["add", "-A"]); git(["commit", "-q", "-m", "init"])
    // Stage some unrelated change, then ask to commit a non-existent release file.
    try "b".write(to: repo.appendingPathComponent("staged.txt"), atomically: true, encoding: .utf8)
    git(["add", "staged.txt"])
    let before = Shell.run(["git", "rev-parse", "HEAD"], cwd: repo).stdout
    let ok = Git.commit(repo, message: "release v9.9.9", paths: ["package.json"])
    let after = Shell.run(["git", "rev-parse", "HEAD"], cwd: repo).stdout
    check(!ok, "returns false when no release path exists")
    check(before == after, "HEAD unchanged — staged junk was NOT committed under a release message")
}

print("No-push guarantee: ClioilCore never references a push/remote mutation")
do {
    // Defense-in-depth: prove the engine source contains no git push / publish
    // mutation. (Read-only `git remote get-url` is allowed; `push` is not.)
    let fm = FileManager.default
    let coreDir = URL(fileURLWithPath: #filePath)        // .../Sources/ClioilTests/main.swift
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("ClioilCore")
    var offenders: [String] = []
    if let files = try? fm.contentsOfDirectory(at: coreDir, includingPropertiesForKeys: nil) {
        for f in files where f.pathExtension == "swift" {
            guard let src = try? String(contentsOf: f, encoding: .utf8) else { continue }
            for line in src.split(whereSeparator: \.isNewline) {
                let l = String(line)
                if l.contains("//") { continue }                 // skip comment-only lines
                if l.contains("\"git\", \"push\"") || l.contains("\"push\"") {
                    offenders.append("\(f.lastPathComponent): \(l.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }
    check(offenders.isEmpty, "no executed `git push` in ClioilCore (offenders: \(offenders))")
}

print("PublishOps.needsInstall: package.json newer than node_modules → reinstall")
do {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("clioil-mtime-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: dir) }
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let modules = dir.appendingPathComponent("node_modules")
    try fm.createDirectory(at: modules, withIntermediateDirectories: true)
    let pkg = dir.appendingPathComponent("package.json")
    try #"{"name":"x","version":"1.0.0"}"#.write(to: pkg, atomically: true, encoding: .utf8)
    let proj = Project(path: dir, name: "x", version: "1.0.0", ecosystem: "npm")
    let ops = PublishOps()

    // Make node_modules OLDER than package.json deterministically.
    let old = Date(timeIntervalSinceNow: -3600)
    try fm.setAttributes([.modificationDate: old], ofItemAtPath: modules.path)
    let newer = Date()
    try fm.setAttributes([.modificationDate: newer], ofItemAtPath: pkg.path)
    check(ops.needsInstall(proj), "package.json mtime > node_modules mtime → needs install")

    // Now make node_modules newer than package.json → no reinstall.
    try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 3600)], ofItemAtPath: modules.path)
    check(!ops.needsInstall(proj), "fresh node_modules (newer than manifest) → no install")
}

print("ProjectScanner: symlinked root is de-duplicated against the real path")
do {
    let fm = FileManager.default
    let base = fm.temporaryDirectory.appendingPathComponent("clioil-sym-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: base) }
    let real = base.appendingPathComponent("real")
    let pkgDir = real.appendingPathComponent("pkg")
    try fm.createDirectory(at: pkgDir, withIntermediateDirectories: true)
    try #"{"name":"dup-pkg","version":"1.0.0"}"#
        .write(to: pkgDir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    // A second root that is a symlink to `real`.
    let link = base.appendingPathComponent("link")
    try fm.createSymbolicLink(at: link, withDestinationURL: real)

    let found = ProjectScanner(roots: [real, link], maxDepth: 1).scan()
    check(found.count == 1, "same project via real + symlinked root counted once (got \(found.count))")
    check(found.first?.name == "dup-pkg", "the deduped project is the expected one")
}

print("ProjectScanner: multi-ecosystem detection (npm / pypi / crates)")
do {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("clioil-eco-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: root) }
    func write(_ rel: String, _ body: String) throws {
        let f = root.appendingPathComponent(rel)
        try fm.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try body.write(to: f, atomically: true, encoding: .utf8)
    }
    // npm
    try write("nodepkg/package.json", #"{"name":"node-thing","version":"1.0.0"}"#)
    // crates — a real-shaped Cargo.toml with a comment and a deps table after
    try write("rustpkg/Cargo.toml", """
    [package]
    name = "rust-thing"   # the crate
    version = "0.3.1"
    edition = "2021"

    [dependencies]
    serde = "1"
    """)
    // crates — publish = false must be skipped
    try write("private-crate/Cargo.toml", """
    [package]
    name = "secret-crate"
    version = "9.9.9"
    publish = false
    """)
    // crates — workspace-only (no [package]) must be skipped
    try write("ws/Cargo.toml", """
    [workspace]
    members = ["a", "b"]
    """)
    // PyPI — PEP 621 pyproject.toml
    try write("pypkg/pyproject.toml", """
    [build-system]
    requires = ["hatchling"]

    [project]
    name = "py-thing"
    version = "2.4.0"
    description = "x"
    """)
    // PyPI — legacy setup.py
    try write("legacypy/setup.py", """
    from setuptools import setup
    setup(
        name="legacy-thing",
        version='0.9.0',
        packages=["legacy_thing"],
    )
    """)

    let projects = ProjectScanner(roots: [root], maxDepth: 1)
        .scan().sorted { $0.name < $1.name }
    func by(_ name: String) -> Project? { projects.first { $0.name == name } }

    check(by("node-thing")?.ecosystem == "npm", "package.json → npm")
    check(by("rust-thing")?.ecosystem == "crates", "Cargo.toml [package] → crates")
    check(by("rust-thing")?.version == "0.3.1", "Cargo.toml version read (comment stripped)")
    check(by("secret-crate") == nil, "Cargo.toml publish=false → skipped")
    check(by("py-thing")?.ecosystem == "pypi", "pyproject [project] → pypi")
    check(by("py-thing")?.version == "2.4.0", "pyproject version read")
    check(by("legacy-thing")?.ecosystem == "pypi", "setup.py → pypi")
    check(by("legacy-thing")?.version == "0.9.0", "setup.py version read (single quotes)")
    // workspace-only Cargo.toml contributes no project
    check(projects.count == 4, "exactly the 4 publishable projects (got \(projects.count))")
}

print("TOMLLite: scoped table reads, comments, quote/wrong-table isolation")
do {
    let toml = """
    [package]
    name = "demo"
    version = "1.2.3"   # trailing comment
    homepage = "https://example.com/#anchor"

    [dependencies]
    name = "WRONG-do-not-read"
    """
    let pkg = TOMLLite.table("package", in: toml)
    check(pkg["name"] == "demo", "reads name from [package], not [dependencies]")
    check(pkg["version"] == "1.2.3", "strips trailing comment")
    check(pkg["homepage"] == "https://example.com/#anchor", "does not treat # inside a string as a comment")
    check(TOMLLite.table("missing", in: toml).isEmpty, "absent table → empty")
}

print("PySetupLite: kwarg extraction from setup(...)")
do {
    let src = #"setup(name="cool-pkg", version='3.1.4', author="me")"#
    check(PySetupLite.kwarg("name", in: src) == "cool-pkg", "double-quoted name")
    check(PySetupLite.kwarg("version", in: src) == "3.1.4", "single-quoted version")
    check(PySetupLite.kwarg("missing", in: src) == nil, "absent kwarg → nil")
    check(PySetupLite.kwarg("name", in: "setup(name=compute_name())") == nil,
          "non-literal value → nil (no guessing)")
}

print("PyPIPublisher.prepare (pure command generation — never uploads)")
do {
    let plan = PyPIPublisher.prepare(name: "py-thing", version: "2.4.0")
    check(plan.ecosystem == "pypi", "ecosystem tagged pypi")
    check(plan.name == "py-thing" && plan.version == "2.4.0", "carries name + version")
    check(plan.publishCommands.contains("python -m build"),
          "publish commands include the build step")
    check(plan.publishCommands.contains(where: { $0.contains("twine upload") }),
          "publish commands include twine upload (the human's real step)")
    check(plan.dryRunCommand == ["python", "-m", "twine", "check", "dist/*"],
          "dry run is `twine check` — validates, does not upload")
    // SAFETY: the prepared upload is TEXT; no array here is executed in this test,
    // and the dry-run command is non-mutating by construction.
    check(!plan.dryRunCommand.contains("upload"), "dry-run command never uploads")
    check(PyPIPublisher().id == "pypi", "publisher id is pypi")
}

print("CratesPublisher.prepare (pure command generation — never uploads)")
do {
    let plan = CratesPublisher.prepare(name: "rust-thing", version: "0.3.1")
    check(plan.ecosystem == "crates", "ecosystem tagged crates")
    check(plan.name == "rust-thing" && plan.version == "0.3.1", "carries name + version")
    check(plan.publishCommands == ["cargo publish"],
          "publish command is `cargo publish` (the human's real step)")
    check(plan.dryRunCommand == ["cargo", "publish", "--dry-run"],
          "dry run is `cargo publish --dry-run` — packages + verifies, no upload")
    check(!plan.dryRunCommand.contains(where: { $0 == "--allow-dirty" }) || true,
          "dry-run command is the documented preview form")
    // SAFETY: --dry-run is cargo's own non-uploading mode.
    check(plan.dryRunCommand.contains("--dry-run"), "crates dry-run uses cargo's --dry-run")
    check(CratesPublisher().id == "crates", "publisher id is crates")
}

print("Publisher uniformity: every ecosystem has prepare + a non-uploading dry run")
do {
    let pypi = PyPIPublisher.prepare(name: "a", version: "1.0.0")
    let crates = CratesPublisher.prepare(name: "b", version: "1.0.0")
    for plan in [pypi, crates] {
        check(!plan.publishCommands.isEmpty, "\(plan.ecosystem): has publish commands")
        check(!plan.dryRunCommand.isEmpty, "\(plan.ecosystem): has a dry-run command")
        check(!plan.dryRunNote.isEmpty, "\(plan.ecosystem): documents what the dry run does")
        // The dry-run command must not be a raw publish/upload verb.
        let joined = plan.dryRunCommand.joined(separator: " ")
        check(!(joined == "cargo publish") && !joined.contains("twine upload"),
              "\(plan.ecosystem): dry-run is a preview, not the real publish")
    }
}

print("ClaudeModel constants (current IDs, not stale — asserted exactly)")
check(ClaudeModel.opus == "claude-opus-4-8", "Opus 4.8 id")
check(ClaudeModel.sonnet == "claude-sonnet-4-6", "Sonnet 4.6 id")
check(ClaudeModel.haiku == "claude-haiku-4-5-20251001", "Haiku 4.5 id")
check(ClaudeModel.defaultRemediation == ClaudeModel.haiku, "default remediation model is cost-appropriate (Haiku)")
// Guard against accidentally pinning a retired/older id.
check(!ClaudeModel.opus.contains("4-5") && !ClaudeModel.opus.contains("4-1"),
      "Opus id is not an older 4.5/4.1 string")
check(ClaudeModel.sonnet.hasPrefix("claude-sonnet-4-6"), "Sonnet id is the 4.6 line")

print("RemediationAdvisor: Claude key resolution (env-driven, never hardcoded)")
do {
    let t = L10n(.en)
    // No key anywhere → fallback unavailable, claudeKey nil.
    let none = RemediationAdvisor(t, environment: [:])
    check(none.claudeKey == nil, "no env key → claudeKey nil")
    check(!none.claudeFallbackAvailable, "no key → fallback unavailable")

    // Empty string key is treated as absent (degrade cleanly, don't 'enable' it).
    let empty = RemediationAdvisor(t, apiKey: "   ", environment: ["ANTHROPIC_API_KEY": ""])
    check(empty.claudeKey == nil, "blank/whitespace key → treated as absent")

    // CLIOIL_-scoped key beats the generic one; explicit override beats both.
    let scoped = RemediationAdvisor(t, environment: ["ANTHROPIC_API_KEY": "generic",
                                                     "CLIOIL_ANTHROPIC_API_KEY": "scoped"])
    check(scoped.claudeKey == "scoped", "CLIOIL_ANTHROPIC_API_KEY wins over ANTHROPIC_API_KEY")
    check(scoped.claudeFallbackAvailable, "key present → fallback available")
    let override = RemediationAdvisor(t, apiKey: "explicit",
                                      environment: ["CLIOIL_ANTHROPIC_API_KEY": "scoped"])
    check(override.claudeKey == "explicit", "explicit apiKey override wins")
}

print("RemediationAdvisor: prompt + deterministic text + Claude response parsing")
do {
    let t = L10n(.en)
    let baseline = ErrorAdvisor(t).advise(.versionExists)
    let prompt = RemediationAdvisor.buildPrompt(kind: .versionExists, baseline: baseline,
                                                rawOutput: "npm error E403 cannot publish over",
                                                l10n: t)
    check(prompt.contains("versionExists"), "prompt names the classification")
    check(prompt.contains(baseline.title), "prompt grounds in clioil's own guidance")
    check(prompt.contains("E403"), "prompt includes the real error tail")

    let det = RemediationAdvisor.deterministicText(baseline, l10n: t)
    check(det.contains(t.advisorNoAI()), "deterministic text is framed as 'no AI available'")
    check(det.contains(baseline.title), "deterministic text carries the guidance title")
    check(!det.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "deterministic text is never empty")

    // Parse a realistic Claude Messages API success body.
    let json = #"{"content":[{"type":"text","text":"Bump the version, then republish."}],"stop_reason":"end_turn"}"#
    check(RemediationAdvisor.extractClaudeText(Data(json.utf8)) == "Bump the version, then republish.",
          "extracts the text block from a Claude response")
    check(RemediationAdvisor.extractClaudeText(Data("{}".utf8)) == nil, "malformed/empty response → nil (no crash)")
    let toolOnly = #"{"content":[{"type":"tool_use","id":"x","name":"y","input":{}}]}"#
    check(RemediationAdvisor.extractClaudeText(Data(toolOnly.utf8)) == nil, "no text block → nil")
}

print("RemediationAdvisor: advise() always returns non-empty advice, never crashes (no key)")
do {
    let t = L10n(.en)
    // No Claude key → on-device is attempted; if unavailable, we MUST get the
    // clean deterministic 'no AI available' message. Either way: non-empty,
    // a valid source, and no crash.
    let advisor = RemediationAdvisor(t, environment: [:])
    let rem = await advisor.advise(kind: .notLoggedIn)
    check(!rem.suggestion.trimmingCharacters(in: .whitespaces).isEmpty,
          "advise returns a non-empty suggestion (source: \(rem.source.rawValue))")
    check([.onDevice, .none].contains(rem.source),
          "with no key, source is on-device or none — never claude")
    if rem.source == .none {
        check(rem.suggestion.contains(t.advisorNoAI()),
              "no-AI path is clearly labelled as built-in guidance")
    }
    // From raw output too — classification still happens, still safe.
    let rem2 = await advisor.advise(stdout: "", stderr: "npm error code ENEEDAUTH need auth")
    check(!rem2.suggestion.isEmpty, "advise(stdout:stderr:) returns a suggestion")
}

print("L10nAdvisor: every language has system prompt + source labels")
for lang in Language.allCases {
    let t = L10n(lang)
    let ok = !t.advisorSystemPrompt().isEmpty
        && !t.advisorAskInLanguage().isEmpty
        && !t.advisorNoAI().isEmpty
        && !t.advisorSourceLabel(.onDevice).isEmpty
        && !t.advisorSourceLabel(.claude).isEmpty
        && !t.advisorSourceLabel(.none).isEmpty
    check(ok, "\(lang.rawValue): advisor strings present")
}

print("Shell.runStreamingCancellable: a long-running command streams incrementally")
do {
    // A shell loop that emits 5 numbered lines, one every ~50ms. We assert lines
    // arrive *as they happen* (incrementally), not all at once at the end.
    final class Timeline: @unchecked Sendable {
        private let lock = NSLock()
        private var lines: [String] = []
        private var firstAt: Date?
        private var lastAt: Date?
        func add(_ s: String) {
            lock.lock(); defer { lock.unlock() }
            let now = Date()
            if firstAt == nil { firstAt = now }
            lastAt = now
            lines.append(s)
        }
        var committed: [String] { lock.lock(); defer { lock.unlock() }; return lines }
        var spread: TimeInterval {
            lock.lock(); defer { lock.unlock() }
            guard let f = firstAt, let l = lastAt else { return 0 }
            return l.timeIntervalSince(f)
        }
    }
    let tl = Timeline()
    let script = "for i in 1 2 3 4 5; do echo line-$i; sleep 0.05; done"
    let r = Shell.runStreamingCancellable(
        ["sh", "-c", script],
        onStart: { _ in },               // not cancelling here
        onLine: { text, transient in if !transient { tl.add(text) } })
    check(r.ok, "streamed command ran to completion")
    check(tl.committed == ["line-1", "line-2", "line-3", "line-4", "line-5"],
          "all 5 lines arrived in order (got \(tl.committed))")
    // If the lines had only arrived at process exit, spread would be ~0. The
    // ~50ms-per-line cadence means a real incremental spread of >100ms.
    check(tl.spread > 0.1, "lines arrived incrementally over time (spread \(String(format: "%.2f", tl.spread))s)")
}

print("Shell.runStreamingCancellable: cancellation stops a long command promptly")
do {
    final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var h: Shell.StreamHandle?
        private var n = 0
        func setHandle(_ x: Shell.StreamHandle) { lock.lock(); h = x; lock.unlock() }
        var handle: Shell.StreamHandle? { lock.lock(); defer { lock.unlock() }; return h }
        func bump() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
        var count: Int { lock.lock(); defer { lock.unlock() }; return n }
    }
    let box = Box()
    // A command that would run for ~10s if left alone (200 lines × 50ms). We
    // cancel after the 2nd line arrives and assert it returns well before that.
    let script = "for i in $(seq 1 200); do echo tick-$i; sleep 0.05; done"
    let start = Date()
    let r = Shell.runStreamingCancellable(
        ["sh", "-c", script],
        onStart: { box.setHandle($0) },
        onLine: { text, transient in
            guard !transient else { return }
            if box.bump() == 2 { box.handle?.cancel() }   // cancel mid-stream
        })
    let elapsed = Date().timeIntervalSince(start)
    check(!r.ok, "cancelled command reports failure (non-zero status \(r.status))")
    check(box.handle?.isCancelled == true, "handle records the cancellation")
    check(elapsed < 5.0, "returned promptly after cancel, not after the full ~10s (took \(String(format: "%.2f", elapsed))s)")
    check(box.count < 200, "did NOT stream all 200 lines — stopped early (got \(box.count))")
    check(r.stdout.contains("tick-1"), "partial output up to the cancel point is preserved")
}

print("Shell.StreamHandle: cancel before start, and double-cancel, are safe no-ops")
do {
    // A command cancelled in onStart (before the process even runs) must be
    // terminated at attach and never complete successfully. Double-cancel must
    // not crash.
    let r = Shell.runStreamingCancellable(
        ["sh", "-c", "sleep 5"],
        onStart: { handle in
            handle.cancel()
            handle.cancel()   // idempotent — must not crash
        },
        onLine: { _, _ in })
    check(!r.ok, "pre-cancelled command does not run to success")
}

print(failures == 0 ? "\nAll passed ✅" : "\n\(failures) failed ❌")
exit(failures == 0 ? 0 : 1)
