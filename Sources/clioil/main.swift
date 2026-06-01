import Foundation
import ClioilCore

// clioil — CLI shell over ClioilCore.
//   clioil list                 list publishable projects
//   clioil status [project]     read-only release readiness report
//   clioil help | --version
// Global flags: --lang=<code>, --json

let home = FileManager.default.homeDirectoryForCurrentUser
let defaultRoots = [home, home.appendingPathComponent("Desktop/GitHub")]

// MARK: - arg parsing

struct CLIOptions {
    var langOverride: String?
    var json = false
    var showVersion = false
    var positional: [String] = []
}

func parse(_ argv: [String]) -> CLIOptions {
    var o = CLIOptions()
    var i = 1
    while i < argv.count {
        let a = argv[i]
        switch true {
        case a == "--lang" || a == "-l":
            i += 1
            if i < argv.count { o.langOverride = argv[i] }
        case a.hasPrefix("--lang="):
            o.langOverride = String(a.dropFirst("--lang=".count))
        case a == "--json":
            o.json = true
        case a == "--version" || a == "-V":
            o.showVersion = true
        default:
            o.positional.append(a)
        }
        i += 1
    }
    return o
}

// MARK: - helpers

func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

func printJSON<T: Encodable>(_ value: T) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    if let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) {
        print(s)
    }
}

func allProjects() -> [Project] {
    ProjectScanner(roots: defaultRoots, maxDepth: 1)
        .scan()
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
}

/// Resolve a project from an optional name selector. Prints a helpful message
/// and exits when the selector is missing/ambiguous.
func resolveProject(_ selector: String?, _ t: L10n) -> Project {
    let projects = allProjects()
    if projects.isEmpty {
        FileHandle.standardError.write(Data((t.noProjectsFound() + "\n").utf8))
        exit(1)
    }
    guard let selector else {
        if projects.count == 1 { return projects[0] }
        printPickOne(projects)
        exit(1)
    }
    let needle = selector.lowercased()
    let exact = projects.filter { $0.name.lowercased() == needle }
    let matches = exact.isEmpty ? projects.filter { $0.name.lowercased().contains(needle) } : exact
    switch matches.count {
    case 1: return matches[0]
    case 0:
        FileHandle.standardError.write(Data("✗ \(selector) — \(t.unknownCommand(selector))\n".utf8))
        printPickOne(projects)
        exit(1)
    default:
        printPickOne(matches)
        exit(1)
    }
}

func printPickOne(_ projects: [Project]) {
    for p in projects { print("  • \(p.name)  (\(p.displayPath))") }
}

// MARK: - commands

func cmdList(_ t: L10n, json: Bool) {
    let projects = allProjects()
    if json { printJSON(projects); return }
    guard !projects.isEmpty else {
        print(t.noProjectsFound())
        for r in defaultRoots { print("  • \(r.path)") }
        exit(1)
    }
    print(t.projectsHeader(projects.count))
    print(String(repeating: "─", count: 48))
    for (i, p) in projects.enumerated() {
        print("  \(pad("\(i + 1))", 4)) \(pad(p.name, 22)) v\(pad(p.version, 10)) \(p.displayPath)")
    }
}

func cmdStatus(_ t: L10n, json: Bool, selector: String?) {
    let project = resolveProject(selector, t)
    let s = StatusService().status(of: project)
    if json { printJSON(s); return }

    print("\(project.name)   v\(project.version)   \(project.displayPath)")
    print(String(repeating: "─", count: 48))
    print("  \(t.statusOnNpm()): \(s.registryLatest ?? t.statusUnpublished())")
    print("  " + (s.currentIsPublished
        ? t.statusAlreadyPublished(project.version)
        : t.statusReadyToPublish(project.version)))

    if !s.isGitRepo {
        print("  \(t.statusNotGitRepo())")
        return
    }
    print("  " + (s.gitDirty ? "⚠ " + t.statusGitDirty() : t.statusGitClean()))
    if let tag = s.lastTag {
        if s.changesSinceTag.isEmpty {
            print("  \(t.statusNoChangesSince(tag))")
        } else {
            print("  \(t.statusChangesSince(tag, s.changesSinceTag.count))")
            for c in s.changesSinceTag.prefix(20) { print("    • \(c)") }
            if s.changesSinceTag.count > 20 { print("    …") }
        }
    } else {
        print("  \(t.statusNoTag())")
    }
}

// MARK: - dispatch

let opts = parse(CommandLine.arguments)
let t = L10n(Language.detect(override: opts.langOverride))

if opts.showVersion {
    print("clioil \(Clioil.version)")
    exit(0)
}

switch opts.positional.first ?? "list" {
case "list":
    cmdList(t, json: opts.json)
case "status":
    cmdStatus(t, json: opts.json, selector: opts.positional.count > 1 ? opts.positional[1] : nil)
case "help", "-h", "--help":
    print(t.help())
case let other:
    print(t.unknownCommand(other))
    print("")
    print(t.help())
    exit(1)
}
