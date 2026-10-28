#!/bin/sh
# agnos-live.sh — darshana's AGNOS arm on a real agnos kernel, in QEMU (v1.5.0).
#
# tests/agnos.tcyr runs on the Linux host, where an agnos syscall reaches
# the Linux kernel under another number, so it can test only the AGNOS
# paths that make no call. This runs tests/agnos_live.cyr on agnos itself:
# it builds the suite with `--agnos`, seeds it as /bin/agnsh on an ext2
# root next to an agnos kernel and gnoboot, boots that image in QEMU, and
# scores the suite's output from the serial log (agnos writes the
# console's output to COM1). The image recipe is agnos's own harness
# recipe (agnos scripts/harness/tty-test.py).
#
# Not a CI gate: it needs an agnos kernel build, which a runner does not
# have. It is a release step, like the Raspberry Pi run (state.md).
#
# Inputs, read and never modified:
#   AGNOS_KERNEL  default ${SIBLINGS_ROOT:-..}/agnos/build/agnos (>= 1.57.13)
#   GNOBOOT_EFI   default ${SIBLINGS_ROOT:-..}/gnoboot/build/BOOTX64.EFI
#   OVMF          the edk2 / OVMF firmware the distribution installs
# Env: LIVE_TIMEOUT seconds to wait for one boot (default 120);
#      LIVE_TRIES boots before giving up as VOID (default 4);
#      SMOKE_KVM=0 to use TCG even when /dev/kvm is writable.
# Writes only build/agnos-live/ (the image, the binary, serial.log).
# Exit: 0 every check passed · 1 a check failed · 2 VOID (an input is
# missing, or the boot never reached the suite: nothing was measured).

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIB="${SIBLINGS_ROOT:-$ROOT/..}"
KERNEL="${AGNOS_KERNEL:-$SIB/agnos/build/agnos}"
EFI="${GNOBOOT_EFI:-$SIB/gnoboot/build/BOOTX64.EFI}"
TIMEOUT="${LIVE_TIMEOUT:-120}"
MIN_AGNOS="1.57.13"
# The suite's assertion total, pinned like scripts/ci.sh's: a count that
# moves by itself is a check that stopped running.
EXPECT_LIVE=57

void() { echo "agnos-live: VOID — $1 (nothing was measured)" >&2; exit 2; }
fail() { echo "agnos-live: FAIL — $1" >&2; exit 1; }

[ -f "$KERNEL" ] || void "no agnos kernel at $KERNEL (set AGNOS_KERNEL)"
[ -f "$EFI" ] || void "no gnoboot at $EFI (set GNOBOOT_EFI)"
for t in cyrius qemu-system-x86_64 parted sgdisk mformat mmd mcopy mkfs.ext2 strings; do
    command -v "$t" >/dev/null 2>&1 || void "$t is not installed"
done
OVMF_CODE=""; OVMF_VARS=""
for c in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2/x64/OVMF_CODE.fd \
         /usr/share/OVMF/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd; do
    [ -f "$c" ] && { OVMF_CODE="$c"; break; }
done
for c in /usr/share/edk2/x64/OVMF_VARS.4m.fd /usr/share/edk2/x64/OVMF_VARS.fd \
         /usr/share/OVMF/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS_4M.fd; do
    [ -f "$c" ] && { OVMF_VARS="$c"; break; }
done
[ -n "$OVMF_CODE" ] && [ -n "$OVMF_VARS" ] || void "no OVMF firmware found"

KVER=$(strings "$KERNEL" | grep -m1 -oE 'AGNOS kernel v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/.* v//')
[ -n "$KVER" ] || void "cannot read the kernel version from $KERNEL"
[ "$(printf '%s\n%s\n' "$MIN_AGNOS" "$KVER" | sort -V | head -1)" = "$MIN_AGNOS" ] \
    || void "agnos $KVER predates $MIN_AGNOS, which added console_mode#110 and fd_kind#111"
echo "agnos-live: kernel v$KVER ($KERNEL)"

WORK="$ROOT/build/agnos-live"
rm -rf "$WORK"
mkdir -p "$WORK/seed/bin"
cyrius build --agnos "$ROOT/tests/agnos_live.cyr" "$WORK/seed/bin/agnsh" > "$WORK/build.log" 2>&1 \
    || fail "the --agnos build failed (see $WORK/build.log)"
