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
# module must be REJECTED, and so must a token in termios.cyr itself that
# sits outside that file's own gate.
#
# v1.1.4: the 1.1.4 audit found two holes. (1) The self-test only planted a
# token in a module with NO gate, so it exercised the "no gate at all"
# branch and never the positional one — disabling the line-number check
# left --self-test green. (2) The Linux token set was the ioctl names only,
# so the Linux signalfd pair (`sys_signalfd`, `sys_sigprocmask`,
# `SFD_CLOEXEC`) could be moved below the AGNOS #endif with every gate
# green; the AGNOS build then warned "duplicate fn … last definition wins"
# and silently used the Linux bodies. Both are closed, and each probe now
# checks for its own failure message rather than for any non-zero exit.
#
# v1.2.1: the AGNOS arm calls the stdlib's agnos `sys_sigprocmask` /
# `sys_signalfd`, which share their names with the Linux wrappers, so those
# two names are no longer Linux-only tokens. What catches a signalfd peer
# escaping its gate now is the PEER rule, which needs no token list at all:
# a function defined more than once in a file is a platform peer, and must
# have exactly one definition inside each target gate and none outside.
#
# v1.3.0: the AGNOS arm also takes the stdlib's `SFD_CLOEXEC`, so that name
# left the Linux token list too; the peer rule is what catches the Linux
# `tty_open_signalfd` escaping. The Linux tokens are now the ones that mean
# nothing on agnos (ioctl and its requests), the agnos tokens the agnos-only
# wrappers (`sys_winsize`, `sys_read_nb`).
#
# v1.5.0: the AGNOS arm calls `sys_console_mode` and `sys_fd_kind` and reads
# `FDK_CONSOLE`, `FDK_CHAN`, `CM_NOECHO` and `CM_FLUSH`. The stdlib defines
# all six only for agnos, so one used outside the gate breaks every Linux
# build; they join the agnos tokens.

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

# $1 = file. Every function defined more than once must be a Linux/AGNOS
# peer pair: one definition inside each target gate, none outside either.
check_peers() {
    _bad=$(awk '
        /^#ifdef CYRIUS_TARGET_LINUX/ { g = "linux"; next }
        /^#ifdef CYRIUS_TARGET_AGNOS/ { g = "agnos"; next }
        /^#endif/                     { g = ""; next }
        /^fn [A-Za-z_][A-Za-z0-9_]*/ {
            n = $2; sub(/\(.*/, "", n)
            cnt[n]++; where[n] = where[n] " " NR ":" (g == "" ? "ungated" : g)
            if (g == "linux") lin[n]++; else if (g == "agnos") agn[n]++; else out[n]++
        }
        END {
            for (n in cnt) if (cnt[n] > 1 && (lin[n] != 1 || agn[n] != 1 || out[n] > 0))
                print n " —" where[n]
        }' "$1")
    [ -z "$_bad" ] || fail "$1: a platform peer is not one-per-gate (each needs exactly one definition in the CYRIUS_TARGET_LINUX gate and one in the CYRIUS_TARGET_AGNOS gate):
$_bad"
}

run() {
    lin_report=""; agn_report=""
    for f in "$SRC_DIR"/*.cyr; do
        check_peers "$f"
        r=$(check_gate "$f" '(SYS_IOCTL|sys_ioctl|TCGETS|TCSETS|TIOCGWINSZ)' CYRIUS_TARGET_LINUX "Linux ioctl")
        [ -n "$r" ] && lin_report="$lin_report $r"
        r=$(check_gate "$f" 'sys_winsize|sys_read_nb|sys_console_mode|sys_fd_kind|FDK_CONSOLE|FDK_CHAN|CM_NOECHO|CM_FLUSH' CYRIUS_TARGET_AGNOS "agnos syscall")
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
    # probe <name> <expected message> <file to append to> <line to append>
    probe() {
        mkdir -p "$tmp/p"; cp "$SRC_DIR"/*.cyr "$tmp/p/"
        printf '\n%s\n' "$4" >> "$tmp/p/$3"
        if _out=$( SRC_DIR="$tmp/p" "$0" 2>&1 ); then
            echo "  SELF-TEST FAIL: '$1' was NOT rejected" >&2; st_fail=1
        elif ! printf '%s' "$_out" | grep -qF "$2"; then
            echo "  SELF-TEST FAIL: '$1' was rejected, but not by the rule under test" >&2; st_fail=1
        else
            echo "  ok: rejected — $1"
        fi
        for _x in "$tmp/p"/*.cyr; do : > "$_x"; done
    }
    # An ungated Linux ioctl token in a NON-termios module — the exact
    # shape the v0.9.3 file-scoped check could not see.
    probe "ungated Linux ioctl token in a non-termios module" "has no CYRIUS_TARGET_LINUX gate" \
        ansi.cyr 'var _probe_req = TCGETS;'
    # The POSITIONAL branch (v1.1.4): termios.cyr HAS the gate, but this
    # token sits after its #endif.
    probe "ioctl token after termios.cyr's own Linux #endif (positional)" "outside the CYRIUS_TARGET_LINUX gate" \
        termios.cyr 'var _probe_pos = TCGETS;'
    # The Linux ioctl wrapper called outside the gate (v1.3.0; through 1.2.1
    # this probe planted SFD_CLOEXEC, which the AGNOS arm now uses too).
    probe "Linux sys_ioctl outside the gate" "outside the CYRIUS_TARGET_LINUX gate" \
        termios.cyr 'fn _probe_io(fd) { return sys_ioctl(fd, 0, 0); }'
    # An agnos-only wrapper after the AGNOS #endif (v1.2.1).
    probe "agnos sys_winsize outside the AGNOS gate" "outside the CYRIUS_TARGET_AGNOS gate" \
        termios.cyr 'fn _probe_ws() { return sys_winsize(); }'
    # The console-mode call and an agnos-only constant after the AGNOS
    # #endif (v1.5.0).
    probe "agnos sys_console_mode outside the AGNOS gate" "outside the CYRIUS_TARGET_AGNOS gate" \
        termios.cyr 'fn _probe_cm() { return sys_console_mode(0, 0); }'
    probe "agnos FDK_CONSOLE outside the AGNOS gate" "outside the CYRIUS_TARGET_AGNOS gate" \
        termios.cyr 'var _probe_fk = FDK_CONSOLE;'
    # The PEER rule (v1.2.1): a third definition of a peer, ungated — the
    # shape of a Linux signalfd body moved below the AGNOS #endif.
    probe "a platform peer defined outside both gates" "is not one-per-gate" \
        termios.cyr 'fn tty_close_signalfd(fd, sigmask) { return 0; }'
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
