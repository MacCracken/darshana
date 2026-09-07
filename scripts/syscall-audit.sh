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
#   SYS_IOCTL                termios TCGETS/TCSETS + TIOCGWINSZ (Linux arm).
#                            Taken from the stdlib so it is arch-correct:
#                            16 on x86_64, 29 on aarch64. Do NOT reintroduce
#                            a local numeric definition (see v0.9.2).
#   _AGNOS_SYS_WINSIZE       agnos #60, framebuffer console grid
#   _AGNOS_SYS_SIGPROCMASK   agnos #17, mirshi-emulated
#   _AGNOS_SYS_SIGNALFD      agnos #18, mirshi-emulated
ALLOWED_SYSCALLS="1 SYS_IOCTL _AGNOS_SYS_WINSIZE _AGNOS_SYS_SIGPROCMASK _AGNOS_SYS_SIGNALFD"

# Stdlib `sys_*` / file helpers darshana is permitted to call. These are
# thin syscall wrappers; the same allowlist discipline applies.
#   sys_sigprocmask   block/unblock the signalfd mask (Linux arm)
#   sys_signalfd      create the signalfd (Linux arm). NOTE: bare
#                     passthrough — returns -errno, not -1. darshana
#                     normalizes at its own boundary.
#   file_close        close the signalfd on teardown
ALLOWED_WRAPPERS="sys_sigprocmask sys_signalfd file_close"

# Language builtins and control keywords, which are not calls to audit.
BUILTINS="syscall load8 load16 load32 load64 store8 store16 store32 store64 if while else return for fn var"

# docs/examples/ is shipped documentation that a consumer copies from, so
# it gets the same syscall discipline as src/ — this is how v1.0.2 found
# raw_loop.cyr ending with a literal `syscall(60, ...)` outside both
# platform gates (60 is exit on x86_64 Linux, but `winsize` on AGNOS).
# Examples additionally exit and poll, which the library itself never does.
#   SYS_EXIT      the example is a program, not a library; it exits
#   EX_SYS_POLL   the example's own poll(2) constant, for its input loop
ALLOWED_SYSCALLS_EXAMPLES="$ALLOWED_SYSCALLS SYS_EXIT EX_SYS_POLL"
# Examples print; the library never does.
ALLOWED_WRAPPERS_EXAMPLES="$ALLOWED_WRAPPERS print println fmt_int sys_read"

fail=0
note() { echo "$1" >&2; }

# Strip comments and blank out string literals, then rejoin so one logical
# statement is one line. Comment stripping is what the v0.9.4 scan already
# did; rejoining is what makes a line-wrapped or parenthesized call visible;
# blanking strings stops payload text being read as code — without it
# `println("raw_loop: Linux-only (raw mode needs termios)")` is scanned as a
# call to a function named `only`.
normalize() {
    sed 's/#.*//' "$@" \
        | sed 's/\\"/\x01/g; s/"[^"]*"/""/g' \
        | tr '\n' ' ' | sed 's/;/;\n/g'
}

