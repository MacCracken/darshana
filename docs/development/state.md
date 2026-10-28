# darshana — Current State

> **A snapshot of where the project is.** Refreshed every release, and replaced
> rather than appended to. What changed and when → [`CHANGELOG.md`](../../CHANGELOG.md).
> Rules and process → [`CLAUDE.md`](../../CLAUDE.md). What is left →
> [`roadmap.md`](roadmap.md). Why → [`../adr/`](../adr/).

## Version

**1.3.0** (2026-10-12). Stable; the API has been frozen since v1.0.0
([ADR 0003](../adr/0003-v1-api-freeze.md)). 1.3.0 shipped the last of the
roadmap's candidates ([ADR 0005](../adr/0005-candidates-ahead-of-second-consumer.md)),
so nothing is queued. The only open item is a test that waits on mirshi.

## Toolchain

| | |
|---|---|
| Pin | cyrius **6.7.9** (`cyrius.cyml [package].cyrius`, the latest release; CI installs from it) |
| Bundle floor | cyrius **≥ 6.7.2**, because the bundle uses `const`. Measured: it fails under 6.6.20 and 6.7.1 and builds under 6.7.2 and 6.7.9 |
| `lib/` | 23 modules, about 744 KB, each byte-identical to the pinned snapshot. It is output: rebuild with `rm -rf lib/ && cyrius deps` |
| `cyrius.lock` | committed; `cyrius deps --verify` checks it. Not pruned when a leaf is removed (filed with cyrius) |
| aarch64 | `cyrius build --aarch64` / `cyrius test --aarch64` work on a stock install, which ships `cycc_aarch64`. Run under `qemu-aarch64`, or on real hardware with `ssh pi` (Raspberry Pi 4, Linux 7.0) |
| CI qemu | `ci.yml` installs `qemu-user` (since 1.3.0; not yet run on a GitHub runner) |

`cyrius build -v` names the compiler it resolved. The driver dispatches to the
**pinned** version's `cycc`, whatever `~/.cyrius/current` says.

## Surface

**54 public functions and 62 constants**, all frozen. ADR 0003 lists 29 + 37 from
v1.0 and 50 added since, each frozen from the release that added it. They are
listed in machine-readable form in `scripts/smoke.sh` (`required_syms` /
`required_flags`), checked against the bundle in both directions, and against
ADR 0003's tables.

| Module | Lines | Concern |
|---|---:|---|
| `src/termios.cyr` | 1,023 | the bundle's front matter: naming, the five return buckets, the module map. Termios modes — `tty_raw`, `tty_raw_nonblock`, `tty_echo_off` — sharing one save slot, plus `tty_cooked` / `tty_forget`; `tty_flush_input`; `tty_winsize` / `_or`; `tty_isatty`; the signalfd trio; `TIO_*` / `TTY_SIGMASK_*` |
| `src/ansi.cyr` | 708 | alt screen, clear, cursor visibility and save/restore, SGR (16 / 256 / truecolor; `TTY_FG_*` / `TTY_BG_*` / `TTY_SGR_*`; `tty_sgr_list`), mouse and paste modes, OSC title and clipboard |
| `src/cursor.cyr` | 182 | `tty_dec_buf`, `tty_move` / `_buf`, `tty_cursor_up` / `_down`, scroll region |
| `src/sanitize.cyr` | 179 | `tty_sanitize_buf`, `tty_has_ctl` (ADR 0004). Pure |
| `src/main.cyr` | 28 | in-tree entry that includes all four; not in the bundle |
| `dist/darshana.cyr` | 2,112 | the bundle: 2,092 module lines plus 20 that `distlib` adds (header, `# Requires`, separators) |
| `dist/darshana.deps` | 4 | sidecar: 2 stdlib leaves, `syscalls` and `io`, derived by `distlib`'s compile-verify |

