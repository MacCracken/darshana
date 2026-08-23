# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.9.2** — *open cycle*. aarch64-Linux ioctl fix. `src/termios.cyr`
hardcoded `var SYS_IOCTL = 16` (the x86_64 number) inside the arch-blind
`#ifdef CYRIUS_TARGET_LINUX` gate, shadowing the stdlib's arch-aware
definition; on aarch64 all five ioctl callsites issued syscall 16, which
is `fremovexattr` there, not `ioctl`. The 0.9.1 carry-forward left the
ESYSXLAT question open — now **verified as not translated**: the ELF
aarch64 branch of `src/backend/aarch64/emit.cyr`'s `ESYSXLAT` has no
`16→29` row, and the compiler's "syscall not routed" warning is
Mach-O-only, so the wrong number passed through silently. Fix drops the
local `var`; the stdlib resolves 16 on x86_64 and 29 on aarch64.
Confirmed in emitted machine code (callsites now materialize the
immediate `29`; `29` is never an `ESYSXLAT` source, so it reaches the
native `ioctl`). `TCGETS` / `TCSETS` / `TIOCGWINSZ` stay local —
arch-stable via `asm-generic/ioctls.h` and not stdlib-defined. Latent,
not live: no aarch64 consumer ships today. 199 assertions green.

**0.9.1** — *open cycle*. Toolchain-only bump `6.2.36` → `6.5.35`
(manifest pin had drifted stale behind the installed wrapper again;
builds were emitting both the pin-drift warning and a `./lib/ shadows
version-pinned` warning over nine behind-snapshot sibling libs).
`cyrius update` re-vendored `lib/` from the 6.5.35 snapshot — 69
modules refreshed, 17 added (`sys`, `ganita`, `yantra`, `bayan`,
`protobuf`, the per-platform `async_*` / `thread_*` / `regression_agnos`
splits, and the six `tls_native_*` shards). Sibling libs advanced:
mabda 3.0.1 → 4.1.0, vani 0.9.3 → 1.2.2, sigil 3.7.8 → 3.12.9, sandhi
1.4.10 → 1.9.10, sankoch 2.2.5 → 2.7.8, sakshi 2.2.10 → 2.4.11, patra
1.10.3 → 1.13.10, yukti 2.2.3 → 2.3.8, niyama 1.0.2 → 1.0.7. No source
or API change; `dist/darshana.cyr` regenerated only to stamp the new
`# Version:` header (module bodies byte-identical to 0.9.0). New
generated artifact: `dist/darshana.deps` (stdlib-leaf sidecar the
6.5.35 `cyrius distlib` emits). 199 assertions green.

**0.9.0** — *open cycle*. AGNOS parity for the signalfd path — agnos
peers for `tty_open_signalfd` / `tty_close_signalfd` plus agnos-specific
`TTY_SIGMASK_EXIT` (`0x8006`) / `TTY_SIGMASK_WINCH` (`0x10000000`)
values, since mirshi represents a signal set as `1 << sig` rather than
Linux's `1 << (sig-1)` sigset_t layout. Last Linux-only surface in
`src/termios.cyr`; chakshu's `--agnos` build failed to link on
`TTY_SIGMASK_EXIT` before it. No Linux-path or API change.

