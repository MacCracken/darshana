# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.9.4] — 2026-08-23

The pre-freeze documentation + audit cut — **the last v1.0 blocker**. Doc- and
audit-shaped: no behavior change to any public function, and the emitted bytes
are unchanged. What did change is that the documentation a consumer actually
reads now exists, is correct, and is enforced by CI rather than by good intentions.

### Added

- **`docs/examples/` — `raw_loop.cyr`, the first runnable example.** The
  directory had held nothing but a `.gitkeep` since v0.1.0 while CLAUDE.md
  listed it as a documentation path. It implements the full
  [ADR 0002](docs/adr/0002-state-restore-posture.md) teardown shape end to end:
  refuses a non-TTY, opens the signalfd *before* going raw so the acquire order
  is unwindable, degrades rather than refusing to launch when the signalfd is
  unavailable, handles Ctrl-C both as a raw byte (`ISIG` is cleared, so `0x03`
  arrives on stdin) and as a signal, redraws on `SIGWINCH`, and restores
  everything through a single idempotent teardown reached from every exit path.
  Verified under a real pseudo-terminal: after it exits, the slave termios is
  **byte-for-byte identical** to its pre-`tty_raw` state.
- **CI builds and RUNS every example.** Examples are documentation that has to
  keep working; one that silently stopped compiling would be worse than none.
  Each example checks `tty_isatty` first and degrades cleanly, so CI can execute
  it — proving the include chain, the syscall surface, and the no-TTY path, not
  merely that the file parses.
- **`docs/architecture/` — the empty Items section is populated.** Two notes on
  invariants a reader cannot derive from the code:
  [001 — Termios save-state is a module global, and there is exactly one slot]
  (docs/architecture/001-module-global-termios-state.md) (why `tty_cooked()`
  takes no fd, why a second `tty_raw` on a different fd is refused, what a
  permanently failing restore strands, and why the literal `60` lives in three
  places that must move together) and
  [002 — Everything is a raw syscall, and what that costs]
  (docs/architecture/002-no-libc-raw-syscalls-only.md) (hardcoded kernel struct
  layouts, the arch-specific-syscall-number trap that actually bit us on
  aarch64, why the ANSI helpers are deliberately outside the Linux gate, and why
  write results go unchecked).
- **`scripts/syscall-audit.sh` — a syscall ALLOWLIST, replacing the exec-sink
  denylist** *(deferred out of v0.9.3)*. darshana's entire surface is raw
  `syscall(...)`, so a denylist can only catch the sinks someone thought to
  write down — the pre-v0.9.3 rule matched named stdlib wrappers only, and
  v0.9.3 could do no better than widen it to a handful of numbers. Inverted, the
  rule now fails on anything not explicitly permitted: the five syscall targets
  darshana issues (`1`, `SYS_IOCTL`, and the three agnos numbers) and the three
  stdlib wrappers it calls, each with its rationale in the script. Verified to
  catch a raw `fork`+`execve` pair, an **unanticipated** `openat`, and an
  unlisted `sys_*` wrapper. One implementation, invoked by both
  `scripts/smoke.sh` and the CI security job, so local and CI cannot drift.
- **A docstring audit in `scripts/smoke.sh`.** Enforces what the per-symbol
  audit below checked by hand: every public fn has a docstring, that docstring
  states the return contract, every `_buf` composer states its byte budget, and
  every public constant is documented individually or by leading a documented
  group. This exists because of the regression it would have caught — see below.

### Fixed

- **The public-surface conventions never shipped to consumers.** The naming
  conventions, the return conventions, and the module map lived in
  `src/main.cyr` — which is deliberately excluded from `[lib].modules`, so
  `cyrius distlib` never copied them. Consumers `include "lib/darshana.cyr"` and
  have never seen any of it, including the return-conventions block that v0.9.3
  rewrote as the authoritative statement of the API contract. Moved to the top
  of `src/termios.cyr`, the first entry in `[lib].modules`, so it is now the
  front matter of `dist/darshana.cyr`. `src/main.cyr` keeps a pointer explaining
  why the text lives where it does.
- **Two public docstrings destroyed by the v0.9.3 duplication pass.**
  `tty_cursor_up` and `tty_fg_rgb_buf` were reduced to one-line wrappers over
  extracted private helpers, and their documentation went with the helper —
  leaving both public symbols with **no docstring at all** in the shipped
  bundle. Every gate stayed green. Restored, along with `tty_bg_rgb_buf` and
  `tty_bg_rgb`, whose docstrings had also been thinned or duplicated by the same
  pass. The new smoke docstring audit fails on exactly this.
- **14 public fns never stated their return contract**, which compounded with
  the first item: the bucket that covered them was in `main.cyr` and did not
  ship. The nine unconditional emitters (`tty_alt_enter/leave`, `tty_clear`,
  `tty_clear_to_eol/eos`, `tty_cursor_hide/show/home`, `tty_sgr_reset`) now each
  state that they always return 0.
- **`tio_load32` / `tio_store32` had a one-line docstring each** despite being
  public surface a consumer uses to read termios without going raw. They now
  document the zero-extension (a flag word with the top bit set reads as a large
  positive, never negative), the kernel field offsets, the always-0 return, and
  that neither bounds-checks `off`.
- **`TCGETS` / `TCSETS` were promoted to listed public surface in v0.9.3 but
  only described in passing** inside a comment about `SYS_IOCTL`. They now carry
  their own documentation, including the warning that writing termios yourself
  is outside darshana's state-restore model — `tty_cooked()` restores only what
  `tty_raw` saved.

### Audit result

Every one of the **29 public functions** and **37 public constants** was walked
against the criterion "is this docstring sufficient to consume the symbol
without reading its body". Result after this cut: **0 gaps** — 29/29 functions
document their return contract, 6/6 `_buf` composers state a byte budget, and
all 37 constants are covered by 8 documented groups. The audit is now a CI
check, so the answer stays 0.

### Notes

`docs/development/roadmap.md` drops its v0.9.4 section, per the convention
adopted in v0.9.3 that closed work is deleted from the roadmap rather than
checked off in place. **v1.0.0 is now unblocked**: the remaining items are the
freeze itself and the registry promotion.

## [0.9.3] — 2026-08-23

P-1 audit / refactor / hardening / security sweep — the last code-shaped cut
before the v1.0 API freeze. Four audit lenses (correctness, security, refactor,
docs + deferred-item sweep) over the full surface, every finding put through an
adversarial refutation pass: 32 raised, 26 survived, folded into 12 work items.

### Breaking

Both breaks are deliberate pre-freeze choices — cheap now, major-bump-expensive
after v1.0. **Zero live call sites are affected**, verified by grep across all
five consumer trees; consumers still need a dep bump for the dist bytes.

- **`tty_sgr_reset_buf` and `tty_dec_buf` gain a `-1` return.** Neither had a
  failure mode before. See the `_buf` fix below.
- **The four `AGNOS_*` constants are now `_AGNOS_*`** (`_AGNOS_SYS_WINSIZE`,
  `_AGNOS_SYS_SIGPROCMASK`, `_AGNOS_SYS_SIGNALFD`, `_AGNOS_SFD_CLOEXEC`). They
  are darshana internals that entered the shipped namespace across v0.8.0–v0.9.0
  without matching any of the naming patterns `src/main.cyr` calls frozen at
  v1.0. Nothing outside darshana references them.

Not a break but consumers should read it: **`tty_open_signalfd`'s failure return
changes from a raw `-errno` to exactly `-1`** — a fix that makes the documented
contract true.

### Fixed

- **`tty_open_signalfd` leaked its `SIG_BLOCK` and returned a raw `-errno` when
  `signalfd(2)` failed** (`src/termios.cyr`, both the Linux and AGNOS peers).
  The function blocks the signals in `sigmask`, then creates the signalfd; the
  sigprocmask half normalized its error but the signalfd half was returned
  unnormalized. Reproduced under `RLIMIT_NOFILE=3`: the call returned **-24**
  (EMFILE) and left SIGWINCH blocked on the thread, with no fd for the caller to
  hand `tty_close_signalfd`. Since the docstring tells callers to degrade
  gracefully on failure, a consumer following it ran its whole session with
  HUP/INT/TERM blocked — Ctrl-C inert, `kill` inert, terminal hangup inert, only
  SIGKILL working. The failure path now rolls the block back and returns exactly
  `-1`, so a failed open leaves no residue. Covered by a deterministic
  forced-failure test in `tests/pty.tcyr`.
