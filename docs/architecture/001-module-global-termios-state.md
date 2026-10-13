# 001 — Termios save-state is a module global, and there is exactly one slot

**What's true about the code**, not what we chose — the decision itself is
[ADR 0002](../adr/0002-state-restore-posture.md).

## The invariant

`src/termios.cyr` holds four module-level variables:

```
var _tty_saved[60];    # the cooked-mode termios the first mode call captured
var _tty_in_raw = 0;   # 1 while the slot is held, until tty_cooked or tty_forget
var _tty_raw_fd = 0;   # the fd the slot belongs to
var _tty_mode = ...;   # which mode it is in: _TTY_RAW, _TTY_RAW_NB, _TTY_NOECHO
```

Three public calls take the slot — `tty_raw`, `tty_raw_nonblock` (1.2.0) and
`tty_echo_off` (1.3.0) — through one body, `_tty_set_mode`. The name
`_tty_in_raw` predates echo-off; it means "the slot is held", whatever the mode.

There is **one** save slot for the whole process. Not one per fd, not one per
caller — one. Every behavior below follows from that single fact, and reading
the functions without it makes several of them look arbitrary.

## What follows from it

**`tty_cooked()` takes no fd.** It restores onto `_tty_raw_fd`. Through v0.6.x
the signature was `tty_cooked(fd)`, which implied a per-fd restore the single
slot cannot deliver: `tty_raw(A)` followed by `tty_cooked(B)` would have written
A's saved termios onto B. The parameter was removed in v0.7.0 rather than
documented around.

**A mode call on a different fd is refused with -1.** Not queued, not silently
accepted. Overwriting `_tty_saved` would strand the first fd with no way back —
its cooked-mode state would be gone. A repeat on the *same* fd in the same mode
is an idempotent success, because there is nothing to lose; a call in another
mode on the same fd switches modes, re-deriving from `_tty_saved`, which is never
overwritten while the slot is held. So `tty_cooked()` restores the state from
before the FIRST mode call, whatever sequence of modes followed.

**A failed restore strands the slot.** `tty_cooked()` leaves `_tty_in_raw` set
when `TCSETS` fails, so the caller can retry. If the failure is permanent —
`EBADF` after the fd is closed, `EIO` after a hangup (measured v1.1.4 on a pty whose master was closed; this note said `ENOTTY` before) — the flag stays 1 and
every mode call on any other fd is refused for the life of the process — until
`tty_forget()` (1.3.0), which clears `_tty_in_raw` and issues no ioctl. It leaves
the terminal exactly as it is, so it belongs only after a `tty_cooked()` that
returned -1. Through 1.2.1 there was no public reset, deliberately: every
consumer's answer to a failed restore was to exit. It shipped with the rest of
the 1.3.0 candidate set ([ADR 0005](../adr/0005-candidates-ahead-of-second-consumer.md)).

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

`TIO_BUF_SIZE = 60` is the public constant, but `_tty_saved[60]` and the
`work[60]` scratch inside `_tty_set_mode` use the bare literal (the copy loop has
read `TIO_BUF_SIZE` since 1.2.0). **If that number ever changes, all three sites
move together.** `tests/darshana.tcyr` carries a drift guard asserting
`TIO_BUF_SIZE == 60`, and since v1.1.4 `scripts/smoke.sh`'s stack-buffer check
requires `work` and `_tty_saved` to hold at least 60 bytes.

cyrius 6.7.2's `const` can size an array, so the literals could become one
private constant. They stay literal because `scripts/smoke.sh`'s budget check
reads array sizes as literals: a `const`-sized buffer would drop out of it.
`TIO_BUF_SIZE` itself stays a `var` — it is frozen, and a consumer may take its
address or redeclare it, which a `const` refuses.

The kernel's `struct termios` is 36 bytes — what TCGETS copies; 60 matches
glibc's padded userspace struct and leaves the tail as slack.
