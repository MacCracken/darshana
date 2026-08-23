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

required_syms="tty_raw tty_cooked tty_alt_enter tty_alt_leave tty_clear tty_cursor_hide tty_cursor_show tty_cursor_home tty_cursor_up tty_cursor_down tty_move tty_dec_buf tio_load32 tio_store32 tty_winsize tty_open_signalfd tty_close_signalfd tty_clear_to_eol tty_clear_to_eos tty_sgr tty_sgr_reset tty_fg_rgb tty_bg_rgb tty_fg_rgb_buf tty_bg_rgb_buf tty_sgr_reset_buf tty_isatty tty_sgr_buf tty_fg_256_buf"
for sym in $required_syms; do
    grep -qE "^fn ${sym}\b" dist/darshana.cyr \
        || fail "dist/darshana.cyr missing 'fn ${sym}' (cyim API contract)"
done
pass "all $(echo "$required_syms" | wc -w) cyim-API tty_* / tio_* symbols present in dist"

# Bidirectional self-audit: every public fn ACTUALLY in dist must be
# listed in required_syms above, so the contract list can never
# silently lag the shipped surface (the loop above only catches the
# other direction — listed-but-missing-from-dist). This is how
# tty_cursor_up / tty_cursor_down went unchecked for several releases.
actual_fns=$(grep -oE '^fn (tty_|tio_)[A-Za-z0-9_]+' dist/darshana.cyr | awk '{print $2}' | sort -u)
for fn in $actual_fns; do
    case " $required_syms " in
        *" $fn "*) : ;;
        *) fail "dist/darshana.cyr exports 'fn ${fn}' but required_syms omits it (surface check lagging dist — add it here)" ;;
    esac
done
pass "required_syms covers every public fn symbol in dist ($(echo "$actual_fns" | wc -w) total — no lag)"

required_flags="TCGETS TCSETS TIO_ECHO TIO_ICANON TIO_ISIG TIO_IEXTEN TIO_ICRNL TIO_IXON TIO_OPOST TIO_CSIZE TIO_CS8 TIO_BRKINT TIO_INPCK TIO_ISTRIP TIO_CC_BASE TIO_VTIME TIO_VMIN TIO_BUF_SIZE TIOCGWINSZ TTY_SIGMASK_EXIT TTY_SIGMASK_WINCH TTY_FG_BLACK TTY_FG_RED TTY_FG_GREEN TTY_FG_YELLOW TTY_FG_BLUE TTY_FG_MAGENTA TTY_FG_CYAN TTY_FG_WHITE TTY_FG_BRIGHT_BLACK TTY_FG_BRIGHT_RED TTY_FG_BRIGHT_GREEN TTY_FG_BRIGHT_YELLOW TTY_FG_BRIGHT_BLUE TTY_FG_BRIGHT_MAGENTA TTY_FG_BRIGHT_CYAN TTY_FG_BRIGHT_WHITE"
for flag in $required_flags; do
    grep -qE "^var ${flag} " dist/darshana.cyr \
        || fail "dist/darshana.cyr missing 'var ${flag}' (cyim API contract)"
done
pass "all $(echo "$required_flags" | wc -w) TIO_* / TIOC* / TTY_* constants present in dist"

# Bidirectional self-audit for CONSTANTS — the mirror of the fn loop
# above, added v0.9.3. Without it the constant contract list could
# silently lag the shipped surface, and it had: four AGNOS_* internals
# entered dist across v0.8.0-v0.9.0 unlisted and outside the naming
# convention `src/main.cyr` calls frozen at v1.0. A shipped constant is
# either public contract (list it here) or internal (`_`-prefix it).
# Not hypothetical in this toolchain: darshana's own v0.9.2 SYS_IOCTL
# bug was a shipped constant silently shadowing a stdlib value.
actual_vars=$(grep -oE '^var [A-Z][A-Za-z0-9_]*' dist/darshana.cyr | awk '{print $2}' | sort -u)
for v in $actual_vars; do
    case " $required_flags " in
        *" $v "*) : ;;
        *) fail "dist/darshana.cyr exports 'var ${v}' but required_flags omits it (constant surface check lagging dist — add it here, or underscore-privatize the constant)" ;;
    esac
done
pass "required_flags covers every public constant in dist ($(echo "$actual_vars" | wc -w) total — no lag)"

# ============================================================
# Syscall allowlist — v0.9.4. Shared implementation with the CI
# security job (scripts/syscall-audit.sh) so the two cannot drift.
# ============================================================
echo "[smoke] syscall allowlist"
bash scripts/syscall-audit.sh || fail "syscall allowlist violation (see above)"

