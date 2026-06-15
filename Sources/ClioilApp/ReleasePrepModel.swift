import SwiftUI
import ClioilCore

/// Prepares (never executes) a GitHub Release + Homebrew formula for the GUI.
///
/// SAFETY: like the CLI `release` command, this only PREPARES — it computes the
/// plan (tag, tarball URL, local sha preview, formula, commands) off the main
/// actor and hands it to the view. It never creates a tag/release or pushes;
/// the `commands` are text the human copies and runs deliberately.
@MainActor
final class ReleasePrepModel: ObservableObject {
    @Published var preparing = false
    @Published var plan: ReleasePlan?
    @Published var error: String?

    func prepare(project: Project) {
        guard !preparing else { return }
        preparing = true; plan = nil; error = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> ReleasePlan? in
                guard let slug = ReleasePrep.repoSlug(of: project.path) else { return nil }
                let repoName = slug.split(separator: "/").last.map(String.init) ?? project.name
                let sha = ReleasePrep.localArchiveSHA256(
                    dir: project.path, tag: "v\(project.version)",
                    prefix: "\(repoName)-\(project.version)")
                return ReleasePrep.makePlan(
                    repoSlug: slug, version: project.version, sha256: sha)
            }.value
            if let result { plan = result } else { error = "no-slug" }
            preparing = false
        }
    }
}
