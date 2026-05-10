# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — M1 close (donor port from cyim/src/tty.cyr). v0.1.0 was the `cyrius init` scaffold (2026-05-09). The next milestone (M2 — chakshu-driven extensions: SIGWINCH, TIOCGWINSZ, partial-clear ANSI helpers) opens when chakshu enters its M2 TUI work.

## Toolchain

- **Cyrius pin**: `5.10.20` (in `cyrius.cyml [package].cyrius`, via `${file:VERSION}` indirection on the package version). Matches the chakshu pin so the two repos move together until a hard reason forces them apart.

## Source

M1 donor port from cyim/src/tty.cyr landed at v0.2.0:

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | ~160 | `TIO_*` flags, `tio_load32/store32`, `tty_apply_raw_flags`, `tty_raw`, `tty_cooked`. Linux-only via `#ifdef CYRIUS_TARGET_LINUX`. |
| `src/ansi.cyr` | ~50 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`. Any vt100-compatible terminal. |
| `src/cursor.cyr` | ~50 | `tty_itoa`, `tty_move`. Composes the CSI row;colH escape inline. |
| `src/main.cyr` | 14 | Convenience entry — `include`s the three sub-modules so smoke + tests get the whole surface in one shot. |
| `programs/smoke.cyr` | ~17 | Compile-link smoke. |
| `dist/darshana.cyr` | 271 | Bundled distribution (regenerate via `cyrius distlib`). What consumers `include "lib/darshana.cyr"`. |

Total source ≈ 270 lines. All public symbol names match cyim's donor — Phase 4 cyim migration is a manifest swap, not a rename.

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | **40 assertions across 4 groups** — pure-function coverage of `tio_load32/store32`, `tty_apply_raw_flags` (every flag bit + idempotence), `tty_itoa` (zero / negative / 1–3 digits / position offset). TTY-bound functions exercised end-to-end via cyim's PTY smoke at Phase 4. |
| `tests/darshana.bcyr` | bench stub — not exercised |
| `tests/darshana.fcyr` | fuzz stub — not exercised |

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert`. Tightened from the init default (`string / fmt / alloc / io / vec / str / syscalls / assert`) — the donor surface uses none of `vec / str / fmt / string`.

## Consumers

_None integrated yet._ Planned:

| Consumer | Phase | Status |
|----------|-------|--------|
| [cyim](https://github.com/MacCracken/cyim) | M3 — drops its private `src/tty.cyr` and depends on darshana | not started |
| [chakshu](https://github.com/MacCracken/chakshu) | M4 — picks up darshana for its M2 TUI work | not started |

## Carry-Forward

- ADR 0001 records the `darshana` name choice (`drishya` and other observation-family alternatives considered). Closed; no re-litigation needed.
- macOS support is deferred — see CLAUDE.md domain rules.

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — three jobs: build-and-test (lint, smoke binary, `cyrius test`, `scripts/smoke.sh`, distlib drift, DCE parity); security scan (no FFI imports, no >=64K stack buffers, Linux gate intact); docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml via `workflow_call`, version-verify against tag, regenerates dist + ships `darshana-X.Y.Z.cyr` standalone + `darshana-X.Y.Z.tar.gz` package + source tarball + SHA256SUMS, GH release with body extracted from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — runs smoke binary, verifies dist drift, asserts cyim-API contract surface (13 `tty_*` / `tio_*` symbols + 16 `TIO_*` constants present in dist), checks `CYRIUS_TARGET_LINUX` gate intact |
| Cutting a release | Bump VERSION + CHANGELOG section, push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

## Roadmap status

- M0 (v0.1.0) — scaffold ✓
- M1 (v0.2.0) — donor port ✓ **(this release)**
- M2 (v0.3.0) — chakshu-driven extensions (SIGWINCH, TIOCGWINSZ, partial-clear ANSI) — not started; opens when chakshu enters M2
- M3 (v0.4.0) — cyim integration (drops its private tty.cyr) — not started
- M4 (v0.5.0) — chakshu integration (picks up darshana) — not started
- M5 (v1.0.0) — both consumers green for ≥30 days — not started

See [`roadmap.md`](roadmap.md) for the full milestone definitions.
