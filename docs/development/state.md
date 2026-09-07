# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.0.1** — *open cycle*. **Toolchain + vendoring release; no source change.**
Pin `6.5.35` → `6.6.0`, `lib/` re-vendored and pruned 111 modules → 20, and
`vec` added to the declared stdlib footprint. `dist/darshana.cyr`'s module
bodies are byte-identical to 1.0.0 — the only delta is the `# Version:` header
— so the frozen surface (29 fns / 37 constants, ADR 0003) is untouched in
name, arity, return contract, constant value and emitted bytes.

The pin move was forced rather than routine: 6.5.35 had begun emitting a
correctness advisory on every invocation (*"carries the v6.5.36 enum Critical
— constants >= 2^62 read back as -1"*). darshana is **not exposed**, and
structurally so: the defect corrupts `enum` constants and darshana declares no
`enum` at all (all 37 frozen constants are top-level `var`s). The largest
constant in the bundle is `TTY_SIGMASK_WINCH = 0x10000000`, ten orders of
magnitude below 2^62. But the pin is what CI greps to choose an installer
version. The twelve-release jump also
spans 6.6.0's `Result` / `Option` / `Either` **value-form flip**, which deleted
`payload()` and `tagged_new()` and forced source migration in eight sibling
stdlibs; darshana needed **none**, because its whole surface is raw `i64`
return codes and it uses no Result idiom or `?` operator anywhere. The v6.5.57
P0 struct-pointer miscompile never reached it either — the pin predates that
defect.

`lib/` went 7.5 MB → 440 KB. The kept 20 are the transitive include-closure of
the declared leaves; the ~90 removed are sibling libs darshana never includes,
ten of which upstream had **deleted outright** — closing the standing
carry-forward by deletion rather than by another note. `lib/` is *output*, not
a curated directory: `rm -rf lib/ && cyrius deps` reproduces it from the
manifest alone — Phase 1 copies the declared leaves from the pinned snapshot,
Phase 3's transitive BFS pulls their includes. (`cyrius lib sync` is the
narrower refresh tool — declared leaves and platform peers only, no transitive
pass — and is not the definition of the footprint.) Declaring `vec` closed the
long-standing `undefined function 'vec_get'` warning: **every native build is
now warning-clean**, and `--agnos` drops from four warnings to one (a
pre-existing `_agnos_getenv` that reproduces at v1.0.0). 217 assertions green.

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

**1.0.0** — **shipped 2026-08-23. The API is frozen.** No code change from
0.9.4 — emitted bytes, test results, and the dist module bodies are
identical. What changed is the promise.

[ADR 0003](../adr/0003-v1-api-freeze.md) enumerates the frozen surface in
full rather than gesturing at it: all 29 functions and all 37 constants,
the four things the freeze covers (names, arity, documented return
contract, emitted bytes and constant values) and the three it does not
(`_`-prefixed symbols, internal structure, additive platform coverage).
It also records the post-1.0 semver policy and names the two
known-imperfect things frozen in — `tio_load32`/`tio_store32` bounds-check
nothing, and the single-raw-fd model has no public reset for a
permanently stranded slot — so neither gets rediscovered as a surprise.

