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
silently.** darshana carried exactly this bug through v0.9.1: `src/termios.cyr`
defined `var SYS_IOCTL = 16` — the x86_64 number — inside a
`#ifdef CYRIUS_TARGET_LINUX` gate, which is architecture-*blind*. On aarch64
Linux `ioctl` is 29, and 16 is `fremovexattr`. The local definition shadowed the
stdlib's arch-aware one, the compiler emitted a "last definition wins" warning
that nothing gated on, and every `tty_raw` / `tty_cooked` / `tty_winsize` on
aarch64 would have called the wrong syscall. Fixed in v0.9.2 by deleting the
local definition; `scripts/smoke.sh` and CI now enforce **positionally** that
Linux ioctl tokens stay inside the Linux gate.

The general shape: take arch-varying numbers from the stdlib, which knows the
target. Define locally only what is arch-*stable* — the ioctl request codes
(`TCGETS`, `TCSETS`, `TIOCGWINSZ`) are, the syscall numbers are not.

**Numbers inside a target's own `#ifdef` are safe to hardcode.** The AGNOS arm
uses raw `syscall(60, ...)` / `syscall(17, ...)` / `syscall(18, ...)` with no
stdlib wrapper, because inside `#ifdef CYRIUS_TARGET_AGNOS` those numbers can
only ever mean agnos's. The Linux↔agnos overlap hazard cannot bite a number used
inside its own target's gate.

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
boundary (v0.9.3) so its documented contract holds. When adding a stdlib `sys_*`
call, check which convention it returns before assuming `-1`.
