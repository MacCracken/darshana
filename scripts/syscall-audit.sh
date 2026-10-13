#!/usr/bin/env bash
# darshana syscall allowlist — v0.9.4, hardened v1.0.2 and v1.1.1.
#
# darshana's entire surface is raw `syscall(...)`, so a DENYLIST can only
# ever catch the sinks someone thought to write down. Through v0.9.2 the
# CI rule matched named stdlib wrappers only (`sys_system`, `sys_exec*`),
# which meant a raw `syscall(57)` / `syscall(59, path, 0, 0)` fork+exec
# pair scored zero hits and the job exited green. v0.9.3 widened the
# pattern to a handful of numbers; v0.9.4 inverted it into this allowlist.
#
# The rule: every syscall darshana issues must be on this list. Anything
# else fails, whether or not anyone anticipated it. Adding a syscall is
# a deliberate act that edits this file — which is the point.
#
# v1.0.2 closed three ways ordinary Cyrius defeated the v0.9.4 scan, each
# of which compiled, ran, and audited green:
#
#   1. A non-identifier first argument. The old regex was
#      `syscall\([[:space:]]*[A-Za-z0-9_]+`, so `syscall((59), path, 0, 0)`
#      did not match at all — invisible rather than rejected.
#   2. A line-wrapped call. grep is line-based, so `syscall(` at end of
#      line with the number on the next line matched nothing.
#   3. A stdlib syscall wrapper outside the `sys_*` / `file_*` prefixes.
#      The resolved stdlib exports `xopen`, `xunlink`, `xmkdir`, `getenv`,
#      `panic` and more — filesystem sinks are exactly the class this
#      script says it exists to catch.
#
# (1) and (2) are fixed by normalizing before matching: comments are
# stripped, then statements are rejoined so one logical statement is one
# line. (3) is fixed by making the callee scan a true allowlist — every
# called identifier must be a darshana-defined fn, a language builtin, or
# an explicitly listed wrapper — instead of a `sys_*`/`file_*` prefix
# filter that only ever looked where it already expected to find trouble.
#
# v1.1.1 added a separate rule for the ARCH-BLINDNESS class — a syscall
# number written as a bare integer is correct for exactly one architecture.
# See `audit_no_literals` below for the three times that has bitten.
#
# v1.1.4: the 1.1.4 audit found that rule had never covered what it
# claimed, and closed four more bypasses. (a) Its glob was `*.cyr`, and
# every test suite is `*.tcyr` — so the rule never scanned tests/, where
# the v1.1.0 instance lived; the exact v1.1.0 regression
# (`syscall(302, ...)` in a test) audited green. (b) It only rejected a
# literal at the call site, so the v0.9.2 shape itself — a NAMED constant
# `var SYS_IOCTL = 16;` declared in an arch-blind gate — passed. A
# constant used as a syscall number must now be declared inside an
# explicit arch (or AGNOS-target) gate, or come from the stdlib. (c)
# Comments were stripped before strings were blanked, so a `#` inside a
# string literal hid the rest of its line from the audit. (d) An
# arithmetic first argument (`syscall(1 + 58, ...)`) audited as `1`, and
# an allowlisted name could be re-bound by a parameter or a local. Each
# is now a `--self-test` probe that checks for its own failure message.
#
# `--self-test` proves the gate can actually fail, by planting each of the
# bypasses above plus a plain fork+exec and asserting all are REJECTED — and
# that `syscall(1, ...)` is still ACCEPTED, so the arch rule is not merely
# over-strict. A gate that cannot fail proves nothing.
#
# Run standalone, or via scripts/smoke.sh / the CI security job.

set -eu

# ------------------------------------------------------------------
# The allowlist. Each entry is a first argument to `syscall(` that
# darshana is permitted to issue, with the reason it is here.
# ------------------------------------------------------------------
#   1                        write(2) to fd 1 — every ANSI escape emitter
#   _AGNOS_SYS_WINSIZE       agnos #60, framebuffer console grid
#   _AGNOS_SYS_SIGPROCMASK   agnos #17, mirshi-emulated
#   _AGNOS_SYS_SIGNALFD      agnos #18, mirshi-emulated
ALLOWED_SYSCALLS="1 _AGNOS_SYS_WINSIZE _AGNOS_SYS_SIGPROCMASK _AGNOS_SYS_SIGNALFD"

