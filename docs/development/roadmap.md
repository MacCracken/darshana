# darshana — Roadmap

> **Forward-facing only.** What is left to do, in what order, against what
> gates. Nothing here describes work already shipped.
>
> - What shipped, and when → [`CHANGELOG.md`](../../CHANGELOG.md)
> - Where the code stands today → [`state.md`](state.md)
> - Why a given choice was made → [`../adr/`](../adr/)
>
> When an item closes, its entry is **deleted** from this file, not checked off
> in place. The history belongs in the CHANGELOG.

## Where things stand

**The API has been frozen since v1.0.0** — 29 functions and 37 constants,
enumerated in [ADR 0003](../adr/0003-v1-api-freeze.md) and machine-checked
bidirectionally on every CI run. Breaking one costs a major bump and its own
ADR; additive change stays minor.

The library is done in the sense that mattered: it owns its slice, five
consumers use it, and the surface has stopped moving. Every release since the
freeze has been maintenance — a hardening sweep, a byte-identical performance
pass, and platform verification. **Nothing about the shipped surface is
outstanding.** What follows is downstream work and consumer-driven growth.

Current version, counts and verification status live in [`state.md`](state.md);
this file does not restate them.

## Open now

Exactly one item, and it is **not** darshana work — it is downstream.

- [ ] **Bump the five consumers to a `1.x` dep.** Outstanding since the v1.0.0
      tag: chakshu (0.9.0), anuenue (0.9.0), cyim (0.8.2), kii (0.8.2),
      bannermanor (0.7.1). Until this lands, the frozen surface is one nobody is
      actually compiled against. bannermanor is furthest behind; **kii
      additionally has a pin mismatch** to reconcile (manifest `tag = "0.8.2"`
      while its vendored bundle reads 0.9.0, because it resolves via
      `path = "../darshana"`).

      **No consumer code change is required.** The frozen surface has not moved
      since v1.0.0, and v1.1.0's composer rewrite was proven byte-identical over
      the complete RGB cube on x86_64 and on real aarch64. The only thing a
      consumer sees differently is `dist/darshana.deps`, which has gained two
      stdlib leaves since the freeze — `vec` (v1.0.1) and `args` (v1.1.1) — so
      `cyrius deps` resolves two more modules.

      Two consumers have a reason to bump beyond staying current:
      - **anuenue** can delete its 1,530-entry / 48,960-byte pre-baked escape
        table, its build pass, and a cache-invalidation bug class. v1.1.0's
        composers are now *faster* than that cache — 34.8 ns/call against the
        39.3 ns measured for a faithful replica in the v1.0.2 audit.
      - **chakshu** holds an EXIT signalfd and a WINCH signalfd at the same
        time, which is exactly the shape v1.0.2's `tty_open_signalfd` rollback
        fix was written for: before it, a failed second open silently unblocked
        signals the first fd owned and disarmed chakshu's exit path.

## Next, by bucket

Nothing here is scheduled. These are the shapes a future release would take,
kept so a candidate lands in the right bucket instead of being argued about.

### 1.1.x — patch

**Nothing outstanding.** Every carry-forward the v1.0.x sweeps opened is closed:
the aarch64 arm is built *and executed* in CI, the arch-blind-syscall class that
bit three times is mechanically gated, and no target emits an
`undefined function` warning.

A patch is a fix that does not change a documented contract — including one that
makes behaviour *match* its existing documentation. Tests, gates, CI and docs are
patch-shaped by definition, since none of them ship.

### 1.x.0 — minor

Additive only. Adding a symbol never breaks the freeze.

- **`tty_bg_256_buf`** — the 256-color background twin of `tty_fg_256_buf`.
  Deferred under the extract-on-2nd-consumer rule, the same discipline as
  v0.5.1's bg/fg split. kii carries a local `_emit_bg_256_buf`
  (`kii/src/emit.cyr`) as consumer #1, and its own comment names the lift
  trigger: *"once a second consumer in the AGNOS surface needs it, lift to
  darshana."* **Lift when that second consumer appears — not before.**
- **Anything a consumer asks for.** The house rule (CLAUDE.md) is that consumers
  drive the API; darshana does not anticipate. The extraction of cyim's
  `tty.cyr` happened *because* chakshu became the second caller, and every
  addition since followed the same pattern.
- **A new platform peer.** Additive by ADR 0003. The AGNOS arm arrived this way
  across v0.8.0–v0.9.0.
- **An internal refactor with identical output.** v1.1.0 was one. The bar is
  proof, not argument: emitted bytes identical over the full input envelope, on
  every architecture the change could affect.

### 2.0.0 — major

**Not planned, and nothing is pushing toward it.** Listed because ADR 0003
knowingly froze two imperfections in, and a frozen imperfection that nobody
writes down gets rediscovered as a surprise:

- **`tio_load32` / `tio_store32` bounds-check nothing.** Deliberate — they are a
  codec over a caller-owned buffer — but a sharp edge a v2 might blunt.
- **The single-raw-fd model has no public reset.** A permanently failing
  `tty_cooked()` strands the slot for the process lifetime
  ([architecture note 001](../architecture/001-module-global-termios-state.md)).
  Adding `tty_forget()` was considered at v0.9.3 and rejected as speculative. If
  a consumer ever hits this for real, note that the *addition* is a *minor*, not
  a major — only changing the existing model would be breaking.

A major needs its own ADR stating what breaks and why the break beats carrying
the defect, plus a migration note for every consumer.

## Out of scope

Boundaries, not backlog. Each has been considered and declined; the reason is
recorded so it does not get re-litigated. Nothing here is blocked on a version —
these are charter decisions, and the freeze does not change them.

- **macOS / BSD termios support.** The donor was Linux-only and darshana
  follows. The BSD termios struct differs, so this is a real port, not a flag.
  Add when a real consumer needs it — not before (CLAUDE.md domain rules).
- **Windows console API.** Out of project scope for any AGNOS first-party tool.
  (`cyrius build --win` happens to succeed and is not gated on; the toolchain's
  generic syscall-routing advisory on that target is expected and ignored.)
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
