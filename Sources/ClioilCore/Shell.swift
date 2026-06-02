import Foundation

/// Minimal process runner. Resolves tools via `/usr/bin/env` so it honours the
/// user's PATH (node, npm, git, …).
public enum Shell {
    /// The user's *real* PATH, resolved once via their login+interactive shell.
    ///
    /// A GUI app launched from Finder inherits only launchd's minimal PATH
    /// (`/usr/bin:/bin:…`), so Homebrew / nvm / fnm / volta node installs are
    /// invisible and `npm` "isn't found". Asking the login shell reproduces the
    /// environment a Terminal would have.
    nonisolated(unsafe) private static var cachedPath: String?

    private static func resolvedPath() -> String {
        if let cachedPath { return cachedPath }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: shell)
        probe.arguments = ["-ilc", "printf %s \"$PATH\""]
        let out = Pipe()
        probe.standardOutput = out
        probe.standardError = Pipe()
        var result = ""
        if (try? probe.run()) != nil {
            let data = out.fileHandleForReading.readDataToEndOfFile()
            probe.waitUntilExit()
            result = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result.isEmpty {
            // Fallback: common node locations + whatever we already had.
            let extras = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
                          "/usr/sbin", "/sbin", NSHomeDirectory() + "/.volta/bin"]
            let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
            result = (extras + [existing]).joined(separator: ":")
        }
        cachedPath = result
        return result
    }

    /// Child environment with PATH widened to the user's real shell PATH.
    private static func childEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = resolvedPath()
        return env
    }

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
    public static func run(_ args: [String], cwd: URL? = nil, stdin: String? = nil) -> Result {
        guard let first = args.first else {
            return Result(status: -1, stdout: "", stderr: "empty command")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.environment = childEnvironment()
        if let cwd { process.currentDirectoryURL = cwd }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let inPipe: Pipe? = stdin != nil ? Pipe() : nil
        if let inPipe { process.standardInput = inPipe }

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
        // Feed stdin (e.g. the ENTER npm's web-auth waits for), then close it.
        if let inPipe, let stdin {
            inPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try? inPipe.fileHandleForWriting.close()
        }
        process.waitUntilExit()
        group.wait()

        return Result(
            status: process.terminationStatus,
            stdout: collector.outString,
            stderr: collector.errString
        )
    }

    /// ANSI CSI escape sequences (colors, cursor moves) emitted under a PTY.
    nonisolated(unsafe) private static let ansiRegex =
        try! NSRegularExpression(pattern: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]")

    /// One terminal line, de-noised for display/parsing: strip CRs, ANSI escapes,
    /// braille spinner frames and other control chars.
    static func cleanLine(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\r", with: "")
        t = ansiRegex.stringByReplacingMatches(
            in: t, range: NSRange(t.startIndex..., in: t), withTemplate: "")
        let scalars = t.unicodeScalars.filter { sc in
            !(sc.value >= 0x2800 && sc.value <= 0x28FF) && (sc.value >= 0x20 || sc.value == 9)
        }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    /// Like `run`, but invokes `onLine` for each cleaned output line as it
    /// arrives — so a caller can react mid-flight (e.g. open npm's web-auth URL
    /// the moment it's printed, while npm keeps polling).
    @discardableResult
    public static func runStreaming(
        _ args: [String], cwd: URL? = nil, stdin: String? = nil,
        onLine: @escaping @Sendable (String) -> Void
    ) -> Result {
        guard let first = args.first else {
            return Result(status: -1, stdout: "", stderr: "empty command")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.environment = childEnvironment()
        if let cwd { process.currentDirectoryURL = cwd }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let inPipe: Pipe? = stdin != nil ? Pipe() : nil
        if let inPipe { process.standardInput = inPipe }

        let acc = OutputCollector()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "clioil.shell.stream", attributes: .concurrent)

        func pump(_ handle: FileHandle, isErr: Bool) {
            group.enter()
            queue.async {
                var buffer = Data()
                while case let chunk = handle.availableData, !chunk.isEmpty {
                    if isErr { acc.appendErr(chunk) } else { acc.appendOut(chunk) }
                    buffer.append(chunk)
                    while let nl = buffer.firstIndex(of: 0x0A) {
                        let lineData = Data(buffer[buffer.startIndex..<nl])
                        buffer.removeSubrange(buffer.startIndex...nl)
                        let line = cleanLine(String(decoding: lineData, as: UTF8.self))
                        if !line.isEmpty { onLine(line) }
                    }
                }
                let last = cleanLine(String(decoding: buffer, as: UTF8.self))
                if !last.isEmpty { onLine(last) }
                group.leave()
            }
        }

        do {
            try process.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: "\(first): \(error.localizedDescription)")
        }
        if let inPipe, let stdin {
            inPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try? inPipe.fileHandleForWriting.close()
        }
        pump(outPipe.fileHandleForReading, isErr: false)
        pump(errPipe.fileHandleForReading, isErr: true)
        process.waitUntilExit()
        group.wait()
        return Result(status: process.terminationStatus, stdout: acc.outString, stderr: acc.errString)
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
        process.environment = childEnvironment()
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
    func appendOut(_ d: Data) { lock.lock(); out.append(d); lock.unlock() }
    func appendErr(_ d: Data) { lock.lock(); err.append(d); lock.unlock() }

    var outString: String { lock.lock(); defer { lock.unlock() }; return String(decoding: out, as: UTF8.self) }
    var errString: String { lock.lock(); defer { lock.unlock() }; return String(decoding: err, as: UTF8.self) }
}