# Stdlib `sys_*` / file helpers darshana is permitted to call. These are
# thin syscall wrappers; the same allowlist discipline applies.
#   sys_sigprocmask   block/unblock the signalfd mask (Linux arm)
#   sys_signalfd      create the signalfd (Linux arm). NOTE: bare
#                     passthrough — returns -errno, not -1. darshana
#                     normalizes at its own boundary.
#   file_close        close the signalfd on teardown
#   sys_ioctl         termios TCGETS/TCSETS + TIOCGWINSZ (Linux arm). The
#                     stdlib wrapper issues its arch-aware SYS_IOCTL (16 on
#                     x86_64, 29 on aarch64). v1.2.0 — before that darshana
#                     issued `syscall(SYS_IOCTL, ...)` itself, and SYS_IOCTL
#                     sat on ALLOWED_SYSCALLS. Do NOT reintroduce a local
#                     numeric definition (see v0.9.2).
#   sys_read          read one signalfd record (Linux tty_read_signal, v1.2.0)
#   sys_read_nb       the AGNOS stdlib's non-blocking read, for the same
#                     (a blocking agnos sys_read waits on pipes/keyboard)
ALLOWED_WRAPPERS="sys_sigprocmask sys_signalfd file_close sys_ioctl sys_read sys_read_nb"

# Language builtins and control keywords, which are not calls to audit.
BUILTINS="syscall load8 load16 load32 load64 store8 store16 store32 store64 if while else return for fn var"

# docs/examples/ is shipped documentation that a consumer copies from, so
# it gets the same syscall discipline as src/ — this is how v1.0.2 found
# raw_loop.cyr ending with a literal `syscall(60, ...)` outside both
# platform gates (60 is exit on x86_64 Linux, but `winsize` on AGNOS).
# Examples additionally exit and poll, which the library itself never does.
#   SYS_EXIT      the example is a program, not a library; it exits
#   EX_SYS_POLL   the example's own poll(2) constant (x86_64 only)
#   SYS_PPOLL     the stdlib's aarch64 ppoll — aarch64 has no poll(2)
ALLOWED_SYSCALLS_EXAMPLES="$ALLOWED_SYSCALLS SYS_EXIT EX_SYS_POLL SYS_PPOLL"
# Examples print; the library never does.
ALLOWED_WRAPPERS_EXAMPLES="$ALLOWED_WRAPPERS print println fmt_int sys_read"

fail=0
note() { echo "$1" >&2; }

# Blank out string literals, THEN strip comments, then rejoin so one
# logical statement is one line. Rejoining is what makes a line-wrapped or
# parenthesized call visible; blanking strings stops payload text being
# read as code — without it `println("raw_loop: Linux-only (raw mode needs
# termios)")` is scanned as a call to a function named `only`. The order
# matters (v1.1.4): stripping comments first let a `#` INSIDE a string —
# ordinary in an escape library (`"\x1b#8"` is DECALN) — delete the rest
# of its line, code included, before anything looked at it.
normalize() {
    sed 's/\\"/\x01/g; s/"[^"]*"/""/g' "$@" \
        | sed 's/#.*//' \
        | tr '\n' ' ' | sed 's/;/;\n/g'
}

# Every syscall() first argument, verbatim up to the first `,` or `)`, with
# parens and whitespace removed. Must be ONE token: an expression such as
# `1 + 58` audits as its first token otherwise.
first_args() {
    printf '%s\n' "$1" | grep -oE 'syscall[[:space:]]*\([^,)]*[,)]' \
        | sed -E 's/^syscall[[:space:]]*\(//; s/[,)]$//; s/[()[:space:]]//g' || true
}
reject_expressions() {   # $1 = label, $2 = normalized text
    for _a in $(first_args "$2" | grep -vxE '[A-Za-z0-9_]+' | sort -u || true); do
        note "FAIL: $1 passes an EXPRESSION ('$_a') as a syscall number."
        note "  The audit reads a syscall number as one token; write the constant."
        fail=1; _dir_fail=1
    done
}

