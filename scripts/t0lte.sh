#!/bin/bash
#
# Compile script for LiCIK kernel - t0lte
# Optimized for Samsung Galaxy Note II (Exynos 4412)

SECONDS=0
DEVICE="t0lte"
DEFCONFIG="lineageos_t0lte_defconfig"

# Feature Name Mapping
case "$1" in
    "droidspace") FEAT="DS" ;;
    "nethunter") FEAT="NH" ;;
    *) FEAT="Base" ;;
esac

[ -z "$DATE" ] && DATE=$(date '+%Y%m%d%H%M')
ZIPNAME="LiCIK-${DEVICE}-${FEAT}-${DATE}.zip"

TC_DIR="$(pwd)/tc/gcc-4.9-arm"
AK3_DIR="$(pwd)/android/AnyKernel3"

if ! [ -d "$TC_DIR" ]; then
    echo "Downloading GCC 4.9 for ARM..."
    mkdir -p "$TC_DIR"
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 "$TC_DIR"
fi

export PATH="$TC_DIR/bin:$PATH"

# Patch Makefile
sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-$DEVICE/" Makefile
if ! grep -q "^EXTRAVERSION =" Makefile; then
    sed -i "/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-$DEVICE" Makefile
fi

mkdir -p out
make O=out ARCH=arm CROSS_COMPILE=arm-linux-androideabi- $DEFCONFIG

# Merge features if requested
if [[ "$1" == "droidspace" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm/configs/droidspacest0lte.config arch/arm/configs/droidspaces.config arch/arm/configs/droidspaces-additional.config
    make O=out ARCH=arm CROSS_COMPILE=arm-linux-androideabi- olddefconfig
elif [[ "$1" == "nethunter" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm/configs/nethunter.config
    make O=out ARCH=arm CROSS_COMPILE=arm-linux-androideabi- olddefconfig
fi

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm \
    CROSS_COMPILE=arm-linux-androideabi- \
    zImage || exit $?

kernel="out/arch/arm/boot/zImage"

if [ -f "$kernel" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"

    rm -rf AnyKernel3
    if [ -d "$AK3_DIR" ]; then
        cp -r "$AK3_DIR" AnyKernel3
    else
        mkdir -p "$(dirname "$AK3_DIR")"
        git clone -q https://github.com/osm0sis/AnyKernel3 "$AK3_DIR"
        cp -r "$AK3_DIR" AnyKernel3
    fi
    curl -Ls https://raw.githubusercontent.com/html6405/android_kernel_samsung_smdk4412/refs/heads/lineage-21.0/anykernel_boeffla-t0lte/anykernel.sh -o AnyKernel3/anykernel.sh

    cp $kernel AnyKernel3/zImage

    cd AnyKernel3
    echo "LiCIK Kernel - $DEVICE $FEAT build" > banner.new
    [ -f "banner" ] && cat banner >> banner.new
    mv banner.new banner

    zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
    cd ..
    echo "Zip: $ZIPNAME"
else
    echo -e "\nCompilation failed!"
    exit 1
fi
