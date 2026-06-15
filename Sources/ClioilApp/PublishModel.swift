import SwiftUI
import AppKit
import ClioilCore

/// Drives a publish from the GUI: runs the blocking npm/git work off the main
/// actor and streams human-readable progress + advice back to the UI.
@MainActor
final class PublishModel: ObservableObject {
    @Published var running = false
    @Published var log: [String] = []
    @Published var statusText = ""        // the live, in-place status line (npm's progress)
    @Published var advice: Advice?
    @Published var finished = false
    @Published var succeeded = false
    @Published var cancelled = false

    private var openedAuthURL = false
    /// Live handle to the streaming publish, so the UI can Stop it mid-flight.
    private var streamHandle: Shell.StreamHandle?

    func run(project: Project, bump: Bump, t: L10n) {
        guard !running else { return }
        running = true; log = []; statusText = ""; advice = nil; finished = false; succeeded = false
        cancelled = false; streamHandle = nil
        openedAuthURL = false
        Task { await perform(project: project, bump: bump, t: t) }
    }

    /// Stop an in-flight publish. Terminates the streamed child process; the
    /// stream returns with whatever it had, and `perform` finishes as cancelled.
    func cancel() {
        guard running else { return }
        cancelled = true
        streamHandle?.cancel()
    }

    /// Handle one streamed line. Committed lines join the log; in-place (transient)
    /// updates drive the live status row; bare spinner frames are absorbed by the
    /// native ProgressView. npm's web-auth URL is opened the moment it appears.
    private func handleStream(_ text: String, transient: Bool) {
        if Self.isSpinnerFrame(text) { return }   // the native spinner is the animation
        if !openedAuthURL, let url = Self.authURL(in: text) {
            openedAuthURL = true
            NSWorkspace.shared.open(url)
        }
        // The top status row always reflects the *latest* activity (live), whether
        // it's an in-place update or a committed line.
        statusText = text
        if !transient { log.append(text) }
    }

    private static let spinnerScalars = Set("\\|/-".unicodeScalars)
    private static func isSpinnerFrame(_ text: String) -> Bool {
        !text.isEmpty && text.count <= 2 && text.unicodeScalars.allSatisfy { spinnerScalars.contains($0) }
    }

    private static func authURL(in line: String) -> URL? {
        guard let r = line.range(of: "https://www.npmjs.com/auth/") else { return nil }
        let s = String(line[r.lowerBound...]).trimmingCharacters(in: .whitespaces)
        return URL(string: s)
    }

    private func perform(project: Project, bump: Bump, t: L10n) async {
        let ops = PublishOps()
        var bumped = project.version

        if bump != .none {
            if let v = await detached({ ops.bump(project, bump) }) {
                bumped = v
                note(t.publishBumpedTo(v))
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
            note(t.publishInstalling())
            _ = await detached { ops.runInstallCaptured(project) }
        }

        if await detached({ ops.hasRealTestScript(project) }) {
            note(t.publishTesting())
            let r = await detached { ops.runTestCaptured(project) }
            if r.ok {
                note(t.publishTestPassed())
            } else {
                note(t.publishTestFailed())
                for line in cleanedLines(r.stdout + "\n" + r.stderr).suffix(8) {
                    log.append("  \(line)")
                }
                return finish(false)
            }
        }

        note(t.publishAuthInBrowser())
        let result = await detached {
            ops.publishStreamingCancellable(project) { handle in
                Task { @MainActor in self.streamHandle = handle }
            } onLine: { text, transient in
                Task { @MainActor in self.handleStream(text, transient: transient) }
            }
        }
        // If the user pressed Stop, finish quietly as cancelled — no error advice.
        if cancelled {
            note(t.publishCancelled())
            return finish(false)
        }
        let combined = result.stdout + "\n" + result.stderr
        if result.ok && !combined.contains("npm error") {
            note(t.publishSuccess(project.name, ver))
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
            // Output already streamed into the log live; just add the guidance.
            advice = ErrorAdvisor(t).advise(stdout: result.stdout, stderr: result.stderr)
            finish(false)
        }
    }

    /// Split output into clean lines: strip CRs/control chars (from the PTY) and blanks.
    private func cleanedLines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { String(String.UnicodeScalarView($0.unicodeScalars.filter { $0 == "\t" || $0.value >= 32 })) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Record a stage marker: into the log *and* the live top status row.
    private func note(_ s: String) {
        log.append(s)
        statusText = s
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