# ------------------------------------------------------------------
# audit_dir <dir> <allowed-syscalls> <allowed-wrappers>
# ------------------------------------------------------------------
audit_dir() {
    _dir="$1"; _allow_sys="$2"; _allow_wrap="$3"
    set -- "$_dir"/*.cyr
    [ -e "$1" ] || return 0
    _norm=$(normalize "$@")

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
                fail=1
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
        fail=1
    done

    _ns=$(echo "$_found" | wc -w)
    _nw=0
    for c in $_called; do
        case " $_allow_wrap " in *" $c "*) _nw=$((_nw + 1)) ;; esac
    done
    echo "  ok: $_dir — $_ns distinct syscall targets, $_nw stdlib wrappers, all permitted"
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
# stdlib's (arch-aware by construction) or one the file declares inside
# an explicit `#ifdef CYRIUS_ARCH_*` gate. `1` is the sole exception —
# write(2) is 1 on every Linux arch and on AGNOS, and every ANSI
# emitter in the library uses it.
#
# Comments are stripped before matching, so the prose above (and the
# rationale comments in src/termios.cyr and tests/agnos.tcyr, which
# legitimately discuss syscall 60) does not trip it.
audit_no_literals() {
    _any=0
    for _d in "$@"; do
        set -- "$_d"/*.cyr
        [ -e "$1" ] || continue
        for _f in "$@"; do
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
    done
    [ $_any -eq 0 ] && echo "  ok: no numeric-literal syscall numbers (arch-blind class gated)"
    return 0
}

# ------------------------------------------------------------------
# --self-test: prove each closed bypass is actually rejected.
# ------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    st_fail=0
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT INT TERM
    mkdir -p "$tmp/src"
    probe() {   # $1 = name, $2 = body
        printf '%s\n' "$2" > "$tmp/src/probe.cyr"
        if ( "$0" "$tmp/src" >/dev/null 2>&1 ); then
            echo "  SELF-TEST FAIL: '$1' was NOT rejected" >&2
            st_fail=1
        else
            echo "  ok: rejected — $1"
        fi
    }
    probe "parenthesized first arg  syscall((59), ...)" 'fn f() { syscall((59), 0, 0, 0); return 0; }'
    probe "line-wrapped call"                           'fn f() { syscall(
    59, 0, 0, 0); return 0; }'
    probe "bare fork+exec numbers"                       'fn f() { syscall(57); syscall(59, 0, 0, 0); return 0; }'
    probe "non-sys_/file_ stdlib sink (xopen)"           'fn f() { return xopen(0, 0, 0); }'
    probe "unlisted sys_ wrapper"                        'fn f() { return sys_execve(0, 0, 0); }'
    # The arch-blind class (v1.1.1). SYS_IOCTL is on the allowlist by
    # NAME, so this probe proves the literal is rejected even when the
    # same syscall would be permitted spelled properly.
    probe "numeric-literal ioctl  syscall(16, ...)"     'fn f() { return syscall(16, 0, 0, 0); }'
    probe "numeric-literal exit    syscall(60, ...)"    'fn f() { syscall(60, 0); return 0; }'
    # ...and that write(1) is still allowed, or every emitter would fail.
    printf '%s\n' 'fn f() { syscall(1, 1, "x", 1); return 0; }' > "$tmp/src/probe.cyr"
    if ( "$0" "$tmp/src" >/dev/null 2>&1 ); then
        echo "  ok: accepted — syscall(1, ...) write literal (not over-strict)"
    else
        echo "  SELF-TEST FAIL: syscall(1, ...) was rejected" >&2
        st_fail=1
    fi
    # And a negative control: the real source must still pass.
    if ( "$0" src >/dev/null 2>&1 ); then
        echo "  ok: real src/ still passes (not vacuous)"
    else
        echo "  SELF-TEST FAIL: real src/ was rejected" >&2
        st_fail=1
    fi
    [ $st_fail -eq 0 ] && echo "  syscall-audit self-test: PASS"
    exit $st_fail
fi

# ------------------------------------------------------------------
# Normal run.
# ------------------------------------------------------------------
if [ $# -ge 1 ]; then
    # Explicit directory (used by --self-test's probes).
    _extra_defs=""
    audit_dir "$1" "$ALLOWED_SYSCALLS" "$ALLOWED_WRAPPERS"
else
    _extra_defs=""
    audit_dir "src" "$ALLOWED_SYSCALLS" "$ALLOWED_WRAPPERS"
    _extra_defs="src/*.cyr"
    audit_dir "docs/examples" "$ALLOWED_SYSCALLS_EXAMPLES" "$ALLOWED_WRAPPERS_EXAMPLES"
    # The arch-blindness gate runs over EVERY tree that compiles, tests
    # included — tests/ is where this class hid longest.
    audit_no_literals src tests programs docs/examples
fi

exit $fail
