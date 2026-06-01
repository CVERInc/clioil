import Foundation
import ClioilCore

// clioil — early CLI shell over ClioilCore.
// First vertical slice: discover publishable projects (no side effects).

let home = FileManager.default.homeDirectoryForCurrentUser
let defaultRoots = [
    home,
    home.appendingPathComponent("Desktop/GitHub"),
]

func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

/// Pull `--lang=xx` / `--lang xx` / `-l xx` out of the args, return the rest.
func parseArgs(_ argv: [String]) -> (override: String?, positional: [String]) {
    var override: String?
    var positional: [String] = []
    var i = 1
    while i < argv.count {
        let a = argv[i]
        if a == "--lang" || a == "-l" {
            i += 1
            if i < argv.count { override = argv[i] }
        } else if a.hasPrefix("--lang=") {
            override = String(a.dropFirst("--lang=".count))
        } else {
            positional.append(a)
        }
        i += 1
    }
    return (override, positional)
}

func cmdList(_ t: L10n) {
    let projects = ProjectScanner(roots: defaultRoots, maxDepth: 1)
        .scan()
        .sorted { $0.name.lowercased() < $1.name.lowercased() }

    guard !projects.isEmpty else {
        print(t.noProjectsFound())
        for r in defaultRoots { print("  • \(r.path)") }
        exit(1)
    }

    print(t.projectsHeader(projects.count))
    print(String(repeating: "─", count: 48))
    for (i, p) in projects.enumerated() {
        let n = pad("\(i + 1))", 4)
        print("  \(n) \(pad(p.name, 22)) v\(pad(p.version, 10)) \(p.displayPath)")
    }
}

let (override, positional) = parseArgs(CommandLine.arguments)
let t = L10n(Language.detect(override: override))

switch positional.first ?? "list" {
case "list":
    cmdList(t)
case "help", "-h", "--help":
    print(t.help())
case let other:
    print(t.unknownCommand(other))
    print("")
    print(t.help())
    exit(1)
}
