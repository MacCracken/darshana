# darshana — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

## v1.0 criteria

- [ ] Public API frozen — every exported symbol named, documented, and tested
- [ ] Both initial consumers (cyim, chakshu) integrated and green
- [ ] Test coverage adequate for the surface area (parsers + state-restore paths)
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security posture documented — termios state-restore guarantees on every exit path (including SIGINT/SIGTERM/panic)

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

### M3 — cyim integration (v0.4.0)

cyim drops its private `src/tty.cyr` and depends on darshana. Touches a different repo (cyim) — opens as a PR for review.

- [ ] cyim `cyrius.cyml` adds `[deps.darshana]` git+tag+modules entry pointing at v0.2.0+
- [ ] `cyim/src/tty.cyr` deleted; references replaced with darshana symbols
- [ ] cyim's existing test suite stays green (no behavior regression)
- [ ] cyim's M-level milestones in its own roadmap don't shift — this is a refactor, not a feature

**Gate to M4**: cyim CI green on the darshana-dep branch.

### M4 — chakshu integration (v0.5.0)

chakshu picks up darshana to power its M2 TUI. Touches chakshu repo.

- [ ] chakshu `cyrius.cyml` adds `[deps.darshana]`
- [ ] chakshu M2 TUI work proceeds against the darshana surface — see chakshu's own roadmap M2

**Gate to M5**: chakshu M2 closes (full-screen TUI, parity with htop) using darshana.

### M5 — v1.0 (v1.0.0)

- [ ] Both consumers green, both green for ≥30 days
- [ ] Public API frozen — no breaking changes after this point without a major bump
- [ ] Security review documented (termios state-restore on every exit path)
- [ ] Promote to AGNOS shared-crates registry as v1.0+ stable

## Out of scope (for v1.0)

- **macOS / BSD termios support.** cyim's tty.cyr is Linux-only; darshana follows. Add when a real consumer needs it (not before).
- **Windows console API.** Out of project scope for any AGNOS first-party tool.
- **Widget toolkit / form controls / render loops.** Belongs in consumers. darshana is primitives.
- **256-color / truecolor ANSI helpers.** 16-color works; richer color is a consumer concern (or a sibling lib if a pattern emerges).
- **Mouse / bracketed paste.** Out of scope until cyim or chakshu asks.
