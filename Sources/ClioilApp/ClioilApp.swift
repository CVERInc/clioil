import SwiftUI
import AppKit
import ClioilCore
import Signet

// Native surface over ClioilCore — reef-styled (deep teal, mint, teal accent).
// Palette/tokens now come from Signet (the shared design system) via ReefTheme.
// Browse projects, see readiness, and publish right from the window.

@main
struct ClioilApp: App {
    var body: some Scene {
        WindowGroup("clioil") {
            ContentView()
                .frame(minWidth: 640, minHeight: 460)
                .preferredColorScheme(.dark)
                .tint(.reefTeal)
                .cverTheme(ReefTheme())
        }
        .windowResizability(.contentSize)

        // Menu-bar surface: publish a project and watch the log stream live,
        // without opening the main window. Same PublishModel under the hood.
        MenuBarExtra("clioil", systemImage: "paperplane.fill") {
            MenuBarPublishView()
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @State private var projects: [Project] = []
    @State private var selected: Project.ID?
    private let t = L10n(Language.detect())

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(projects) { p in
                    let isSel = p.id == selected
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).font(.headline)
                            .foregroundStyle(isSel ? Color.white : Color.reefMint)
                        Text("v\(p.version) · \(p.displayPath)")
                            .font(.caption)
                            .foregroundStyle(isSel ? Color.white.opacity(0.85) : Color.reefTextDim)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSel ? Color.reefTeal : Color.clear)
                            .padding(.vertical, 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selected = p.id }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            // Frosted teal sidebar via Signet's material treatment.
            .background(Color.reefDeep.opacity(0.55))
            .background(.ultraThinMaterial)
            .navigationTitle("clioil")
            .frame(minWidth: 240)
        } detail: {
            Group {
                if let project = projects.first(where: { $0.id == selected }) {
                    ProjectDetailView(project: project, t: t).id(project.id)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 34)).foregroundStyle(Color.reefTeal)
                        Text(t.projectsHeader(projects.count)).foregroundStyle(Color.reefTextDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.reefGround)
        }
        .onAppear(perform: load)
    }

    private func load() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        projects = ProjectScanner(roots: [home, home.appendingPathComponent("Desktop/GitHub")], maxDepth: 1)
            .scan()
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

