# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-09 via `cyrius init --lib darshana`. No releases tagged yet; M1 (donor port) is the next checkpoint.

## Toolchain

- **Cyrius pin**: `5.10.20` (in `cyrius.cyml [package].cyrius`). Matches the chakshu pin so the two repos move together until a hard reason forces them apart.

## Source

M1 donor port from cyim/src/tty.cyr landed (in [Unreleased]; v0.2.0 cuts when user tags):

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

## Next

See [`roadmap.md`](roadmap.md). M1 — donor port from `cyim/src/tty.cyr` — is the first real work.
