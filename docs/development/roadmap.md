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

### Soak-window cuts (v0.6.0 — v0.8.0)

The M5 gate "both consumers green for ≥30 days" is calendar-gated, not work-gated — both consumers shipped on 2026-05-20, so M5 cannot close before 2026-06-19. The intervening month is intentionally light, but two work items close the remaining v1.0 partials and lower the risk of a rushed pre-freeze audit. Skipped patch slots (v0.5.x, v0.7.x) stay open for fix-shaped cuts if regressions surface during the soak.

**Constraint for both cuts** — no breaking changes to the public surface (`tty_*`, `tio_*`, `TIO_*`, `TTY_*`). Forward-compat additions are allowed only if a consumer asks (per CLAUDE.md "consumers drive the API"). Pure-internal refactors that don't touch the dist bundle bytes are fine.

#### v0.6.0 — in-repo PTY harness (early soak)

Closes two v1.0 partials at once: "Public API frozen — every exported symbol named, documented, **and tested**" and "Test coverage adequate for the surface area (parsers + state-restore paths)." Lands early in the soak window so the harness itself gets burn-in.

- [ ] Pseudo-terminal smoke under `tests/` or `scripts/` — opens a PTY, drives `tty_raw` → write known input → read echo'd bytes → `tty_cooked`, asserting the round-trip behaviour
- [ ] Exercises the symbols the v0.5.0 live-fd tests can't touch under `cyrius test`: `tty_raw`, `tty_cooked`, `tty_alt_enter/leave`, `tty_clear*`, `tty_cursor_*`, `tty_move`, `tty_sgr` valid-code emission
- [ ] CI integration — runs as part of `build-and-test` so the gate is enforced on every push, not just developer machines
- [ ] State.md Tests row updated to reflect coverage of the previously consumer-only surface

**Why early in soak**: the harness is the most net-new code shipping during soak. Better to let it run against the integrated stack for ~3 weeks than to land it the day before v1.0 cut.

#### v0.8.0 — documentation + final API audit (late soak)

Pre-freeze polish. Doc-shaped and lower-risk; lands close to v1.0 so the audit reflects the actual freeze surface (any v0.6.x patches included).

- [ ] `docs/examples/` directory — at least one runnable example matching the ADR 0002 teardown shape (raw-enter, render loop, signalfd-driven exit, full restoration sequence). `docs/examples/` is named in CLAUDE.md as a doc path but doesn't exist yet.
- [ ] Final API audit — walk every exported symbol (`fn tty_*`, `fn tio_*`, every `var TIO_*` / `var TTY_*`), confirm the docstring is sufficient to consume without reading the function body. Log any gaps in a single audit pass and patch them in the same cut.
- [ ] `docs/architecture/` populated — currently has only `README.md`; v1.0 freeze deserves one or two architecture notes (e.g., "why module-globals for `_tty_saved`", "the syscall-vs-libc decision," cross-referencing ADRs).

**Why late in soak**: doc/audit work benefits from being applied to the *actual* v1.0 surface, after any soak-revealed fixes have landed. Doing the audit pre-soak risks needing a re-audit after a 0.5.x patch.

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
