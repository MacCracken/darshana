# Examples

Runnable programs. Each builds from the project root and each is built
**and executed** by CI, so an example that stops compiling — or stops
working — fails the build rather than rotting in place.

| Example | What it shows |
|---------|---------------|
| [`raw_loop.cyr`](raw_loop.cyr) | The full [ADR 0002](../adr/0002-state-restore-posture.md) teardown shape: raw-mode enter, alt-screen, a signalfd-driven redraw loop, and complete restoration on every exit path. |

```sh
cyrius build docs/examples/raw_loop.cyr build/raw-loop
./build/raw-loop
```

## `raw_loop.cyr`

The example to copy from if you are taking over the screen. It covers the
sequence every full-screen consumer needs and the order those calls have
to happen in:

- **Refuses a non-TTY.** `tty_isatty(0)` first, so running under a pipe
  prints one line and exits 0 instead of spraying escape bytes downstream.
  That is also what makes it safe for CI to run.
- **Acquires in an unwindable order.** The signalfd is opened *before*
  `tty_raw`, so a failure there needs no terminal cleanup; if `tty_raw`
  then fails, only the signalfd has to be released. Nothing is half-owned.
- **Degrades instead of refusing to launch.** A failed
  `tty_open_signalfd` drops signal handling and keeps going — the posture
  the docstring prescribes. Since v0.9.3 a failed open leaves no
  signal-mask residue, so that degrade is genuinely clean.
- **Handles Ctrl-C twice over.** `tty_raw` clears `ISIG`, so Ctrl-C
  normally arrives as the byte `0x03` rather than as a signal. The loop
  reads that byte *and* watches the signalfd, because whether a given
  Ctrl-C becomes a byte or a signal depends on when the terminal entered
  raw mode.
- **Redraws on `SIGWINCH`.** Re-queries `tty_winsize` each frame and
  anchors a line to the bottom row, so resizing the window visibly
  re-lays-out.
- **Restores everything, once, from every path.** One `ex_teardown()`
  reached by normal quit, by a signal, and by a read error. The order is
  ADR 0002's — cursor show, alt-screen leave, SGR reset, cooked mode,
  close signalfd — and each call is idempotent, which is what makes it
  safe to reach from more than one place.

Verified under a real pseudo-terminal: after the example exits, the slave
termios is **byte-for-byte identical** to its pre-`tty_raw` state.

### What it deliberately does not do

darshana is a primitives library, not a TUI framework
([CLAUDE.md](../../CLAUDE.md) domain rules), so this example wires its own
loop rather than handing one to darshana. There is no `tty_guard(fp)`
wrapper and no library-installed signal handler — ADR 0002 rejected both.
The `poll(2)` here is just one readiness mechanism; a consumer already
running `epoll` wires the signalfd into that instead, and darshana does
not care which you pick.