**0.8.2** — *open cycle*. AGNOS peers for `tty_isatty` / `tty_raw` /
`tty_cooked`. agnos has no termios: `tty_isatty` reports a tty when the
framebuffer console-grid syscall (`winsize`#60) succeeds, `tty_raw`
returns `-1` (consumers fall back to their line REPL), `tty_cooked` is a
no-op success. No Linux-path or API change.

**0.8.1** — *open cycle*. Toolchain-only bump `6.2.22` → `6.2.36`
(picks up the 6.2.31–6.2.36 agnos-stdlib fixes: `io.cyr` file-lock
SIGILL-stub fix, agnos mutex, `time_unix`#46). No source/API change.

**0.8.0** — *open cycle*. `tty_winsize` on AGNOS — the first
`#ifdef CYRIUS_TARGET_AGNOS` peer. agnos has no `ioctl`; the kernel
exposes the live framebuffer console grid via `winsize`#60, returning
both counts packed in one i64 (`high 16 = cols`, `low 16 = rows`).
The agnos branch unpacks that through the caller's out-pointers,
preserving the Linux `tty_winsize(fd, out_rows, out_cols)` → 0/-1
contract exactly. Requires agnos ≥ **1.45.13**.

**0.7.1** — *open cycle*. Toolchain-only bump `6.1.24` → `6.2.22`.

**0.7.0** — *open cycle*. Pre-freeze hardening / refactor / security /
freeze-readiness sweep (multi-agent review: 66 findings → 25 confirmed).
Deliberately includes **breaking** changes — cheap now, major-bump-
expensive after the v1.0 freeze. Breaking: `tty_cooked(fd)`→`tty_cooked()`
(single-raw-fd model; `_tty_raw_fd` added; 2nd concurrent raw fd refused);
`tty_itoa`→`tty_dec_buf` (return harmonized digit-count→new-position);
`tty_clear_to_end`→`tty_clear_to_eos`; `tty_apply_raw_flags` privatized.
Added: `tty_close_signalfd`; `tty_move` [1,65535] bounds. Security:
`SFD_CLOEXEC` on the signalfd; `tty_move` `buf[32]`→`[44]` overrun fix;
CI exec-sink scan.

**0.6.0** — *open cycle*. First soak-window cut: an in-repo PTY harness
(`tests/pty.tcyr`) that manufactures its own pseudo-terminal and drives
darshana's syscall-touching + escape-emitting surface against it.
Test-only. Closes the v1.0 "every symbol tested" + "state-restore paths
covered" partials.

**0.5.4** — toolchain-only bump `6.0.1` → `6.1.24`.

**0.5.1** — *open cycle*. anuenue's M1 (the AGNOS rainbow pipe-filter)
is the first consumer to need 24-bit SGR. Adds `tty_fg_rgb`,
`tty_bg_rgb`, `tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf`.

**0.5.0** — tagged 2026-05-20. **M4 closed.** chakshu shipped its Full
TUI at chakshu 0.5.0 (2026-05-19) on darshana 0.3.0, satisfying the M4
gate. Test-coverage release: live-fd-gated tests for `tty_winsize` and
`tty_open_signalfd`.

**0.4.1** — tagged 2026-05-20. Doc-only patch following the M3 close.

**0.4.0** — tagged 2026-05-20. **M3 closed.** `tty_sgr` now rejects
codes outside `[0, 999]`; ADR 0002 (termios state-restore posture).
cyim shipped 1.7.1 the same day satisfying the M3 gate.

**0.3.5** — tagged 2026-05-20. SGR helpers (`tty_sgr`, `tty_sgr_reset`,
16 named foreground-color constants) for bannermanor's M5.

**0.3.0** — tagged 2026-05-09. M2 close (chakshu-driven extensions):
`tty_winsize` (TIOCGWINSZ), `tty_open_signalfd(mask)` +
TTY_SIGMASK_EXIT/WINCH, `tty_clear_to_eol/to_end`.

## Toolchain

- **Cyrius pin**: `6.5.35` (in `cyrius.cyml [package].cyrius`, via
  `${file:VERSION}` indirection on the package version). Bumped from
  `6.2.36` at v0.9.1 — the manifest pin had drifted stale behind the
  installed wrapper again, and `lib/` was shadowing the pinned snapshot
  with nine behind-version sibling libs. History: `6.2.22` → `6.2.36`
  at v0.8.1; `6.1.24` → `6.2.22` at v0.7.1; `6.0.1` → `6.1.24` at
  v0.5.4; `5.10.20` → `6.0.1` at v0.3.5.
- `cyrius update` is the refresh procedure (additive — it re-vendors the
  pin snapshot into `lib/` but does not prune). Ten modules upstream has
  since dropped from the stdlib snapshot (`agnosys`, `base64`, `bigint`,
  `csv`, `cyml`, `json`, `linalg`, `matrix`, `toml`, `u128`) still sit in
  `lib/` from older snapshots; none is included by darshana's sources.

## Source

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | 463 | `TIO_*` flags, `tio_load32/store32`, `tty_raw`, `tty_cooked`, **v0.3.0:** `TIOCGWINSZ`, `TTY_SIGMASK_EXIT/WINCH`, `tty_winsize`, `tty_open_signalfd`. **v0.5.3:** `tty_isatty`. **v0.7.0:** `tty_cooked` is zero-arg (single-raw-fd model, `_tty_raw_fd`); `tty_apply_raw_flags` privatized → `_tty_apply_raw_flags`; `tty_close_signalfd` added; `SFD_CLOEXEC` on the signalfd. **v0.8.0–v0.9.0:** `#ifdef CYRIUS_TARGET_AGNOS` peers for all six syscall-touching entry points (`tty_winsize`, `tty_isatty`, `tty_raw`, `tty_cooked`, `tty_open_signalfd`, `tty_close_signalfd`) + agnos-specific `TTY_SIGMASK_*` values. Linux arm gated via `#ifdef CYRIUS_TARGET_LINUX`. **v0.9.2:** local `var SYS_IOCTL = 16` dropped — the Linux gate is arch-blind, so it shadowed the stdlib's arch-aware value and issued the x86_64 number on aarch64; `TCGETS`/`TCSETS`/`TIOCGWINSZ` stay local (arch-stable). |
| `src/ansi.cyr` | 352 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`, **v0.3.0:** `tty_clear_to_eol`, `tty_clear_to_eos` (renamed from `tty_clear_to_end` v0.7.0), **v0.3.5:** `tty_sgr`, `tty_sgr_reset`, 16 `TTY_FG_*` constants. **v0.4.0:** `tty_sgr` validates input range `[0, 999]`. **v0.5.1:** `tty_fg_rgb`, `tty_bg_rgb`, `tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf`. **v0.5.3:** `tty_sgr_buf`, `tty_fg_256_buf`. Any vt100-compatible terminal. |
| `src/cursor.cyr` | 107 | `tty_dec_buf` (decimal formatter — renamed from `tty_itoa`, returns new write position, v0.7.0), `tty_move` (with [1,65535] coord bounds + `buf[44]` v0.7.0), `tty_cursor_up/down`. Composes the CSI row;colH escape inline. |
| `src/main.cyr` | 35 | Convenience entry — `include`s the three sub-modules; carries the authoritative surface pointer (→ `scripts/smoke.sh`) + naming/return conventions (v0.7.0). Not in the dist bundle. |
| `programs/smoke.cyr` | 17 | Compile-link smoke. |
| `dist/darshana.cyr` | 922 | Bundled distribution — regenerate via `cyrius distlib`. What consumers `include "lib/darshana.cyr"`. (935 lines on disk; `distlib` reports module-body lines, excluding its 13-line generated header.) |
| `dist/darshana.deps` | 6 | Generated stdlib-leaf sidecar — 4 entries (v0.9.1; `syscalls`, `alloc`, `io`, `assert`). Consumed by a consumer's `cyrius deps`. |

Total source ≈ 922 lines across the three dist modules (grew from ~780
at v0.7.0 with the v0.8.0–v0.9.0 agnos peers, and by the v0.9.2
`SYS_IOCTL` comment block). Public fn surface is **29**
unique names — 35 definitions in the bundle, six of which are agnos/Linux
`#ifdef` peers of the same name (`scripts/smoke.sh` is authoritative and
self-audits bidirectionally).

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | **152 assertions** (a couple live-fd-gated): pure-function coverage of `tio_load32/store32`, `_tty_apply_raw_flags` (every flag bit + idempotence), `tty_dec_buf` (zero / negative / 1–3 digits / new-position offset), `tty_move` rejection bounds (v0.7.0), `TIO_BUF_SIZE` drift guard (v0.7.0), the v0.3.0 constant set (`TTY_SIGMASK_*`, `TIOCGWINSZ` ABI), `tty_sgr` rejection, **v0.5.x** truecolor + 256 `_buf` exact-byte + bounds coverage, and **live-fd** tests for `tty_winsize` and `tty_open_signalfd` + `tty_close_signalfd` (v0.7.0). |
| `tests/pty.tcyr` | **47 assertions (v0.6.0; hardened v0.7.0)** — the in-repo PTY harness. Opens a real pseudo-terminal (`/dev/ptmx` → `TIOCSPTLCK` → `TIOCGPTN` → `/dev/pts/N`) and drives darshana against the slave: `tty_isatty` on a known-live fd (+ deterministic `/dev/null` negative), `tty_winsize` set/get (24×80), the `tty_raw`→`tty_cooked()` state-restore (byte-for-byte), the single-raw-fd model (2nd fd refused), the cooked-vs-raw output round-trip (OPOST/ONLCR, fail-not-skip), and fd-1 escape-byte capture (via `dup2`) for `tty_alt_*`, `tty_clear`, `tty_clear_to_eol/eos`, `tty_cursor_*`, `tty_move`, `tty_sgr`, `tty_sgr_reset`, `tty_fg_rgb`/`tty_bg_rgb`. Wired into CI (v0.7.0) with `SKIP pty:` degradation tokens. Hang-proof (`O_NONBLOCK` master, bounded drains) and skip-clean (Linux-only). |

**199 assertions total**, green at cyrius 6.5.35.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert`. Tightened from the init default (`string / fmt / alloc / io / vec / str / syscalls / assert`) — the donor surface uses none of `vec / str / fmt / string`.

Known benign build warning: `undefined function 'vec_get'`. `io.cyr`
pulls `fmt.cyr`, which calls `vec_get`, but `vec` is not in darshana's
declared footprint. The call site is unreachable from darshana's
surface, so the build emits and links clean. Pre-dates v0.9.1 (present
at v0.9.0 too) — upstream-stdlib shaped, not a darshana defect.

## Consumers

| Consumer | Status |
|----------|--------|
| [chakshu](https://github.com/MacCracken/chakshu) | **Live on v0.9.0** (chakshu 0.7.11, cyrius 6.4.66). Drove M2 (Full TUI) and the agnos peers — its `--agnos` build failed to link on `TTY_SIGMASK_EXIT` before v0.9.0. Exercises `tty_raw/cooked`, `tty_alt_*`, `tty_clear_to_eol/eos`, `tty_cursor_*`, `tty_move`, `tty_winsize`, `tty_open_signalfd`, `TTY_SIGMASK_EXIT/WINCH`. |
| [anuenue](https://github.com/MacCracken/anuenue) | **Live on v0.9.0** (anuenue 1.2.0, cyrius 6.4.62). Pipe-decorator consumer; uses `tty_fg_rgb_buf` + `tty_sgr_reset_buf` to compose per-character escapes into a line buffer for one-write-per-line throughput. Drove the v0.5.1 truecolor addition. |
| [cyim](https://github.com/MacCracken/cyim) | **Live on v0.8.2** (cyim 1.8.1, cyrius 6.5.18). 1.7.0 was the original adopter on darshana 0.2.0. `cyim/src/tty.cyr` reduced from ~207 lines to 38 (only the cyim-specific `tty_probe` stays local). |
| [kii](https://github.com/MacCracken/kii) | **Live on v0.8.2** (kii 1.4.1, cyrius 6.4.20) — image → ANSI/ASCII converter; consumes `tty_winsize` to size art to the real console. Resolves via `path = "../darshana"`, so its vendored `lib/darshana.cyr` currently reads 0.9.0 while the manifest `tag` still says 0.8.2 — kii-side pin drift to reconcile at its next bump. |
| [bannermanor](https://github.com/MacCracken/bannermanor) | **Live on v0.7.1** (bannermanor 1.1.2, cyrius 6.2.24). First non-TUI consumer; uses `tty_sgr` + `TTY_FG_*` constants only. Drove the v0.3.5 SGR addition. Furthest behind — a bump candidate. |

## Carry-Forward

- ADR 0001 records the `darshana` name choice (`drishya` and other observation-family alternatives considered). Closed; no re-litigation needed.
- macOS support is deferred — see CLAUDE.md domain rules.
- The v0.8.0 roadmap slot (docs/examples/, final API audit, docs/architecture/ notes) was **not** what shipped as v0.8.0 — the agnos-parity work took the 0.8.x/0.9.0 cuts instead. Those three doc items are still open against the v1.0 freeze.
- `cyrius lint` on 6.5.35 reports one untracked-deferral note each in `src/ansi.cyr:317` and `src/termios.cyr:19` ("not yet" without a CHANGELOG/issue cross-reference). Zero warnings, so CI's `warn`-only gate is unaffected; worth cross-referencing during the doc cut.

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — three jobs: build-and-test (lint, smoke binary, `cyrius test`, `scripts/smoke.sh`, distlib drift, DCE parity); security scan (no FFI imports, no >=64K stack buffers, Linux gate intact); docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml via `workflow_call`, version-verify against tag, regenerates dist + ships `darshana-X.Y.Z.cyr` standalone + `darshana-X.Y.Z.tar.gz` package + source tarball + SHA256SUMS, GH release with body extracted from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — runs smoke binary, verifies dist drift, asserts the public contract surface (29 `tty_*` / `tio_*` fn symbols + 35 `TIO_* / TTY_*` constants present in dist) with a **bidirectional self-audit** (v0.7.0) that also fails if dist exports a public fn missing from the checklist, checks `CYRIUS_TARGET_LINUX` gate intact |
| Cutting a release | Bump VERSION + CHANGELOG section, push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

## Roadmap status

- M0 (v0.1.0) — scaffold ✓
- M1 (v0.2.0) — donor port ✓
- M2 (v0.3.0) — chakshu-driven extensions ✓ — `tty_winsize`, `tty_open_signalfd`, partial-clear helpers, TTY_SIGMASK_*
- M3 (v0.4.0) — cyim integration milestone ✓ (cyim 1.7.1, 2026-05-20)
- M4 (v0.5.0) — chakshu integration ✓ **closed 2026-05-20**
- **Soak-window cuts** (v0.6.0 → v0.9.2) — during the M5 calendar gate:
    - v0.6.0 — in-repo PTY harness ✓ shipped.
    - v0.7.0 — pre-freeze hardening / security / freeze-readiness sweep ✓ shipped. Breaking API reshapes, `tty_close_signalfd`, `SFD_CLOEXEC`, `tty_move` bounds, CI/smoke/test hardening.
    - v0.8.0 / v0.8.2 / v0.9.0 — **AGNOS parity** ✓ shipped. Took the slot the roadmap had penciled for the doc cut: `#ifdef CYRIUS_TARGET_AGNOS` peers for every syscall-touching entry point, so consumers stay platform-blind.
    - v0.7.1 / v0.8.1 / v0.9.1 — toolchain pin catch-ups ✓ shipped (6.2.22 / 6.2.36 / 6.5.35).
    - v0.9.2 — aarch64-Linux `SYS_IOCTL` shadow fix ✓ shipped. Cleared the 0.9.1 carry-forward: ESYSXLAT verified as *not* renumbering 16→29, so the hardcoded x86_64 number was a real defect, not a harmless one.
    - **Still open before the freeze**: `docs/examples/`, the final per-symbol API audit, and `docs/architecture/` notes — the v0.8.0 roadmap items that agnos parity displaced.
    - See [`roadmap.md`](roadmap.md) §Soak-window cuts for the full plan + per-cut checklist.
- M5 (v1.0.0) — both consumers green for ≥30 days — calendar-gated from 2026-05-20; the ≥30-day soak has long since elapsed. Remaining blockers are the three carried-forward doc/audit items, not the calendar.

See [`roadmap.md`](roadmap.md) for the full milestone definitions.
