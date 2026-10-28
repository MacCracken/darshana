# 0007 — 1.5.0's AGNOS arms use console_mode#110 and fd_kind#111

**Status**: Accepted
**Date**: 2026-10-28
**Deciders**: project owner (the release); the shape below, recorded for review

## Context

Through 1.4.0 three AGNOS peers could not do what their Linux twins do, and
said so in their docstrings. `tty_echo_off` and `tty_flush_input` returned -1
always: the agnos console echoed every key and had no flush call.
`tty_isatty(fd)` answered about the console rather than `fd`: 1 whenever the
framebuffer console was up, so `prog > file` on agnos still received escapes.
darshana filed all three with agnos on 2026-10-12.

agnos 1.57.13 closed them. `console_mode#110(set, clear)` sets and clears the
console's `CM_NOECHO` mode and performs `CM_FLUSH` (discard typeahead and the
non-blocking reader's partial line), answering the flags from before the call
or -1. `fd_kind#111(fd)` answers what an fd is: `FDK_CONSOLE`, `FDK_FILE`,
`FDK_PIPE`, `FDK_CHAN` and six more, or -1. The kernel also posts SIGWINCH (28)
to a bit-28 signalfd watcher when the console grid changes. cyrius's stdlib
wraps both calls from 6.7.11. The roadmap held the arms for 1.5.0, and the owner
scheduled them after 1.4.0.

The roadmap classifies an AGNOS arm that becomes real as **additive**: the
answers that change were documented platform limits, never promises, and each
change moves the AGNOS peer onto the Linux contract it was always meant to
share. ADR 0003's return buckets are unchanged. So the release is a minor.

Several shapes needed choosing.

## Decision

**Which fds are terminals.** `tty_isatty(fd)` is 1 for `FDK_CONSOLE` and for
`FDK_CHAN`, and 0 for everything else. A `#97` channel endpoint is how a
terminal emulator hands its child stdio: puka runs its child on one and
interprets the child's escapes, and through 1.4.0 that child already got 1.
agnsh pipelines use `pipe#25` (`FDK_PIPE`), so a pipe is not mistaken for one.
agnos itself left the channel question to darshana ("whether a channel
endpoint is a terminal band is the caller's call").

**Which fds take a mode.** `tty_echo_off` and `tty_flush_input` act only when
`fd` is `FDK_CONSOLE`. `console_mode#110` reaches the console's line discipline
and nothing else; a terminal emulator runs its own (puka's
`line_discipline.cyr`), and agnos offers darshana no call into it. On a channel
both stay -1, the answer that is true there.

**Echo-off flushes, as on Linux.** `tty_echo_off` issues `CM_NOECHO | CM_FLUSH`
in one call, agnos's TCSETSF, so keys typed before the prompt cannot become the
secret: the Linux peer's documented behaviour.

**One slot, with Linux's rules.** `tty_echo_off` takes the single save slot. A
different fd while it is held is refused, even another fd on the console; the
fd that holds it gets a no-op 0. `tty_cooked()` puts the console's `CM_NOECHO`
bit back as it was before the first call (so echo that was already off stays
off), and leaves the slot held if the call fails. `tty_forget()` frees the slot
and makes no call. One difference is agnos's and is documented: the kernel
clears the mode when its holder dies, so a crash cannot leave the console dark.

**Old kernels keep their 1.4.0 answers.** Before 1.57.13 neither call exists.
The arm asks once per process with `console_mode#110`'s query `(0, 0)`, which
changes nothing, and caches the answer: a kernel cannot gain or lose a syscall
mid-process. Without the calls, `tty_echo_off` and `tty_flush_input` are -1 and
`tty_isatty` answers about the console, exactly as through 1.4.0. Asking once
also keeps a process quiet under mirshi 1.11.3, which prints a line for every
call it does not know and does not know these two yet.

**An fd outside [0, 0x7FFFFFFF] is refused before any call**, as on Linux. On
an old kernel this is the one answer that changes: such an fd was "about the
console" through 1.4.0 and is now 0.

**Stdlib wrappers, so AGNOS builds need cyrius ≥ 6.7.11.** `src/` issues no raw
`syscall(` (CLAUDE.md), so the arm calls `sys_console_mode` and `sys_fd_kind`
and reads `FDK_*` and `CM_*`, which the stdlib has had since 6.7.11. Measured
with a consumer that includes the bundle: its AGNOS build fails under 6.7.10
(`undefined variable 'FDK_CONSOLE'`) and builds under 6.7.11 and 6.7.18. Linux
builds compile none of the AGNOS arm, and their floor stays 6.7.2.

**Tested on a real agnos kernel.** The host suite (`tests/agnos.tcyr`) can run
only the paths that make no call, because on the Linux host agnos 110 and 111
are `getppid` and `getpgrp`. So `tests/agnos_live.cyr` runs on agnos itself:
`scripts/agnos-live.sh` seeds it as `/bin/agnsh` next to an agnos kernel and
gnoboot, boots that in QEMU with agnos's own image recipe, and scores the
suite's 57 assertions from the serial log. It mints a #97 channel pair, so the
channel answers run too. It needs an agnos kernel build, so
it is a release step, like the Raspberry Pi run, and not a CI gate.

## Consequences

**Positive**

- On agnos 1.57.13 and later, a password prompt hides what is typed, a
  confirmation prompt can discard typeahead, and `prog > file` or `prog | other`
  gets no escapes. bannermanor's and darshini's AGNOS workarounds for the
  console-wide `tty_isatty` can go.
- The AGNOS arm runs on a real kernel for the first time, the signalfd peers
  included: the live suite raises SIGINT at itself and reads it through
  `tty_read_signal`.

**Negative**

- An AGNOS consumer must pin cyrius 6.7.11 or later to take 1.5.0.
- Some of it rests on reading, not running. The old-kernel fallback needs a
  kernel older than 1.57.13, and the flush itself (for echo-off and for
  `tty_flush_input`) needs typed keys to discard; the live suite reaches
  neither. A planted defect in each survives every suite.
- Under today's mirshi the arms keep their 1.4.0 answers until mirshi learns
  the two calls, and print one `mirshi: ENOSYS agnos#110` line per process.

**Neutral**

- The SIGWINCH mask (`1 << 28`) was already right; agnos's tty-smoke T7 shows
  the kernel posting to a bit-28 watcher. darshana has not run its WINCH
  signalfd against it, which needs agnos's TTY_SELFTEST geometry knob.

## Alternatives considered

- **`tty_isatty` true for `FDK_CONSOLE` only.** The literal reading of the
  stdlib's comment. It turns colour off in puka, the one terminal emulator
  agnos has, where 1.4.0 left it on.
- **A per-call probe, or none.** Probing on every call doubles the calls and,
  under mirshi, the diagnostics; not probing and treating `fd_kind`'s -1 as
  "not a terminal" would answer 0 for every fd on an old kernel, where 1.4.0
  answered 1.
- **Raw `syscall(110, …)` in the AGNOS gate**, to keep AGNOS builds on 6.7.2.
  CLAUDE.md forbids it, and the stdlib wrapper also handles the tagged socket
  fds that the kernel cannot see.
- **A CI gate for the live suite.** A runner has no agnos kernel. Fetching
  agnos's release image in CI is possible later; until then the run is a
  release step.
