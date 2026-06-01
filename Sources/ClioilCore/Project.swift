import Foundation

/// A publishable project discovered on disk.
///
/// Ecosystem-agnostic on purpose: a project knows *where* it is, *what* it's
/// called and *which* version it sits at. The rules for "is this publishable"
/// and "where does it publish to" live in a ``Publisher``, not here.
public struct Project: Sendable, Identifiable, Hashable, Codable {
    /// Stable identity = absolute directory path.
    public var id: String { path.path }

    /// Directory that contains the manifest (e.g. the folder with package.json).
    public let path: URL

    /// Package name as declared in the manifest.
    public let name: String

    /// Current local version string.
    public let version: String

    /// Which ecosystem this project belongs to (e.g. "npm").
    public let ecosystem: String

    public init(path: URL, name: String, version: String, ecosystem: String) {
        self.path = path
        self.name = name
        self.version = version
        self.ecosystem = ecosystem
    }

    /// Path with the user's home folder collapsed to `~`, for display.
    public var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let p = path.path
        if p == home { return "~" }
        if p.hasPrefix(home + "/") { return "~" + p.dropFirst(home.count) }
        return p
    }
}
