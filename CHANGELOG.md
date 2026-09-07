# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Roadmap restructured around the semver cost of each open item, and a
stale-information sweep over every doc the last five releases outran. **No
executable line changed** — the `src/` diff is comment-only, and so is the
regenerated `dist/darshana.cyr`, so emitted bytes are unchanged by construction
rather than by measurement.

**Not assigned a version.** These are working-tree changes; the release they
belong to is the owner's call.

### Changed

- **`docs/development/roadmap.md` restructured.** It had accumulated the shape
  of a pre-1.0 milestone list while the library has been frozen and in
  maintenance for five releases. Now:
  - **"Where things stand"** stops restating counts that live in `state.md`,
    and says the honest thing: nothing about the shipped surface is
    outstanding.
  - **"Open now"** holds exactly one item, and flags that it is **not darshana
    work** — the five consumer dep bumps are downstream. It gains the two
    concrete reasons a consumer would bump beyond staying current: anuenue can
    delete a 48,960-byte pre-baked escape table that v1.1.0's composers are now
    *faster* than (34.8 ns vs 39.3 ns), and chakshu holds two live signalfds,
    which is exactly the shape v1.0.2's rollback fix was written for.
  - **"Next, by bucket"** replaces the old flat "Tracked, additive" list with
    `1.1.x` / `1.x.0` / `2.0.0` sections, so a candidate lands in the right
    bucket instead of being argued about. The patch bucket is explicitly
    *empty* — every carry-forward the v1.0.x sweeps opened is closed.
  - **`2.0.0`** is a new section, listing the two imperfections ADR 0003
    knowingly froze in. Neither is planned; they are written down because a
    frozen imperfection nobody records gets rediscovered as a surprise. It also
    notes that *adding* `tty_forget()` would be a **minor**, not a major — only
    changing the existing model breaks.
  - **"Out of scope"** keeps its charter decisions verbatim, plus a note that
    `--win` builds succeed incidentally and the toolchain's syscall-routing
    advisory there is expected.

- **`CLAUDE.md` — six stale rules corrected.** It is the durable-rules file, so
  a wrong rule there propagates:
  - The Quick Start ran `cyrius test` with no argument and named two suites.
    There are **three**, and two are cross-target — `tests/agnos.tcyr` and the
    aarch64 runs must be *built for their target and executed*, which
    `cyrius test` cannot do. Both spelled out.
  - "Do not modify `lib/` files" understated it. `lib/` is **output**:
    `[deps].stdlib` is the only declaration, `rm -rf lib/ && cyrius deps`
    rebuilds it, and `cyrius lib sync` does **not** close the transitive graph —
    its file list is not the footprint.
  - The platform-gate rule still pointed at `scripts/smoke.sh` checking
    "positionally, by line number". That moved to `scripts/platform-gate.sh` at
    v1.0.2 and became corpus-wide (every `src/*.cyr`, not just `termios.cyr`).
  - **New rule: never write a syscall number as a bare integer.** The class has
    bitten three times; it is now mechanically gated, and the rule belongs
    beside the allowlist rule rather than only in a script comment.
  - The roadmap was described as "what is left to do through v1.0 and beyond" —
    v1.0 shipped four releases ago.
  - Process step 6 said to sync the version into `cyrius.cyml`. It carries
    `version = "${file:VERSION}"`; CI asserts that indirection is still there
    rather than a literal. Replaced, and a step 7 added for regenerating
    **both** dist artifacts.

- **`docs/guides/getting-started.md`** never learned about `tests/agnos.tcyr`
  (v1.0.2), `scripts/platform-gate.sh` (v1.0.2), or the aarch64 runs. Its
  "Adding a feature" recipe told a contributor to run two suites on one
  architecture; it now runs all of them on all targets, with the note that the
  aarch64 run is what has caught **every** arch-blind syscall number this
  project has shipped.

- **`docs/architecture/002`** described the arch-specific-syscall trap as
  something that happened once, through v0.9.1. It has happened **three times**;
  the note now carries the table, names both gates that enforce it, and records
  that each carries a `--self-test`. Its sentinel-normalization paragraph
  credited v0.9.3 alone — that release normalized `tty_open_signalfd` and missed
  its teardown twin for three releases, which is the more useful lesson and is
  now the one written down.

### Fixed

- **`state.md` contradicted itself about the registry promotion.** The v1.0.0
  entry and the CHANGELOG both record it as landing *with the tag*; the
  milestone summary at the bottom of the same file still listed it as open.
- **`state.md`'s sidecar row** said `dist/darshana.deps` was 7 lines / 5
  entries. It has been 8 / 6 since v1.1.1 added the `args` leaf.
- **Two `src/` comments referenced a roadmap section that does not exist** —
  `§"Out of scope (for v1.0)"`, where the heading has been plain
  `## Out of scope` since the v1.0 milestone closed. `src/ansi.cyr` now points
  at the `1.x.0` bucket where `tty_bg_256_buf` actually lives, and
  `src/termios.cyr` at the real heading. These ship in `dist/darshana.cyr`,
  which is the API reference consumers read, so a dangling cross-reference
  there is a shipped defect rather than a private note.

### Verification

- **Comment-only, proven not assumed**: `git diff src/` and
  `git diff dist/darshana.cyr` contain no non-comment line. No executable byte
  moved, so the ADR-0003 frozen surface is untouched by construction.
- 309 assertions on x86_64 (238 + 56 + 15) and 294 on aarch64 (238 + 56) under
  `qemu-aarch64`; `scripts/smoke.sh` PASS; both gate self-tests pass;
  `cyrius lint` clean; the example builds and runs.


## [1.1.1] — 2026-09-07

**aarch64 goes into CI — and doing that found that four assertions, including
v1.0.2's signalfd security regression test, had never actually run there.**

Patch-shaped: **no `src/` file changed**, and `dist/darshana.cyr` is
byte-identical to the v1.1.0 tag. The only shipped delta is one line in
`dist/darshana.deps`. Everything else is CI, tests, gates and docs. (Same shape
and same semver call as v1.0.1, which added the `vec` leaf.)

### Added

