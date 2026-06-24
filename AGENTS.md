# AGENTS.md — driving clioil as an agent

You are likely an AI coding agent (Claude Code, Codex, Antigravity, …) being asked to
ship a package with clioil. This file is your front door: read it and you can wield
clioil correctly on the first try. (Human-facing intro is in [README.md](README.md);
every command also self-documents — see `clioil help`.)

## What clioil is, in one breath

clioil turns "publish this package" into one guided flow instead of a pile of
ecosystem-specific incantations. It's a pure-Swift CLI (plus an optional SwiftUI app),
native to the Mac. **Publishing is outward-facing and higher-stakes than editing
code** — the real publish is the only irreversible step, and it always demands an
explicit human confirmation. Treat clioil as a careful shipping tool, not a code editor.

## Driving it headless (the part you'll actually use)

```bash
swift run clioil list                          # scan ~ / ~/Developer for publishable projects
swift run clioil status <project> --json       # read-only readiness report (npm latest, dirty tree, commits since tag)
swift run clioil publish <project> --dry-run   # full guided flow, STOPS before the real publish — always safe
swift run clioil release <project> --json      # PREPARE a GitHub Release + Homebrew formula (preview only, never publishes)
swift run clioil prepare <project>             # PREPARE a PyPI/crates publish (prints commands; --dry-run runs the registry's own safe check)
```

`<project>` is a name or path fragment; an ambiguous or missing match prints the
candidate list and exits non-zero — never guesses. Power-user flags on `publish`:
`--bump <patch|minor|major>`, `--no-test`, `--no-install`, `--yes`, `--dry-run`.
Global: `--json`, `--lang=<code>` (BCP-47, e.g. `ja-JP`). Optional `--ai` adds an
error-remediation hint (on-device Apple Foundation Models → Claude API only if a key
is present → built-in guidance).

## Non-negotiable rules (break one and you ship something you shouldn't)

1. **Only `publish` ever mutates the outside world**, and only at its final
   confirmation step. `list`, `status`, `release`, and `prepare` are read-only /
   preview-only by design — `release` and `prepare` print the exact commands and
   never tag, cut a release, push a tap, or upload anything. Do not reimplement those
   missing steps with raw `npm publish` / `gh release create` / `git push` to "finish
   the job."
2. **The real publish is the human's gate, not yours.** It needs interactive browser
   passkey auth (`npm publish --auth-type=web`) and an explicit confirm. Don't trick
   your way past it with `--yes` on a non-dry run unless the human told you to. User
   excitement is not authorization.
3. **Default to `--dry-run` when you're verifying.** It runs the whole flow (install →
   test → pack preview) and stops at the cliff. Show that output; let the human take
   the last step.
4. **Resolve the right target.** Two checkouts of the same package can both match a
   name fragment — when clioil prints a pick-one list, pick deliberately; never ship
   to the wrong one.

## Honest scope (don't claim more than is here)

- **npm** is the only ecosystem with a real, audited *publish* flow today.
- **PyPI / crates** are `prepare`-only (preview + the registry's own safe dry-run).
- **GitHub Releases + Homebrew** are `release`-only (prepare path: tag, tarball URL,
  local SHA-256, formula, and the commands — cutting it stays a human action).

## Where to look

- [README.md](README.md) — what's real today, architecture, roadmap.
- `swift run clioil help` (or any command) — self-documenting; trust it over guessing.
- Requirements: macOS 13+, a Swift 6 toolchain to build.
