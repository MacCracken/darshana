# 0006 — 1.4.0 adds an SGR scanner for text: `tty_sgr_len` and `tty_sgr_strip_buf`

**Status**: Accepted
**Date**: 2026-10-28
**Deciders**: project owner

## Context

anuenue v1.4.5 removes the SGR sequences (`ESC [ <params> m`) from its input
before applying its own colour. Through v1.4.4 it kept them, and they could not
survive anyway: anuenue writes an escape before every cluster, an input ESC is a
cluster of its own, so `ls --color=always | anuenue` printed `[01;34m` as text.
anuenue carries a stand-in in `src/filter.cyr`, `_sgr_len` and
`anuenue_sgr_strip`, and on 2026-10-15 filed a proposal asking darshana to own
it (`docs/development/proposals/archive/2026-10-15-input-sgr-scanner.md`). Its
case: deciding whether the bytes at an ESC are a complete SGR, are not one, or
cannot be decided yet is ANSI grammar, and darshana owns the grammar it emits.

Two standing rules said no.

- **The input ruling** (2026-10-12, roadmap § Out of scope): darshana is
  output, termios and signals, never input decoding. The proposal is titled
  "input-side".
- **The extract-on-second-consumer rule** (CLAUDE.md, ADR 0003). Only anuenue
  asks. ADR 0005 recorded 1.3.0 as the one exception.

`tty_sanitize_buf` (ADR 0004) is not the tool. It neutralizes every control
byte, and a recolouring filter must keep every other escape sequence and every
other byte exactly as it was.

## Decision

**Both functions ship in 1.4.0, by owner decision (2026-10-28).** Each is
additive, and from 1.4.0 each is frozen like the rest of the surface
(ADR 0003's "Added since 1.0" table).

**It is in charter.** The scanner reads escapes in text a program is about to
display or measure: a filter's input, a log line, a cell whose width is being
counted. That is the output side of the terminal, the side `tty_sanitize_buf`
sits on. It decodes nothing a terminal sends back: no keys, no mouse or paste
reports. The input ruling stands as written, and CLAUDE.md now says where this
sits relative to it.

**It is the second recorded exception to the second-consumer rule**, after
ADR 0005. The rule stands for everything after.

**The shape is anuenue's**, taken from the stand-in's code rather than from
the proposal's summary of it. An SGR is ESC, `[`, zero or more parameter bytes
0x30–0x3B (digits, `:` and `;`, so colon sub-parameters too), then `m`. A
private marker, an intermediate byte, another final byte or a control byte
makes it something else. Where darshana differs from the stand-in, and why:

1. **`max` is a parameter of `tty_sgr_len`**, as the proposal specified. The
   stand-in fixed it at 128; `tty_sgr_strip_buf` keeps 128, and its docstring
   says so. There is no public constant for it, because nobody asked for one.
2. **`tty_sgr_len` checks that the byte at `s` is ESC.** The stand-in assumed
   it, because anuenue only ever asks at an ESC. A public function should not
   call `x[1m` an SGR.
3. **Out-of-contract arguments answer 0**: `s < 0`, `s >= n`, or `max < 3`.
   darshana usually answers -1 to bad arguments, but here -1 means "undecided:
   hold these bytes and ask again with more". Telling a bad call to wait could
   hold a stream forever; 0, "not an SGR", tells the caller to pass the byte
   on, which never drops or holds anything. `max < 3` answers 0 even at a lone
   ESC, because nothing shorter than `ESC [ m` is an SGR.
4. **`tty_sgr_strip_buf` rejects** a negative `n`, and a `final` other than 0
   or 1, with -1, writing nothing (`out_held` included). The stand-in took any
   nonzero `final` as 1 and rejected nothing.
5. **No counter.** The stand-in counts what it strips, for anuenue's `-v`. That
   is anuenue's to keep.

It lives in `src/ansi.cyr`, the proposal's first choice, beside the SGR
emitters: the grammar it reads is the grammar they write.

## Consequences

**Positive**

- anuenue can drop its stand-in, and any consumer that filters or measures
  coloured text gets one checked definition instead of writing its own.
- The proof is in-tree. `tests/identity.tcyr` checks both functions against
  references written apart from `src/ansi.cyr` over every string of up to five
  bytes drawn from the ten bytes that matter, every parameter-run length around
  the bound, and 3000 random strings. It checks that stripping in three chunks,
  carrying the held tail, equals stripping whole at every pair of cut points
  for the short strings, and that a strip writes nothing outside `buf[0, n)`.
  Twenty-two planted defects, one per rule, each fail the unit suite. Eighteen
  also fail the identity suite; the other four are the `s < 0` guard and the
  three rejections, which that suite never calls.

**Negative**

- Two more frozen functions. What counts as an SGR is now frozen: the
  0x30–0x3B parameter range, the rejection of private markers and
  intermediates, the `max` semantics, the 128-byte strip bound.
- darshana now reads escape sequences, which is nearer the input line than
  anything it did before. The next request of this kind (strip every CSI, scan
  OSC) needs its own decision; this one does not make it.
- The scanner is not a sanitizer. Stripped text still carries every other
  escape and is no safer for a terminal; its docstring says to sanitize after
  stripping when that matters.

**Neutral**

- anuenue's fuzz harness (`fuzz/sgr-strip.fcyr`) and robustness gate stay in
  anuenue; darshana's equivalents live in `tests/identity.tcyr`. anuenue
  replaces the stand-in on its own schedule.

## Alternatives considered

- **Leave it in anuenue until a second consumer asks.** The rule's default.
  Declined by owner decision: the grammar is darshana's, and the proposal names
  the consumers that would follow (a log viewer, a pager, a width count).
- **A general escape-sequence tokenizer** (every CSI, OSC, DCS). Larger than
  anything asked for, and much further toward decoding.
- **A strip mode for `tty_sanitize_buf`.** A different job: sanitizing
  neutralizes every control, stripping removes one kind and keeps the rest.
  Folding them would make a frozen function's mode mean two unrelated things.
- **-1 for bad arguments to `tty_sgr_len`**, as `tty_has_ctl` does. Rejected
  because -1 already means "hold and wait" (decision 3).
- **A public `TTY_SGR_STRIP_MAX`.** Not asked for; it would freeze a second
  name for a number the docstring already states.
