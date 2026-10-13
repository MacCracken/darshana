# 0005 — 1.3.0 ships the candidate set ahead of a second consumer

**Status**: Accepted
**Date**: 2026-10-12
**Deciders**: project owner

## Context

CLAUDE.md's "consumers drive the API" rule extracts a primitive when a
**second** consumer needs it, and not before; ADR 0003 restates it as the
extract-on-second-consumer rule. Every 1.2.0 addition passed that test. After
1.2.0 the roadmap held seven candidates that had not:

| Candidate | Evidence at the 2026-10-12 survey |
|---|---|
| Input flush | chakshu |
| thoth's screen controls: cursor save / restore, scroll region, window title, clipboard, `_buf` move and clear-to-EOL, mouse and bracketed-paste enable / disable | thoth |
| 16-color background codes and a compound SGR composer | commandress, vidya, cyrius-yeomans-descent (none a consumer) |
| Echo-off for password input | shakti, kybernet (neither a consumer) |
| `TTY_SIGMASK_PIPE` | nobody: every surveyed signalfd mask leaves SIGPIPE out |
| A reject-only sanitizer predicate | kii |
| `tty_forget()`, a public reset of the raw slot | nobody hit the stranded-slot case |

## Decision

**All seven ship in 1.3.0, by owner decision**, given with that table in
view. Each is additive, and from 1.3.0 each is frozen like the rest of the
surface (ADR 0003's "Added since 1.0" table).

The rule is not repealed. This is one release in which the owner chose to
close the candidate list rather than carry it. Later candidates wait for a
second consumer as before.

Shipping without a second consumer leaves the shape with no second opinion,
so each shape copies the hand-rolled code that exists:

- **`tty_flush_input(fd)`** is chakshu's `TCFLSH` / `TCIFLUSH` call.
- **`tty_echo_off(fd)`** follows kybernet's rule: clear ECHO and ECHONL, keep
  line editing (ICANON), apply with TCSETSF so typed-ahead keys are discarded.
  It takes the same single save slot as `tty_raw`, so one `tty_cooked()`
  restores either mode and a mode switch on the slot's fd re-derives from the
  saved cooked state. A second slot would have needed a second restore and an
  ordering rule between the two.
- **thoth's controls** match thoth's bytes:
  - `ESC 7` / `ESC 8`, not `CSI s` / `CSI u`;
  - mouse modes 1000 + 1006 only, disabled in reverse;
  - OSC titles and the clipboard terminated with BEL, which more terminals
    accept than ST;
  - standard RFC 4648 base64 with padding.

  The title goes through `tty_sanitize_buf` (UTF-8 mode, nothing kept), so the
  text cannot end the escape early. The direct `tty_title` takes at most 256
  bytes, thoth's cap. `tty_clipboard_set` streams in 48-byte pieces, so its
  payload has no cap.
- **`tty_sgr_list_buf(buf, pos, codes, n)`** takes an i64 array, the shape
  commandress builds its codes in. It accepts 1–16 codes, each in [0, 999], and
  validates all of them before writing.
- **`tty_has_ctl`** is `tty_sanitize_buf`'s rule as a predicate.
  `tests/identity.tcyr` proves, over the sanitizer's whole test domain, that
  it answers 1 exactly when sanitizing changes the input.
- **`TTY_SIGMASK_PIPE`** is `0x1000` on Linux and `0x2000` on AGNOS, using the
  agnos `1 << sig` layout. agnos has no SIGPIPE, so the AGNOS mask never fires.
- **`tty_forget()`** clears the slot and issues no ioctl, as ADR 0003 and
  architecture note 001 sketched it.

On AGNOS, `tty_echo_off` and `tty_flush_input` return **-1**. The kernel
console echoes every key and has no flush call, so a `0` would tell a password
prompt that it is hidden when it is not. Both gaps are filed with agnos.

## Consequences

- **Positive** — no candidate is left half-designed in the roadmap. Every new
  composer and emitter is frozen by a digest. Each design rule in the Decision
  section was planted as a defect, and every test suite caught it.
- **Negative** — seven shapes now frozen with at most one user each. If a later
  consumer wants a different shape, that is a new symbol, not a change.
- **Negative** — the surface went from 34 functions and 45 constants to 54 and
  62 in one release. That is the frozen surface consumers depend on, and the
  docs they read.
- **Neutral** — the extract-on-second-consumer rule stands for everything not
  in the table above.

## Alternatives considered

- **Re-survey and ship only what fired** — recommended, and declined. Same-day
  evidence would have shipped none of the seven.
- **Leave them out** — declined, for the same reason the rule exists.