**Platforms.** Linux on x86_64 and aarch64, and AGNOS. Every syscall-touching
function has a peer in each target gate, enforced by `scripts/platform-gate.sh`'s
peer rule. `src/` issues no raw `syscall(`: every kernel call is a stdlib wrapper,
and `src/`'s syscall allowlist is empty. What AGNOS cannot do today:

| Call | AGNOS answer | Why |
|---|---|---|
| `tty_raw`, `tty_raw_nonblock` | -1 | no termios; raw keyboard input is out of scope (roadmap) |
| `tty_echo_off`, `tty_flush_input` | -1 | the console always echoes and has no flush call (filed with agnos) |
| `tty_isatty(fd)` | about the console, not `fd` | no fd-kind query (filed with agnos) |
| `TTY_SIGMASK_WINCH` signalfd | never fires | the kernel never raises SIGWINCH (filed with agnos). Poll `tty_winsize` |
| `TTY_SIGMASK_PIPE` signalfd | never fires | agnos has no SIGPIPE |
| any signalfd under mirshi | receives nothing | mirshi defects (filed in mirshi's roadmap) |

## Tests

| Suite | Assertions | Covers | Run |
|---|---:|---|---|
| `tests/darshana.tcyr` | 382 | the pure surface, constant values, exact bytes, rejections, live-fd signalfd and winsize | `cyrius test` |
| `tests/pty.tcyr` | 127 | a real pseudo-terminal: every mode, restore byte-for-byte, mode switches, flush, hangup and `tty_forget`, fd aliasing, fd-1 escape capture | `cyrius test` |
| `tests/identity.tcyr` | 28 | every `_buf` composer over its whole domain inside guard regions, and **19 frozen digests** over everything darshana emits | `cyrius test` |
| `tests/agnos.tcyr` | 27 | the AGNOS arm's constants, decode and syscall-free peers | `cyrius build --agnos` then run it on the Linux host |

**564 on x86_64; 537 on aarch64** (the AGNOS suite is x86_64-hosted). All green
at 1.3.0 on x86_64, under `CYRIUS_DCE=1`, under qemu-aarch64 and on the Pi. The
totals are pinned in `scripts/ci.sh`.

A digest that moves means a frozen byte moved. The digests freeze:
- since v1.0.0: the RGB, 256, SGR, reset and dec composers; the fixed, SGR, RGB
  and move emitters; the relative moves;
- since 1.2.0: `tty_bg_256_buf`, `tty_sanitize_buf`;
- since 1.3.0: `tty_clear_to_eol_buf`, `tty_move_buf`, `tty_sgr_list_buf`,
  `tty_title_buf`, `tty_clipboard_buf`, and the 1.3.0 emitters.

## Gates

`bash scripts/ci.sh all` runs exactly what CI runs: 15 gates.
- toolchain, deps (`--verify`), smoke-binary, lint;
- unit, pty, identity, examples (the no-TTY path and the real TTY path under
  `script(1)`), agnos, aarch64;
- project-smoke, distlib-drift, dce, security, docs.

Each suite's total is pinned, a `SKIP` is fatal under CI, and any build warning is
fatal.

| Script | Enforces |
|---|---|
| `scripts/smoke.sh` | dist drift for both artifacts; the surface in both directions and against ADR 0003; stack-buffer budgets (21 buffers); docstrings (every public fn states its return, every `_buf` its byte budget, every constant is documented) |
| `scripts/syscall-audit.sh` | `src/` issues no raw syscall; called wrappers come from an allowlist of 8; no syscall number written as a literal anywhere — `syscall(1, …)` included — and no locally declared number outside an arch gate. Has `--self-test` |
| `scripts/platform-gate.sh` | Linux ioctl tokens only inside the Linux gate, agnos-only wrappers only inside the AGNOS gate (positional, corpus-wide); every platform peer has one definition per gate and none outside (the peer rule). Has `--self-test` |

## Dependencies

darshana's own footprint is `[deps].stdlib = ["syscalls", "alloc", "io",
"assert"]` (`assert` is for the tests). Consumers resolve only the sidecar's two
leaves; the bundle's `# Requires` block includes them.

