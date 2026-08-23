#!/usr/bin/env bash
# darshana syscall allowlist — v0.9.4.
#
# darshana's entire surface is raw `syscall(...)`, so a DENYLIST can only
# ever catch the sinks someone thought to write down. Through v0.9.2 the
# CI rule matched named stdlib wrappers only (`sys_system`, `sys_exec*`),
# which meant a raw `syscall(57)` / `syscall(59, path, 0, 0)` fork+exec
# pair scored zero hits and the job exited green. v0.9.3 widened the
# pattern to a handful of numbers; this inverts it.
#
# The rule: every syscall darshana issues must be on this list. Anything
# else fails, whether or not anyone anticipated it. Adding a syscall is
# a deliberate act that edits this file — which is the point.
#
# Run standalone, or via scripts/smoke.sh / the CI security job.

set -eu

SRC_DIR="${1:-src}"

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

fail=0
note() { echo "$1" >&2; }

# ------------------------------------------------------------------
# 1. Raw syscall() first arguments.
# ------------------------------------------------------------------
# Strip comment lines first — docstrings legitimately mention syscalls
# darshana does not issue (e.g. the note about execve in this very rule).
found=$(grep -hoE '^[^#]*syscall\([[:space:]]*[A-Za-z0-9_]+' "$SRC_DIR"/*.cyr 2>/dev/null \
        | sed 's/.*syscall([[:space:]]*//' | sort -u || true)

for nr in $found; do
    case " $ALLOWED_SYSCALLS " in
        *" $nr "*) : ;;
        *)
            note "FAIL: src/ issues syscall($nr), which is not on the allowlist."
            note "  darshana is a TTY primitives library; its permitted syscalls are:"
            note "    $ALLOWED_SYSCALLS"
            note "  If this is intentional, add it to ALLOWED_SYSCALLS in"
            note "  scripts/syscall-audit.sh with a one-line reason. If it is a"
            note "  process-spawning or filesystem syscall, it is out of charter."
            fail=1
            ;;
    esac
done

# ------------------------------------------------------------------
# 2. Stdlib syscall wrappers.
# ------------------------------------------------------------------
wrappers=$(grep -hoE '^[^#]*\b(sys_[a-z0-9_]+|file_[a-z0-9_]+)[[:space:]]*\(' "$SRC_DIR"/*.cyr 2>/dev/null \
           | grep -oE '\b(sys_[a-z0-9_]+|file_[a-z0-9_]+)' | sort -u || true)

for w in $wrappers; do
    case " $ALLOWED_WRAPPERS " in
        *" $w "*) : ;;
        *)
            note "FAIL: src/ calls stdlib wrapper '$w', which is not on the allowlist."
            note "  Permitted wrappers: $ALLOWED_WRAPPERS"
            note "  Add it to ALLOWED_WRAPPERS in scripts/syscall-audit.sh with a reason."
            fail=1
            ;;
    esac
done

if [ $fail -eq 0 ]; then
    n_sys=$(echo "$found" | wc -w)
    n_wrap=$(echo "$wrappers" | wc -w)
    echo "  ok: syscall allowlist — $n_sys distinct syscall targets, $n_wrap stdlib wrappers, all permitted"
fi
exit $fail
