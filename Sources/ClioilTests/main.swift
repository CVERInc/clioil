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

print(failures == 0 ? "\nAll passed ✅" : "\n\(failures) failed ❌")
exit(failures == 0 ? 0 : 1)