CLAUDE.md gained three hard rules replacing the pre-1.0 latitude: a
frozen-symbol break needs a major bump plus its own ADR; a new public
symbol must join `scripts/smoke.sh`; a new syscall must join
`scripts/syscall-audit.sh`. Its platform rule ("Linux-only at
v0.1.0–v0.4.x") was five minor versions stale and wrong since the AGNOS
peers landed — now Linux + AGNOS, macOS out of scope. `docs/adr/README.md`
had read "_No ADRs yet_" since v0.1.0 with two ADRs on disk; it now
indexes all three.

**Registry promotion done in the same cut**: darshana's pre-1.0 row was
removed from agnosticos `docs/development/planning/shared-crates.md`
(Pre-1.0 21 → 20) and added to `docs/applications/libs/README.md` under
OS & Infrastructure (29 → 30, total 89 → 90), per the graduation
convention. Counts re-derived by counting live rows, not carried forward.

**Open at the tag**: the five consumers are still on 0.7.1–0.9.0 dep
pins. The two v0.9.3 breaks affect zero live call sites across all five
trees, so this is sequencing rather than correctness — but the frozen
surface is not yet one anything is compiled against.

**0.9.4** — *open cycle*. **Pre-freeze documentation + audit cut — the last
v1.0 blocker, now closed.** No behavior change; emitted bytes unchanged.

Found and fixed the structural defect the audit existed to find: the
public-surface conventions — naming, return contracts, module map —
lived in `src/main.cyr`, which is deliberately excluded from
`[lib].modules`, so `cyrius distlib` never copied them and **consumers
had never seen them**. That included the return-conventions block
v0.9.3 had just rewritten as the authoritative API contract. Moved to
the head of `src/termios.cyr`, the first bundle module, so it is now
the front matter of `dist/darshana.cyr`.

The per-symbol audit also caught a regression from v0.9.3's own
duplication pass: `tty_cursor_up` and `tty_fg_rgb_buf` had been reduced
to one-line wrappers and their docstrings went with the extracted
private helpers, leaving both public symbols **undocumented in the
shipped bundle** with every gate green. Restored, plus 14 fns that had
never stated a return contract and the two `tio_*` codecs that had one
line each.

`docs/examples/raw_loop.cyr` is the first runnable example — the full
ADR 0002 teardown shape, verified under a real PTY to leave the slave
termios byte-for-byte identical to its pre-`tty_raw` state. CI builds
**and runs** every example. `docs/architecture/` gained its first two
notes (the single-termios-slot model; the raw-syscall cost, including
the aarch64 `SYS_IOCTL` trap). The exec-sink denylist became a syscall
**allowlist** (`scripts/syscall-audit.sh`, shared by smoke and CI) —
verified to catch a raw fork+execve, an unanticipated `openat`, and an
unlisted `sys_*` wrapper.

Audit result: **29/29 public fns and 37/37 constants, zero gaps**, and
the audit is now a smoke check so it stays zero.

**0.9.3** — *open cycle*. **P-1 audit / refactor / hardening / security
sweep** — the last code-shaped cut before the v1.0 freeze. Four audit
lenses (correctness, security, refactor, docs + deferred-item sweep)
over the whole surface, every finding put through an adversarial
refutation pass: 32 raised, 26 survived, folded into 12 work items.

Fixed: `tty_open_signalfd` leaked its `SIG_BLOCK` and returned a raw
`-errno` when `signalfd(2)` failed — reproduced under
`RLIMIT_NOFILE=3`, where it returned **-24** and left SIGWINCH blocked
for the process lifetime with no fd for the caller to hand
`tty_close_signalfd`; a consumer taking the documented "degrade
gracefully" path then ran deaf to Ctrl-C / `kill` / hangup. Now rolls
the block back and returns exactly -1 (both peers). The `_buf`
composers laundered a -1 sentinel into an out-of-bounds write:
`tty_sgr_reset_buf(&b, -1)` wrote ESC at `b - 1` and returned **3**,
erasing the sentinel; all seven now reject a negative `pos`
(**breaking** — `tty_sgr_reset_buf` and `tty_dec_buf` gain a -1
return; zero live call sites affected across the five consumers).

Refactor: three copies of the 1–3 digit decimal emitter collapsed to
one, fg/bg RGB to one parameterized body, `tty_cursor_up/down` to one.
Emitted bytes verified **identical** to v0.9.2 across the full input
envelope — 55,798 bytes of composer output plus all 29 emitters,
byte-for-byte, with the existing suite passing unmodified.

Hardening: `scripts/smoke.sh` gained a reverse audit for constants
(four `AGNOS_*` internals had entered dist unlisted across
v0.8.0–v0.9.0 — now `_AGNOS_*`); the platform-gate check became
positional rather than substring-presence (it stayed green with the
entire ioctl arm hoisted outside the gate); the CI exec-sink pattern
now covers raw syscall numbers, not just named stdlib wrappers.

Docs: `main.cyr`'s frozen return-conventions block was false for 12 of
the 29 public fns; `tty_winsize`'s "only fn writing through caller
pointers" claim ignored six `_buf` composers; `getting-started.md` told
contributors to add features to `src/main.cyr`, which is excluded from
the dist bundle (every gate stays green while the symbol ships to
nobody); the README advertised a `SIGWINCH` handler hook that ADR 0002
rejects. All corrected; both `cyrius lint` untracked-deferral notes
cross-referenced and cleared.

Tests **199 → 217** (167 + 50), including a deterministic
forced-failure signalfd test. Consumers need a dep bump for the dist
bytes; no consumer code change required.

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

- **Cyrius pin**: `6.6.0` (in `cyrius.cyml [package].cyrius`, via
  `${file:VERSION}` indirection on the package version). Bumped from `6.5.35`
  at v1.0.1 — not drift housekeeping this time: 6.5.35 emitted a correctness
  advisory on every invocation (*"carries the v6.5.36 enum Critical —
  constants >= 2^62 read back as -1"*). darshana is not exposed (largest bundle
  declares no `enum`, which is the defect's only vector; largest bundle constant
  is `TTY_SIGMASK_WINCH = 0x10000000`), but the pin is what CI greps to pick an
  installer version.
  History: `6.2.36` → `6.5.35` at v0.9.1; `6.2.22` → `6.2.36` at v0.8.1;
  `6.1.24` → `6.2.22` at v0.7.1; `6.0.1` → `6.1.24` at v0.5.4; `5.10.20` →
  `6.0.1` at v0.3.5.
- **`[deps].stdlib` is the opt-in auto-prepend list, and the only place the
  footprint is declared.** `lib/` is not hand-curated: it is *output*.
  **`cyrius deps` is the resolver and the authority** — Phase 1 copies the
  declared leaves from the pinned snapshot, Phase 2 resolves named deps, Phase 3
  runs a transitive BFS that pulls each leaf's own includes. From an empty
  `lib/` it produces the complete, correct set in one pass.
- **`cyrius lib sync` is the narrower tool** — declared leaves plus their
  platform peers only (14 files at the current footprint), with **no transitive
  pass**. It is for *refreshing* what is already vendored, not for *defining*
  the set. Do not mistake its file list for the footprint.
- **Neither command prunes**, so the refresh procedure as of v1.0.1 is:

      rm -rf lib/ && cyrius deps

  What lands is by definition the proper set — reproducible from the manifest,
  never hand-picked. At v1.0.1 that is **20 modules, 456 KB**, each
  byte-identical to `~/.cyrius/versions/6.6.0/lib`. It had been 118 tracked
  files and 7.8 MB, carrying ~90 sibling libs darshana never includes — ten of
  them (`agnosys`, `base64`, `bigint`, `csv`, `cyml`, `json`, `linalg`,
  `matrix`, `toml`, `u128`) deleted upstream and vendored here as dead bytes.
  Verified by resolving into a clean tree and rebuilding: 217 assertions green
  and `dist/darshana.cyr` byte-identical to the repo's.

## Source

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | 593 | `TIO_*` flags, `tio_load32/store32`, `tty_raw`, `tty_cooked`, **v0.3.0:** `TIOCGWINSZ`, `TTY_SIGMASK_EXIT/WINCH`, `tty_winsize`, `tty_open_signalfd`. **v0.5.3:** `tty_isatty`. **v0.7.0:** `tty_cooked` is zero-arg (single-raw-fd model, `_tty_raw_fd`); `tty_apply_raw_flags` privatized → `_tty_apply_raw_flags`; `tty_close_signalfd` added; `SFD_CLOEXEC` on the signalfd. **v0.8.0–v0.9.0:** `#ifdef CYRIUS_TARGET_AGNOS` peers for all six syscall-touching entry points (`tty_winsize`, `tty_isatty`, `tty_raw`, `tty_cooked`, `tty_open_signalfd`, `tty_close_signalfd`) + agnos-specific `TTY_SIGMASK_*` values. Linux arm gated via `#ifdef CYRIUS_TARGET_LINUX`. **v0.9.2:** local `var SYS_IOCTL = 16` dropped — the Linux gate is arch-blind, so it shadowed the stdlib's arch-aware value and issued the x86_64 number on aarch64; `TCGETS`/`TCSETS`/`TIOCGWINSZ` stay local (arch-stable). |
| `src/ansi.cyr` | 369 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`, **v0.3.0:** `tty_clear_to_eol`, `tty_clear_to_eos` (renamed from `tty_clear_to_end` v0.7.0), **v0.3.5:** `tty_sgr`, `tty_sgr_reset`, 16 `TTY_FG_*` constants. **v0.4.0:** `tty_sgr` validates input range `[0, 999]`. **v0.5.1:** `tty_fg_rgb`, `tty_bg_rgb`, `tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf`. **v0.5.3:** `tty_sgr_buf`, `tty_fg_256_buf`. Any vt100-compatible terminal. |
| `src/cursor.cyr` | 137 | `tty_dec_buf` (decimal formatter — renamed from `tty_itoa`, returns new write position, v0.7.0), `tty_move` (with [1,65535] coord bounds + `buf[44]` v0.7.0), `tty_cursor_up/down`. Composes the CSI row;colH escape inline. |
| `src/main.cyr` | 27 | Convenience entry — `include`s the three sub-modules; carries the authoritative surface pointer (→ `scripts/smoke.sh`) + naming/return conventions (v0.7.0). Not in the dist bundle. |
| `programs/smoke.cyr` | 17 | Compile-link smoke. |
| `dist/darshana.cyr` | 1,099 | Bundled distribution — regenerate via `cyrius distlib`. What consumers `include "lib/darshana.cyr"`. (1,112 lines on disk; `distlib` reports module-body lines, excluding its 13-line generated header.) |
| `dist/darshana.deps` | 7 | Generated stdlib-leaf sidecar — **5 entries** (`syscalls`, `alloc`, `io`, `assert`, **`vec`** — the fifth added at v1.0.1, compile-verified by 6.6.0's `distlib`). Consumed by a consumer's `cyrius deps`. |

Total source ≈ 1,099 lines across the three dist modules (grew from ~780
at v0.7.0 with the v0.8.0–v0.9.0 agnos peers, and again through the v0.9.3
refactor and the v0.9.4 docstring restoration). The line counts above were
re-derived with `wc -l` at v1.0.1 — every row had been stale since v0.9.2, in a
file whose own header says it is refreshed every release. Public fn surface is **29**
unique names — 35 definitions in the bundle, six of which are agnos/Linux
`#ifdef` peers of the same name (`scripts/smoke.sh` is authoritative and
self-audits bidirectionally).

