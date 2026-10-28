# Proposal: an input-side SGR scanner (`tty_sgr_len` / `tty_sgr_strip_buf`)

**Filed:** 2026-10-15 by anuenue (v1.4.5 cut). anuenue now strips SGR colour codes from its *input*, with an
inline stand-in pending this.
**Status:** ✅ RESOLVED — darshana 1.4.0 shipped both functions on 2026-10-28, in `src/ansi.cyr`, by owner
decision ([ADR 0006](../../../adr/0006-sgr-scanner.md)). The contract is the stand-in's, with five recorded
differences: `max` is a parameter of `tty_sgr_len` (`tty_sgr_strip_buf` keeps 128); `tty_sgr_len` checks for
the ESC at `s`; out-of-contract arguments answer 0; `tty_sgr_strip_buf` rejects a negative `n` or a `final`
other than 0 / 1 with -1; and darshana keeps no strip counter.
**Target version:** darshana 1.4.0 (pure-additive surface; no behavioural change to existing helpers)
**Affects:** `src/ansi.cyr`, plus a `dist/darshana.cyr` rebuild and tests

## Why

darshana owns the ANSI substrate on the way OUT: every escape anuenue emits is darshana's. anuenue v1.4.5
added the first thing it does with escapes on the way IN. On its colour routes it removes SGR sequences
(`ESC [ <params> m`) from the input before applying its own colour. Through v1.4.4 they were kept, and they
could not survive anyway: anuenue's per-cluster escape cancels each input ESC, so `ls --color=always | anuenue`
printed `[01;34m` as text.

`tty_sanitize_buf` is not the tool for this. It neutralises every control byte, and anuenue must keep non-SGR
sequences and every other byte as they are. So anuenue carries a stand-in, `_sgr_len` / `anuenue_sgr_strip` in
`src/filter.cyr`, that decides one thing: whether the bytes at an ESC are a complete SGR, are not one, or cannot
be decided yet (the buffer ends first).

That decision is ANSI grammar, which this crate owns. Any consumer that filters or measures coloured text needs
it too: a log viewer, a pager, a width calculation.

## Proposed surface

```cyrius
# Length of the SGR sequence at buf + s (an ESC) within n bytes:
#   > 0  a complete SGR of that many bytes
#   0    not an SGR
#   -1   undecided — the buffer ends first (within max bytes)
# SGR = ESC '[' params(0x30..0x3B, so ':' sub-parameters too) 'm'; a private marker
# ('<' '=' '>' '?') or an intermediate byte makes it something else. Never longer than max.
fn tty_sgr_len(buf, s, n, max): i64

# Remove complete SGRs from buf[0, n) in place; return the kept length. With final == 0, an
# undecided tail is moved after the kept bytes and its length stored through out_held,
# for a streaming caller to carry into its next read.
fn tty_sgr_strip_buf(buf, n, final, out_held): i64
```

anuenue's stand-in has this exact contract, with `max` fixed at 128. It is covered by:
- a fuzz harness checking it against an independent reference, including the property that stripping in two
  chunks with the held tail carried equals stripping in one (`fuzz/sgr-strip.fcyr`);
- a robustness gate over the real binary (`scripts/robustness-check.sh` gate 10);

both of which could move with it.

## What anuenue would do

Replace the stand-in with the darshana calls, at the next sandhi bump after this ships. No anuenue output
changes.