- **The `_buf` composers laundered a `-1` sentinel into an out-of-bounds write.**
  The family is documented as chainable — each takes a write position, returns
  the new one, or `-1` on bad input — but no member validated the *incoming*
  `pos`. `tty_sgr_reset_buf(&b, -1)` wrote ESC at `b - 1`, then `[0m` at `b+0..2`,
  and returned **3**: the sentinel erased, a neighbouring stack slot clobbered,
  and the caller left holding a length that emits a broken escape missing its
  ESC. `tty_dec_buf(&b, -5, 7)` returned **-4**, a negative "new position" a
  caller would pass as a `write(2)` length. All seven composers now reject a
  negative `pos` with `-1`, and `tty_move` propagates a rejection out of either
  of its two `tty_dec_buf` links.

### Changed

- **Duplication pass in `src/ansi.cyr` / `src/cursor.cyr`.** Three verbatim
  copies of the 1–3 digit decimal emitter collapsed to one (`_ansi_emit_u8`);
  `tty_fg_rgb_buf` / `tty_bg_rgb_buf` — 19 duplicated lines differing in a single
  byte literal — collapsed onto a parameterized `_ansi_rgb_buf`, with
  `tty_fg_rgb` / `tty_bg_rgb` over a shared `_ansi_rgb_write`; `tty_cursor_up` /
  `tty_cursor_down` collapsed onto `_cursor_rel` (the copy had already drifted —
  it had lost its comments). `tty_sgr` became a one-shot wrapper over
  `tty_sgr_buf`, matching the shape `tty_fg_rgb` already used, and moved beside
  it. **Emitted bytes are identical to v0.9.2** — verified across the full input
  envelope (55,798 bytes of composer output plus all 29 emitters, byte-for-byte),
  with the existing exact-byte suite passing unmodified.
- **Contract docs repaired on the surface about to be frozen.** `src/main.cyr`'s
  "Return conventions" block was false for 12 of the 29 public fns — it had no
  bucket for the unconditional emitters, so `tty_cursor_up/down` and the fixed
  escape writers were described as returning `-1` on failure, which they never
  do. `tty_winsize`'s claim to be "the ONLY darshana primitive that writes
  through caller-supplied pointers" ignored six `_buf` composers that write a
  *variable* number of bytes through a caller pointer with no capacity argument.
  Each composer now documents its own byte budget. `tty_close_signalfd`'s
  docstring said it "restores the prior signal mask" — it calls `SIG_UNBLOCK`,
  and open passes `oldset = NULL`, so the prior mask is never captured; the
  docstring now says unblock and explains why unblock-what-you-blocked is the
  right primitive when a consumer holds two signalfds. `tty_cooked` gained a note
  on the stranded-slot state a permanently failing restore produces.
- **`scripts/smoke.sh` gained a reverse audit for constants**, mirroring the one
  it has had for functions since v0.7.0. `TCGETS` / `TCSETS` are now listed as
  the consumer surface they already were; the four `AGNOS_*` internals were
  privatized instead. A shipped constant must now be either public contract or
  `_`-prefixed. The label also stopped claiming all 37 constants are `TIO_*`.
- **The platform-gate check is positional, not substring-presence**
  (`scripts/smoke.sh` and `.github/workflows/ci.yml`). It previously grepped for
  `#ifdef CYRIUS_TARGET_LINUX` anywhere in the file, which stayed green with the
  entire ioctl arm hoisted outside the gate — the check had no relationship to
  what its comment claimed it verified. It now resolves both gates' line ranges
  and fails if a Linux ioctl token or an agnos syscall token sits outside its
  own gate.
- **The CI exec-sink scan now covers raw syscall numbers.** It matched only named
  stdlib wrappers (`sys_system`, `sys_exec*`, `system(`) while its comment
  claimed to catch "a raw execve syscall" — and darshana's entire surface is
  `syscall(N, ...)`, so a synthetic `syscall(57)` / `syscall(59, path, 0, 0)`
  fork+exec pair scored zero hits and the job exited green. Inverting this
  denylist into a syscall *allowlist* is tracked in the roadmap's v0.9.4 cut.
- **`docs/guides/getting-started.md` no longer routes contributor work into a
  no-op.** It said "Edit `src/main.cyr`" — a file excluded from `[lib].modules`,
  so a public symbol added there compiles, tests green, passes the dist-drift
  check and the smoke surface audit, and ships to nobody. It now names the three
  domain modules, says explicitly that `main.cyr` is not in the bundle, and adds
  the `scripts/smoke.sh` contract-list step the old six-step recipe omitted.
- **README scope table** no longer advertises "`SIGWINCH` install + handler
  hook". No such API exists, and ADR 0002 rejects that shape outright; the row
  now names the `signalfd` path that actually shipped.
- **`docs/development/roadmap.md` is now forward-facing only** — 137 lines to
  109, with the surviving content being almost entirely different. It had become
  a second changelog: five closed milestones (M0–M4) with their gates, the
  shipped soak-window cuts, and a v0.8.0 doc slot that AGNOS parity had displaced
  and that therefore read as dead history. All of it duplicated the CHANGELOG,
  and the duplication had gone stale — M1's and M2's 12 checkboxes still read
  unchecked three months after both shipped, and the M5 calendar gate still read
  as the v1.0 blocker two months after it elapsed. Closed milestones are now
  **deleted** from the file rather than checked off in place, a convention the
  header states explicitly. What remains is what is still open: the **v0.9.4**
  cut (the sole v1.0 blocker), the v1.0.0 freeze and registry promotion, the
  out-of-scope boundaries, and post-1.0 tracked items. Two anti-goals were
  preserved from the deleted milestone text because they are forward-facing
  decisions rather than history: `tty_frame_begin`/`tty_frame_end` will not ship,
  and no `sigaction`-shaped handler-install API will ship. The soak-window
  constraint paragraph was dropped along with its section; for the record its
  "refactors that don't touch the dist bundle bytes are fine" clause was always
  vacuous, since `dist/darshana.cyr` *is* the concatenated source text.
- **Stale shipped comments corrected.** `src/ansi.cyr` claimed 256-color and
  truecolor "will land when a consumer asks" — both landed in that same file
  (v0.5.1 and v0.5.3, driven by anuenue); cited a "v0.6.0 candidate per state.md
  M5 carry-forward" whose three anchors are all dead; understated the short-end
  256-color escape as 8 bytes (it is 9); and sized a `buf[16]` for a one-shot
  that was never shipped. Two comments still named `tty_itoa`, renamed in v0.7.0.
  These all ship verbatim in `dist/darshana.cyr`, so consumers read them.
