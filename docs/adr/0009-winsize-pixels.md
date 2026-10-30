# 0009 — 1.7.0 adds `tty_winsize_px`: the window's pixel size, from the same read

**Status**: Accepted
**Date**: 2026-10-30
**Deciders**: project owner

## Context

TIOCGWINSZ fills a `struct winsize` of four u16s: rows, columns, and the
window's width and height in pixels. `tty_winsize` (v0.3.0, frozen at 1.0)
decodes the first two from that read and throws the other two away. Through
1.6.0 its docstring called them "rarely populated; ignored".

kii added three image-protocol lanes in 2.4.0–2.6.0: iTerm2, kitty and
Sixel. Sixel is drawn in device pixels, so kii needs the cell's pixel size,
and for now it takes it as `--cell-size WxH` with a default of 10x20. Its
roadmap names two more uses. Every lane could fit the measured cell aspect
instead of an assumed 2:1. And the iTerm2 and kitty lanes could send no more
pixels than the cell box shows, where today they send the image at its decoded
resolution. kii takes its terminal size from `tty_winsize` and makes no ioctl
of its own.

Only kii asks, so the extract-on-second-consumer rule (CLAUDE.md, ADR 0003)
says wait. puka writes the pixel fields (as 0) on its child's pty, and thoth
and owl describe the struct, but all three read only rows and columns.

`tty_winsize` cannot take the pixels: two more out-pointers change its arity,
which is a major under ADR 0003.

## Decision

**`tty_winsize_px(fd, out_rows, out_cols, out_xpix, out_ypix)` ships in
1.7.0, by owner decision (2026-10-30).** It is additive, so the release is a
minor, and from 1.7.0 it is frozen like the rest of the surface (ADR 0003's
"Added since 1.0" table).

**It is the fourth recorded exception to the second-consumer rule**, after
[ADR 0005](0005-candidates-ahead-of-second-consumer.md),
[ADR 0006](0006-sgr-scanner.md) and [ADR 0008](0008-isatty-scope-probe.md).
The case: it reads nothing darshana does not already read on every
`tty_winsize` call, and a consumer that takes its terminal size from darshana
can get the rest only by issuing its own ioctl. The rule stands for
everything after.

**The shape is `tty_winsize` with two more out-pointers**, in the
validating-ops bucket: 0 on success, -1 on failure, and nothing written on
-1. One TIOCGWINSZ read fills all four, so the values describe the same
window. Two reads could straddle a resize and pair one geometry's cells with
another's pixels. The rows and columns come with the pixels because the cell
size needs both.

**0 means not reported.** The pixel fields hold whatever the terminal side
last stored with TIOCSWINSZ. Some terminal emulators store their window's
pixels, many store 0, and a pty sized by rows and columns alone has 0 there.
darshana passes the value through as it is. It does not divide or compute a
cell, and it does not substitute a default. Callers want different things from
it: kii wants the cell size, another caller might want the window size or the
aspect. Each caller also picks its own fallback for a 0.

- **Linux**: one TIOCGWINSZ read, decoded to four i64s. It refuses what
  `tty_winsize` refuses: an `fd` outside [0, 0x7FFFFFFF] and a failed ioctl.
- **AGNOS**: `tty_winsize`'s grid, with 0 × 0 pixels, or -1 if the
  framebuffer console is not up. winsize#60 answers the grid alone. The agnos
  kernel computes its cell internally (8·scale × 16·scale, `fb_console.cyr`),
  but darshana has no agnos call that reports it. So a caller's fallback for
  a 0 is what runs on agnos.

It is a platform peer, with one definition in each target gate, so
`scripts/platform-gate.sh`'s peer rule checks it with no change, and aarch64
compiles the Linux arm. It uses only the syscalls `tty_winsize` already uses,
so `scripts/syscall-audit.sh` is unchanged. It emits nothing, so no digest
covers it.

## Consequences

**Positive**

- kii can size Sixel from the terminal, fit every lane to the measured cell
  aspect, and cap the protocol lanes' pixels, wherever the terminal reports
  its pixels. It keeps `--cell-size` and its 2:1 default for terminals that
  do not.
- Any consumer gets the pixel size without its own ioctl, and gets it on
  both platforms with the same "0 is unknown" fallback.
- Tested where each arm runs. `tests/pty.tcyr` reads back pixel values whose
  high and low bytes differ, checks that a pty with no pixel size answers
  0 × 0, and checks the refusals on a non-TTY and on an aliased `slave + 2^32`.
  The unit suite checks the out-of-range refusals and that a refusal writes
  nothing. `tests/agnos_live.cyr` reads it on a real agnos kernel. Seven
  planted defects (x and y swapped, a high byte dropped, a wrong offset,
  pixels never written, rows and cols swapped, a write on failure, no fd
  check) each fail a suite.

**Negative**

- One more frozen function, with one consumer. The exception list grows to
  four.
- It hands out a value that is often 0. A caller that divides by it without
  checking divides by zero. The docstring leads with that warning, and the
  ADR records it here.

**Neutral**

- `tty_winsize` is unchanged and still ignores the pixel fields.
  `tty_winsize_or` gets no pixel sibling. Its job is a usable grid, and there
  is no common default for a pixel size.
- On AGNOS, ADR 0008's note still holds. winsize#60 reports the console's
  grid whatever `fd` is, and on a terminal emulator's channel that is not the
  emulator window's size. `tty_winsize_px` inherits this.

## Alternatives considered

- **Widen `tty_winsize`.** An arity change is a major under ADR 0003.
- **A `tty_cell_px(fd, &w, &h)` that divides.** The cell is one of kii's
  three uses. darshana would also have to choose a rounding and decide what
  a 0 means, both of which belong to the caller.
- **A separate `tty_winpixels(fd, &x, &y)`.** That is two ioctls where one
  will do, and the two answers can come from different windows. A caller
  computing the cell needs the rows and columns from the same read anyway.
- **Hand back the raw 8-byte `struct winsize`.** That gives the caller the
  u16 decode and the layout to know, which is what darshana exists to keep
  in one place.
- **Ask the terminal in-band** (xterm's `CSI 14 t`, which a terminal answers
  with its pixel size). This reaches terminals that leave the ioctl fields 0.
  But the reply arrives on the input stream, so asking needs raw mode, a
  timed read and a parser. That is a request-and-reply protocol run on the
  user's input, and no darshana call does that today. Not taken up. A consumer
  that needs it can still do it after `tty_raw`.