# ------------------------------------------------------------------
# audit_dir <dir> <allowed-syscalls> <allowed-wrappers>
# ------------------------------------------------------------------
audit_dir() {
    _dir="$1"; _allow_sys="$2"; _allow_wrap="$3"
    _dir_fail=0
    set -- "$_dir"/*.cyr
    [ -e "$1" ] || return 0
    _norm=$(normalize "$@")
    reject_expressions "$_dir/" "$_norm"

    # An allowlisted syscall NAME may not be re-bound: as a fn parameter, or
    # as a local `var` inside a body. Either way the call site still reads
    # `syscall(SYS_IOCTL, ...)` while issuing whatever the caller passed.
    for _nm in $_allow_sys; do
        case "$_nm" in [0-9]*) continue ;; esac
        if printf '%s\n' "$_norm" | grep -qE "fn [A-Za-z_0-9]+[[:space:]]*\([^)]*\b${_nm}\b"; then
            note "FAIL: $_dir/ binds the allowlisted syscall name '$_nm' as a fn parameter."
            fail=1; _dir_fail=1
        fi
        if sed 's/\\"/\x01/g; s/"[^"]*"/""/g; s/#.*//' "$@" | grep -qE "^[[:space:]]+var[[:space:]]+${_nm}\b"; then
            note "FAIL: $_dir/ shadows the allowlisted syscall name '$_nm' with a local var."
            fail=1; _dir_fail=1
        fi
    done

    # 1. Raw syscall() first arguments. `\(*` tolerates any number of
    #    opening parens so `syscall((59), ...)` is captured, not skipped.
    _found=$(printf '%s\n' "$_norm" \
             | grep -oE 'syscall[[:space:]]*\([[:space:]]*\(*[[:space:]]*[A-Za-z0-9_]+' \
             | grep -oE '[A-Za-z0-9_]+$' | sort -u || true)
    for nr in $_found; do
        case " $_allow_sys " in
            *" $nr "*) : ;;
            *)
                note "FAIL: $_dir/ issues syscall($nr), which is not on the allowlist."
                note "  darshana is a TTY primitives library; permitted syscalls here:"
                note "    $_allow_sys"
                note "  If this is intentional, add it to scripts/syscall-audit.sh with a"
                note "  one-line reason. If it is a process-spawning or filesystem"
                note "  syscall, it is out of charter."
                fail=1; _dir_fail=1
                ;;
        esac
    done

    # 2. Every called identifier must be darshana's own, a builtin, or an
    #    allowlisted wrapper. Not a `sys_*`/`file_*` prefix filter.
    #    `$_extra_defs` lets the examples scan see the library surface they
    #    legitimately call — an example `include`s src/main.cyr, so every
    #    public `tty_*` is in scope there without being defined locally.
    _defined=$( { grep -hoE '^fn [A-Za-z_][A-Za-z0-9_]*' "$@" || true
                  [ -n "${_extra_defs:-}" ] && grep -hoE '^fn [A-Za-z_][A-Za-z0-9_]*' $_extra_defs || true
                } | awk '{print $2}' | sort -u )
    _called=$(printf '%s\n' "$_norm" \
              | grep -oE '\b[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(' \
              | sed 's/[[:space:]]*($//;s/($//' | sort -u || true)
    for c in $_called; do
        case " $BUILTINS " in *" $c "*) continue ;; esac
        case " $_allow_wrap " in *" $c "*) continue ;; esac
        _isdef=0
        for d in $_defined; do [ "$c" = "$d" ] && _isdef=1 && break; done
        [ $_isdef -eq 1 ] && continue
        note "FAIL: $_dir/ calls '$c', which is neither defined there, a builtin,"
        note "  nor an allowlisted wrapper. Permitted wrappers: $_allow_wrap"
        note "  Add it to scripts/syscall-audit.sh with a reason, or drop the call."
        fail=1; _dir_fail=1
    done

    _ns=$(echo "$_found" | wc -w)
    _nw=0
    for c in $_called; do
        case " $_allow_wrap " in *" $c "*) _nw=$((_nw + 1)) ;; esac
    done
    # Through v1.1.3 this line printed even after the FAIL lines above.
    if [ $_dir_fail -eq 0 ]; then
        echo "  ok: $_dir — $_ns distinct syscall targets, $_nw stdlib wrappers, all permitted"
    fi
}

