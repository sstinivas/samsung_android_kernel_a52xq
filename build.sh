#!/bin/bash
#
# Usage:
#   ./build.sh          # fast dev build: Image.gz only (incremental, ccache)
#   ./build.sh full     # release build: Image.gz + dtbs + modules
#   ./build.sh clean    # wipe out/ (ccache survives — it's in ~/.ccache)
#
set -euo pipefail
cd "$(dirname "$0")"

export ARCH=arm64
export PROJECT_NAME=a52xq

ROOT=$(pwd)
OUT="$ROOT/out"
mkdir -p "$OUT"

export CROSS_COMPILE="$ROOT/toolchain/toolchains-gcc-10.3.0/bin/aarch64-buildroot-linux-gnu-"
CLANG_BIN="$ROOT/toolchain/clang/host/linux-x86/clang-r383902/bin/clang"

if command -v ccache >/dev/null 2>&1; then
    export CC="ccache $CLANG_BIN"
    export HOSTCC="ccache gcc"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-10G}"
else
    export CC="$CLANG_BIN"
    echo "NOTE: ccache not found — install it for much faster rebuilds" >&2
fi

export CLANG_TRIPLE=aarch64-linux-gnu-

MAKE="$ROOT/make-4.3/bin/make"
if [ ! -x "$MAKE" ]; then
    echo "ERROR: $MAKE not found/executable." >&2
    echo "This kernel requires GNU Make 4.3 in make-4.3/bin/ at the kernel root." >&2
    exit 1
fi
MAKE_VERSION=$("$MAKE" --version | head -n1)
case "$MAKE_VERSION" in
    *"GNU Make 4.3"*) echo "Using $MAKE_VERSION" ;;
    *) echo "WARNING: expected GNU Make 4.3, got: $MAKE_VERSION" >&2 ;;
esac
export MAKE

KERNEL_MAKE_ENV="DTC_EXT=$ROOT/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"

export KCFLAGS="-w"
export CONFIG_DRV_BUILD_IN=Y

CORES=$(nproc)
RAM_GB=$(awk '/MemTotal/ {print int($2/1048576)}' /proc/meminfo)
JOBS=$(( CORES < RAM_GB ? CORES : RAM_GB ))
[ "$JOBS" -lt 1 ] && JOBS=1
echo "Building with -j$JOBS (cores=$CORES ram=${RAM_GB}GB)"

MAKE_ARGS=(-C "$ROOT" O="$OUT" $KERNEL_MAKE_ENV KCFLAGS="$KCFLAGS" -j"$JOBS")

case "${1:-dev}" in
    clean)
        rm -rf "$OUT"
	make mrproper
        echo "out/ wiped. ccache kept (ccache --zero-stats to reset it too)."
        exit 0
        ;;
    full)
        TARGETS=(Image dtbs modules)
        ;;
    dev|"")
        TARGETS=(Image.gz)
        ;;
    *)
        echo "usage: $0 [dev|full|clean]" >&2
        exit 1
        ;;
esac

if [ ! -f "$OUT/.config" ] || [ arch/arm64/configs/a52xq_defconfig -nt "$OUT/.config" ]; then
    "$MAKE" "${MAKE_ARGS[@]}" a52xq_defconfig
fi
"$MAKE" "${MAKE_ARGS[@]}" uapi-asm-generic
"$MAKE" "${MAKE_ARGS[@]}" asm-generic
"$MAKE" "${MAKE_ARGS[@]}" prepare

time "$MAKE" "${MAKE_ARGS[@]}" "${TARGETS[@]}"

cp "$OUT/arch/arm64/boot/Image" "$ROOT/arch/arm64/boot/Image"

echo
echo "Done: $OUT/arch/arm64/boot/Image"
ls -lh "$OUT/arch/arm64/boot/Image"
