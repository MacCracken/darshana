# ADR 0003 — The v1.0 API freeze: what is frozen, and what it costs to change

**Status**: Accepted
**Date**: 2026-08-23
**Deciders**: project owner
**Supersedes**: nothing. **Amends**: the pre-v1.0 latitude recorded in CLAUDE.md.

## Context

darshana shipped v1.0.0 with all five v1.0 criteria met. Up to that tag,
breaking the public surface was not merely permitted but *encouraged* — the
cheapest time to fix a bad name or a bad return convention is before anyone is
promised stability. That latitude was used, repeatedly and deliberately:

| Version | Break |
|---------|-------|
| v0.7.0 | `tty_cooked(fd)` → `tty_cooked()` — the fd parameter implied a per-fd restore the single save slot cannot deliver |
| v0.7.0 | `tty_itoa` → `tty_dec_buf`, return harmonized from digit-count to new-position |
| v0.7.0 | `tty_clear_to_end` → `tty_clear_to_eos` — "end" read ambiguously against `_to_eol` |
| v0.7.0 | `tty_apply_raw_flags` privatized to `_tty_apply_raw_flags` |
| v0.9.3 | `tty_sgr_reset_buf` / `tty_dec_buf` gained a `-1` return (negative-`pos` rejection) |
| v0.9.3 | `AGNOS_*` constants privatized to `_AGNOS_*` |

That window is now closed. This ADR records **exactly what closed**, because a
freeze that does not enumerate its own surface is a slogan rather than a
contract.

## Decision

**The symbols below are frozen at v1.0.0.** Their names, arities, and documented
return contracts do not change without a major version bump.

### Frozen: 29 public functions

| | | | |
|---|---|---|---|
| `tio_load32` | `tio_store32` | `tty_alt_enter` | `tty_alt_leave` |
| `tty_bg_rgb` | `tty_bg_rgb_buf` | `tty_clear` | `tty_clear_to_eol` |
| `tty_clear_to_eos` | `tty_close_signalfd` | `tty_cooked` | `tty_cursor_down` |
| `tty_cursor_hide` | `tty_cursor_home` | `tty_cursor_show` | `tty_cursor_up` |
| `tty_dec_buf` | `tty_fg_256_buf` | `tty_fg_rgb` | `tty_fg_rgb_buf` |
| `tty_isatty` | `tty_move` | `tty_open_signalfd` | `tty_raw` |
| `tty_sgr` | `tty_sgr_buf` | `tty_sgr_reset` | `tty_sgr_reset_buf` |
| `tty_winsize` | | | |

### Frozen: 37 public constants

| | | | |
|---|---|---|---|
| `TCGETS` | `TCSETS` | `TIOCGWINSZ` | `TIO_BRKINT` |
| `TIO_BUF_SIZE` | `TIO_CC_BASE` | `TIO_CS8` | `TIO_CSIZE` |
| `TIO_ECHO` | `TIO_ICANON` | `TIO_ICRNL` | `TIO_IEXTEN` |
| `TIO_INPCK` | `TIO_ISIG` | `TIO_ISTRIP` | `TIO_IXON` |
| `TIO_OPOST` | `TIO_VMIN` | `TIO_VTIME` | `TTY_FG_BLACK` |
| `TTY_FG_BLUE` | `TTY_FG_BRIGHT_BLACK` | `TTY_FG_BRIGHT_BLUE` | `TTY_FG_BRIGHT_CYAN` |
| `TTY_FG_BRIGHT_GREEN` | `TTY_FG_BRIGHT_MAGENTA` | `TTY_FG_BRIGHT_RED` | `TTY_FG_BRIGHT_WHITE` |
| `TTY_FG_BRIGHT_YELLOW` | `TTY_FG_CYAN` | `TTY_FG_GREEN` | `TTY_FG_MAGENTA` |
| `TTY_FG_RED` | `TTY_FG_WHITE` | `TTY_FG_YELLOW` | `TTY_SIGMASK_EXIT` |
| `TTY_SIGMASK_WINCH` | | | |

`scripts/smoke.sh` (`required_syms` / `required_flags`) is the machine-readable
form of both tables, checked against `dist/darshana.cyr` in **both** directions
on every CI run: a listed symbol missing from dist fails, and a public symbol in
dist missing from the list fails. Editing either table means editing that file,
which is the point.

### What "frozen" covers

- **Names.** No renames.
- **Arity.** No added, removed, or reordered parameters.
- **The documented return contract**, as stated in the front matter of
  `dist/darshana.cyr`: the four return buckets (validating side-effecting ops,
  unconditional emitters, `_buf` composers, predicates/fd-openers) and each
  symbol's own docstring.