# ------------------------------------------------------------------
# NO NUMERIC-LITERAL SYSCALL NUMBERS (v1.1.1).
# ------------------------------------------------------------------
# A syscall number written as a bare integer is only correct for one
# architecture, and darshana targets Linux on BOTH x86_64 and aarch64.
# This exact defect has now bitten the project THREE times, each time
# invisible because the compiler's "syscall not routed" diagnostic is
# Mach-O-only:
#
#   v0.9.2  src/termios.cyr defined `SYS_IOCTL = 16` inside an
#           arch-BLIND `#ifdef CYRIUS_TARGET_LINUX` gate. On aarch64,
#           16 is `fremovexattr`. Every ioctl in the library was wrong.
#   v1.0.2  docs/examples/raw_loop.cyr ended with `syscall(60, ...)`
#           for exit, outside both platform gates. On AGNOS 60 is
#           `winsize`.
#   v1.1.0  tests/pty.tcyr hardcoded ioctl/nanosleep/dup/dup2/
#           prlimit64/rt_sigprocmask and failed 15 of 53 assertions the
#           first time it ran on real aarch64; tests/darshana.tcyr
#           hardcoded openat/close/prlimit64/rt_sigprocmask, which made
#           four assertions — including the v1.0.2 signalfd security
#           regression test — silently never run on ARM while looking
#           like a deliberate skip.
#
# The rule: a syscall number must be a NAMED constant. Either the
# stdlib's (arch-aware by construction) or one the corpus declares inside
# an explicit `#ifdef CYRIUS_ARCH_X86` / `CYRIUS_ARCH_AARCH64` gate — or
# `CYRIUS_TARGET_AGNOS`, which is x86_64-only, so its numbers are fixed.
# Both halves are checked (v1.1.4): no literal at a call site, AND no
# locally-declared syscall constant outside such a gate. `1` is the sole
# literal exception: write(2) is 1 on x86_64 and AGNOS, and on aarch64
# (where write is 64) the backend translates the literal 1 — the one
# translation darshana relies on, which every aarch64 suite exercises.
#
# Comments are stripped before matching, so the prose above (and the
# rationale comments in src/termios.cyr and tests/agnos.tcyr, which
# legitimately discuss syscall 60) does not trip it. The corpus is every
# compiled extension: .cyr, and the .tcyr / .fcyr / .bcyr test, fuzz and
# bench files — through v1.1.3 only .cyr, which excluded every test.
corpus_files() {
    for _d in "$@"; do
        for _f in "$_d"/*.cyr "$_d"/*.tcyr "$_d"/*.fcyr "$_d"/*.bcyr; do
            [ -e "$_f" ] && printf '%s\n' "$_f"
        done
    done
    return 0
}
audit_no_literals() {
    _any=0
    _files=$(corpus_files "$@")
    [ -n "$_files" ] || { note "FAIL: arch rule found no files to scan in: $*"; fail=1; return 0; }
    for _f in $_files; do
            _n=$(normalize "$_f")
            reject_expressions "$_f" "$_n"
            _hits=$(normalize "$_f" \
                    | grep -oE 'syscall[[:space:]]*\([[:space:]]*\(*[[:space:]]*[0-9]+' \
                    | grep -oE '[0-9]+$' | grep -vx '1' | sort -u || true)
            for _lit in $_hits; do
                note "FAIL: $_f issues syscall($_lit) as a NUMERIC LITERAL."
                note "  Syscall numbers differ per architecture — darshana targets"
                note "  Linux on x86_64 AND aarch64, where e.g. ioctl is 16 vs 29,"
                note "  exit 60 vs 93, openat 257 vs 56. Use the stdlib's arch-aware"
                note "  constant (SYS_IOCTL, SYS_EXIT, ...) or declare your own"
                note "  inside an explicit #ifdef CYRIUS_ARCH_X86 / _AARCH64 gate."
                note "  Only syscall(1, ...) — write(2) — may be a literal."
                fail=1
                _any=1
            done
    done

    # The declaration half: every NAME used as a syscall number that the
    # corpus itself declares (`var NAME = <integer>;`) must have every one of
    # its declarations inside an arch / AGNOS-target gate. A name the corpus
    # never declares comes from the stdlib, which is arch-aware.
    _used=$(for _f in $_files; do first_args "$(normalize "$_f")"; done \
            | grep -xE '[A-Za-z_][A-Za-z0-9_]*' | sort -u || true)
    _ungated=$(awk '
        FNR == 1 { depth = 0 }
        /^[[:space:]]*#ifdef[[:space:]]+/  { depth++; g[depth] = ($2 ~ /^CYRIUS_(ARCH_X86|ARCH_AARCH64|TARGET_AGNOS)$/); next }
        /^[[:space:]]*#ifndef[[:space:]]+/ { depth++; g[depth] = 0; next }
        /^[[:space:]]*#else/               { g[depth] = 0; next }
        /^[[:space:]]*#endif/              { if (depth > 0) depth--; next }
        /^[[:space:]]*var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(0x[0-9A-Fa-f]+|[0-9]+)[[:space:]]*;/ {
            name = $2; sub(/=.*/, "", name)
            gated = 0; for (i = 1; i <= depth; i++) if (g[i]) gated = 1
            if (!gated) print name "\t" FILENAME ":" FNR
        }' $_files)
    for _nm in $_used; do
        _bad=$(printf '%s\n' "$_ungated" | awk -F'\t' -v n="$_nm" '$1 == n { print $2 }')
        for _where in $_bad; do
            note "FAIL: $_where declares syscall number '$_nm' outside an arch gate."
            note "  This is the v0.9.2 shape: a named constant is still a literal for"
            note "  ONE architecture. Prefer the stdlib's constant; otherwise declare it"
            note "  inside #ifdef CYRIUS_ARCH_X86 and CYRIUS_ARCH_AARCH64 (or"
            note "  CYRIUS_TARGET_AGNOS). On aarch64, check a hand-written number"
            note "  against the backend's ESYSXLAT table: it rewrites some x86_64"
            note "  numbers, which is why the stdlib uses private aliases (SYS_PPOLL)."
            fail=1
            _any=1
        done
    done
    [ $_any -eq 0 ] && echo "  ok: no numeric-literal or arch-blind syscall numbers ($(echo "$_files" | wc -l) files)"
    return 0
}

