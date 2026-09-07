#!/usr/bin/env bash
# darshana platform-gate check — extracted to its own file in v1.0.2.
#
# The Linux-only ioctl arm must stay inside `#ifdef CYRIUS_TARGET_LINUX`
# and the agnos syscall arm inside `#ifdef CYRIUS_TARGET_AGNOS`. macOS
# BSD termios layout differs, and agnos has no ioctl at all; without the
# gates a cross-build silently gets wrong syscall numbers — the class
# darshana already paid for at v0.9.2.
#
# Three generations of this check, each fixing the previous one's blindness:
#
#   v0.9.2 and earlier — `grep -q '#ifdef CYRIUS_TARGET_LINUX'`. Substring
#     presence only, with no relationship to where the ioctl code sat, so
#     hoisting the entire arm out of the gate left it green.
#   v0.9.3 — POSITIONAL: tokens must fall between the gate's line numbers.
#     Correct, but hard-coded `src/termios.cyr` as both the gate source and
#     the search corpus.
#   v1.0.2 — CORPUS-DRIVEN: every `src/*.cyr` is checked against its own
#     gates. The v0.9.3 form could not see the identical ungated ioctl code
#     placed in src/ansi.cyr, src/cursor.cyr, or any new module added to
#     [lib].modules — it would ship into dist/darshana.cyr outside any
#     `#ifdef` with every gate green. The syscall allowlist does not
#     backstop that: SYS_IOCTL / TCGETS / TCSETS are permitted there
#     *because* this check was supposed to confine them.
#
# One implementation, invoked by scripts/smoke.sh AND the CI security job,
# so the local and CI verdicts cannot drift. (Through v1.0.1 ci.yml carried
# its own copy of the awk.)
#
# `--self-test` mutation-proves it: an ungated token in a non-termios
# module must be REJECTED.

set -eu

SRC_DIR="${SRC_DIR:-src}"

fail() { echo "platform-gate: FAIL — $1" >&2; exit 1; }

gate_bounds() {   # $1 = #ifdef token, $2 = file -> "start end"
    awk -v tok="$1" '
        $0 ~ "^#ifdef " tok { s = NR; next }
        s && /^#endif/ { print s, NR; exit }
    ' "$2"
}

# $1 = file, $2 = token regex, $3 = gate token, $4 = human label
check_gate() {
    _f="$1"; _re="$2"; _tok="$3"; _label="$4"
    # Comment lines are excluded — the gates' own docstrings legitimately
    # name these tokens, at length.
    _hits=$(grep -nE "$_re" "$_f" | grep -vE '^[0-9]+: *#' || true)
    [ -n "$_hits" ] || return 0            # file doesn't use these tokens
    _b=$(gate_bounds "$_tok" "$_f")
    [ -n "$_b" ] || fail "$_f: uses $_label tokens but has no $_tok gate:
$_hits"
    _s=${_b% *}; _e=${_b#* }
    _stray=$(printf '%s\n' "$_hits" | awk -F: -v s="$_s" -v e="$_e" '$1 < s || $1 > e')
    [ -z "$_stray" ] || fail "$_f: $_label tokens outside the $_tok gate (lines $_s-$_e):
$_stray"
    echo "$_f:$_s-$_e"
}

run() {
    lin_report=""; agn_report=""
    for f in "$SRC_DIR"/*.cyr; do
        r=$(check_gate "$f" '(SYS_IOCTL|TCGETS|TCSETS|TIOCGWINSZ)' CYRIUS_TARGET_LINUX "Linux ioctl")
        [ -n "$r" ] && lin_report="$lin_report $r"
        r=$(check_gate "$f" '_AGNOS_SYS_[A-Z]+|_AGNOS_SFD_' CYRIUS_TARGET_AGNOS "agnos syscall")
        [ -n "$r" ] && agn_report="$agn_report $r"
    done
    # The gates must exist SOMEWHERE — a corpus-driven check that finds no
    # tokens at all would otherwise pass vacuously on a gutted tree.
    [ -n "$lin_report" ] || fail "no $SRC_DIR file contains a gated Linux ioctl arm — the termios path must exist and be gated"
    [ -n "$agn_report" ] || fail "no $SRC_DIR file contains a gated agnos syscall arm"
    echo "  ok: Linux ioctl arm confined to$lin_report; agnos arm to$agn_report"
}

if [ "${1:-}" = "--self-test" ]; then
    st_fail=0
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT INT TERM
    mkdir -p "$tmp/src"
    cp "$SRC_DIR"/*.cyr "$tmp/src/"
    # Mutation: an ungated Linux ioctl token in a NON-termios module — the
    # exact shape the v0.9.3 file-scoped check could not see.
    printf '\nvar _probe_req = TCGETS;\n' >> "$tmp/src/ansi.cyr"
    if ( SRC_DIR="$tmp/src" "$0" >/dev/null 2>&1 ); then
        echo "  SELF-TEST FAIL: ungated ioctl token in ansi.cyr was NOT rejected" >&2
        st_fail=1
    else
        echo "  ok: rejected — ungated Linux ioctl token in a non-termios module"
    fi
    # Negative control: the real tree must still pass.
    if ( "$0" >/dev/null 2>&1 ); then
        echo "  ok: real $SRC_DIR still passes (not vacuous)"
    else
        echo "  SELF-TEST FAIL: real $SRC_DIR was rejected" >&2
        st_fail=1
    fi
    [ $st_fail -eq 0 ] && echo "  platform-gate self-test: PASS"
    exit $st_fail
fi

run
