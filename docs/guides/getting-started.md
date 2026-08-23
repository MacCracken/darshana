# Getting started with darshana

## Build

```sh
cyrius deps                                            # resolve sibling deps
cyrius build programs/smoke.cyr build/darshana-smoke       # compile-link smoke
cyrius distlib                                         # produce dist/darshana.cyr
cyrius test                                            # run tests/*.tcyr
```

## Layout

- `src/termios.cyr` / `src/ansi.cyr` / `src/cursor.cyr` — the three domain modules. These are `[lib].modules` in `cyrius.cyml`; they are exactly what `cyrius distlib` concatenates into `dist/darshana.cyr`. **New public code goes in one of these.**
- `src/main.cyr` — in-tree convenience entry. Re-exports the three domain modules so the tests and `programs/smoke.cyr` pull the whole surface via one `include`. **Not part of the dist bundle** — a symbol added here compiles and tests green locally but ships to nobody.
- `programs/smoke.cyr` — minimal end-to-end smoke. CI builds this on every push.
- `tests/darshana.tcyr` — the pure-function surface. Use `assert_eq` / `assert` and exit with `assert_summary()`.
- `tests/pty.tcyr` — the PTY harness (v0.6.0). Manufactures its own pseudo-terminal to cover the syscall-touching and escape-emitting surface deterministically. CI runs both files as separate steps.
- `dist/darshana.cyr` — single-file bundle produced by `cyrius distlib`. Consumers `include` this from their own `cyrius.cyml [deps.darshana] modules = ["dist/darshana.cyr"]`.

## Adding a feature

1. Edit the domain module the change belongs to — `src/termios.cyr`, `src/ansi.cyr`, or `src/cursor.cyr`. A brand-new module must **also** be added to `[lib].modules` in `cyrius.cyml`, or it never reaches `dist/darshana.cyr` and no consumer can link against it. Do **not** add public code to `src/main.cyr`: it is excluded from the bundle, and every gate (tests, dist-drift, smoke) stays green while the symbol ships to nobody.
2. Add the new symbol to `required_syms` (functions) or `required_flags` (constants) in `scripts/smoke.sh` — that list is the authoritative API contract, and its reverse audit fails the build if dist exports a public name the list omits. Internal helpers take a `_` prefix instead.
3. Add a test case to `tests/darshana.tcyr` (pure surface) or `tests/pty.tcyr` (syscall / escape-emitting surface).
4. Run `cyrius test tests/darshana.tcyr` and `cyrius test tests/pty.tcyr`.
5. `cyrius distlib` to regenerate the bundle, then `bash scripts/smoke.sh`.
6. Bump `VERSION` and add a CHANGELOG entry before tagging.

See [`../adr/template.md`](../adr/template.md) when a non-trivial design choice deserves an ADR.