### Upstream gaps

Found while working on darshana; each belongs to its owner.

| Owner | Gap | Filed |
|---|---|---|
| mirshi | five signal-band defects: a signalfd never delivers a blocked signal; host signals bypass the agnos model; the `read#5` record; the slot leak on close; `sigprocmask` edges | mirshi `docs/development/roadmap.md` |
| agnos | the console grid changes without SIGWINCH | agnos `docs/development/issues/2026-10-12-console-grid-changes-without-sigwinch.md` |
| agnos | no ring-3 control of the console line discipline (echo-off, input flush) | agnos `…/2026-10-12-console-line-discipline-has-no-ring3-control.md` |
| agnos | no way to ask what an fd is | agnos `…/2026-10-12-no-way-to-ask-what-an-fd-is.md` |
| cyrius stdlib | agnos `sys_close` / `sys_read` / `sys_write` take a negative fd for socket slot `fd & 7`. darshana never passes a negative fd to close | cyrius `docs/development/issues/2026-10-12-agnos-negative-fd-taken-for-socket-slot-7.md` |
| cyrius stdlib | `sys_ioctl`'s comment says aarch64 has no 16 → 29 row | cyrius `…/2026-10-12-sys-ioctl-comment-says-aarch64-has-no-16-to-29-row.md` |
| cyrius CLI | `cyrius deps` keeps a removed leaf vendored and locked | cyrius `…/2026-10-12-deps-keeps-a-removed-stdlib-leaf-vendored-and-locked.md` |
| cyrius CLI | `cyrius lib sync --dry-run` prints pointers | cyrius `…/2026-10-08-cli-path-and-reporting-leftovers.md` |
| cyrius CLI | a dep's tag change leaves the old `commit` row in `cyrius.lock`, and `--locked` passes | cyrius `…/2026-10-12-deps-keeps-a-stale-commit-row-after-a-tag-change.md` |
| cyrius CLI | `distlib` records a named dep's transitive leaf (`boxed`) as the bundle's own | cyrius `…/2026-10-12-distlib-records-a-named-deps-transitive-leaf-as-the-bundles-own.md` |
| cyrius CLI | `cyrfmt --check` passes a file `cyrfmt` reformats | cyrius `…/2026-10-12-cyrfmt-check-passes-a-file-cyrfmt-would-reformat.md` |
| cyrius compiler | DCE keeps the callees of a redefined fn's losing body | cyrius `…/2026-10-12-dce-keeps-the-callees-of-a-redefined-fns-losing-body.md` |
| cyrius stdlib | `epoll_event_new` per arch, but no reader for the data offset | cyrius `…/2026-10-12-stdlib-epoll-event-has-a-writer-but-no-reader.md` |

## Consumers

Nine. Read from each consumer's manifest **and** the bundle it actually compiles.
Seven moved to darshana **1.3.0** on cyrius **6.7.9** in their own minor releases
on 2026-10-12, each resolving by git tag alone; kii's and anuenue's `path` deps on
this tree were dropped. thoth and jalwa have not moved yet.

