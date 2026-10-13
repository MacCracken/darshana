# darshana — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.2.1** — *open cycle*. **darshana issues no raw syscall.** Every escape
emitter writes through the stdlib's `sys_write` (a literal `syscall(1, …)` was
right on aarch64, where write is 64, only because the backend rewrites it), and
the AGNOS arm calls the agnos stdlib's `sys_winsize`, `sys_sigprocmask` and
`sys_signalfd` instead of carrying its own copy of their numbers. All thirteen
identity digests are unchanged on x86_64, qemu-aarch64 and a real Pi 4.

The gates moved with it: `src/`'s syscall allowlist is **empty**, the arch
rule's literal-1 exemption is gone (tests included), and the platform gate's
new **peer rule** — a function defined more than once must have exactly one
definition in each target gate — replaces the two signalfd wrapper names it can
no longer police as Linux-only. Each was mutation-proven. Docs: the consumer
upgrade notes are a guide (`docs/guides/upgrading.md`), the roadmap is open
items and boundaries only, and `cyrius.cyml`'s comments are a manifest's.

**1.2.0** — *open cycle*. **A minor: five functions and eight constants
added, the composers 35–49% faster, and nothing already shipped changed.**
All eleven digests `tests/identity.tcyr` froze at 1.1.4 are unchanged on
x86_64, qemu-aarch64 and a real Pi 4; the two new ones (`tty_bg_256_buf`,
`tty_sanitize_buf`) are frozen from here.

⭐ **Added**, each the consumer-driven candidate whose second-consumer trigger
fired in the 2026-10-12 surveys: `tty_sanitize_buf` (+ `TTY_SANITIZE_UTF8` /
`_LATIN1`, `TTY_KEEP_TAB` / `_LF`; the output sanitizer the owner ruled into
the charter — ADR 0004), `tty_bg_256_buf`, `tty_read_signal`, `tty_winsize_or`,
`tty_raw_nonblock`, and `TTY_SGR_BOLD` / `_DIM` / `_UNDERLINE` / `_REVERSE`.
ADR 0003's new "Added since 1.0" table freezes them, and `scripts/smoke.sh`
checks it.

**Faster, byte-identically**: every composer writes its prefix as one literal
store (cycc 6.6.20 does not fold the OR chain the v1.1.0 store was built from)
and each digit field as exact-width packed stores. `tty_fg_rgb_buf` −36%,
`tty_fg_256_buf` −41%, `tty_sgr_buf` −35%, `tty_dec_buf` −49% (0–1023). The new
unaligned `store16` / `store32` were licensed on the Pi, as v1.1.0's `store64`
was.

**Refactors**: the ioctls go through the stdlib's `sys_ioctl`; `tty_raw`'s loop
reads `TIO_BUF_SIZE`; the AGNOS winsize decode is a pure, tested helper (the
rows/cols-swap mutant that survived 1.1.4 is caught). **Not taken**, with
reasons in the CHANGELOG: flattening the RGB wrappers, and moving the AGNOS arm
onto the stdlib's same-named signal wrappers (the platform gate polices those
names). mirshi's signal band was found broken for signalfds and filed in
mirshi's roadmap.

**1.1.4** — *open cycle*. **The third audit sweep — and the finding that
mattered most was about the gates, not the code.** Five lenses over a frozen
snapshot (correctness, security, tests and gates by mutation, docs truth,
optimization), every finding verified before it was acted on. **No frozen
name, arity, return contract, emitted byte or constant moved**, and that is now
proven rather than argued: `tests/identity.tcyr`'s eleven digests are identical
on v1.0.0, v1.0.2, v1.1.0, v1.1.3 and 1.1.4, on x86_64, under qemu-aarch64 and
on a real Raspberry Pi 4.

⛔ **The arch-blind syscall gate never covered what it claimed.** Its literal
rule globbed `*.cyr`, so it scanned no `*.tcyr` test, and it checked only
call-site literals, so a named constant in an arch-blind gate — the v0.9.2
shape — passed. Of 52 planted defects, **35 survived every gate** on the 1.1.3
tree. The sweep closed them by mutation: each new or tightened gate was shown to
fail on its defect before it was trusted.

⭐ **One implementation for every CI gate.** `scripts/ci.sh` is what `ci.yml`
calls step by step and what `bash scripts/ci.sh all` runs locally. It pins each
suite's assertion total, makes `SKIP` fatal under CI, makes build warnings
fatal, runs the suites under DCE, and drives the example's real TTY path under
`script(1)`.

**Code repairs, patch-shaped** (behaviour now matches the docs): the four Linux
fd-taking functions reject an fd outside [0, 0x7FFFFFFF] instead of aliasing a
different descriptor (the kernel reads fds as 32-bit unsigned); the AGNOS
`tty_close_signalfd` no longer passes -1 to a stdlib close that treats it as a
socket. **Docs that could strand a terminal**: ADR 0002's teardown order put
`tty_cooked()` behind three writes that SIGPIPE can kill — reordered.

**Supply chain**: CI fetched the toolchain installer — which carries the
release-signing key — from cyrius's unpinned `main`; now from the pinned tag.
Least-privilege tokens, SHA-pinned actions, releases verify rather than
regenerate `dist/` and ship the sidecar.

Optimizations found by the sweep (up to −57% on the RGB composers, all proven
byte-identical in scratch) are queued for 1.2.0, as ADR 0003 prices them.

**1.1.3** — *open cycle*. **Toolchain bump cyrius 6.6.2 → 6.6.20, and the
sidecar finally tells consumers the truth.** No `src/` line changed and
`dist/darshana.cyr`'s module bodies are byte-identical to the 1.1.2 tag, so the
frozen surface cannot have moved. What changed is packaging.

⭐ **`dist/darshana.deps` went from six leaves to two** (`syscalls`, `io`).
cyrius 6.6.18 made a sidecar exactly what `distlib`'s compile-verify fixpoint
proves the bundle needs, on six targets including agnos, instead of seeding it
from the producer's `[deps].stdlib`. So `alloc`, `assert`, `vec` and `args` —
darshana's own test and include-gap footprint — stop being pushed onto every
consumer. The bundle also gained a `# Requires` block (`include
"lib/syscalls.cyr"` / `"lib/io.cyr"`), making it compile with no other stdlib
include; includes are once-only by literal path, so existing consumers pay
nothing. Proven with a scratch path-dep consumer on x86_64, aarch64 and agnos,
with an empty `[deps].stdlib`, and again under the consumers' current 6.6.2 pin.

The two include-gap leaves were then **dropped from darshana's own footprint**:
6.6.20's `fmt.cyr` includes `vec.cyr` and its `io.cyr` includes
`args_agnos.cyr`, so both definers arrive through the BFS anyway. A/B-proven:
identical counts everywhere, zero warnings, smoke binary 99,312 → 95,184 B.
`cyrius.lock` is new and belongs in the repo.

