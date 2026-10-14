# PLAN — non-npm (Homebrew / gh-release) publishing

Goal: **clioil can publish a non-npm CLI tool shipped via a Homebrew tap** — e.g.
[`sheersweep`](https://github.com/CVERInc/sheersweep) (a bash CLI at `~/code/sheersweep`,
tap at `~/code/homebrew-sheersweep`) — end to end, with the SAME guided / dry-run /
confirm / ErrorAdvisor / i18n DNA the npm path already has. This is "ecosystem #2"
on top of the already-working npm core; the `Publisher` protocol was designed for it
("PyPI, crates, GitHub Releases, Homebrew next").

## Ground truth (read these first)
- `Sources/ClioilCore/Publisher.swift` — `Publisher` protocol + `NpmPublisher` (read-only queries done).
- `Sources/ClioilCore/PublishOps.swift` — npm mutating ops (real `npm publish`, bump, packPreview).
- `Sources/ClioilCore/Project.swift` — project model (currently npm-centric: name/version from package.json).
- `Sources/ClioilCore/ProjectScanner.swift` — scans `~/Desktop/GitHub` for npm projects (package.json).
- `Sources/clioil/main.swift` — the `list` / `status` / `publish` flow (publish: bump→preflight→install→test→preview→dry-run stop→confirm→`ops.publish`→commit+tag).
- `Sources/ClioilCore/{Git,Shell,L10n*,ErrorAdvisor,Bump,Version}.swift`.

## Scope (minimal, 克制 — do NOT build a giant plugin framework)
1. **Generalize `Project`** with a `kind` (`.npm` / `.homebrewTap`) and a kind-aware
   version source. npm = package.json `.version`; homebrewTap = a `VERSION="x.y.z"`
   line in the repo-root executable script (sheersweep's pattern). Keep npm behaviour
   byte-identical.
2. **`ProjectScanner`**: also scan `~/code` (in addition to `~/Desktop/GitHub`; make the
   root list a small constant or config). Detect a homebrewTap project by a simple,
   documented heuristic: repo has NO `package.json` but HAS a repo-root executable
   named like the repo containing a `VERSION=` line, AND a sibling tap repo
   `homebrew-<name>` (look under the same parent dir, e.g. `~/code/homebrew-sheersweep`).
3. **`HomebrewPublisher: Publisher`**: `latestPublishedVersion` = newest `vX` git tag /
   gh release; `versionExists` = that tag/release exists. Plus mutating ops (in
   PublishOps or a sibling): create the gh release (`gh release create vX`), compute the
   release tarball `sha256`, rewrite the tap formula's `url` + `sha256`, commit the tap.
   Mirror the manual sheersweep steps (see that repo's history).
4. **Publish flow per kind** (generalize main.swift / extract a small `PublishFlow`):
   - npm (unchanged): install → test → npm publish → commit+tag.
   - homebrewTap: version from script → preview (what the release/formula will become)
     → **dry-run stops here** → confirm → `gh release create` → bump tap formula
     sha256 → commit tap. The irreversible step (gh release) requires explicit confirm.
5. **i18n**: any new user-facing strings go through `L10n` (en-US / ja-JP / zh-TW).
6. **Tests** (`Sources/ClioilTests`, framework-free, NO network): project-kind
   detection, `VERSION=` parsing, formula sha/url rewrite (pure string), the dry-run
   path stops before any irreversible call. Stub Shell/git/network.

## Definition of done (hard gate — all must hold before finishing)
- `swift build` clean, `swift run ClioilTests` green (existing npm tests UNCHANGED + new ones).
- `swift run clioil list` shows `sheersweep` (from `~/code/sheersweep`) as a homebrewTap project.
- `swift run clioil publish sheersweep --dry-run` walks the homebrew flow and **stops
  before** the gh release (no side effects).
- npm path + its tests behave exactly as before.
- Stale self-deprecation fixed: update `README.md` + the `Publisher.swift` comment that
  claim "publish still lives in the shell prototype / early skeleton" — the npm publish
  is implemented and working; say so accurately (and note Homebrew is now supported too).

## Constraints
- Work ONLY in this repo, on the current branch. **Do NOT push, do NOT open PRs, do NOT
  run any real `gh release` / `npm publish` / formula push** (dry-run + unit tests only).
- Keep build + tests GREEN at every commit. Commit in logical steps.
- Follow existing code style and the CVER 危險操作 DNA (preview → confirm → evidence →
  never silently destructive). Don't over-engineer.
- If you cannot fully finish, STOP at a state where `swift build` + tests are GREEN, with
  partial progress committed, and document exactly what's left.
- When finished (or stopping), write a summary + DoD checklist + remaining work to
  `/tmp/clioil-burn-result.md`.
