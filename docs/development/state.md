# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-09 via `cyrius init --lib darshana`. No releases tagged yet; M1 (donor port) is the next checkpoint.

## Toolchain

- **Cyrius pin**: `5.10.20` (in `cyrius.cyml [package].cyrius`). Matches the chakshu pin so the two repos move together until a hard reason forces them apart.

## Source

Initial scaffold only:
- `src/main.cyr` — header-only library entry; M1 splits into `src/{termios,ansi,cursor}.cyr`.
- `programs/smoke.cyr` — proves the include chain compiles.

No working API surface yet. **Don't depend on this version.**

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | 2 assertions — placeholder smoke (true is true; 1+1==2) |
| `tests/darshana.bcyr` | bench stub — not exercised |
| `tests/darshana.fcyr` | fuzz stub — not exercised |

Real tests land alongside the M1 donor port.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`. Footprint will tighten in M1 — termios + ANSI doesn't need `vec`/`fmt`/`str`.

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
