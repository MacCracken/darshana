# Examples

Runnable programs. Each builds from the project root and each is built
**and executed** by CI — twice since v1.1.4: once with stdin from
`/dev/null` (the no-TTY path), and once under `script(1)` with a real
pseudo-terminal and a `q` keypress, which drives the loop and the teardown
and requires the alt screen to be left and the terminal restored. Through
v1.1.3 only the no-TTY path ran, so an example could lose its
`tty_cooked()` and stay green.

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

- **Refuses a non-TTY — on both ends.** `tty_isatty(0)` AND
  `tty_isatty(1)` first, so running under a pipe or with output redirected
  prints one line and exits 0 instead of spraying escape bytes downstream.
  (Through v1.1.3 it checked stdin only, so `raw_loop > file` still got
  every escape.) That is also what makes it safe for CI to run.
- **Acquires in an unwindable order.** The signalfd is opened *before*
  `tty_raw`, so a failure there needs no terminal cleanup; if `tty_raw`
  then fails, only the signalfd has to be released. Nothing is half-owned.
- **Degrades instead of refusing to launch.** A failed
  `tty_open_signalfd` drops signal handling and keeps going — the posture
  the docstring prescribes. A failed open returns exactly -1 (since v0.9.3)
  and leaves no signal-mask residue (exactly so since v1.0.2), so that
  degrade is genuinely clean.
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
  ADR 0002's as amended in v1.1.4 — **cooked mode first**, then cursor
  show, alt-screen leave, SGR reset, and **close signalfd last** — and each
  call is idempotent, which is what makes it safe to reach from more than
  one place. Cooked mode first because every later step writes to fd 1,
  and a write to a pipe whose reader has gone raises SIGPIPE and kills the
  process; close last because its unblock delivers any signal that arrived
  unread. (Through v1.1.3 cooked mode was fourth.)

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