- **aarch64 is now verified on every CI run** — smoke plus both suites,
  cross-built and executed. darshana targets Linux on x86_64 **and** aarch64,
  and until v1.1.0 nothing had ever built the aarch64 arm, let alone run it;
  v0.9.2's `SYS_IOCTL` fix was verified by reading emitted machine code.

  ⭐ **The blocker v1.1.0 recorded turned out not to exist.** That release said
  a CI step "would need the compiler built or fetched first, because the
  standard installer does not place `cycc_aarch64`". Wrong: the published
  `cyrius-<v>-x86_64-linux.tar.gz` **does** contain `bin/cycc_aarch64`, an
  x86-hosted cross-compiler — the local 6.6.0 install simply predated it. So
  the install step CI already runs provides the compiler for free; the job just
  adds `qemu-user-static`. qemu-user passes syscalls through to the host
  kernel, so even the PTY harness gets **full** coverage there — it opens a
  real `/dev/ptmx` and drives a real pseudo-terminal. The step fails loudly if
  a future release stops shipping the compiler, rather than quietly becoming a
  no-op.

- **A gate for the arch-blindness class itself** (`audit_no_literals` in
  `scripts/syscall-audit.sh`). A syscall number written as a bare integer is
  correct for exactly one architecture, and this defect has now bitten the
  project **three times**, each time invisible because the toolchain's "syscall
  not routed" diagnostic is Mach-O-only:

  | | where | consequence |
  |---|---|---|
  | v0.9.2 | `src/termios.cyr` `SYS_IOCTL = 16` in an arch-blind gate | every ioctl in the library wrong on aarch64 (16 is `fremovexattr`) |
  | v1.0.2 | `docs/examples/raw_loop.cyr` `syscall(60, …)` for exit | a stray `winsize` on AGNOS |
  | v1.1.0 | `tests/pty.tcyr` + `tests/darshana.tcyr` | 15 of 53 pty assertions failed on ARM; four unit assertions silently never ran |

  The rule is now mechanical: a syscall number must be a **named** constant —
  the stdlib's (arch-aware by construction) or one declared inside an explicit
  `#ifdef CYRIUS_ARCH_*` gate. `syscall(1, …)` is the sole literal exception
  (`write(2)` is 1 on every Linux arch and on AGNOS, and every ANSI emitter
  uses it). It scans `src/`, `tests/`, `programs/` and `docs/examples/` —
  `tests/` is where this class hid longest. `--self-test` proves it rejects a
  literal `ioctl(16)` and a literal `exit(60)` **and** still accepts
  `syscall(1, …)`, so it cannot silently become either useless or over-strict.

### Fixed

- ⛔ **Four assertions — including the v1.0.2 signalfd rollback security
  regression test — had never run on aarch64, and looked like a deliberate
  skip.** `tests/darshana.tcyr` guarded them behind an `RLIMIT_NOFILE` squeeze
  using the bare x86_64 `prlimit64` number 302; on aarch64 that is 261, so the
  guard's `== 0` check simply failed and the whole block was skipped. The suite
  reported 234/238 there and read like intentional degradation. It was a wrong
  syscall number. Now gated per-arch — **aarch64 runs 238/238, full parity with
  x86_64.** So the fix v1.0.2 shipped for a signal-handling defect that could
  strand a user's terminal is, as of this release, actually verified on both
  architectures rather than one.

- **Three more arch-blind numbers in the same file**: `openat` 257 and `close`
  3 (56 and 57 on aarch64) now use the stdlib's `sys_open` / `file_close`, and
  the process exit uses `SYS_EXIT` rather than the literal 60. The exit code
  happened to propagate correctly on aarch64 anyway — verified across several
  codes — because the compiler's implicit epilogue carries it, but relying on
  that is luck rather than contract, and CI's pass/fail signal depends on it.

- ⭐ **The last `undefined function` warning in the tree is gone.**
  `_agnos_getenv` on the `--agnos` cross-build had been carried since before
  v1.0.0 as "pre-existing and upstream-shaped; nobody has checked". Checked: it
  is `lib/io.cyr` delegating to `_agnos_getenv`, which `lib/args_agnos.cyr`
  defines and which was simply not in darshana's declared footprint — the exact
  shape v1.0.1's `vec` / `vec_get` fix closed. Declaring the `args` leaf pulls
  it in. **No target now emits an `undefined function` warning**: native,
  `--agnos` and `--aarch64` are completely silent, and `--win` emits only the
  toolchain's generic syscall-routing advisory, which is informational, not
  darshana-specific, and concerns a target the roadmap puts out of scope.
  `dist/darshana.cyr` is byte-identical with and without the declaration.

### Carry-forwards closed

- **aarch64 in CI** — opened v1.0.2, half-closed v1.1.0 (verified by hand),
  fully closed here.
- **The inherited aarch64 `SYS_SIGNALFD4` renumber** (`74` → `1074`, a private
  alias upstream translates via `ESYSXLAT`) — recorded at v1.0.1 as "untested
  here for want of an aarch64 cross-compiler". Now verified: the signalfd
  open / close / rollback assertions run on aarch64 and pass, so the alias
  reaches the real `signalfd4`. They were not running even after v1.1.0 made
  aarch64 buildable — the `prlimit64` bug above was hiding them.

### Verification

- **Nothing that ships changed.** `git diff 1.1.0 -- src/` is empty and
  `git diff 1.1.0 -- dist/darshana.cyr` is empty, so the frozen 29 functions
  and 37 constants cannot have moved — a stronger statement than re-running the
  byte harness, because the source that produces those bytes is untouched.
  `dist/darshana.deps` gains exactly one line.
- **309 assertions on x86_64** (238 + 56 + 15) and **294 on aarch64**
  (238 + 56; the AGNOS suite is x86_64-hosted by construction), under
  `qemu-aarch64` and on a **Raspberry Pi 4** (Linux 6.8).
- `scripts/smoke.sh` PASS; both gate self-tests pass, now including the two new
  arch-blindness probes and the write(1) anti-over-strictness control;
  `cyrius lint` clean; DCE parity OK; AGNOS suite 15/15; examples build and run.


## [1.1.0] — 2026-09-07

**The two refactors v1.0.2 deferred, plus the first verification of darshana on
real aarch64 hardware.** Minor rather than patch because ADR 0003 prices
"internal refactors with identical output" that way — and identical output is
exactly what this is: the frozen 29 functions and 37 constants emit the same
bytes for the same inputs, proven exhaustively on three platforms.

⭐ **The two deferred refactors turned out to contradict each other, and doing
the first one as written would have made darshana ~40% slower.** That is the
substance of this release.

### Changed

