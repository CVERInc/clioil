# clioil

> Make shipping your code to *any* registry a one-click, friendly thing — on a native Mac.

`clioil` turns "publish this package" from a pile of ecosystem-specific incantations
(`npm publish --access public`, `twine upload`, `cargo publish`, `gh release create`,
bumping a Homebrew formula's SHA…) into a single guided flow that holds your hand
instead of spitting cryptic errors at you.

It's the productized successor to a personal `發布 npm 專案.command` script: same
"double-click, pick a project, ship it" feel — but native, multi-ecosystem, and
friendly enough that you don't need to remember each platform's quirks.

## Status — early skeleton 🌱

This is the engine's first vertical slice. Working today:

```bash
swift build
swift run clioil list      # scan & list publishable projects (pure Swift, no node needed)
swift run ClioilTests      # framework-free test runner (no Xcode required)
```

The actual **publish** flow currently still lives in the audited shell prototype
(`發布 npm 專案.command`) until the engine grows a confirmation/auth layer — see the
Roadmap. Read-only npm queries (`latest`, `versionExists`) are already wired into
`NpmPublisher`.

## Why a separate project (and not part of clikae)

`clikae` manages your AI coding **identities** — a two-way, everyday "manage myself"
tool. `clioil` is about **shipping outward** — a one-way, higher-stakes "send it"
action. Different verb, different moment, different feelings. They may share a design
language and credential plumbing, but mashing them into one binary would blur both.
Sibling products, not one app.

## Architecture

The split mirrors that philosophy — one engine, many shells:

```
ClioilCore  ── pure engine, no UI, no globals
  ├─ ProjectScanner   scan roots → publishable projects (parses manifests in Swift)
  ├─ Publisher        plugin seam: one per ecosystem
  │    └─ NpmPublisher    npm (read-only queries today)
  ├─ Project / Bump   ecosystem-agnostic models
  └─ Shell            safe process runner (deadlock-free pipe draining)

clioil (CLI)   ── thin shell over the engine; `list` today
ClioilApp      ── (planned) SwiftUI MenuBarExtra — the real "click to ship" surface
```

Adding an ecosystem = adding one `Publisher`. Everything above it stays put.

## Roadmap

- [x] Engine: scan + parse manifests in pure Swift
- [x] `Publisher` plugin seam + npm read-only queries
- [x] CLI `list`
- [ ] Engine: publish plan (bump → test → pack preview → publish → tag) ported from the prototype
- [ ] **MenuBarExtra app** — the native "pick a project, ship it" surface
- [ ] **Friendly guidance via Apple Intelligence** — on-device Foundation Models
      translate ugly registry errors into plain-language next steps, classify known
      failure modes (version exists / not logged in / missing access), draft changelogs.
      *Honest scope:* the on-device ~3B model is great for guidance/classification/summary,
      not heavy stack-trace reasoning — for genuine debugging the app optionally escalates
      to a larger model (Claude API). On-device first, cloud only when stuck.
- [ ] More ecosystems: PyPI, crates, GitHub Releases, Homebrew

## Requirements

- macOS 13+
- Swift 6 toolchain (Command Line Tools is enough to build the CLI)

## License

MIT — see [LICENSE](LICENSE).