- **Emitted bytes** for a given input. A consumer asserting on exact escape
  bytes — `tests/pty.tcyr` does, and so may a consumer's own suite — is
  relying on frozen behavior.
- **Constant values.** `TTY_SIGMASK_EXIT` is `0x4003` on Linux and `0x8006` on
  AGNOS, and stays so.

### What "frozen" does NOT cover

- **`_`-prefixed symbols.** `_tty_saved`, `_tty_in_raw`, `_tty_raw_fd`,
  `_tty_apply_raw_flags`, `_ansi_emit_u8`, `_ansi_rgb_buf`, `_ansi_rgb_write`,
  `_cursor_rel`, `_AGNOS_SYS_*`, `_AGNOS_SFD_CLOEXEC`. These ship in the bundle
  because it is one compilation unit, not because they are API. They may be
  renamed, resliced, or deleted in a minor release.

  One caveat, stated because ADR 0002 depends on it: the module-global save
  state (`_tty_saved` / `_tty_in_raw` / `_tty_raw_fd`) is *reachable* by design —
  ADR 0002 makes consumer-side restore-from-any-exit-path possible precisely
  because those globals can be touched. Reachable is not the same as frozen. A
  consumer that reads them is depending on an internal, and the supported way to
  restore is `tty_cooked()`.
- **Internal structure.** Which module a symbol lives in, the order of modules
  in the bundle, and the presence or shape of private helpers are all free to
  change — as the v0.9.3 duplication pass demonstrated without touching a byte
  of output.
- **Platform coverage growing.** Adding an `#ifdef` peer for a new target is
  additive, not breaking.

## Consequences

**Positive**

- Consumers can pin a `1.x` tag and take minor bumps without reading a diff.
  Five consumers were carrying darshana at four different versions during the
  0.9.x arc; that cost is now bounded.
- The freeze is enumerated and machine-checked, so "did we break the API?" is a
  CI answer rather than a judgement call.

**Negative**

- Mistakes now cost a major bump. Two known-imperfect things are frozen in:
  - `tio_load32` / `tio_store32` bounds-check nothing. That is documented and
    deliberate — they are a codec over a caller-owned buffer — but it is a sharp
    edge that a v2 might blunt.
  - The single-raw-fd model means a permanently failing `tty_cooked()` strands
    the slot for the process lifetime with no public reset
    ([architecture note 001](../architecture/001-module-global-termios-state.md)).
    Adding `tty_forget()` was considered at v0.9.3 and rejected as a
    speculative knob; if a consumer ever hits this for real, it is a **minor**
    addition, not a break.
- "Consumers drive the API" now has a harder edge: a consumer asking for a
  *changed* symbol gets a v2 discussion, not a patch.

**Neutral**

- Additive change stays cheap. New functions, new constants, new platform peers,
  and new `_`-prefixed internals are all minor bumps. The extract-on-2nd-consumer
  rule (`tty_bg_256_buf` is the standing example) is unaffected by the freeze.

## Post-1.0 change policy

Semver, read strictly:

- **Patch (1.0.x)** — bug fixes that do not change a documented contract.
  A fix that makes behavior *match* its existing documentation is a patch, even
  if the observable behavior changes; v0.9.3's `tty_open_signalfd` sentinel
  normalization would have qualified.
- **Minor (1.x.0)** — additive only. New symbols, new platform peers, new
  documentation, internal refactors with identical output.
- **Major (2.0.0)** — anything in the "What frozen covers" list above. Requires
  its own ADR stating what breaks and why the break beats carrying the defect,
  plus a migration note for every consumer.

## Alternatives considered

**Freeze only the names, not the return contracts.** Rejected. The v0.9.3 audit
found `main.cyr`'s return-conventions block was false for 12 of 29 functions and
had never shipped to consumers at all; a name-only freeze would have frozen the
easy half and left the half that actually bites unpinned.

**Wait for all five consumers to bump to a v0.9.4 dep before tagging.**
Considered and declined by the project owner. The consumer bumps are tracked in
`docs/development/roadmap.md` and remain outstanding at the v1.0.0 tag: the
surface being frozen is the one v0.9.4 audited, not the one any consumer is
currently compiled against. This is a sequencing choice, not a correctness one —
the two v0.9.3 breaks were verified against all five consumer trees and affect
zero live call sites — but it does mean the first real exercise of the frozen
surface happens after the tag rather than before it.
