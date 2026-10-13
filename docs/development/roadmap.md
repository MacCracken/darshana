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
enumerated in [ADR 0003](../adr/0003-v1-api-freeze.md) — and **v1.2.0 added
five functions and eight constants**, frozen from that release in the same
ADR's "Added since 1.0" table. All of it is machine-checked on every CI run.
Breaking any of it costs a major bump and its own ADR; additive change stays
minor.

Nine consumers use it ([`state.md`](state.md) § Consumers). v1.1.4 was the
third audit sweep; v1.2.0 shipped what that sweep deferred — the measured
composer speedups (35–49%, byte-identical, proven on a real Pi 4), the
refactors, and every candidate whose extract-on-second-consumer trigger had
fired, plus the output sanitizer the owner ruled into the charter
([ADR 0004](../adr/0004-output-sanitization.md)). **Nothing is scheduled
next.** What follows is the queue of shapes a future release could take.

Current version, counts and verification status live in [`state.md`](state.md);
this file does not restate them.

## Next, by bucket

Nothing here is scheduled; each item says what would schedule it.

### 1.2.x — patch

- **Run `tests/agnos.tcyr`'s live half under mirshi in CI.** The AGNOS peers
  that issue agnos syscalls are uncallable on a Linux host, so they have compile
  coverage, plus the pure decode `_agnos_winsize_unpack` (v1.2.0). The signalfd
  peers cannot be meaningfully exercised under mirshi until mirshi delivers a
  blocked signal through a signalfd, the first defect filed in its roadmap —
  so this waits on mirshi.

### 1.x.0 — minor (additive; consumer-driven)

The house rule (CLAUDE.md) is that darshana does not anticipate: a primitive is
extracted when a **second** consumer needs it. Evidence from the 2026-10-12
surveys; **consumers** depend on darshana, **elsewhere** counts projects that
hand-roll the primitive without it (potential adopters, not votes).

*One consumer so far — wait for a second:*

- **Input flush (`TCIFLUSH`)** — chakshu only (`src/tui.cyr:495-496`, `:520`).
- **thoth-only screen controls:** cursor save/restore (`ESC 7` / `ESC 8`), the
  DECSTBM scroll region, OSC 0 window title, OSC 52 clipboard, and `_buf` forms
  of cursor-move and clear-to-EOL. thoth also enables mouse reporting and
  bracketed paste; their *reports* are input and ruled out (see Out of scope),
  so only the enable/disable escapes could ever qualify.

*No consumer yet:*

- **16-color background constants** (`TTY_BG_*`, 40–47 / 100–107) and a
  **compound `CSI a;b;c m` composer** — elsewhere: commandress, vidya,
  cyrius-yeomans-descent. `tty_sgr(4x)` works today.
- **Echo-off / password input** — elsewhere: shakti; kybernet (which also
  flushes pending input with `TCSETSF`). Termios-shaped, so in charter.
- **`TTY_SIGMASK_PIPE`** (Linux 0x1000 / AGNOS 0x2000), so a consumer can route
  SIGPIPE through its signalfd; ignoring SIGPIPE works today.
- **A reject-only sanitizer predicate** (`tty_has_ctl`) — kii's semantics. ADR
  0004 records why the composer shipped without it; an addition if a second
  consumer wants it.

*Measured and set aside in 1.2.0 — revisit only with new evidence:*

- **Flattening `tty_fg_rgb_buf` / `tty_bg_rgb_buf`** into two copies of the
  packed body: ~4–5 ns more per call, for two hand-maintained copies. Worth it
  only if a consumer becomes bound by the composer (anuenue dropping its escape
  cache is the plausible case). `tests/identity.tcyr` is what would catch the
  copies drifting.
- **The AGNOS arm on the stdlib's agnos `sys_sigprocmask` / `sys_signalfd`**:
  blocked by the platform gate, which polices those names as Linux-only tokens.

*Ruled out of scope:* key-input decoding and an AGNOS kbscan reader (see Out of
scope); `NO_COLOR` / `COLORTERM` / `TERM` negotiation and color quantizers
(color management); the stdin + signalfd epoll loop (a render loop); EINTR-safe
write-all loops (the stdlib's); PTY plumbing and `TIOCSWINSZ` (terminal
emulators and relays, not screen-owning tools).

**Always eligible:** a new platform peer (additive by ADR 0003), and anything a
consumer asks for.

## Upstream — not darshana work

Found while working on darshana, recorded for their owners:

- **mirshi** — five signal-band defects, **filed in mirshi's roadmap**
  (2026-10-12), two confirmed by run: a signalfd never delivers a blocked signal
  (so darshana's AGNOS signalfd receives nothing under mirshi), host signals
  bypass the agnos signal model, the `read#5` record differs from the kernel's,
  a closed signalfd's slot is never freed, and `sigprocmask` edge cases diverge.
- **cyrius stdlib**: agnos `sys_close(-1)` frees socket slot 7 (darshana guards
  since 1.1.4); `lib/syscalls_linux_common.cyr` repeats darshana's old "no
  16→29 ESYSXLAT row" claim; cyrius 6.6.20 `cyrius deps` does not prune
  `cyrius.lock` when a leaf is removed, and `lib sync --dry-run` prints pointers
  instead of file names.
- **The agnos kernel** never raises SIGWINCH, so a `TTY_SIGMASK_WINCH` signalfd
  never fires there; consumers poll `tty_winsize`.

## Upgrade notes for consumers

What a consumer bumping its darshana dep should know. Consumer-specific issues
live in each consumer's own roadmap, not here.

- **1.2.0 needs no consumer code change.** It is additive, and every byte darshana
  already emitted is unchanged. What it offers: `tty_sanitize_buf` in place of a
  hand-rolled control-byte scrubber (pick the mode by the terminal you write to);
  `tty_read_signal` in place of reading `signalfd_siginfo`; `tty_winsize_or` in
  place of a 0 × 0 guard; `tty_raw_nonblock` in place of patching VMIN / VTIME;
  `tty_bg_256_buf`; and `TTY_SGR_*` names for bold, dim, underline and reverse.
- **1.1.4 needed none either**, but changed the recommended teardown: ADR 0002's
  amended sequence puts `tty_cooked()` first and `tty_close_signalfd()` last,
  because the old order can leave the terminal raw when fd 1 is a broken pipe.
  Live signalfds need disjoint masks, and a child spawned while one is open
  inherits its signal block. An fd outside [0, 0x7FFFFFFF] is rejected instead
  of aliasing another descriptor.

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