⛔ **Two stale records corrected.** The consumer table and the roadmap's only
open item both had the five consumers on 0.7.1–0.9.0 — all five are on 1.x
(checked against each manifest *and* each vendored bundle), so the roadmap item
is closed. And 6.6.2's `lib/io.cyr` had been making every `--aarch64` build warn
(`raw syscall 32 is x86_64 dup`), which nothing recorded; 6.6.20 fixes it, and
no target now emits any warning.

**1.1.2** — *open cycle*. **Toolchain bump cyrius 6.6.0 → 6.6.2 (no source
edit; the one changed vendored file, `lib/result.cyr`, is comment-only), plus
the documentation sweep below: roadmap restructured around semver cost, and a
stale-information sweep over every doc the last five releases outran.** No
executable line changed — the `src/` and `dist/darshana.cyr` diffs are
comment-only, so emitted bytes are unchanged by construction rather than by
measurement.

`roadmap.md` had kept the shape of a pre-1.0 milestone list while the library
has been frozen and in maintenance for five releases. It now buckets everything
by the bump it would cost — `1.1.x` / `1.x.0` / `2.0.0` — with the patch bucket
explicitly **empty** (every carry-forward the v1.0.x sweeps opened is closed),
and a new `2.0.0` section recording the two imperfections ADR 0003 knowingly
froze in. Its single open item is flagged as **downstream, not darshana work**.

`CLAUDE.md` had six stale rules, which matters because it is the durable-rules
file: the Quick Start named two suites where there are three (two of them
cross-target and unreachable by `cyrius test`); "do not modify `lib/`"
understated that `lib/` is *output*; the platform-gate rule still pointed at
`smoke.sh` checking positionally, which moved to `scripts/platform-gate.sh` and
went corpus-wide at v1.0.2; the roadmap was described as running "through v1.0
and beyond"; and step 6 said to sync the version into `cyrius.cyml`, which
carries `${file:VERSION}`. A new hard rule was added for the arch-blind syscall
class that has bitten three times.

Also fixed: `state.md` contradicted itself on the registry promotion (the
v1.0.0 entry and the CHANGELOG both record it landing with the tag, while the
milestone summary still listed it open); the sidecar row was 7 lines / 5 entries
when it has been 8 / 6 since `args` landed; `getting-started.md` never learned
about `tests/agnos.tcyr`, `scripts/platform-gate.sh` or the aarch64 runs; and
`docs/architecture/002` described the arch-syscall trap as a single v0.9.1
event rather than the three-time recurrence it is.

⚠ **Two `src/` comments pointed at a roadmap section that does not exist**
(`§"Out of scope (for v1.0)"`; the heading has been plain `## Out of scope`
since the milestone closed). Those ship inside `dist/darshana.cyr`, which is
the API reference consumers read, so a dangling cross-reference there is a
shipped defect rather than a private note.

**1.1.1** — *open cycle*. **aarch64 goes into CI — and wiring it found that
four assertions, including v1.0.2's signalfd security regression test, had
never actually run there.** Patch-shaped: **no `src/` file changed** and
`dist/darshana.cyr`'s module bodies are byte-identical to the v1.1.0 tag, so
the frozen surface provably cannot have moved. The only shipped delta is one
line in `dist/darshana.deps`.

⭐ **The CI blocker v1.1.0 recorded did not exist.** That release said a step
would first need `cycc_aarch64` built or fetched, "because the standard
installer does not place it". Wrong: the published
`cyrius-<v>-x86_64-linux.tar.gz` ships `bin/cycc_aarch64` — the local 6.6.0
install simply predated it. CI's existing install step provides the
cross-compiler; the job only adds `qemu-user-static`. qemu-user passes
syscalls to the host kernel, so even the PTY harness gets full coverage.

⛔ **The find**: `tests/darshana.tcyr` guarded its `RLIMIT_NOFILE` squeeze with
the bare x86_64 `prlimit64` number 302 — 261 on aarch64 — so the guard failed,
the block skipped, and the suite reported 234/238 on ARM in a way that read as
deliberate degradation. It was a wrong syscall number, and the four assertions
it hid include the regression test for the v1.0.2 signalfd defect that could
strand a user's terminal. Now gated per-arch: **aarch64 runs 238/238, full
parity.** Three more arch-blind numbers in the same file (`openat` 257,
`close` 3, exit `60`) now use the stdlib's arch-aware wrappers.

That class — a syscall number as a bare integer — has now bitten three times
(v0.9.2 `SYS_IOCTL`, v1.0.2 `raw_loop.cyr`, v1.1.0 both test suites), always
invisibly, because the toolchain's "syscall not routed" diagnostic is
Mach-O-only. It is now **mechanically gated**: `audit_no_literals` in
`scripts/syscall-audit.sh` requires every syscall number to be a NAMED
constant — the stdlib's, or one declared inside an explicit
`#ifdef CYRIUS_ARCH_*` gate — across `src/`, `tests/`, `programs/` and
`docs/examples/`. `syscall(1, ...)` is the sole exception. Its `--self-test`
proves it rejects a literal `ioctl(16)` and `exit(60)` *and* still accepts
`write(1)`, so it can become neither useless nor over-strict.

⚠ **Corrected at v1.1.4: that paragraph was false.** The rule globbed `*.cyr`,
so it never scanned `tests/` (every suite is `*.tcyr`), and it checked only
call-site literals, so a named constant in an arch-blind gate passed. Its
self-test's literal probes were in fact rejected by the allowlist rule, so
neutering the literal rule left it green. All three are fixed in 1.1.4.

⭐ **The last `undefined function` warning in the tree is gone.**
`_agnos_getenv` had been carried since before v1.0.0 as "upstream-shaped;
nobody has checked". Checked: `lib/io.cyr` delegates to it, `lib/args_agnos.cyr`
defines it, and it was simply not in the declared footprint — the exact shape
v1.0.1's `vec` fix closed. Declaring the `args` leaf pulls it in.

**1.1.0** — *open cycle*. **The two refactors v1.0.2 deferred — which turned
out to contradict each other — plus the first verification of darshana on real
aarch64 hardware.** Minor, not patch: ADR 0003 prices "internal refactors with
identical output" that way, and identical output is what this is.

v1.0.2 recorded two byte-identical improvements for the next minor: collapse
the duplicate decimal emitter `_ansi_emit_u8` into `tty_dec_buf`, and a ~30%
RGB-composer speedup whose main ingredient is *inlining* those same digit
emissions. One says share a function; the other says stop calling one. **Doing
the first as written is byte-identical and 32-45% SLOWER** (`tty_dec_buf` is a
general i64 formatter that reverses digits through a 24-byte scratch array;
these composers only ever emit 1-3 digits). The two findings came from
different audit lenses and neither measured the other's direction.

