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

## Where v1.0 stands

**All five v1.0 criteria are met.** Consumers integrated and green, test
coverage adequate, CHANGELOG complete, security posture documented (ADR 0002),
and — as of v0.9.4 — every exported symbol named, documented, and tested, with
the per-symbol API audit returning zero gaps and now enforced by CI. The ≥30-day
consumer soak elapsed **2026-06-19**; five consumers are live.

**Nothing is blocking v1.0.0 but the decision to cut it.** What remains below is
the freeze itself and the registry promotion — both acts, not work items.

## v1.0.0 — the freeze

- [ ] **Bump the five consumers to a v0.9.4+ dep.** chakshu, anuenue, cyim, kii,
      and bannermanor all need a dep bump for the v0.9.3/v0.9.4 dist bytes. No
      consumer *code* change is required — the two v0.9.3 breaks were verified
      to affect zero live call sites — but shipping v1.0.0 while consumers sit
      on pre-audit bytes would make the freeze nominal. bannermanor is furthest
      behind (v0.7.1); kii additionally has a manifest/vendored pin mismatch to
      reconcile.
- [ ] **Freeze the public API.** After this tag, no breaking change without a
      major bump. Everything pre-v1.0 has been fair game — `tty_cooked` lost its
      fd parameter, `tty_itoa` became `tty_dec_buf`, `tty_clear_to_end` became
      `tty_clear_to_eos`, `tty_sgr_reset_buf` and `tty_dec_buf` gained a -1
      return, and four `AGNOS_*` constants were privatized. That latitude ends
      here. The v0.9.3 sweep and the v0.9.4 audit were the last chances to
      object to the surface; anything still objectionable must change **before**
      the tag, not after.
- [ ] **Promote to the AGNOS shared-crates registry as v1.0+ stable**
      (registry entry uses the name `darshana` — see
      [ADR 0001](../adr/0001-name-darshana.md)).

## Out of scope (for v1.0)

These are boundaries, not backlog. Each has been considered and declined; the
reason is recorded so it does not get re-litigated.

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

## Tracked for post-1.0

Purely additive, so none of these gate the freeze.

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
