import Foundation

/// Minimal process runner. Resolves tools via `/usr/bin/env` so it honours the
/// user's PATH (node, npm, git, …).
public enum Shell {
    public struct Result: Sendable {
        public let status: Int32
        public let stdout: String
        public let stderr: String
        public var ok: Bool { status == 0 }
    }

    /// Run a command and capture its output.
    ///
    /// Both pipes are drained on background threads *before* the process exits,
    /// so a command that floods stderr while we read stdout can't deadlock on a
    /// full pipe buffer.
    @discardableResult
    public static func run(_ args: [String], cwd: URL? = nil) -> Result {
        guard let first = args.first else {
            return Result(status: -1, stdout: "", stderr: "empty command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let collector = OutputCollector()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "clioil.shell.read", attributes: .concurrent)
        group.enter()
        queue.async {
            collector.setOut(outPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        queue.async {
            collector.setErr(errPipe.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }

        do {
            try process.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: "\(first): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        group.wait()

        return Result(
            status: process.terminationStatus,
            stdout: collector.outString,
            stderr: collector.errString
        )
    }

    /// Run a command with the terminal's stdio inherited (no capture), so the
    /// user sees live output and can interact — e.g. `npm publish`'s browser
    /// passkey prompt. Returns only the exit status.
    @discardableResult
    public static func runInteractive(_ args: [String], cwd: URL? = nil) -> Int32 {
        guard !args.isEmpty else { return -1 }
        // Flush our own buffered output first so our lines stay ordered ahead of
        // the child's live output (matters when stdout is piped, not a TTY).
        fflush(stdout)
        fflush(stderr)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        if let cwd { process.currentDirectoryURL = cwd }
        // No pipes set → child inherits this process's stdin/stdout/stderr.
        do { try process.run() } catch { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

/// Thread-safe holder for the two pipe reads.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var out = Data()
    private var err = Data()

    func setOut(_ d: Data) { lock.lock(); out = d; lock.unlock() }
    func setErr(_ d: Data) { lock.lock(); err = d; lock.unlock() }

    var outString: String { lock.lock(); defer { lock.unlock() }; return String(decoding: out, as: UTF8.self) }
    var errString: String { lock.lock(); defer { lock.unlock() }; return String(decoding: err, as: UTF8.self) }
}
