#!/usr/bin/env bash
# scripts/ci.sh — every CI gate, one implementation (v1.1.4).
#
#   bash scripts/ci.sh <gate>...     run the named gates, in order
#   bash scripts/ci.sh all           run every gate (local convenience)
#   bash scripts/ci.sh --list        print the gate names
#
# .github/workflows/ci.yml calls this script for each of its steps, so a
# gate run locally is literally the code CI runs — not a second copy of
# it. Through v1.1.3 each gate's logic lived only in the YAML, so nothing
# could run "what CI runs" before pushing, and the 1.1.3 toolchain
# comparison needed a hand-built mirror of all of them. That is the same
# drift this project already removed for the platform gate and the syscall
# audit (v1.0.2): one implementation, two callers.
#
# What stays in the YAML is environment setup that is not a gate: the
# toolchain install and the apt-get of qemu-user-static.
#
# Under GitHub Actions ($GITHUB_ACTIONS set) warnings and errors are
# emitted as workflow annotations; locally they print plainly.
#
# Exit status: 0 if every requested gate passed, 1 otherwise. `all` runs
# every gate even after a failure and summarizes at the end; naming gates
# explicitly stops at the first failing one, which is what a CI step wants.

set -u
cd "$(dirname "$0")/.." || exit 1

CYRIUS_HOME_DIR="${CYRIUS_HOME:-$HOME/.cyrius}"

warn() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::$*"; else echo "warning: $*"; fi
}
err() {
    if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error::$*"; else echo "error: $*"; fi
}
pin() {
    grep '^cyrius = ' cyrius.cyml | head -1 | sed 's/cyrius = "\(.*\)"/\1/'
}

# ---- pinned assertion totals (v1.1.4) -------------------------------------
# Every suite guards some assertions behind a precondition (a live signalfd,
# a real pty, an RLIMIT squeeze that took). Through v1.1.3 a guard that
# stopped holding made its assertions silently not run: in the 1.1.4 audit,
# breaking tty_open_signalfd outright dropped the unit suite from 238 to 232
# assertions — the v1.0.2 security regression test among them — and every
# gate stayed green. So each suite's TOTAL is pinned here, on every arch it
# runs on. Adding or removing an assertion means updating its pin in the
# same change, which is the point: a count that moves by itself is a test
# that stopped running.
EXPECT_UNIT=382
EXPECT_PTY=127
EXPECT_IDENTITY=28
EXPECT_AGNOS=27

# check_total <label> <expected> <file-with-suite-output>
check_total() {
    local got
    got="$(grep -oE '\(([0-9]+) total\)' "$3" | tail -1 | grep -oE '[0-9]+')"
    if [ -z "$got" ]; then err "$1: no 'N total' line in its output"; return 1; fi
    if [ "$got" != "$2" ]; then
        err "$1 ran $got assertions, expected $2 — an assertion stopped running (or the pin is stale)"
        return 1
    fi
    echo "$1: $got/$2 assertions ran"
}

# A 'SKIP pty:' token means the runner could not provide what the suite needs.
# Under CI (ubuntu-latest has /dev/ptmx) that is a failure; set
# DARSHANA_ALLOW_SKIP=1 to downgrade it to a warning on a degraded runner.
# Locally it is a warning, since a sandbox may legitimately lack a pty.
check_skip() {   # <label> <file>
    grep -q 'SKIP pty:' "$2" || return 0
    if [ -n "${GITHUB_ACTIONS:-}" ] && [ -z "${DARSHANA_ALLOW_SKIP:-}" ]; then
        err "$1 ran degraded (SKIP token present) — set DARSHANA_ALLOW_SKIP=1 if this runner cannot provide a pty"
        return 1
    fi
    warn "$1 ran degraded (SKIP token present) — coverage incomplete on this runner"
}

# cbuild <cyrius build args...> — `cyrius build`, with any `warning:` line
# FATAL (v1.1.4). Every target builds warning-free, so this costs nothing;
# without it a build that printed "duplicate fn ... (last definition wins)"
# — a Linux body silently compiled into the AGNOS build — stayed green.
cbuild() {
    local f rc
    f="$(mktemp)"
    cyrius build "$@" > "$f" 2>&1; rc=$?
    cat "$f"
    if [ $rc -eq 0 ] && grep -q 'warning:' "$f"; then
        err "build emitted a warning (fatal since v1.1.4): cyrius build $*"; rc=1
    fi
    rm -f "$f"
    return $rc
}

