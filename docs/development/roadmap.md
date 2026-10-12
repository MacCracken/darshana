# darshana — Roadmap

> **Forward-facing only.** What is left to do, in what order, against what
> gates. Nothing here describes work already shipped.
>
> - What shipped, and when → [`CHANGELOG.md`](../../CHANGELOG.md)
> - Where the code stands today → [`state.md`](state.md)
> - Why a given choice was made → [`../adr/`](../adr/)
>
> When an item closes, its entry is **deleted** from this file, not checked off
> in place. The history belongs in the CHANGELOG.

## Where things stand

**The API has been frozen since v1.0.0** — 29 functions and 37 constants,
enumerated in [ADR 0003](../adr/0003-v1-api-freeze.md) and machine-checked
bidirectionally on every CI run. Breaking one costs a major bump and its own
ADR; additive change stays minor.

The library is done in the sense that mattered: it owns its slice, **nine**
consumers use it, and the surface has stopped moving. Every release since the
freeze has been maintenance — a hardening sweep, a byte-identical performance
pass, platform verification, toolchain bumps. **Nothing about the shipped
surface is outstanding.** The one open item the freeze left — moving the five
known consumers onto a `1.x` dep — closed by v1.1.3. A survey on 2026-10-12
found four more (thoth, jalwa, darshini, agora); [`state.md`](state.md)
§ Consumers has each one's pin.

Current version, counts and verification status live in [`state.md`](state.md);
this file does not restate them.

## Next: 1.1.4 — audit, repairs and security sweep (patch)

The third full sweep (after v0.9.3 and v1.0.2), and the first since v1.1.0
rewrote the composers with unaligned wide stores and two toolchain bumps changed
how the stdlib and the aarch64 backend emit code.

**Scope is patch, strictly** — ADR 0003 § Post-1.0 change policy:

- **In:** bug fixes that do not change a documented contract, including fixes
  that make behaviour *match* its documentation; tests; gates; CI; and
  refactors of code that does **not ship** (`tests/`, `scripts/`, CI, harnesses).
  Documentation rides along as it does with every release — it is never a
  release by itself and never sets the level (ADR 0003, amended 2026-10-12).
- **Out, queued for 1.2.0:** every optimization, and any `src/` refactor that is
  not part of a bug fix. ADR 0003 prices "internal refactors with identical
  output" as **minor**. The sweep still *looks* for optimizations and measures
  them — it records each one in the 1.2.0 queue below instead of landing it.

**Process** — the v1.0.2 shape, which worked: independent lenses over the whole
surface, every finding through an adversarial refutation pass (does it
reproduce; is the semver classification honest; is the severity honest), and
every finding that survives but is not taken named in the CHANGELOG rather than
silently carried.

**Seeded leads.** Each was checked to *exist* while planning; none has been
judged yet, and the sweep is not limited to them.

- *Correctness — signalfd teardown order.* `tty_close_signalfd` closes the fd,
  then unblocks. Any signal still queued and unread when the unblock lands is
  delivered with its default action, which for `TTY_SIGMASK_EXIT` terminates the
  process. So closing a signalfd *before* `tty_cooked()` / `tty_alt_leave()`
  can strand the user's terminal — the outcome v1.0.2's headline fix existed to
  prevent. `docs/examples/raw_loop.cyr` already closes it last, but neither the
  docstring nor ADR 0002 says *why*. Prove the hazard with a test, then document
  the ordering where consumers read it (the docstring ships in the bundle).
- *Correctness — real aarch64 hardware.* The last Pi 4 run was v1.1.1. Since
  then: two toolchain bumps, including 6.6.18's compile-time ESYSXLAT fold,
  which changed how aarch64 syscall numbers are emitted. qemu-user passes;
  the Pi is what settles alignment and ABI questions for the wide stores.
- *Security — CI trusts an unpinned installer.* `ci.yml` and `release.yml` pipe
  `install.sh` from cyrius's **`main`** branch into `sh`, though the toolchain
  version is pinned. The installer carries the Ed25519 key that verifies the
  release tarball, so the trust anchor itself is fetched unpinned. The script
  exists at the pinned tag; fetch it from there.
- *Security — workflow privileges.* `release.yml` grants `contents: write` at
  workflow level, so every job — including the reused CI gate — holds it. Only
  the publishing job needs it. Third-party actions are on mutable major tags
  (`actions/checkout@v4`, `softprops/action-gh-release@v2`, …); decide whether
  to pin by commit SHA.
