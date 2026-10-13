# Getting started with darshana

## Build

```sh
cyrius deps                                            # resolve the stdlib footprint
cyrius build programs/smoke.cyr build/darshana-smoke       # compile-link smoke
cyrius distlib                                         # produce dist/darshana.cyr + .deps
cyrius test tests/darshana.tcyr tests/pty.tcyr tests/identity.tcyr
bash scripts/ci.sh all                                 # every CI gate, as CI runs it
```

Name the suites: bare `cyrius test` also picks up `tests/agnos.tcyr`, which
only builds `--agnos`, and fails on it.

## Layout

- `src/termios.cyr` / `src/ansi.cyr` / `src/cursor.cyr` / `src/sanitize.cyr` — the four domain modules (`sanitize.cyr` since v1.2.0). These are `[lib].modules` in `cyrius.cyml`; they are exactly what `cyrius distlib` concatenates into `dist/darshana.cyr`. **New public code goes in one of these.**
- `src/main.cyr` — in-tree convenience entry. Re-exports the four domain modules so the tests and `programs/smoke.cyr` pull the whole surface via one `include`. **Not part of the dist bundle** — a symbol added here compiles and tests green locally but ships to nobody.
- `programs/smoke.cyr` — minimal end-to-end smoke. CI builds this on every push.
- `tests/darshana.tcyr` — the pure-function surface. Use `assert_eq` / `assert` and exit with `assert_summary()`.
- `tests/pty.tcyr` — the PTY harness (v0.6.0). Manufactures its own pseudo-terminal to cover the syscall-touching and escape-emitting surface deterministically.
- `tests/identity.tcyr` — the emitted-byte identity and byte-budget suite (v1.1.4). Every `_buf` composer over its whole input domain into a poisoned guard region, and eleven frozen digests over everything darshana emits. **A change that moves a digest changes frozen bytes** — never "fix" it by pasting in the new value (see its header).
- `tests/agnos.tcyr` — the AGNOS arm (v1.0.2). **Not reachable by `cyrius test`**: build it with `cyrius build --agnos` and run the result. Read its header before adding to it — the AGNOS peers that issue agnos syscalls must not be *called* from a harness running on Linux, where agnos `winsize` (#60) is Linux `exit`.
- `scripts/ci.sh` — every CI gate, one implementation (v1.1.4): `.github/workflows/ci.yml` calls it step by step, and `bash scripts/ci.sh all` runs the same thing locally. It pins each suite's assertion total, so an assertion that silently stops running fails by name.
- `scripts/smoke.sh` — dist drift (both artifacts), the frozen-surface contract in both directions and against ADR 0003's tables, the stack-buffer budgets, the docstring audit, then delegates the platform gate. `scripts/platform-gate.sh` and `scripts/syscall-audit.sh` are separate so CI and local runs share one implementation; both carry a `--self-test` whose probes each check for their own failure message.
- `dist/darshana.cyr` — single-file bundle produced by `cyrius distlib`. Consumers `include` this from their own `cyrius.cyml [deps.darshana] modules = ["dist/darshana.cyr"]`.

## Adding a feature

1. Edit the domain module the change belongs to — `src/termios.cyr`, `src/ansi.cyr`, or `src/cursor.cyr`. A brand-new module must **also** be added to `[lib].modules` in `cyrius.cyml`, or it never reaches `dist/darshana.cyr` and no consumer can link against it. Do **not** add public code to `src/main.cyr`: it is excluded from the bundle, and every gate (tests, dist-drift, smoke) stays green while the symbol ships to nobody.
2. Add the new symbol to `required_syms` (functions) or `required_flags` (constants) in `scripts/smoke.sh` — that list is the authoritative API contract, and its reverse audit fails the build if dist exports a public name the list omits. Internal helpers take a `_` prefix instead.
3. Add a test case to `tests/darshana.tcyr` (pure surface) or `tests/pty.tcyr` (syscall / escape-emitting surface), and bump that suite's pinned total in `scripts/ci.sh` (`EXPECT_*`) in the same change.
4. `cyrius distlib` to regenerate **both** dist artifacts.
5. Run every gate, on every target:
   ```sh
   bash scripts/ci.sh all
   ```
   That includes the AGNOS cross-build and the aarch64 runs under qemu
   (`cyrius test --aarch64 tests/darshana.tcyr` also works on its own).
   x86_64 alone is not enough: the aarch64 run is what has caught every
   arch-blind syscall number this project has shipped.
6. If the change could touch emitted bytes at all, `tests/identity.tcyr` proves whether it did — ADR 0003 freezes them. A moved digest is a frozen-surface change, not a test to update.
7. Bump `VERSION` and add a CHANGELOG entry before tagging. `cyrius.cyml` needs no version edit — it reads `${file:VERSION}`.

See [`../adr/template.md`](../adr/template.md) when a non-trivial design choice deserves an ADR.