# run_suite <label> <expected-total> <command...> — run, always print, then
# require exit 0, the pinned total, no unsanctioned SKIP, and (for a
# `cyrius test` compile) no compiler warning.
run_suite() {
    local label="$1" want="$2" f rc
    shift 2
    f="$(mktemp)"
    "$@" > "$f" 2>&1; rc=$?
    cat "$f"
    [ $rc -eq 0 ] || { rm -f "$f"; return $rc; }
    check_total "$label" "$want" "$f" || { rm -f "$f"; return 1; }
    check_skip "$label" "$f" || { rm -f "$f"; return 1; }
    if grep -q 'warning:' "$f"; then
        err "$label: the compile emitted a warning (fatal since v1.1.4)"; rm -f "$f"; return 1
    fi
    rm -f "$f"
}

# ---- toolchain -----------------------------------------------------------
# Guards a successful-looking install that leaves no versions/<v>/lib
# snapshot, so every later cyrius invocation dies on dep resolution instead
# of here.
gate_toolchain() {
    local v; v="$(pin)"
    if [ ! -d "$CYRIUS_HOME_DIR/versions/$v/lib" ]; then
        err "stdlib snapshot missing at $CYRIUS_HOME_DIR/versions/$v/lib"
        return 1
    fi
    cyrius version || return 1
    echo "toolchain ok: pin $v, snapshot present"
}

# ---- deps ---------------------------------------------------------------
# darshana's own footprint is cyrius.cyml [deps].stdlib; `cyrius deps`
# resolves it into lib/. v1.1.4: `--verify` runs FIRST, against the
# committed lib/ and cyrius.lock. `cyrius deps` re-copies lib/ from the
# pinned snapshot, so run alone it silently repaired — and so hid — a
# committed hand-edit of a vendored file; `--verify` names the hash that
# disagrees instead.
gate_deps() {
    cyrius deps --verify || { err "lib/ does not match cyrius.lock (a vendored file was edited, or the lock is stale)"; return 1; }
    cyrius deps
}

# ---- smoke-binary --------------------------------------------------------
# Compile-link smoke: the include chain resolves end-to-end and the
# dead-code eliminator has not dropped a live symbol.
gate_smoke_binary() {
    mkdir -p build
    cbuild programs/smoke.cyr build/darshana-smoke || return 1
    local out; out="$(./build/darshana-smoke)"
    if [ "$out" != "darshana smoke ok" ]; then
        err "smoke output mismatch: $out"
        return 1
    fi
    echo "$out"
}

