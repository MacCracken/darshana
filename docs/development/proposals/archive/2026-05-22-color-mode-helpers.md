# Proposal: darshana 0.5.3 — isatty + 256-color + sgr buf helpers

**Filed:** 2026-05-22 (anuenue v0.7.0 cut; M6 — Color-Mode
Negotiation — shipped with three inline stand-ins pending this work)
**Status:** ✅ RESOLVED — darshana 0.5.3 shipped 2026-05-22. anuenue migration landed in [Unreleased] on the same day.
**Target version:** darshana v0.5.3 (pure-additive surface; no
behavioural change to existing helpers)
**Affects:** `darshana/src/termios.cyr` (1 fn) and
`darshana/src/ansi.cyr` (2 fns) + `dist/darshana.cyr` rebuild +
`tests/darshana.tcyr` (~10 assertions)

## Why now

anuenue's M6 milestone (color-mode negotiation) shipped in v0.7.0
on 2026-05-22. It detects TRUECOLOR / 256-color / 16-color / MONO
modes from `--color <mode>`, `--no-color`, `NO_COLOR` env,
`isatty(STDOUT)`, `COLORTERM`, and `TERM`, then populates the M5
phase-cached escape table with per-mode escape bytes.

Three primitives are missing from darshana 0.5.2's surface:

1. A proper **`isatty(fd)`** — anuenue today overloads
   `tty_winsize` with dummy out pointers because TIOCGWINSZ
   succeeds only on TTYs. That works (it's how anuenue's M6
   stand-in `_isatty_compat` is implemented) but conflates
   "query terminal dimensions" with "is this a terminal" at the
   API surface.
2. A **buf variant of `tty_sgr`** — darshana 0.5.1 added `_buf`
   forms for `tty_fg_rgb` / `tty_bg_rgb` / `tty_sgr_reset` but
   not for `tty_sgr`. anuenue's 16-color mode emits one-int SGR
   escapes (`\x1b[91m` … `\x1b[97m`) per phase into the
   `_PHASE_ESC_TABLE` stack buffer — the buf form is essential
   because the table builder writes into a stack buffer, not fd 1.
3. A **`tty_fg_256_buf`** — buf-targeting `\x1b[38;5;Nm` emitter.
   The truecolor (24-bit) and 16-color paths already have buf
   helpers; the 256-color middle was the only gap.

This is the *sandhi pattern's third turn for the same crank*:

- darshana **0.5.1** (2026-05-21) — anuenue M1 asked for 24-bit
  truecolor SGR helpers; darshana shipped `tty_fg_rgb` /
  `tty_bg_rgb` + buf variants + `tty_sgr_reset_buf`.
- darshana **0.5.2** (2026-05-22) — anuenue M4 asked for relative
  cursor positioning; darshana shipped `tty_cursor_up(n)` /
  `tty_cursor_down(n)`.
- darshana **0.5.3** (proposed, this doc) — anuenue M6 asks for
  isatty + 256-color emit + sgr buf form.

Pure-additive in all three cases; existing consumers
(cyim 1.7.1, chakshu 0.6.1, bannermanor, anuenue M1–M5)
unaffected.

## The ask (three functions)

### 1. `tty_isatty(fd)` — proper isatty primitive

```cyrius
# Returns 1 if `fd` refers to a TTY, 0 otherwise. Same property
# libc isatty(3) tests. Implementation can be whatever's cleanest
# on Linux — ioctl(fd, TIOCGWINSZ, &ws), tcgetattr, or fstat +
# S_IFCHR. anuenue today uses TIOCGWINSZ with dummy buffers as a
# stand-in because TIOCGWINSZ succeeds only on TTYs.
fn tty_isatty(fd) {
    var ws[8];
    var rc = syscall(SYS_IOCTL, fd, TIOCGWINSZ, &ws);
    if (rc < 0) { return 0; }
    return 1;
}
```

**File:** `darshana/src/termios.cyr` (alongside `tty_winsize` —
both are TTY-property queries). The TIOCGWINSZ const + SYS_IOCTL
are already in scope at that point in the compilation unit.

### 2. `tty_sgr_buf(buf, pos, code)` — buf variant of `tty_sgr`

