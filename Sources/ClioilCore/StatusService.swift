import Foundation

/// A read-only snapshot of where a project stands relative to the registry and
/// its git history — everything a user needs to decide "is it safe to publish,
/// and what would I be shipping?"
public struct ProjectStatus: Sendable, Codable {
    public let project: Project
    public let registryLatest: String?
    /// Whether the *current local* version is already on the registry.
    public let currentIsPublished: Bool
    public let isGitRepo: Bool
    public let gitDirty: Bool
    public let lastTag: String?
    public let changesSinceTag: [String]

    public init(
        project: Project,
        registryLatest: String?,
        currentIsPublished: Bool,
        isGitRepo: Bool,
        gitDirty: Bool,
        lastTag: String?,
        changesSinceTag: [String]
    ) {
        self.project = project
        self.registryLatest = registryLatest
        self.currentIsPublished = currentIsPublished
        self.isGitRepo = isGitRepo
        self.gitDirty = gitDirty
        self.lastTag = lastTag
        self.changesSinceTag = changesSinceTag
    }
}

/// Gathers a ``ProjectStatus``. The registry side goes through ``Publisher`` so
/// it's trivially stubbable in tests (no network); the git side uses ``Git``.
public struct StatusService: Sendable {
    public let publisher: any Publisher

    public init(publisher: any Publisher = NpmPublisher()) {
        self.publisher = publisher
    }

    public func status(of project: Project) -> ProjectStatus {
        let isRepo = Git.isRepo(project.path)
        let tag = isRepo ? Git.lastTag(project.path) : nil
        return ProjectStatus(
            project: project,
            registryLatest: publisher.latestPublishedVersion(of: project),
            currentIsPublished: publisher.versionExists(project.version, of: project),
            isGitRepo: isRepo,
            gitDirty: isRepo && Git.isDirty(project.path),
            lastTag: tag,
            changesSinceTag: tag.map { Git.commitsSince($0, dir: project.path) } ?? []
        )
    }
}
