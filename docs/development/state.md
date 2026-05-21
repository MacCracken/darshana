# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.4.0** — tagged 2026-05-20. M3 milestone cut. One hardening
change (`tty_sgr` now rejects codes outside `[0, 999]` with `-1`
before writing) and one ADR (0002 — termios state-restore posture).
No new public functions; no breaking changes. The M3 *close
ceremony* (state.md consumers table updated, roadmap M3 ✓) lands as
a separate doc-only commit after cyim CI is green on the bumped dep
— see Roadmap status below.

**0.3.5** — tagged 2026-05-20. SGR helpers (`tty_sgr`,
`tty_sgr_reset`, 16 named foreground-color constants) added for
bannermanor's M5 (`bnrmr --color cyan TEXT`). Toolchain pin caught
up to ecosystem-wide 6.0.1. Pure additions on the API surface;
v0.3.0 consumers unaffected.

**0.3.0** — tagged 2026-05-09. M2 close (chakshu-driven extensions).
v0.2.0 was the donor port from cyim/src/tty.cyr; v0.3.0 added
`tty_winsize` (TIOCGWINSZ), `tty_open_signalfd(mask)` +
TTY_SIGMASK_EXIT/WINCH constants, and `tty_clear_to_eol/to_end`
ANSI helpers. Driven by chakshu's M2 Slice D needs (dynamic resize).

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`, via
  `${file:VERSION}` indirection on the package version). Bumped from
  `5.10.20` at v0.3.5 — caught up to the ecosystem-wide cycc.

## Source

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | ~225 | `TIO_*` flags, `tio_load32/store32`, `tty_apply_raw_flags`, `tty_raw`, `tty_cooked`, **v0.3.0:** `TIOCGWINSZ`, `TTY_SIGMASK_EXIT/WINCH`, `tty_winsize`, `tty_open_signalfd`. Linux-only via `#ifdef CYRIUS_TARGET_LINUX`. |
| `src/ansi.cyr` | ~170 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`, **v0.3.0:** `tty_clear_to_eol`, `tty_clear_to_end`, **v0.3.5:** `tty_sgr`, `tty_sgr_reset`, 16 `TTY_FG_*` constants. **v0.4.0:** `tty_sgr` validates input range `[0, 999]`. Any vt100-compatible terminal. |
| `src/cursor.cyr` | ~50 | `tty_itoa`, `tty_move`. Composes the CSI row;colH escape inline. |
| `src/main.cyr` | 14 | Convenience entry — `include`s the three sub-modules so smoke + tests get the whole surface in one shot. |
| `programs/smoke.cyr` | ~17 | Compile-link smoke. |
| `dist/darshana.cyr` | 430 | Bundled distribution (regenerate via `cyrius distlib`). What consumers `include "lib/darshana.cyr"`. |

Total source ≈ 460 lines (v0.4.0). All public symbol names match cyim's donor for the v0.2.0 surface — cyim's migration to darshana is a manifest swap (cyim 1.7.0 picked this up at darshana 0.2.0). v0.3.0+ additions are extension-only (no donor counterpart) and extraction-ready for any future consumer.

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | **47 assertions across 7 groups** — pure-function coverage of `tio_load32/store32`, `tty_apply_raw_flags` (every flag bit + idempotence), `tty_itoa` (zero / negative / 1–3 digits / position offset), the v0.3.0 constant set (`TTY_SIGMASK_EXIT/WINCH` math + disjointness, `TIOCGWINSZ` ABI), and the v0.4.0 `tty_sgr` rejection paths. TTY-bound functions (`tty_raw`, `tty_winsize`, `tty_open_signalfd`) and `tty_sgr` valid-code emission exercised end-to-end via cyim's PTY smoke at Phase 4. |
| `tests/darshana.bcyr` | bench stub — not exercised |
| `tests/darshana.fcyr` | fuzz stub — not exercised |

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert`. Tightened from the init default (`string / fmt / alloc / io / vec / str / syscalls / assert`) — the donor surface uses none of `vec / str / fmt / string`.

## Consumers

| Consumer | Status |
|----------|--------|
| [chakshu](https://github.com/MacCracken/chakshu) | **Live on v0.2.0** since chakshu's 0.2.1 (M2 Slice A); will bump to v0.3.0 for M2 Slice D (dynamic resize). |
| [cyim](https://github.com/MacCracken/cyim) | **Bumped to v0.4.0** + cyrius 6.0.1 on 2026-05-20. cyim 1.7.0 has been the live darshana consumer since picking up darshana 0.2.0; `cyim/src/tty.cyr` reduced from ~207 lines to 38 (only the cyim-specific `tty_probe` stays local); 25 callsites in cyim/src/ resolve against darshana symbols. Local build + tests green on the bumped manifest; remote CI green pending push. |
| [bannermanor](https://github.com/MacCracken/bannermanor) | Wiring v0.3.5 in for bnrmr's M5 (`bnrmr --color cyan TEXT`). First non-TUI consumer; uses `tty_sgr` + `TTY_FG_*` constants only. Drove the v0.3.5 SGR addition. |

## Carry-Forward

- ADR 0001 records the `darshana` name choice (`drishya` and other observation-family alternatives considered). Closed; no re-litigation needed.
- macOS support is deferred — see CLAUDE.md domain rules.

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — three jobs: build-and-test (lint, smoke binary, `cyrius test`, `scripts/smoke.sh`, distlib drift, DCE parity); security scan (no FFI imports, no >=64K stack buffers, Linux gate intact); docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml via `workflow_call`, version-verify against tag, regenerates dist + ships `darshana-X.Y.Z.cyr` standalone + `darshana-X.Y.Z.tar.gz` package + source tarball + SHA256SUMS, GH release with body extracted from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — runs smoke binary, verifies dist drift, asserts cyim-API contract surface (19 `tty_*` / `tio_*` symbols + 35 `TIO_* / TTY_*` constants present in dist as of v0.3.5), checks `CYRIUS_TARGET_LINUX` gate intact |
| Cutting a release | Bump VERSION + CHANGELOG section, push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

## Roadmap status

- M0 (v0.1.0) — scaffold ✓
- M1 (v0.2.0) — donor port ✓
- M2 (v0.3.0) — chakshu-driven extensions ✓ — `tty_winsize`, `tty_open_signalfd`, partial-clear helpers, TTY_SIGMASK_*
- M3 (v0.4.0) — cyim integration milestone ✓ **(this release)**. cyim 1.7.0 has been live on darshana 0.2.0 since its port; M3 ceremony bumped cyim's manifest to darshana 0.4.0 + cyrius 6.0.1 on 2026-05-20 with local build + tests green. Remote CI green is pending the darshana tag push + cyim PR (gate stays "cyim CI green on the integrated branch").
- M4 (v0.5.0) — chakshu integration confirmed (chakshu picked up darshana at its M2 Slice A in v0.2.1) ✓ in spirit; formal close when chakshu M2 ships at v0.5.0
- M5 (v1.0.0) — both consumers green for ≥30 days — not started

See [`roadmap.md`](roadmap.md) for the full milestone definitions.
