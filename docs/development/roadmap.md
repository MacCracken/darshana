# darshana — Roadmap

> **Forward-facing only.** What is left to do, in what order, against what
> gates. Nothing here describes work already shipped.
>
> - What shipped, and when → [`CHANGELOG.md`](../../CHANGELOG.md)
> - Where the code stands today → [`state.md`](state.md)
> - Why a given choice was made → [`../adr/`](../adr/)
>
> When a milestone closes, its section is **deleted** from this file, not
> checked off in place. The checkbox history belongs in the CHANGELOG.

## Where things stand

**v1.0.0 shipped 2026-08-23 — the API is frozen.** 29 functions and 37
constants, enumerated in [ADR 0003](../adr/0003-v1-api-freeze.md) and
machine-checked bidirectionally on every CI run. Breaking one now costs a major
bump and its own ADR; additive change stays minor.

The library is done in the sense that mattered: it owns its slice, five
consumers use it, and the surface has stopped moving. What follows is
maintenance and consumer-driven growth, not a march to a milestone.

## Open now

- [ ] **Bump the five consumers to a `1.x` dep.** Outstanding at the v1.0.0 tag:
      chakshu (0.9.0), anuenue (0.9.0), cyim (0.8.2), kii (0.8.2), bannermanor
      (0.7.1). No consumer *code* change is required — the two v0.9.3 breaks were
      verified against all five trees and affect zero live call sites — but until
      this lands, the frozen surface is one nobody is actually compiled against.
      bannermanor is furthest behind; **kii additionally has a pin mismatch** to
      reconcile (manifest `tag = "0.8.2"` while its vendored bundle reads 0.9.0,
      because it resolves via `path = "../darshana"`).

## Out of scope

Boundaries, not backlog. Each has been considered and declined; the reason is
recorded so it does not get re-litigated. Nothing here is blocked on a version —
these are charter decisions, and the freeze does not change them.

- **macOS / BSD termios support.** The donor was Linux-only and darshana
  follows. The BSD termios struct differs, so this is a real port, not a flag.
  Add when a real consumer needs it — not before (CLAUDE.md domain rules).
- **Windows console API.** Out of project scope for any AGNOS first-party tool.
- **Widget toolkit / form controls / render loops / event dispatch.** Belongs in
  the consumer. darshana is the primitive layer below them. Specifically:
  **`tty_frame_begin()` / `tty_frame_end()` will not ship** — they were penciled
  in early under an explicit "otherwise skip — primitives, not framework"
  clause, and that clause won. Do not resurrect them.
- **Signal-*handler* installation.** No `tty_install_winch_handler(fp)` or any
  other `sigaction`-shaped API will ship. Signal delivery is routed through
  `signalfd` instead, which is what `tty_open_signalfd` /
  `tty_close_signalfd` + `TTY_SIGMASK_*` exist for. Rejected outright in
  [ADR 0002](../adr/0002-state-restore-posture.md) §Alternatives.
- **A color-management layer.** The SGR primitives cover 16-color, 256-color,
  and truecolor emission. Anything *above* raw SGR — palette abstraction,
  nearest-color quantization, theme management — is a consumer or sibling-lib
  concern.
- **Mouse / bracketed paste.** Out of scope until a consumer asks.

## Tracked, additive

All minor-bump-shaped under the [ADR 0003](../adr/0003-v1-api-freeze.md) policy —
adding a symbol never breaks the freeze.

- **`tty_bg_256_buf`** — the 256-color background twin of `tty_fg_256_buf`.
  Deferred under the extract-on-2nd-consumer rule, the same discipline as
  v0.5.1's bg/fg split. kii carries a local `_emit_bg_256_buf`
  (`kii/src/emit.cyr`) as consumer #1, and its own comment names the lift
  trigger: *"once a second consumer in the AGNOS surface needs it, lift to
  darshana."* Lift when that second consumer appears.
- **Anything a consumer asks for.** The house rule (CLAUDE.md) is that
  consumers drive the API — darshana does not anticipate. The extraction of
  cyim's `tty.cyr` happened *because* chakshu became the second caller, and
  every addition since followed the same pattern. Post-1.0 growth works the
  same way, under semver.
