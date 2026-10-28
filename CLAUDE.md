# darshana — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**darshana** — Sanskrit **दर्शन** (*darśana*, "viewing / showing / sight"). Linux TTY/raw-mode primitives — termios on/off, ANSI escape helpers, cursor positioning, alt-screen control. Same observational family as `chakshu` (the eye) and the planned `drishti-*` codecs (vision).

- **Type**: Library
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md)
- **Donor**: cyim's private `src/tty.cyr` (~207 lines). darshana exists because chakshu became the second consumer needing the same primitives.

## Goal

Own the small, sharp slice of terminal control that any AGNOS first-party tool taking over the screen needs — termios, ANSI, cursor, alt-screen, SIGWINCH, and making untrusted bytes safe to put on the screen. **Not a TUI framework.** No widgets, no render loop, no event dispatch, no input decoding. Those belong in the consumer; darshana stays the primitive layer below them.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, surface area, in-flight work, consumers, dep gaps.
> Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init` (greenfield) or `cyrius port` (Rust → Cyrius migration). **Do not manually create project structure** — use the tools. If a tool is missing something, fix the tool.

## Quick Start

```sh
cyrius deps                                          # resolve the stdlib footprint
cyrius build programs/smoke.cyr build/darshana-smoke
cyrius test tests/darshana.tcyr                      # pure surface
cyrius test tests/pty.tcyr                           # real pseudo-terminal
cyrius test tests/identity.tcyr                      # emitted-byte digests + byte budgets
bash scripts/smoke.sh                                # dist drift + frozen surface + gates
bash scripts/ci.sh all                               # EVERY CI gate, exactly as CI runs it
```

`scripts/ci.sh` is the one implementation of every CI gate — `ci.yml` calls
it step by step — so "passes locally" and "passes in CI" are the same claim.
It pins each suite's assertion total (`EXPECT_*`): **adding or removing an
assertion means updating its pin in the same change.**

The AGNOS suite is **not** reachable by `cyrius test` — it is cross-target and
must be built for its target and then executed. aarch64 is reachable either
way (`cyrius test --aarch64` drives qemu itself as of cyrius 6.6.20):

```sh
cyrius build --agnos   tests/agnos.tcyr    build/agnos-tests && ./build/agnos-tests
cyrius test --aarch64  tests/darshana.tcyr
cyrius build --aarch64 tests/darshana.tcyr build/a64-unit    && qemu-aarch64 build/a64-unit
```

These emit x86_64-runnable or qemu-runnable ELFs, so they work on an ordinary
Linux host. CI runs all of them. See [`state.md`](docs/development/state.md)
§"Release Process" for the aarch64 recipe on a machine whose toolchain install
lacks `cycc_aarch64`.

## Key Principles

- **Correctness over cleverness** — if it's wrong, the bugs own you
- Test after every change, not after the feature is "done"
- ONE change at a time — never bundle unrelated changes
- Research before implementation — check vidya / existing patterns
- Build with `cyrius build`, not raw `cat file | cc5` — the manifest auto-resolves deps and prepends includes
- Source files only need project includes — stdlib / external deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N **bytes**, not N entries
- `&&` / `||` short-circuit; mixed expressions require explicit parens

## Rules (Hard Constraints)

- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API if needed
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection
- Do not trust external data (file / network / args) without validation
- **`lib/` is OUTPUT, not a curated directory.** Never hand-edit or hand-prune it. `[deps].stdlib` in `cyrius.cyml` is the only place the footprint is declared; `rm -rf lib/ && cyrius deps` rebuilds it (Phase 1 copies the declared leaves from the pinned snapshot, Phase 3's transitive BFS pulls their includes). `cyrius lib sync` refreshes what is already vendored and does **not** close the graph — its file list is not the footprint
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth
- **The public API is FROZEN as of v1.0.0.** Breaking any of the 29 functions or 37 constants enumerated in [ADR 0003](docs/adr/0003-v1-api-freeze.md) — name, arity, documented return contract, emitted bytes, or constant value — requires a **major** bump and its own ADR. Additive change (new symbols, new platform peers, internal refactors with identical output) stays a minor bump. `_`-prefixed symbols are not frozen. This replaces the pre-v1.0 posture under which breaking the surface was encouraged; that latitude is spent.
- **Documentation is never a release by itself.** Doc changes — README, guides, ADRs, `state.md`, the roadmap, and comments/docstrings in `src/` — ride whatever release comes next (patch, minor or major) and never set its level. Record them under `## [Unreleased]` in the CHANGELOG until that release is cut. The one exception is not really one: a docstring edit that changes a documented *contract* is the contract change, priced by ADR 0003 like any other.
- **A newer cyrius language feature in `src/` raises every consumer's toolchain floor**, because consumers compile the bundle under their own pin (and a `path` consumer compiles this tree). Before adopting one, measure the oldest toolchain the bundle still compiles under, and record it in `state.md`, the upgrade guide and each consumer's roadmap. 1.3.0's `const` made the floor 6.7.2.
- **Do not add a public symbol without adding it to `scripts/smoke.sh`** (`required_syms` / `required_flags`). The surface check is bidirectional — a public name in dist that the list omits fails CI. Internal helpers take a `_` prefix instead.
- **Do not add a syscall without adding it to `scripts/syscall-audit.sh`.** That rule is an allowlist, not a denylist: anything unlisted fails, whether or not it looks dangerous.
- **Never write a syscall number as a bare integer.** It is correct for exactly one architecture, and darshana targets Linux on x86_64 **and** aarch64 (ioctl 16 vs 29, exit 60 vs 93, openat 257 vs 56). Use the stdlib's arch-aware constant, or declare your own inside an explicit `#ifdef CYRIUS_ARCH_X86` / `CYRIUS_ARCH_AARCH64` gate. There is no literal exception — `write(2)` is the stdlib's `sys_write`, not `syscall(1, ...)` (write is 64 on aarch64). This class has bitten three times and is mechanically gated by `scripts/syscall-audit.sh` across `src/`, `tests/`, `programs/` and `docs/examples/` — both halves: no literal at a call site, and no locally-declared syscall constant outside an arch (or AGNOS-target) gate. (Through v1.1.3 that gate scanned no `*.tcyr` file and checked only call-site literals, so it caught neither the v0.9.2 shape nor the v1.1.0 one; v1.1.4 fixed both.) Prefer the stdlib's constant even over a per-arch declaration: the aarch64 backend rewrites some x86_64 numbers, which is why the stdlib uses private aliases such as `SYS_PPOLL`. The toolchain's "syscall not routed" diagnostic is Mach-O-only, so nothing else catches it.

