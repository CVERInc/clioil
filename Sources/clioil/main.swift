import Foundation
import ClioilCore

/// Tiny thread-safe holder to hand a Sendable result back across the Task →
/// semaphore bridge without tripping the concurrency checker.
final class RemediationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Remediation?
    func set(_ r: Remediation) { lock.lock(); stored = r; lock.unlock() }
    var value: Remediation? { lock.lock(); defer { lock.unlock() }; return stored }
}

// clioil — CLI shell over ClioilCore.
//   clioil list                  list publishable projects
//   clioil status  [project]     read-only release-readiness report
//   clioil publish [project]     guided publish (install → test → preview → publish)
//   clioil release [project]     PREPARE a GitHub Release + Homebrew formula
//                                (prints artifacts/commands; never publishes)
//   clioil help | --version
// Global flags: --lang=<code>, --json
// publish flags: --dry-run, --bump <patch|minor|major>, --no-test, --no-install, --yes
// release flags: --slug <owner/repo> (override remote), --formula-out <path> (write formula)

let home = FileManager.default.homeDirectoryForCurrentUser
let defaultRoots = [home, home.appendingPathComponent("Desktop/GitHub")]

// MARK: - arg parsing

struct CLIOptions {
    var langOverride: String?
    var json = false
    var showVersion = false
    var dryRun = false
    var noTest = false
    var noInstall = false
    var yes = false
    var ai = false
    var bump: Bump?
    var slug: String?
    var formulaOut: String?
    var positional: [String] = []
}

