# 0004 — Output sanitization: one composer, two modes, `?` for everything

**Status**: Accepted
**Date**: 2026-10-12

## Context

A tool that prints text it did not write — a filename, another process's
`cmdline`, a log line, a chat message — hands the terminal whatever control
sequences that text contains. A CSI recolours or repaints the screen; an OSC
retitles the window or, on some terminals, writes the clipboard; a DCS is acted
on by others. Neutralizing those bytes before they are written is terminal
safety, not formatting.

The 2026-10-12 surveys found it was the most-duplicated terminal primitive in
the ecosystem: seven darshana consumers and nine other projects each wrote
their own. The four consumer rules read in full were all different:

| Consumer | Rule |
|---|---|
| chakshu | C0 and DEL become `?`; every byte ≥ 0x80 passes |
| cyim | C0 except TAB becomes `^X`, DEL `^?`; every byte ≥ 0x80 passes |
| kii | rejects the whole string on C0 (except TAB/LF), DEL, or C1 — raw or UTF-8-encoded — and on malformed UTF-8 |
| bannermanor | C0, DEL and every raw 0x80–0x9F byte become a space |

Two of them let C1 controls through (0x80–0x9F, the 8-bit forms of the CSI,
OSC and ST introducers). The owner ruled output sanitization into darshana's
charter the same day. The open question was the rule, because the consumers'
disagreement is not carelessness: **raw 0x80–0x9F bytes are C1 controls to a
Latin-1 terminal and ordinary continuation bytes to a UTF-8 one** (`€` is
`E2 82 AC`). bannermanor replaces them deliberately — its font schema is
ASCII-only — and that rule corrupts UTF-8 text; chakshu's and cyim's rules keep
UTF-8 text and pass C1.

## Decision

**One `_buf` composer, `tty_sanitize_buf(buf, pos, src, len, mode, keep)`,
with a mode for each kind of terminal** (owner decision between the options
offered): `TTY_SANITIZE_UTF8` and `TTY_SANITIZE_LATIN1`.

- **What is neutralized, both modes**: every C0 byte the caller did not name in
  `keep`, and DEL. **ESC is never kept**, whatever `keep` says — it is the
  attack. `TTY_KEEP_TAB` and `TTY_KEEP_LF` name the two bytes consumers keep;
  bit N of `keep` keeps byte N for the rest of C0.
- **UTF-8 mode** neutralizes C1 controls written as UTF-8 (U+0080–U+009F) and
  every byte that is not part of a well-formed RFC 3629 sequence — overlong
  forms, surrogates, code points above U+10FFFF, stray continuation bytes,
  sequences cut off by the end of the input. kii's rule is the model; it is
  the only consumer rule that was both UTF-8-safe and C1-safe. Well-formed,
  non-C1 text passes byte-for-byte.
- **Latin-1 mode** neutralizes every raw 0x80–0x9F byte and passes 0xA0–0xFF.
  This is bannermanor's rule, kept for terminals and data that really are
  single-byte; its docstring says plainly that it breaks UTF-8.
- **Every neutralized byte or sequence becomes one `?`.** So the output is never
  longer than the input — the byte budget is `len`, the same no-capacity-argument
  shape as every other `_buf` composer — and sanitizing in place
  (`buf + pos == src`) is safe. A malformed sequence is replaced one byte at a
  time and decoding resumes at the next byte.
- **Idempotent by construction**, and proven over every 1- and 2-byte input,
  the 3- and 4-byte lead space, in both modes, by `tests/identity.tcyr` against
  an independently written validator. Its digest is frozen from 1.2.0.

## Consequences

- **Positive** — one audited rule where there were four disagreeing ones, and
  the C1 pass-through two consumers shipped is closed for any consumer that
  adopts it. The rule is frozen by digest, so it cannot drift.
- **Positive** — the mode argument makes the UTF-8 / Latin-1 trade-off a
  visible, named choice at every call site instead of an accident of whichever
  consumer's copy was borrowed.
- **Negative** — the replacement byte is not configurable. cyim's caret
  notation (`^X`, two bytes per byte) and bannermanor's space are not
  reproduced; a consumer that wants them keeps its own loop. A configurable
  replacement was not added because no rule but caret notation needs more than
  one byte, and caret notation would break the `len` budget.
- **Negative** — there is no reject-only predicate; kii's "refuse the whole
  string" use is served by comparing the output length with the input's, or by
  keeping its own check.
- **Neutral** — Unicode format characters (bidirectional overrides,
  U+202A–U+202E and U+2066–U+2069) are not neutralized. Terminals do not execute
  them as controls; reordering displayed text is a different threat, and a
  consumer that needs to strip them can do so on code points.

## Alternatives considered

- **UTF-8 only.** Simplest, and right for nearly every terminal AGNOS tools run
  in, but it silently overrules bannermanor's deliberate Latin-1 rule.
- **A replace composer plus a reject predicate (`tty_has_ctl`).** Recommended
  first; the owner chose the two-mode composer instead. The predicate can be
  added later if a second consumer wants reject semantics — an addition, a
  minor.
- **Strip instead of replace.** Removing bytes hides that anything was there,
  and makes a filename that differed only in a control byte display identically
  to the one that did not. A visible `?` keeps the difference visible.