- *Security — byte budgets, mechanically.* The six `_buf` composers take no
  capacity argument, so each one's documented byte budget is the whole memory
  safety contract. The suite checks the returned length at every budget edge
  and poisons the canvas for one composer's shortest escape. A
  `cyrius fuzz --poison` harness (new in cyrius 6.6.18) giving every composer a
  buffer sized *exactly* to its budget would turn any write past the end into a
  redzone stop (exit 86), across the whole input envelope.
- *Refactor (non-shipping) — land the identity harnesses.* The two emitted-byte
  harnesses that proved v1.0.1 and v1.1.0 byte-identical (the streaming
  `sha256:6dcd7228…` dump and the exhaustive RGB-cube checksum) live outside
  the repo as scratch tooling, "regenerate as needed". Every 1.2.0 optimization
  will need exactly that proof, and a proof that is rebuilt each time can
  quietly drift from the one that was run before.
- *Refactor (non-shipping) — one local runner for every CI gate.* `ci.yml` has
  16 gates; `scripts/smoke.sh` runs a subset, and the aarch64, agnos, lint, DCE
  and example gates have no local one-command equivalent. The 1.1.3 toolchain
  comparison needed a scratch mirror of all 16.
- *Docs (ride along) — what consumers had to discover alone.* Two docstrings
  leave out facts that consumers re-derived by hand, which a 2026-10-12 survey
  of all five consumer trees found:
  - `tty_winsize` succeeds with **0 × 0** on a pty whose size was never set.
    Four consumers (chakshu, cyim, kii, bannermanor) each wrote their own guard
    for that "successful zero", and bannermanor's `stdout_is_tty` treats it as
    not-a-TTY, so it disagrees with `tty_isatty`. The docstring should say so.
  - `tty_open_signalfd` returns a **blocking** fd, and nothing says how to get a
    non-blocking one; anuenue hand-rolled a signalfd for exactly that reason.
    The stdlib's `fd_set_nonblocking(fd)` (cyrius 6.6.8+) on the returned fd
    does it with no new darshana API. One docstring line says so.
  - Two shipped comments are now inaccurate. `src/termios.cyr` says no consumer
    references the `_AGNOS_*` internals, "verified across all five consumer
    trees". There are nine; re-checked 2026-10-12 and none does, so only the
    count is stale. The AGNOS `tty_raw` docstring says raw mode waits until
    "agnos grows a raw-input mechanism". kbscan#42 already delivers raw
    scancodes, and chakshu and cyim decode it themselves. Since AGNOS input was
    ruled out of scope (2026-10-12), the docstring should say that -1 is the
    answer by design — darshana will not build raw input over kbscan, and
    consumers wanting raw keys on AGNOS read it themselves. Only a kernel-side
    raw-mode switch on the AGNOS console would change that, as a termios-shaped
    peer rather than a decoder.

## Queued: 1.2.0 (minor)

Additive only — adding a symbol never breaks the freeze. Items arrive here from
the 1.1.4 sweep (optimizations and standalone `src/` refactors) and from
consumers (new symbols). The bar for anything claiming identical output is
proof, not argument: emitted bytes identical over the full input envelope, on
every architecture the change could affect — which is why 1.1.4 lands the
harnesses first.

**Queued at planning** (before the sweep):

- **Route the five Linux `ioctl` calls through the stdlib's `sys_ioctl`.** The
  wrapper is in the vendored 6.6.20 stdlib (`lib/syscalls_linux_common.cyr`),
  filed by kybernet, and its own comment cites darshana's hand-rolled call. The
  behaviour is identical, so it is a refactor and minor-priced.
  `scripts/syscall-audit.sh`'s allowlist moves with it.

**Queued by 1.1.4** — empty until the sweep runs.

**Candidate symbols** — consumer-driven, under the house rule (CLAUDE.md) that
darshana does not anticipate: a primitive is extracted when a **second**
consumer needs it, as cyim's `tty.cyr` was when chakshu became the second
caller. The list is evidence, not a commitment. It comes from two surveys on
2026-10-12: the nine consumer trees, and every other Cyrius project under
`~/Repos` that does terminal control by hand. Every consumer claim cited here
was checked against that consumer's source. The **elsewhere** counts are the
second survey's, sampled rather than exhaustively re-checked: the games'
`VMIN = 0`, commandress's attributes, kybernet's `TCSETSF`, shakti's echo-off
and mine-cart's kbscan read were confirmed. **Consumers** are the projects that already depend
on darshana. **Elsewhere** counts projects that hand-roll the same primitive
without depending on it; those are potential adopters, not votes under the
rule. Names and shapes are placeholders to settle with the consumers.