## Tests

| File | Status |
|------|--------|
| `tests/darshana.tcyr` | **167 assertions** (a couple live-fd-gated): pure-function coverage of `tio_load32/store32`, `_tty_apply_raw_flags` (every flag bit + idempotence), `tty_dec_buf` (zero / negative / 1–3 digits / new-position offset), `tty_move` rejection bounds (v0.7.0), `TIO_BUF_SIZE` drift guard (v0.7.0), the v0.3.0 constant set (`TTY_SIGMASK_*`, `TIOCGWINSZ` ABI), `tty_sgr` rejection, **v0.5.x** truecolor + 256 `_buf` exact-byte + bounds coverage, and **live-fd** tests for `tty_winsize` and `tty_open_signalfd` + `tty_close_signalfd` (v0.7.0). |
| `tests/pty.tcyr` | **50 assertions (v0.6.0; hardened v0.7.0 and v0.9.3)** — the in-repo PTY harness. Opens a real pseudo-terminal (`/dev/ptmx` → `TIOCSPTLCK` → `TIOCGPTN` → `/dev/pts/N`) and drives darshana against the slave: `tty_isatty` on a known-live fd (+ deterministic `/dev/null` negative), `tty_winsize` set/get (24×80), the `tty_raw`→`tty_cooked()` state-restore (byte-for-byte), the single-raw-fd model (2nd fd refused), the cooked-vs-raw output round-trip (OPOST/ONLCR, fail-not-skip), and fd-1 escape-byte capture (via `dup2`) for `tty_alt_*`, `tty_clear`, `tty_clear_to_eol/eos`, `tty_cursor_*`, `tty_move`, `tty_sgr`, `tty_sgr_reset`, `tty_fg_rgb`/`tty_bg_rgb`. Wired into CI (v0.7.0) with `SKIP pty:` degradation tokens. Hang-proof (`O_NONBLOCK` master, bounded drains) and skip-clean (Linux-only). |

