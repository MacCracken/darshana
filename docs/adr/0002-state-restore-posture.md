# ADR 0002 — Termios state-restore is a consumer responsibility

**Status**: Accepted (amended 2026-06-10 for v0.7.0 — see Amendments)
**Date**: 2026-05-20
**Deciders**: project owner

## Context

darshana's `tty_raw(fd)` ioctls the terminal into raw mode and stashes
the prior cooked-mode termios in a module-global (`_tty_saved[60]`,
`_tty_in_raw`). A consumer that takes the terminal raw and then exits
without restoring it leaves the user's shell broken: no echo, no line
editing, Ctrl-C delivered as a literal byte. The same hazard applies
to leaving the alt-screen entered (`tty_alt_enter`) or the cursor
hidden (`tty_cursor_hide`).

The v1.0 release criterion explicitly calls this out:

> Security posture documented — termios state-restore guarantees on
> every exit path (including SIGINT/SIGTERM/panic)

The question is **who owns the guarantee** — darshana or the consumer
that's holding the terminal.

Three plausible designs were on the table:

1. **darshana installs the exit/signal handlers itself.** Library
   calls an internal `tty_install_atexit` from `tty_raw`, registers
   `SIGINT`/`SIGTERM`/`SIGHUP` handlers (or an `atexit` callback) that
   call `tty_cooked(0)` + `tty_alt_leave()` + `tty_cursor_show()`. The
   consumer gets restoration "for free."
2. **darshana provides the primitive; consumers wire teardown.**
   Library exposes `tty_open_signalfd(mask)` and the module-globals
   needed for any consumer-installed handler to reach
   `tty_cooked(0)`. The consumer composes its own exit / signal /
   panic paths against those primitives.
3. **darshana ships a `tty_guard(fp)` wrapper.** Library takes a
   function pointer to the consumer's main loop, brackets it with raw
   + alt + hide on entry and cooked + leave + show on return —
   including from a signal-fd-driven exit. RAII-shaped at the library
   surface.

Option (1) collides with CLAUDE.md's domain rule "Don't grow into a
TUI framework" and with the cyim donor's existing wiring (cyim
already installs its own exit path; doubling up is a regression).
Option (3) is interesting but commits darshana to a control-flow
shape (callback) that cyim and chakshu don't currently want — both
own their main loops and want darshana below, not around, that loop.

## Decision

**darshana provides the primitives; consumers own the teardown
guarantee.** State-restore is not a darshana responsibility; it's a
contract darshana enables.

What darshana provides:

- **Module-global saved state.** `_tty_saved[60]`, `_tty_in_raw`, and
  `_tty_raw_fd` in `src/termios.cyr` are reachable from any
  consumer-installed signal handler or panic path — no state-threading
  required to call `tty_cooked()` from outside the raw-mode entry point.
- **Idempotent restore.** `tty_cooked()` (zero-arg as of v0.7.0) is a
  no-op if not in raw, so consumers can call it unconditionally from
  multiple exit paths (atexit, SIGINT handler, panic) without
  double-restore failure. Single-raw-fd model: darshana tracks exactly
  one raw fd (`_tty_raw_fd`); `tty_cooked()` restores onto it, and a
  second `tty_raw` on a *different* fd while still raw is refused (-1).
- **`tty_open_signalfd(sigmask)` + `TTY_SIGMASK_EXIT`.** The
  recommended path for HUP/INT/TERM cleanup. Returns a signalfd the
  consumer's main loop reads; the consumer drains the signal and
  invokes its teardown sequence. No `rt_sigaction` / sa_restorer
  trampoline trap — pure syscall.
- **Documented teardown sequence.** Restore in this order so the
  terminal is in a sane state when the shell prompt returns:
  1. `tty_cursor_show()` — cursor visible
  2. `tty_alt_leave()`   — primary screen restored
  3. `tty_sgr_reset()`   — colors back to default (if `tty_sgr` was used)
  4. `tty_cooked()`      — line discipline restored (zero-arg as of
     v0.7.0; restores the fd `tty_raw` saved)
  5. `tty_close_signalfd(fd, mask)` — if a signalfd was opened: close
     it and unblock the signals (v0.7.0; without it the `SIG_BLOCK`
     installed by `tty_open_signalfd` persists after exit)

What darshana does **not** do:

- No `atexit()` registration on `tty_raw` entry.
- No signal handler installation. (`tty_open_signalfd` blocks the
  signals and routes them to an fd, but it does not bind a callback.)
- No panic hook. Cyrius panics are the consumer's problem; if a
  consumer wants restore-on-panic, it wraps its entry point.
