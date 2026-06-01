import SwiftUI
import ClioilCore

/// Drives a publish from the GUI: runs the blocking npm/git work off the main
/// actor and streams human-readable progress + advice back to the UI.
@MainActor
final class PublishModel: ObservableObject {
    @Published var running = false
    @Published var log: [String] = []
    @Published var advice: Advice?
    @Published var finished = false
    @Published var succeeded = false

    func run(project: Project, bump: Bump, t: L10n) {
        guard !running else { return }
        running = true; log = []; advice = nil; finished = false; succeeded = false
        Task { await perform(project: project, bump: bump, t: t) }
    }

    private func perform(project: Project, bump: Bump, t: L10n) async {
        let ops = PublishOps()
        var bumped = project.version

        if bump != .none {
            if let v = await detached({ ops.bump(project, bump) }) {
                bumped = v
                log.append(t.publishBumpedTo(v))
            } else {
                log.append("✗ npm version \(bump.rawValue)")
                return finish(false)
            }
        }
        let ver = bumped   // immutable from here — safe to capture in Sendable closures

        if await detached({ NpmPublisher().versionExists(ver, of: project) }) {
            advice = ErrorAdvisor(t).advise(.versionExists)
            return finish(false)
        }

        if await detached({ ops.needsInstall(project) }) {
            log.append(t.publishInstalling())
            _ = await detached { ops.runInstallCaptured(project) }
        }

        if await detached({ ops.hasRealTestScript(project) }) {
            log.append(t.publishTesting())
            let r = await detached { ops.runTestCaptured(project) }
            if r.ok {
                log.append(t.publishTestPassed())
            } else {
                log.append(t.publishTestFailed())
                let tail = (r.stdout + "\n" + r.stderr)
                    .split(whereSeparator: \.isNewline)
                    .suffix(8)
                for line in tail { log.append("  \(line)") }
                return finish(false)
            }
        }

        log.append(t.publishAuthInBrowser())
        let result = await detached { ops.publishCaptured(project) }
        if result.ok {
            log.append(t.publishSuccess(project.name, ver))
            if bump != .none, Git.isRepo(project.path) {
                _ = await detached {
                    Git.commit(project.path, message: "release v\(ver)",
                               paths: ["package.json", "package-lock.json", "npm-shrinkwrap.json"])
                }
                _ = await detached { Git.tag(project.path, "v\(ver)") }
                log.append("→ git commit + tag v\(ver)")
            }
            finish(true)
        } else {
            // Surface npm's actual error so it's visible (and copyable), not hidden.
            let tail = (result.stdout + "\n" + result.stderr)
                .split(whereSeparator: \.isNewline)
                .suffix(12)
            for line in tail { log.append("  \(line)") }
            advice = ErrorAdvisor(t).advise(stdout: result.stdout, stderr: result.stderr)
            finish(false)
        }
    }

    private func finish(_ ok: Bool) {
        running = false
        finished = true
        succeeded = ok
    }

    /// Run blocking work off the main actor and await its (Sendable) result.
    private func detached<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
        await Task.detached(priority: .userInitiated, operation: work).value
    }
}