# ============================================================
# Docstring audit — v0.9.4. `dist/darshana.cyr` IS the documentation
# a consumer reads, so a public symbol without a usable docstring is a
# shipped defect, not a style nit. Enforces the three things the v0.9.4
# per-symbol API audit checked by hand:
#
#   1. every public fn has a comment block immediately above it,
#   2. that block states the return contract,
#   3. every `_buf` composer states its byte budget (it takes no
#      capacity argument, so the caller cannot size the buffer without
#      that number),
#   4. every public constant is documented, individually or by leading
#      a documented group.
#
# This exists because the v0.9.3 duplication pass silently destroyed the
# docstrings on `tty_cursor_up` and `tty_fg_rgb_buf` — the text stayed
# with the extracted private helper and the public wrapper was left
# bare — and every gate stayed green. Only the hand audit caught it.
# ============================================================
echo "[smoke] docstring audit"

doc_gaps=$(awk '
/^#/                  { if (reset) { blk=""; reset=0 } blk = blk "\n" $0; prev="c"; next }
/^[[:space:]]*$/      { reset=1; prev="b"; next }
/^fn (tty_|tio_)[a-z0-9_]+\(/ {
    name=$2; sub(/\(.*/, "", name)
    if (!seen[name]++) {
        if (reset || blk == "")                    print "  no docstring:      " name
        else {
            if (blk !~ /[Rr]eturn/)                print "  return not stated: " name
            if (name ~ /_buf$/ && blk !~ /budget/) print "  no byte budget:    " name
        }
    }
    blk=""; reset=0; prev="f"; next
}
/^var [A-Z]/ {
    cname=$2
    if (!cseen[cname]++ && (reset || blk == "") && prev != "v") print "  no doc group:      " cname
    blk=""; reset=0; prev="v"; next
}
{ blk=""; reset=0; prev="o" }
' dist/darshana.cyr)

if [ -n "$doc_gaps" ]; then
    fail "public symbols in dist/darshana.cyr with inadequate docstrings:
$doc_gaps"
fi
pass "every public fn documents its return; every _buf states its byte budget"

# ============================================================
# Platform gates — the Linux syscall arm must stay INSIDE
# CYRIUS_TARGET_LINUX and the agnos arm inside CYRIUS_TARGET_AGNOS.
# macOS BSD termios layout differs, and agnos has no ioctl at all;
# without the gates a cross-build silently gets wrong syscall numbers.
#
# v0.9.3: this is a POSITIONAL check. It previously just grepped for
# the `#ifdef` string anywhere in the file, which stayed green even
# with the entire ioctl arm hoisted outside the gate — the check had
# no relationship to what it claimed to verify.
# ============================================================
echo "[smoke] platform gate"

gate_bounds() {   # $1 = #ifdef token -> echoes "start end"
    awk -v tok="$1" '
        $0 ~ "^#ifdef " tok { s = NR; next }
        s && /^#endif/ { print s, NR; exit }
    ' src/termios.cyr
}

lin_bounds=$(gate_bounds CYRIUS_TARGET_LINUX)
agn_bounds=$(gate_bounds CYRIUS_TARGET_AGNOS)
[ -n "$lin_bounds" ] || fail "src/termios.cyr: CYRIUS_TARGET_LINUX gate not found (Linux-syscall arm must stay gated)"
[ -n "$agn_bounds" ] || fail "src/termios.cyr: CYRIUS_TARGET_AGNOS gate not found"

# Every Linux-only ioctl token must sit inside the Linux gate, and
# every agnos syscall constant inside the agnos gate. Comment lines are
# excluded — the gates' own docstrings legitimately name these tokens.
lin_start=${lin_bounds% *}; lin_end=${lin_bounds#* }
agn_start=${agn_bounds% *}; agn_end=${agn_bounds#* }

stray_lin=$(grep -nE '(SYS_IOCTL|TCGETS|TCSETS|TIOCGWINSZ)' src/termios.cyr \
            | grep -vE '^[0-9]+: *#' \
            | awk -F: -v s="$lin_start" -v e="$lin_end" '$1 < s || $1 > e')
[ -z "$stray_lin" ] || fail "src/termios.cyr: Linux ioctl tokens outside the CYRIUS_TARGET_LINUX gate (lines $lin_start-$lin_end):
$stray_lin"

stray_agn=$(grep -nE '_AGNOS_SYS_[A-Z]+|_AGNOS_SFD_' src/termios.cyr \
            | grep -vE '^[0-9]+: *#' \
            | awk -F: -v s="$agn_start" -v e="$agn_end" '$1 < s || $1 > e')
[ -z "$stray_agn" ] || fail "src/termios.cyr: agnos syscall tokens outside the CYRIUS_TARGET_AGNOS gate (lines $agn_start-$agn_end):
$stray_agn"

pass "Linux ioctl arm confined to lines $lin_start-$lin_end; agnos arm to $agn_start-$agn_end"

echo
echo "smoke: PASS ($BIN)"
