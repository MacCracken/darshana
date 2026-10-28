# darshana — Current State

> **A snapshot of where the project is.** Refreshed every release, and replaced
> rather than appended to. What changed and when → [`CHANGELOG.md`](../../CHANGELOG.md).
> Rules and process → [`CLAUDE.md`](../../CLAUDE.md). What is left →
> [`roadmap.md`](roadmap.md). Why → [`../adr/`](../adr/).

## Version

**1.5.0** (2026-10-28). Stable; the API has been frozen since v1.0.0
([ADR 0003](../adr/0003-v1-api-freeze.md)). 1.5.0 makes the AGNOS arms of
`tty_echo_off`, `tty_flush_input` and `tty_isatty` real on agnos 1.57.13 and
later ([ADR 0007](../adr/0007-agnos-console-mode-and-fd-kind.md)), and runs the
AGNOS arm on a real agnos kernel for the first time. 1.4.0 added the SGR scanner
and 1.3.1 moved to cyrius 6.7.18, both the same day. Nothing is queued; open: a
signalfd rollback test that waits on mirshi, which will be updated later, or on
a real-kernel way to make a signalfd fail.

## Toolchain

| | |
|---|---|
| Pin | cyrius **6.7.18** (`cyrius.cyml [package].cyrius`, the latest release; CI installs from it) |
| Bundle floor | Linux: cyrius **≥ 6.7.2**, because the bundle uses `const`. AGNOS: **≥ 6.7.11** since 1.5.0, for the stdlib's `sys_console_mode` / `sys_fd_kind` / `FDK_*` / `CM_*`. Measured for 1.5.0 with a consumer that includes the bundle: Linux fails under 6.7.1 and builds under 6.7.2, 6.7.10, 6.7.11 and 6.7.18; AGNOS fails under 6.7.10 (`undefined variable 'FDK_CONSOLE'`) and builds under 6.7.11 and 6.7.18 |
| `lib/` | 23 modules, 750,222 bytes, each byte-identical to the pinned snapshot. It is output: rebuild with `rm -rf lib/ && cyrius deps` |
| `cyrius.lock` | committed; `cyrius deps --verify` checks it. A vendored file outside the declared footprint is named by `cyrius deps` and kept (cyrius 6.7.12); `rm lib/<file> && cyrius deps` drops it and its lock row (6.7.13) |
| aarch64 | `cyrius build --aarch64` / `cyrius test --aarch64` work on a stock install, which ships `cycc_aarch64`. Run under `qemu-aarch64`, or on real hardware with `ssh pi` (Raspberry Pi 4, Linux 7.0) |
| CI runner | every job in `ci.yml` and `release.yml` runs on `ubuntu-26.04` (since 1.3.1), where `qemu-user` ships the static `qemu-aarch64`. Not yet run on a GitHub runner; 1.3.0's CI and release ran green on `ubuntu-latest` (24.04) |
| CI actions | `actions/checkout` v7.0.1, `actions/upload-artifact` v7.0.2, `actions/download-artifact` v8.0.2, `softprops/action-gh-release` v3.0.3, each pinned by commit SHA |

`cyrius build -v` names the compiler it resolved. The driver dispatches to the
**pinned** version's `cycc`, whatever `~/.cyrius/current` says.

## Surface

**56 public functions and 62 constants**, all frozen. ADR 0003 lists 29 + 37 from
v1.0 and 52 added since, each frozen from the release that added it. They are
listed in machine-readable form in `scripts/smoke.sh` (`required_syms` /
`required_flags`), checked against the bundle in both directions, and against
ADR 0003's tables.

