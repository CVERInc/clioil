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

func cmdList() {
    let scanner = ProjectScanner(roots: defaultRoots, maxDepth: 1)
    let projects = scanner.scan().sorted { $0.name.lowercased() < $1.name.lowercased() }

    guard !projects.isEmpty else {
        print("找不到可發布的專案。掃描位置：")
        for r in defaultRoots { print("  • \(r.path)") }
        exit(1)
    }

    print("可發布的專案（\(projects.count)）：")
    print(String(repeating: "─", count: 48))
    for (i, p) in projects.enumerated() {
        let n = pad("\(i + 1))", 4)
        print("  \(n) \(pad(p.name, 22)) v\(pad(p.version, 10)) \(p.displayPath)")
    }
}

func cmdHelp() {
    print("""
    clioil — 讓「把程式碼推到各平台」變成一件簡單的事（早期骨架）

    用法：
      clioil list     掃描並列出可發布的專案
      clioil help     顯示這個說明

    現況：list 已可用（純 Swift 掃描，不需要 node）。
    發布流程目前仍由桌面的「發布 npm 專案.command」負責，
    待引擎補上確認/驗證層後再內建。詳見 README 的 Roadmap。
    """)
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "list" {
case "list":          cmdList()
case "help", "-h", "--help": cmdHelp()
case let other:
    print("未知指令：\(other)\n")
    cmdHelp()
    exit(1)
}
