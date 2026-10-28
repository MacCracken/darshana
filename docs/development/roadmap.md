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

## 1.3.x — patch (waiting on mirshi)

- **The AGNOS `tty_open_signalfd` rollback has no test that can fail.**
  Dropping it passes every gate, because the AGNOS signalfd peers cannot run on
  a Linux host. The fix is to run `tests/agnos.tcyr`'s live half under mirshi in
  CI, which waits on mirshi delivering a blocked signal through a signalfd (filed
  in mirshi's roadmap). Until then the peers have compile coverage only, beside
  the pure `_agnos_winsize_unpack` tests.

## 1.x.0 — minor (additive; consumer-driven)

**Nothing is queued.** 1.3.0 shipped every candidate the 2026-10-12 surveys
found ([ADR 0005](../adr/0005-candidates-ahead-of-second-consumer.md)). From
here the CLAUDE.md rule applies again: a primitive is extracted when a **second**
consumer needs it.

*Always eligible:*
- a new platform peer;
- an AGNOS arm that becomes real when agnos grows the mechanism. **Unblocked:**
  agnos 1.57.13 ships `console_mode#110` (`CM_NOECHO`, `CM_FLUSH`) and
  `fd_kind#111`, and cyrius's stdlib wraps both from 6.7.11 (`sys_console_mode`,
  `sys_fd_kind`). So `tty_echo_off` / `tty_flush_input` can stop answering -1 on
  AGNOS, and `tty_isatty(fd)` can answer about `fd` (`sys_fd_kind(fd) ==
  FDK_CONSOLE`) instead of about the console. A kernel older than 1.57.13 answers
  -1 to both calls, and the arms must keep that answer there. agnos 1.57.13 also
  raises SIGWINCH on a grid change; the WINCH signalfd stays untestable until
  mirshi delivers signals (above);
- anything a consumer asks for.

## 2.0.0 — major

**Nothing planned.** ADR 0003 § Consequences records the imperfections knowingly
frozen in at v1.0. `tio_load32` / `tio_store32` bounds-check nothing, and the
process has a single termios save slot (`tty_forget`, since 1.3.0, frees a
stranded slot but does not lift that limit). A major needs its own ADR and a
migration note for every consumer.

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
- **Mouse and bracketed-paste reports.** Input, under the ruling above. The
  enable / disable escapes shipped in 1.3.0; decoding what the terminal sends
  back is the consumer's.
- **AGNOS raw keyboard input** — a darshana reader over kbscan#42 Set-1
  scancodes. Ruled out 2026-10-12 with the key decoder, for the same reason.
  The AGNOS `tty_raw` peer returns -1 by design. The ruling covers *decoding*:
  if the AGNOS console grows a kernel raw-mode switch, wrapping it is a
  termios-shaped platform peer and is not ruled out.
- **EINTR-safe write-all loops.** The stdlib's job, not darshana's.
- **PTY plumbing and `TIOCSWINSZ`.** For terminal emulators and relays, not
  for tools that own a screen.