- ⛔ **The two v1.0.2 findings conflicted, and the conflict was only visible
  once measured.** v1.0.2 recorded two byte-identical improvements to take at
  the next minor: (1) collapse the duplicate decimal emitter `_ansi_emit_u8`
  into `tty_dec_buf`, and (2) a ~30% speedup in the RGB composers whose main
  ingredient is *inlining* those same digit emissions. One says share a
  function; the other says stop calling one.

  Measured on this host (Ryzen 7 5800H, cyrius 6.6.0, 20M calls, median of 7,
  interleaved to control for thermal drift):

  | | v1.0.2 | delegate to `tty_dec_buf` | **shipped here** |
  |---|---|---|---|
  | `tty_fg_rgb_buf`  |  990 ms | 1418 ms (**+43%**) | **696 ms (−30%)** |
  | `tty_fg_256_buf`  |  458 ms |  605 ms (**+32%**) | **303 ms (−34%)** |
  | `tty_sgr_buf`     |  353 ms |  511 ms (**+45%**) | **289 ms (−18%)** |

  Refactor (1) as literally described is byte-identical and a **large
  regression**: `tty_dec_buf` is a general i64 formatter that reverses digits
  through a 24-byte scratch array and copies them back, where these composers
  only ever emit 1–3 digits. The two findings came from different audit lenses
  (refactor vs optimization) and neither measured the other's direction.

  So the duplication was removed by **elimination rather than delegation**: the
  1–3 digit sequence is written inline at each of the five call sites and
  `_ansi_emit_u8` is deleted. That satisfies what refactor (1) actually
  wanted — no second decimal-emitter *function* in the library — while getting
  faster instead of slower.

- **`_ansi_emit_u8` deleted.** ADR 0003 explicitly lists it among the
  `_`-prefixed symbols that "may be renamed, resliced, or deleted in a minor
  release", so this is the not-frozen clause working exactly as designed. The
  ADR's enumeration is updated to match.

- **The 7-byte fixed prefixes are now single wide stores.** `_ansi_rgb_buf`'s
  `ESC [ <layer> 8 ; 2 ;` and `tty_fg_256_buf`'s `ESC [ 3 8 ; 5 ;` were seven
  `store8` + increment pairs each; they are now one `store64`. The 8th byte is
  always overwritten immediately by the first digit — the shortest escape
  either composer can produce is 13 and 9 bytes respectively, so `[pos, pos+8)`
  is strictly inside the result. `tty_sgr_reset_buf`'s four pairs became one
  `store32`, which writes exactly the four bytes it produces with no overrun
  argument needed at all.

  ⚠ These are darshana's **first unaligned wide stores**, which is why v1.0.2
  declined to take them: the aarch64 question could not be answered on this
  host. It can be now — see *Verification*.

- ⛔ **Two audit conclusions are recorded in the source so they are not
  re-litigated**, both measured rather than reasoned:
  - **Do not substitute reciprocal multiplication for the divisions.**
    `(val*41)>>12` for `/100` and `(val*205)>>11` for `/10` are exact over this
    domain and are **slower** (1040 ms vs 1000 ms): the extra multiply/shift
    nodes cost more in cycc's stack machine than Zen3's `idiv` on small
    operands saves. anuenue's `src/filter.cyr` asserts the divides dominate
    here; they do not.
  - **The cost was the CALL, not the arithmetic.** cycc's prologue
    unconditionally spills `rbx`/`r12`–`r15` even in a leaf function that
    touches none of them, so `_ansi_rgb_buf` paid ~30 wasted memory ops per
    call for its three digit emissions. This deliberately re-expands what
    v0.9.3 deduplicated, so the reason is written at the site: if cycc ever
    grows a leaf-prologue optimization, re-collapsing becomes free — measure
    before assuming it still is.

  Context for why 15 ns matters: anuenue currently builds a 1,530-entry,
  48,960-byte heap table of pre-baked escapes plus a per-character copy loop
  purely to avoid this call. The v1.0.2 audit measured that replica at 39.3
  ns/call — **slower than the composer now is** (34.8 ns). Its biggest consumer
  can delete 48 KB of heap, a build pass and a cache-invalidation bug class,
  and get faster doing it.

### Fixed

- ⛔ **`tests/pty.tcyr` — darshana's deepest coverage — was silently x86_64-only,
  and failed 15 of 53 assertions the first time it ran on real aarch64.** Its
  ABI block hardcoded `SYS_ioctl = 16`, `nanosleep = 35`, `dup = 32`,
  `dup2 = 33`, `prlimit64 = 302` and `rt_sigprocmask = 14` inside a gate that is
  only `CYRIUS_TARGET_LINUX` — which is arch-**blind**. On aarch64 syscall 16 is
  `fremovexattr`, so every `TCGETS` / `TIOCGWINSZ` probe in the harness was
  calling the wrong kernel entry point, and the resulting failures were reported
  against darshana rather than against the test. Syscall 35 there is `unlinkat`,
  not `nanosleep`.

  This is the v0.9.2 `SYS_IOCTL` defect for the third time — an x86_64 literal
  in an arch-blind position, no diagnostic — now living in the harness that
  exists to catch it. Everything the stdlib defines arch-aware is taken from the
  stdlib (`SYS_IOCTL` 16/29, `SYS_DUP` 32/23, `sys_sigprocmask` 14/135); the two
  it does not define (`nanosleep`, `prlimit64`) get an explicit
  `CYRIUS_ARCH_X86` / `CYRIUS_ARCH_AARCH64` gate; and `dup2` gets a local
  two-line helper because aarch64 has no `dup2` at all, only
  `dup3(old, new, 0)`. **56/56 on both architectures now.**

- **`tests/darshana.tcyr` read the signal mask with a hardcoded x86_64 syscall
  number.** Four sites used `syscall(14, 0, 0, &buf, 8)` for `rt_sigprocmask`.
  That number is **135 on aarch64**, so on that target the read returned
  something else entirely and the assertions checked garbage. Found the moment
  the suite was first run on aarch64 — it failed there and passed on x86_64.
  This is precisely the v0.9.2 `SYS_IOCTL` class of defect (an x86_64 constant
  in an arch-blind position, no diagnostic), living in the test suite that is
  supposed to catch it. Now uses the stdlib's arch-aware `sys_sigprocmask`.

### Added

- **Tests: 295 → 309** (`darshana.tcyr` 224 → 238). The assertions that called
  `_ansi_emit_u8` directly now drive the same three digit-length branches
  through the **public** composers, which is what actually ships — same
  coverage, one layer further out. Plus new assertions pinning each byte of the
  256-colour composer's wide-stored prefix, and a poisoned-canvas check that
  the byte past the escape is untouched — the specific hazard a wide store
  introduces.

### Verification

