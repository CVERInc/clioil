import SwiftUI
import ClioilCore

// The native surface over ClioilCore. v1: browse your publishable projects and
// see each one's release readiness at a glance. Same engine as the CLI.

@main
struct ClioilApp: App {
    var body: some Scene {
        WindowGroup("clioil") {
            ContentView()
                .frame(minWidth: 560, minHeight: 400)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var projects: [Project] = []
    @State private var selected: Project.ID?
    @State private var status: ProjectStatus?
    @State private var loading = false

    private let t = L10n(Language.detect())

    var body: some View {
        NavigationSplitView {
            List(projects, selection: $selected) { p in
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.headline)
                    Text("v\(p.version) · \(p.displayPath)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("clioil")
            .frame(minWidth: 220)
        } detail: {
            detail
        }
        .onAppear(perform: loadProjects)
        .onChange(of: selected) { _ in loadStatus() }
    }

    @ViewBuilder
    private var detail: some View {
        if let project = projects.first(where: { $0.id == selected }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(project.name).font(.title2).bold()
                    Text(project.displayPath).font(.callout).foregroundStyle(.secondary)
                    Divider()

                    if loading {
                        HStack { ProgressView(); Text("…") }
                    } else if let s = status {
                        row("shippingbox",
                            "\(t.statusOnNpm()): \(s.registryLatest ?? t.statusUnpublished())")
                        row(s.currentIsPublished ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                            s.currentIsPublished
                                ? t.statusAlreadyPublished(project.version)
                                : t.statusReadyToPublish(project.version))
                        if s.isGitRepo {
                            row(s.gitDirty ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                                s.gitDirty ? t.statusGitDirty() : t.statusGitClean())
                            if let tag = s.lastTag {
                                Text(s.changesSinceTag.isEmpty
                                     ? t.statusNoChangesSince(tag)
                                     : t.statusChangesSince(tag, s.changesSinceTag.count))
                                    .font(.callout).padding(.top, 4)
                                ForEach(Array(s.changesSinceTag.prefix(15)), id: \.self) { c in
                                    Text("• \(c)").font(.caption).foregroundStyle(.secondary)
                                }
                            } else {
                                Text(t.statusNoTag()).font(.callout)
                            }
                        } else {
                            row("xmark.circle", t.statusNotGitRepo())
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(t.projectsHeader(projects.count))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func row(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.callout)
    }

    private func loadProjects() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [home, home.appendingPathComponent("Desktop/GitHub")]
        projects = ProjectScanner(roots: roots, maxDepth: 1)
            .scan()
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func loadStatus() {
        guard let project = projects.first(where: { $0.id == selected }) else {
            status = nil
            return
        }
        loading = true
        status = nil
        Task.detached {
            let result = StatusService().status(of: project)
            await MainActor.run {
                self.status = result
                self.loading = false
            }
        }
    }
}
