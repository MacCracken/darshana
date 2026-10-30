# Architecture Decision Records

Decisions about darshana — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-name-darshana.md) | The library is named `darshana` (दर्शन — *viewing/showing*), not `drishya` or another observation-family alternative | Accepted |
| [0002](0002-state-restore-posture.md) | darshana provides the state-restore *primitives*; the consumer owns the teardown guarantee. No library-installed atexit, no signal handlers, no `tty_guard(fp)` wrapper | Accepted (amended v0.7.0) |
| [0003](0003-v1-api-freeze.md) | The v1.0 API freeze — the 29 functions and 37 constants it covers, what it explicitly does not cover, and the post-1.0 semver policy; plus the symbols added since, frozen from the release that added them | Accepted (amended 2026-10-30) |
| [0004](0004-output-sanitization.md) | Output sanitization is one `_buf` composer with a UTF-8 and a Latin-1 mode; ESC is never kept; every neutralized byte or sequence becomes one `?` | Accepted |
| [0005](0005-candidates-ahead-of-second-consumer.md) | 1.3.0 ships the seven roadmap candidates ahead of a second consumer (owner decision), each shaped on the code that hand-rolls it; the rule stands for everything after | Accepted |
| [0006](0006-sgr-scanner.md) | 1.4.0 adds `tty_sgr_len` / `tty_sgr_strip_buf`, reading SGR in text a program displays or measures: in charter on the output side, the second exception to the second-consumer rule (owner decision), anuenue's shape with five recorded differences | Accepted |
| [0007](0007-agnos-console-mode-and-fd-kind.md) | 1.5.0's AGNOS arms: `tty_isatty` per fd (console and a terminal emulator's channel), echo-off and flush on the console only, one probe per process with the 1.4.0 answers on older kernels, AGNOS builds on cyrius ≥ 6.7.11, and a live suite on a real agnos kernel | Accepted |
| [0008](0008-isatty-scope-probe.md) | 1.6.0 adds `tty_isatty_is_per_fd()`, a no-argument 1/0 predicate saying whether `tty_isatty` answers about the fd (always on Linux; on AGNOS from agnos 1.57.13): the third exception to the second-consumer rule (owner decision), for darshini | Accepted |
| [0009](0009-winsize-pixels.md) | 1.7.0 adds `tty_winsize_px`, the window's rows, columns and pixel size from one TIOCGWINSZ read, 0 where none is reported (always on AGNOS): the fourth exception to the second-consumer rule (owner decision), for kii's Sixel lane | Accepted |

_This index was empty through v0.9.4 while two ADRs sat on disk; keep it current when adding one._