- ⭐ **darshana ran on real aarch64 hardware for the first time**, closing the
  carry-forward v1.0.2 opened ("the aarch64 arm is *unbuilt*, not
  *known-good*"). The toolchain ships no `cycc_aarch64` in the installed tree,
  but the cyrius repo builds one, and pointing `CYRIUS_HOME` at a sandboxed
  copy — never mutating the live toolchain — produces working aarch64 ELFs.
  Verified in three places, in increasing order of authority: `qemu-aarch64`,
  then a **Raspberry Pi 4 (Linux 6.8, aarch64)**.

  | | smoke | `darshana.tcyr` | exhaustive equivalence checksum |
  |---|---|---|---|
  | x86_64 native | ok | 238/238 | `2666313271416689717` |
  | aarch64 (qemu) | ok | — | `2666313271416689717` |
  | **aarch64 (Pi 4, real)** | **ok** | **234/234** + pty **56/56** | **`2666313271416689717`** |

  (234 rather than 238 on aarch64: the four assertions behind the `prlimit64`
  forced-failure guard skip there, by design.) **That is what licensed the
  unaligned wide stores** — the same checksum before and after the refactor, on
  real ARM, not an argument about `SCTLR.A`.

- **Emitted-byte identity, two independent proofs.**
  - The v1.0.2 streaming harness — 13,518 records / 178,199 bytes across every
    composer's full envelope — is **byte-identical**, `sha256:6dcd7228…`,
    unchanged since v1.0.1.
  - A new exhaustive checksum harness folds the return value **and all 48 bytes
    of a `0xAA`-poisoned canvas** for every case, composing at `pos = 3` so a
    wide store cannot land on a convenient alignment. It sweeps
    `tty_fg_rgb_buf` and `tty_bg_rgb_buf` over the **complete `[0,255]³` cube**
    (16,777,216 triples × 2 composers), plus every rejection edge, every start
    position including the negative reject, and the full `tty_sgr_buf` /
    `tty_fg_256_buf` / `tty_dec_buf` envelopes. Folding the whole canvas rather
    than the escape is what proves the wide stores leave no stray byte.
    Identical across all three platforms and both before and after.
- **309 assertions green**; `scripts/smoke.sh` PASS with the frozen 29 fns / 37
  constants bidirectionally audited; both gate self-tests pass; `cyrius lint`
  clean; DCE parity OK; the example builds and runs on both targets; AGNOS
  suite 15/15. Native builds emit **zero warnings**.


## [1.0.2] — 2026-09-07

**P-1 audit / refactor / hardening / optimization / security sweep** — the
first such cut since v0.9.3, and the first under the freeze. Seven audit
lenses over the whole surface, every finding put through a three-way
adversarial refutation pass with a distinct angle each (does it reproduce; is
the semver classification honest; is the severity honest): **32 raised, 28
survived, folded into 14 work items.**

Everything here is a **patch** under [ADR 0003](docs/adr/0003-v1-api-freeze.md):
a fix that makes behaviour match its existing documentation, a test, or a
gate. **No frozen byte moved** — verified exhaustively rather than asserted
(see *Verification*). Two confirmed findings were deliberately **not** taken
because they price as minor; they are named at the bottom rather than quietly
carried.

### Fixed

- ⛔ **`tty_open_signalfd`'s failure rollback unblocked signals it did not
  block, silently disarming a consumer's exit path.** On the `signalfd(2)`
  failure path the rollback issued `SIG_UNBLOCK` over the **whole requested
  mask** instead of restoring the mask in force on entry — and the `SIG_BLOCK`
  passed `oldset = 0`, so the prior mask was never captured and could not be
  restored.

  When a signal in the mask was **already blocked** — most importantly by an
  earlier, still-open darshana signalfd, which is the documented
  multi-signalfd pattern (chakshu holds an EXIT fd and a WINCH fd) — the failed
  open unblocked it, and the first signalfd **went deaf**. For the flagship
  mask that is the "terminal left unrecoverable" outcome in full: a consumer
  whose second `tty_open_signalfd` fails on the documented degrade-gracefully
  path (EMFILE/ENFILE/ENOMEM) has SIGHUP/SIGINT/SIGTERM returned to default
  disposition, so the next Ctrl-C kills the process outright instead of waking
  the poll loop — `tty_cooked()`, `tty_alt_leave()` and `tty_cursor_show()`
  never run, and the user lands back in a shell that is still raw, still on the
  alt-screen, with the cursor hidden.

  This is **not** the v0.9.3 leak; v0.9.3 *added* this rollback, fixing the
  case where none happened at all. The residual defect is that the rollback it
  added was an unblock rather than a restore, and it contradicted the
  function's own frozen docstring ("A failed open leaves NO residue"). The -1
  path did leave residue — negative residue, removing a block the caller
  installed.

  Reproduced under `RLIMIT_NOFILE=3` with a live SIGWINCH signalfd (SIGWINCH
  because its default action is *ignore*, so the demonstration is safe to run;
  with `TTY_SIGMASK_EXIT` the same sequence terminates the process).

  The fix captures the entry mask via `oldset` and unblocks **only the bits
  this call added** — `sigmask & ~prev`. Deliberately not `SIG_SETMASK` of the
  captured mask: `how` 0 and 1 are the only two values **both** kernels
  implement by name (agnos/mirshi's `sigprocmask#17` handles 0 and 1
  explicitly and would treat 2 as an unnamed store-verbatim fall-through), and
  unblock-what-you-blocked is the doctrine `tty_close_signalfd` already
  follows. Both arms fixed; mirshi honours a non-NULL `oldset_ptr`, verified
  in the agnos kernel source rather than assumed.

- **`tty_close_signalfd` returned a raw `-errno` where its docstring promised
  `-1`.** v0.9.3 normalized `tty_open_signalfd`'s sentinel and missed the
  teardown twin added alongside it, which went on returning
  `sys_sigprocmask`'s bare syscall result. So the two peers disagreed on a
  contract both claimed to share — the AGNOS one normalizes because mirshi
  does it for them, the Linux one did not. Latent rather than live
  (`rt_sigprocmask(SIG_UNBLOCK, <valid stack ptr>, NULL, 8)` has no reachable
  failure mode here), but ADR 0003 names exactly this case as patch-shaped.
  The AGNOS peer gained the same explicit clamp — redundant today, written so
  the two arms cannot diverge again if mirshi changes.

- ⛔ **`docs/examples/raw_loop.cyr` ended with a hardcoded `syscall(60, ...)`
  outside both platform gates.** 60 is `exit` only on x86_64 Linux — it is 93
  on aarch64 Linux, and on AGNOS it is `winsize`, the very syscall
  `src/termios.cyr` uses for `tty_winsize`. The shipped example whose header
  says it is the one to copy from therefore compiled to a stray console-grid
  query on agnos and exited via the implicit epilogue, with **no diagnostic**:
  the toolchain's "syscall not routed" warning is Mach-O-only, exactly as the
  v0.9.2 `SYS_IOCTL` fix records. `programs/smoke.cyr` two directories away had
  it right. Now `syscall(SYS_EXIT, ...)`, verified at the instruction level —
  the agnos build's tail is `xor %eax,%eax` (agnos exit = 0) where the literal
  emitted `mov $0x3c,%eax`. The example's copy-paste consumer manifest also
  still pinned `tag = "0.9.4"`, three releases stale and pre-freeze.

- **Four stale docstring blocks shipped in `dist/darshana.cyr`**, two of them
  on public frozen symbols. v0.9.3 extracted `_ansi_rgb_buf` and `_cursor_rel`
  as shared bodies and v0.9.4 restored the docstrings its extraction had
  destroyed — but left the originals stranded on the new private helpers, so
  the bundle carried **two** descriptions for `tty_bg_rgb_buf` and
  `tty_cursor_down`, and put a public function's frozen return contract on top
  of a private helper that does something else. v0.9.4's docstring audit is
  structurally blind to this: it checks a comment block is *present*, not that
  there is only one. All four removed.

### Changed — gate hardening

Every gate below had stopped being able to catch the thing it names. Each fix
is **mutation-proven**, and two of the gates now carry a `--self-test` that
re-proves it on every CI run, because a gate that cannot fail proves nothing.

- **`scripts/syscall-audit.sh` was bypassed by three ordinary Cyrius
  constructs**, and it is the only syscall gate in both `smoke.sh` and CI:
  a non-identifier first argument (`syscall((59), path, 0, 0)` did not match
  the regex at all — invisible rather than rejected), a line-wrapped call
  (grep is line-based), and any stdlib syscall wrapper outside the
  `sys_*` / `file_*` prefixes (`xopen`, `xunlink`, `xmkdir`, `getenv`, `panic`
  — filesystem sinks are precisely the class the script says it exists to
  catch). Fixed by normalizing before matching (comments stripped, string
  literals blanked, statements rejoined) and by making the callee scan a true
  allowlist: every called identifier must be a darshana-defined fn, a language
  builtin, or an explicitly listed wrapper. It now also scans
  **`docs/examples/`** — which is how the `syscall(60)` above was found, and
  which the old `SRC_DIR="${1:-src}"` default never looked at.
- **`scripts/platform-gate.sh` (new)** — the platform-gate check, extracted so
  `smoke.sh` and the CI security job share one implementation instead of two
  copies of the same awk. v0.9.3 fixed this check's *substring vs positional*
  half but left its **file scope**: it hard-coded `src/termios.cyr` as both the
  gate source and the search corpus, so identical ungated Linux ioctl code in
  `src/ansi.cyr`, `src/cursor.cyr`, or any new `[lib].modules` entry was never
  examined and would ship outside any `#ifdef` with every gate green. Now
  corpus-driven over every `src/*.cyr`, with a vacuity guard so a gutted tree
  cannot pass by containing no tokens at all.
- **The docstring audit exempted the entire AGNOS arm.** Its `!seen[name]++` /
  `!cseen[cname]++` de-dup meant only the first definition of each name was
  ever checked — and the bundle defines six public fns and two public
  constants twice (Linux peer, then AGNOS peer). The de-dup is gone. It found
  three real gaps immediately: AGNOS `tty_winsize` had shipped since v0.8.0
  with **no docstring at all**, and the AGNOS `tty_isatty` / `tty_cooked`
  peers never stated their return contract. All three written.
- **`dist/darshana.deps` had no drift gate.** Both drift checks diffed only
  `darshana.cyr` — and the `cyrius distlib` call they make to produce the
  comparison rewrites the sidecar *first*, so a stale committed sidecar was
  destroyed in the runner before anything could compare it. It is what tells a
  consumer's `cyrius deps` which stdlib leaves to resolve; v1.0.1 shipped
  precisely because that file was wrong. Both artifacts are now snapshotted,
  diffed, and restored on failure.

### Added

- **`tests/agnos.tcyr` — the AGNOS arm had zero coverage of any kind.** Six
  public functions, two ADR-0003-frozen constants and four mirshi syscall
  numbers were checked by nothing: no test touched them, and no CI job
  cross-built them. Both frozen AGNOS sigmask constants could be corrupted to
  their Linux values and `cyrius build`, `cyrius lint`, both suites,
  `scripts/smoke.sh`, `scripts/syscall-audit.sh` and even
  `cyrius build --agnos` all stayed green — confirmed by doing it. That
  mattered because the AGNOS values differ from Linux by design and cannot be
  inferred (mirshi encodes a signal set as `1 << sig`; Linux sigset_t uses
  `1 << (sig - 1)`).

  15 assertions, and the non-obvious part is that they **run on an ordinary
  Linux host**: `--agnos` emits an x86_64 ELF and `write(2)` is 1 on both
  targets, so the stdlib assert harness works unmodified. The file documents
  loudly what must **not** be called there — AGNOS `tty_isatty` / `tty_winsize`
  issue `syscall(60, ...)`, which on Linux is `exit`, so calling them would
  terminate the harness with status 0 and fake a pass. Its own exit likewise
  uses the **host** number, not `SYS_EXIT`: building for agnos and running on
  Linux made `SYS_EXIT` resolve to 0, which Linux reads as `read(2)`, so the
  process fell through, re-entered `main()`, printed the suite twice and
  segfaulted. That is written down in the file, because it will bite again.

- **A CI step that cross-builds and runs the AGNOS arm.** Nothing in CI
  compiled `#ifdef CYRIUS_TARGET_AGNOS` before: 6 of 29 frozen functions and 2
  of 37 frozen constants were never even parsed, so structural breakage there
  shipped.

- **Tests: 217 → 295 assertions** (`darshana.tcyr` 167 → 224, `pty.tcyr`
  50 → 56, `agnos.tcyr` 15 new). The additions target gaps the sweep proved
  were real, not coverage for its own sake:
  - **Frozen constant VALUES.** Only 4 of the 37 had their value asserted
    anywhere; `smoke.sh` checks each name is *present*, never what it equals,
    so a typo'd `TIO_ECHO` would have shipped green and raw-moded the wrong
    bit. All 37 now pinned to their kernel-ABI literals, written out rather
    than derived from the constant under test.
  - **`_tty_apply_raw_flags` preserves what it does not name.** Every existing
    raw-flag assertion checks a bit went to 0 or 1, so all 21 of them would
    still pass against an implementation that simply **zeroed all four flag
    words** — the half of the contract that matters on a real terminal was
    unasserted. Now sets unrelated bits in each word plus a non-VMIN/VTIME
    `c_cc` slot and requires them to survive, and requires the struct's tail
    padding to stay untouched.
  - **`tty_winsize`'s u16 high-byte decode.** The only geometry ever tested
    was 24×80 — both single-byte — so the `| (load8(...) << 8)` half of the
    decode was never executed. Now round-trips 0x0123 × 0x0456 through a real
    PTY, with distinct non-zero high and low bytes so a byte-order or
    field-swap error cannot coincide with the expected answer, and with
    non-zero pixel fields to prove they are ignored rather than folded in.
    Mutation-proven both ways.
  - **Accepted boundary inputs.** Every existing bounds assertion tested a
    *rejected* input, so an off-by-one that narrowed a frozen envelope would
    have passed. The inclusive edges are now asserted, including
    `tty_fg_rgb_buf(255,255,255)` landing exactly on its documented 19-byte
    budget.
  - **`tty_winsize` / `tty_isatty` on a live non-TTY fd**, distinguishing "not
    a terminal" from "bad fd", and asserting the out-pointers are left
    untouched on failure.
  - **A regression test for the signalfd rollback**, which fails with exactly
    the right message when the fix is reverted.

### Documentation

- **The frozen return-conventions table claimed all 29 public fns fell in one
  of four buckets; three fell in none** — `tio_load32`, `tio_store32` and
  `tty_close_signalfd`. A fifth bucket now covers the termios field codec, and
  `tty_close_signalfd` joins the fd-opener bucket alongside its twin.
- **`tty_winsize`'s docstring claimed it was "the only darshana primitive that
  writes a FIXED-WIDTH value through caller-supplied pointers".** `tio_store32`
  does exactly that. Reworded to the true distinction: it is the only one
  writing through an *out-parameter*.
- **`_ansi_emit_u8`'s docstring was wrong twice.** It declared a `[0, 255]`
  domain while `tty_sgr_buf` feeds it codes up to 999 (its own frozen
  envelope, handled correctly by the three-digit arm); and it justified
  duplicating `tty_dec_buf` with a language claim — that the
  termios → ansi → cursor bundle order leaves `tty_dec_buf` undefined at that
  point — which is **false** for cyrius 6.6.0, verified by building the module
  set in exactly that arrangement. Both corrected, with the real constraint
  recorded so the duplication is not re-created on a false premise.
- Buffer-sizing comments in `cursor.cyr` corrected: `tty_move`'s counted 20
  decimal digits per coordinate where `tty_dec_buf` emits at most 19 (so
  `buf[44]` is 2 bytes of headroom, not exactly the worst case), and
  `_cursor_rel`'s summed to 22 by luck — its middle term was written "(1)"
  where it meant 19.

### Verification

- **Emitted-byte identity, proven exhaustively.** ADR 0003 freezes emitted
  bytes, so a purpose-built harness drives every `_buf` composer across its
  full input envelope — `tty_dec_buf` over −5…10000 plus every decade boundary
  and i64 max, `tty_sgr_buf` over −3…1002, `tty_fg_256_buf` and all three RGB
  channels over −3…258 each, plus cube corners, a diagonal, negative-`pos`
  rejection and 20 start offsets per composer — recording both the produced
  bytes **and** the returned position, with its own decimal emitter so a change
  in `tty_dec_buf` cannot mask itself. **13,518 records / 178,199 bytes,
  `sha256:6dcd7228…`, byte-identical before and after every change in this
  release** (~3× the v0.9.3 precedent's 55,798 bytes).
- **295 assertions green** — 224 + 56 + 15. Every new gate mutation-proven:
  corrupting either AGNOS sigmask reddens `agnos.tcyr` (6 failures); dropping
  the winsize high-byte shift or swapping the row/col offsets reddens
  `pty.tcyr`; reverting the signalfd rollback reddens `darshana.tcyr`; an
  ungated ioctl token in `src/ansi.cyr` reddens the platform gate; a stale
  sidecar reddens the drift check; and each of the five syscall-audit bypasses
  is asserted rejected by its own self-test.
- `cyrius lint` clean; `scripts/smoke.sh` PASS with the frozen 29 fns / 37
  constants bidirectionally audited; DCE parity OK; the example builds and
  runs on both targets. **Native builds emit zero warnings**; `--win` zero;
  `--agnos` retains only the pre-existing upstream `_agnos_getenv` warning.
- `--aarch64` remains **unverifiable on this host** — `cycc_aarch64` is not
  installed, so `cyrius build --aarch64` fails before reaching darshana's
  source, at v1.0.1 and v1.0.2 alike. That arm is *unbuilt*, not *known-good*;
  tracked in `state.md`.

### Confirmed but deliberately not taken

Both price as **minor** under ADR 0003, not patch, and are recorded rather
than silently carried:

- **Collapsing `_ansi_emit_u8` into `tty_dec_buf`.** They are the same function
  over every input any caller can deliver, and the replacement was proven
  byte-identical over an exhaustive sweep. ADR 0003 prices "internal refactors
  with identical output" as minor, so it waits for 1.1.0. The false rationale
  that would have prevented anyone from trying is corrected now.
- **A measured ~30% byte-identical speedup in the RGB composers.** Same
  reasoning. (The audit also established that the divide-elimination one
  reaches for first makes it *slower* — worth recording before someone tries.)


## [1.0.1] — 2026-09-07

Toolchain + vendoring release. **No source change** — `src/` is untouched and
`dist/darshana.cyr`'s module bodies are byte-identical to 1.0.0. The frozen
surface ([ADR 0003](docs/adr/0003-v1-api-freeze.md): 29 functions, 37 constants)
is unchanged in name, arity, documented return contract, constant value and
emitted bytes. The whole diff to the shipped bundle is one line: the
`# Version:` header.

### Changed

- **cyrius toolchain pin `6.5.35` → `6.6.0`** in `cyrius.cyml [package].cyrius`.
  Unlike the v0.7.1 / v0.8.1 / v0.9.1 catch-ups, this one was not drift
  housekeeping: 6.5.35 had begun emitting a correctness advisory on *every*
  invocation — *"pins 6.5.35, which carries the v6.5.36 enum Critical (constants
  >= 2^62 read back as -1). Re-pin to 6.5.36 or later."*

  darshana is **not exposed**, and the decisive reason is structural rather than
  numeric: the defect corrupts **`enum`** constants, and darshana declares no
  `enum` at all — `grep -cE '^enum ' src/*.cyr dist/darshana.cyr` returns zero on
  every file. All 37 frozen constants are top-level `var`s. The numbers agree as
  a second check: the largest constant in the bundle is `TTY_SIGMASK_WINCH =
  0x10000000` (2.7e8, the AGNOS arm; `0x08000000` on Linux), about **ten** orders
  of magnitude below 2^62. But the pin is what `.github/workflows/ci.yml` greps
  to choose the installer version, so it had to move regardless.

  The jump spans twelve upstream releases. Two of them matter more than the
  advisory that prompted it, and darshana's exposure to both is nil for reasons
  worth recording:

  - **The P0 silent miscompile that shipped in v6.5.57 and was live for
    seventeen releases.** `X = Y;` between two struct-*pointer* locals copied the
    number of slots the *type* implies rather than the number the variables
    occupy, overwriting neighbouring locals — compiling clean, corrupting a
    neighbour, and surfacing somewhere else entirely. **darshana never built
    under an affected compiler**: its pin has been 6.5.35 since v0.9.1, which
    predates the defect's introduction in v6.5.57. The fix is
    inherited, not needed retroactively. (It would not have bitten regardless —
    darshana declares no struct-pointer locals; its only aggregates are the
    `var buf[N]` byte arrays the termios codec reads through `tio_load32` /
    `tio_store32`.)
  - **`Result` / `Option` / `Either` became a zero-allocation value form**,
    changing the arity of every payload-carrying value and **deleting `payload()`
    and `tagged_new()` outright**. This is the ecosystem's largest break in a
    year — eight sibling stdlibs needed source migration, two of them twice.
    **darshana needed none.** Its entire surface is raw `i64` return codes
    (`0` / `-1` / `-errno`), which is the return convention frozen at v1.0 and
    documented at the head of the bundle. A sweep of `src/`, `tests/`,
    `programs/` and `docs/examples/` finds zero occurrences of `payload(`,
    `result_unwrap`, `tagged_new`, `is_err_result`, `ok_via` / `err_via`, or the
    `?` operator. The vendored `lib/result.cyr` is the migrated 6.6.0 copy.

- **`lib/` re-resolved from the manifest and cut from 118 tracked files to 20**
  (7.8 MB → 456 KB). `[deps].stdlib` is cyrius's opt-in auto-prepend list and the
  only place the footprint is declared; `lib/` is **output**, not a curated
  directory. The whole change is therefore reproducible from the manifest alone:

  ```sh
  rm -rf lib/ && cyrius deps
  ```

  `cyrius deps` is the resolver and the authority — Phase 1 copies the declared
  leaves from the pinned snapshot, Phase 2 resolves named deps, Phase 3 runs a
  transitive BFS that pulls each leaf's own includes (`alloc` → `atomic` /
  `fnptr`, `assert` → `string` / `fmt`, `io` → `result` / `args_macos`). Run
  against an empty `lib/` it lands exactly 20 modules, every one byte-identical
  to `~/.cyrius/versions/6.6.0/lib`. Verified by resolving into a clean tree
  built from `git ls-files` and rebuilding there: smoke binary OK, 217 assertions
  green, `dist/darshana.cyr` byte-identical to the repo's.

  What went: roughly ninety sibling libraries darshana never includes (`mabda`,
  `sigil`, `sandhi`, `sankoch`, `bayan`, `yukti`, `patra`, `niyama`, `vani`, the
  six `tls_native_*` shards, and the rest), each frozen at whatever snapshot last
  vendored it, plus `lib/unicode/`. Ten of them — `agnosys`, `base64`, `bigint`,
  `csv`, `cyml`, `json`, `linalg`, `matrix`, `toml`, `u128` — **upstream has
  deleted entirely**; they are absent from the 6.6.0 snapshot and had been
  sitting in the tree as dead bytes since before v0.9.1. They were the standing
  carry-forward in `state.md` ("*ten modules upstream has since dropped … still
  sit in `lib/`*"), which this closes by deletion rather than by another note.

  ⚠ **`cyrius lib sync` is not the definition of the footprint** and should not
  be read as one. It copies the declared leaves plus their platform peers — 14
  files here — with **no transitive pass**, so it is a refresh tool for what is
  already vendored. Neither it nor `cyrius deps` prunes; deleting `lib/` first is
  what makes the result reproducible rather than accumulated.

- **`docs/development/state.md`'s Source table refreshed** — every row was stale.
  `src/termios.cyr` 463 → **593**, `src/ansi.cyr` 352 → **369**,
  `src/cursor.cyr` 107 → **137**, `src/main.cyr` 35 → **27**, and
  `dist/darshana.cyr` 922/935 → **1,099 module-body lines / 1,112 on disk**. The
  numbers had not been re-derived since v0.9.2, so the v0.9.3 refactor, the
  v0.9.4 docstring restoration and the AGNOS peers all landed without the table
  moving — in a file whose own header says it is refreshed every release. Counted
  with `wc -l`, not carried forward.

### Added

- **`vec` added to `[deps].stdlib`**, taking the declared footprint from four
  leaves to five. 6.6.0's `cyrius distlib` compile-verifies the sidecar it emits
  and reported *"sidecar: re-added 1 leaf(s) the inference missed
  (compile-verified)"*, so `dist/darshana.deps` now carries five entries.

  That fifth leaf is the far end of the **`undefined function 'vec_get'` warning
  `state.md` has carried as "known benign … upstream-stdlib shaped, not a
  darshana defect" since before v0.9.0**: `lib/assert.cyr:4` pulls `lib/fmt.cyr`,
  which is the only caller of `vec_get` outside `vec.cyr` itself, and `vec` was
  not in darshana's declared footprint — so the call site linked against nothing.
  (`state.md` had named `io.cyr` as the puller since before v0.9.0; that was
  wrong. `io.cyr` includes only `syscalls`, `result` and `args_macos` — `assert`
  is the one that pulls `fmt`, which is why the warning appears in the test
  builds too.) Declaring `vec` makes the manifest agree with the
  compile-verified sidecar, and **every native build is now warning-clean**:
  smoke binary, both test suites, the example, and `cyrius distlib`. The
  `--agnos` cross-build goes from four warnings to one, the survivor being a
  pre-existing `undefined function '_agnos_getenv'` that is upstream-agnos
  shaped and unrelated to this change (it reproduces identically at the v1.0.0
  tag). `--win` builds clean. `--aarch64` cannot be built or judged here at all:
  `cycc_aarch64` is not installed on this host, and it fails the same way at
  v1.0.0. The
  diagnosis was right that it was upstream-shaped and unreachable; it was wrong
  that nothing could be done about it locally.

  `dist/darshana.cyr` is byte-identical with and without the declaration — this
  changes the build footprint, not the shipped bundle. The cost is 160 bytes in
  the DCE'd smoke binary (15,808 → 15,968) and nothing in the frozen surface.

### Verification

- **217 assertions green** — 167 `tests/darshana.tcyr` + 50 `tests/pty.tcyr`,
  the PTY harness running its full set with no `SKIP pty:` degradation token.
- `scripts/smoke.sh` **PASS**: 29 `tty_*` / `tio_*` functions and 37
  `TIO_*` / `TIOC*` / `TTY_*` constants present and **bidirectionally**
  self-audited (no listed-but-missing, no shipped-but-unlisted); docstring audit
  clean; platform gate positionally clean (Linux ioctl arm confined to
  `src/termios.cyr` lines 193–452, agnos arm to 454–593).
- `scripts/syscall-audit.sh` **PASS** — 5 distinct syscall targets, 3 stdlib
  wrappers, all on the allowlist.
- `cyrius lint` clean on all four `src/*.cyr`.
- distlib drift clean; DCE parity OK (54,800 bytes eliminated, same
  output); `docs/examples/raw_loop.cyr` builds and takes its no-TTY path.
- `git diff dist/darshana.cyr` against 1.0.0 is **one line** — the `# Version:`
  header. `dist/darshana.deps` gains the `vec` line. Consumers (chakshu, anuenue,
  cyim, kii, bannermanor) need a dep bump for the sidecar; **no consumer code
  change is required.**


## [1.0.0] — 2026-08-23

**The API freeze.** No code change from v0.9.4 — the emitted bytes, the test
results, and `dist/darshana.cyr`'s module bodies are identical. What changes is
the promise: the surface stops moving.

darshana began as ~207 lines of `cyim/src/tty.cyr`, extracted in May 2026 once
chakshu became the second consumer needing the same machinery. It is now 29
functions and 37 constants over Linux and AGNOS, consumed by five projects.

### Added

- **[ADR 0003 — The v1.0 API freeze](docs/adr/0003-v1-api-freeze.md).** Names
  and enumerates the frozen surface rather than gesturing at it: all 29
  functions and all 37 constants, in full, plus the four things the freeze
  covers (names, arity, documented return contract, emitted bytes and constant
  values) and the three it explicitly does not (`_`-prefixed symbols, internal
  structure, additive platform coverage). Records the post-1.0 semver policy —
  what counts as patch, minor, and major — and names the two known-imperfect
  things being frozen in, so nobody re-discovers them as surprises: `tio_load32`
  / `tio_store32` bounds-check nothing, and the single-raw-fd model has no
  public reset for a permanently stranded slot.
- **Three hard rules in CLAUDE.md**, replacing the pre-1.0 latitude: breaking a
  frozen symbol needs a major bump and its own ADR; a new public symbol must be
  added to `scripts/smoke.sh`; a new syscall must be added to
  `scripts/syscall-audit.sh`.

### Changed

- **`docs/adr/README.md`** had said "_No ADRs yet_" since v0.1.0 while two ADRs
  sat on disk. It now indexes all three with their decisions and status.
- **CLAUDE.md's platform rule** said "Linux-only at v0.1.0–v0.4.x" — five minor
  versions out of date, and wrong since the AGNOS peers landed across
  v0.8.0–v0.9.0. It now states Linux + AGNOS, macOS out of scope, and points at
  the positional gate check that enforces it.
- **README** reflects a stable, frozen v1.0.0 rather than a pre-1.0 hardening
  window.

### The frozen surface

29 public functions (`tty_*`, `tio_*`) and 37 public constants (`TIO_*`,
`TIOC*`, `TTY_*`, `TCGETS`/`TCSETS`), enumerated in full in ADR 0003 and
machine-checked bidirectionally against `dist/darshana.cyr` by
`scripts/smoke.sh` on every CI run.

Everything `_`-prefixed — `_tty_saved`, `_tty_in_raw`, `_tty_raw_fd`,
`_tty_apply_raw_flags`, `_ansi_emit_u8`, `_ansi_rgb_buf`, `_ansi_rgb_write`,
`_cursor_rel`, `_AGNOS_*` — ships in the bundle but is **not** API and may
change in a minor release. ADR 0002 depends on the save-state globals being
*reachable* from a consumer's exit path; reachable is not frozen, and
`tty_cooked()` remains the supported way to restore.

### Known and accepted at the freeze

- **The five consumers are not yet on a v0.9.4+ dep** — chakshu and anuenue sit
  at 0.9.0, cyim and kii at 0.8.2, bannermanor at 0.7.1. The two v0.9.3 breaks
  were verified against all five trees and affect zero live call sites, so this
  is a sequencing gap rather than a correctness one, but it does mean the first
  real exercise of the frozen surface happens after this tag. Tracked in
  [`docs/development/roadmap.md`](docs/development/roadmap.md).
- **Registry promotion landed with the tag** — the pre-1.0 row moved out of
  agnosticos `docs/development/planning/shared-crates.md` (Pre-1.0 21 → 20) into
  `docs/applications/libs/README.md` under OS & Infrastructure (29 → 30, total
  89 → 90).
- **kii carries a pin mismatch** — its manifest `tag` says 0.8.2 while its
  vendored bundle reads 0.9.0, because it resolves via `path = "../darshana"`.
  To reconcile at its next bump.

### Verification

199 → 217 assertions green (167 `tests/darshana.tcyr` + 50 `tests/pty.tcyr`).
`cyrius lint` clean: zero warnings, zero untracked deferrals. Smoke passes all
seven gates — dist drift, forward and reverse fn surface, forward and reverse
constant surface, syscall allowlist, docstring audit, positional platform gate.
DCE parity holds. Both cross-builds (`--agnos`, `--aarch64`) clean. The example
builds and runs, and leaves a real pseudo-terminal byte-for-byte as it found it.

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
