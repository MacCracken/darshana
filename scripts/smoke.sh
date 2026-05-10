#!/usr/bin/env bash
# darshana smoke test — runs the compile-link smoke binary, verifies
# its single line of output, and re-asserts the dist artifact is in
# sync with the source modules. CI runs this in build-and-test;
# contributors should run it before commit.
#
# bash (not /bin/sh dash) is required: `<( ... )` process substitution
# is used for the dist drift check.

set -eu

BIN="${1:-build/darshana-smoke}"

if [ ! -x "$BIN" ]; then
    echo "smoke: $BIN not executable — run 'cyrius build programs/smoke.cyr build/darshana-smoke' first" >&2
    exit 1
fi

fail() { echo "smoke: FAIL — $1" >&2; exit 1; }
pass() { echo "  ok: $1"; }

# ============================================================
# Smoke binary — proves the include chain compiles end-to-end
# and `tty_*` symbols link from the three sub-modules.
# ============================================================
echo "[smoke] binary"

out=$("$BIN") || fail "$BIN exited non-zero"
test "$out" = "darshana smoke ok" || fail "smoke output mismatch: '$out'"
pass "smoke binary prints expected line, exit 0"

# ============================================================
# dist drift — dist/darshana.cyr must equal what `cyrius distlib`
# would produce right now. Without this, src/ changes ship to
# nobody (consumers `include "lib/darshana.cyr"` = the dist file).
# ============================================================
echo "[smoke] dist drift"

if [ ! -f dist/darshana.cyr ]; then
    fail "dist/darshana.cyr missing — run 'cyrius distlib'"
fi

# Snapshot what's checked in; regenerate; diff.
TMPSNAP="${TMPDIR:-/tmp}/darshana-dist-snap-$$.cyr"
trap 'rm -f "$TMPSNAP"' EXIT INT TERM
cp dist/darshana.cyr "$TMPSNAP"
cyrius distlib > /dev/null
if ! diff -q "$TMPSNAP" dist/darshana.cyr > /dev/null; then
    cp "$TMPSNAP" dist/darshana.cyr   # restore committed bytes
    fail "dist/darshana.cyr is stale. Run 'cyrius distlib' and commit."
fi
pass "dist/darshana.cyr matches src/ — no drift"

# ============================================================
# Public API surface — confirm the donor's `tty_*` and `TIO_*`
# names made it into dist/darshana.cyr. Phase 4 cyim migration
# depends on these being present and identically named.
# ============================================================
echo "[smoke] public surface"

required_syms="tty_apply_raw_flags tty_raw tty_cooked tty_alt_enter tty_alt_leave tty_clear tty_cursor_hide tty_cursor_show tty_cursor_home tty_move tty_itoa tio_load32 tio_store32 tty_winsize tty_open_signalfd tty_clear_to_eol tty_clear_to_end"
for sym in $required_syms; do
    grep -qE "^fn ${sym}\b" dist/darshana.cyr \
        || fail "dist/darshana.cyr missing 'fn ${sym}' (cyim API contract)"
done
pass "all $(echo "$required_syms" | wc -w) cyim-API tty_* / tio_* symbols present in dist"

required_flags="TIO_ECHO TIO_ICANON TIO_ISIG TIO_IEXTEN TIO_ICRNL TIO_IXON TIO_OPOST TIO_CSIZE TIO_CS8 TIO_BRKINT TIO_INPCK TIO_ISTRIP TIO_CC_BASE TIO_VTIME TIO_VMIN TIO_BUF_SIZE TIOCGWINSZ TTY_SIGMASK_EXIT TTY_SIGMASK_WINCH"
for flag in $required_flags; do
    grep -qE "^var ${flag} " dist/darshana.cyr \
        || fail "dist/darshana.cyr missing 'var ${flag}' (cyim API contract)"
done
pass "all $(echo "$required_flags" | wc -w) TIO_* constants present in dist"

# ============================================================
# Linux gate — termios.cyr's syscall arm must remain inside
# CYRIUS_TARGET_LINUX. macOS BSD termios layout differs; without
# the gate, cross-builds silently get wrong syscall numbers.
# ============================================================
echo "[smoke] platform gate"

grep -q '#ifdef CYRIUS_TARGET_LINUX' src/termios.cyr \
    || fail "src/termios.cyr missing CYRIUS_TARGET_LINUX gate (Linux-syscall arm must stay gated)"
pass "src/termios.cyr Linux gate intact"

echo
echo "smoke: PASS ($BIN)"
