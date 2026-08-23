# darshana — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

## v1.0 criteria

- [~] Public API frozen — every exported symbol named, documented, and tested (names + docstrings ✓ as of v0.4.1; tested ✓ as of v0.6.0 — pure-function surface in `tests/darshana.tcyr`, syscall-touching + escape-emitting surface in `tests/pty.tcyr`; contract docstrings re-audited at v0.9.3). The remaining `~` is the *freeze* itself, now gated on the three displaced doc/audit items in the v0.9.4 cut below — **not** on the calendar, which elapsed 2026-06-19.
- [x] Both initial consumers (cyim, chakshu) integrated and green — cyim 1.7.1 + chakshu 0.6.1 both live on darshana 0.4.1 since 2026-05-20
- [x] Test coverage adequate for the surface area (parsers + state-restore paths) — pure-function surface in `tests/darshana.tcyr`; live-TTY state-restore + escape-emission paths now covered in-repo by `tests/pty.tcyr` (v0.6.0). The signalfd live path remains consumer-covered (chakshu) plus the v0.5.0 skip-clean fd-0 probe.
- [x] CHANGELOG complete from v0.1.0 onward
- [x] Security posture documented — termios state-restore guarantees on every exit path (ADR 0002 landed v0.4.0)

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-09

- `cyrius init --lib darshana` scaffold landed
- README, CHANGELOG, CLAUDE.md, state.md, roadmap.md, ADR-0001 (name)
- Cyrius pinned 5.10.20 (matches chakshu)
- CI + release workflows
- No working API yet

### M1 — Donor port from cyim (v0.2.0) — ✅ shipped 2026-05-09

The cyim/src/tty.cyr migration. Verbatim functional port — same behavior, different repo, split by concern.

- [x] `src/termios.cyr` — TCGETS/TCSETS ioctl, raw-mode on/off, cooked-mode save/restore, signal-safe restore at exit
- [x] `src/ansi.cyr` — alt-screen enter/exit, clear, cursor hide/show
- [x] `src/cursor.cyr` — positioning (`tty_move(row, col)`), home, integer formatter for the position-encoding payload
- [x] `dist/darshana.cyr` — single re-export module produced by `cyrius distlib`; consumers `include "lib/darshana.cyr"` after `cyrius deps`
- [x] Unit tests against termios bit constants + ANSI escape byte sequences (no live TTY needed; the constants and escape strings are pure data)
- [x] CI green — lint, build, test, smoke
- [x] cyim's existing behavior must be reproducible — port is a no-op behaviorally

**Gate to M2**: every public symbol cyim's `src/tty.cyr` exposes today is available from `dist/darshana.cyr` with the same name and signature.

### M2 — Chakshu-driven extensions (v0.3.0) — ✅ shipped 2026-05-09

Surface chakshu needs that cyim doesn't currently exercise. Don't add anything chakshu hasn't asked for.

- [x] `tty_winsize(fd, &rows, &cols)` — TIOCGWINSZ ioctl, returns terminal dimensions. AGNOS peer over the kernel's `winsize`#60 added v0.8.0.
- [x] SIGWINCH delivery — shipped as `tty_open_signalfd(TTY_SIGMASK_WINCH)` + `tty_close_signalfd`, **not** the sigaction hook penciled in here. The handler-install shape was subsequently rejected outright ([ADR 0002](../adr/0002-state-restore-posture.md) §Alternatives): no `tty_install_winch_handler` will ever ship. *(This line was the source of a false README scope row, corrected in v0.9.3.)*
- [x] `tty_clear_to_eol()` / `tty_clear_to_eos()` — partial-clear ANSI helpers. Penciled here as `tty_clear_below`; shipped as `tty_clear_to_end` and renamed `tty_clear_to_eos` at v0.7.0.
- [~] Render-loop frame helpers (`tty_frame_begin()` / `tty_frame_end()`) — **deliberately skipped** under this item's own "otherwise skip — primitives, not framework" clause and CLAUDE.md's anti-framework domain rule. Not a gap; do not resurrect.
- [x] Tests: TIOCGWINSZ against the active TTY — live-fd probes in `tests/darshana.tcyr` (v0.5.0), then deterministically in `tests/pty.tcyr` (v0.6.0).

