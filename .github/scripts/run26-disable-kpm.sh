#!/usr/bin/env bash
set -Eeuo pipefail

KERNEL_DIR="$GITHUB_WORKSPACE/$KERNEL_REL"
cd "$KERNEL_DIR"
exec > >(tee "$GITHUB_WORKSPACE/run26-disable-kpm.log") 2>&1

echo '===== RUN26 ReSukiSU: force CONFIG_KPM off ====='
test -f "$OUT_DIR/.config"
test -x scripts/config

./scripts/config --file "$OUT_DIR/.config" -d KPM
# Droidspaces: PID/IPC
./scripts/config --file "$OUT_DIR/.config" -e SYSVIPC
./scripts/config --file "$OUT_DIR/.config" -e SYSVIPC_SYSCTL
./scripts/config --file "$OUT_DIR/.config" -e PID_NS
./scripts/config --file "$OUT_DIR/.config" -e IPC_NS
./scripts/config --file "$OUT_DIR/.config" -e DEVTMPFS
# ./scripts/config --file "$OUT_DIR/.config" -e DEVTMPFS_MOUNT
./scripts/config --file "$OUT_DIR/.config" -e USER_NS || true
# Docker/droidspaces: POSIX message queues needed for /dev/mqueue mounts
./scripts/config --file "$OUT_DIR/.config" -e POSIX_MQUEUE
./scripts/config --file "$OUT_DIR/.config" -e POSIX_MQUEUE_SYSCTL || true
# ---- Docker (runc/containerd) requirements beyond droidspaces ----
# device cgroup: fixes "bpf_prog_query(BPF_CGROUP_DEVICE) failed: invalid argument"
# runc needs an available device controller; enable both v1 (CGROUP_DEVICE) path.
./scripts/config --file "$OUT_DIR/.config" -e CGROUP_DEVICE
./scripts/config --file "$OUT_DIR/.config" -e CGROUP_PIDS
# CFS_BANDWIDTH_SCHED not present in this trinket 4.14 tree; skip (only affects --cpu-quota)
./scripts/config --file "$OUT_DIR/.config" -e CHECKPOINT_RESTORE || true
./scripts/config --file "$OUT_DIR/.config" -e FHANDLE || true

unset LLVM LLVM_IAS KBUILD_COMPILER_STRING
make O="$OUT_DIR" ARCH=arm64 LOCALVERSION=+ \
  CC="${CC:-}" REAL_CC="${REAL_CC:-}" LD="${LD:-}" \
  CROSS_COMPILE="${CROSS_COMPILE:-}" \
  CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32:-}" \
  CLANG_TRIPLE="${CLANG_TRIPLE:-}" olddefconfig || make O="$OUT_DIR" ARCH=arm64 olddefconfig

! grep -q '^CONFIG_KPM=y$' "$OUT_DIR/.config"
grep -q '^CONFIG_KSU=y$' "$OUT_DIR/.config"
grep -q '^CONFIG_KSU_SUSFS=y$' "$OUT_DIR/.config"

{
  echo 'kpm=disabled'
  echo 'reason=resukisu_no_longer_supports_kpm'
  echo 'config_ksu=y'
  echo 'config_ksu_susfs=y'
} | tee "$GITHUB_WORKSPACE/run26-disable-kpm-proof.txt"

echo '[PASS] ReSukiSU build has CONFIG_KPM disabled'
