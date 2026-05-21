# darshana — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

## v1.0 criteria

- [~] Public API frozen — every exported symbol named, documented, and tested (names + docstrings ✓ as of v0.4.1; tested = pure-function surface covered, syscall-touching surface relies on consumer PTY smoke — see M5 carry-forward)
- [x] Both initial consumers (cyim, chakshu) integrated and green — cyim 1.7.1 + chakshu 0.6.1 both live on darshana 0.4.1 since 2026-05-20
- [~] Test coverage adequate for the surface area (parsers + state-restore paths) — 47/47 unit assertions on pure-function surface; live-TTY / signalfd paths not yet covered in-repo (M5 deferred-hardening item #5)
- [x] CHANGELOG complete from v0.1.0 onward
- [x] Security posture documented — termios state-restore guarantees on every exit path (ADR 0002 landed v0.4.0)

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-09

- `cyrius init --lib darshana` scaffold landed
- README, CHANGELOG, CLAUDE.md, state.md, roadmap.md, ADR-0001 (name)
- Cyrius pinned 5.10.20 (matches chakshu)
- CI + release workflows
- No working API yet

### M1 — Donor port from cyim (v0.2.0)

The cyim/src/tty.cyr migration. Verbatim functional port — same behavior, different repo, split by concern.

- [ ] `src/termios.cyr` — TCGETS/TCSETS ioctl, raw-mode on/off, cooked-mode save/restore, signal-safe restore at exit
- [ ] `src/ansi.cyr` — alt-screen enter/exit, clear, cursor hide/show
- [ ] `src/cursor.cyr` — positioning (`tty_move(row, col)`), home, integer formatter for the position-encoding payload
- [ ] `dist/darshana.cyr` — single re-export module produced by `cyrius distlib`; consumers `include "lib/darshana.cyr"` after `cyrius deps`
- [ ] Unit tests against termios bit constants + ANSI escape byte sequences (no live TTY needed; the constants and escape strings are pure data)
- [ ] CI green — lint, build, test, smoke
- [ ] cyim's existing behavior must be reproducible — port is a no-op behaviorally

**Gate to M2**: every public symbol cyim's `src/tty.cyr` exposes today is available from `dist/darshana.cyr` with the same name and signature.

### M2 — Chakshu-driven extensions (v0.3.0)

Surface chakshu needs that cyim doesn't currently exercise. Don't add anything chakshu hasn't asked for.

- [ ] `tty_winsize(fd, &rows, &cols)` — TIOCGWINSZ ioctl, returns terminal dimensions
- [ ] `tty_install_winch_handler(fp)` — sigaction install for SIGWINCH; caller's fp gets called from the signal handler with new (rows, cols)
- [ ] `tty_clear_to_eol()` / `tty_clear_below()` — partial-clear ANSI helpers (chakshu's render loop wants to repaint regions, not the whole screen, every tick)
- [ ] Render-loop frame helpers — `tty_frame_begin()` / `tty_frame_end()` thin wrappers if a clear pattern emerges (otherwise skip — primitives, not framework)
- [ ] Tests: TIOCGWINSZ against the active TTY (where one exists in CI)

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

### M5 — v1.0 (v1.0.0) — calendar-gated from 2026-05-20

- [ ] Both consumers green, both green for ≥30 days — both adopted (cyim 1.7.1 + chakshu 0.6.1 on darshana 0.4.1 since 2026-05-20); earliest viable cut ~2026-06-19
- [ ] Public API frozen — no breaking changes after this point without a major bump
- [x] Security review documented (termios state-restore on every exit path) — ADR 0002 landed at v0.4.0
- [ ] Promote to AGNOS shared-crates registry as v1.0+ stable

## Out of scope (for v1.0)

- **macOS / BSD termios support.** cyim's tty.cyr is Linux-only; darshana follows. Add when a real consumer needs it (not before).
- **Windows console API.** Out of project scope for any AGNOS first-party tool.
- **Widget toolkit / form controls / render loops.** Belongs in consumers. darshana is primitives.
- **256-color / truecolor ANSI helpers.** 16-color works; richer color is a consumer concern (or a sibling lib if a pattern emerges).
- **Mouse / bracketed paste.** Out of scope until cyim or chakshu asks.
