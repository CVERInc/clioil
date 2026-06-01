import Foundation

/// Walks a set of root folders and returns the publishable projects it finds.
///
/// Today it understands npm (package.json). New ecosystems plug in by teaching
/// the scanner another manifest reader — the rest of the engine doesn't change.
public struct ProjectScanner: Sendable {
    public let roots: [URL]
    /// How many directory levels below each root to descend.
    /// `1` = the root itself plus its direct children (matches the original
    /// `find -maxdepth 2` behaviour of the shell prototype).
    public let maxDepth: Int

    public init(roots: [URL], maxDepth: Int = 1) {
        self.roots = roots
        self.maxDepth = maxDepth
    }

    /// Deduplicated list of publishable projects across all roots.
    public func scan() -> [Project] {
        var seen = Set<String>()
        var found: [Project] = []
        for root in roots {
            for manifest in manifests(named: "package.json", in: root) {
                let dir = manifest.deletingLastPathComponent().resolvingSymlinksInPath()
                if seen.contains(dir.path) { continue }
                guard let project = readNpm(manifest: manifest, dir: dir) else { continue }
                seen.insert(dir.path)
                found.append(project)
            }
        }
        return found
    }

    // MARK: - npm manifest reader

    /// Parse package.json in pure Swift — no node dependency. A project is
    /// publishable when it has a non-empty `name` and is not `"private": true`.
    private func readNpm(manifest: URL, dir: URL) -> Project? {
        guard
            let data = try? Data(contentsOf: manifest),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }

        if obj["private"] as? Bool == true { return nil }
        guard let name = obj["name"] as? String, !name.isEmpty else { return nil }
        let version = (obj["version"] as? String) ?? "0.0.0"
        return Project(path: dir, name: name, version: version, ecosystem: "npm")
    }

    // MARK: - filesystem walk

    private func manifests(named file: String, in root: URL) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        var results: [URL] = []
        func walk(_ dir: URL, depth: Int) {
            let manifest = dir.appendingPathComponent(file)
            if fm.fileExists(atPath: manifest.path) { results.append(manifest) }
            guard depth < maxDepth else { return }

            let entries = (try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for entry in entries {
                let entryIsDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard entryIsDir, entry.lastPathComponent != "node_modules" else { continue }
                walk(entry, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        return results
    }
}