# ------------------------------------------------------------------
# --self-test: prove each closed bypass is actually rejected.
# ------------------------------------------------------------------
# Every probe names the FAILURE MESSAGE it expects (v1.1.4). Through
# v1.1.3 a probe passed on any non-zero exit, so the two "numeric
# literal" probes were in fact being rejected by the allowlist rule —
# the literal rule itself was never exercised, and neutering it left
# --self-test green. The arch rule's probes now run through --corpus,
# which runs that rule alone.
if [ "${1:-}" = "--self-test" ]; then
    st_fail=0
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM
    expect_reject() {   # $1 = name, $2 = expected message, then the command
        _name="$1"; _want="$2"; shift 2
        if _out=$("$@" 2>&1); then
            echo "  SELF-TEST FAIL: '$_name' was NOT rejected" >&2; st_fail=1
        elif ! printf '%s' "$_out" | grep -qF "$_want"; then
            echo "  SELF-TEST FAIL: '$_name' was rejected, but not by the rule under test" >&2
            echo "    expected: $_want" >&2; st_fail=1
        else
            echo "  ok: rejected — $_name"
        fi
    }
    expect_accept() {   # $1 = name, then the command
        _name="$1"; shift
        if "$@" >/dev/null 2>&1; then echo "  ok: accepted — $_name"
        else echo "  SELF-TEST FAIL: '$_name' was rejected" >&2; st_fail=1; fi
    }
    put() {   # $1 = dir, $2 = file, $3 = body
        rm -rf "$tmp/$1"; mkdir -p "$tmp/$1"; printf '%s\n' "$3" > "$tmp/$1/$2"
    }
    ALLOW="not on the allowlist"

    # The allowlist rule (audit_dir), over a probe src/.
    put src probe.cyr 'fn f() { syscall((59), 0, 0, 0); return 0; }'
    expect_reject "parenthesized first arg  syscall((59), ...)" "$ALLOW" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { syscall(
    59, 0, 0, 0); return 0; }'
    expect_reject "line-wrapped call" "$ALLOW" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { syscall(57); syscall(59, 0, 0, 0); return 0; }'
    expect_reject "bare fork+exec numbers" "$ALLOW" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { return xopen(0, 0, 0); }'
    expect_reject "non-sys_/file_ stdlib sink (xopen)" "calls 'xopen'" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { return sys_execve(0, 0, 0); }'
    expect_reject "unlisted sys_ wrapper" "calls 'sys_execve'" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { var s = "#"; syscall(59, 0, 0, 0); return 0; }'
    expect_reject "a # inside a string hides the rest of the line (v1.1.4)" "$ALLOW" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { syscall(1 + 58, 0, 0, 0); return 0; }'
    expect_reject "arithmetic first arg  syscall(1 + 58, ...) (v1.1.4)" "EXPRESSION" "$0" "$tmp/src"
    put src probe.cyr 'fn f(_AGNOS_SYS_WINSIZE, a) { return syscall(_AGNOS_SYS_WINSIZE, a, 0, 0); }'
    expect_reject "allowlisted name re-bound as a parameter (v1.1.4)" "as a fn parameter" "$0" "$tmp/src"
    put src probe.cyr 'fn f() {
    var _AGNOS_SYS_WINSIZE = 59;
    return syscall(_AGNOS_SYS_WINSIZE, 0, 0, 0);
}'
    expect_reject "allowlisted name shadowed by a local (v1.1.4)" "with a local var" "$0" "$tmp/src"
    put src probe.cyr 'fn f() { syscall(1, 1, "x", 1); return 0; }'
    expect_accept "syscall(1, ...) write literal (not over-strict)" "$0" "$tmp/src"

    # The arch-blindness rule (audit_no_literals), via --corpus.
    put corpus probe.cyr 'fn f() { return syscall(16, 0, 0, 0); }'
    expect_reject "numeric-literal ioctl  syscall(16, ...)" "NUMERIC LITERAL" "$0" --corpus "$tmp/corpus"
    put corpus probe.cyr 'fn f() { syscall(60, 0); return 0; }'
    expect_reject "numeric-literal exit    syscall(60, ...)" "NUMERIC LITERAL" "$0" --corpus "$tmp/corpus"
    put corpus probe.tcyr 'fn t() { return syscall(302, 0, 7, 0, 0); }'
    expect_reject "numeric literal in a *.tcyr test — the v1.1.0 shape (v1.1.4)" "NUMERIC LITERAL" "$0" --corpus "$tmp/corpus"
    put corpus probe.cyr '#ifdef CYRIUS_TARGET_LINUX
