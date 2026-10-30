#!/usr/bin/env bash
# darshana smoke test — runs the compile-link smoke binary, verifies
# its single line of output, and re-asserts the dist artifact is in
# sync with the source modules. CI runs this in build-and-test;
# contributors should run it before commit.
#
# Run it with bash, as CI and scripts/ci.sh do. (Through v1.1.3 this
# header said bash was required for `<( ... )` process substitution in
# the drift check; that was removed in v1.0.2.)

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
if [ ! -f dist/darshana.deps ]; then
    fail "dist/darshana.deps missing — run 'cyrius distlib'"
fi

# Snapshot what's checked in; regenerate; diff.
#
# BOTH artifacts, as of v1.0.2. `cyrius distlib` writes darshana.cyr AND
# darshana.deps, but through v1.0.1 this check snapshotted and diffed only
# the former — and the `cyrius distlib` call it makes to produce the
# comparison rewrites the sidecar first. So a stale committed sidecar was
# destroyed in the working tree before anything could compare it, and could
# sit wrong in the repo indefinitely with every gate green. It is not a
# cosmetic file: it is what tells a consumer's `cyrius deps` which stdlib
# leaves to resolve, which is exactly the failure v1.0.1 hit when the `vec`
# leaf was missing and every consumer build warned.
TMPSNAP="${TMPDIR:-/tmp}/darshana-dist-snap-$$.cyr"
TMPSNAPD="${TMPDIR:-/tmp}/darshana-deps-snap-$$.deps"
trap 'rm -f "$TMPSNAP" "$TMPSNAPD"' EXIT INT TERM
cp dist/darshana.cyr  "$TMPSNAP"
cp dist/darshana.deps "$TMPSNAPD"
cyrius distlib > /dev/null
if ! diff -q "$TMPSNAP" dist/darshana.cyr > /dev/null; then
    cp "$TMPSNAP"  dist/darshana.cyr    # restore committed bytes
    cp "$TMPSNAPD" dist/darshana.deps
    fail "dist/darshana.cyr is stale. Run 'cyrius distlib' and commit."
fi
if ! diff -q "$TMPSNAPD" dist/darshana.deps > /dev/null; then
    cp "$TMPSNAP"  dist/darshana.cyr
    cp "$TMPSNAPD" dist/darshana.deps   # restore committed bytes
    fail "dist/darshana.deps is stale. Run 'cyrius distlib' and commit."
fi
pass "dist/darshana.cyr and dist/darshana.deps match src/ — no drift"

# ============================================================
# Public API surface — confirm the donor's `tty_*` and `TIO_*`
# names made it into dist/darshana.cyr. Phase 4 cyim migration
# depends on these being present and identically named.
# ============================================================
echo "[smoke] public surface"

required_syms="tty_raw tty_cooked tty_alt_enter tty_alt_leave tty_clear tty_cursor_hide tty_cursor_show tty_cursor_home tty_cursor_up tty_cursor_down tty_move tty_dec_buf tio_load32 tio_store32 tty_winsize tty_open_signalfd tty_close_signalfd tty_clear_to_eol tty_clear_to_eos tty_sgr tty_sgr_reset tty_fg_rgb tty_bg_rgb tty_fg_rgb_buf tty_bg_rgb_buf tty_sgr_reset_buf tty_isatty tty_sgr_buf tty_fg_256_buf tty_bg_256_buf tty_read_signal tty_winsize_or tty_raw_nonblock tty_sanitize_buf tty_forget tty_flush_input tty_echo_off tty_has_ctl tty_sgr_list_buf tty_sgr_list tty_cursor_save tty_cursor_restore tty_scroll_region tty_scroll_region_reset tty_title tty_title_buf tty_clipboard_set tty_clipboard_buf tty_move_buf tty_clear_to_eol_buf tty_mouse_enable tty_mouse_disable tty_paste_enable tty_paste_disable tty_sgr_len tty_sgr_strip_buf tty_isatty_is_per_fd tty_winsize_px"
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
# v1.1.4: EVERY non-underscore fn, not just `tty_`/`tio_` ones. The
# naming convention says anything without a `_` prefix is public, so an
# undocumented `fn darshana_bell()` used to ship past this check unlisted.
actual_fns=$(grep -oE '^fn [A-Za-z][A-Za-z0-9_]*' dist/darshana.cyr | awk '{print $2}' | sort -u)
for fn in $actual_fns; do
    case " $required_syms " in
        *" $fn "*) : ;;
        *) fail "dist/darshana.cyr exports 'fn ${fn}' but required_syms omits it (surface check lagging dist — add it here)" ;;
    esac
