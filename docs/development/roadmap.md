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

**v1.1.4 was the third audit sweep** (after v0.9.3 and v1.0.2): five lenses,
every finding verified before it was acted on. Its record, including what it
confirmed and deliberately did not take, is [CHANGELOG `[1.1.4]`](../../CHANGELOG.md).
What it found and deferred because it prices as minor is queued below. **The
next release is 1.2.0.**

Current version, counts and verification status live in [`state.md`](state.md);
this file does not restate them.

## Queued: 1.2.0 (minor)

The next release. Additive only — adding a symbol never breaks the freeze.
Items arrive here from the 1.1.4 sweep (optimizations and standalone `src/`
refactors) and from consumers (new symbols). The bar for anything claiming
identical output is proof, not argument: **`tests/identity.tcyr`'s eleven
digests unchanged** — on x86_64, under qemu-aarch64, and on the Pi 4 for
anything that changes a store width or alignment. That suite, landed in 1.1.4,
is the proof; a moved digest is a frozen-surface change, not a test update.

**Optimizations, queued by 1.1.4.** Each was prototyped in scratch and matched
1.1.3 with zero mismatches over its full envelope (return value plus every byte
of a poisoned canvas), on x86_64 and qemu-aarch64. Medians of 14–28 samples of
20M calls, pinned to one core, cycc 6.6.20 on Zen3. Nothing here is a consumer
bottleneck today: the largest measured win for a real consumer is ~70 µs/frame
for kii at ~10k cells, and anuenue's per-character path only if it drops its
escape cache.

1. **Write the constant escape prefixes as hex literals** (`ansi.cyr`, the
   three wide stores). cycc 6.6.20 does not fold `27 | (91 << 8) | …`: ~45
   instructions per call build the "one store". `tty_fg_256_buf` −17%,
   `tty_sgr_reset_buf` −19%, `tty_fg_rgb_buf` −6%. No control flow changes.
2. **Rewrite the shared RGB body, keeping the wrappers.** Literal prefix; one
   range check `((r | g | b) >> 8) != 0`; a pointer cursor instead of
   `pos = pos + 1` per byte; exact-width packed stores per field.
   `tty_fg_rgb_buf` 770.5 → 502.9 ms (−35%); net 31.8 → 18.4 ns. **Needs the Pi**:
   store16 is new and store32 lands at data-dependent unaligned offsets.
3. **Optional on top of 2: flatten `tty_fg_rgb_buf` / `tty_bg_rgb_buf`.** −47–49%
   gross, net 13.8 ns. Re-expands v0.9.3's dedupe; the identity suite is what
   catches the two copies drifting.
4. **The same treatment for `tty_fg_256_buf` (−41%) and `tty_sgr_buf` (−31%)** —
   and write the queued `tty_bg_256_buf` in that shape from the start.
5. **A `tty_dec_buf` fast path** — small values −47%, 10-digit −40%. Trap: the
   digit counter overflows at 19 digits; it needs an explicit stop.

*Measured and rejected — do not retry without new evidence:* `#inline` (cycc
ignores it here); `#regalloc` (no codegen change); copying parameters into
locals (none); two divisions instead of four (+3%); rodata digit tables (−27%,
but +2,328 B in every consumer binary, even under DCE); inlining `tty_move`'s
compose, flattening `tty_cursor_up`/`down`, or inlining `tty_sgr`'s hop (−1% to
−6.6% end to end — the write(2) dominates); widening `tty_raw`'s 60-byte copy
(runs once per session); build flags (no change in ranking).

