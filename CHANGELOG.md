# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_No unreleased changes._

## [0.1.0] — 2026-05-09

Initial scaffold. No working code yet — the donor port from
`cyim/src/tty.cyr` lands at M1 (v0.2.0). See
[`docs/development/roadmap.md`](docs/development/roadmap.md) for the
arc to v1.0.

### Added

- Repo scaffolded via `cyrius init --lib darshana`.
- `cyrius.cyml` library manifest. Cyrius toolchain pinned to 5.10.20
  (matches chakshu, the first downstream consumer).
- `src/main.cyr` — header-only library entry; domain modules will
  be split per the roadmap (`termios.cyr`, `ansi.cyr`, `cursor.cyr`)
  when M1 lands.
- `programs/smoke.cyr` — compile-link smoke that proves the include
  chain resolves.
- `tests/darshana.{tcyr,bcyr,fcyr}` — test/bench/fuzz harness stubs.
- `docs/development/{roadmap,state}.md` — milestone arc + live state.
- `docs/adr/0001-name-darshana.md` — name choice (Sanskrit observation
  family — `drishya` considered and rejected).
- `.github/workflows/{ci,release}.yml` — CI on push/PR + tag-triggered
  release pipeline.
- `LICENSE` — GPL-3.0-only (matches chakshu / cyim).

### Notes

- No working API yet. Don't depend on this version — wait for M1.
