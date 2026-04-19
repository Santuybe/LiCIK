#!/bin/bash
#
# Compile script for LiCIK kernel - t0lte
# Optimized for Samsung Galaxy Note II (Exynos 4412)
# Merged with make-koffee.sh logic

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

if ! [ -d "$TC_DIR" ]; then
    echo "Downloading GCC 4.9 for ARM..."
    mkdir -p "$TC_DIR"
    GIT_TERMINAL_PROMPT=0 git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 "$TC_DIR"
fi

export PATH="$TC_DIR/bin:$PATH"
TOOLCHAIN_PREFIX="$TC_DIR/bin/arm-linux-androideabi-"

# Patch Makefile
sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-$DEVICE/" Makefile
if ! grep -q "^EXTRAVERSION =" Makefile; then
    sed -i "/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-$DEVICE" Makefile
fi

mkdir -p out
make O=out ARCH=arm CROSS_COMPILE="$TOOLCHAIN_PREFIX" $DEFCONFIG

# Merge features if requested
if [[ "$1" == "droidspace" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm/configs/droidspacest0lte.config arch/arm/configs/droidspaces.config arch/arm/configs/droidspaces-additional.config
    make O=out ARCH=arm CROSS_COMPILE="$TOOLCHAIN_PREFIX" olddefconfig
elif [[ "$1" == "nethunter" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm/configs/nethunter.config
    make O=out ARCH=arm CROSS_COMPILE="$TOOLCHAIN_PREFIX" olddefconfig
fi

# Metadata from make-koffee.sh
REVISION=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_USER=${USER:-"LiCIK-CI"}
BUILD_DATE=$(date)

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm \
    CROSS_COMPILE="$TOOLCHAIN_PREFIX" \
    KBUILD_BUILD_USER="$BUILD_USER" \
    KBUILD_BUILD_VERSION="1" \
    zImage || exit $?

# Build Modules (from make-koffee.sh)
echo -e "\nBuilding modules...\n"
make -j$(nproc --all) O=out ARCH=arm \
    CROSS_COMPILE="$TOOLCHAIN_PREFIX" \
    KBUILD_BUILD_USER="$BUILD_USER" \
    KBUILD_BUILD_VERSION="1" \
    modules || exit $?

kernel="out/arch/arm/boot/zImage"

if [ -f "$kernel" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"

    # Download AnyKernel3 template from the specific commit and directory
    echo "Downloading AnyKernel3 template..."
    wget -q https://github.com/html6405/android_kernel_samsung_smdk4412/archive/2a4f865d94e35f2b7bac491168fdd8e79ea71d75.zip -O source.zip
    unzip -q source.zip
    cp -r android_kernel_samsung_smdk4412-*/anykernel_boeffla-t0lte AnyKernel3
    rm -rf source.zip android_kernel_samsung_smdk4412-*

    cp $kernel AnyKernel3/zImage

    # Process modules (from make-koffee.sh)
    echo "Processing modules..."
    MODULES_PATH="AnyKernel3/modules"
    mkdir -p "$MODULES_PATH"
    find out -name '*.ko' -exec cp -av {} "$MODULES_PATH" \;
    chmod 0644 "$MODULES_PATH"/*
    "${TOOLCHAIN_PREFIX}strip" --strip-unneeded "$MODULES_PATH"/* 2>/dev/null

    cd AnyKernel3

    # Metadata patching for update-binary (from make-koffee.sh)
    if [ -f "META-INF/com/google/android/update-binary" ]; then
        echo "Patching installer metadata..."
        KERNELNAME="Flashing LiCIK kernel ($FEAT)"
        COPYRIGHT_SCRIPT="(c) html6405 × LiCIK, $(date +%Y)"
        COPYRIGHT="(c) html6405, 2022"
        BUILDINFO="Revision $REVISION, $BUILD_DATE"
        SOURCECODE="Source code: https://github.com/html6405/android_kernel_samsung_smdk4412"

        sed -i "s;###kernelname###;${KERNELNAME};" META-INF/com/google/android/update-binary
        sed -i "s;###copyright_script###;${COPYRIGHT_SCRIPT};" META-INF/com/google/android/update-binary
        sed -i "s;###copyright###;${COPYRIGHT};" META-INF/com/google/android/update-binary
        sed -i "s;###buildinfo###;${BUILDINFO};" META-INF/com/google/android/update-binary
        sed -i "s;###sourcecode###;${SOURCECODE};" META-INF/com/google/android/update-binary
    fi

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