struct ProjectDetailView: View {
    let project: Project
    let t: L10n
    @State private var status: ProjectStatus?
    @State private var loading = true
    @State private var bump: Bump = .none
    @StateObject private var publisher = PublishModel()
    @StateObject private var releasePrep = ReleasePrepModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                divider
                statusSection
                divider
                publishSection
                divider
                releaseSection
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await loadStatus() }
    }

    private var divider: some View { Rectangle().fill(Color.reefBorder).frame(height: 1) }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name).font(.title2).bold().foregroundStyle(Color.reefMint)
            Text("v\(project.version) · \(project.displayPath)")
                .font(.callout).foregroundStyle(Color.reefTextDim)
        }
    }

    @ViewBuilder private var statusSection: some View {
        if loading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("…").foregroundStyle(Color.reefTextDim)
            }
        } else if let s = status {
            row("shippingbox", "\(t.statusOnNpm()): \(s.registryLatest ?? t.statusUnpublished())", .reefText)
            if s.currentIsPublished {
                row("exclamationmark.triangle.fill", t.statusAlreadyPublished(project.version), .reefAmber)
            } else {
                row("checkmark.circle.fill", t.statusReadyToPublish(project.version), .reefGreen)
            }
            if s.isGitRepo {
                row(s.gitDirty ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                    s.gitDirty ? t.statusGitDirty() : t.statusGitClean(),
                    s.gitDirty ? .reefAmber : .reefGreen)
                if let tag = s.lastTag {
                    Text(s.changesSinceTag.isEmpty
                         ? t.statusNoChangesSince(tag)
                         : t.statusChangesSince(tag, s.changesSinceTag.count))
                        .font(.callout).foregroundStyle(Color.reefText).padding(.top, 2)
                    ForEach(Array(s.changesSinceTag.prefix(12)), id: \.self) { c in
                        Text("• \(c)").font(.caption).foregroundStyle(Color.reefTextDim)
                    }
                } else {
                    Text(t.statusNoTag()).font(.callout).foregroundStyle(Color.reefTextDim)
                }
            } else {
                row("xmark.circle", t.statusNotGitRepo(), .reefTextDim)
            }
        }
    }

    private var publishSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $bump) {
                Text("—").tag(Bump.none)
                Text("patch").tag(Bump.patch)
                Text("minor").tag(Bump.minor)
                Text("major").tag(Bump.major)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(publisher.running)

            Button {
                publisher.run(project: project, bump: bump, t: t)
            } label: {
                Label(t.publishButton(), systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.reefTeal)
            .controlSize(.large)
            .disabled(publisher.running)

            if publisher.running {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(publisher.statusText.isEmpty ? t.publishAuthInBrowser() : publisher.statusText)
                        .font(.caption).foregroundStyle(Color.reefMint)
                        .animation(.default, value: publisher.statusText)
                }
                .padding(.vertical, 2)
            }

            if !publisher.log.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Spacer()
                        Button { copyLog() } label: {
                            Label(t.copyButton(), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(Color.reefMint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(publisher.log.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.reefText)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0x031c1c))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let a = publisher.advice {
                VStack(alignment: .leading, spacing: 5) {
                    Label(a.title, systemImage: "lightbulb.fill")
                        .foregroundStyle(Color.reefAmber).font(.callout.bold())
                    ForEach(a.steps, id: \.self) { step in
                        Text("→ \(step)").font(.caption).foregroundStyle(Color.reefText)
                    }
                }
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.reefAmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// PREPARE a GitHub Release + Homebrew formula. Mirrors `clioil release`:
    /// it only previews the formula + the commands the human runs; it never
    /// creates a tag/release or pushes.
    private var releaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.releaseFormulaHeader()).font(.callout.bold()).foregroundStyle(Color.reefMint)

            Button {
                releasePrep.prepare(project: project)
            } label: {
                Label(t.cmdReleaseDesc(), systemImage: "shippingbox.and.arrow.backward.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.reefTeal)
            .disabled(releasePrep.preparing)

            if releasePrep.preparing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("…").font(.caption).foregroundStyle(Color.reefTextDim)
                }
            }

            if releasePrep.error != nil {
                Label(t.releaseNoSlug(), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(Color.reefAmber)
            }

            if let plan = releasePrep.plan {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(t.releaseTarball()): \(plan.tarballURL)")
                        .font(.caption).foregroundStyle(Color.reefTextDim).textSelection(.enabled)
                    if let sha = plan.sha256 {
                        Text("sha256: \(sha)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.reefTextDim).textSelection(.enabled)
                        Text(t.releaseShaPreviewNote())
                            .font(.caption2).foregroundStyle(Color.reefAmber)
                    }

                    HStack {
                        Text(t.releaseFormulaHeader()).font(.caption.bold()).foregroundStyle(Color.reefMint)
                        Spacer()
                        Button { copyToPasteboard(plan.formula) } label: {
                            Label(t.copyButton(), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless).font(.caption).foregroundStyle(Color.reefMint)
                    }
                    Text(plan.formula)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.reefText).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(hex: 0x031c1c))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(t.releaseCommandsHeader()).font(.caption.bold()).foregroundStyle(Color.reefAmber)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(plan.commands, id: \.self) { c in
                            Text("$ \(c)").font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.reefText).textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.reefAmber.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(t.releasePrepareOnly()).font(.caption2).foregroundStyle(Color.reefTextDim)
                }
            }
        }
    }

    private func copyToPasteboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func row(_ icon: String, _ text: String, _ color: Color) -> some View {
        Label {
            Text(text).foregroundStyle(Color.reefText)
        } icon: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .font(.callout)
    }

    private func copyLog() {
        var lines = publisher.log
        if let a = publisher.advice {
            lines.append(a.title)
            lines.append(contentsOf: a.steps)
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func loadStatus() async {
        loading = true
        let project = self.project
        status = await Task.detached(priority: .userInitiated) {
            StatusService().status(of: project)
        }.value
        loading = false
    }
}