- No bracketing `tty_guard(fp)` wrapper. Adding one was considered
  and rejected (see Alternatives).

## Consequences

**Positive**

- Stays a primitives library. The "Don't grow into a TUI framework"
  domain rule (CLAUDE.md) is preserved without exception.
- Consumers keep full control of their main loop / exit dispatch.
  cyim's existing teardown wiring (Phase 4 migration) needs zero
  shape change to adopt darshana.
- Module-global saved state + idempotent restore are the minimum
  primitives needed to make consumer-side restore *reliable*. A
  consumer that does the simplest possible thing — `atexit { tty_cooked();
  tty_alt_leave(); tty_cursor_show(); }` plus a signalfd loop on
  `TTY_SIGMASK_EXIT` — is fully covered.
- No hidden ordering between darshana's `atexit` and the consumer's
  `atexit`. Hidden ordering is exactly the kind of bug that bites at
  3am.

**Negative**

- A naïve consumer that calls `tty_raw(0)` and exits via `return`
  from `main()` without teardown will leave the terminal broken.
  darshana cannot save them from this; the README + this ADR are the
  only safety net. The donor cyim already does the right thing, and
  the chakshu render loop does too, so the worst case in practice is
  the consumer that grew from a snippet.
- "Did the consumer wire all four restore calls in the right order?"
  is a question darshana can't answer at compile time. A future
  `darshana lint`-style helper could grep consumer source for the
  pattern, but that's out of scope for v0.4.0.

**Neutral**

- A future `tty_guard(fp)` higher-order wrapper could land as a
  sibling helper *without* superseding this ADR — the primitive
  layer (this ADR) is the floor, not the ceiling. If chakshu's
  render loop or a future consumer wants RAII shape, build it on
  top.

## Alternatives considered

**Install handlers from `tty_raw`.** Rejected. Hidden ordering
between darshana's atexit and the consumer's atexit is a footgun;
silently double-installing signal handlers when the consumer already
has its own is worse. CLAUDE.md "no FFI / libc / ncurses" doesn't
forbid this directly, but the "primitives, not framework" rule does.

**`tty_guard(fp)` callback wrapper.** Rejected (for now). cyim and
chakshu both own their main loops; neither wants to invert control
to a darshana-supplied scaffold. Reconsider when a third consumer
materializes with a different shape (e.g., a one-shot CLI like
bannermanor that wants RAII-style coloring — though bannermanor M5
ended up not needing this because color is the only thing it touches).

**Document via `docs/architecture/state-restore.md` instead of an
ADR.** Rejected — this is a *decision* (we chose the primitive shape
over the framework shape), not a constraint of the code. ADRs are
the right home for decisions; architecture docs explain what's true
once a decision has been made.

## Amendments

**2026-06-10 (v0.7.0).** The state-restore primitives were reshaped
during the pre-v1.0 hardening sweep, *without* changing this ADR's core
decision (primitives, not framework; the consumer owns teardown):

- `tty_cooked(fd)` → `tty_cooked()` (zero-arg). The fd parameter
  advertised a per-fd restore the single saved-state slot can't deliver
  (`tty_raw(A)` + `tty_cooked(B)` would have written A's state onto B).
  `tty_raw` now records the owning fd in `_tty_raw_fd`, `tty_cooked()`
  restores onto it, and a second concurrent `tty_raw` on a different fd
  is refused (-1) rather than silently stranding the first fd in raw.
- `tty_close_signalfd(fd, sigmask)` added as the teardown counterpart
  to `tty_open_signalfd`. The open call's `SIG_BLOCK` is otherwise
  irreversible within darshana (closing the fd alone does not unblock);
  the new primitive closes the fd and restores the signal mask, and is
  step 5 of the teardown sequence above.

Both are breaking signature changes, taken pre-freeze precisely because
the frozen v1.0 surface should not advertise a capability the data
model can't deliver, nor freeze an open primitive without its teardown
counterpart. Blast radius was one mechanical edit each in cyim/chakshu
(both already called `tty_cooked(0)`).

## References

- v1.0 release criterion in [`docs/development/roadmap.md`](../development/roadmap.md)
- CLAUDE.md domain rule: "Don't grow into a TUI framework."
- `src/termios.cyr` — `_tty_saved`, `_tty_in_raw`, `_tty_raw_fd`,
  `tty_raw`, `tty_cooked`, `tty_open_signalfd`, `tty_close_signalfd`
- `src/ansi.cyr` — `tty_alt_enter/leave`, `tty_cursor_hide/show`,
  `tty_sgr_reset`
- Donor restore wiring: `cyim/src/main.cyr` (the consumer pattern
  this ADR codifies as the recommended shape)