grep -qiE '[1-9][0-9]* warnings?' "$WORK/build.log" && fail "the --agnos build warned (see $WORK/build.log)"

# ESP 1-33 MiB (gnoboot + kernel), ext2 33-100 MiB seeded with the suite.
IMG="$WORK/live.img"
run() { "$@" > /dev/null 2>> "$WORK/image.log" || fail "image step failed: $* (see $WORK/image.log)"; }
run dd if=/dev/zero of="$IMG" bs=1M count=128 status=none
run parted -s "$IMG" mklabel gpt mkpart ESP fat32 1MiB 33MiB set 1 esp on mkpart agnos-fs ext2 33MiB 100MiB
run sgdisk -t 2:8300 "$IMG"
run mformat -i "$IMG@@1048576" -F
run mmd -i "$IMG@@1048576" ::EFI ::EFI/BOOT ::boot
run mcopy -i "$IMG@@1048576" "$EFI" ::EFI/BOOT/BOOTX64.EFI
run mcopy -i "$IMG@@1048576" "$KERNEL" ::boot/agnos
run mkfs.ext2 -F -q -L DARSHANA-LIVE -b 4096 -m 0 \
    -O '^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg' \
    -d "$WORK/seed" -E offset=$((33 * 1048576)) "$IMG" $(((67 * 1048576) / 4096))
ACCEL="-cpu max"
if [ -w /dev/kvm ] && [ "${SMOKE_KVM:-1}" = "1" ]; then ACCEL="-enable-kvm -cpu host"; fi
SER="$WORK/serial.log"

# One boot. Echoes END (the suite finished), HUNG (it started and never
# finished: a failure), or VOID (firmware never handed off to agnos, or
# nothing arrived in time: retried, never scored). agnos's own harnesses
# meet the same OVMF boot menu now and then and retry it the same way.
boot() {
    cp "$OVMF_VARS" "$WORK/vars.fd" && chmod +w "$WORK/vars.fd"
    : > "$SER"
    # shellcheck disable=SC2086
    qemu-system-x86_64 -machine q35 -m 512M $ACCEL -smp 1 \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,file="$WORK/vars.fd" \
        -drive file="$IMG",format=raw,if=none,id=disk0 -device nvme,drive=disk0,serial=DARSHANA-LIVE \
        -serial file:"$SER" -display none -no-reboot > "$WORK/qemu.log" 2>&1 &
    QPID=$!
    trap 'kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null' EXIT INT TERM
    _r=VOID
    _t=0
    while [ "$_t" -lt "$TIMEOUT" ]; do
        if grep -q 'DARSHANA-LIVE-END' "$SER"; then _r=END; break; fi
        if grep -qE 'BootManagerMenuApp|Please select boot device|gnoboot: fail @' "$SER"; then break; fi
        kill -0 "$QPID" 2>/dev/null || break
        sleep 1
        _t=$((_t + 1))
    done
    kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null
    trap - EXIT INT TERM
    if [ "$_r" = VOID ] && grep -q 'DARSHANA-LIVE-BEGIN' "$SER"; then _r=HUNG; fi
    echo "$_r"
}

TRIES="${LIVE_TRIES:-4}"
n=1
while :; do
    r=$(boot)
    [ "$r" = VOID ] || break
    echo "agnos-live: boot $n never reached the suite (VOID), retrying" >&2
    [ "$n" -lt "$TRIES" ] || void "no boot of $TRIES reached the suite (last serial log: $SER)"
    n=$((n + 1))
done
[ "$r" = END ] || fail "the suite started but never finished within ${TIMEOUT}s (serial log: $SER)"

OUT=$(tr -d '\r' < "$SER" | awk '/DARSHANA-LIVE-BEGIN/ { on = 1 } on { print } /DARSHANA-LIVE-END/ { exit }')
printf '%s\n' "$OUT"
printf '%s\n' "$OUT" | grep -q "^$EXPECT_LIVE passed, 0 failed ($EXPECT_LIVE total)\$" \
    || fail "expected $EXPECT_LIVE passed, 0 failed ($EXPECT_LIVE total)"
echo "agnos-live: PASS ($EXPECT_LIVE assertions on agnos v$KVER)"
