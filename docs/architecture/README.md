# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Items

- [001 — Termios save-state is a module global, and there is exactly one slot](001-module-global-termios-state.md)
  — why `tty_cooked()` takes no fd, why a second `tty_raw` on a different fd is
  refused, what a permanently failing restore strands, and why the literal `60`
  appears in three places that must move together.
- [002 — Everything is a raw syscall, and what that costs](002-no-libc-raw-syscalls-only.md)
  — hardcoded kernel struct layouts, the arch-specific-syscall-number trap that
  actually bit us (aarch64 `SYS_IOCTL`), why the ANSI helpers are deliberately
  outside the Linux gate, and why write results go unchecked.

_Add a numbered entry (`NNN-kebab-case-title.md`) the next time the code has a
non-obvious invariant a reader can't derive. Never renumber. Do not write entries
for decisions — those are ADRs._
