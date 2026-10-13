# darshana — Roadmap

> **Forward-facing only: open work, and the boundaries.** When an item closes,
> it is **deleted** from this file, not checked off — shipped work lives in the
> [`CHANGELOG`](../../CHANGELOG.md), current state in [`state.md`](state.md),
> reasons in [`../adr/`](../adr/), and what a consumer must do on a bump in
> [`../guides/upgrading.md`](../guides/upgrading.md).
>
> Items are bucketed by the semver bump they would cost under
> [ADR 0003](../adr/0003-v1-api-freeze.md). Documentation is never a release
> by itself; it rides the next one.

## 1.2.x — patch (test gaps)

Two planted defects from the 1.1.4 mutation run still pass every gate.

- **`tty_raw` ignoring a failed TCSETS.** Dropping the
  `sys_ioctl(fd, TCSETS, …) < 0` check in `_tty_raw_mode` passes all 312 + 100 +
  18 assertions (re-checked at 1.2.1): no test has an fd on which TCGETS succeeds
  and TCSETS fails. The fix is a test that manufactures one.
- **The AGNOS `tty_open_signalfd` rollback dropped** — waiting on mirshi. Run
  `tests/agnos.tcyr`'s live half under mirshi in CI. The AGNOS peers that issue
  agnos syscalls cannot run on a Linux host, so they have compile coverage plus
  the pure `_agnos_winsize_unpack` tests; the signalfd peers cannot be
  exercised under mirshi until mirshi delivers a blocked signal through a
  signalfd (filed in mirshi's roadmap).

## 1.x.0 — minor (additive; consumer-driven)

darshana does not anticipate: a primitive is extracted when a **second**
consumer needs it (CLAUDE.md). Evidence is from the 2026-10-12 surveys;
"elsewhere" counts projects that hand-roll the primitive without darshana —
potential adopters, not votes.

*One consumer so far — waiting for a second:*

- **Input flush (`TCIFLUSH`)** — chakshu.
- **Screen controls only thoth uses:** cursor save / restore (`ESC 7` /
  `ESC 8`), the DECSTBM scroll region, OSC 0 window title, OSC 52 clipboard, and
  `_buf` forms of cursor-move and clear-to-EOL. The enable / disable escapes for
  mouse reporting and bracketed paste could qualify; the reports they produce
  are input and cannot (see Out of scope).

*No consumer yet:*

- **16-color background constants** (`TTY_BG_*`, 40–47 / 100–107) and a
  **compound `CSI a;b;c m` composer** — elsewhere: commandress, vidya,
  cyrius-yeomans-descent. `tty_sgr(4x)` works today.
- **Echo-off / password input** — elsewhere: shakti, kybernet (which also
  flushes pending input with `TCSETSF`). Termios-shaped, so in charter.
- **`TTY_SIGMASK_PIPE`** (Linux 0x1000 / AGNOS 0x2000), so a consumer can route
  SIGPIPE through its signalfd. Ignoring SIGPIPE works today.
- **A reject-only sanitizer predicate** (`tty_has_ctl`) — kii's semantics; see
  ADR 0004.
- **`tty_forget()`**, a public reset for the single raw slot. Only if a consumer
  ever hits a permanently failing `tty_cooked()`
  ([architecture note 001](../architecture/001-module-global-termios-state.md)).

*Always eligible:* a new platform peer, and anything a consumer asks for.

## 2.0.0 — major

**Nothing planned.** The two imperfections knowingly frozen in at v1.0 —
`tio_load32` / `tio_store32` bound-check nothing, and the single-raw-fd model
has no public reset — are recorded in ADR 0003 § Consequences. A major needs
its own ADR and a migration note for every consumer.

## Out of scope

Boundaries, not backlog. Each was considered and declined, and the reason is
recorded so it is not re-litigated. These are charter decisions; no version
changes them.

- **macOS / BSD termios.** The BSD termios struct differs, so this is a real
  port, not a flag. Only when a real consumer needs it (CLAUDE.md domain
  rules).
- **The Windows console API.** Out of scope for any AGNOS first-party tool.
  (`cyrius build --win` happens to succeed and is not gated on; the toolchain's
  generic syscall-routing advisory there is expected.)
- **Widgets, form controls, render loops, event dispatch.** They belong in the
  consumer; darshana is the primitive layer below them. That includes the
  stdin + signalfd epoll loop. **`tty_frame_begin()` / `tty_frame_end()` will
  not ship** — they were penciled in early under an explicit "otherwise skip —
  primitives, not framework" clause, and that clause won.
- **Signal-*handler* installation.** No `sigaction`-shaped API, such as
  `tty_install_winch_handler(fp)`. Signals are routed through `signalfd`
  (`tty_open_signalfd` / `tty_read_signal` / `tty_close_signalfd`). Rejected in
  [ADR 0002](../adr/0002-state-restore-posture.md) § Alternatives.
- **Color management.** The SGR primitives emit 16-color, 256-color and
  truecolor. Palettes, nearest-color quantization, themes, and `NO_COLOR` /
  `COLORTERM` / `TERM` negotiation belong to the consumer or a sibling library.
- **Key-input decoding** — arrows, Home / End / PgUp / PgDn, modifiers,
  function keys, SS3, the lone-Esc timeout. Ruled out 2026-10-12 (owner
  decision) with the evidence in view: four consumers (chakshu, cyim, jalwa,
  thoth) and six other projects hand-roll it. A decoder is not dispatch, but it
  is the input layer: owning it means owning terminal-specific key tables and
  timing heuristics, the far side of the line between darshana and a TUI
  framework. darshana is output, termios and signals; input stays with the
  consumer.
- **Mouse and bracketed-paste reports.** Input, under the ruling above. Only
  the enable / disable escapes could qualify (see the 1.x.0 list).
- **AGNOS raw keyboard input** — a darshana reader over kbscan#42 Set-1
  scancodes. Ruled out 2026-10-12 with the key decoder, for the same reason.
  The AGNOS `tty_raw` peer returns -1 by design. The ruling covers *decoding*:
  if the AGNOS console grows a kernel raw-mode switch, wrapping it is a
  termios-shaped platform peer and is not ruled out.
- **EINTR-safe write-all loops.** The stdlib's job, not darshana's.
- **PTY plumbing and `TIOCSWINSZ`.** For terminal emulators and relays, not
  for tools that own a screen.