- **Both `cyrius lint` untracked-deferral notes cleared** by cross-referencing
  rather than deleting: the 256-color background twin is a *live* deferral with a
  named first consumer (kii's local `_emit_bg_256_buf`) and is now tracked in the
  roadmap's "Out of scope" section under the extract-on-2nd-consumer rule; the
  macOS termios note now points at CLAUDE.md's domain rule.

### Tests

- **199 → 217 assertions** (167 in `tests/darshana.tcyr`, 50 in `tests/pty.tcyr`).
- New `_buf` negative-`pos` group: rejection for all seven composers, positive
  controls, a no-write-below-base check that stays in bounds by composing at an
  interior offset, and a chain-poisoning assertion. Against v0.9.2 source these
  produce 10 failures, including the literal out-of-bounds bytes (ESC = 27 and
  '4' = 52 landing below the buffer).
- New deterministic `tty_open_signalfd` failure test in `tests/pty.tcyr`: squeezes
  `RLIMIT_NOFILE` to force the failure, asserts the return is exactly `-1` and
  that the thread signal mask is byte-identical to before the call. Against
  v0.9.2 source it fails with `-24` and a leaked `0x08000000`.
- `tests/darshana.tcyr`'s header no longer claims the TTY-bound surface is
  untestable in-repo or that CI re-runs cyim's smoke — both false since v0.6.0.

## [0.9.2] — 2026-08-23

Behavior fix on aarch64-Linux. No public-API change; x86_64 and agnos codegen
are unaffected.

### Fixed

- **aarch64-Linux issued the wrong syscall for every ioctl.** `src/termios.cyr`
  defined `var SYS_IOCTL = 16` — the x86_64 number — inside the
  `#ifdef CYRIUS_TARGET_LINUX` gate, which is arch-blind. That shadowed the
  stdlib's arch-aware definition (`lib/syscalls_x86_64_linux.cyr:29` = 16,
  `lib/syscalls_aarch64_linux.cyr:47` = 29) and darshana's value won, so
  `cyrius build --aarch64` emitted `duplicate symbol 'SYS_IOCTL' redefined with
  conflicting value (last definition wins)` and all five ioctl callsites
  (`tty_raw`, `tty_cooked`, `tty_winsize` ×2, `tty_isatty`) issued syscall 16.
  On aarch64-Linux 16 is **`fremovexattr`**, not `ioctl` — the TCGETS/TCSETS/
  TIOCGWINSZ request code was reinterpreted as an xattr-name pointer, so raw
  mode, cooked restore and window-size query would each have failed at runtime.

  The carry-forward note flagged the renumbering as unverified; it is now
  verified as **not** translated. The ELF aarch64 branch of the backend's
  `ESYSXLAT` chain (`src/backend/aarch64/emit.cyr`) has no `16→29` row — its
  x86→aarch64 compat sources are 0/1/2/3/4/7/9/10/11/12/22/39/41–55/60/72–75/
  79/82/88/217/228/232/262/269/280 plus the 1049/1054 private aliases, and 16
  is absent from that set — so an untranslated 16 reaches the native `svc`
  unchanged. The compiler's "syscall not routed" warning is Mach-O-only, so
  nothing flagged it beyond the duplicate-symbol line.

  Fix: drop the local `var` and let the stdlib's arch-aware `SYS_IOCTL`
  resolve. Verified in the emitted machine code — the five callsites now
  materialize the immediate `29` on aarch64 (previously they loaded a `.bss`
  global holding 16), and `29` is never an `ESYSXLAT` source number, so it
  passes through to the native aarch64 `ioctl`. x86_64 still resolves 16.

  `TCGETS` (0x5401), `TCSETS` (0x5402) and `TIOCGWINSZ` (0x5413) stay local and
  are unchanged: both Linux targets share `asm-generic/ioctls.h` (x86_64's
  `asm/ioctls.h` is a bare include of it), so the request codes are arch-stable,
  and the stdlib does not define them — there is no shadowing to undo.

  Latent rather than live: darshana ships x86_64-Linux + agnos and has no
  aarch64 consumer today, so no released consumer was affected. Pre-dates
  0.9.1 (reproduces at 0.9.0).

### Changed

- `dist/darshana.cyr` regenerated — carries the `src/termios.cyr` change plus
  the new `# Version:` header stamp.

## [0.9.1] — 2026-08-23

Toolchain-only release. No source or public-API changes.

### Changed

- **cyrius toolchain pin `6.2.36` → `6.5.35`** in `cyrius.cyml [package].cyrius`.
  The manifest pin had drifted stale behind the installed wrapper again (already
  on 6.5.35), so builds were emitting both the pin-drift warning and a
  `./lib/ shadows version-pinned ...` warning listing nine bundled sibling libs
  behind the snapshot. `cyrius update` re-vendored `lib/` from the 6.5.35
  snapshot — 69 modules refreshed, 17 new ones added (`sys`, `ganita`,
  `yantra`, `bayan`, `protobuf`, the per-platform `async_*` / `thread_*` /
  `regression_agnos` splits, and the six `tls_native_*` shards the monolithic
  `tls_native.cyr` was broken into). Bundled sibling-lib versions advanced:
  mabda 3.0.1 → 4.1.0, vani 0.9.3 → 1.2.2, sigil 3.7.8 → 3.12.9, sandhi
  1.4.10 → 1.9.10, sankoch 2.2.5 → 2.7.8, sakshi 2.2.10 → 2.4.11, patra
  1.10.3 → 1.13.10, yukti 2.2.3 → 2.3.8, niyama 1.0.2 → 1.0.7. darshana's own
  declared footprint is unchanged (`syscalls`, `alloc`, `io`, `assert`);
  `dist/darshana.cyr` regenerated only to stamp the new `# Version:` header —
  module bodies are byte-identical to 0.9.0. Build, lint, `scripts/smoke.sh`,
  distlib-drift and DCE-parity all clean; 199 assertions green (152
  `tests/darshana.tcyr` + 47 `tests/pty.tcyr`). Consumers (cyim, chakshu,
  bannermanor, anuenue, kii) unaffected.

### Added

- **`dist/darshana.deps`** — a dep sidecar `cyrius distlib` began emitting at
  the 6.5.35 toolchain. It records the four stdlib leaves the bundle needs in
  scope (`syscalls`, `alloc`, `io`, `assert`) so a consumer's `cyrius deps` can
  resolve them from the bundle instead of the consumer restating darshana's
  footprint in its own manifest. Generated, not hand-maintained — `cyrius
  distlib` rewrites it alongside `dist/darshana.cyr`.

## [0.9.0] — 2026-07-08

AGNOS parity for the signalfd path. Completes the agnos branch so consumers
(chakshu) stay platform-blind — the same `#ifdef CYRIUS_TARGET_AGNOS` peer
pattern already shipped for `tty_winsize` (0.8.0) and `tty_isatty` / `tty_raw` /
`tty_cooked` (0.8.2). This was the last Linux-only surface in `src/termios.cyr`;
chakshu's `--agnos` build failed to link on `TTY_SIGMASK_EXIT` before it.

### Added

