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

Four of the five v1.0 criteria are met: consumers integrated and green, test
coverage adequate, CHANGELOG complete, security posture documented (ADR 0002).
The ≥30-day consumer soak elapsed **2026-06-19**; five consumers are live.

**One criterion is open — the API freeze itself**, and it is gated on the
v0.9.4 cut below, not on the calendar. Every exported symbol is named,
documented, and tested; what remains is the audit that lets us commit to those
names, and the docs a first-time consumer needs.

## v0.9.4 — pre-freeze documentation + audit cut

The last cut before the freeze, and **the only remaining v1.0 blocker**.
Doc- and audit-shaped, so it lands directly before v1.0.0 and reflects the
actual freeze surface.

- [ ] **`docs/examples/` — at least one runnable example.** The directory holds
      only a `.gitkeep`. Write the ADR 0002 teardown shape end to end:
      raw-enter, render loop, signalfd-driven exit, full restoration on every
      path. This is the artifact a first-time consumer copies from, and its
      absence is the biggest gap in the pre-freeze surface.
- [ ] **Final per-symbol API audit.** Walk every exported symbol — `fn tty_*`,
      `fn tio_*`, and every `var TIO_*` / `TIOC*` / `TTY_*` — and confirm the
      docstring is sufficient to consume the symbol without reading its body,
      and that each `_buf` composer states its byte budget. v0.9.3 cleared the
      claims already known to be false; this is the sweep for what that missed.
      Log gaps in one pass and patch them in the same cut.
- [ ] **`docs/architecture/` — populate the empty Items section.** Candidates:
      why `_tty_saved` is a module global rather than caller-owned; the
      syscall-vs-libc decision; why `tty_close_signalfd` unblocks rather than
      restores; the single-raw-fd model. Cross-reference ADRs 0001/0002.
- [ ] **CI syscall allowlist** *(deferred out of v0.9.3)*. Invert the exec-sink
      denylist in `.github/workflows/ci.yml`: extract the first argument of
      every `syscall(` in `src/*.cyr` and fail on anything outside the set
      darshana is permitted to issue. A denylist can only catch the sinks we
      thought of, and darshana's entire surface is raw syscalls. Needs per-arch
      symbolic-vs-numeric handling, which is why it is its own item rather than
      a one-line pattern widening.

**Gate to v1.0.0**: all four land, CI green, and `cyrius lint` reports zero
warnings **and zero untracked-deferral notes** across `src/`. Any new deferral
introduced by this cut must cross-reference a CHANGELOG or roadmap entry on the
same line — that is what keeps this file honest.

## v1.0.0 — the freeze

- [ ] **Freeze the public API.** After this tag, no breaking change without a
      major bump. Everything pre-v1.0 has been fair game — `tty_cooked` lost its
      fd parameter, `tty_itoa` became `tty_dec_buf`, `tty_clear_to_end` became
      `tty_clear_to_eos`, `tty_sgr_reset_buf` and `tty_dec_buf` gained a -1
      return. That latitude ends here, so anything the v0.9.4 audit finds
      objectionable must be changed **before** the tag, not after.
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