| Module | Lines | Concern |
|---|---:|---|
| `src/termios.cyr` | 1,126 | the bundle's front matter: naming, the five return buckets, the module map. Termios modes — `tty_raw`, `tty_raw_nonblock`, `tty_echo_off` — sharing one save slot, plus `tty_cooked` / `tty_forget`; `tty_flush_input`; `tty_winsize` / `_or`; `tty_isatty`; the signalfd trio; `TIO_*` / `TTY_SIGMASK_*` |
| `src/ansi.cyr` | 811 | alt screen, clear, cursor visibility and save/restore, SGR (16 / 256 / truecolor; `TTY_FG_*` / `TTY_BG_*` / `TTY_SGR_*`; `tty_sgr_list`), mouse and paste modes, OSC title and clipboard; reading SGR in text, `tty_sgr_len` / `tty_sgr_strip_buf` (ADR 0006). The scanner is pure |
| `src/cursor.cyr` | 182 | `tty_dec_buf`, `tty_move` / `_buf`, `tty_cursor_up` / `_down`, scroll region |
| `src/sanitize.cyr` | 179 | `tty_sanitize_buf`, `tty_has_ctl` (ADR 0004). Pure |
| `src/main.cyr` | 28 | in-tree entry that includes all four; not in the bundle |
| `dist/darshana.cyr` | 2,318 | the bundle: 2,298 module lines plus 20 that `distlib` adds (header, `# Requires`, separators) |
| `dist/darshana.deps` | 4 | sidecar: 2 stdlib leaves, `syscalls` and `io`, derived by `distlib`'s compile-verify |

**Platforms.** Linux on x86_64 and aarch64, and AGNOS. Every syscall-touching
function has a peer in each target gate, enforced by `scripts/platform-gate.sh`'s
peer rule. `src/` issues no raw `syscall(`: every kernel call is a stdlib wrapper,
and `src/`'s syscall allowlist is empty. On AGNOS, since 1.5.0 (ADR 0007), on
agnos 1.57.13 and later:

| Call | AGNOS answer | Notes |
|---|---|---|
| `tty_isatty(fd)` | about `fd`: 1 for the console and a terminal emulator's `#97` channel, 0 otherwise | fd_kind#111. Before 1.57.13, and under mirshi 1.11.3: about the console, as through 1.4.0 |
| `tty_echo_off`, `tty_flush_input` | 0 on the console | console_mode#110 (`CM_NOECHO \| CM_FLUSH`, `CM_FLUSH`). -1 on a channel (the emulator runs its own echo), on anything else, before 1.57.13 and under mirshi 1.11.3 |
| `tty_cooked`, `tty_forget` | 0 | restore the console's echo state from before / free the slot with no call |
| `tty_raw`, `tty_raw_nonblock` | -1 | no termios; raw keyboard input is out of scope (roadmap) |
| `TTY_SIGMASK_WINCH` signalfd | not run by darshana | agnos 1.57.13 posts SIGWINCH to a bit-28 watcher on a grid change (agnos's tty-smoke T7). Under mirshi no signalfd receives anything |
| `TTY_SIGMASK_PIPE` signalfd | never fires | agnos has no SIGPIPE |

The arms ask once per process whether the kernel has the two calls
(`console_mode#110`'s query), and keep the answer. Under mirshi 1.11.3, which has
neither, that costs one `mirshi: ENOSYS agnos#110 -> -1` line on stderr.

## Tests

| Suite | Assertions | Covers | Run |
|---|---:|---|---|
| `tests/darshana.tcyr` | 441 | the pure surface, constant values, exact bytes, rejections, the SGR scanner's contract edges, live-fd signalfd and winsize | `cyrius test` |
| `tests/pty.tcyr` | 127 | a real pseudo-terminal: every mode, restore byte-for-byte, mode switches, flush, hangup and `tty_forget`, fd aliasing, fd-1 escape capture | `cyrius test` |
| `tests/identity.tcyr` | 33 | every `_buf` composer over its whole domain inside guard regions; the SGR scanner against independent references, chunked against whole; **20 frozen digests** | `cyrius test` |
| `tests/agnos.tcyr` | 44 | the AGNOS arm's constants, the stdlib values it relies on, the winsize decode, and every path that makes no syscall (out-of-range fds, the old-kernel answers, the slot) | `cyrius build --agnos` then run it on the Linux host |
| `tests/agnos_live.cyr` | 57 | the AGNOS arm on a real agnos kernel: `tty_isatty` per fd, echo-off and its slot, flush, a #97 channel endpoint, winsize, a signalfd reading a self-sent SIGINT | `bash scripts/agnos-live.sh` (QEMU; a release step, not CI) |

**645 on x86_64; 601 on aarch64** (the AGNOS suite is x86_64-hosted), plus 57
on agnos. All green at 1.5.0 on x86_64, under `CYRIUS_DCE=1`, under
qemu-aarch64, on the Pi, and on agnos 1.57.14 in QEMU. The
totals are pinned in `scripts/ci.sh`. Run with a sized terminal on stdin, the unit
suite adds two live-TTY winsize assertions (443); CI has no TTY and pins 441.

A digest that moves means a frozen byte moved. The digests freeze:
- since v1.0.0: the RGB, 256, SGR, reset and dec composers; the fixed, SGR, RGB
  and move emitters; the relative moves;
- since 1.2.0: `tty_bg_256_buf`, `tty_sanitize_buf`;
- since 1.3.0: `tty_clear_to_eol_buf`, `tty_move_buf`, `tty_sgr_list_buf`,
  `tty_title_buf`, `tty_clipboard_buf`, and the 1.3.0 emitters;
- since 1.4.0: `tty_sgr_len` / `tty_sgr_strip_buf`, over every answer and every
  whole strip of the identity suite's inputs.

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
| `scripts/syscall-audit.sh` | `src/` issues no raw syscall; called wrappers come from an allowlist of 10; no syscall number written as a literal anywhere — `syscall(1, …)` included — and no locally declared number outside an arch gate. Has `--self-test` |
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
| mirshi | 1.11.3 has no `console_mode#110` or `fd_kind#111`, so under mirshi the 1.5.0 arms keep their 1.4.0 answers. Not filed: the owner will update mirshi later | — |

Every other gap darshana filed is closed upstream; each record is in its owner's
`docs/development/issues/archived/`:
- **agnos 1.57.13** closed all three: a console grid change now raises SIGWINCH,
  `console_mode#110` gives ring 3 echo-off and an input flush, and `fd_kind#111`
  says what an fd is. darshana's AGNOS arms do not use them yet (roadmap).
- **cyrius 6.7.11 – 6.7.14** closed all nine: the agnos negative-fd socket alias
  (6.7.11); the `sys_ioctl` comment, the removed leaf `deps` kept, the
  `lib sync --dry-run` output, the stale `commit` lock row (now reported, by
  design still accepted), the `distlib` transitive leaf, `cyrfmt --check` (the
  2-or-4 continuation contract kept, `audit` now agrees), and the epoll event
  reader (6.7.12); the DCE losing-body callees (6.7.14).

## Consumers

Nine. Versions, pins and darshana tags read from each consumer's manifest (and
thoth's vendored bundle) on 2026-10-28; the "Uses" column was read from their
code on 2026-10-12. Seven resolve darshana **1.3.0** by git tag alone, on cyrius
6.7.9 to 6.7.12; none is on 1.3.1 or 1.4.0 yet. anuenue, whose proposal 1.4.0
shipped, still carries its own stand-in. thoth and jalwa have not moved past
1.1.2.

| Consumer | Version | darshana | cyrius | Uses |
|---|---|---|---|---|
| [chakshu](https://github.com/MacCracken/chakshu) | 0.11.0 | 1.3.0 | 6.7.9 | raw/cooked, alt screen, clear, cursor, `tty_move`, `tty_winsize_or`, `tty_flush_input`; an EXIT\|PIPE and a WINCH signalfd read by `tty_read_signal`; `tty_sanitize_buf` on process names, cmdlines, logs and model output; `tty_sgr*` / `TTY_FG_*` / `TTY_SGR_*` |
| [anuenue](https://github.com/MacCracken/anuenue) | 1.5.0 | 1.3.0 | 6.7.9 | `tty_fg_rgb_buf` / `tty_fg_256_buf` / `tty_sgr_reset_buf` behind its own escape table (kept: re-measured faster in 256/16-color); an EXIT signalfd via `tty_open_signalfd` / `tty_read_signal` / `tty_close_signalfd`; `tty_isatty`; cursor up / hide / show |
| [cyim](https://github.com/MacCracken/cyim) | 1.11.0 | 1.3.0 | 6.7.9 | the donor: raw/cooked, alt screen, clear, `tty_move`, `tty_winsize`; a WINCH and a PIPE signalfd via `tty_read_signal`; `tty_fg_256_buf`, `tty_sgr*`; `tty_sanitize_buf` on paths, messages and picker rows (its buffer view keeps caret notation) |
| [kii](https://github.com/MacCracken/kii) | 1.9.0 | 1.3.0 | 6.7.12 | `tty_winsize`, `tty_fg_256_buf`, `tty_bg_256_buf`, `tty_sgr_reset_buf`; `tty_has_ctl` as its filename check |
| [bannermanor](https://github.com/MacCracken/bannermanor) | 1.8.1 | 1.3.0 | 6.7.11 | `tty_sgr` + `TTY_FG_*`; `tty_winsize` for the terminal width (the real AGNOS console grid since 1.2.0) |
| [darshini](https://github.com/MacCracken/darshini) | 1.6.0 | 1.3.0 | 6.7.9 | `tty_sgr_buf` / `tty_sgr_reset_buf` + `TTY_FG_*`; `tty_winsize` (Linux), `tty_isatty`; `tty_sanitize_buf` on every filename it echoes |
| [agora](https://github.com/MacCracken/agora) | 1.12.1 | 1.3.0 | 6.7.9 | `tty_sgr_buf` / `tty_sgr_reset_buf` + `TTY_FG_*`; `tty_sanitize_buf` on all user text it sends. Its shutdown signalfd is its own, not darshana's |
| [thoth](https://github.com/MacCracken/thoth) | 0.52.8 | 1.1.2 (copied) | 6.6.6 | the widest: modes, screen, cursor, winsize, isatty, signals; also the private `_tty_apply_raw_flags`. Needs cyrius ≥ 6.7.2 before taking 1.3.0 |
| [jalwa](https://github.com/MacCracken/jalwa) | 1.4.5 | 1.1.2 | 6.6.3 | raw/cooked, alt screen, clear, cursor, isatty. Needs cyrius ≥ 6.7.2 before taking 1.3.0 |

AGNOS sizing was not settled the same way everywhere, because through 1.4.0
darshana's AGNOS `tty_isatty` could not say what an fd was (1.5.0 can, on agnos
1.57.13 and later). bannermanor sizes banners to the AGNOS console even when stdout is
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
   run them, and diff the identity digests against x86_64's. Run them in a
   terminal that has a size, such as `ssh -t pi`, or under `script(1)` after
   `stty rows 24 cols 80`. A 0×0 pty fails the unit suite's two live-TTY winsize
   assertions. Strip the pty's `\r` before diffing.
3. On agnos: `bash scripts/agnos-live.sh`, with sibling `../agnos` (kernel
   ≥ 1.57.13) and `../gnoboot` builds, or `AGNOS_KERNEL` / `GNOBOOT_EFI`. It
   boots the image in QEMU, about 16 s with KVM. Exit 2 is VOID: nothing was
   measured, so it is not a pass. It retries the OVMF boot menu that agnos's own
   harnesses also meet.
4. Bump `VERSION`, add the matching `## [X.Y.Z]` CHANGELOG section (moving
   `[Unreleased]` into it), refresh this file, and run `cyrius distlib`.
5. Tag `X.Y.Z`. `.github/workflows/release.yml` gates on CI, verifies the version
   against the tag, regenerates dist and publishes the bundle, the package and
   `SHA256SUMS`.
