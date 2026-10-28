#!/bin/bash

export ARCH=arm64
export PROJECT_NAME=a52xq
mkdir out

export CROSS_COMPILE=$(pwd)/toolchain/toolchains-gcc-10.3.0/bin/aarch64-buildroot-linux-gnu-
export CC=$(pwd)/toolchain/clang/host/linux-x86/clang-r383902/bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y"

export KCFLAGS=-w
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y
export CONFIG_DRV_BUILD_IN=Y
make -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y a52xq_defconfig
make -C $(pwd) O=$(pwd)/out $KERNEL_MAKE_ENV KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y -j16


cp out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image
