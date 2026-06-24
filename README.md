# clioil

[![CI](https://github.com/CVERInc/clioil/actions/workflows/ci.yml/badge.svg)](https://github.com/CVERInc/clioil/actions/workflows/ci.yml)

> Make shipping your code to *any* registry a one-click, friendly thing — on a native Mac.

`clioil` turns "publish this package" from a pile of ecosystem-specific incantations
(`npm publish --access public`, `twine upload`, `cargo publish`, `gh release create`,
bumping a Homebrew formula's SHA…) into a single guided flow that walks you through it
instead of leaving you to decode each platform's errors.

It's the productized successor to a personal `發布 npm 專案.command` script: same
"double-click, pick a project, ship it" feel — but native, multi-ecosystem, and
friendly enough that you don't need to remember each platform's quirks.

## Status — early skeleton 🌱

This is the engine's first vertical slice. Working today:

```bash
swift build
swift run clioil list                       # scan & list publishable projects (pure Swift, no node needed)
swift run clioil status <project>           # read-only release-readiness report
swift run clioil publish <project> --dry-run # guided publish, stops before the real publish
swift run clioil release <project>          # PREPARE a GitHub Release + Homebrew formula (preview only — never publishes)
swift run clioil prepare <project>          # PREPARE a PyPI / crates publish (preview only — never uploads)
swift run clioil --version
swift run ClioilApp                         # native SwiftUI app: browse projects + readiness
swift run ClioilTests                       # framework-free test runner (no Xcode required)
```

`publish` walks the whole flow — install deps if needed → run tests → preview
the tarball → confirm → `npm publish` (browser passkey auth) → git commit+tag a
bump. Beginner-friendly by default (guided, confirms, explains); power users can
drive it non-interactively: `--bump <patch|minor|major>`, `--no-test`,
`--no-install`, `--yes`, `--dry-run`. On failure it prints localized, actionable
guidance instead of a raw npm stack (`ErrorAdvisor`). The real publish is the
only irreversible step and always requires explicit confirmation.

Pass `--ai` to add an opt-in remediation hint when a publish fails. It degrades
honestly: it tries Apple's on-device Foundation Models first (no network,
private), falls back to the Claude API *only* if a key is present
(`ANTHROPIC_API_KEY`, or `CLIOIL_ANTHROPIC_API_KEY` to scope it to clioil), and
otherwise prints clioil's built-in guidance. With no on-device model and no key
it still says something useful — it just never silently calls the network and
never claims an AI ran when none did.

`status` shows, for a project: its npm latest, whether the local version is
already published (so you know a publish would fail), whether the git tree is
dirty, and the commits since the last version tag — everything you'd want to
eyeball before shipping. Add `--json` for scripting, `--lang=<code>` to force a
language.

The **publish** flow is implemented in Swift (`PublishOps.swift`): an interactive
`npm publish --auth-type=web` (browser passkey) run under a pseudo-TTY, with
`ErrorAdvisor` turning common failures into localized guidance. Read-only npm
queries (`latest`, `versionExists`) are wired into `NpmPublisher`, and
`scripts/build-app.sh` produces the double-clickable app.

The **release** flow (`ReleasePlan.swift`) *prepares* a GitHub Release + Homebrew
formula — and stops there, on purpose. It computes the tag, the GitHub source
tarball URL, a **local** SHA-256 preview (via `git archive`, no network), the
rendered Homebrew formula (Ruby), and the exact commands you'd run to publish —
then prints them for you to review. clioil never creates a tag, cuts a release,
or pushes a tap: cutting a release is the irreversible step, so it stays a
deliberate human action. The same logic backs the app's "Prepare release"
section and `clioil release <project> --json` / `--formula-out <path>`.

The **prepare** flow (`PreparedPublish.swift`) covers the ecosystems where clioil
doesn't (yet) own an audited mutating publish — **PyPI** and **crates.io**. Like
`release`, it's deliberately non-mutating: it prints the exact commands a human
runs (`python -m build` → `twine upload`, or `cargo publish`) and, with
`--dry-run`, runs the registry's *own* safe preview — `twine check` (validates the
built artifacts, no network upload) for PyPI, `cargo publish --dry-run` (packages
and verifies the crate without uploading) for crates. The actual upload stays a
human step; clioil never publishes here. Add `--json` for the structured plan.

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
  │    ├─ NpmPublisher       npm (read-only queries + the audited publish flow)
  │    ├─ PyPIPublisher      PyPI  (prepare/preview-only — twine check, never uploads)
  │    └─ CratesPublisher    crates.io (prepare/preview-only — cargo publish --dry-run)
  ├─ Project / Bump   ecosystem-agnostic models
  └─ Shell            safe process runner (deadlock-free draining; streaming + cancellable)

clioil (CLI)   ── thin shell over the engine; `list` / `status` / `publish` / `release` / `prepare`
ClioilApp      ── SwiftUI app — browse projects, see readiness, publish from the window
                  (MenuBarExtra "click to ship" mode implemented in code; runtime dogfood pending)
```

Adding an ecosystem = adding one `Publisher`. Everything above it stays put.

## Roadmap

- [x] Engine: scan + parse manifests in pure Swift
- [x] `Publisher` plugin seam + npm read-only queries
- [x] CLI `list`
- [x] Localized UI — 7 languages, auto-detected, compiler-enforced completeness
- [x] CLI `status` — read-only release-readiness report (+ `--json`, `--version`)
- [x] CI — `swift build` + tests on every push/PR
- [x] `clioil publish` — guided flow (install → test → pack preview → publish → tag), `--dry-run` + power-user flags
- [x] `ErrorAdvisor` — localized, actionable guidance on publish failures (7 langs)
- [x] **SwiftUI app** — `ClioilApp`: browse projects, see readiness, and **publish from the window** (reepub-themed). Double-clickable `.app` via `scripts/build-app.sh`.
- [~] App: menu-bar (MenuBarExtra) mode + live-streaming publish log — shipped in
      code (`MenuBarPublishView`, with cancel) and builds; not yet runtime-dogfooded
      (a menu-bar GUI can't be verified headlessly, so it stays unchecked until then).
- [~] **Friendly guidance via Apple Intelligence** — on-device Foundation Models
      translate ugly registry errors into plain-language next steps. *Done:* the
      `publish --ai` remediation hint (on-device first → Claude API only if a key is
      set → built-in guidance), via `RemediationAdvisor`. *Still pending:* drafting
      changelogs, and surfacing the hint in the app.
      *Honest scope:* the on-device ~3B model is great for guidance/classification/summary,
      not heavy stack-trace reasoning — for genuine debugging it optionally escalates
      to a larger model (Claude API). On-device first, cloud only when stuck.
- [x] **GitHub Releases + Homebrew — *prepare* path** (`clioil release`): generate the
      tag, tarball URL, local SHA-256 preview, formula, and the exact publish commands.
      Cutting the actual release stays a human step (clioil never tags/releases/pushes).
- [~] More ecosystems: **PyPI, crates** — *prepare* path done (`clioil prepare`:
      preview commands + the registry's own safe dry-run, never uploads). Still
      pending: the *execute* side for these (and for `release`), behind explicit confirm.

## Languages

The UI is localized into 7 languages, tagged with full BCP-47 codes (the shared
convention across our OSS projects):

`en-US` · `es-ES` · `ja-JP` · `zh-TW` · `ko-KR` · `fr-FR` · `de-DE`

It auto-detects from your locale; override per-run with `--lang=<code>` or the
`CLIOIL_LANG` environment variable (both full and short forms are accepted):

```bash
clioil --lang=ja-JP list
CLIOIL_LANG=zh-TW clioil help
```

Translations live in `ClioilCore/L10n.swift` as exhaustive `switch`es, so adding
a language is a compile error until every string is translated — the UI can't
ship half-localized. (Simplified Chinese is intentionally omitted; any `zh-*`
locale maps to `zh-TW`.)

## Requirements

- macOS 13+
- Swift 6 toolchain (Command Line Tools is enough to build the CLI)

## License

MIT — see [LICENSE](LICENSE).