func parse(_ argv: [String]) -> CLIOptions {
    var o = CLIOptions()
    var i = 1
    while i < argv.count {
        let a = argv[i]
        switch true {
        case a == "--lang" || a == "-l":
            i += 1; if i < argv.count { o.langOverride = argv[i] }
        case a.hasPrefix("--lang="):
            o.langOverride = String(a.dropFirst("--lang=".count))
        case a == "--bump":
            i += 1; if i < argv.count { o.bump = Bump(rawValue: argv[i]) }
        case a.hasPrefix("--bump="):
            o.bump = Bump(rawValue: String(a.dropFirst("--bump=".count)))
        case a == "--slug":
            i += 1; if i < argv.count { o.slug = argv[i] }
        case a.hasPrefix("--slug="):
            o.slug = String(a.dropFirst("--slug=".count))
        case a == "--formula-out":
            i += 1; if i < argv.count { o.formulaOut = argv[i] }
        case a.hasPrefix("--formula-out="):
            o.formulaOut = String(a.dropFirst("--formula-out=".count))
        case a == "--json":      o.json = true
        case a == "--dry-run":   o.dryRun = true
        case a == "--no-test":   o.noTest = true
        case a == "--no-install": o.noInstall = true
        case a == "--yes" || a == "-y": o.yes = true
        case a == "--ai": o.ai = true
        case a == "--version" || a == "-V": o.showVersion = true
        default: o.positional.append(a)
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
    if let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) { print(s) }
}

func eprint(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

func allProjects() -> [Project] {
    ProjectScanner(roots: defaultRoots, maxDepth: 1)
        .scan()
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
}

/// Resolve a project from a name *or* path fragment. Exits with a helpful list
/// when missing or ambiguous — important for publish, where the wrong target is
/// dangerous (e.g. two `bleedblend` checkouts).
func resolveProject(_ selector: String?, _ t: L10n) -> Project {
    let projects = allProjects()
    if projects.isEmpty { eprint(t.noProjectsFound()); exit(1) }
    guard let selector else {
        if projects.count == 1 { return projects[0] }
        printPickOne(projects); exit(1)
    }
    let needle = selector.lowercased()
    func broad(_ p: Project) -> Bool {
        p.name.lowercased().contains(needle) || p.path.path.lowercased().contains(needle)
    }
    var matches = projects.filter(broad)
    if matches.count > 1 {
        let exact = projects.filter { $0.name.lowercased() == needle || $0.path.path.lowercased() == needle }
        if exact.count == 1 { matches = exact }
    }
    switch matches.count {
    case 1: return matches[0]
    case 0: eprint("✗ \(selector)"); printPickOne(projects); exit(1)
    default: printPickOne(matches); exit(1)
    }
}

func printPickOne(_ projects: [Project]) {
    for p in projects { print("  • \(p.name)  (\(p.displayPath))") }
}

/// Run the AI remediation advisor (opt-in via `--ai`) and print its hint. The
/// advisor itself degrades gracefully (on-device → Claude if a key is present →
/// built-in guidance), so this always prints *something* useful and never
/// crashes. Bridged to the sync CLI with a semaphore — safe here because the CLI
/// runner is not main-actor-bound.
func printAIHint(_ t: L10n, stdout: String, stderr: String) {
    let advisor = RemediationAdvisor(t)
    let sem = DispatchSemaphore(value: 0)
    let box = RemediationBox()
    Task {
        let result = await advisor.advise(stdout: stdout, stderr: stderr)
        box.set(result)
        sem.signal()
    }
    sem.wait()
    guard let r = box.value else { return }
    print("  💡 \(t.advisorHintHeader()) [\(t.advisorSourceLabel(r.source))]")
    for line in r.suggestion.split(whereSeparator: \.isNewline) {
        print("     \(line)")
    }
}

// MARK: - commands

func cmdList(_ t: L10n, json: Bool) {
    let projects = allProjects()
    if json { printJSON(projects); return }
    guard !projects.isEmpty else {
        print(t.noProjectsFound()); for r in defaultRoots { print("  • \(r.path)") }; exit(1)
    }
    print(t.projectsHeader(projects.count))
    print(String(repeating: "─", count: 48))
    for (i, p) in projects.enumerated() {
        print("  \(pad("\(i + 1))", 4)) \(pad(p.name, 22)) v\(pad(p.version, 10)) \(p.displayPath)")
    }
}

func cmdStatus(_ t: L10n, json: Bool, selector: String?) {
    let project = resolveProject(selector, t)
    let s = StatusService(publisher: .forEcosystem(project.ecosystem)).status(of: project)
    if json { printJSON(s); return }

    print("\(project.name)   v\(project.version)   \(project.displayPath)")
    print(String(repeating: "─", count: 48))
    print("  \(t.statusOnNpm()): \(s.registryLatest ?? t.statusUnpublished())")
    print("  " + (s.currentIsPublished
        ? t.statusAlreadyPublished(project.version)
        : t.statusReadyToPublish(project.version)))
    if !s.isGitRepo { print("  \(t.statusNotGitRepo())"); return }
    print("  " + (s.gitDirty ? "⚠ " + t.statusGitDirty() : t.statusGitClean()))
    if let tag = s.lastTag {
        if s.changesSinceTag.isEmpty {
            print("  \(t.statusNoChangesSince(tag))")
        } else {
            print("  \(t.statusChangesSince(tag, s.changesSinceTag.count))")
            for c in s.changesSinceTag.prefix(20) { print("    • \(c)") }
            if s.changesSinceTag.count > 20 { print("    …") }
        }
    } else { print("  \(t.statusNoTag())") }
}

func cmdPublish(_ t: L10n, opts: CLIOptions, selector: String?) {
    let project = resolveProject(selector, t)
    let ops = PublishOps()
    let advisor = ErrorAdvisor(t)
    let sep = String(repeating: "─", count: 48)
    var version = project.version

    func showAdvice(_ kind: PublishErrorKind) {
        let a = advisor.advise(kind)
        print("  ✗ \(a.title)")
        for s in a.steps { print("    → \(s)") }
    }

    print("\(project.name)   v\(version)   \(project.displayPath)")
    print(sep)

    // 1. bump (optional)
    if let level = opts.bump {
        guard let newVer = ops.bump(project, level) else {
            eprint("✗ npm version \(level.rawValue)"); exit(1)
        }
        version = newVer
        print("  \(t.publishBumpedTo(version))")
    }

    // 2. pre-flight: refuse to even try if this version is already published
    if NpmPublisher().versionExists(version, of: project) {
        print("  ⚠ \(t.publishAlreadyBlocked(version))")
        showAdvice(.versionExists)
        exit(1)
    }

    // 3. install if needed
    if !opts.noInstall && ops.needsInstall(project) {
        print("  \(t.publishInstalling())")
        _ = ops.runInstall(project)
        print(sep)
    }

    // 4. test
    if !opts.noTest && ops.hasRealTestScript(project) {
        print("  \(t.publishTesting())")
        if ops.runTest(project) == 0 {
            print("  \(t.publishTestPassed())")
        } else {
            print("  \(t.publishTestFailed())")
            if !opts.yes {
                print("  (yes / Enter→cancel)")
                let line = readLine()?.trimmingCharacters(in: .whitespaces).lowercased()
                if line != "yes" && line != "y" { print("  \(t.publishAborted())"); exit(0) }
            }
        }
        print(sep)
    }

    // 5. pack preview
    print("  \(t.publishPackPreview())")
    for line in ops.packPreview(project).prefix(40) { print("    \(line)") }
    print(sep)

    // 6. dry run stops here — fully safe
    if opts.dryRun { print("  \(t.publishDryRunDone())"); return }

    // 7. confirm + real publish (interactive browser auth)
    if !opts.yes {
        print("  \(t.publishConfirm(project.name, version))")
        if readLine() == nil { print("  \(t.publishAborted())"); exit(0) }
    }
    print(sep)
    let code = ops.publish(project)
    print(sep)
    guard code == 0 else {
        // Diagnose without captured output: check auth, then version-exists.
        let kind: PublishErrorKind =
            !ops.isLoggedIn(project) ? .notLoggedIn
            : NpmPublisher().versionExists(version, of: project) ? .versionExists
            : .unknown
        showAdvice(kind)
        // Opt-in AI remediation hint (on-device → Claude fallback → built-in).
        if opts.ai { printAIHint(t, stdout: "", stderr: kind.rawValue) }
        exit(1)
    }

    print("  \(t.publishSuccess(project.name, version))")

    // 8. record the bump in git (only if we bumped and it's a repo)
    if opts.bump != nil, Git.isRepo(project.path) {
        if Git.commit(project.path, message: "release v\(version)",
                      paths: ["package.json", "package-lock.json", "npm-shrinkwrap.json"]) {
            Git.tag(project.path, "v\(version)")
            print("  → git commit + tag v\(version)  (git push --follow-tags)")
        }
    }
}

/// PREPARE a GitHub Release + Homebrew formula. This command is deliberately
/// non-mutating: it computes the tag, tarball URL, a local SHA-256 preview, the
/// formula text and the exact publish commands — and prints them for the human
/// to run. It NEVER creates a tag, a release, or pushes anything.
func cmdRelease(_ t: L10n, opts: CLIOptions, selector: String?) {
    let project = resolveProject(selector, t)
    let sep = String(repeating: "─", count: 48)

    // owner/repo: explicit --slug wins, else read origin (read-only).
    guard let slug = opts.slug ?? ReleasePrep.repoSlug(of: project.path) else {
        eprint(t.releaseNoSlug())
        exit(1)
    }

    let repoName = slug.split(separator: "/").last.map(String.init) ?? project.name
    let tag = "v\(project.version)"
    // Local, read-only SHA-256 preview of the source archive (no network).
    let sha = ReleasePrep.localArchiveSHA256(dir: project.path, tag: tag, prefix: "\(repoName)-\(project.version)")
    let plan = ReleasePrep.makePlan(repoSlug: slug, version: project.version, sha256: sha)

    if opts.json { printJSON(plan); return }

    print("\(project.name)   \(plan.tag)   \(slug)")
    print(sep)
    print("  \(t.releaseTarball()): \(plan.tarballURL)")
    print("  sha256: \(plan.sha256 ?? t.releaseShaUnknown())")
    if plan.sha256 != nil { print("  \(t.releaseShaPreviewNote())") }
    print(sep)
    print("  \(t.releaseFormulaHeader()):")
    for line in plan.formula.split(separator: "\n", omittingEmptySubsequences: false) {
        print("    \(line)")
    }
    print(sep)
    print("  \(t.releaseCommandsHeader()):")
    for c in plan.commands { print("    $ \(c)") }
    print(sep)
    print("  \(t.releasePrepareOnly())")

    if let out = opts.formulaOut {
        do {
            try plan.formula.write(toFile: out, atomically: true, encoding: .utf8)
            print("  \(t.releaseFormulaWritten(out))")
        } catch {
            eprint("✗ \(out): \(error.localizedDescription)")
            exit(1)
        }
    }
}

/// PREPARE a PyPI or crates.io publish. Like `clioil release`, this is
/// deliberately non-mutating: it prints the exact commands a human runs, and can
/// run the registry's own SAFE dry-run (`twine check` / `cargo publish
/// --dry-run`) — but it NEVER performs the real upload. Used for the ecosystems
/// where clioil doesn't (yet) own an audited mutating flow.
func cmdPrepare(_ t: L10n, opts: CLIOptions, selector: String?) {
    let project = resolveProject(selector, t)
    let sep = String(repeating: "─", count: 48)

    let plan: PreparedPublish
    switch project.ecosystem {
    case "pypi":   plan = PyPIPublisher.prepare(name: project.name, version: project.version)
    case "crates": plan = CratesPublisher.prepare(name: project.name, version: project.version)
    default:
        eprint(t.prepareUnsupported(project.ecosystem))
        exit(1)
    }

    if opts.json { printJSON(plan); return }

    print("\(project.name)   v\(project.version)   \(plan.ecosystem)")
    print(sep)
    print("  \(t.prepareDryRunHeader()) (\(plan.dryRunNote)):")
    print("    $ \(plan.dryRunCommand.joined(separator: " "))")

    // --dry-run actually RUNS the safe preview (never an upload).
    if opts.dryRun {
        print(sep)
        print("  \(t.prepareRunningDryRun())")
        let result: DryRunResult = project.ecosystem == "pypi"
            ? PyPIPublisher().dryRun(project)
            : CratesPublisher().dryRun(project)
        for line in result.output.suffix(40) { print("    \(line)") }
        print("  " + (result.ok ? t.prepareDryRunOk() : t.prepareDryRunFailed()))
    }

    print(sep)
    print("  \(t.releaseCommandsHeader()):")
    for c in plan.publishCommands { print("    $ \(c)") }
    print(sep)
    print("  \(t.releasePrepareOnly())")
}

// MARK: - dispatch

let opts = parse(CommandLine.arguments)
let t = L10n(Language.detect(override: opts.langOverride))

if opts.showVersion { print("clioil \(Clioil.version)"); exit(0) }

func arg(_ n: Int) -> String? { opts.positional.count > n ? opts.positional[n] : nil }

switch opts.positional.first ?? "list" {
case "list":    cmdList(t, json: opts.json)
case "status":  cmdStatus(t, json: opts.json, selector: arg(1))
case "publish": cmdPublish(t, opts: opts, selector: arg(1))
case "release": cmdRelease(t, opts: opts, selector: arg(1))
case "prepare": cmdPrepare(t, opts: opts, selector: arg(1))
case "help", "-h", "--help": print(t.help())
case let other:
    print(t.unknownCommand(other)); print(""); print(t.help()); exit(1)
}
