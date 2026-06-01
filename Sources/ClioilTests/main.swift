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
check(Language.parse("zh-Hant-TW") == .zhHant, "zh-Hant-TW → zhHant")
check(Language.parse("zh_TW.UTF-8") == .zhHant, "zh_TW.UTF-8 → zhHant")
check(Language.parse("zh_CN") == .zhHant, "any Chinese → zhHant (no simplified, by design)")
check(Language.parse("es_ES") == .es, "es_ES → es")
check(Language.parse("ja") == .ja, "ja → ja")
check(Language.parse("ko_KR") == .ko, "ko_KR → ko")
check(Language.parse("fr-FR") == .fr, "fr-FR → fr")
check(Language.parse("de") == .de, "de → de")
check(Language.parse("en_US.UTF-8") == .en, "en_US.UTF-8 → en")
check(Language.parse("xx") == nil, "unknown → nil")

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

print(failures == 0 ? "\nAll passed ✅" : "\n\(failures) failed ❌")
exit(failures == 0 ? 0 : 1)