**Gate to M3**: chakshu's M2 TUI (full-screen, 1Hz refresh, key-driven) compiles + runs against darshana with no `darshana_TODO` calls.

### M3 — cyim integration (v0.4.0) — ✅ shipped 2026-05-20

cyim drops its private `src/tty.cyr` and depends on darshana. Touches a different repo (cyim) — opens as a PR for review.

- [x] cyim `cyrius.cyml` adds `[deps.darshana]` git+tag+modules entry pointing at v0.2.0+ — landed at cyim 1.7.0 (darshana 0.2.0); bumped to darshana 0.4.0 + cyrius 6.0.1 on 2026-05-20
- [x] `cyim/src/tty.cyr` deleted; references replaced with darshana symbols — reduced from ~207 lines to 38 (only cyim-specific `tty_probe` stays local)
- [x] cyim's existing test suite stays green (no behavior regression) — verified locally on the 0.4.0 + 6.0.1 manifest
- [x] cyim's M-level milestones in its own roadmap don't shift — confirmed; the bump is a forward-compat dep refresh, no cyim feature work

**Gate to M4**: cyim CI green on the darshana-dep branch. Satisfied — cyim 1.7.1 (2026-05-20) shipped on darshana 0.4.0 + cyrius 6.0.1.

### M4 — chakshu integration (v0.5.0) — ✅ shipped 2026-05-20

chakshu picks up darshana to power its M2 TUI. Touches chakshu repo.

- [x] chakshu `cyrius.cyml` adds `[deps.darshana]` — landed at chakshu 0.2.1 (M2 Slice A) on darshana 0.2.0; bumped to darshana 0.3.0 for M2 Slice D (SIGWINCH / dynamic resize); bumped to darshana 0.4.1 at chakshu 0.6.1 (M4 close ceremony)
- [x] chakshu M2 TUI work proceeds against the darshana surface — done at chakshu 0.5.0 (Full TUI: alt-screen, signalfd cleanup, 1Hz refresh, SIGWINCH re-layout, ↑↓ select, sort, filter, kill, --pid focus). M2.5 (mihi integration) shipped at chakshu 0.6.0 the following day.

**Gate to M5**: chakshu M2 closes (full-screen TUI, parity with htop) using darshana. Satisfied — chakshu 0.5.0 (2026-05-19) shipped the Full TUI exercising the full v0.3.0 darshana surface (`tty_raw/cooked`, alt-screen, `tty_winsize`, `tty_open_signalfd`, partial-clear helpers, cursor positioning).

### Soak-window cuts (v0.6.0 — v0.9.x)

The M5 gate "both consumers green for ≥30 days" is calendar-gated, not work-gated — both consumers shipped on 2026-05-20, so M5 cannot close before 2026-06-19. The intervening month is intentionally light, but two work items close the remaining v1.0 partials and lower the risk of a rushed pre-freeze audit. Skipped patch slots (v0.5.x, v0.7.x) stay open for fix-shaped cuts if regressions surface during the soak.

**Constraint for the soak cuts (v0.6.0 — v0.9.2)** — no breaking changes to the public surface (`tty_*`, `tio_*`, `TIO_*`, `TTY_*`). Forward-compat additions are allowed only if a consumer asks (per CLAUDE.md "consumers drive the API").

*Note on the old "pure-internal refactors that don't touch the dist bundle bytes are fine" clause: it was always vacuous — `dist/darshana.cyr` **is** the concatenated source text, so every `src/` edit changes its bytes. The operative constraint is behavioral, and the acceptance test is that the existing suite passes **unmodified**.*

**This constraint lapsed with the soak window.** v0.9.3 onward is explicitly pre-freeze: a breaking-but-correct fix is preferred to carrying a defect past the v1.0 freeze, where it would cost a major bump.