Resolved by **elimination rather than delegation**: the 1-3 digit sequence is
inline at each of the five call sites and `_ansi_emit_u8` is deleted. That is
what the dedup finding actually wanted — no second decimal-emitter *function* —
while getting faster instead of slower. 20M calls, median of 7:
`tty_fg_rgb_buf` 990 → **696 ms** (-30%), `tty_fg_256_buf` 458 → **303 ms**
(-34%), `tty_sgr_buf` 353 → **289 ms** (-18%). The 7-byte fixed prefixes became
single wide stores; `tty_sgr_reset_buf`'s four became one `store32`.

⭐ **darshana ran on real aarch64 for the first time**, closing v1.0.2's
carry-forward. The installed toolchain ships no `cycc_aarch64`, but the cyrius
repo builds one and a sandboxed `CYRIUS_HOME` (never the live tree) produces
working aarch64 ELFs. Verified under `qemu-aarch64` and then on a **Raspberry
Pi 4 (Linux 6.8)**: smoke ok, 234/234 unit + 56/56 pty, and the exhaustive
equivalence checksum identical to x86_64 before and after the refactor. **That
is what licensed the unaligned wide stores** — measured on real ARM, not an
argument about `SCTLR.A`.

Running on aarch64 immediately found TWO real defects, both the v0.9.2
`SYS_IOCTL` class living in the suites meant to catch it.
`tests/darshana.tcyr` read the signal mask with a hardcoded `syscall(14, ...)`
(`rt_sigprocmask` on x86_64, **135** on aarch64). Worse, **`tests/pty.tcyr` was
silently x86_64-only and failed 15 of 53 assertions there**: its ABI block
hardcoded the ioctl / nanosleep / dup / dup2 / prlimit64 / rt_sigprocmask
numbers inside an arch-BLIND `CYRIUS_TARGET_LINUX` gate, so on aarch64 every
`TCGETS` / `TIOCGWINSZ` probe called syscall 16 — `fremovexattr` — and the
failures were blamed on darshana rather than on the test. Both now take
arch-aware constants and wrappers from the stdlib, with explicit
`CYRIUS_ARCH_X86` / `CYRIUS_ARCH_AARCH64` gates for the two the stdlib does not
define and a local helper for `dup2` (aarch64 has only `dup3`). **56/56 on both
architectures.**

Tests **295 → 309**. Two audit conclusions are recorded at the source so they
are not re-litigated: reciprocal multiplication for the divides is **slower**
(measured), and the cost was the CALL, not the arithmetic (cycc spills five
callee-saved registers even in a leaf).

**1.0.2** — *open cycle*. **P-1 audit / refactor / hardening / optimization /
security sweep** — the first since v0.9.3 and the first under the freeze.
Seven lenses over the whole surface, every finding through a three-way
adversarial refutation pass: **32 raised, 28 survived, 14 work items.**
Everything shipped is patch-shaped under ADR 0003 (a fix matching existing
documentation, a test, or a gate); **no frozen byte moved**, proven
exhaustively rather than asserted.

Headline fix: **`tty_open_signalfd`'s failure rollback unblocked signals it
did not block.** It issued `SIG_UNBLOCK` over the whole requested mask instead
of restoring the entry mask (the `SIG_BLOCK` passed `oldset = 0`, so the prior
mask was never captured). A failed second open therefore unblocked a signal an
earlier, still-live signalfd owned — the documented multi-signalfd pattern —
and that fd went deaf. With `TTY_SIGMASK_EXIT` the consequence is the
unrecoverable-terminal outcome in full: the next Ctrl-C kills the process
instead of waking the poll loop, so `tty_cooked()` / `tty_alt_leave()` never
run. Reproduced under `RLIMIT_NOFILE=3`. Fixed by capturing `oldset` and
unblocking only `sigmask & ~prev` — using only the `how` values both kernels
implement by name. Not the v0.9.3 leak: v0.9.3 *added* this rollback, and the
residual defect was that it unblocked rather than restored.

Also fixed: `tty_close_signalfd` returned a raw `-errno` where its docstring
promised `-1` (v0.9.3 normalized the open path and missed its twin);
`docs/examples/raw_loop.cyr` ended with an ungated literal `syscall(60, ...)`,
which is `winsize` on AGNOS, not `exit`; and four stale docstring blocks
shipped in the bundle, two on public frozen symbols, left stranded when v0.9.4
restored the ones v0.9.3's extraction had destroyed.

**Gate hardening was the bulk of the cut**, because each gate had stopped
catching what it names. `scripts/syscall-audit.sh` was bypassed by three
ordinary constructs (parenthesized first argument, line-wrapped call, any
stdlib wrapper outside the `sys_*`/`file_*` prefixes) and never scanned
`docs/examples/` — which is where the `syscall(60)` was hiding. The
platform-gate check was extracted to **`scripts/platform-gate.sh`** and made
corpus-driven: v0.9.3 fixed its substring-vs-positional half but left it
hard-coded to `src/termios.cyr`, so the same ungated ioctl code in any other
module was invisible. The docstring audit's `!seen[name]++` de-dup exempted
the entire AGNOS peer arm, and removing it immediately found three real gaps.
`dist/darshana.deps` had no drift gate at all. Both gates now carry
`--self-test` and run it in CI.

**The AGNOS arm had zero coverage of any kind** — six public fns, two frozen
constants and four mirshi syscall numbers checked by nothing, with no CI job
even compiling the arm. Both frozen AGNOS sigmask constants could be corrupted
to their Linux values with every gate green. `tests/agnos.tcyr` (15
assertions) closes it, and runs on an ordinary Linux host because `--agnos`
emits an x86_64 ELF.

Tests **217 → 295**. Two confirmed findings were deliberately NOT taken
because they price as minor, not patch: collapsing `_ansi_emit_u8` into
`tty_dec_buf` (proven byte-identical) and a measured ~30% RGB-composer
speedup. Both are named in the CHANGELOG rather than silently carried.

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

- **Cyrius pin**: `6.6.20` (in `cyrius.cyml [package].cyrius`; the package
  version itself comes from `${file:VERSION}`). Bumped from `6.6.2` at v1.1.3
  with no source edit; what reached darshana is `distlib`'s verify-derived
  sidecar and requires block (6.6.18) and the stdlib closing its own include
  gaps. The pin is what CI greps to pick an installer version.
  History: `6.6.0` → `6.6.2` at v1.1.2; `6.5.35` → `6.6.0` at v1.0.1 (forced:
  6.5.35 emitted an enum-Critical advisory on every invocation; darshana
  declares no `enum`, so it was not exposed); `6.2.36` → `6.5.35` at v0.9.1;
  `6.2.22` → `6.2.36` at v0.8.1; `6.1.24` → `6.2.22` at v0.7.1; `6.0.1` →
  `6.1.24` at v0.5.4; `5.10.20` → `6.0.1` at v0.3.5.