## Domain rules (darshana-specific)

- **Don't grow into a TUI framework.** Widgets, render loops, event/input dispatch belong in the consumer. darshana is the primitive layer.
- **darshana is output, termios and signals — never input decoding** (owner ruling, 2026-10-12). No key-sequence decoder (arrows, modifiers, SS3, lone-Esc timing) and no AGNOS kbscan reader, though several consumers hand-roll both. Termios *settings* that affect input (e.g. VMIN/VTIME) are still in charter; parsing what the user typed is not. The reasons are in `roadmap.md` § Out of scope.
- **Output sanitization IS in charter** (owner ruling, 2026-10-12): neutralizing control bytes in untrusted text before it reaches the terminal is terminal safety, not formatting. It is still consumer-driven — its rule and shape were settled with the consumers that hand-rolled it ([ADR 0004](docs/adr/0004-output-sanitization.md)).
- **Reading SGR in text IS in charter** (owner ruling, 2026-10-28): `tty_sgr_len` / `tty_sgr_strip_buf` recognize colour codes in text a program is about to display or measure, the output side, like sanitization ([ADR 0006](docs/adr/0006-sgr-scanner.md)). The input ruling above is unchanged: nothing in darshana decodes keys or what a terminal sends back.
- **Linux + AGNOS; macOS/BSD is out of scope.** Every syscall-touching entry point has had an `#ifdef CYRIUS_TARGET_AGNOS` peer since v0.9.0, so consumers stay platform-blind across both. Termios layout differs on macOS (BSD) — add that arm only when a real consumer needs it. Gate platform-specific code via `#ifdef CYRIUS_TARGET_LINUX` / `#ifdef CYRIUS_TARGET_AGNOS`, and keep the tokens *inside* their gate. `scripts/platform-gate.sh` enforces this **positionally** (by line number, not substring presence) and **corpus-wide** (every `src/*.cyr`, not just `termios.cyr`); `scripts/smoke.sh` and the CI security job both call that one script, so their verdicts cannot drift.
- **No FFI / libc / ncurses.** Same sovereign-stack rule as chakshu / cyim. Every kernel call goes through a stdlib syscall wrapper — termios is `sys_ioctl(fd, TCGETS|TCSETS, &buf)`, ANSI is `sys_write(1, "\e[...", n)` — and `src/` issues no raw `syscall(` at all: its allowlist in `scripts/syscall-audit.sh` is empty, and a new call means a new entry on the wrapper allowlist. No `tcgetattr(3)`, no `tputs(3)`.
- **Consumers drive the API.** Don't add knobs cyim/chakshu haven't asked for. The whole point of extracting cyim's tty.cyr was that chakshu's needs would shape the seams — listen to those needs, don't anticipate hypothetical ones.

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos, including [`upgrading.md`](docs/guides/upgrading.md): what a consumer must know on each bump. A release with a consumer-visible change adds its note there
- [`docs/examples/`](docs/examples/) — Runnable examples
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — **Forward-facing only**: what is left to do, organized around the next release and the semver bump each item would cost (patch / minor / major), plus the out-of-scope charter boundaries. Closed items are deleted from it, not checked off — shipped work lives in the CHANGELOG, current state in `state.md`.

## Process

1. **Work phase** — features, roadmap items, bug fixes
2. **Build check** — `cyrius build`
3. **Test + benchmark additions** for new code
4. **Internal review** — performance, memory, correctness, edge cases
5. **Documentation** — update CHANGELOG, `docs/development/state.md`, any ADR the change earned
6. **Version sync** — bump `VERSION` and add the matching `## [X.Y.Z]` CHANGELOG header. `cyrius.cyml` needs no edit: it carries `version = "${file:VERSION}"`, and CI asserts that indirection is still in place rather than a literal
7. **Regenerate `dist/`** — `cyrius distlib` writes **both** `dist/darshana.cyr` and `dist/darshana.deps`; both are drift-gated

