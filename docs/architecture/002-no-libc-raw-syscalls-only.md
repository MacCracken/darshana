# 002 — Everything is a raw syscall, and what that costs

**What's true about the code.** The sovereign-stack rule itself is a
[CLAUDE.md](../../CLAUDE.md) domain rule; this note is about what living under it
actually looks like in `src/`.

## The invariant

darshana links no libc, no ncurses, no terminfo. There is no `tcgetattr(3)`, no
`tputs(3)`, no `isatty(3)`. Every kernel interaction is a bare `syscall(...)`:

- termios is `syscall(SYS_IOCTL, fd, TCGETS|TCSETS, &buf)` against a 60-byte
  buffer whose field offsets are hardcoded from `asm-generic/termbits.h`
- window size is `syscall(SYS_IOCTL, fd, TIOCGWINSZ, &ws)` against an 8-byte
  struct, or agnos syscall #60 on the AGNOS arm
- every escape sequence is `syscall(1, 1, <bytes>, <len>)` — a direct `write(2)`
  to fd 1

CI enforces the negative half: the security job fails on any
`include "lib/{cffi,dynlib,fdlopen,pam}.cyr"`.

## What it costs, concretely

**Struct layouts are hardcoded, so they are load-bearing constants.** The termios
field offsets (c_iflag 0, c_oflag 4, c_cflag 8, c_lflag 12, c_cc at 17) and the
flag bit values are transcribed from kernel headers. Nothing checks them at
compile time. They are correct for x86_64 and aarch64 Linux, which share the
`asm-generic` layout; they are **wrong for macOS/BSD**, which is the concrete
reason macOS support is a port rather than a flag.

**Syscall numbers are architecture-specific, and getting one wrong fails
silently.** This is the single most recurrent defect in the project's
history — it has landed **three separate times**, each time invisibly, because
the compiler's "syscall not routed" diagnostic is Mach-O-only:

| | Where | What it did |
|---|---|---|
| through v0.9.1 | `src/termios.cyr` defined `var SYS_IOCTL = 16` inside an arch-*blind* `#ifdef CYRIUS_TARGET_LINUX` gate | shadowed the stdlib's arch-aware value; on aarch64 every `tty_raw` / `tty_cooked` / `tty_winsize` would have called `fremovexattr` (16), not `ioctl` (29) |
| through v1.0.1 | `docs/examples/raw_loop.cyr` ended with `syscall(60, ...)` for exit, outside both platform gates | a stray `winsize` on AGNOS, where 60 is the console-grid call |
| through v1.1.0 | both test suites hardcoded ioctl / nanosleep / dup / dup2 / openat / close / prlimit64 / rt_sigprocmask | `tests/pty.tcyr` failed 15 of 53 assertions the first time it ran on real aarch64; four `tests/darshana.tcyr` assertions — including the v1.0.2 signalfd security regression test — silently never ran there while *looking* like a deliberate skip |

Two gates enforce it, and both carry a `--self-test` because a gate that cannot
fail proves nothing. `scripts/platform-gate.sh` checks **positionally** (by line
number) and **corpus-wide** (every `src/*.cyr`, not one file) that Linux ioctl and
signalfd tokens stay inside the Linux gate and agnos tokens inside theirs.
`scripts/syscall-audit.sh` refuses any syscall number written as a bare integer,
and any locally-declared syscall constant outside an arch (or AGNOS-target) gate,
anywhere in `src/`, `tests/`, `programs/` or `docs/examples/` — `syscall(1, ...)`
excepted.

⚠ Until v1.1.4 that sentence overstated what ran. The literal rule globbed
`*.cyr`, so it never scanned a single `*.tcyr` test, and it looked only at call
sites, so a NAMED constant declared in an arch-blind gate — the v0.9.2 shape
itself — passed. Neither of the first and third rows above would have been
caught by the gate this note said enforced them. Both halves are checked now, and
each `--self-test` probe asserts its own failure message, so a neutered rule can
no longer hide behind a different rule's rejection.

The general shape: take arch-varying numbers from the stdlib, which knows the
target. Define locally only what is arch-*stable* — the ioctl request codes
(`TCGETS`, `TCSETS`, `TIOCGWINSZ`) are, the syscall numbers are not.

**Numbers declared inside a target's own `#ifdef` are safe.** The AGNOS arm
declares `_AGNOS_SYS_WINSIZE = 60`, `_AGNOS_SYS_SIGPROCMASK = 17` and
`_AGNOS_SYS_SIGNALFD = 18` inside `#ifdef CYRIUS_TARGET_AGNOS`, where those numbers
can only ever mean agnos's, and calls through the names. (It never wrote a bare
`syscall(60, ...)` — the syscall audit rejects that even there.) The Linux↔agnos
overlap hazard cannot bite a number declared inside its own target's gate.

**Even a correct per-arch number can be rewritten.** The aarch64 backend
translates *some* x86_64 syscall numbers into their aarch64 equivalents. A
hand-written NATIVE aarch64 number that collides with an x86_64 one can be
"translated" into the wrong call: aarch64's ppoll is 73, which is x86_64's flock.
That is why the stdlib spells such numbers as private aliases (`SYS_PPOLL = 1073`,
translated back to 73), and why the rule is "prefer the stdlib's constant" before
"declare your own per arch". `docs/examples/raw_loop.cyr` (v1.1.4) uses the
stdlib's `SYS_PPOLL` on aarch64 for exactly this reason.

**No terminfo means no capability negotiation.** darshana emits vt100/xterm
sequences unconditionally and never asks the terminal what it supports. That is
why the escape helpers are *not* inside the Linux gate — they are byte emission,
valid on any vt100-compatible terminal regardless of host OS. A terminal that
does not understand `CSI ?1049h` gets it anyway. Capability detection would mean
terminfo or a query/response round-trip, and no consumer has asked.

**Write results are not checked.** Every escape emitter discards the `write(2)`
return. A short write on a 3–8 byte escape to a terminal does not happen in
practice, and a consumer mid-render has no useful recovery, so the emitters stay
call-site-clean and always return 0. The `_buf` composers are the escape hatch
for anyone who wants one checked write per frame instead of many unchecked ones.

## The one place it is not a raw syscall

`tty_open_signalfd` / `tty_close_signalfd` use the stdlib's `sys_sigprocmask` /
`sys_signalfd` / `file_close` wrappers on the Linux arm. Those are still
syscalls — the wrappers are thin — but note that `sys_signalfd` is a bare
passthrough that returns `-errno`, not `-1`. darshana normalizes it at its own
boundary so its documented contract holds — `tty_open_signalfd` at v0.9.3, and
`tty_close_signalfd` at v1.0.2, which is the point: v0.9.3 normalized the open
path and missed its teardown twin for three releases, leaving the Linux and
AGNOS peers disagreeing on a contract both claimed to share. When adding a
stdlib `sys_*` call, check which convention it returns before assuming `-1`, and
check the peer on the other arm at the same time.
