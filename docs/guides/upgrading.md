# Upgrading darshana

What a consumer bumping its darshana dep needs to know, release by release.
The short answer for every 1.x release so far: **no code change is
required.** The API has been frozen since v1.0.0
([ADR 0003](../adr/0003-v1-api-freeze.md)), so a patch or minor bump cannot
rename, re-arity or re-contract a public symbol, change a constant's value, or
change the bytes an emitter writes. What a release *can* change is packaging,
the recommended way to use the API, and what you no longer have to write
yourself. Those are the notes below.

Each note says what changed for you and what you can now drop. The full record
of every release is the [CHANGELOG](../../CHANGELOG.md).

## How to bump

Move the tag in your manifest and re-resolve:

```
[deps.darshana]
git     = "https://github.com/MacCracken/darshana.git"
tag     = "1.3.1"
modules = ["dist/darshana.cyr"]
```

```sh
cyrius deps
```

then rebuild and run your own suite. A consumer that resolves darshana by
`path` reads the working tree, not the tag, so it picks up the bundle as soon as
the tree changes; one that vendors `dist/darshana.cyr` by copy re-copies it.

## 1.3.1

**No code change, no behavior change, and no toolchain move required.** 1.3.1
moves darshana's own toolchain to cyrius 6.7.18 and its CI to Ubuntu 26.04. The
bundle's code is byte-identical to 1.3.0's (only its `# Version:` line moved), so
every byte it emits is unchanged, its stdlib requirements are still `syscalls`
and `io`, and its floor is still cyrius 6.7.2. It is built and tested on 6.7.18.

## 1.3.0

**Move your cyrius pin to 6.7.2 or later first.** The bundle now declares private
constants with `const`, which cyrius gained in 6.7.2. Under 6.7.1 and earlier, and
so under every 6.6.x pin, it fails to compile with `expected '=', got
identifier`. 1.3.0 is built and tested on 6.7.9. A consumer that resolves darshana
by `path` gets this on its next `cyrius deps`, not at its next bump.

Apart from the toolchain, **no code change**: the release only adds symbols, and
every byte darshana already emitted is unchanged.

What you can drop:

| If you hand-wrote | Use |
|---|---|
| `TCFLSH` / `TCIFLUSH` before a confirmation prompt | `tty_flush_input(fd)` |
| clearing ECHO for a password prompt | `tty_echo_off(fd)`. It clears ECHO and ECHONL, keeps line editing, and discards typeahead; restore with `tty_cooked()`. It takes the same slot as `tty_raw`: on the fd that holds it, either call switches modes, and one `tty_cooked()` restores the state from before the first. Print the newline yourself after reading the line |
| `ESC 7` / `ESC 8` | `tty_cursor_save()` / `tty_cursor_restore()` |
| `CSI top;bot r` and its reset | `tty_scroll_region(top, bot)` / `tty_scroll_region_reset()`. Both also home the cursor |
| `CSI ?1000h CSI ?1006h` and the reverse | `tty_mouse_enable()` / `tty_mouse_disable()` |
| `CSI ?2004h` / `CSI ?2004l` | `tty_paste_enable()` / `tty_paste_disable()` |
| an OSC 0 title, with or without your own scrubbing | `tty_title(s, len)` (up to 256 bytes) or `tty_title_buf`. The title is sanitized for you |
| OSC 52 with your own base64 | `tty_clipboard_set(src, len)` (any length, streamed) or `tty_clipboard_buf` |
| `CSI row;col H` or `CSI K` into a frame buffer | `tty_move_buf` / `tty_clear_to_eol_buf` |
| SGR background codes 40–47 / 100–107 as literals | `TTY_BG_*` |
| building `CSI a;b;c m` yourself | `tty_sgr_list_buf(buf, pos, codes, n)` or `tty_sgr_list(codes, n)`, with `codes` an i64 array of 1–16 codes |
| a "does this string contain controls" check | `tty_has_ctl(src, len, mode, keep)`, which answers 1 exactly when `tty_sanitize_buf` would change the input. `TTY_KEEP_TAB \| TTY_KEEP_LF` gives kii's rule |
| clearing darshana's `_tty_in_raw` after a hangup | `tty_forget()`, only after a `tty_cooked()` that returned -1 |

`TTY_SIGMASK_PIPE` routes SIGPIPE through a signalfd, so a write to a vanished
reader returns EPIPE instead of killing your process. Give it its own signalfd or
OR it into another; the three masks are disjoint.

On **AGNOS**, `tty_echo_off` and `tty_flush_input` return -1. The agnos console
echoes every key and cannot discard typeahead, so there is nothing for them to call.
A password typed at the agnos console is visible whatever your program does; both
gaps are filed with agnos. `TTY_SIGMASK_PIPE`'s signalfd never fires there, because
agnos has no SIGPIPE.

## 1.2.1

**No code change, and no behavior change.** darshana's own syscalls now go
through the stdlib's wrappers — `sys_write` for every escape emitter, and on
AGNOS `sys_winsize`, `sys_sigprocmask` and `sys_signalfd` — and every byte it
emits is unchanged. The bundle's stdlib requirements (`syscalls`, `io`) are
unchanged too.