done
pass "required_syms covers every public fn symbol in dist ($(echo "$actual_fns" | wc -w) total — no lag)"

required_flags="TCGETS TCSETS TIO_ECHO TIO_ICANON TIO_ISIG TIO_IEXTEN TIO_ICRNL TIO_IXON TIO_OPOST TIO_CSIZE TIO_CS8 TIO_BRKINT TIO_INPCK TIO_ISTRIP TIO_CC_BASE TIO_VTIME TIO_VMIN TIO_BUF_SIZE TIOCGWINSZ TTY_SIGMASK_EXIT TTY_SIGMASK_WINCH TTY_FG_BLACK TTY_FG_RED TTY_FG_GREEN TTY_FG_YELLOW TTY_FG_BLUE TTY_FG_MAGENTA TTY_FG_CYAN TTY_FG_WHITE TTY_FG_BRIGHT_BLACK TTY_FG_BRIGHT_RED TTY_FG_BRIGHT_GREEN TTY_FG_BRIGHT_YELLOW TTY_FG_BRIGHT_BLUE TTY_FG_BRIGHT_MAGENTA TTY_FG_BRIGHT_CYAN TTY_FG_BRIGHT_WHITE TTY_SGR_BOLD TTY_SGR_DIM TTY_SGR_UNDERLINE TTY_SGR_REVERSE TTY_SANITIZE_UTF8 TTY_SANITIZE_LATIN1 TTY_KEEP_TAB TTY_KEEP_LF TTY_SIGMASK_PIPE TTY_BG_BLACK TTY_BG_RED TTY_BG_GREEN TTY_BG_YELLOW TTY_BG_BLUE TTY_BG_MAGENTA TTY_BG_CYAN TTY_BG_WHITE TTY_BG_BRIGHT_BLACK TTY_BG_BRIGHT_RED TTY_BG_BRIGHT_GREEN TTY_BG_BRIGHT_YELLOW TTY_BG_BRIGHT_BLUE TTY_BG_BRIGHT_MAGENTA TTY_BG_BRIGHT_CYAN TTY_BG_BRIGHT_WHITE"
for flag in $required_flags; do
    grep -qE "^var ${flag} " dist/darshana.cyr \
        || fail "dist/darshana.cyr missing 'var ${flag}' (cyim API contract)"
done
pass "all $(echo "$required_flags" | wc -w) TIO_* / TIOC* / TTY_* constants present in dist"

# Bidirectional self-audit for CONSTANTS — the mirror of the fn loop
# above, added v0.9.3. Without it the constant contract list could
# silently lag the shipped surface, and it had: four AGNOS_* internals
# entered dist across v0.8.0-v0.9.0 unlisted and outside the naming
# convention the bundle front matter (src/termios.cyr) calls frozen at
# v1.0 — in src/main.cyr until v0.9.4. A shipped constant is
# either public contract (list it here) or internal (`_`-prefix it).
# Not hypothetical in this toolchain: darshana's own v0.9.2 SYS_IOCTL
# bug was a shipped constant silently shadowing a stdlib value.
# v1.1.4: any non-underscore `var`, lowercase included — `var tty_last_sgr`
# used to slip past an uppercase-only pattern.
actual_vars=$(grep -oE '^var [A-Za-z][A-Za-z0-9_]*' dist/darshana.cyr | awk '{print $2}' | sort -u)
for v in $actual_vars; do
    case " $required_flags " in
        *" $v "*) : ;;
        *) fail "dist/darshana.cyr exports 'var ${v}' but required_flags omits it (constant surface check lagging dist — add it here, or underscore-privatize the constant)" ;;
    esac
done
pass "required_flags covers every public constant in dist ($(echo "$actual_vars" | wc -w) total — no lag)"

# The lists above are this script's own; ADR 0003 is the freeze (v1.1.4).
# Renaming a frozen symbol CONSISTENTLY — in src, tests and the lists
# above — kept every check green through v1.1.3. So every name the ADR's
# two tables freeze must still exist in dist, and each table must hold the
# count its heading states. Additive 1.x symbols are fine: this is a
# subset check, not equality.
adr=docs/adr/0003-v1-api-freeze.md
adr_names() {   # $1 = heading regex that starts the table section
    awk -v h="$1" '$0 ~ h { on = 1; next } on && /^### / { exit } on && /^\|/' "$adr" \
        | grep -oE '`[A-Za-z_][A-Za-z0-9_]*`' | tr -d '`' | sort -u
}
adr_fns=$(adr_names '^### Frozen: 29 public functions')
adr_consts=$(adr_names '^### Frozen: 37 public constants')
[ "$(echo "$adr_fns" | wc -w)" -eq 29 ] || fail "ADR 0003's function table lists $(echo "$adr_fns" | wc -w) names, not 29"
[ "$(echo "$adr_consts" | wc -w)" -eq 37 ] || fail "ADR 0003's constant table lists $(echo "$adr_consts" | wc -w) names, not 37"
for n in $adr_fns; do
    grep -qE "^fn ${n}\(" dist/darshana.cyr || fail "ADR 0003 freezes 'fn ${n}', but dist/darshana.cyr does not define it — renaming or removing a frozen fn needs a major (ADR 0003)"
