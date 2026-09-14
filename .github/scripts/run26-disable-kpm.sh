#!/usr/bin/env bash
set -Eeuo pipefail

KERNEL_DIR="$GITHUB_WORKSPACE/$KERNEL_REL"
cd "$KERNEL_DIR"
exec > >(tee "$GITHUB_WORKSPACE/run26-disable-kpm.log") 2>&1

echo '===== RUN26 ReSukiSU: force CONFIG_KPM off ====='
test -f "$OUT_DIR/.config"
test -x scripts/config

./scripts/config --file "$OUT_DIR/.config" -d KPM
# Droidspaces: PID/IPC 命名空间 + devtmpfs（MUST/REQUIRED）
./scripts/config --file "$OUT_DIR/.config" -e SYSVIPC
./scripts/config --file "$OUT_DIR/.config" -e SYSVIPC_SYSCTL
./scripts/config --file "$OUT_DIR/.config" -e PID_NS
./scripts/config --file "$OUT_DIR/.config" -e IPC_NS
./scripts/config --file "$OUT_DIR/.config" -e DEVTMPFS
# ./scripts/config --file "$OUT_DIR/.config" -e DEVTMPFS_MOUNT   # 可选，见下
 ./scripts/config --file "$OUT_DIR/.config" -e USER_NS          # 可选，见下
|| true

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
