# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.5.4** — *open cycle*. Toolchain-only bump `6.0.1` → `6.1.24`
(catch-up to the ecosystem-wide cycc; the wrapper had already
drifted, the manifest pin was stale). `cyrius update` refreshed
`lib/` (101 files); no source changes, dist bundle bytes unchanged.
Build clean, all 144 assertions green on the new toolchain. No API
surface change; consumers (cyim 1.7.1, chakshu 0.6.1, bannermanor,
anuenue 0.7.0) unaffected.

**0.5.1** — *open cycle*. anuenue's M1 (the AGNOS rainbow pipe-filter,
scaffolded 2026-05-21) is the first consumer to need 24-bit SGR.
Adds five new public symbols (`tty_fg_rgb`, `tty_bg_rgb`,
`tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf`) — the `_buf`
variants close the v0.3.5 deferred "Phase 3 may add buf-targeting
variants" note. 50 new assertions land alongside (10 groups → 14).
No breaking changes; v0.5.0 consumers (cyim 1.7.1, chakshu 0.6.1)
unaffected. Tag pending close-ceremony.

**0.5.0** — tagged 2026-05-20. **M4 closed.** chakshu shipped its
Full TUI at chakshu 0.5.0 (2026-05-19) on darshana 0.3.0,
satisfying the M4 gate; chakshu 0.6.1 bumped to darshana 0.4.1 as
the close ceremony. From darshana's side this is a test-coverage
release: live-fd-gated tests for `tty_winsize` and
`tty_open_signalfd` added, closing the deferred-hardening item #5.
No new public functions; dist bundle bytes match v0.4.1 (the
test-only additions live in `tests/darshana.tcyr`).