- **agnos peers for `tty_open_signalfd` / `tty_close_signalfd` + the
  `TTY_SIGMASK_EXIT` / `TTY_SIGMASK_WINCH` masks** (`src/termios.cyr`). mirshi
  supervisor-emulates the signalfd path (`sigprocmask`#17 / `signalfd`#18), so
  the agnos peers block/create via raw `syscall(17/18, ...)` inside the
  agnos-only branch (the AGNOS_SYS_WINSIZE self-contained pattern — no cyrius
  stdlib `sys_*` wrapper, avoiding the Linux↔agnos syscall-number-overlap
  hazard). mirshi's signalfd is edge-triggered + non-blocking; consumers poll
  it via `epoll_wait`#21 / `read`#5, exactly as the Linux peers are used.
  **The mask VALUES differ from the Linux branch**: agnos/mirshi represent a
  signal set as `1 << sig` (bit N = signal N), not Linux's `1 << (sig-1)`
  sigset_t layout, so `TTY_SIGMASK_EXIT` = `0x8006` (bits 1,2,15) and
  `TTY_SIGMASK_WINCH` = `0x10000000` (bit 28) — copying the Linux `0x4003` /
  `0x08000000` would silently watch the wrong signals. No Linux-path or API
  change; `dist/darshana.cyr` regenerated.

## [0.8.2] — 2026-07-01

AGNOS parity for the TTY-mode primitives. Completes the agnos branch so
consumers (thoth / chakshu / cyim / kii) stay platform-blind — the same
`#ifdef CYRIUS_TARGET_AGNOS` peer pattern already shipped for `tty_winsize`.

### Added

- **agnos peers for `tty_isatty` / `tty_raw` / `tty_cooked`** (`src/termios.cyr`).
  agnos has no termios (no `ioctl` TCGETS/TCSETS/TIOCGWINSZ): `tty_isatty`
  reports a tty when the framebuffer console-grid syscall (`winsize`#60)
  succeeds (mirroring the Linux TIOCGWINSZ mechanism); `tty_raw` returns `-1`
  (no raw-mode toggle — consumers fall back to their line REPL); `tty_cooked`
  is a no-op success. No Linux-path or API change; `dist/darshana.cyr`
  regenerated.

## [0.8.1] — 2026-06-22

### Changed

- **cyrius toolchain pin `6.2.22` → `6.2.36`** — aligns with the latest cyrius (picks up the
  6.2.31–6.2.36 agnos-stdlib fixes: `io.cyr` file-lock SIGILL-stub fix, agnos mutex,
  `time_unix`#46). `dist/darshana.cyr` regenerated at the new pin; no source/API change.

## [0.8.0] — 2026-06-22

### Added

- **`tty_winsize` on AGNOS** (`src/termios.cyr`) — a `#ifdef CYRIUS_TARGET_AGNOS`
  peer to the Linux `ioctl(TIOCGWINSZ)` variant. agnos has no `ioctl`, so the
  kernel instead exposes the live framebuffer console grid via its new
  `winsize`#60 syscall, which returns the two counts packed in one i64
  (`high 16 = cols`, `low 16 = rows`) or `-1` if the framebuffer isn't up. The
  agnos branch unpacks that and writes rows + cols through the caller's
  out-pointers, preserving the Linux `tty_winsize(fd, out_rows, out_cols)` → 0/-1
  contract exactly (`fd` accepted for parity but ignored — the console grid is a
  global FB property, not per-fd). This lets agnos consumers (kii, chakshu) call
  one `tty_winsize` and size to the real console instead of a hardcoded 80×24,
  the platform branch invisible at the call site. Raw `syscall(60)` is used
  directly (no cyrius stdlib `sys_*` wrapper needed — the number is unambiguous
  inside its own target's `#ifdef`). Linux behavior is unchanged. Requires
  agnos ≥ **1.45.13** (the `winsize`#60 cut).

## [0.7.1] — toolchain pin bump

Toolchain-only release. No source or public-API changes.

### Changed

- **Cyrius pin `6.1.24` → `6.2.22`** in `cyrius.cyml [package].cyrius`.
  The manifest pin had drifted stale behind the installed wrapper
  (already on 6.2.22); this catches the manifest back up. `dist/darshana.cyr`
  regenerated only to stamp the new `# Version:` header — module bodies
  are byte-identical. Consumers (cyim 1.7.1, chakshu 0.6.1, bannermanor,
  anuenue 0.7.0) unaffected.

## [0.7.0] — pre-freeze hardening & API-reshaping sweep

A deep hardening / refactor / optimization / security review ahead of
the v1.0 API freeze, run as a multi-agent review (66 findings → 25
confirmed after adversarial verification). The guiding question was
"would we regret freezing this as-is?", so this cut deliberately
includes **breaking** changes to the public surface — fixing an API
wart is cheap now and needs a major bump after the freeze. The four
sibling consumers (cyim 1.7.1, chakshu 0.6.1, bannermanor, anuenue
0.7.0) are all coordinatable; each breaking change's blast radius is
one or two mechanical edits (see *Consumer coordination* below).

### Breaking

- **`tty_cooked(fd)` → `tty_cooked()`** (zero-arg). The fd parameter
  advertised a per-fd restore the single saved-state slot can't deliver
  (`tty_raw(0)` + `tty_cooked(1)` would have written fd 0's termios onto
  fd 1). `tty_raw` now records the owning fd (`_tty_raw_fd`);
  `tty_cooked()` restores onto it; a second concurrent `tty_raw` on a
  *different* fd is refused with -1 rather than silently stranding the
  first. All consumers already called `tty_cooked(0)`, so the zero-arg
  form preserves their semantics. ADR-0002 amended.
- **`tty_itoa` → `tty_dec_buf`**, return harmonized from digit-count to
  the **new write position**. The old name was a generic misnomer and
  the digit-count return was the lone odd-one-out in the `_buf` family
  (every other `_buf` composer returns the new position) — a documented
  footgun. Scratch buffer widened 20→24 (i64 is ≤20 decimal digits).
- **`tty_clear_to_end` → `tty_clear_to_eos`** (end-of-screen), to
  parallel `tty_clear_to_eol` (end-of-line) so the extent is explicit
  at the call site. Emitted bytes unchanged (still CSI J).
- **`tty_apply_raw_flags` → `_tty_apply_raw_flags`** (privatized). It
  bakes in darshana's specific raw-mode mask and is reached only through
  `tty_raw`; no consumer calls it directly. Dropped from the public
  contract (`scripts/smoke.sh`); still reachable by same-unit tests.

### Added

- **`tty_close_signalfd(fd, sigmask)`** — the teardown counterpart to
  `tty_open_signalfd`. The open call's `SIG_BLOCK` was irreversible
  within darshana (closing the fd alone doesn't unblock); this closes
  the fd and restores the signal mask. Step 5 of the ADR-0002 teardown
  sequence; chakshu's signalfd-driven exit is the first consumer.
- **`tty_move` coordinate bounds** — rejects coordinates outside
  [1, 65535] with -1 before emitting (fail-before-emit, matching
  `tty_sgr` / `tty_fg_rgb`), giving `tty_move` the -1 return it lacked.

### Security

- **`tty_open_signalfd` now opens with `SFD_CLOEXEC`** so the signalfd
  doesn't leak across an execve — a consumer that takes over the screen
  and later spawns a child (editor shelling out, pager, `$SHELL`) must
  not hand it the fd.
- **`tty_move` stack-buffer sizing** — the compose buffer was `buf[32]`
  but two max-width decimal fields total 44 bytes; resized to `buf[44]`
  so a large coordinate cannot overrun the stack (the new clamp also
  prevents this — defense in depth).
- **CI security scan** gained a command-exec-sink check (`sys_system` /
  `sys_exec*` / `system(`); darshana is syscall-only and must never
  spawn processes.

### Changed / Fixed

- **`tests/pty.tcyr` now runs in CI.** The v0.6.0 harness was never
  executed by CI (the Test step ran only `tests/darshana.tcyr`); a
  dedicated step runs it, warning if a `SKIP pty:` token shows the
  runner degraded.
- **`scripts/smoke.sh` surface check** — added the missing
  `tty_cursor_up` / `tty_cursor_down` (unchecked for several releases)
  and a bidirectional self-audit that fails if any public `fn tty_*` /
  `tio_*` in dist is absent from `required_syms`, so the contract list
  can never silently lag the shipped surface again.
- **`tests/pty.tcyr` hardening** — grep-able `SKIP pty:` tokens on every
  skip branch; the OPOST/ONLCR round-trip drains now *fail* (not
  silently skip) on a zero-byte read; added fd-1 capture for
  `tty_fg_rgb` / `tty_bg_rgb`, a deterministic non-TTY `tty_isatty`
  assertion, an ONLCR sanity check, and a single-raw-fd-model test.
- **`tests/darshana.tcyr`** — added a `TIO_BUF_SIZE == 60` drift guard
  (the constant must track the `[60]` array literals), `tty_move`
  rejection assertions, and the `tty_close_signalfd` live path.
- **Docstring / doc accuracy** — `src/main.cyr` no longer enumerates a
  stale public-symbol list (points at `scripts/smoke.sh` as
  authoritative) and records the naming + return conventions; fixed
  `tty_sgr`'s reference to a non-existent "TtyFgColor enum"; softened
  `tty_isatty`'s isatty(3)-parity claim; documented `tty_winsize` as the
  lone caller-memory-write surface; refreshed the roadmap's stale
  "256-color/truecolor out of scope" bullet (those shipped v0.3.5–0.5.3).

### Removed

- **`tests/darshana.bcyr` / `tests/darshana.fcyr`** — phantom bench/fuzz
  stubs that were never executed (`cyrius fuzz` reads `fuzz/*.fcyr`, not
  `tests/`) and implied coverage that didn't exist. The emitter surface
  is boundary-tested in `darshana.tcyr` and byte-verified in `pty.tcyr`.

### Consumer coordination (follow-up)

The breaking changes need a coordinated dep bump to darshana 0.7.0 plus
these call-site edits (prepared in the sibling working trees):

- **cyim**: `tty_cooked(0)` → `tty_cooked()` (`src/main.cyr`,
  `src/tty.cyr`); `tty_itoa` → `tty_dec_buf` at `src/render.cyr`
  (`var nd = tty_dec_buf(...) - pos` keeps the digit count `pos` and
  `visible` advance by) + `tests/tty.tcyr`; and — caught by an
  exhaustive re-grep the per-finding blast-radius missed —
  `tty_apply_raw_flags` → `_tty_apply_raw_flags` in `tests/tty.tcyr`,
  which calls the now-private helper directly (white-box, first-party).
- **chakshu**: `tty_cooked(0)` → `tty_cooked()` (`src/tui.cyr`);
  `tty_clear_to_end` → `tty_clear_to_eos` (×3, `src/tui.cyr`);
  optionally adopt `tty_close_signalfd` in its exit teardown.
- **anuenue / bannermanor**: dep bump only — no changed call-sites.

## [0.6.0] — in-repo PTY harness (soak-window cut)

The first of the two soak-window cuts (roadmap §"Soak-window cuts").
Closes two v1.0 partials at once — "every exported symbol named,
documented, **and tested**" and "test coverage adequate (parsers +
state-restore paths)" — by giving the syscall-touching surface
deterministic in-repo coverage instead of relying on the
opportunistic v0.5.0 live-fd tests (which only fire when the runner
happens to have a controlling TTY on fd 0; CI does not).

Test-only release — no `src/` change, no public-surface change. The
dist bundle is unchanged apart from the regenerated `# Version:`
header. Existing consumers (cyim 1.7.1, chakshu 0.6.1, bannermanor,
anuenue 0.7.0) are unaffected. Lands early in the M5 soak so the
harness itself gets burn-in against the integrated stack before the
v1.0 freeze.

### Added

- **`tests/pty.tcyr`** — a pseudo-terminal harness that manufactures
  its own TTY (open `/dev/ptmx` → `TIOCSPTLCK` unlock → `TIOCGPTN` →
  open `/dev/pts/N`) and drives darshana against the slave end while
  observing results on the master end. 38 assertions across:
  - **`tty_isatty`** against a known-live slave fd (deterministic,
    unlike the fd-0 return-shape test in `darshana.tcyr`).
  - **`tty_winsize`** set/get round-trip — `TIOCSWINSZ` a known 24×80
    geometry, read it back, assert exact dimensions.
  - **State-restore round-trip** (the ADR-0002 guarantee): snapshot
    termios → `tty_raw` → assert the raw mask applied (ECHO / ICANON /
    ISIG / IEXTEN / OPOST cleared, CS8 set, VMIN=1 / VTIME=0) →
    `tty_cooked` → assert termios restored **byte-for-byte**.
  - **Behavioral output round-trip**: write `A\nB` to the slave, read
    on the master — raw mode passes `\n` through untranslated (3
    bytes), cooked mode injects CR via OPOST/ONLCR (`A\r\nB`, 4 bytes),
    confirming the restore re-enabled post-processing end-to-end.
  - **Escape-emission capture**: `dup2` the slave onto fd 1 (raw, so
    OPOST can't rewrite the bytes) and read back the exact CSI
    sequences from `tty_alt_enter` / `tty_alt_leave` / `tty_clear` /
    `tty_clear_to_eol` / `tty_clear_to_end` / `tty_cursor_hide` /
    `tty_cursor_show` / `tty_cursor_home` / `tty_move` /
    `tty_cursor_up` / `tty_cursor_down` / `tty_sgr` (valid code) /
    `tty_sgr_reset`. These fd-1 writers previously had *no* byte-level
    coverage — the unit suite only reaches their `_buf` twins and the
    rejection paths.

### Notes

- Hang-proof in CI: the master fd is `O_NONBLOCK` and every read is
  bounded (a 200-iteration × 1 ms drain cap, or a non-blocking flush),
  so a wedged kernel buffer can never stall the suite.
- Skip-clean: every kernel step is guarded. A sandbox / seccomp policy
  that blocks `/dev/ptmx`, the unlock ioctl, or the slave open stops
  the harness without faking a pass — the consumer-side PTY smoke
  (cyim / chakshu) still covers the live path end-to-end.
- Linux-only — the pty/devpts mechanism (`TIOCGPTN`, `TIOCSPTLCK`) is
  Linux ABI; on any other target the harness compiles to a single skip
  assertion, matching the `CYRIUS_TARGET_LINUX` gate on `termios.cyr`.
- Auto-discovered by `cyrius test` (it is a `tests/*.tcyr`), so the
  gate is enforced on every push with no CI-config change.

## [0.5.4] — toolchain bump 6.0.1 → 6.1.24

Pure version-pin release, no source changes. Catches darshana up to
the ecosystem-wide cycc pin (the wrapper had already drifted to
6.1.24; the manifest pin was stale at 6.0.1). `cyrius update`
refreshed `lib/` (101 files) from the matching snapshot; no source
edits required (`dist/darshana.cyr` regenerated only to stamp the
new `# Version:` header). Build clean
and all 144 assertions green on the new toolchain. Existing
consumers (cyim 1.7.1, chakshu 0.6.1, bannermanor, anuenue 0.7.0)
are unaffected — no API surface change.

### Changed

- `cyrius.cyml` pin bumped `6.0.1` → `6.1.24`.
- `lib/` refreshed via `cyrius update` to the 6.1.24 snapshot.

## [0.5.3] — anuenue color-mode negotiation unlock

Third turn of the same crank that produced 0.5.1 (truecolor for
anuenue M1) and 0.5.2 (relative cursor for anuenue M4):
**anuenue** is the consumer asking. Their M6 milestone (color-mode
negotiation — detects TRUECOLOR / 256-color / 16-color / MONO from
`--color`, `NO_COLOR`, `isatty`, `COLORTERM`, `TERM`) shipped in
anuenue v0.7.0 with three inline stand-ins pending this work; 0.5.3
closes the deferral. Pure additions; existing consumers (cyim 1.7.1,
chakshu 0.6.1, bannermanor, anuenue 0.7.0) are unaffected.

Sandhi-coordination proposal at
[`sandhi/docs/proposals/2026-05-22-darshana-color-mode-helpers.md`](https://github.com/MacCracken/sandhi/blob/main/docs/proposals/2026-05-22-darshana-color-mode-helpers.md).

### Added

- **`tty_isatty(fd)`** in `src/termios.cyr` — proper isatty
  primitive. Returns 1 if `fd` is an open TTY, 0 otherwise.
  Implemented as the cheapest TTY-property syscall (TIOCGWINSZ
  succeeds only on TTYs); same signal libc's `isatty(3)` returns
  via the same ioctl path on Linux. Anuenue M6 previously
  overloaded `tty_winsize` with dummy out-pointers as a stand-in
  (`_isatty_compat`); same syscall, cleaner surface.
- **`tty_sgr_buf(buf, pos, code)`** in `src/ansi.cyr` — buffer-
  targeting twin of `tty_sgr`. Writes `CSI <code>m` into `buf` at
  `pos`, returns new `pos` or -1 if `code` is outside [0, 999].
  Same [0, 999] envelope as `tty_sgr`, same fail-before-emit
  discipline. Used by anuenue M6's `_PHASE_ESC_TABLE` builder
  which emits 16-color named SGR escapes (`\x1b[91m` ...
  `\x1b[97m`) per phase into a stack buffer rather than fd 1.
  Inlines the 1–3 digit emit (rather than calling `tty_itoa`
  from cursor.cyr) so the dist bundle order termios → ansi →
  cursor doesn't matter.
- **`tty_fg_256_buf(buf, pos, n)`** in `src/ansi.cyr` —
  256-color (8-bit indexed) foreground SGR. Writes
  `CSI 38;5;Nm` into `buf` at `pos`, returns new `pos` or -1 if
  `n` is outside [0, 255]. The middle of the color-fidelity
  spectrum between 16-color named (existing `TTY_FG_*` named
  constants) and 24-bit truecolor (0.5.1's `tty_fg_rgb` family).
  Background twin (`tty_bg_256_buf`) not yet shipped — wait for
  a consumer ask, same discipline as 0.5.1's bg/fg split.

### Changed (rode along)

- `src/ansi.cyr` reformatted to match `cyrius fmt --check`. The
  pre-existing `tty_sgr` and `_ansi_emit_u8` if/else digit-emit
  blocks were drifted from fmt's preferred indentation; brought
  in line. No semantic change.

### Tests

- `tests/darshana.tcyr` — 9 new test groups across `tty_sgr_buf`
  (1-digit / 2-digit / 3-digit / bounds), `tty_fg_256_buf`
  (low end / high end / bounds), and `tty_isatty` (return shape
  + `/dev/null` definitely-not-a-TTY assertion). **144 passing**
  assertions (was 109 at 0.5.2 close; +35 across new helpers).

### Surface count

`scripts/smoke.sh` `required_syms` grew from 24 → 27.

### Anuenue migration (post-release)

When anuenue picks up `darshana = "0.5.3"`, the three inline
stand-ins (`_isatty_compat`, `_fg_256_buf_compat`, `_sgr_buf_compat`)
in `anuenue/src/color.cyr` get deleted and their call sites in
`color.cyr` + `filter.cyr` rewrite to call the darshana forms
directly. ~30 LOC delete + ~3 call-site renames. Mechanical
swap (signature-identical).

## [0.5.2] — anuenue animation unlock

Adds two relative-cursor helpers — `tty_cursor_up(n)` /
`tty_cursor_down(n)` — to round out the cursor surface. Sandhi-
unlock pattern, second turn of the same crank that produced 0.5.1:
**anuenue** is the consumer asking (M4 animation re-anchors the
rendered block at the top of the buffered region each frame, which
needs CSI `<n>A`). Pure additions; v0.5.1 consumers (cyim 1.7.1,
chakshu 0.6.1, bannermanor adopter, anuenue's M1/M2/M3 truecolor
filter) are unaffected.

### Added

- **`tty_cursor_up(n)`** in `src/cursor.cyr` — emit `CSI <n>A` to
  move the cursor up `n` rows in the current column. `n <= 0` is a
  no-op (CSI 0A is documented as "move 1 row" by xterm; guarding
  here lets callers pass an unchecked row count without spurious
  jumps). Composes the escape into a 24-byte stack buf and writes
  it in one syscall — same single-syscall discipline as `tty_move`.
- **`tty_cursor_down(n)`** in `src/cursor.cyr` — mirror of
  `tty_cursor_up`. Emits `CSI <n>B`, same no-op-on-zero guard,
  same envelope. Pairs with `tty_cursor_up` for callers that need
  bidirectional row offsets (anuenue M4 only uses up; provided for
  symmetry since the surface cost is one fn).

## [0.5.1] — anuenue truecolor unlock

Adds 24-bit (truecolor) SGR helpers — the slot the v0.3.5 header
left deferred ("ANSI-256 and truecolor will land when a consumer
asks"). The asker is **anuenue** (the rainbow pipe-filter scaffolded
2026-05-21), whose M1 per-character HSV phase cycle needs
`\x1b[38;2;R;G;Bm` directly; 8/16 named colors quantize the rainbow
into ROYGBIV-with-banding. Pure additions on the API surface —
v0.5.0 consumers (cyim 1.7.1, chakshu 0.6.1, bannermanor v0.3.5
adopter) are unaffected.

### Added

- **`tty_fg_rgb(r, g, b)` / `tty_bg_rgb(r, g, b)`** in `src/ansi.cyr`
  — set foreground / background to 24-bit RGB by writing
  `CSI 38;2;R;G;Bm` / `CSI 48;2;R;G;Bm` directly to fd 1. Per-channel
  bounds `[0, 255]`; out-of-range returns -1 *before* any bytes
  reach fd 1 (same fail-before-emit discipline as `tty_sgr`'s
  v0.4.0 `[0, 999]` guard).
- **`tty_fg_rgb_buf(buf, pos, r, g, b)` / `tty_bg_rgb_buf(...)` /
  `tty_sgr_reset_buf(buf, pos)`** — buffer-targeting variants for
  consumers that batch many escapes + payload bytes into one
  `write(2)`. Returns the new write position; same per-channel
  bounds rejection. anuenue's M1 line-loop is the first such
  consumer (one syscall per line vs ~5 syscalls per character).
  Closes the v0.3.5 header note "Phase 3 may add buf-targeting
  variants if a pattern emerges" — anuenue is the pattern.
- **Private helper `_ansi_emit_u8(buf, pos, val)`** — encodes a
  u8 channel value as 1–3 ASCII decimal digits. Inlined-and-
  conditional (same shape as `tty_sgr`'s digit emit) rather than
  forward-referencing `cursor.cyr`'s `tty_itoa`, which the
  `cyrius distlib` bundle order (termios → ansi → cursor) hasn't
  yet defined at the `ansi.cyr` call site.
- **50 new assertions** in `tests/darshana.tcyr` across 5 new
  groups: digit-encoding (1/2/3-digit branches), `tty_fg_rgb_buf`
  exact-byte sequence, `tty_bg_rgb_buf` marker swap, per-channel
  bounds rejection (negative + >255 on both fg and bg paths, both
  `_buf` and direct variants), `tty_sgr_reset_buf` exact bytes +
  position-offset.

### Notes

- No breaking changes. Dist bundle line count grows by ~120
  (helpers + comments); `tty_sgr` / `tty_sgr_reset` semantics
  unchanged.
- `scripts/smoke.sh` symbol-surface check updated to include the
  five new public names (`tty_fg_rgb`, `tty_bg_rgb`,
  `tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf`).

## [0.5.0] — 2026-05-20 — M4: chakshu integration milestone

The milestone cut associated with chakshu's adoption of darshana.
chakshu's M2 (Full TUI) shipped at chakshu 0.5.0 on darshana 0.3.0
the day before — literally satisfying the M4 gate "chakshu M2
closes (full-screen TUI, parity with htop) using darshana." chakshu
0.6.1 (2026-05-20) advanced its `[deps.darshana].tag` from 0.3.0 to
0.4.1 as the M4 close ceremony, putting both consumers (cyim 1.7.1,
chakshu 0.6.1) on the same dep pin.

From darshana's side this release adds one deferred-hardening item
(M5 carry-forward #5 — live-fd test coverage for the v0.3.0
syscall-touching surface). No new public functions; no breaking
changes. The dist bundle is line-identical to v0.4.1 (test-only
additions).

### Added

- **Live-fd tests for `tty_winsize` and `tty_open_signalfd`** in
  `tests/darshana.tcyr`. Both gate on the syscall returning
  success; if the host context doesn't satisfy the precondition
  (stdin not a TTY for `tty_winsize`; signalfd blocked by
  seccomp/sandbox for `tty_open_signalfd`) the test skips silently
  rather than faking a pass or failing the suite. Closes the M5
  carry-forward note in `state.md` Tests row that previously read
  "TTY-bound functions … exercised end-to-end via cyim's PTY smoke
  at Phase 4" — now exercised in-repo too, when possible.
  - `tty_winsize` against fd 0: when stdin is a TTY (interactive
    `cyrius test` from a shell), asserts `rows > 0` + `cols > 0`.
  - `tty_open_signalfd(TTY_SIGMASK_WINCH)`: asserts the returned
    fd ≥ 0, closes it. WINCH chosen over EXIT so a developer's
    ctrl-C still kills a hanging test — blocking SIGINT/SIGTERM for
    the test process duration would be a real footgun.

### Tests

- 48 assertions total (was 47). The increment is +1 from the
  signalfd live-path assertion (always reachable in non-sandboxed
  hosts); `tty_winsize` adds 0–2 depending on whether stdin is a
  TTY in the test runner's context. Under `cyrius test` from a
  non-interactive shell, stdin is not a TTY → 48 reported. From
  an interactive terminal → 50 reported. Both are green.

### Milestone

- **M4 closed**. chakshu 0.6.1 + cyim 1.7.1 both on darshana 0.4.1+;
  see `docs/development/roadmap.md` and `state.md` for the close
  framing. M5 is now calendar-gated ("both consumers green for ≥30
  days") — earliest viable v1.0.0 cut ~2026-06-19.

### v1.0 criteria refresh (from `roadmap.md`)

The criteria checklist now reads:

- [~] Public API frozen — every exported symbol named, documented,
      tested (live-syscall surface partial; rest ✓ as of v0.5.0)
- [x] Both initial consumers integrated and green
- [~] Test coverage adequate for the surface area (47 unit + 1–3
      live-gated; consumer PTY smoke for the rest)
- [x] CHANGELOG complete from v0.1.0 onward
- [x] Security posture documented — ADR 0002

### Notes

- No darshana source change in `src/`. The dist bundle bytes
  match v0.4.1 verbatim; the version header bumps to `0.5.0`.
- chakshu's `cyrius.cyml [build].test` was missing entirely (bare
  `cyrius test` had no entry point) — added pointing at
  `tests/chakshu.tcyr` while wiring up 0.6.1. Cross-repo polish,
  not strictly an M4 deliverable, but flagged in chakshu's
  CHANGELOG `[0.6.1]`.

## [0.4.1] — 2026-05-20 — M3 close-out + docstring hardening

Doc-only patch shipped the same day as 0.4.0 once cyim 1.7.1
satisfied the M3 gate (cyim CI green on darshana 0.4.0 + cyrius
6.0.1). Two deferred-hardening items from the 0.4.0 audit land
here; no source-behavior change, no surface change.

### Changed

- **`TIO_BUF_SIZE` docstring** — clarifies the role of the
  constant (canonical name for callers ioctling TCGETS/TCSETS
  directly) and records the Cyrius array-size constraint that
  forces the internal `_tty_saved[60]` / `work[60]` declarations
  to use the matching literal instead of the named constant.
  Both sites now carry an inline comment tying them back to
  `TIO_BUF_SIZE`. Behavior unchanged.
- **`tty_winsize` docstring** — documents the out-pointer
  contract: `out_rows` / `out_cols` each receive an i64 (8 bytes)
  via `store64`, so callers must pass `&var` where `var` is a
  Cyrius natural. Catches a footgun where a caller passing a
  pointer to a smaller slot (e.g., a byte field inside a struct)
  would silently overflow.

### Docs

- `docs/development/state.md` and `docs/development/roadmap.md`
  refreshed to drop the "remote CI green pending push" hedging
  language from the 0.4.0 cut. M3 close is now recorded as fact
  (cyim 1.7.1 shipped on darshana 0.4.0).

### Notes

- No source-behavior change between 0.4.0 and 0.4.1. The dist
  bundle grows by ~18 lines (docstring additions only); the DCE'd
  smoke binary is byte-identical.

## [0.4.0] — 2026-05-20 — M3: cyim integration milestone

The milestone cut associated with cyim adopting darshana as its TTY
primitive provider. cyim 1.7.0 already ships with
`[deps.darshana] tag = "0.2.0"`; the M3 close ceremony — bumping
cyim from 0.2.0 → 0.4.0 to pick up the post-port additions
(`tty_winsize`, `tty_open_signalfd`, partial-clear helpers, SGR
helpers) — happens in cyim's repo. From darshana's side, this
release adds one hardening item and one ADR; no breaking changes,
no new public functions.

### Added

- **ADR 0002 — Termios state-restore posture.** Codifies the design
  decision that darshana provides the primitives (module-global
  `_tty_saved`, idempotent `tty_cooked`, `tty_open_signalfd` +
  `TTY_SIGMASK_EXIT`) and consumers own the teardown contract —
  *not* the other way around. Closes the v1.0 release criterion
  "Security posture documented — termios state-restore guarantees
  on every exit path." See [`docs/adr/0002-state-restore-posture.md`](docs/adr/0002-state-restore-posture.md).

### Changed

- **`tty_sgr(code)` now validates its input.** Codes outside `[0, 999]`
  return `-1` *before* any bytes reach fd 1. Previous behavior on an
  out-of-range code was to emit a malformed CSI sequence (the digit
  formatter assumed `code < 1000`); the buffer was sized to absorb
  the extra byte so there was no overflow, but the terminal would
  see garbage. Backwards-compatible for any caller already passing
  a value in range (every `TTY_FG_*` constant is in `[30, 97]`).

### Tests

- 3 new assertions on `tty_sgr` rejection paths
  (negative / `>= 1000` / deeply negative). Total 47 (was 44). The
  rejection paths short-circuit before any write, so they're safe
  to call in-test without polluting the output with stray ANSI.

### Notes

- M3 close ceremony — bumping `state.md` consumers table to
  "cyim 1.7.0 → live on darshana 0.4.0" and marking the roadmap M3
  ✓ — lands as a separate doc-only commit after cyim CI is green
  on the bumped dep, per the M3 gate.
- No source line-count change worth noting (≈3 lines added to
  `src/ansi.cyr` for the guard + docstring; nothing else moved).

## [0.3.5] — 2026-05-20 — SGR helpers + toolchain bump

Two changes, both driven by bannermanor's M5 (color via darshana):

1. **SGR helpers.** Pre-0.3.5, darshana covered cursor / alt-screen
   / clear / signalfd / termios — every screen control except text
   color. bannermanor's `--color cyan TEXT` needed primitives this
   library didn't have, so they're added here rather than inlined in
   the consumer (the CLAUDE.md "no raw ANSI in the consumer" rule).
2. **Toolchain bump 5.10.20 → 6.0.1.** Caught darshana up to the
   ecosystem-wide cycc pin. Pure version-pin change — `cyrius update`
   refreshed `lib/` from the matching snapshot; no source edits
   required.

### Added

- **`tty_sgr(code)`** — emit `CSI <code>m` to set an SGR attribute.
  Most callers pass a `TTY_FG_*` constant, but any 1–3 digit decimal
  works; this is the door for future bold (1) / underline (4) /
  background (40–47, 100–107) helpers without growing the function
  surface.
- **`tty_sgr_reset()`** — emit `CSI 0m` to clear all SGR attributes.
  Pair with every `tty_sgr` call before returning to the user's
  shell prompt; darshana does not install an exit handler.
- **16 named foreground-color constants** — `TTY_FG_BLACK` (30) …
  `TTY_FG_WHITE` (37), `TTY_FG_BRIGHT_BLACK` (90) …
  `TTY_FG_BRIGHT_WHITE` (97). Values are raw SGR parameter codes;
  consumers map color names to these and pass to `tty_sgr`.

Background colors (40–47 / 100–107) and ANSI-256 / truecolor are
deliberately deferred — bannermanor M5 only needs the 16 named
foregrounds, and CLAUDE.md says "consumers drive the API."

### Changed

- `cyrius.cyml` pin bumped `5.10.20` → `6.0.1`.
- `lib/` refreshed via `cyrius update` to the 6.0.1 snapshot.
- `scripts/smoke.sh` API-surface check now requires `tty_sgr`,
  `tty_sgr_reset`, and the 16 `TTY_FG_*` constants. Total: 19
  required fn symbols (was 17), 35 required const symbols (was 19).

### Notes

- The `lib/fmt.cyr` `undefined function 'vec_get'` build warning is
  pre-existing (predates this release) and benign — fmt is not
  invoked from darshana's own source, only present transitively in
  `lib/`. The unreachable fn count climbed because the dist bundle
  now carries the new SGR symbols.

## [0.3.0] — 2026-05-09 — M2: chakshu-driven extensions

The Phase 3 work the original chakshu TUI extraction plan deferred —
finally executing because chakshu's M2 Slice D (dynamic resize)
needs primitives darshana didn't have. Three new functions plus
two helper constants. No breaking changes; pure additions, so any
v0.2.0 consumer keeps working.

### Added

- **`tty_winsize(fd, out_rows, out_cols)`** — TIOCGWINSZ ioctl wrapper.
  Reads terminal dimensions into the caller's out-pointers; returns 0
  on success, -1 on ioctl failure. Lives in `src/termios.cyr` under
  the `CYRIUS_TARGET_LINUX` gate alongside `tty_raw` / `tty_cooked`.
  `TIOCGWINSZ = 0x5413` exposed as a const for callers wanting to
  ioctl directly. Driven by chakshu's M2 Slice D.
- **`tty_open_signalfd(sigmask)`** — promoted from chakshu's
  `_tui_open_exit_signalfd`, generalized to take a mask. Blocks the
  signals on the calling thread via `sys_sigprocmask` (SIG_BLOCK) and
  creates a signalfd that delivers them. Caller-supplied mask covers
  any signal set; common-case constants below. Avoids the
  `rt_sigaction` x86_64 sa_restorer trampoline trap by routing to a
  regular fd instead of installing synchronous handlers.
- **`TTY_SIGMASK_EXIT = 0x4003`** — HUP/INT/TERM bitmap for the
  "guaranteed cleanup at exit" pattern. Linux sigset_t encoding:
  bit 0 (HUP) | bit 1 (INT) | bit 14 (TERM).
- **`TTY_SIGMASK_WINCH = 0x08000000`** — SIGWINCH(28) bit 27. Used
  by chakshu Slice D to wake the render loop on resize. Disjoint
  from EXIT — callers can OR them into one signalfd or open two
  separate fds (chakshu does the latter for clearer dispatch).
- **`tty_clear_to_eol()` / `tty_clear_to_end()`** — partial-clear
  ANSI helpers (CSI K and CSI J). Promoted from chakshu's inline
  `_tui_clear_eol` / `_tui_clear_to_end`. Used in render loops to
  wipe row leftovers without flickering the whole screen.

### Tests

- 4 new assertions on the constants (TTY_SIGMASK_EXIT/WINCH math +
  disjointness, TIOCGWINSZ kernel ABI value). Total 44 (was 40).
  TTY-bound functions (`tty_winsize`, `tty_open_signalfd`) need a
  real TTY fd / signal delivery to exercise; integration coverage
  comes via cyim's PTY smoke at Phase 4.

### Tooling

- `scripts/smoke.sh` API contract surface check expanded to require
  the four new function names + three new constants. The dist drift
  check auto-catches forgetting to regenerate `dist/darshana.cyr`
  after the source changes.

### Notes

- No breaking changes — pure additions. v0.2.0 consumers (none yet
  outside chakshu, which is consuming v0.2.0 today) can stay on v0.2.0
  if they don't need the new surface. chakshu's Slice D bumps to
  v0.3.0 to use `tty_winsize` + `TTY_SIGMASK_WINCH`; cyim's eventual
  Phase 4 migration also benefits from `tty_clear_to_eol/to_end` if
  it grows partial-redraw paths.

## [0.2.0] — 2026-05-09 — M1 close

The donor port. cyim's private `src/tty.cyr` now lives here as a
shared library, split into three domain modules and ready to be
consumed by both cyim (Phase 4) and chakshu (Phase 5 of the M2 TUI
extraction plan). All public symbol names preserved verbatim — the
upcoming cyim migration is a manifest swap, not a rename.

### Added

- **M1 — donor port from cyim/src/tty.cyr.** Verbatim functional behavior,
  split per concern. All public symbol names preserved (`tty_raw`,
  `tty_cooked`, `tty_apply_raw_flags`, `tty_alt_enter/leave`, `tty_clear`,
  `tty_cursor_hide/show/home`, `tty_move`, `tty_itoa`, `tio_load32/store32`,
  plus the `TIO_*` flag constants) so Phase 4's cyim migration is a manifest
  change, not a rename.
  - `src/termios.cyr` — Linux raw-mode (TCGETS/TCSETS via ioctl), the
    `tty_apply_raw_flags` bit-twiddling, cooked-mode save/restore.
    `#ifdef CYRIUS_TARGET_LINUX` gates the syscall arm.
  - `src/ansi.cyr` — alt-screen, clear, cursor visibility helpers
    (vt100-compatible, no Linux gate).
  - `src/cursor.cyr` — `tty_move(row, col)` + the `tty_itoa` decimal
    formatter it composes with.
  - `src/main.cyr` — convenience entry that includes the three sub-modules
    (for smoke + tests). Not in `[lib].modules` — distlib reads those
    three files directly so dist doesn't double-include.
  - `cyrius.cyml [lib].modules` set to the three sub-modules; stdlib dep
    footprint tightened to `syscalls / alloc / io / assert` (was the init
    default `string / fmt / alloc / io / vec / str / syscalls / assert`).
  - `dist/darshana.cyr` — 271-line bundled distribution, generated by
    `cyrius distlib`. Consumers get the whole API via one
    `include "lib/darshana.cyr"` after `cyrius deps`.

### Tests

- **38 new assertions across 3 groups**, total 40 (was 2 placeholder).
  Coverage: `tio_load32 / tio_store32` round-trip including offset
  isolation; `tty_apply_raw_flags` bit-clear / bit-set verification
  per the donor's intent (vim-convention raw mode — ISIG cleared so
  Ctrl-C reaches as a byte, OPOST cleared so `\n` isn't post-processed)
  plus idempotence; `tty_itoa` decimal formatter for zero, negative,
  single/two/three-digit, and position-offset cases.
- TTY-bound functions (`tty_raw / tty_cooked / tty_alt_* / tty_cursor_*
  / tty_move`) need a real TTY fd to ioctl against and stdout-byte
  capture, neither cleanly available in unit-test scope. Phase 4 (cyim
  migration) re-runs cyim's existing PTY integration smoke against
  darshana — that's the end-to-end coverage path.

### Notes

- `tty_probe` from cyim's donor was **not** ported — it's a cyim-
  specific diagnostic ("[cyim tty probe: raw mode active]" string).
  Consumers wanting a probe write their own using the public API.
- `_tty_saved` / `_tty_in_raw` are module-globals (not caller-owned)
  so signal handlers and panic paths can reach them for cleanup
  without threading state. Same shape as the donor.

### Tooling

- **CI/release workflows.** `.github/workflows/ci.yml` (three jobs:
  build-and-test → lint → tests → smoke → distlib drift → DCE parity;
  security scan; docs + version-consistency) and `.github/workflows/release.yml`
  (semver-tag-triggered, gates on CI via `workflow_call`, version-verify
  against tag, package step that regenerates dist + ships
  `darshana-X.Y.Z.cyr` + `darshana-X.Y.Z.tar.gz` + source tarball + SHA256SUMS,
  GH release with body extracted from the matching CHANGELOG section).
  Patterned on chakshu/owl; library-shape adaptations (no binary
  matrix; dist/darshana.cyr is the consumable artifact).
- `scripts/smoke.sh` — runs the smoke binary, verifies dist drift,
  asserts the cyim-API contract surface (13 `tty_*` / `tio_*`
  function names + 16 `TIO_*` constants present in dist), and checks
  the `CYRIUS_TARGET_LINUX` gate is intact in `src/termios.cyr`.
- `cyrius.cyml` `[package].version` switched to `${file:VERSION}`
  indirection (was a literal `"0.1.0"` from the `cyrius init`
  template); CI version-consistency check now closed-loop.

### Fixed

- CI Test step uses explicit `cyrius test tests/darshana.tcyr` rather
  than bare `cyrius test`. The bare form's auto-discovery failed on
  the GitHub-hosted runner against the 5.10.20 toolchain artifact with
  `No .tcyr files found in tests/tcyr/ or tests/` even though the
  test file was checked in and discovery worked locally — the
  discovery surface has varied between cyrius releases. The documented
  form per `cyrius help test` is `cyrius test <test.cyr>`; using it
  explicitly removes the discovery surface from CI altogether.

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
