# 001 — Termios save-state is a module global, and there is exactly one slot

**What's true about the code**, not what we chose — the decision itself is
[ADR 0002](../adr/0002-state-restore-posture.md).

## The invariant

`src/termios.cyr` holds three module-level variables:

```
var _tty_saved[60];    # the cooked-mode termios tty_raw captured
var _tty_in_raw = 0;   # 1 between a successful tty_raw and tty_cooked
var _tty_raw_fd = 0;   # the fd tty_raw saved state for
```

There is **one** save slot for the whole process. Not one per fd, not one per
caller — one. Every behavior below follows from that single fact, and reading
the functions without it makes several of them look arbitrary.

## What follows from it

**`tty_cooked()` takes no fd.** It restores onto `_tty_raw_fd`. Through v0.6.x
the signature was `tty_cooked(fd)`, which implied a per-fd restore the single
slot cannot deliver: `tty_raw(A)` followed by `tty_cooked(B)` would have written
A's saved termios onto B. The parameter was removed in v0.7.0 rather than
documented around.

**A second `tty_raw` on a different fd is refused with -1.** Not queued, not
silently accepted. Overwriting `_tty_saved` would strand the first fd in raw
mode with no way back — its cooked-mode state would be gone. A second `tty_raw`
on the *same* fd is an idempotent success, because there is nothing to lose.

**A failed restore strands the slot.** `tty_cooked()` leaves `_tty_in_raw` set
when `TCSETS` fails, so the caller can retry. If the failure is permanent —
`EBADF` after the fd is closed, `ENOTTY` after a hangup — the flag stays 1 and
`tty_raw` on any other fd is refused for the life of the process. There is no
public reset. That is deliberate: every consumer's answer to a failed restore is
to exit, and a `tty_forget()` would mostly be a way to lose a terminal quietly.

**Do not retry `tty_cooked()` after the raw fd has been closed and reissued.**
The fd number may now belong to something else, and the retry would write a dead
terminal's 60 saved bytes onto it.

## Why a module global rather than a caller-owned handle

Because the restore has to be reachable from places that were never handed a
handle. A signal-driven exit path, an `atexit`-style teardown, a panic path — none
of them are threading a darshana state struct around. ADR 0002 makes state-restore
the *consumer's* responsibility; a module global is what makes discharging that
responsibility possible from an arbitrary exit path, with no argument to plumb.

The cost is the single-slot limit above. No consumer has ever wanted two
simultaneous raw fds — cyim, chakshu, kii and thoth each hold exactly one
terminal — so the limit has never bound in practice.

## The literal `60`, in three places

`TIO_BUF_SIZE = 60` is the public constant, but `_tty_saved[60]` and the `work[60]`
scratch inside `tty_raw` use the bare literal. Cyrius array sizes must be literals
or enum constants, not `var` constants, so the duplication cannot be factored out.
**If that number ever changes, all three sites move together.** `tests/darshana.tcyr`
carries a drift guard asserting `TIO_BUF_SIZE == 60` for exactly this reason.

The kernel struct is 36 active bytes; 60 covers the historically padded variants
without straddling a stack red-zone.