*In charter, and the 2nd-consumer trigger has fired:*

1. **A window size that never reports 0 × 0.** Consumers: 4 — chakshu
   (`src/tui.cyr:160-172`), cyim (`src/tty.cyr:44-68`), kii
   (`src/main.cyr:373-393`), bannermanor (`src/layout.cyr:88-104`). Each rejects
   the "successful zero" and falls back to a default. `tty_winsize` cannot
   change — its frozen contract is 0 whenever the ioctl succeeds — so this would
   be a new symbol taking a caller default. The clamps differ (cyim 2×20 to
   1000×1000, bannermanor up to 4096) and would stay in the consumer. **First
   decide whether 1.1.4's docstring fix is enough.**
2. **Named SGR attributes.** Consumers: 3 — chakshu and cyim hand-write
   `ESC [ 7 m` (reverse video) for selection, chakshu also bold and dim, and
   thoth reverse, underline and bold. Elsewhere: 5 — cyrius-yeomans-descent,
   vidya, commandress, ark, kriya. `tty_sgr(code)` already emits every one.
   What is missing is the names (`TTY_SGR_BOLD = 1`, `TTY_SGR_DIM = 2`,
   `TTY_SGR_REVERSE = 7`, …), which `tty_sgr`'s docstring anticipated as "the
   door for future bold / underline". Constants only, and only attributes a
   consumer uses. Two adjacent asks come from elsewhere only, so they do not
   meet the rule yet: 16-color background constants (`TTY_BG_*`, 40–47 /
   100–107; commandress, vidya), and a compound `CSI a;b;c m` composer
   (commandress, cyrius-yeomans-descent).
3. **Reading a signalfd record.** Consumers: 3 — chakshu (`src/tui.cyr:1872`,
   `:1881`), cyim (`src/main.cyr:420`), anuenue (`src/animate.cyr:455-465`).
   Each reads the 128-byte `signalfd_siginfo` by hand. darshana opens and
   closes signalfds but leaves every caller to read them. A
   `tty_read_signal(fd)`-shaped primitive — the signal number, 0 when nothing is
   pending on a non-blocking fd, -1 on error — completes the existing pair; the
   AGNOS peer reads mirshi's emulated record.