```cyrius
# Writes `\x1b[<code>m` into `buf` at `pos`. Returns the new pos
# on success, -1 if `code` is outside [0, 999]. Matches the
# existing tty_sgr's bounds + the buf-targeting discipline of
# tty_fg_rgb_buf / tty_sgr_reset_buf.
fn tty_sgr_buf(buf, pos, code) {
    if (code < 0)   { return 0 - 1; }
    if (code > 999) { return 0 - 1; }
    store8(buf + pos + 0, 27);     # ESC
    store8(buf + pos + 1, 91);     # '['
    pos = pos + 2;
    pos = pos + tty_itoa(buf, pos, code);
    store8(buf + pos, 109);        # 'm'
    return pos + 1;
}
```

**File:** `darshana/src/ansi.cyr` (alongside the existing
`tty_sgr` + `tty_sgr_reset_buf`).

**Note:** the body uses `tty_itoa` from `cursor.cyr` because it
handles 1–3 digit values. cursor.cyr is included AFTER ansi.cyr
in the dist bundle order — same forward-reference shape that
`tty_fg_rgb_buf` carefully *avoids* by using the private
`_ansi_emit_u8` (u8 only). For tty_sgr_buf the 0..999 range
matches tty_sgr's bounds, so tty_itoa is the right helper, but
this requires the dist bundle order to be re-checked or
_ansi_emit_u8 to be extended to handle 0..999. Two options:

- **2a (simpler):** restrict `tty_sgr_buf`'s upper bound to 255
  (matching `_ansi_emit_u8`'s capacity) and use `_ansi_emit_u8`
  directly. SGR codes go up to 255 in common use anyway;
  anuenue's 16-color emission only hits 30–37 / 90–97. Loses
  parity with tty_sgr's [0, 999] envelope.
- **2b (right):** add a `tty_sgr_buf` implementation that
  inlines the 1–3 digit emit (same 9-line pattern `tty_itoa`
  uses, copied into ansi.cyr to avoid the cross-module
  reference). Preserves tty_sgr's [0, 999] envelope.

Recommend **2b** — keeps the buf form a drop-in replacement for
the fd-write form. Eight lines of inline digit-emit beats a
distlib-order coupling.

### 3. `tty_fg_256_buf(buf, pos, n)` — 256-color fg emitter

```cyrius
# Writes `\x1b[38;5;Nm` into `buf` at `pos` for `n` in [0, 255].
# Returns the new pos, -1 out-of-range. Length envelope:
# 8 bytes ("\x1b[38;5;0m") to 11 bytes ("\x1b[38;5;255m").
fn tty_fg_256_buf(buf, pos, n) {
    if (n < 0)   { return 0 - 1; }
    if (n > 255) { return 0 - 1; }
    store8(buf + pos + 0, 27);     # ESC
    store8(buf + pos + 1, 91);     # '['
    store8(buf + pos + 2, 51);     # '3'
    store8(buf + pos + 3, 56);     # '8'
    store8(buf + pos + 4, 59);     # ';'
    store8(buf + pos + 5, 53);     # '5'
    store8(buf + pos + 6, 59);     # ';'
    pos = pos + 7;
    pos = _ansi_emit_u8(buf, pos, n);
    store8(buf + pos, 109);        # 'm'
    return pos + 1;
}
```

**File:** `darshana/src/ansi.cyr` (alongside `tty_fg_rgb_buf`).
`_ansi_emit_u8` is already in this file and handles 0–255 — no
forward-reference concern.

## Anuenue's compat stand-ins (what gets removed)

When darshana 0.5.3 lands, these three stand-ins in
`anuenue/src/color.cyr` get deleted:

```cyrius
# Stand-in for darshana 0.5.3's tty_isatty
fn _isatty_compat(fd) { ... 5 lines ... }

# Stand-in for darshana 0.5.3's tty_fg_256_buf
fn _fg_256_buf_compat(buf, pos, n) { ... 14 lines ... }

# Stand-in for darshana 0.5.3's tty_sgr_buf
fn _sgr_buf_compat(buf, pos, code) { ... 11 lines ... }
```

…and their call sites (in `anuenue/src/color.cyr` and
`anuenue/src/filter.cyr`) get sed-rewritten to call the darshana
forms. Approximate impact on anuenue:

- ~30 lines deleted from `src/color.cyr`
- ~3 call-site renames in `src/filter.cyr` (`_phase_esc_init`
  branches) and `src/color.cyr` (the detect path's isatty call)
- Anuenue's DCE binary shrinks by ~1–2 KB (compat fns + the
  call-site jumps)

Each stand-in carries a `TODO(sandhi 0.5.3)` comment marker —
`grep -rn 'TODO(sandhi 0.5.3)' src/` finds them.

## Acceptance gates

For darshana 0.5.3:

1. **VERSION bumped** 0.5.2 → 0.5.3.
2. **CHANGELOG entry** in `[0.5.3]` section — sandhi pattern's
   third turn, name anuenue M6 as the consumer asking. Pure
   additions; no behavioural change.
3. **`cyrius distlib`** rebuilds `dist/darshana.cyr` — three new
   public fns visible in the bundle, dist drift check passes.
4. **`tests/darshana.tcyr` additions** — pattern from
   the v0.5.1 truecolor truth-table tests:
   - `tty_sgr_buf(buf, 0, 0)` → 4 bytes `\x1b[0m`
   - `tty_sgr_buf(buf, 0, 91)` → 5 bytes `\x1b[91m`
   - `tty_sgr_buf(buf, 0, 1000)` → -1, buf untouched
   - `tty_fg_256_buf(buf, 0, 0)` → 9 bytes `\x1b[38;5;0m`
   - `tty_fg_256_buf(buf, 0, 255)` → 11 bytes `\x1b[38;5;255m`
   - `tty_fg_256_buf(buf, 0, -1)` / `(buf, 0, 256)` → -1
   - `tty_isatty(fd_to_known_not_tty)` → 0  (use the same
     non-tty fd pattern darshana's existing tty_winsize live test
     uses; if no such pattern exists, just confirm both 0/1
     return values are reachable without crash)
5. **`scripts/smoke.sh`** — public-surface enumerator gains the
   three new symbols. Current count is 24; bumps to 27.
6. **`build/darshana-smoke`** still prints `darshana smoke ok` —
   confirms the bundle still compiles and the dist-drift check
   passes.

## Anuenue-side migration (post-darshana-0.5.3)

Sequenced as a small follow-up PR; estimated 10-minute task:

1. `cd /home/macro/Repos/anuenue`
2. Edit `cyrius.cyml`: `tag = "0.5.2"` → `tag = "0.5.3"` under
   `[deps.darshana]`.
3. `cyrius deps` — pull the new pin.
4. In `src/color.cyr`: delete `_isatty_compat`, `_fg_256_buf_compat`,
   `_sgr_buf_compat` (with their TODO markers). Search-replace
   call sites:
   - `_isatty_compat(STDOUT)` → `tty_isatty(STDOUT)`
   - `_fg_256_buf_compat(...)` → `tty_fg_256_buf(...)`
   - `_sgr_buf_compat(...)` → `tty_sgr_buf(...)`
5. `cyrius build src/main.cyr build/anuenue` — confirm clean
   compile (the swap is signature-identical).
6. Full gauntlet: `cyrius test` (241/241), `sh scripts/golden-check.sh`
   (6 fixtures + 3 MONO equivalence), `sh scripts/animate-smoke.sh`,
   `sh scripts/perf-bench.sh` (should match 0.7.0 within noise).
7. Bump anuenue VERSION 0.7.0 → 0.7.1 (sandhi-bump cleanup
   patch) or fold into 0.8.0 (M7 doc work) — user's call.
8. CHANGELOG entry: removes the "sandhi pending" caveat from
   the 0.7.0 entry, lands the darshana 0.5.3 pin bump.

## Why this lives in sandhi/docs/proposals/

The folder is the AGNOS cross-repo coordination hub (per the
existing `2026-04-24-cyrius-fixup-table-cap.md` and
`2026-05-03-allocator-migration.md` precedents — one is a cyrius
proposal, one is a sandhi-internal migration). This proposal is
about a darshana sandhi-bump driven by an anuenue need — three
repos involved, no obvious home in any of them.

## References

- anuenue 0.7.0 CHANGELOG: M6 — Color-Mode Negotiation (the
  shipped milestone this proposal closes the deferral on)
- anuenue `src/color.cyr`: the three `_*_compat` stand-ins
  (search `TODO(sandhi 0.5.3)`)
- darshana 0.5.1 CHANGELOG: previous sandhi-bump (truecolor for
  anuenue M1) — same pattern, same scope shape
- darshana 0.5.2 CHANGELOG: previous sandhi-bump (cursor_up/down
  for anuenue M4)
- `feedback_dep_lockin_sandhi_unlock` (agnosticos memory): the
  consumer-driven dep-bump pattern this proposal exercises
- AGNOS first-party-standards rule: *ANSI escape generation
  belongs in darshana* (CLAUDE.md, anuenue) — the rule this
  proposal closes the loop on

## Log

- **2026-05-22** — Filed alongside the anuenue v0.7.0 cut.
  Anuenue M6 shipped with three inline stand-ins so the milestone
  could land without blocking on this proposal. Migration steps
  (above) are mechanical when darshana 0.5.3 ships.
