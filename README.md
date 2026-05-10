# darshana

> **दर्शन** — *viewing / showing / sight.* Shared Linux TTY/raw-mode primitives for AGNOS first-party tools.

`darshana` owns the small slice of terminal control that any tool taking over the screen needs — termios raw mode (TCGETS/TCSETS via ioctl), ANSI escape helpers, cursor positioning, alt-screen enter/exit. The Sanskrit name **दर्शन** *darśana* means *viewing / showing / sight* and belongs to the same observational family as [chakshu](https://github.com/MacCracken/chakshu) (चक्षु — *the eye*) and the planned `drishti-*` codecs (दृष्टि — *vision*).

## What it is

The library that came out of cyim's private `src/tty.cyr` once a second consumer (chakshu) needed the same machinery. **It is not a TUI framework** — no widgets, no render loop, no event dispatch. Those belong in the consumer. darshana is the layer below: the syscalls and escape sequences that make raw-mode terminal I/O work.

Donor: [`cyim/src/tty.cyr`](https://github.com/MacCracken/cyim) (~207 lines, Linux-only). Adjacent prior art: [`cyrius-doom/src/input.cyr`](https://github.com/MacCracken/cyrius-doom).

## Status

**v0.1.0 — scaffold.** Skeleton + design notes. No working code yet. The arc to v1.0 lives in [`docs/development/roadmap.md`](docs/development/roadmap.md).

If you want raw-mode TTY primitives in a Cyrius project today, copy `cyim/src/tty.cyr` directly — that's what darshana is going to vendor in M1.

## Build

```sh
cyrius deps                                          # resolve stdlib
cyrius build programs/smoke.cyr build/darshana-smoke # compile-link smoke
cyrius distlib                                       # produce dist/darshana.cyr
cyrius test                                          # run tests/*.tcyr
```

## Consumers

- [cyim](https://github.com/MacCracken/cyim) — vim-like editor (M3 — extracts its current `src/tty.cyr` into here)
- [chakshu](https://github.com/MacCracken/chakshu) — AI-augmented system monitor (M4 — picks up darshana for its M2 TUI)

## Scope

| In | Out |
|----|-----|
| Linux termios raw/cooked mode (TCGETS/TCSETS ioctl) | macOS BSD termios layout (deferred until a consumer asks) |
| ANSI escape helpers (alt-screen, clear, cursor) | Widget toolkit / form controls |
| Cursor positioning + visibility | Render loop + frame scheduling |
| `TIOCGWINSZ` window-size query | Event/input dispatch system |
| `SIGWINCH` install + handler hook | Tab/window/pane management |

Render loops, widgets, and event loops belong in the consumer. darshana is the primitive layer.

## License

GPL-3.0-only.
