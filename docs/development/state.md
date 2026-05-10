# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.3.0** — M2 close (chakshu-driven extensions). v0.2.0 was the donor port from cyim/src/tty.cyr (2026-05-09); v0.3.0 adds `tty_winsize` (TIOCGWINSZ), `tty_open_signalfd(mask)` + TTY_SIGMASK_EXIT/WINCH constants, and `tty_clear_to_eol/to_end` ANSI helpers. Driven by chakshu's M2 Slice D needs (dynamic resize). Pure additions — v0.2.0 consumers unaffected.

## Toolchain

- **Cyrius pin**: `5.10.20` (in `cyrius.cyml [package].cyrius`, via `${file:VERSION}` indirection on the package version). Matches the chakshu pin so the two repos move together until a hard reason forces them apart.

## Source

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | ~225 | `TIO_*` flags, `tio_load32/store32`, `tty_apply_raw_flags`, `tty_raw`, `tty_cooked`, **v0.3.0:** `TIOCGWINSZ`, `TTY_SIGMASK_EXIT/WINCH`, `tty_winsize`, `tty_open_signalfd`. Linux-only via `#ifdef CYRIUS_TARGET_LINUX`. |
| `src/ansi.cyr` | ~75 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`, **v0.3.0:** `tty_clear_to_eol`, `tty_clear_to_end`. Any vt100-compatible terminal. |
| `src/cursor.cyr` | ~50 | `tty_itoa`, `tty_move`. Composes the CSI row;colH escape inline. |
| `src/main.cyr` | 14 | Convenience entry — `include`s the three sub-modules so smoke + tests get the whole surface in one shot. |
| `programs/smoke.cyr` | ~17 | Compile-link smoke. |
| `dist/darshana.cyr` | 340 | Bundled distribution (regenerate via `cyrius distlib`). What consumers `include "lib/darshana.cyr"`. |

Total source ≈ 365 lines (v0.3.0). All public symbol names match cyim's donor for the v0.2.0 surface — Phase 4 cyim migration is a manifest swap. v0.3.0 additions are new (no donor counterpart) and extraction-ready for any future consumer.

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | **44 assertions across 6 groups** — pure-function coverage of `tio_load32/store32`, `tty_apply_raw_flags` (every flag bit + idempotence), `tty_itoa` (zero / negative / 1–3 digits / position offset), and the v0.3.0 constant set (`TTY_SIGMASK_EXIT/WINCH` math + disjointness, `TIOCGWINSZ` ABI). TTY-bound functions (`tty_raw`, `tty_winsize`, `tty_open_signalfd`) exercised end-to-end via cyim's PTY smoke at Phase 4. |
| `tests/darshana.bcyr` | bench stub — not exercised |
| `tests/darshana.fcyr` | fuzz stub — not exercised |

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert`. Tightened from the init default (`string / fmt / alloc / io / vec / str / syscalls / assert`) — the donor surface uses none of `vec / str / fmt / string`.

## Consumers

| Consumer | Status |
|----------|--------|
| [chakshu](https://github.com/MacCracken/chakshu) | **Live on v0.2.0** since chakshu's 0.2.1 (M2 Slice A); will bump to v0.3.0 for M2 Slice D (dynamic resize). |
| [cyim](https://github.com/MacCracken/cyim) | Not yet integrated. Pending Phase 4 migration (drops `cyim/src/tty.cyr`, depends on darshana). |

Planned (legacy table):

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
- M1 (v0.2.0) — donor port ✓
- M2 (v0.3.0) — chakshu-driven extensions ✓ **(this release)** — `tty_winsize`, `tty_open_signalfd`, partial-clear helpers, TTY_SIGMASK_*
- M3 (v0.4.0) — cyim integration (drops its private tty.cyr) — not started
- M4 (v0.5.0) — chakshu integration confirmed (chakshu picked up darshana at its M2 Slice A in v0.2.1) ✓ in spirit; formal close when chakshu M2 ships at v0.5.0
- M5 (v1.0.0) — both consumers green for ≥30 days — not started

See [`roadmap.md`](roadmap.md) for the full milestone definitions.