- **`cyrius.lock`** (new at v1.1.3) pins a sha256 for every vendored `lib/`
  file plus the stdlib pin, and is committed. `cyrius deps --verify` checks it.
  It is **not** pruned when a leaf is removed — re-run `--verify` after any
  `[deps].stdlib` change and regenerate the lock if it names a file that is gone.
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
  and `dist/darshana.cyr` byte-identical to the repo's. At v1.1.3 the same
  procedure yields **23 modules, 728 KB**, each byte-identical to
  `~/.cyrius/versions/6.6.20/lib`.

## Source

| File | Lines | Surface |
|------|-------|---------|
| `src/termios.cyr` | 913 | `TIO_*` flags, `tio_load32/store32`, `tty_raw`, `tty_cooked`, **v0.3.0:** `TIOCGWINSZ`, `TTY_SIGMASK_EXIT/WINCH`, `tty_winsize`, `tty_open_signalfd`. **v0.5.3:** `tty_isatty`. **v0.7.0:** `tty_cooked` is zero-arg (single-raw-fd model, `_tty_raw_fd`); `tty_apply_raw_flags` privatized → `_tty_apply_raw_flags`; `tty_close_signalfd` added; `SFD_CLOEXEC` on the signalfd. **v0.8.0–v0.9.0:** `#ifdef CYRIUS_TARGET_AGNOS` peers for all six syscall-touching entry points (`tty_winsize`, `tty_isatty`, `tty_raw`, `tty_cooked`, `tty_open_signalfd`, `tty_close_signalfd`) + agnos-specific `TTY_SIGMASK_*` values. Linux arm gated via `#ifdef CYRIUS_TARGET_LINUX`. **v0.9.2:** local `var SYS_IOCTL = 16` dropped — the Linux gate is arch-blind, so it shadowed the stdlib's arch-aware value and issued the x86_64 number on aarch64; `TCGETS`/`TCSETS`/`TIOCGWINSZ` stay local (arch-stable). **v1.1.4:** private `_tty_fd_ok` — the four Linux fd-taking peers reject an fd outside [0, 0x7FFFFFFF]; the AGNOS `tty_close_signalfd` skips a negative fd. Signalfd, winsize and AGNOS docstrings corrected. **v1.2.1:** the AGNOS arm calls the agnos stdlib's `sys_winsize` / `sys_sigprocmask` / `sys_signalfd`; `_AGNOS_SYS_*` deleted. |
| `src/ansi.cyr` | 485 | `tty_alt_enter/leave`, `tty_clear`, `tty_cursor_hide/show/home`, **v0.3.0:** `tty_clear_to_eol`, `tty_clear_to_eos` (renamed from `tty_clear_to_end` v0.7.0), **v0.3.5:** `tty_sgr`, `tty_sgr_reset`, 16 `TTY_FG_*` constants. **v0.4.0:** `tty_sgr` validates input range `[0, 999]`. **v0.5.1:** `tty_fg_rgb`, `tty_bg_rgb`, `tty_fg_rgb_buf`, `tty_bg_rgb_buf`, `tty_sgr_reset_buf`. **v0.5.3:** `tty_sgr_buf`, `tty_fg_256_buf`. **v1.2.1:** every emitter writes through `sys_write`. Any vt100-compatible terminal. |
| `src/cursor.cyr` | 159 | `tty_dec_buf` (decimal formatter — renamed from `tty_itoa`, returns new write position, v0.7.0), `tty_move` (with [1,65535] coord bounds + `buf[44]` v0.7.0), `tty_cursor_up/down`. Composes the CSI row;colH escape inline. |
| `src/sanitize.cyr` | 141 | **v1.2.0:** `tty_sanitize_buf`, `TTY_SANITIZE_UTF8` / `_LATIN1`, `TTY_KEEP_TAB` / `_LF`; the private strict-RFC-3629 sequence check `_san_utf8_len`. Pure — no syscall, no platform gate. Design: ADR 0004. |
| `src/main.cyr` | 28 | Convenience entry — `include`s the four sub-modules; carries the authoritative surface pointer (→ `scripts/smoke.sh`). The naming/return conventions it carried from v0.7.0 moved to the head of `src/termios.cyr` at v0.9.4, so they ship as the bundle's front matter. Not in the dist bundle. |
| `programs/smoke.cyr` | 17 | Compile-link smoke. |
| `dist/darshana.cyr` | 1,698 | Bundled distribution — regenerate via `cyrius distlib`. What consumers `include "lib/darshana.cyr"`. (1,718 lines on disk; `distlib` reports module-body lines. The other 20 are its 4-line header, the 4-line `# Requires` block that `include`s the sidecar's leaves so the bundle compiles on its own (since v1.1.3), and a separator around each module.) |
| `dist/darshana.deps` | 4 | Generated stdlib-leaf sidecar — **2 entries** (`syscalls`, `io`) since v1.1.3, down from 6. Derived by `distlib`'s compile-verify across six targets (cyrius 6.6.18+), not copied from `[deps].stdlib`, so darshana's test-only `assert` no longer reaches consumers. Consumed by a consumer's `cyrius deps`. |

Total source ≈ 1,698 lines across the four dist modules (1,717 at v1.2.0 with
the new symbols and `sanitize.cyr`; 1,368 at v1.1.4, 1,254 before it) (grew from ~780
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
| `tests/darshana.tcyr` | **312 assertions** (some live-fd-gated; the total is pinned in `scripts/ci.sh`, so a guard that stops holding fails by name): pure-function coverage of `tio_load32/store32`, `_tty_apply_raw_flags` (every flag bit + idempotence), `tty_dec_buf` (zero / negative / 1–3 digits / new-position offset), `tty_move` rejection bounds (v0.7.0), `TIO_BUF_SIZE` drift guard (v0.7.0), the v0.3.0 constant set (`TTY_SIGMASK_*`, `TIOCGWINSZ` ABI), `tty_sgr` rejection, **v0.5.x** truecolor + 256 `_buf` exact-byte + bounds coverage, and **live-fd** tests for `tty_winsize` and `tty_open_signalfd` + `tty_close_signalfd` (v0.7.0). |
| `tests/pty.tcyr` | **100 assertions (v0.6.0; hardened v0.7.0, v0.9.3 and v1.1.4; v1.2.0 added `tty_winsize_or` on a real 0×0 pty and `tty_raw_nonblock`'s modes and restore)** — v1.1.4 added the raw-mode iflag bits, out-of-range-fd aliasing, a failed `tty_raw` leaving no state, the re-raw after `tty_cooked()`, and the documented hangup path. The rest: the in-repo PTY harness. Opens a real pseudo-terminal (`/dev/ptmx` → `TIOCSPTLCK` → `TIOCGPTN` → `/dev/pts/N`) and drives darshana against the slave: `tty_isatty` on a known-live fd (+ deterministic `/dev/null` negative), `tty_winsize` set/get (24×80), the `tty_raw`→`tty_cooked()` state-restore (byte-for-byte), the single-raw-fd model (2nd fd refused), the cooked-vs-raw output round-trip (OPOST/ONLCR, fail-not-skip), and fd-1 escape-byte capture (via `dup2`) for `tty_alt_*`, `tty_clear`, `tty_clear_to_eol/eos`, `tty_cursor_*`, `tty_move`, `tty_sgr`, `tty_sgr_reset`, `tty_fg_rgb`/`tty_bg_rgb`. Wired into CI (v0.7.0) with `SKIP pty:` degradation tokens. Hang-proof (`O_NONBLOCK` master, bounded drains) and skip-clean (Linux-only). |

| `tests/identity.tcyr` | **18 assertions (v1.1.4; v1.2.0 added the `tty_bg_256_buf` and `tty_sanitize_buf` groups — the sanitizer over every 1- and 2-byte input and the 3-/4-byte lead space in both modes, against an independent validator)** — every `_buf` composer over its whole input domain (the full 256³ RGB cube for both RGB composers, every code / index / digit-length boundary, every rejection edge, start positions 0–7) into a 0xAA-poisoned guard region: nothing outside `[pos, ret)` may change, every call stays within its documented byte budget, a rejection writes nothing. Plus eleven 64-bit digests over everything darshana emits, fd-1 emitters captured through a pipe. The digests are identical when the same harness is compiled against the v1.0.0, v1.0.2, v1.1.0 and v1.1.3 tags' `src/`. ~7 s native, ~80 s under qemu. Replaces the two out-of-repo harnesses under Release Process, whose formats were lost. |
| `tests/agnos.tcyr` | **20 assertions (v1.0.2; v1.2.0 added the pure winsize decode)** — the AGNOS arm's first coverage of any kind. Cross-built with `cyrius build --agnos` and RUN on the Linux host (that works: `--agnos` emits an x86_64 ELF and `write(2)` is 1 on both targets). Pins both ADR-0003-frozen AGNOS sigmask values, the agnos stdlib's three syscall numbers the arm relies on (v1.2.1; through 1.2.0 darshana's own copies) plus its `SFD_CLOEXEC` value, and the no-termios contract. ⛔ Deliberately does NOT call `tty_isatty` / `tty_winsize` / the signalfd pair: those issue agnos syscalls, and agnos `winsize` (#60) is `exit` on Linux, so running them would terminate the harness with status 0 and fake a pass — they get compile coverage from the `--agnos` build of `programs/smoke.cyr` instead. Its own process exit uses the HOST's number for the same reason. |

**450 assertions total** (312 + 100 + 18 + 20), green at cyrius 6.6.20 on
x86_64, and under `CYRIUS_DCE=1` — and **430 on aarch64** (312 + 100 + 18; the
AGNOS suite is x86_64-hosted by construction), under `qemu-aarch64` and on real
hardware (a Raspberry Pi 4, Linux 7.0) at v1.2.1. Full unit parity since v1.1.1, when the four
`prlimit64`-gated unit assertions stopped skipping there; the PTY
harness runs its full set with no `SKIP pty:` token. Grew from 217 at v1.0.2's
sweep — the additions target proven gaps, not coverage for its own sake: all
37 frozen constant VALUES (only 4 were pinned before; `smoke.sh` checks names,
never values), `_tty_apply_raw_flags` preserving what it does not name (all 21
prior assertions would pass against an implementation that zeroed every flag
word), `tty_winsize`'s u16 high-byte decode (only 24×80 had ever been tested —
both single-byte, so the shift never ran), accepted boundary inputs (every
prior bounds assertion tested a *rejected* input), the non-TTY failure path,
and a regression test for the signalfd rollback.


## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `io`, `assert` (four leaves as of v1.1.3,
  when `vec` and `args` were dropped). Still tighter than the init default
  (`string / fmt / alloc / io / vec / str / syscalls / assert`) — darshana's
  own sources use none of `str / fmt / string / vec` directly.

**v1.1.3: both include-gap leaves are gone, because the gaps closed upstream.**
`vec` (v1.0.1, below) and `args` (v1.1.1, Carry-Forward) were each declared to
supply a definer some stdlib file called without including it. cyrius 6.6.20's
`fmt.cyr` includes `vec.cyr` and its `io.cyr` includes `args_agnos.cyr`, so the
transitive BFS pulls both regardless, and declaring the leaves only
auto-prepended an unused `lib/args.cyr`. Removing them changed no assertion
count on any suite or target and introduced no warning; the smoke binary shrank
99,312 → 95,184 B. The history below is kept because the *method* — read the
include graph rather than blame the nearest file — is what found both.

~~Known benign build warning: `undefined function 'vec_get'`~~ — **closed at
v1.0.1.** `lib/assert.cyr:4` pulls `lib/fmt.cyr`, the only caller of `vec_get`
outside `vec.cyr` itself, and `vec` was not in the declared footprint, so the
call site linked against nothing. **The attribution above was wrong from v0.9.0
until now**: this file blamed `io.cyr`, which then included only `syscalls`,
`result` and `args_macos` (at cyrius 6.6.20 it also includes `fmt`, `string`
and `args_agnos` — see v1.1.3 above). Corrected against the include graph. 6.6.0's
`cyrius distlib` compile-verifies the sidecar it emits and flagged the missing
leaf (*"re-added 1 leaf(s) the inference missed"*); declaring `vec` makes the
manifest agree with `dist/darshana.deps`. **Every native build is now
warning-clean** — smoke binary, both suites, the example, and `distlib`.
`dist/darshana.cyr` is byte-identical with and without the declaration; the
cost is 160 bytes in the DCE'd smoke binary (15,808 → 15,968). The earlier
diagnosis was right that the call was unreachable and upstream-shaped, and
wrong that nothing could be done about it locally.

`cyrius deps` resolves those four leaves — via its Phase 3 transitive BFS — to
the **23** modules vendored in `lib/` at cyrius 6.6.20: `alloc` `alloc_agnos`
`alloc_cx` `alloc_macos` `alloc_windows` `args_agnos` `args_macos` `assert`
`atomic` `fmt` `fnptr` `io` `poison` `result` `string` `syscalls`
`syscalls_aarch64_linux` `syscalls_linux_common` `syscalls_macos`
`syscalls_windows` `syscalls_x86_64_agnos` `syscalls_x86_64_linux` `vec`.

What a **consumer** resolves is narrower: `dist/darshana.deps` names only
`syscalls` and `io`, the leaves `distlib`'s compile-verify proves the bundle
needs. darshana's `[deps].stdlib` is its own build footprint — tests and smoke
included — and since cyrius 6.6.18 it never reaches the published sidecar.

### Upstream gaps

Found while working on darshana; each belongs to its owner, not to darshana's
roadmap.

| Owner | Gap | Filed |
|-------|-----|-------|
| mirshi | Five signal-band defects, two confirmed by run: a signalfd never delivers a blocked signal (so darshana's AGNOS signalfd receives nothing under mirshi), host signals bypass the agnos signal model, the `read#5` record differs from the kernel's, a closed signalfd's slot is never freed, `sigprocmask` edge cases diverge | mirshi `docs/development/roadmap.md`, 2026-10-12 |
| agnos kernel | Never raises SIGWINCH, though a live modeset changes the console grid, so a `TTY_SIGMASK_WINCH` signalfd never fires; consumers poll `tty_winsize` | agnos `docs/development/issues/2026-10-12-console-grid-changes-without-sigwinch.md` |
| cyrius stdlib | agnos `sys_close(-1)` frees socket slot 7 (bit 0x40000000 reads as a socket tag); darshana guards since 1.1.4 | not yet |
| cyrius stdlib | `lib/syscalls_linux_common.cyr` still says ESYSXLAT has no 16 → 29 row — darshana's own claim, corrected here at 1.1.4 | not yet |
| cyrius CLI | `cyrius deps` does not prune `cyrius.lock` when a leaf is removed | not yet |
| cyrius CLI | `cyrius lib sync --dry-run` prints pointers instead of file names | cyrius `docs/development/issues/2026-10-08-cli-path-and-reporting-leftovers.md` |

## Consumers

Re-derived 2026-10-12 from each consumer's `cyrius.cyml` **and** the
`# Version:` header of the bundle it actually compiles — the two disagree for
the path-resolved consumers, so reading only the manifest misreports them.
**Nine consumers.** This table listed five until a survey of every Cyrius
project under `~/Repos` found four more: thoth, jalwa, darshini, agora. Eight
are on a 1.x dep; **agora is still on 0.9.0**, before the freeze. None is yet on
1.1.3.

| Consumer | Status |
|----------|--------|
| [chakshu](https://github.com/MacCracken/chakshu) | **Live on v1.1.1** (chakshu 0.10.3, cyrius 6.6.2). Drove M2 (Full TUI) and the agnos peers — its `--agnos` build failed to link on `TTY_SIGMASK_EXIT` before v0.9.0. Exercises `tty_raw/cooked`, `tty_alt_*`, `tty_clear_to_eol/eos`, `tty_cursor_*`, `tty_move`, `tty_winsize`, `tty_open_signalfd`, `TTY_SIGMASK_EXIT/WINCH`. On a release carrying v1.0.2's signalfd rollback fix, which matters because it holds an EXIT and a WINCH signalfd at once. |
| [anuenue](https://github.com/MacCracken/anuenue) | **Live on v1.1.2 vendored, `tag = "1.1.1"`** (anuenue 1.3.6, cyrius 6.6.2). Resolves via `path = "../darshana"` beside its `git`/`tag`, so the vendored bundle tracks this working tree, not the tag. Pipe-decorator consumer; uses `tty_fg_rgb_buf` + `tty_sgr_reset_buf` to compose per-character escapes into a line buffer for one-write-per-line throughput. Drove the v0.5.1 truecolor addition. Still ships its phase-cached escape table. |
| [cyim](https://github.com/MacCracken/cyim) | **Live on v1.0.0** (cyim 1.10.1, cyrius 6.6.2). 1.7.0 was the original adopter on darshana 0.2.0. `cyim/src/tty.cyr` reduced from ~207 lines to 38 (only the cyim-specific `tty_probe` stays local). |
| [kii](https://github.com/MacCracken/kii) | **Live on v1.1.2 vendored, `tag = "1.0.0"`** (kii 1.5.2, cyrius 6.6.2) — image → ANSI/ASCII converter; consumes `tty_winsize` to size art to the real console. Same `path = "../darshana"` shape as anuenue, and the same tag-vs-vendored drift recorded here since v0.9.x. |
| [bannermanor](https://github.com/MacCracken/bannermanor) | **Live on v1.0.0** (bannermanor 1.1.5, cyrius 6.6.2). First non-TUI consumer; uses `tty_sgr` + `TTY_FG_*` constants only. Drove the v0.3.5 SGR addition. |
| [thoth](https://github.com/MacCracken/thoth) | **Live on v1.1.2, vendored by copy** (thoth 0.52.8, cyrius 6.6.6). No `[deps.darshana]`: `scripts/sync-darshana.sh` copies `dist/darshana.cyr` to `src/vendor/darshana.cyr` by tag. The widest user — raw/cooked, alt screen, clear, cursor, `tty_move`, `tty_winsize`, `tty_isatty`, the signalfd pair. ⚠ Also calls the **private** `_tty_apply_raw_flags` (`src/intr.cyr:50`) and overrides VMIN/VTIME after it, so a change to that non-frozen internal reaches thoth at its next sync. |
| [jalwa](https://github.com/MacCracken/jalwa) | **Live on v1.1.2** (jalwa 1.4.5, cyrius 6.6.3). Raw/cooked, alt screen, clear, cursor visibility/home, `tty_isatty`. |
| [darshini](https://github.com/MacCracken/darshini) | **Live on v1.0.0** (darshini 1.3.4, cyrius 6.6.2). `tty_sgr` / `tty_sgr_reset` and seven `TTY_FG_*` colors. |
| [agora](https://github.com/MacCracken/agora) | **Live on v0.9.0 — pre-freeze** (agora 1.7.1, cyrius 6.6.2). `tty_sgr_buf`, `tty_sgr_reset_buf`, `tty_open_signalfd` + `TTY_SIGMASK_EXIT`. Its pin predates both signalfd failure-path fixes (v0.9.3, v1.0.2) and the v0.9.3 negative-`pos` rejection in the `_buf` composers. |

Every consumer that resolves through `cyrius deps` declares `syscalls`,
`alloc`, `io`, `vec`, `args` and `assert` in its own `[deps].stdlib`, so the
v1.1.3 sidecar shrinking from six leaves to two removes nothing any of them
relies on. thoth does not read the sidecar at all; it declares `syscalls` and
`io`, which are what the bundle's requires block includes.

## Carry-Forward

- ADR 0001 records the `darshana` name choice (`drishya` and other observation-family alternatives considered). Closed; no re-litigation needed.
- macOS support is deferred — see CLAUDE.md domain rules.
- ~~**`undefined function '_agnos_getenv'` on the `--agnos` cross-build**~~ —
  **closed at v1.1.1**, and it was closable the same way `vec_get` was: it is
  `lib/io.cyr` delegating to `_agnos_getenv`, which `lib/args_agnos.cyr`
  defines and which was simply not in darshana's declared footprint. Declaring
  the `args` leaf pulled it in. **No target emits an `undefined function`
  warning.** `dist/darshana.cyr` is byte-identical with and without the
  declaration, so this changed the build footprint and nothing that ships.
  **Superseded at v1.1.3**: cyrius 6.6.20's `lib/io.cyr` includes
  `lib/args_agnos.cyr` itself, so the `args` leaf was dropped again — the gap is
  closed at its source rather than worked around here.
  ⚠ "native, `--agnos` and `--aarch64` are completely silent" was written here
  at v1.1.1 and did **not** hold on the 6.6.2 pin: 6.6.2's `lib/io.cyr` made
  every `--aarch64` build warn `raw syscall 32 is x86_64 'dup'`. Gone at 6.6.20,
  which is silent on all three. `--win` still emits only the toolchain's generic
  "which syscall numbers route on Windows" advisory — informational, not
  darshana-specific, and for a target the roadmap puts out of scope.
- ~~**`--aarch64` is unverifiable on this host**~~ — **closed at v1.1.0.** The
  installed toolchain still ships no `cycc_aarch64`, but the cyrius repo builds
  one at `build/cycc_aarch64`, and pointing `CYRIUS_HOME` at a **sandboxed copy**
  of the toolchain tree (never the live one — a previous cyrius release lost a
  toolchain to treating `$CYRIUS_HOME` as scratch) produces working aarch64
  ELFs. Those run under `qemu-aarch64` and on the `pi` host (Raspberry Pi 4,
  Linux 6.8). The arm is now *known-good*, not merely *unbuilt*: smoke ok,
  234/234 assertions, exhaustive composer checksum identical to x86_64.
  **Wired into CI at v1.1.1**, and the blocker turned out not to exist: the
  published `cyrius-<v>-x86_64-linux.tar.gz` **does** ship `bin/cycc_aarch64`
  (an x86-hosted cross-compiler), so the install step CI already runs provides
  it — the local 6.6.0 tree simply predated it. CI installs `qemu-user-static`
  and runs the emitted aarch64 ELFs; qemu-user passes syscalls to the host
  kernel, so even the PTY harness gets full coverage there. The sandboxed
  `CYRIUS_HOME` recipe below remains the way to reproduce it by hand on a
  machine whose install is missing the compiler.
- **Inherited at v1.0.1: aarch64 `SYS_SIGNALFD4` moved `74` to `1074`** in the
  vendored `lib/syscalls_aarch64_linux.cyr` (a private alias upstream now
  translates via `ESYSXLAT 1074 -> 74`). darshana's Linux arm calls the stdlib
  wrapper `sys_signalfd`, not a hardcoded number, so it picks this up for free —
  which is the whole reason v0.9.2 dropped darshana's local `SYS_IOCTL`
  constant. ~~Untested here for want of an aarch64 cross-compiler~~ —
  **verified at v1.1.1**: the signalfd open/close/rollback assertions now run
  on aarch64 (under qemu and on the Pi) and pass, so the renumbered alias
  reaches the real `signalfd4`. They had NOT been running before v1.1.1 even
  once aarch64 was buildable — the `prlimit64` guard around them used the
  x86_64 number, so the block silently skipped and looked deliberate.
- ~~The displaced v0.8.0 doc/audit slot~~ — **closed at v0.9.4.** `docs/examples/` holds a runnable, CI-executed example; `docs/architecture/` holds notes 001 and 002; the per-symbol API audit returned zero gaps and is now enforced by `scripts/smoke.sh`.
- ~~`cyrius lint` untracked-deferral notes in `src/ansi.cyr` / `src/termios.cyr`~~ — **closed at v0.9.3**: the bg-256 deferral note pointed at the roadmap until `tty_bg_256_buf` shipped in v1.2.0 and the note went with it, the macOS termios note cross-references CLAUDE.md's domain rule. All four src modules are deferral-note clean; keep them that way.

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — three jobs (build-and-test, security, docs), each step a call to **`scripts/ci.sh <gate>`** (v1.1.4), so `bash scripts/ci.sh all` locally runs literally what CI runs. 15 gates: toolchain, deps (`--verify` first), smoke-binary, lint, unit, pty, identity, examples (no-TTY path AND the real TTY path under `script(1)`), agnos, aarch64 (qemu-user: smoke + unit + pty + identity), project-smoke, distlib-drift, dce (smoke + the unit and PTY suites under `CYRIUS_DCE=1`), security, docs (required files, version consistency, and that `ci.yml` calls every gate). Suite totals are pinned (`EXPECT_*`), `SKIP` is fatal under CI (`DARSHANA_ALLOW_SKIP=1` to downgrade), build warnings are fatal. Read-only token; actions SHA-pinned; the installer fetched at the pinned cyrius tag. |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml via `workflow_call`, version-verify against tag, regenerates dist + ships `darshana-X.Y.Z.cyr` standalone + `darshana-X.Y.Z.tar.gz` package + source tarball + SHA256SUMS, GH release with body extracted from CHANGELOG section |
| Syscall allowlist | `scripts/syscall-audit.sh` (v0.9.4, hardened v1.0.2) — the permitted syscall targets and stdlib wrappers, each with its rationale. One implementation, invoked by both `scripts/smoke.sh` and the CI security job so the two cannot drift. Replaced the exec-sink denylist, which could only catch anticipated sinks. **v1.0.2** closed three bypasses that all compiled, ran and audited green — a parenthesized first argument (`syscall((59), …)` did not match the regex at all), a line-wrapped call, and any stdlib wrapper outside the `sys_*`/`file_*` prefixes (`xopen`, `getenv`, `panic`, …) — by normalizing before matching (comments stripped, string literals blanked, statements rejoined) and making the callee scan a true allowlist. It now also scans **`docs/examples/`**, which is how the ungated `syscall(60)` there was found. `--self-test` asserts each bypass is rejected. **v1.1.4** closed four more: the arch rule now scans `*.tcyr` (it never had) and also rejects a locally-declared syscall constant outside an arch / AGNOS-target gate (the v0.9.2 shape, which passed); strings are blanked before comments are stripped (a `#` inside a string hid the rest of its line); an expression as a syscall number is rejected (`1 + 58` audited as `1`); an allowlisted name may not be re-bound by a parameter or local. Every probe now asserts its own failure message, so a neutered rule cannot hide behind another rule's rejection. **v1.2.1**: `src/`'s allowlist is empty — every syscall goes through an allowlisted stdlib wrapper — and the arch rule has no literal exception, so `syscall(1, ...)` fails in any tree. |
| Platform gate | `scripts/platform-gate.sh` (v1.0.2) — extracted so `smoke.sh` and the CI security job share one implementation instead of two copies of the same awk. **Corpus-driven**: every `src/*.cyr` is checked against its own gates. v0.9.3 fixed this check's substring-vs-positional half but left it hard-coded to `src/termios.cyr` as both gate source and search corpus, so identical ungated Linux ioctl code in any other module was never examined and would ship outside any `#ifdef` with every gate green. Carries a vacuity guard (a gutted tree with no tokens cannot pass) and a `--self-test`. **v1.2.1**: a **peer rule** — a function defined more than once in a file must have exactly one definition in the Linux gate and one in the AGNOS gate — catches a peer escaping either gate with no token list; it replaced `sys_signalfd` / `sys_sigprocmask` as Linux-only tokens once the AGNOS arm called the same-named agnos wrappers. Proven on the real tree by moving the Linux `tty_open_signalfd`, the Linux `tty_close_signalfd` and the AGNOS `tty_winsize` out of their gates; the fatal duplicate-fn build warning catches each a second time. |
| aarch64 verification | **In CI since v1.1.1** — the `x86_64-linux` release tarball ships `bin/cycc_aarch64`, so the existing install step provides it; the job adds `qemu-user-static` and runs the emitted aarch64 ELFs (smoke + both suites). Reproduce by hand on a machine whose install lacks the compiler — copy the toolchain tree to a scratch dir, drop the compiler the cyrius repo builds into it, and point `CYRIUS_HOME` at the copy. **Never at the live tree.** (`<pin>` is `cyrius.cyml`'s `[package].cyrius`.)<br>`cp -a ~/.cyrius/versions $S/cyhome/versions && ln -sfn $S/cyhome/versions/<pin>/bin $S/cyhome/bin` (same for `lib`)<br>`cp ~/Repos/cyrius/build/cycc_aarch64 $S/cyhome/versions/<pin>/bin/`<br>`CYRIUS_HOME=$S/cyhome cyrius build --aarch64 tests/darshana.tcyr build/a64-tests`<br>Run under `qemu-aarch64 build/a64-tests`, and on real hardware via `ssh pi` (Raspberry Pi 4; Linux 7.0 at the v1.1.4 run) — `scp` the binary to `/tmp` and execute. Expect the same pinned totals as x86_64 (`scripts/ci.sh` `EXPECT_*`), and `tests/identity.tcyr`'s digests identical to x86_64's — that is what licenses any store-width or alignment change. On a stock 6.6.20 install none of the sandbox is needed: `cyrius build --aarch64` works directly, and `cyrius test --aarch64` drives qemu itself. |
| Emitted-byte identity | **`tests/identity.tcyr` since v1.1.4**, in the repo and in CI on both architectures — see Tests. ⚠ It replaces the two harnesses described next, which lived outside the repo; their record format and fold were never written down and the scripts are gone, so the values below can no longer be re-derived. The new suite re-proved the claims they backed by compiling against the tagged sources. *Historical:* two harnesses, both kept out of the repo (scratch tooling, regenerate as needed). A **streaming** one dumps every composer's bytes + return over its full envelope for `diff`/`sha256` (13,518 records / 178,199 bytes; `sha256:6dcd7228…` since v1.0.1). An **exhaustive** one folds the return plus all 48 bytes of a `0xAA`-poisoned canvas, composing at `pos = 3`, over the complete `[0,255]³` RGB cube (16.7M triples × 2 composers) plus every rejection edge and start position; it printed `CHECKSUM 2666313271416689717` identically on x86_64, qemu-aarch64 and a real Pi 4, before and after v1.1.0's refactor. Folding the whole canvas rather than the escape is what proves a wide store leaves no stray byte. |
| Examples | `docs/examples/*.cyr` — CI builds **and runs** each one. Every example checks `tty_isatty` first and degrades cleanly, so executing it in CI is meaningful. |
| Smoke test | `scripts/smoke.sh` — runs smoke binary, verifies dist drift, asserts the public contract surface (29 `tty_*` / `tio_*` fn symbols + 37 `TIO_* / TIOC* / TTY_*` constants present in dist) with a **bidirectional self-audit** covering both fns (v0.7.0) and constants (v0.9.3) — it fails if dist exports a public name the checklist omits, in either direction. The platform-gate check is **positional** as of v0.9.3: Linux ioctl tokens must sit inside the `CYRIUS_TARGET_LINUX` gate and agnos syscall tokens inside `CYRIUS_TARGET_AGNOS`, by line number rather than by substring presence. A **docstring audit** (v0.9.4) additionally fails the build if any public fn lacks a docstring or a stated return contract, if any `_buf` composer omits its byte budget, or if a public constant is undocumented. **v1.0.2**: the platform-gate check moved out to `scripts/platform-gate.sh` (shared with CI); the dist-drift check now covers **`dist/darshana.deps`** as well as the bundle, restoring both on failure — previously the sidecar was silently regenerated before anything could compare it; and the docstring audit's `!seen[name]++` de-dup was removed, which had exempted **every duplicated symbol — i.e. the whole AGNOS peer arm** — and whose removal immediately found AGNOS `tty_winsize` shipping with no docstring at all since v0.8.0. **v1.1.4**: the surface audits cover every non-underscore `fn` / `var` (not only `tty_`/`tio_` and uppercase names); every name ADR 0003's tables freeze must still exist in dist (a consistent rename used to pass); and every `src/` stack buffer must meet its documented worst case, listed bidirectionally. |
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
    - v0.9.3 — **P-1 audit / refactor / hardening / security sweep** ✓ shipped. signalfd failure-path fix, `_buf` negative-`pos` rejection, contract-doc repair on the freeze surface, duplication pass, smoke/CI guards. Two breaking-but-correct fixes taken deliberately pre-freeze.
    - v1.0.0 — **the API freeze** ✓ shipped. ADR 0003 enumerates the 29 fns + 37 constants; CLAUDE.md carries the post-freeze rules.
    - v0.9.4 — **pre-freeze documentation + audit cut** ✓ shipped. `docs/examples/raw_loop.cyr`, `docs/architecture/` 001+002, the per-symbol API audit (0 gaps), the syscall allowlist, and the fix for the conventions block that never shipped.
    - **Nothing is open before the freeze.** All five v1.0 criteria are met; v1.0.0 needs the consumer dep bumps, the freeze itself, and the registry promotion.
    - Shipped-cut detail lives in [`CHANGELOG.md`](../../CHANGELOG.md); [`roadmap.md`](roadmap.md) carries only what is still open.
- M5 (v1.0.0) — ✅ **shipped 2026-08-23.** All five v1.0 criteria met; the surface is frozen per ADR 0003. The shared-crates registry promotion landed **with the tag** (see the v1.0.0 entry above and CHANGELOG). The five consumer dep bumps to a `1.x` tag — the last item the milestone left open — had **all landed** by v1.1.3 (see Consumers).

[`roadmap.md`](roadmap.md) is forward-facing only: open items bucketed by semver cost, and the out-of-scope charter boundaries. Upgrade notes for consumers live in [`../guides/upgrading.md`](../guides/upgrading.md), upstream gaps under Dependencies above. The arc above is the surviving milestone summary, and [`CHANGELOG.md`](../../CHANGELOG.md) is the full record.