#### v0.6.0 — in-repo PTY harness (early soak)

Closes two v1.0 partials at once: "Public API frozen — every exported symbol named, documented, **and tested**" and "Test coverage adequate for the surface area (parsers + state-restore paths)." Lands early in the soak window so the harness itself gets burn-in.

- [x] Pseudo-terminal smoke under `tests/` — `tests/pty.tcyr` opens a PTY (`/dev/ptmx` → `TIOCSPTLCK` → `TIOCGPTN` → `/dev/pts/N`), drives `tty_raw` → writes `A\nB` to the slave → reads it on the master → `tty_cooked`, asserting both the byte-for-byte termios restore and the cooked-vs-raw output round-trip (OPOST/ONLCR). Shipped v0.6.0.
- [x] Exercises the symbols the v0.5.0 live-fd tests can't touch under `cyrius test`: `tty_raw`, `tty_cooked`, `tty_isatty`, `tty_winsize` (set/get), and — via `dup2` onto fd 1 — `tty_alt_enter/leave`, `tty_clear*`, `tty_cursor_hide/show/home`, `tty_move`, `tty_cursor_up/down`, `tty_sgr` valid-code emission, `tty_sgr_reset`. 38 assertions total.
- [x] CI integration — `tests/pty.tcyr` is auto-discovered by `cyrius test` (already a `build-and-test` step), so the gate is enforced on every push with no workflow change. Hang-proof (`O_NONBLOCK` master + bounded drains) and skip-clean in sandboxes that block `/dev/ptmx`.
- [x] State.md Tests row updated to reflect coverage of the previously consumer-only surface.

**Why early in soak**: the harness is the most net-new code shipping during soak. Better to let it run against the integrated stack for ~3 weeks than to land it the day before v1.0 cut.

#### v0.8.0 — v0.9.0 — AGNOS parity (took the late-soak slot)

Not planned here — these cuts displaced the doc/audit work that had been penciled into the v0.8.0 slot (re-slotted to v0.9.4 below). `#ifdef CYRIUS_TARGET_AGNOS` peers for every syscall-touching entry point, so consumers stay platform-blind.

- [x] v0.8.0 — `tty_winsize` over the agnos kernel's `winsize`#60 (requires agnos ≥ 1.45.13).
- [x] v0.8.2 — `tty_isatty` / `tty_raw` / `tty_cooked` peers.
- [x] v0.9.0 — `tty_open_signalfd` / `tty_close_signalfd` peers + agnos-specific `TTY_SIGMASK_*` bit layout.

#### v0.9.3 — P-1 audit / hardening sweep — ✅ shipped

Last code-shaped cut before the freeze. Two breaking-but-correct fixes taken deliberately pre-freeze, per the lapsed-constraint note above.

- [x] `tty_open_signalfd` rolls its `SIG_BLOCK` back when `signalfd(2)` fails, and returns exactly -1 instead of a raw `-errno` (both peers). Through v0.9.2 a failed open returned e.g. -24/EMFILE **and** left the signals blocked for the process lifetime, with no fd for the caller to hand `tty_close_signalfd`.
- [x] `_buf` composers reject a negative incoming `pos` — a -1 from an earlier link now poisons the chain instead of writing below the caller's buffer. **Breaking**: `tty_sgr_reset_buf` and `tty_dec_buf` gain a -1 return.
- [x] Contract-doc repair on the freeze surface: `main.cyr` return conventions, `tty_winsize`'s caller-pointer scope, per-composer byte budgets, `tty_close_signalfd` unblock-vs-restore, `tty_cooked`'s stranded-slot note.
- [x] Duplication pass — three copies of the decimal emitter → one; fg/bg RGB → one parameterized body; `tty_cursor_up/down` → one. Emitted bytes verified identical across the full input envelope.
- [x] Smoke/CI hardening: reverse audit for constants, positional (not substring) platform-gate check, exec-sink pattern widened to raw syscall numbers. **Breaking (nominal)**: the four `AGNOS_*` constants became `_AGNOS_*`; zero consumer usage.

