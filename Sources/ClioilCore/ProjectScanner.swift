import Foundation

/// Walks a set of root folders and returns the publishable projects it finds.
///
/// Understands npm (package.json), PyPI (pyproject.toml / setup.py) and crates
/// (Cargo.toml). New ecosystems plug in by teaching the scanner another manifest
/// reader — the rest of the engine doesn't change.
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
    ///
    /// Manifests are tried in priority order per directory: a folder with both a
    /// package.json and a Cargo.toml is reported once, as the first ecosystem
    /// that claims it. (`seen` keys on the directory, so one project = one entry.)
    public func scan() -> [Project] {
        var seen = Set<String>()
        var found: [Project] = []

        // (manifest filename, reader). Order = ecosystem priority for a dir that
        // somehow carries more than one manifest.
        let readers: [(String, (URL, URL) -> Project?)] = [
            ("package.json", readNpm),
            ("Cargo.toml", readCargo),
            ("pyproject.toml", readPyproject),
            ("setup.py", readSetupPy),
        ]

        for root in roots {
            for (file, reader) in readers {
                for manifest in manifests(named: file, in: root) {
                    let dir = manifest.deletingLastPathComponent().resolvingSymlinksInPath()
                    if seen.contains(dir.path) { continue }
                    guard let project = reader(manifest, dir) else { continue }
                    seen.insert(dir.path)
                    found.append(project)
                }
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

    // MARK: - Cargo (Rust) manifest reader

    /// Parse the `[package]` table of a Cargo.toml in pure Swift — no toml crate.
    /// A crate is publishable when its `[package]` has a `name` and is not marked
    /// `publish = false`. Workspace-only manifests (no `[package]`) are skipped.
    private func readCargo(manifest: URL, dir: URL) -> Project? {
        guard let text = try? String(contentsOf: manifest, encoding: .utf8) else { return nil }
        let pkg = TOMLLite.table("package", in: text)
        guard let name = pkg["name"], !name.isEmpty else { return nil }
        if pkg["publish"] == "false" { return nil }
        let version = pkg["version"] ?? "0.0.0"
        return Project(path: dir, name: name, version: version, ecosystem: "crates")
    }

    // MARK: - PyPI manifest readers

    /// Parse the `[project]` table of a pyproject.toml (PEP 621) in pure Swift.
    /// Publishable when `[project]` declares a `name`. Build-backend-only files
    /// without a `[project].name` are skipped (e.g. pure tool config).
    private func readPyproject(manifest: URL, dir: URL) -> Project? {
        guard let text = try? String(contentsOf: manifest, encoding: .utf8) else { return nil }
        let project = TOMLLite.table("project", in: text)
        guard let name = project["name"], !name.isEmpty else { return nil }
        let version = project["version"] ?? "0.0.0"
        return Project(path: dir, name: name, version: version, ecosystem: "pypi")
    }

    /// Fallback for legacy projects that only ship a setup.py: read the `name=`
    /// and `version=` keyword args from the `setup(...)` call. Best-effort and
    /// deliberately shallow — it recognises the common literal form, not arbitrary
    /// Python. A name we can't read → not reported (honest, never a fake project).
    private func readSetupPy(manifest: URL, dir: URL) -> Project? {
        guard let text = try? String(contentsOf: manifest, encoding: .utf8) else { return nil }
        guard let name = PySetupLite.kwarg("name", in: text), !name.isEmpty else { return nil }
        let version = PySetupLite.kwarg("version", in: text) ?? "0.0.0"
        return Project(path: dir, name: name, version: version, ecosystem: "pypi")
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