**217 assertions total**, green at cyrius 6.6.0 (167 + 50; the PTY harness runs
its full set with no `SKIP pty:` token).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert`, **`vec`** (five leaves as of
  v1.0.1). Still tighter than the init default (`string / fmt / alloc / io /
  vec / str / syscalls / assert`) — darshana's own sources use none of
  `str / fmt / string / vec` directly.

~~Known benign build warning: `undefined function 'vec_get'`~~ — **closed at
v1.0.1.** `lib/assert.cyr:4` pulls `lib/fmt.cyr`, the only caller of `vec_get`
outside `vec.cyr` itself, and `vec` was not in the declared footprint, so the
call site linked against nothing. **The attribution above was wrong from v0.9.0
until now**: this file blamed `io.cyr`, which includes only `syscalls`, `result`
and `args_macos`. Corrected against the include graph. 6.6.0's
`cyrius distlib` compile-verifies the sidecar it emits and flagged the missing
leaf (*"re-added 1 leaf(s) the inference missed"*); declaring `vec` makes the
manifest agree with `dist/darshana.deps`. **Every native build is now
warning-clean** — smoke binary, both suites, the example, and `distlib`.
`dist/darshana.cyr` is byte-identical with and without the declaration; the
cost is 160 bytes in the DCE'd smoke binary (15,808 → 15,968). The earlier
diagnosis was right that the call was unreachable and upstream-shaped, and
wrong that nothing could be done about it locally.

`cyrius deps` resolves those five leaves — via its Phase 3 transitive BFS — to
the **20** modules vendored in `lib/`: `alloc` `alloc_agnos` `alloc_macos` `alloc_windows` `args_macos`
`assert` `atomic` `fmt` `fnptr` `io` `result` `string` `syscalls`
`syscalls_aarch64_linux` `syscalls_linux_common` `syscalls_macos`
`syscalls_windows` `syscalls_x86_64_agnos` `syscalls_x86_64_linux` `vec`.

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
- **`undefined function '_agnos_getenv'` on the `--agnos` cross-build.** The one
  warning left anywhere in the tree after v1.0.1. Pre-existing and
  upstream-agnos shaped — it reproduces identically at the v1.0.0 tag, and
  darshana's own surface never calls it. Same class as the `vec_get` warning
  v1.0.1 closed, so it may well be closable the same way (a declared leaf)
  rather than being upstream's problem; nobody has checked.
- **`--aarch64` is unverifiable on this host** — `cycc_aarch64` is not installed,
  so `cyrius build --aarch64` fails before reaching darshana's source, at v1.0.0
  and v1.0.1 alike. The aarch64 arm is therefore *unbuilt*, not *known-good*;
  v0.9.2's `SYS_IOCTL` fix was verified by reading emitted machine code, not by
  a cross-build. Worth wiring up before an aarch64 consumer appears.
- **Inherited at v1.0.1: aarch64 `SYS_SIGNALFD4` moved `74` to `1074`** in the
  vendored `lib/syscalls_aarch64_linux.cyr` (a private alias upstream now
  translates via `ESYSXLAT 1074 -> 74`). darshana's Linux arm calls the stdlib
  wrapper `sys_signalfd`, not a hardcoded number, so it picks this up for free —
  which is the whole reason v0.9.2 dropped darshana's local `SYS_IOCTL`
  constant. Untested here for want of an aarch64 cross-compiler (above).
- ~~The displaced v0.8.0 doc/audit slot~~ — **closed at v0.9.4.** `docs/examples/` holds a runnable, CI-executed example; `docs/architecture/` holds notes 001 and 002; the per-symbol API audit returned zero gaps and is now enforced by `scripts/smoke.sh`.
- ~~`cyrius lint` untracked-deferral notes in `src/ansi.cyr` / `src/termios.cyr`~~ — **closed at v0.9.3**: the bg-256 twin now cross-references roadmap.md §"Out of scope", the macOS termios note cross-references CLAUDE.md's domain rule. All four src modules are deferral-note clean; keep them that way.

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — three jobs: build-and-test (lint, smoke binary, `cyrius test`, `scripts/smoke.sh`, distlib drift, DCE parity); security scan (no FFI imports, no >=64K stack buffers, Linux gate intact); docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml via `workflow_call`, version-verify against tag, regenerates dist + ships `darshana-X.Y.Z.cyr` standalone + `darshana-X.Y.Z.tar.gz` package + source tarball + SHA256SUMS, GH release with body extracted from CHANGELOG section |
| Syscall allowlist | `scripts/syscall-audit.sh` (v0.9.4) — the permitted syscall targets and stdlib wrappers, each with its rationale. One implementation, invoked by both `scripts/smoke.sh` and the CI security job so the two cannot drift. Replaced the exec-sink denylist, which could only catch anticipated sinks. |
| Examples | `docs/examples/*.cyr` — CI builds **and runs** each one. Every example checks `tty_isatty` first and degrades cleanly, so executing it in CI is meaningful. |
| Smoke test | `scripts/smoke.sh` — runs smoke binary, verifies dist drift, asserts the public contract surface (29 `tty_*` / `tio_*` fn symbols + 37 `TIO_* / TIOC* / TTY_*` constants present in dist) with a **bidirectional self-audit** covering both fns (v0.7.0) and constants (v0.9.3) — it fails if dist exports a public name the checklist omits, in either direction. The platform-gate check is **positional** as of v0.9.3: Linux ioctl tokens must sit inside the `CYRIUS_TARGET_LINUX` gate and agnos syscall tokens inside `CYRIUS_TARGET_AGNOS`, by line number rather than by substring presence. A **docstring audit** (v0.9.4) additionally fails the build if any public fn lacks a docstring or a stated return contract, if any `_buf` composer omits its byte budget, or if a public constant is undocumented |
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
    - v0.9.3 — **P-1 audit / refactor / hardening / security sweep** ✓ shipped (this release). signalfd failure-path fix, `_buf` negative-`pos` rejection, contract-doc repair on the freeze surface, duplication pass, smoke/CI guards. Two breaking-but-correct fixes taken deliberately pre-freeze.
    - v1.0.0 — **the API freeze** ✓ shipped (this release). ADR 0003 enumerates the 29 fns + 37 constants; CLAUDE.md carries the post-freeze rules.
    - v0.9.4 — **pre-freeze documentation + audit cut** ✓ shipped. `docs/examples/raw_loop.cyr`, `docs/architecture/` 001+002, the per-symbol API audit (0 gaps), the syscall allowlist, and the fix for the conventions block that never shipped.
    - **Nothing is open before the freeze.** All five v1.0 criteria are met; v1.0.0 needs the consumer dep bumps, the freeze itself, and the registry promotion.
    - Shipped-cut detail lives in [`CHANGELOG.md`](../../CHANGELOG.md); [`roadmap.md`](roadmap.md) carries only what is still open.
- M5 (v1.0.0) — ✅ **shipped 2026-08-23.** All five v1.0 criteria met; the surface is frozen per ADR 0003. Still open, and tracked in [`roadmap.md`](roadmap.md): the five consumer dep bumps to a `1.x` tag, and the shared-crates registry promotion.

[`roadmap.md`](roadmap.md) is forward-facing only — it now carries just the v0.9.4 cut, the v1.0.0 freeze, the out-of-scope boundaries, and the post-1.0 tracked items. Closed-milestone definitions were retired there at v0.9.3; the arc above is the surviving summary, and [`CHANGELOG.md`](../../CHANGELOG.md) is the full record.