**0.4.1** — tagged 2026-05-20. Doc-only patch following the M3
close. Tightens `TIO_BUF_SIZE` and `tty_winsize` docstrings
(deferred-hardening items #3 and #4 from the 0.4.0 audit) and
drops the "pending push" hedging from state.md / roadmap.md now
that cyim 1.7.1 made the M3 gate fact. Bundle gains ~18 lines of
documentation; behavior unchanged.

**0.4.0** — tagged 2026-05-20. **M3 closed.** One hardening change
(`tty_sgr` now rejects codes outside `[0, 999]` with `-1` before
writing) and one ADR (0002 — termios state-restore posture). No new
public functions; no breaking changes. cyim shipped 1.7.1 the same
day with `[deps.darshana].tag = "0.4.0"` + cyrius pin 6.0.1,
satisfying the M3 gate.

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

- **Cyrius pin**: `6.1.24` (in `cyrius.cyml [package].cyrius`, via
  `${file:VERSION}` indirection on the package version). Bumped from
  `6.0.1` at v0.5.4 (`5.10.20` → `6.0.1` was v0.3.5) — caught up to
  the ecosystem-wide cycc.

## Source

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | ~235 | `TIO_*` flags, `tio_load32/store32`, `tty_apply_raw_flags`, `tty_raw`, `tty_cooked`, **v0.3.0:** `TIOCGWINSZ`, `TTY_SIGMASK_EXIT/WINCH`, `tty_winsize`, `tty_open_signalfd`. **v0.4.1:** tightened docstrings on `TIO_BUF_SIZE` (canonical-name + Cyrius array-size constraint) and `tty_winsize` (i64 out-pointer contract). Linux-only via `#ifdef CYRIUS_TARGET_LINUX`. |
| `src/ansi.cyr` | ~290 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`, **v0.3.0:** `tty_clear_to_eol`, `tty_clear_to_end`, **v0.3.5:** `tty_sgr`, `tty_sgr_reset`, 16 `TTY_FG_*` constants. **v0.4.0:** `tty_sgr` validates input range `[0, 999]`. **v0.5.1:** `tty_fg_rgb`, `tty_bg_rgb`, `tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf` — 24-bit SGR with per-channel `[0, 255]` bounds rejection; `_buf` variants compose into a caller buffer for batched single-write frames. Any vt100-compatible terminal. |
| `src/cursor.cyr` | ~50 | `tty_itoa`, `tty_move`. Composes the CSI row;colH escape inline. |
| `src/main.cyr` | 14 | Convenience entry — `include`s the three sub-modules so smoke + tests get the whole surface in one shot. |
| `programs/smoke.cyr` | ~17 | Compile-link smoke. |
| `dist/darshana.cyr` | 448 | Bundled distribution (regenerate via `cyrius distlib`). What consumers `include "lib/darshana.cyr"`. |

Total source ≈ 450 lines (v0.4.1; docstring expansion versus 0.4.0). All public symbol names match cyim's donor for the v0.2.0 surface — cyim's migration to darshana is a manifest swap (cyim 1.7.0 picked this up at darshana 0.2.0; bumped to 0.4.0 at cyim 1.7.1). v0.3.0+ additions are extension-only (no donor counterpart) and extraction-ready for any future consumer.

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | **98–100 assertions across 14 groups** (count depends on TTY-availability in the runner — 98 when stdin is not a TTY, 100 when it is): pure-function coverage of `tio_load32/store32`, `tty_apply_raw_flags` (every flag bit + idempotence), `tty_itoa` (zero / negative / 1–3 digits / position offset), the v0.3.0 constant set (`TTY_SIGMASK_EXIT/WINCH` math + disjointness, `TIOCGWINSZ` ABI), the v0.4.0 `tty_sgr` rejection paths, **v0.5.0** live-fd tests for `tty_winsize` and `tty_open_signalfd`, and **v0.5.1** truecolor coverage: `_ansi_emit_u8` digit encoding, `tty_fg_rgb_buf` / `tty_bg_rgb_buf` exact-byte verification, per-channel bounds rejection on both `_buf` and direct variants, `tty_sgr_reset_buf` exact bytes + position-offset. `tty_raw/cooked` and valid-code SGR emission still exercised end-to-end via consumer PTY smoke. |
| `tests/darshana.bcyr` | bench stub — not exercised |
| `tests/darshana.fcyr` | fuzz stub — not exercised |

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert`. Tightened from the init default (`string / fmt / alloc / io / vec / str / syscalls / assert`) — the donor surface uses none of `vec / str / fmt / string`.

## Consumers

| Consumer | Status |
|----------|--------|
| [chakshu](https://github.com/MacCracken/chakshu) | **Live on v0.4.1** since chakshu 0.6.1 (2026-05-20). chakshu's M2 (Full TUI) shipped at chakshu 0.5.0 on darshana 0.3.0 — satisfying darshana's M4 gate "chakshu M2 closes ... using darshana." M2.5 (mihi integration) shipped at chakshu 0.6.0 the next day; 0.6.1 advances darshana 0.3.0 → 0.4.1 as the M4 close ceremony. chakshu exercises `tty_raw/cooked`, `tty_alt_*`, `tty_clear_to_eol/end`, `tty_cursor_*`, `tty_move`, `tty_winsize`, `tty_open_signalfd`, `TTY_SIGMASK_EXIT/WINCH` — full v0.3.0 surface. |
| [cyim](https://github.com/MacCracken/cyim) | **Live on v0.4.0** + cyrius 6.0.1 since cyim 1.7.1 (2026-05-20). 1.7.0 was the original adopter on darshana 0.2.0; 1.7.1 closed M3. `cyim/src/tty.cyr` reduced from ~207 lines to 38 (only the cyim-specific `tty_probe` stays local); 25 callsites in cyim/src/ resolve against darshana symbols. |
| [bannermanor](https://github.com/MacCracken/bannermanor) | Wiring v0.3.5 in for bnrmr's M5 (`bnrmr --color cyan TEXT`). First non-TUI consumer; uses `tty_sgr` + `TTY_FG_*` constants only. Drove the v0.3.5 SGR addition. |
| [anuenue](https://github.com/MacCracken/anuenue) | Open cycle on **v0.5.1** for M1 (`echo X \| anuenue` → rainbow ASCII). First pipe-decorator consumer; uses the new `tty_fg_rgb_buf` + `tty_sgr_reset_buf` to compose per-character escapes into a line buffer for one-write-per-line throughput. Drove the v0.5.1 truecolor addition. |

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
- M3 (v0.4.0) — cyim integration milestone ✓ **(this release)**. cyim 1.7.0 was the original adopter on darshana 0.2.0; cyim 1.7.1 (2026-05-20) bumped to darshana 0.4.0 + cyrius 6.0.1 and satisfied the M3 gate ("cyim CI green on the integrated branch").
- M4 (v0.5.0) — chakshu integration ✓ **closed 2026-05-20**. chakshu's M2 (Full TUI) shipped at chakshu 0.5.0 on darshana 0.3.0; chakshu 0.6.1 advanced to darshana 0.4.1 as the close ceremony. Both consumers (cyim 1.7.1, chakshu 0.6.1) are now on the same dep pin.
- **Soak-window cuts** (v0.6.0 / v0.8.0) — planned during the M5 calendar gate:
    - v0.6.0 — in-repo PTY harness (early soak); closes the two v1.0 "API frozen — tested" + "test coverage adequate" partials.
    - v0.8.0 — `docs/examples/` + final API audit + `docs/architecture/` notes (late soak); pre-freeze polish on the actual v1.0 surface.
    - See [`roadmap.md`](roadmap.md) §Soak-window cuts for the full plan + per-cut checklist.
- M5 (v1.0.0) — both consumers green for ≥30 days — calendar-gated from 2026-05-20; earliest viable cut ~2026-06-19.

See [`roadmap.md`](roadmap.md) for the full milestone definitions.