#### v0.9.4 — documentation + final API audit (pre-freeze)

Displaced from the v0.8.0 slot by the AGNOS parity work. These are the last substantive v1.0 blockers. Doc-shaped and lower-risk; lands directly before the freeze so the audit reflects the actual v1.0 surface, v0.9.3 hardening included.

- [ ] `docs/examples/` directory — at least one runnable example matching the ADR 0002 teardown shape (raw-enter, render loop, signalfd-driven exit, full restoration sequence). Named in CLAUDE.md as a doc path but still empty.
- [ ] Final API audit — walk every exported symbol (`fn tty_*`, `fn tio_*`, every `var TIO_*` / `var TIOC*` / `var TTY_*`), confirm the docstring is sufficient to consume without reading the function body, and confirm each `_buf` composer states its byte budget. v0.9.3 pre-cleared the known-false claims; this pass is the sweep for what it missed.
- [ ] `docs/architecture/` populated — currently only a `README.md` with an empty Items section. Candidate notes: "why module-globals for `_tty_saved`", "the syscall-vs-libc decision", "why `tty_close_signalfd` unblocks rather than restores", cross-referencing ADRs 0001/0002.
- [ ] CI syscall **allowlist** (deferred from v0.9.3) — invert the exec-sink denylist: extract every first argument of `syscall(` in `src/*.cyr` and fail on anything outside the set darshana is permitted to issue. The right shape for a library whose entire surface is raw syscalls; needs per-arch symbolic/numeric handling, which is why it is its own item rather than a sweep line.
- [ ] `cyrius lint` stays deferral-note clean — both untracked deferrals were cross-referenced at v0.9.3; keep it that way.

**Why last**: doc/audit work benefits from being applied to the *actual* v1.0 surface, after the hardening fixes have landed.

### M5 — v1.0 (v1.0.0)

- [x] Both consumers green, both green for ≥30 days — **satisfied 2026-06-19**. Five consumers are now live and green: chakshu 0.7.11, anuenue 1.2.0, cyim 1.8.1, kii 1.4.1, bannermanor 1.1.2 (see [`state.md`](state.md) §Consumers).
- [ ] The v0.9.4 doc/audit cut lands (`docs/examples/`, per-symbol API audit, `docs/architecture/` notes, CI syscall allowlist) — **the real remaining blocker**.
- [ ] Public API frozen — no breaking changes after this point without a major bump
- [x] Security review documented (termios state-restore on every exit path) — ADR 0002 landed at v0.4.0
- [ ] Promote to AGNOS shared-crates registry as v1.0+ stable

## Out of scope (for v1.0)

- **macOS / BSD termios support.** cyim's tty.cyr is Linux-only; darshana follows. Add when a real consumer needs it (not before).
- **Windows console API.** Out of project scope for any AGNOS first-party tool.
- **Widget toolkit / form controls / render loops.** Belongs in consumers. darshana is primitives.
- **A color-management layer.** The SGR primitives shipped v0.3.5–v0.5.3 as consumers asked: 16-color (`TTY_FG_*` + `tty_sgr`), 256-color (`tty_fg_256_buf`), and truecolor (`tty_fg_rgb` / `tty_bg_rgb` + `_buf` twins). What stays out of scope is anything *above* raw SGR emission — palette abstraction, nearest-color quantization, theme/colorscheme management — a consumer (or sibling-lib) concern.
- **Mouse / bracketed paste.** Out of scope until cyim or chakshu asks.
- **`tty_bg_256_buf` (256-color background twin).** Deferred under the extract-on-2nd-consumer rule, the same discipline as v0.5.1's bg/fg split. kii carries a local `_emit_bg_256_buf` (`kii/src/emit.cyr`) as consumer #1, and its own comment names the lift trigger: "once a second consumer in the AGNOS surface needs it, lift to darshana." Purely additive, so post-v1.0 is fine. *(Bubbled up from a source-only deferral in `src/ansi.cyr` at v0.9.3.)*