## 1.2.0

**No code change.** Additive only, and every byte darshana already emitted is
unchanged (its identity digests are identical to 1.1.4's).

What you can drop:

| If you hand-wrote | Use |
|---|---|
| a control-byte scrubber for untrusted text | `tty_sanitize_buf(buf, pos, src, len, mode, keep)` — choose `TTY_SANITIZE_UTF8` or `TTY_SANITIZE_LATIN1` by the terminal you write to; `TTY_KEEP_TAB` / `TTY_KEEP_LF` keep those bytes; ESC is never kept ([ADR 0004](../adr/0004-output-sanitization.md)) |
| a read of the 128-byte `signalfd_siginfo` | `tty_read_signal(fd)` — the signal number, **0** when nothing is pending on a non-blocking fd, -1 on error |
| a guard against a 0 × 0 window size | `tty_winsize_or(fd, &rows, &cols, def_rows, def_cols)` — always returns 0; the defaults are yours |
| a VMIN / VTIME patch after `tty_raw` | `tty_raw_nonblock(fd)` — same raw slot, same `tty_cooked()` restore; on the fd that holds the slot, `tty_raw` and `tty_raw_nonblock` switch between each other |
| the 256-color background sequence | `tty_bg_256_buf` |
| SGR 1 / 2 / 4 / 7 as literals | `TTY_SGR_BOLD`, `TTY_SGR_DIM`, `TTY_SGR_UNDERLINE`, `TTY_SGR_REVERSE` |

A call to the private `_tty_apply_raw_flags` still works, but it is not frozen
and `tty_raw_nonblock` is the supported route to the same mode.

On **AGNOS**, two things you might otherwise discover the hard way:

- **A `TTY_SIGMASK_WINCH` signalfd never fires.** The agnos kernel does not
  raise SIGWINCH, though a live modeset can change the console grid. Poll
  `tty_winsize` (or `tty_winsize_or`) instead. Filed with agnos.
- **Under mirshi, a darshana signalfd receives nothing.** mirshi delivers only
  unblocked signals through a signalfd, and the fd blocks the signals it
  watches. The same binary on the agnos kernel is unaffected. Filed with mirshi.

## 1.1.4

**No code change**, but the recommended teardown changed. If your exit path
follows the old order, reorder it to
[ADR 0002](../adr/0002-state-restore-posture.md)'s amended sequence:

1. `tty_cooked()` — **first**;
2. `tty_cursor_show()`;
3. `tty_alt_leave()`;
4. `tty_sgr_reset()`, if you set colors;
5. `tty_close_signalfd(fd, mask)` — **last**, if you opened a signalfd.

`tty_cooked()` moved to the front because steps 2–4 are writes to fd 1, and
when fd 1 is a pipe whose reader has gone (`prog | head -c 1`) the first of them
raises SIGPIPE and kills the process — in the old order, with the terminal
still raw. `tty_close_signalfd` goes last because its unblock delivers any
signal that arrived but was never read, with that signal's default action.

Two hazards 1.1.4 wrote down are not new — they hold for every earlier
release too:

- **Signalfds that are open at the same time need disjoint masks.** Closing one
  unblocks its mask, and so silences any other fd watching the same signal.
- **A child spawned while a signalfd is open inherits its signal block**, across
  `fork` and `execve`. Close the signalfd, or unblock in the child, before you
  exec something that expects those signals.

And one fix:

- **An fd outside [0, 0x7FFFFFFF] is now rejected** with -1. The kernel reads
  an fd as 32 bits, so such a number used to alias a real descriptor —
  `tty_close_signalfd(fd + 2^32, …)` closed `fd`.

## 1.1.3

**No code change**, and no `src/` line changed. Packaging only:

- **`dist/darshana.deps` lists two stdlib leaves, `syscalls` and `io`**, down
  from six. The four that left (`alloc`, `assert`, `vec`, `args`) were
  darshana's own build footprint, not the bundle's. If your build was relying
  on darshana's sidecar to supply one of them, declare it in your own
  `[deps].stdlib`.
- **`dist/darshana.cyr` starts with a `# Requires` block** that includes
  `lib/syscalls.cyr` and `lib/io.cyr`, so the bundle compiles with no other
  stdlib include. Includes are once-only by literal path, so a consumer that
  already includes them pays nothing.
- The bundle still builds under a cyrius **6.6.2** pin.

## 1.1.0 – 1.1.2

**No code change, and no behavior change.** 1.1.0 is an internal refactor with
byte-identical output; 1.1.1 added the `args` leaf to the sidecar (removed again
in 1.1.3, above); 1.1.2 is documentation and the cyrius 6.6.2 toolchain bump.

## 1.0.1 – 1.0.2

**No code change.** Two fixes in 1.0.2 make behavior match what was already
documented:

- **A failed `tty_open_signalfd` restores the signal mask it found.** Before,
  its rollback unblocked the whole requested mask — including signals an
  earlier, still-open signalfd had blocked, which silenced that fd.
- **`tty_close_signalfd` returns -1 on failure**, as documented, instead of a
  raw `-errno`.

1.0.1 added the `vec` leaf to the sidecar (removed again in 1.1.3).