*Correctness traps that look like optimizations:* a packed store that writes
past the escape (only a whole-canvas check sees it); folding `pos` into the
channel mask (rejects pos ≥ 256); dropping a composer's own `pos < 0` guard
(reopens v0.9.3's laundered -1); an 8-byte access at offset 56 of `tty_raw`'s
60-byte buffer; a fixed 5-digit inline in `tty_move` (silently depends on a
guard its docstring contemplates loosening).

**Refactors with identical output, queued:**

- **Route the five Linux `ioctl` calls through the stdlib's `sys_ioctl`.** The
  wrapper is in the vendored 6.6.20 stdlib (`lib/syscalls_linux_common.cyr`),
  filed by kybernet, and its own comment cites darshana's hand-rolled call.
  `scripts/syscall-audit.sh`'s allowlist moves with it.
- **Move the AGNOS arm onto the stdlib's agnos `sys_winsize`,
  `sys_sigprocmask` and `sys_signalfd`**, which use the same numbers.
- **Extract the AGNOS peers' pure decode and mask math into `_agnos_*`
  helpers**, so `tests/agnos.tcyr` can unit-test them. Today they have compile
  coverage only: in the 1.1.4 audit, swapping AGNOS `tty_winsize`'s rows and
  cols, or dropping its signalfd rollback, survived every gate.
- **`tty_raw`'s copy-loop bound to `TIO_BUF_SIZE`**, removing the fourth literal
  `60` site a resize has to remember.

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
- **`TTY_SIGMASK_PIPE`** (Linux 0x1000 / AGNOS 0x2000), so a consumer can route
  SIGPIPE through its signalfd instead of dying on a broken output pipe —
  suggested by the 1.1.4 security lens alongside the teardown reorder. No
  consumer has asked; ignoring SIGPIPE works today.
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

## Later 1.1.x — patch candidates

Confirmed in the 1.1.4 sweep and patch-shaped, but not taken in it:

- **Run `tests/agnos.tcyr`'s live half under mirshi in CI.** The AGNOS peers
  that issue agnos syscalls are uncallable on a Linux host, so they have compile
  coverage only. The 1.1.4 correctness lens ran them under mirshi 1.11.3 locally
  — winsize, isatty, raw/cooked, both signalfds — 15/15. Wiring it needs mirshi
  available in CI.

## Upstream — not darshana work

Found by the 1.1.4 sweep in the toolchain and emulator darshana builds on,
recorded for their owners:

- **cyrius stdlib, agnos `sys_close(-1)`** treats -1 as a tagged socket (bit
  0x40000000 is set in -1) and frees socket slot 7. darshana's AGNOS
  `tty_close_signalfd` guards against it since 1.1.4.
- **mirshi** never frees a closed signalfd's slot (its documented v1.6.0 limit;
  8 per process), so the 9th `tty_open_signalfd` under mirshi fails.
- **The agnos kernel's sigprocmask** stores any `how` other than 0 and 1
  verbatim, while mirshi names SIG_SETMASK — the two disagree on `how = 2`.
- **cyrius `lib/syscalls_linux_common.cyr`** (≈:179) repeats darshana's old
  "no 16→29 ESYSXLAT row" claim; 6.5.38 added that row.
- **cyrius 6.6.20 `cyrius deps`** does not prune `cyrius.lock` when a stdlib
  leaf is removed, and `cyrius lib sync --dry-run` prints pointer values
  instead of file names.

## Upgrade notes for consumers

What a consumer bumping its darshana dep should know. Consumer-specific
issues live in each consumer's own roadmap, not here.

- **1.1.4 needs no consumer code change.** No frozen name, arity, return
  contract, emitted byte or constant moved — `tests/identity.tcyr`'s digests are
  identical to every release since v1.0.0. Two inputs that were already
  outside the documented contract now behave as documented: an fd outside
  [0, 0x7FFFFFFF] is rejected by the four Linux fd-taking functions instead of
  aliasing another descriptor, and the AGNOS `tty_close_signalfd` no longer
  passes a negative fd to close.
- **Reorder your teardown** to ADR 0002's amended sequence: `tty_cooked()`
  first, `tty_close_signalfd()` last. The old order (cooked fourth) can leave the
  terminal raw when fd 1 is a broken pipe.
- **Live signalfds need disjoint masks**, and a child spawned while one is open
  inherits its signal block — both now documented in the docstrings.
- **1.1.3 needed no consumer code change either.** `cyrius deps` resolves two
  stdlib leaves from darshana's sidecar instead of six.

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
