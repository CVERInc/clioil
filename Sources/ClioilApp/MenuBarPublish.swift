import SwiftUI
import AppKit
import ClioilCore
import Signet

/// The menu-bar surface: a compact panel that lists publishable projects and
/// runs a publish, streaming `Shell.runStreaming()` output live into a
/// scrollable log. Reuses the exact same ``PublishModel`` as the main window —
/// no duplicated publish logic — and adds a Stop button wired to the model's
/// cancellation (which terminates the streamed child process mid-flight).
struct MenuBarPublishView: View {
    private let t = L10n(Language.detect())
    @State private var projects: [Project] = []
    @State private var selected: Project.ID?
    @State private var bump: Bump = .none
    @StateObject private var publisher = PublishModel()

    private var current: Project? { projects.first { $0.id == selected } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            picker
            controls
            if publisher.running || !publisher.log.isEmpty {
                liveLog
            }
            if let a = publisher.advice {
                adviceBox(a)
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 360)
        .tint(.reefTeal)
        .cverTheme(ReefTheme())
        .onAppear(perform: loadIfNeeded)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperplane.fill").foregroundStyle(Color.reefTeal)
            Text("clioil — \(t.menuBarTitle())").font(.headline).foregroundStyle(Color.reefMint)
            Spacer()
            if publisher.running {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder private var picker: some View {
        if projects.isEmpty {
            Text(t.noProjectsFound()).font(.caption).foregroundStyle(Color.reefTextDim)
        } else {
            Text(t.menuBarPickProject()).font(.caption).foregroundStyle(Color.reefTextDim)
            Picker("", selection: $selected) {
                ForEach(projects) { p in
                    Text("\(p.name)  v\(p.version)").tag(Optional(p.id))
                }
            }
            .labelsHidden()
            .disabled(publisher.running)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Picker("", selection: $bump) {
                Text("—").tag(Bump.none)
                Text("patch").tag(Bump.patch)
                Text("minor").tag(Bump.minor)
                Text("major").tag(Bump.major)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(publisher.running)

            if publisher.running {
                Button(role: .destructive) {
                    publisher.cancel()
                } label: {
                    Label(t.stopButton(), systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    if let p = current { publisher.run(project: p, bump: bump, t: t) }
                } label: {
                    Label(t.publishButton(), systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.reefTeal)
                .disabled(current == nil)
            }
        }
    }

    /// The live, scrollable streaming log. Auto-scrolls to the newest committed
    /// line as `Shell.runStreaming` feeds them in; the top status row shows the
    /// latest transient (in-place) progress.
    private var liveLog: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !publisher.statusText.isEmpty {
                Text(publisher.statusText)
                    .font(.caption).foregroundStyle(Color.reefMint)
                    .lineLimit(1).truncationMode(.middle)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(publisher.log.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.reefText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160)
                .background(Color(hex: 0x031c1c))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                // Single-arg onChange for macOS 13 compatibility (the two-arg
                // form is 14+). Auto-scroll to the newest streamed line.
                .onChange(of: publisher.log.count) { count in
                    if count > 0 { withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) } }
                }
            }
        }
    }

    private func adviceBox(_ a: Advice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(a.title, systemImage: "lightbulb.fill")
                .foregroundStyle(Color.reefAmber).font(.caption.bold())
            ForEach(a.steps, id: \.self) { step in
                Text("→ \(step)").font(.caption2).foregroundStyle(Color.reefText)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reefAmber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(t.quitButton()) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless).font(.caption).foregroundStyle(Color.reefTextDim)
        }
    }

    private func loadIfNeeded() {
        guard projects.isEmpty else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        projects = ProjectScanner(roots: [home, home.appendingPathComponent("Developer"), home.appendingPathComponent("Desktop/GitHub")],
                                  maxDepth: 1)
            .scan()
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        if selected == nil { selected = projects.first?.id }
    }
}