| Consumer | Version | darshana | cyrius | Uses |
|---|---|---|---|---|
| [chakshu](https://github.com/MacCracken/chakshu) | 0.11.0 | 1.3.0 | 6.7.9 | raw/cooked, alt screen, clear, cursor, `tty_move`, `tty_winsize_or`, `tty_flush_input`; an EXIT\|PIPE and a WINCH signalfd read by `tty_read_signal`; `tty_sanitize_buf` on process names, cmdlines, logs and model output; `tty_sgr*` / `TTY_FG_*` / `TTY_SGR_*` |
| [anuenue](https://github.com/MacCracken/anuenue) | 1.4.0 | 1.3.0 | 6.7.9 | `tty_fg_rgb_buf` / `tty_fg_256_buf` / `tty_sgr_reset_buf` behind its own escape table (kept: re-measured faster in 256/16-color); an EXIT signalfd via `tty_open_signalfd` / `tty_read_signal` / `tty_close_signalfd`; `tty_isatty`; cursor up / hide / show |
| [cyim](https://github.com/MacCracken/cyim) | 1.11.0 | 1.3.0 | 6.7.9 | the donor: raw/cooked, alt screen, clear, `tty_move`, `tty_winsize`; a WINCH and a PIPE signalfd via `tty_read_signal`; `tty_fg_256_buf`, `tty_sgr*`; `tty_sanitize_buf` on paths, messages and picker rows (its buffer view keeps caret notation) |
| [kii](https://github.com/MacCracken/kii) | 1.6.0 | 1.3.0 | 6.7.9 | `tty_winsize`, `tty_fg_256_buf`, `tty_bg_256_buf`, `tty_sgr_reset_buf`; `tty_has_ctl` as its filename check |
| [bannermanor](https://github.com/MacCracken/bannermanor) | 1.2.0 | 1.3.0 | 6.7.9 | `tty_sgr` + `TTY_FG_*`; `tty_winsize` for the terminal width (the real AGNOS console grid since 1.2.0) |
| [darshini](https://github.com/MacCracken/darshini) | 1.4.0 | 1.3.0 | 6.7.9 | `tty_sgr_buf` / `tty_sgr_reset_buf` + `TTY_FG_*`; `tty_winsize` (Linux), `tty_isatty`; `tty_sanitize_buf` on every filename it echoes |
| [agora](https://github.com/MacCracken/agora) | 1.8.0 | 1.3.0 | 6.7.9 | `tty_sgr_buf` / `tty_sgr_reset_buf` + `TTY_FG_*`; `tty_sanitize_buf` on all user text it sends. Its shutdown signalfd is its own, not darshana's |
| [thoth](https://github.com/MacCracken/thoth) | — | 1.1.2 (copied) | 6.6.6 | the widest: modes, screen, cursor, winsize, isatty, signals; also the private `_tty_apply_raw_flags`. Needs cyrius ≥ 6.7.2 before taking 1.3.0 |
| [jalwa](https://github.com/MacCracken/jalwa) | — | 1.1.2 | 6.6.3 | raw/cooked, alt screen, clear, cursor, isatty. Needs cyrius ≥ 6.7.2 before taking 1.3.0 |

AGNOS sizing is not settled the same way everywhere, because agnos cannot say
what an fd is. bannermanor sizes banners to the AGNOS console even when stdout is
redirected (color stays off). darshini keeps width 0 and decoration off on AGNOS,
having watched icons and escapes land in a redirected file under mirshi.

## Known limits, true today

- **One termios save slot per process.** Modes switch on its fd; any other fd is
  refused until `tty_cooked()` or `tty_forget()` (architecture note 001).
- **The emitters do not check write(2).** A SIGPIPE on a vanished reader kills the
  process unless it is ignored or routed through `TTY_SIGMASK_PIPE`. The teardown
  order in ADR 0002 puts `tty_cooked()` first for that reason.
- **`tio_load32` / `tio_store32` bounds-check nothing**, deliberately (ADR 0003).
- **No capability negotiation.** darshana emits vt100/xterm sequences
  unconditionally (architecture note 002).
- **The AGNOS signalfd rollback has no test that can fail** (roadmap).

## Release process

1. `bash scripts/ci.sh all` — every gate, x86_64 and qemu-aarch64.
2. On the Pi: build `programs/smoke.cyr`, `tests/darshana.tcyr`, `tests/pty.tcyr`
   and `tests/identity.tcyr` with `cyrius build --aarch64`, `scp` them to the Pi,
   run them, and diff the identity digests against x86_64's.
3. Bump `VERSION`, add the matching `## [X.Y.Z]` CHANGELOG section (moving
   `[Unreleased]` into it), refresh this file, and run `cyrius distlib`.
4. Tag `X.Y.Z`. `.github/workflows/release.yml` gates on CI, verifies the version
   against the tag, regenerates dist and publishes the bundle, the package and
   `SHA256SUMS`.