var SYS_IOCTL_X = 16;
#endif
fn f() { return syscall(SYS_IOCTL_X, 0, 0, 0); }'
    expect_reject "named constant in an arch-BLIND gate — the v0.9.2 shape (v1.1.4)" "outside an arch gate" "$0" --corpus "$tmp/corpus"
    put corpus probe.tcyr 'var T_SYS = 35;
fn t() { return syscall(T_SYS, 0); }'
    expect_reject "ungated named constant in a test (v1.1.4)" "outside an arch gate" "$0" --corpus "$tmp/corpus"
    put corpus probe.cyr '#ifdef CYRIUS_ARCH_X86
var P_SYS = 35;
#endif
#ifdef CYRIUS_ARCH_AARCH64
var P_SYS = 101;
#endif
fn f() { return syscall(P_SYS, 0); }'
    expect_accept "a constant declared per arch (not over-strict)" "$0" --corpus "$tmp/corpus"
    put corpus probe.cyr 'fn f() { syscall(1, 1, "x", 1); return syscall(SYS_IOCTL, 0, 0, 0); }'
    expect_accept "write(1) literal and a stdlib constant" "$0" --corpus "$tmp/corpus"

    # Negative controls: the real trees must still pass both rules.
    expect_accept "real src/ (allowlist rule)" "$0" src
    expect_accept "real corpus (arch rule)" "$0" --corpus src tests programs docs/examples
    [ $st_fail -eq 0 ] && echo "  syscall-audit self-test: PASS"
    exit $st_fail
fi

# ------------------------------------------------------------------
# Normal run.
# ------------------------------------------------------------------
if [ "${1:-}" = "--corpus" ]; then
    # The arch-blindness rule alone, over the named trees (--self-test).
    shift
    audit_no_literals "$@"
elif [ $# -ge 1 ]; then
    # Explicit directory: the allowlist rule alone (--self-test's probes).
    _extra_defs=""
    audit_dir "$1" "$ALLOWED_SYSCALLS" "$ALLOWED_WRAPPERS"
else
    _extra_defs=""
    audit_dir "src" "$ALLOWED_SYSCALLS" "$ALLOWED_WRAPPERS"
    _extra_defs="src/*.cyr"
    audit_dir "docs/examples" "$ALLOWED_SYSCALLS_EXAMPLES" "$ALLOWED_WRAPPERS_EXAMPLES"
    # The arch-blindness rule runs over EVERY tree that compiles, tests
    # included — tests/ is where this class hid longest, and through v1.1.3
    # this rule did not actually look there (see the header).
    audit_no_literals src tests programs docs/examples
fi

exit $fail