done
for n in $adr_consts; do
    grep -qE "^var ${n} " dist/darshana.cyr || fail "ADR 0003 freezes 'var ${n}', but dist/darshana.cyr does not define it — needs a major (ADR 0003)"
done
# Symbols added since 1.0 are frozen from their release too (the ADR's
# third table). Each must still be in dist, as a fn or a constant.
adr_added=$(adr_names '^### Added since 1.0')
[ -n "$adr_added" ] || fail "ADR 0003's 'Added since 1.0' table lists no names"
for n in $adr_added; do
    grep -qE "^(fn ${n}\(|var ${n} )" dist/darshana.cyr || fail "ADR 0003 records '${n}' as added and frozen, but dist/darshana.cyr does not define it — needs a major"
done
pass "every ADR 0003 frozen name is still in dist (29 fns, 37 constants, $(echo "$adr_added" | wc -w) added since 1.0)"

# ============================================================
# Stack-buffer budgets — v1.1.4. Every fixed-size stack buffer in src/
# is listed here with the WORST CASE it has to hold, and must be at least
# that large. Caller buffers are covered exhaustively by
# tests/identity.tcyr's guard region; these are the library's OWN
# buffers, which no test can see past: shrinking tty_move's buf[44] to
# buf[8] overflows its stack frame silently and every suite stays green
# (shown in the 1.1.4 audit). Bidirectional: a stack buffer missing from
# this list fails too, so a new one has to declare its worst case.
#
#   fn                  buffer  min  worst case
#   _ansi_rgb_write     buf     19   CSI 38;2;255;255;255m
#   tty_sgr             buf      6   ESC [ + 3 digits + m
#   tty_move            buf     14   ESC [ + 5 digits + ; + 5 digits + H (tty_move_buf)
#   tty_scroll_region   buf     14   ESC [ + 5 digits + ; + 5 digits + r
#   _cursor_rel         buf     22   ESC [ + 19 digits + final
#   _tty_set_mode       work    60   TIO_BUF_SIZE (the copy loop runs to it)
#   tty_sgr_list        buf     66   ESC [ + 16 x (3 digits + ;/m)
#   tty_title           buf    261   ESC ] 0 ; + 256 title bytes + BEL
#   tty_clipboard_set   chunk   64   base64 of one 48-byte piece
#   tty_winsize         ws       8   struct winsize
#   tty_winsize_px      ws       8   struct winsize
#   tty_isatty          ws       8   struct winsize
#   tty_open_signalfd   mask     8   one u64 sigset (both peers)
#   tty_open_signalfd   prev     8
#   tty_open_signalfd   added    8
#   tty_close_signalfd  mask     8
#   tty_read_signal     info   128   struct signalfd_siginfo (Linux)
#   tty_read_signal     rec      8   agnos record: 4 B kernel, 8 B mirshi
# ============================================================
echo "[smoke] stack-buffer budgets"
stack_budgets="_ansi_rgb_write:buf:19 tty_sgr:buf:6 tty_move:buf:14 tty_scroll_region:buf:14 _cursor_rel:buf:22 _tty_set_mode:work:60 tty_sgr_list:buf:66 tty_title:buf:261 tty_clipboard_set:chunk:64 tty_winsize:ws:8 tty_winsize_px:ws:8 tty_isatty:ws:8 tty_open_signalfd:mask:8 tty_open_signalfd:prev:8 tty_open_signalfd:added:8 tty_close_signalfd:mask:8 tty_read_signal:info:128 tty_read_signal:rec:8"
actual_bufs=$(awk '/^fn /{ f = $2; sub(/\(.*/, "", f) }
    /^[[:space:]]+var [A-Za-z_][A-Za-z0-9_]*\[[0-9]+\];/ {
        b = $2; n = b; sub(/\[.*/, "", b); sub(/.*\[/, "", n); sub(/\].*/, "", n)
        print f ":" b ":" n
    }' src/*.cyr)
for entry in $actual_bufs; do
    fb="${entry%:*}"; size="${entry##*:}"
    want=""
    for sb in $stack_budgets; do
        [ "${sb%:*}" = "$fb" ] && want="${sb##*:}"
    done
    [ -n "$want" ] || fail "src/ declares stack buffer '${fb}' (${size} bytes) with no budget in scripts/smoke.sh — add it with its worst case"
    [ "$size" -ge "$want" ] || fail "stack buffer '${fb}' is ${size} bytes but its worst case is ${want}"
done
grep -qE '^var _tty_saved\[([6-9][0-9]|[1-9][0-9]{2,})\];' src/termios.cyr \
    || fail "_tty_saved must hold TIO_BUF_SIZE (60) bytes"
pass "every src/ stack buffer meets its documented worst case ($(echo "$actual_bufs" | wc -w) buffers)"

# ============================================================
# Syscall allowlist — v0.9.4. Shared implementation with the CI
# security job (scripts/syscall-audit.sh) so the two cannot drift.
# ============================================================
echo "[smoke] syscall allowlist"
bash scripts/syscall-audit.sh || fail "syscall allowlist violation (see above)"

# ============================================================
# Docstring audit — v0.9.4. `dist/darshana.cyr` IS the documentation
# a consumer reads, so a public symbol without a usable docstring is a
# shipped defect, not a style nit. Enforces what the v0.9.4 per-symbol
# API audit checked by hand:
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

#   5. EVERY definition is audited, not just the first with a given name
#      (v1.0.2). Through v1.0.1 the fn check was guarded by `!seen[name]++`
#      and the constant check by `!cseen[cname]++`. dist/darshana.cyr
#      defined six public fns twice (tty_raw, tty_cooked, tty_winsize,
#      tty_isatty, tty_open_signalfd, tty_close_signalfd — Linux peer then
#      AGNOS peer; thirteen by v1.7.0) and two public constants twice
#      (TTY_SIGMASK_EXIT / _WINCH), so the de-dup exempted the ENTIRE
#      AGNOS half of the frozen surface from the docstring rule. That is the worst possible place
#      for the exemption: the AGNOS docstrings are the only text explaining
#      why TTY_SIGMASK_EXIT is 0x8006 there and 0x4003 on Linux (agnos
#      `1<<sig` vs Linux `1<<(sig-1)`), which ADR 0003 freezes and a
#      consumer cannot infer. It was not hypothetical — AGNOS tty_winsize
#      shipped from v0.8.0 with no adjacent docstring at all, and this gate
#      never saw it. Nothing in the rules is order-dependent, so the
#      de-dup is simply gone.
doc_gaps=$(awk '
/^#/                  { if (reset) { blk=""; reset=0 } blk = blk "\n" $0; prev="c"; next }
/^[[:space:]]*$/      { reset=1; prev="b"; next }
/^fn [A-Za-z][A-Za-z0-9_]*\(/ {
    name=$2; sub(/\(.*/, "", name)
    occ[name]++
    tag = (occ[name] > 1) ? name " (peer #" occ[name] ")" : name
    if (reset || blk == "")                    print "  no docstring:      " tag
    else {
        if (blk !~ /[Rr]eturn/)                print "  return not stated: " tag
        if (name ~ /_buf$/ && blk !~ /budget/) print "  no byte budget:    " tag
    }
    blk=""; reset=0; prev="f"; next
}
/^var [A-Za-z]/ {
    cname=$2
    if ((reset || blk == "") && prev != "v") print "  no doc group:      " cname
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

#
# v1.0.2: CORPUS-DRIVEN, not file-driven. Through v1.0.1 both this check
# and its CI twin hard-coded `src/termios.cyr` as the gate source AND the
# search corpus, so the identical Linux-only ioctl code placed in
# src/ansi.cyr, src/cursor.cyr or any new module added to [lib].modules
# was never examined — it would ship into dist/darshana.cyr outside any
# `#ifdef` with every gate green. That is precisely the hole v0.9.3 closed
# ("the check had no relationship to what it claimed to verify"), moved by
# one file. The syscall allowlist does not backstop it either: SYS_IOCTL /
# TCGETS / TCSETS are permitted there *because* this gate was supposed to
# confine them.
# One implementation, shared with the CI security job, so the local and
# CI verdicts cannot drift apart (v1.0.2 — through v1.0.1 ci.yml carried
# its own copy of this awk).
bash scripts/platform-gate.sh || fail "platform gate violation (see above)"

echo
echo "smoke: PASS ($BIN)"
