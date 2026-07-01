# darshana

> **दर्शन** — *viewing / showing / sight.* Shared TTY/raw-mode primitives for AGNOS first-party tools.

`darshana` owns the small slice of terminal control that any tool taking over the screen needs — termios raw mode (TCGETS/TCSETS via ioctl), ANSI escape helpers, cursor positioning, alt-screen enter/exit. The Sanskrit name **दर्शन** *darśana* means *viewing / showing / sight* and belongs to the same observational family as [chakshu](https://github.com/MacCracken/chakshu) (चक्षु — *the eye*) and the planned `drishti-*` codecs (दृष्टि — *vision*).

## What it is

The library that came out of cyim's private `src/tty.cyr` once a second consumer (chakshu) needed the same machinery. **It is not a TUI framework** — no widgets, no render loop, no event dispatch. Those belong in the consumer. darshana is the layer below: the syscalls and escape sequences that make raw-mode terminal I/O work.

Donor: [`cyim/src/tty.cyr`](https://github.com/MacCracken/cyim) (~207 lines, Linux-only). Adjacent prior art: [`cyrius-doom/src/input.cyr`](https://github.com/MacCracken/cyrius-doom).

## Status

**v0.8.1 — pre-1.0 hardening.** The donor port and the chakshu/anuenue-driven extensions have landed; the surface is in its v1.0 pre-freeze hardening window (see [`docs/development/roadmap.md`](docs/development/roadmap.md)). The TTY surface works on Linux and, as of v0.8.0, on AGNOS — `tty_winsize` has a `#ifdef CYRIUS_TARGET_AGNOS` branch over the kernel's `winsize`#60 syscall (requires agnos ≥ 1.45.13), so consumers size to the real console on both targets.

Consume it via `cyrius deps` against the `dist/darshana.cyr` bundle — no need to copy `cyim/src/tty.cyr` anymore.

## Build

```sh
cyrius deps                                          # resolve stdlib
cyrius build programs/smoke.cyr build/darshana-smoke # compile-link smoke
cyrius distlib                                       # produce dist/darshana.cyr
cyrius test                                          # run tests/*.tcyr
```

## Consumers

- [cyim](https://github.com/MacCracken/cyim) — vim-like editor (the donor; extracted its `src/tty.cyr` into here)
- [chakshu](https://github.com/MacCracken/chakshu) — AI-augmented system monitor (drove the M2 TUI extensions)
- [anuenue](https://github.com/MacCracken/anuenue) — drove the truecolor / relative-cursor / color-mode helpers
- [bannermanor](https://github.com/MacCracken/bannermanor) — figlet-equivalent banner generator (drove the SGR color helpers)
- [kii](https://github.com/MacCracken/kii) — image → ANSI/ASCII converter (consumes `tty_winsize` to size art to the real console)

## Scope

| In | Out |
|----|-----|
| Linux termios raw/cooked mode (TCGETS/TCSETS ioctl) | macOS BSD termios layout (deferred until a consumer asks) |
| ANSI escape helpers (alt-screen, clear, cursor) | Widget toolkit / form controls |
| Cursor positioning + visibility | Render loop + frame scheduling |
| Window-size query (`TIOCGWINSZ` on Linux, `winsize`#60 on AGNOS) | Event/input dispatch system |
| `SIGWINCH` install + handler hook | Tab/window/pane management |

Render loops, widgets, and event loops belong in the consumer. darshana is the primitive layer.

## License

GPL-3.0-only.
