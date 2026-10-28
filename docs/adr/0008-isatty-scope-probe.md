# 0008 — 1.6.0 adds `tty_isatty_is_per_fd()`: whether `tty_isatty` answered about the fd

**Status**: Accepted
**Date**: 2026-10-28
**Deciders**: project owner

## Context

Since 1.5.0 ([ADR 0007](0007-agnos-console-mode-and-fd-kind.md)) the AGNOS
`tty_isatty(fd)` gives one of two answers, depending on the kernel. On agnos
1.57.13 and later it asks `fd_kind#111` and answers about `fd`. On an older
kernel, and under mirshi 1.11.3, which has neither new call, it answers about
the console: 1 whenever the framebuffer console is up, for a pipe or a file
too. The arm picks between them with a private, once-per-process probe,
`_agnos_has_tty_calls()`. On Linux the answer is always about `fd`.

A consumer holding a 1 from `tty_isatty(1)` cannot tell which answer it got,
and on an old kernel that 1 is also what `prog > file` gets. darshini split
AGNOS decoration (colour, icons, the grid) and `-l` link targets out of its
1.8.0 for exactly this reason (2026-10-28): gated on `tty_isatty` alone, both
would put escapes and link targets into `darshini > file` on those kernels.
darshini's CLAUDE.md routes every terminal query through darshana, so it can
call neither `sys_fd_kind` nor the private probe, and its roadmap waits on "a
public darshana probe".

Only darshini asks, so the extract-on-second-consumer rule (CLAUDE.md,
ADR 0003) says wait. bannermanor hand-rolls `sys_fd_kind(1) == FDK_CONSOLE`
(`src/layout.cyr`, `_winsize_describes_stdout`), but it asks a different
question: whether winsize#60 describes fd 1, which is true of the console
alone and not of a terminal emulator's channel. This probe does not answer it,
so bannermanor is not a second consumer of this probe.

## Decision

**`tty_isatty_is_per_fd()` ships in 1.6.0, by owner decision
(2026-10-28).** It is additive, so the release is a minor, and from 1.6.0 it
is frozen like the rest of the surface (ADR 0003's "Added since 1.0" table).

**It is the third recorded exception to the second-consumer rule**, after
[ADR 0005](0005-candidates-ahead-of-second-consumer.md) and
[ADR 0006](0006-sgr-scanner.md). The case: the function computes nothing
darshana does not already compute privately, and a consumer that routes
terminal queries through darshana has no other way to get the answer. The
rule stands for everything after.

**The shape is a predicate with no argument**, in the predicates bucket:
1 if `tty_isatty(fd)` answers about `fd` on this platform, 0 if it answers
about something wider. It takes no fd because the answer is a property of the
platform (on AGNOS, of the kernel), not of any fd, and it cannot change
during a process: a kernel does not gain or lose a syscall mid-run.

- **Linux**: 1, with no syscall. TIOCGWINSZ is asked of `fd` itself.
- **AGNOS**: `_agnos_has_tty_calls()`, so 1 on agnos 1.57.13 and later and
  0 before and under mirshi 1.11.3. It shares the probe's cached answer with
  `tty_isatty`, so asking both costs at most one `console_mode#110` query per
  process and, under mirshi, one `ENOSYS` line, as in 1.5.0.

The intended use is two calls together: decorate when `tty_isatty_is_per_fd()`
is 1 and `tty_isatty(fd)` is 1. On a 0, a 1 from `tty_isatty` shows only that
the console is up. A terminal-safety control that should fail closed, such as
sanitizing names, can keep reading `tty_isatty` alone: on an old kernel it
then sanitizes a redirected listing too, the safe direction.

It is a platform peer, with one definition in each target gate, so
`scripts/platform-gate.sh`'s peer rule checks it with no change, and aarch64
compiles the Linux arm. It emits nothing, so no digest covers it; the 20
digests are unchanged.

## Consequences

**Positive**

- darshini can turn on AGNOS decoration and link targets on agnos 1.57.13 and
  later, and keep them off where `tty_isatty` cannot say, without leaving
  darshana's surface.
- Every consumer that gates output on `tty_isatty` gets the same check,
  instead of each one probing the kernel itself.
- Tested at every level the arm runs on: the unit suite (Linux, x86_64 and
  aarch64), `tests/agnos.tcyr` (both cached answers, and that the old-kernel
  answer asks nothing) and `tests/agnos_live.cyr` on agnos 1.57.14, where it
  is asked first and so makes the real query. Five planted defects (the Linux
  peer answering 0; the AGNOS peer answering 1 always, 0 always, the raw
  cache value, or a fresh query on every call) each fail a suite. The two that
  change the answer on a new kernel (0 always, the raw cache) also fail the
  live suite.

**Negative**

- One more frozen function, with one consumer. Its name freezes the idea that
  `tty_isatty`'s scope is one of two things, per fd or wider. A platform that
  answered per fd for some fds and not others would need another symbol.
- The exception list grows to three.

**Neutral**

- The probe says nothing about `tty_winsize`. On AGNOS, winsize#60 reports
  the console's grid whatever `fd` is. On a terminal emulator's `#97` channel,
  `tty_isatty` is 1 and so is this probe, yet `tty_winsize` still answers with
  the console's size, not the emulator window's. bannermanor's console-only gate
  exists for that question, which nobody has asked darshana to answer.
  A consumer sizing a grid from `tty_winsize` on AGNOS should know it.

## Alternatives considered

- **`tty_isatty_exact(fd)`, answering 1 / 0 / -1 (cannot tell).** One call
  per stream. But it adds a third answer, puts a second copy of what counts as
  a terminal (`FDK_CONSOLE` and `FDK_CHAN`) in a second frozen function, and
  on an old kernel answers -1 for every in-range fd, which is the predicate's
  0 restated per fd. Offered and declined.
- **Let darshini call `_agnos_has_tty_calls()`.** A `_` symbol is not frozen
  (ADR 0003): a consumer that reads one depends on an internal that a minor
  may rename or delete.
- **The consumer calls `sys_fd_kind` itself**, bannermanor's route. darshini's
  CLAUDE.md forbids it. It would also duplicate the probe and, under mirshi,
  the diagnostic line.
- **Make the old-kernel `tty_isatty` answer 0.** ADR 0007 kept the 1.4.0
  answers on old kernels on purpose (colour stays on in puka there), and
  changing a documented answer is a major under ADR 0003.
- **A constant.** On AGNOS the answer depends on the running kernel, so it
  is known only at run time.