4. **`tty_bg_256_buf`** — the 256-color background twin of `tty_fg_256_buf`,
   deferred under the rule since v0.5.3. Consumers: 2 — kii's local
   `_emit_bg_256_buf` (`src/emit.cyr:63-96`), whose comment names the lift
   trigger (*"once a second consumer in the AGNOS surface needs it, lift to
   darshana"*), and now thoth's `_ui_bg_escape` (`src/ui.cyr:217+`), which emits
   `48;5;N`. **The trigger has fired.**
5. **Sanitizing untrusted bytes before they reach the terminal** — brought into
   the charter 2026-10-12 (owner ruling). It is output-side terminal safety,
   the one thing every screen-owning tool needs and each gets subtly different
   alone. The most-duplicated terminal primitive found: consumers 7 (chakshu,
   cyim, kii, bannermanor, thoth, agora, darshini), elsewhere 9 (owl,
   commandress, sit, agnoshi, kybernet, iam, cyrius-yeomans-descent, kriya,
   puka, plus cyrius's own `cbt`). The four consumer rules read in full all
   differ:
   - chakshu: C0 and DEL become `?`; bytes ≥ 0x80 pass.
   - cyim: C0 except TAB becomes `^X`, DEL `^?`; bytes ≥ 0x80 pass.
   - kii (`src/cli.cyr:114-167`): rejects the whole string on C0 (except
     TAB/LF) or DEL, and walks the UTF-8 structure to reject encoded C1
     (`C2 80`–`C2 9F`), stray continuation bytes, overlong leads and truncated
     sequences. Its comment records why a flat 0x80–0x9F test is wrong (`ч` is
     `D1 87`). The strictest rule, and the obvious starting point.
   - bannermanor: C0, DEL and every raw 0x80–0x9F byte become a space —
     deliberately, because its font schema is ASCII-only and a Latin-1
     terminal reads those bytes as controls.

   **To settle with the consumers before writing it:**
   - *UTF-8 versus Latin-1.* Raw 0x80–0x9F are also ordinary UTF-8
     continuation bytes (`€` is `E2 82 AC`), so bannermanor's rule cannot be
     the general one without breaking text. That rule is right for a Latin-1
     terminal and wrong for a UTF-8 one. A UTF-8-aware rule keeps valid
     sequences, neutralizes encoded C1 (U+0080–U+009F) and has to decide what
     a malformed or stray byte becomes. One function, two, or a mode argument.
   - *Replace or reject.* Three consumers replace (`?`, `^X`, space); kii
     rejects the string outright. That suggests a replacing composer plus a
     predicate.
   - *Which C0 bytes the caller may keep.* TAB in a table cell, LF in a
     multi-line log.
   - *Byte budget.* `_buf` composers take no capacity argument, so the budget
     has to be stated as a function of the input length: 1× for a one-byte
     replacement, 2× for caret notation, 3× if U+FFFD stands in for a byte.

   No syscall, so no platform gate: it is platform-independent, like
   `ansi.cyr`. It is a parser over hostile input, so it ships with the
   `cyrius fuzz --poison` harness 1.1.4 builds, asserting at least that no
   neutralized byte survives, that valid UTF-8 in gives valid UTF-8 out, and
   that sanitizing twice changes nothing.

*In charter, one consumer — but that consumer depends on a private symbol:*

6. **Non-blocking raw mode (VMIN = 0, VTIME = 0).** Consumers: 1 — but thoth
   gets it by calling darshana's **private** `_tty_apply_raw_flags`
   (`src/intr.cyr:50`) and overriding the two bytes after it. That makes a
   non-frozen internal load-bearing for a consumer. Elsewhere: 5 — cyrius-doom,
   cyrius-bb, cyrius-polyomino, encom-hits, mirshi. All copy the same pattern
   to keep a game or poll loop from blocking on `read(0)`. Below the rule's
   count, but the private-symbol dependency is a reason to decide it on purpose
   rather than by drift. It is a termios setting, not input decoding, so the
   2026-10-12 ruling that put decoding out of scope does not reach it.

*No consumer yet, or one — wait for a second:*

- **Echo-off / password input** — elsewhere: 2 (shakti; kybernet, which also
  flushes pending input with `TCSETSF`). Termios-shaped, so in charter, but no
  consumer has asked.
- **Input flush (`TCIFLUSH`)** — chakshu only (`src/tui.cyr:495-496`, `:520`).
- **thoth-only screen controls:** cursor save/restore (`ESC 7` / `ESC 8`), the
  DECSTBM scroll region, OSC 0 window title, OSC 52 clipboard, and `_buf` forms
  of cursor-move and clear-to-EOL. thoth also hand-rolls mouse reporting and
  bracketed paste, which **Out of scope** below parks "until a consumer asks". A
  consumer now uses them; under the rule they still wait for a second.

*Hand-rolled, but already ruled out of scope:* key-input decoding (4
consumers, 6 elsewhere) and an AGNOS kbscan reader (2 consumers), both ruled
out 2026-10-12 — see **Out of scope**. `NO_COLOR` / `COLORTERM` /
`TERM` color negotiation (chakshu, anuenue, bannermanor, thoth; owl and kriya
elsewhere) and the RGB→256/16 quantizers (anuenue) fall under color management.
The stdin + signalfd epoll loop (chakshu, cyim) is a render loop. EINTR-safe
write-all loops (kii, anuenue) belong in the stdlib. PTY plumbing and
`TIOCSWINSZ` (shakti, puka) serve terminal *emulators and relays*, not tools
that take over a screen.

**Always eligible:** a new platform peer (additive by ADR 0003 — the AGNOS arm
arrived this way across v0.8.0–v0.9.0), and anything a consumer asks for.

## Downstream — not darshana work

Kept so the reasons are not lost:

- **anuenue** can delete its 1,530-entry / 48,960-byte pre-baked escape table,
  its build pass, and a cache-invalidation bug class. v1.1.0's composers are
  *faster* than that cache — 34.8 ns/call against the 39.3 ns measured for a
  faithful replica in the v1.0.2 audit. Still present at anuenue 1.3.6.
- **kii and anuenue resolve darshana by `path`.** Both declare
  `path = "../darshana"` beside their `git` / `tag`, so the vendored bundle
  tracks this working tree rather than the tag they name (kii: `tag = "1.0.0"`,
  anuenue: `tag = "1.1.1"`; both vendored 1.1.2). Reconcile at their next bump.
- **A bump to 1.1.3 needs no consumer code change.** The frozen surface has not
  moved since v1.0.0. What changes is that `cyrius deps` resolves two stdlib
  leaves from darshana's sidecar instead of six — and every consumer already
  declares the four that dropped.

## 2.0.0 — major

**Not planned, and nothing is pushing toward it.** Listed because ADR 0003
knowingly froze two imperfections in, and a frozen imperfection that nobody
writes down gets rediscovered as a surprise:

- **`tio_load32` / `tio_store32` bounds-check nothing.** Deliberate — they are a
  codec over a caller-owned buffer — but a sharp edge a v2 might blunt.
- **The single-raw-fd model has no public reset.** A permanently failing
  `tty_cooked()` strands the slot for the process lifetime
  ([architecture note 001](../architecture/001-module-global-termios-state.md)).
  Adding `tty_forget()` was considered at v0.9.3 and rejected as speculative. If
  a consumer ever hits this for real, note that the *addition* is a *minor*, not
  a major — only changing the existing model would be breaking.

A major needs its own ADR stating what breaks and why the break beats carrying
the defect, plus a migration note for every consumer.

## Out of scope

Boundaries, not backlog. Each has been considered and declined; the reason is
recorded so it does not get re-litigated. Nothing here is blocked on a version —
these are charter decisions, and the freeze does not change them.

- **macOS / BSD termios support.** The donor was Linux-only and darshana
  follows. The BSD termios struct differs, so this is a real port, not a flag.
  Add when a real consumer needs it — not before (CLAUDE.md domain rules).
- **Windows console API.** Out of project scope for any AGNOS first-party tool.
  (`cyrius build --win` happens to succeed and is not gated on; the toolchain's
  generic syscall-routing advisory on that target is expected and ignored.)
- **Widget toolkit / form controls / render loops / event dispatch.** Belongs in
  the consumer. darshana is the primitive layer below them. Specifically:
  **`tty_frame_begin()` / `tty_frame_end()` will not ship** — they were penciled
  in early under an explicit "otherwise skip — primitives, not framework"
  clause, and that clause won. Do not resurrect them.
- **Signal-*handler* installation.** No `tty_install_winch_handler(fp)` or any
  other `sigaction`-shaped API will ship. Signal delivery is routed through
  `signalfd` instead, which is what `tty_open_signalfd` /
  `tty_close_signalfd` + `TTY_SIGMASK_*` exist for. Rejected outright in
  [ADR 0002](../adr/0002-state-restore-posture.md) §Alternatives.
- **A color-management layer.** The SGR primitives cover 16-color, 256-color,
  and truecolor emission. Anything *above* raw SGR — palette abstraction,
  nearest-color quantization, theme management — is a consumer or sibling-lib
  concern.
- **Mouse / bracketed paste.** Out of scope until a consumer asks. The
  *reports* they produce are input, and fall under the key-input ruling below.
  Only the enable/disable escapes could ever qualify, and they wait for a
  second consumer (thoth is the first).
- **Key-input decoding** — arrows, Home/End/PgUp/PgDn, modifiers, function
  keys, SS3, the lone-Esc timeout. Ruled out 2026-10-12 (owner decision), with
  the evidence in view: 4 consumers (chakshu, cyim, jalwa, thoth) and 6 other
  projects hand-roll it. A bytes-to-key decoder is not dispatch, but it is the
  input layer. Owning it means owning terminal-specific key tables and timing
  heuristics, which is the far side of the line between darshana and a TUI
  framework. darshana stays output, termios and signals; input stays with the
  consumer.
- **AGNOS raw keyboard input** — a darshana reader over kbscan#42 Set-1
  scancodes. Ruled out 2026-10-12 with the key decoder, for the same reason: it
  is input decoding on another platform. chakshu and cyim each keep their own.
  The AGNOS `tty_raw` peer therefore returns -1 by design, not as a stopgap
  waiting on a mechanism; its docstring is corrected in 1.1.4 to say so. The
  ruling covers *decoding*. If the AGNOS console ever grows a kernel raw-mode
  switch, wrapping it is a termios-shaped platform peer and is not ruled out.