# ---- lint ----------------------------------------------------------------
# Same tolerance policy as chakshu/owl/cyim: every src file clean; the only
# acceptable warning is the cosmetic "exceeds 120 characters" rule on
# comment-divider lines. The exit status is not the verdict — cyrius 6.6.20
# exits 0 even when it prints warnings (checked) — so the filtered warning
# lines are.
gate_lint() {
    local fail=0 f out bad
    for f in src/*.cyr; do
        out="$(cyrius lint "$f" 2>&1 || true)"
        echo "$out"
        bad="$(echo "$out" | grep -E '^\s*warn ' | grep -v 'exceeds 120 characters' || true)"
        [ -n "$bad" ] && fail=1
    done
    [ $fail -eq 0 ] || { err "lint: non-cosmetic warnings present"; return 1; }
}

# ---- unit / pty / identity ----------------------------------------------
# Explicit paths: bare `cyrius test` auto-discovery has varied between cyrius
# releases (it failed in CI on 5.10.20 with "No .tcyr files found").
gate_unit() {
    run_suite "tests/darshana.tcyr" "$EXPECT_UNIT" cyrius test tests/darshana.tcyr
}

# The PTY harness manufactures its own pseudo-terminal. A 'SKIP pty:' token
# means the runner degraded (no pty, blocked ioctl) — fatal under CI since
# v1.1.4 (see check_skip). The output is ALWAYS printed: through v1.1.3 the
# YAML did `out=$(...)` under `bash -e`, so a failing harness aborted the
# step before its output was echoed, and CI showed a red step with no
# assertion named.
gate_pty() {
    run_suite "tests/pty.tcyr" "$EXPECT_PTY" cyrius test tests/pty.tcyr
}

# v1.1.4. Every `_buf` composer over its whole input domain into a poisoned
# guard region (nothing outside [pos, ret) may change; every call inside its
# documented byte budget; a rejection writes nothing), plus eleven frozen
# digests over everything darshana emits (ADR 0003). ~33.6M records.
gate_identity() {
    run_suite "tests/identity.tcyr" "$EXPECT_IDENTITY" cyrius test tests/identity.tcyr
}

# ---- examples ------------------------------------------------------------
# docs/examples/ is documentation that has to keep WORKING. Each example
# checks tty_isatty first and degrades cleanly, so running it without a TTY
# proves the include chain, the syscall surface and the no-TTY path.
gate_examples() {
    local fail=0 ex name out
    mkdir -p build
    for ex in docs/examples/*.cyr; do
        name="$(basename "$ex" .cyr)"
        echo "--- $name ---"
        cbuild "$ex" "build/example-$name" || { err "example failed to build: $ex"; fail=1; continue; }
        out="$("./build/example-$name" < /dev/null)" || { err "example exited non-zero: $ex"; fail=1; continue; }
        echo "$out"
        case "$out" in
            *"not a TTY"*) : ;;
            *) warn "$name did not take the no-TTY path; output was: $out" ;;
        esac

        # v1.1.4: the TTY path, too. Through v1.1.3 CI ran each example with
        # stdin from /dev/null only, so nothing past the isatty check ever
        # executed — an example that dropped tty_cooked() from its teardown
        # stayed green. Under script(1) the example gets a real pty, a 'q'
        # keypress drives it through the loop and the teardown, and the
        # transcript must show the alt screen entered AND left, and a final
        # line ending in CRLF — which only appears once tty_cooked() has
        # restored output processing (raw mode leaves a bare LF).
        if command -v script >/dev/null 2>&1; then
            # A file, not $(...): command substitution strips the trailing
            # newline, which is exactly the byte this check reads.
            local tty_out
            tty_out="build/example-$name.tty"
            printf 'q' | timeout 30 script -qec "./build/example-$name" /dev/null > "$tty_out" \
                || { err "$name exited non-zero (or hung) on the TTY path"; fail=1; continue; }
            if grep -qF "$(printf '\033[?1049h')" "$tty_out"; then
                if ! grep -qF "$(printf '\033[?1049l')" "$tty_out"; then
                    err "$name entered the alt screen and never left it"; fail=1; continue
                fi
                if [ "$(tail -c 2 "$tty_out" | od -An -c | tr -d ' ')" != '\r\n' ]; then
                    err "$name's last line is not CRLF-terminated: tty_cooked() did not run before exit"
                    fail=1; continue
                fi
            fi
            echo "$name: TTY path ok (alt screen left, terminal restored)"
        else
            warn "script(1) not found — $name's TTY path was not exercised"
        fi
    done
    [ $fail -eq 0 ] || { err "examples: build/run failures above"; return 1; }
}

# ---- agnos ---------------------------------------------------------------
# v1.0.2. `--agnos` emits an x86_64 ELF, so the test binary RUNS on a Linux
# host. See tests/agnos.tcyr's header for what it may not call: AGNOS
# tty_isatty / tty_winsize issue syscall 60, which is `exit` on Linux, so
# executing them would end the harness with status 0 and fake a pass.
gate_agnos() {
    mkdir -p build
    cbuild --agnos programs/smoke.cyr build/darshana-smoke-agnos || return 1
    cbuild --agnos tests/agnos.tcyr build/agnos-tests || return 1
    run_suite "tests/agnos.tcyr (--agnos)" "$EXPECT_AGNOS" ./build/agnos-tests
}

# ---- aarch64 -------------------------------------------------------------
# v1.1.0 / v1.1.1. The x86_64-linux release tarball ships bin/cycc_aarch64,
# and qemu-user runs the emitted ELFs, passing syscalls to the host kernel —
# so even the PTY harness drives a real pseudo-terminal. This is the only
# gate that sees an arch-blind syscall number; it has caught every one this
# project has shipped.
gate_aarch64() {
    local q out
    if [ ! -x "$CYRIUS_HOME_DIR/bin/cycc_aarch64" ]; then
        # Fail loudly: a check that quietly turns into a no-op is worse than
        # no check.
        err "cycc_aarch64 missing from the toolchain install — the aarch64 arm is unverified"
        return 1
    fi
    if command -v qemu-aarch64-static >/dev/null 2>&1; then q=qemu-aarch64-static
    elif command -v qemu-aarch64 >/dev/null 2>&1; then q=qemu-aarch64
    else err "no qemu-aarch64 / qemu-aarch64-static on PATH"; return 1
    fi
    mkdir -p build
    cbuild --aarch64 programs/smoke.cyr   build/darshana-smoke-a64 || return 1
    cbuild --aarch64 tests/darshana.tcyr  build/a64-unit           || return 1
    cbuild --aarch64 tests/pty.tcyr       build/a64-pty            || return 1
    cbuild --aarch64 tests/identity.tcyr  build/a64-identity       || return 1

    echo "--- smoke (aarch64) ---"
    out="$("$q" build/darshana-smoke-a64)"
    if [ "$out" != "darshana smoke ok" ]; then err "aarch64 smoke mismatch: $out"; return 1; fi
    echo "$out"

    echo "--- tests/darshana.tcyr (aarch64) ---"
    run_suite "tests/darshana.tcyr (aarch64)" "$EXPECT_UNIT" "$q" build/a64-unit || return 1

    echo "--- tests/pty.tcyr (aarch64) ---"
    run_suite "tests/pty.tcyr (aarch64)" "$EXPECT_PTY" "$q" build/a64-pty || return 1

    # The arch the unaligned wide stores were licensed on; digests must
    # match x86_64's exactly. ~80 s under qemu-user.
    echo "--- tests/identity.tcyr (aarch64) ---"
    run_suite "tests/identity.tcyr (aarch64)" "$EXPECT_IDENTITY" "$q" build/a64-identity
}

# ---- project-smoke -------------------------------------------------------
gate_project_smoke() {
    bash scripts/smoke.sh
}

# ---- distlib-drift -------------------------------------------------------
# Consumers `include "lib/darshana.cyr"` — dist/, not src/ — so src changes
# that land without a regenerated dist ship stale code. BOTH artifacts are
# compared (v1.0.2): the regeneration rewrites the sidecar too, so a stale
# committed dist/darshana.deps used to be destroyed before anything noticed.
# The committed bytes are restored either way, so a local run never leaves
# the tree modified.
gate_distlib_drift() {
    local tmp rc=0
    tmp="$(mktemp -d)"
    cp dist/darshana.cyr  "$tmp/darshana.cyr"
    cp dist/darshana.deps "$tmp/darshana.deps"
    if ! cyrius distlib > /dev/null; then rc=1; err "cyrius distlib failed"; fi
    if [ $rc -eq 0 ] && ! diff -q "$tmp/darshana.cyr" dist/darshana.cyr; then
        err "dist/darshana.cyr is stale. Run 'cyrius distlib' and commit."; rc=1
    fi
    if [ $rc -eq 0 ] && ! diff -q "$tmp/darshana.deps" dist/darshana.deps; then
        err "dist/darshana.deps is stale. Run 'cyrius distlib' and commit."; rc=1
    fi
    cp "$tmp/darshana.cyr"  dist/darshana.cyr
    cp "$tmp/darshana.deps" dist/darshana.deps
    rm -rf "$tmp"
    return $rc
}

# ---- dce -----------------------------------------------------------------
# Release builds set CYRIUS_DCE=1; the DCE'd smoke binary must behave like
# the debug build, or the pass dropped something live.
gate_dce() {
    local out
    mkdir -p build
    CYRIUS_DCE=1 cbuild programs/smoke.cyr build/darshana-smoke-dce || return 1
    echo "darshana-smoke-dce: $(wc -c < build/darshana-smoke-dce) bytes"
    out="$(./build/darshana-smoke-dce)"
    if [ "$out" != "darshana smoke ok" ]; then err "DCE smoke mismatch: $out"; return 1; fi
    # v1.1.4: programs/smoke.cyr calls no darshana function at all — under
    # DCE every one of the 29 is dead code there — so the binary above
    # proves the include chain and nothing about darshana. The suites DO
    # call the surface, so they run under DCE too, with their pinned totals.
    CYRIUS_DCE=1 run_suite "tests/darshana.tcyr (DCE)" "$EXPECT_UNIT" cyrius test tests/darshana.tcyr || return 1
    CYRIUS_DCE=1 run_suite "tests/pty.tcyr (DCE)" "$EXPECT_PTY" cyrius test tests/pty.tcyr
}

# ---- security ------------------------------------------------------------
# Pure shell — the CI security job installs no toolchain. CLAUDE.md's
# invariants: no FFI / libc; no >= 64 KiB stack buffers; platform gates
# positional and corpus-wide; the syscall ALLOWLIST. Both gates are
# mutation-proven on every run (--self-test): a gate that cannot fail proves
# nothing, and both have silently stopped checking their rule before.
gate_security() {
    local fail=0 hits big
    hits="$(grep -rnE 'include "lib/(cffi|dynlib|fdlopen|pam)\.cyr"' src/ 2>/dev/null || true)"
    if [ -n "$hits" ]; then err "FFI/dynlib/pam library import"; echo "$hits"; fail=1; fi

    big="$(awk '
        /var [A-Za-z_][A-Za-z0-9_]*\[[0-9]+\]/ {
            match($0, /\[[0-9]+\]/); s = substr($0, RSTART + 1, RLENGTH - 2); n = s + 0;
            if (n >= 65536) print FILENAME ":" FNR ": large stack buffer (" n " bytes): " $0
        }' src/*.cyr)"
    if [ -n "$big" ]; then err "large stack buffer"; echo "$big"; fail=1; fi

    bash scripts/platform-gate.sh             || fail=1
    bash scripts/platform-gate.sh --self-test || fail=1
    bash scripts/syscall-audit.sh --self-test || fail=1
    bash scripts/syscall-audit.sh             || fail=1
    echo "security scan complete (fail: $fail)"
    return $fail
}

# ---- docs ----------------------------------------------------------------
# Required files, and version consistency: VERSION is the single source of
# truth; the CHANGELOG must have its section and cyrius.cyml must still pull
# the version through ${file:VERSION} rather than a literal. (The dist
# header is regenerated from VERSION, so distlib-drift covers it.)
gate_docs() {
    local missing=0 f v
    for f in README.md CHANGELOG.md VERSION LICENSE cyrius.cyml cyrius.lock CLAUDE.md \
             docs/development/roadmap.md docs/development/state.md \
             docs/adr/0001-name-darshana.md docs/adr/0002-state-restore-posture.md \
             docs/adr/0003-v1-api-freeze.md docs/adr/0004-output-sanitization.md \
             docs/guides/upgrading.md dist/darshana.cyr dist/darshana.deps; do
        if [ -f "$f" ]; then echo "  OK: $f"; else echo "  MISSING: $f"; missing=1; fi
    done
    v="$(tr -d '[:space:]' < VERSION)"
    if ! grep -qE "^## \[${v}\]" CHANGELOG.md; then
        err "CHANGELOG.md missing section [${v}]"; missing=1
    fi
    if ! grep -qE '^version *= *"\$\{file:VERSION\}"' cyrius.cyml; then
        err "cyrius.cyml version no longer pulls from VERSION"; missing=1
    fi
    [ $missing -eq 0 ] && echo "Version consistent: VERSION = CHANGELOG = cyrius.cyml = $v"

    # CI wiring (v1.1.4): every gate in this script must be called by
    # ci.yml, and ci.yml may call no gate this script lacks — otherwise a
    # gate added here never runs in CI, which is a gate in name only.
    local listed called
    listed="$(for g in $ALL_GATES; do echo "$g"; done | sort)"
    called="$(grep -oE 'scripts/ci\.sh [a-z0-9-]+' .github/workflows/ci.yml | awk '{print $2}' | sort -u)"
    if [ "$listed" != "$called" ]; then
        err "ci.yml and scripts/ci.sh disagree on the gate list"
        diff <(echo "$listed") <(echo "$called") | sed 's/^/    /'
        missing=1
    else
        echo "  OK: ci.yml calls every scripts/ci.sh gate ($(echo "$listed" | wc -l))"
    fi
    return $missing
}

# ---- driver --------------------------------------------------------------
# Order matches CI: the build-and-test job's steps, then the security and
# docs jobs (which CI runs in parallel).
ALL_GATES="toolchain deps smoke-binary lint unit pty identity examples agnos aarch64 project-smoke distlib-drift dce security docs"

run_gate() {
    local fn="gate_${1//-/_}"
    if ! declare -F "$fn" >/dev/null; then err "unknown gate: $1 (try --list)"; return 2; fi
    echo "===== $1 ====="
    "$fn"
}

if [ $# -eq 0 ]; then
    echo "usage: bash scripts/ci.sh <gate>... | all | --list" >&2
    exit 2
fi

if [ "$1" = "--list" ]; then
    for g in $ALL_GATES; do echo "$g"; done
    exit 0
fi

if [ "$1" = "all" ]; then
    failed=""
    for g in $ALL_GATES; do
        run_gate "$g" || failed="$failed $g"
    done
    echo
    if [ -z "$failed" ]; then echo "ci.sh: all gates passed"; exit 0; fi
    echo "ci.sh: FAILED:$failed"
    exit 1
fi

for g in "$@"; do
    run_gate "$g" || { echo "ci.sh: gate '$g' failed"; exit 1; }
done
