#!/bin/bash
#
# Compile script for LiCIK kernel - msm8937
# Based on original script by Adithya R.

SECONDS=0 # builtin bash timer
DEVICE="msm8937"
DEFCONFIG="msm8937_defconfig"
ZIPNAME="LiCIK-${DEVICE}-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-498229"
AK3_DIR="$(pwd)/android/AnyKernel3"

# Feature configs
FEATURE_CONFIGS=""
if [[ "$1" == "droidspace" ]]; then
    FEATURE_CONFIGS="droidspaces.config droidspaces-additional.config"
elif [[ "$1" == "nethunter" ]]; then
    FEATURE_CONFIGS="nethunter.config"
fi

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
    echo "Cloning toolchain..."
    git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"
fi

# Patch Makefile for branding dynamically (handles existing EXTRAVERSION)
sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-$DEVICE/" Makefile
if ! grep -q "^EXTRAVERSION =" Makefile; then
    sed -i "/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-$DEVICE" Makefile
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG $FEATURE_CONFIGS

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 Image.gz dtb.img dtbo.img || exit $?

kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dtb.img"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    else
        git clone -q https://github.com/surya-aosp/AnyKernel3 -b shinigami AnyKernel3
    fi
    cp $kernel $dtb $dtbo AnyKernel3/ 2>/dev/null || cp $kernel AnyKernel3/

    cd AnyKernel3
    # Patch Banner without destroying ASCII art
    echo "CiLIK Kernel - $DEVICE build" > banner.new
    cat banner >> banner.new
    mv banner.new banner

    zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
    cd ..
    echo "Zip: $ZIPNAME"
else
    echo -e "\nCompilation failed!"
    exit 1
fi
