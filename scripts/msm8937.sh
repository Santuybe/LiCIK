#!/bin/bash
#
# Compile script for LiCIK kernel - msm8937
# Optimized with Jules CI-fixer

SECONDS=0
DEVICE="msm8937"
FEATURE="$1"
DEFCONFIG="vendor/msm8937_defconfig"
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
[ -z "$DATE" ] && DATE=$(date '+%Y%m%d%H%M')
ZIPNAME="LiCIK-${DEVICE}-${FEATURE}-${COMMIT_HASH}-${DATE}.zip"
TC_DIR="$(pwd)/tc/neutron-clang"
GCC_DIR="$(pwd)/tc/gcc"
AK3_DIR="$(pwd)/android/AnyKernel3"

jules_ci_fixer() {
    echo "Running Jules CI-fixer..."
    for f in scripts/dtc/dtc-lexer.lex.c_shipped scripts/dtc/dtc-lexer.c_shipped; do
        [ -f "$f" ] && sed -i 's/YYLTYPE yylloc;/extern YYLTYPE yylloc;/g' "$f"
    done
    find . -name Makefile -exec sed -i 's/-Werror\( \|$\)//g' {} +
    echo "Jules CI-fixer completed."
}

if ! [ -d "$TC_DIR" ]; then
    echo "Downloading Neutron Clang..."
    mkdir -p "$TC_DIR"
    cd "$TC_DIR"
    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman -S
    ./antman --patch=glibc
    cd ../..
fi

if ! [ -d "$GCC_DIR" ]; then
    echo "Downloading ARM GNU Toolchain..."
    mkdir -p "$GCC_DIR"
    cd "$GCC_DIR"
    wget -q https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
    tar -xf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
    cd ../..
fi

export PATH="$TC_DIR/bin:$GCC_DIR/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin:$PATH"

jules_ci_fixer

# Patch Makefile
sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-$DEVICE/" Makefile
if ! grep -q "^EXTRAVERSION =" Makefile; then
    sed -i "/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-$DEVICE" Makefile
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG
make O=out ARCH=arm64 olddefconfig

# Merge features if requested
if [[ "$FEATURE" == "droidspace" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm64/configs/droidspaces.config arch/arm64/configs/droidspaces-additional.config
    make O=out ARCH=arm64 olddefconfig
elif [[ "$FEATURE" == "nethunter" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm64/configs/nethunter.config
    make O=out ARCH=arm64 olddefconfig
fi

# Enable KernelSU if present and not nethunter
if [[ "$FEATURE" != "nethunter" ]] && [ -d "drivers/kernelsu" ]; then
    echo "Enabling KernelSU..."
    if [ -f "arch/arm64/configs/ksu.config" ]; then
        scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm64/configs/ksu.config
    else
        echo "ksu.config not found in arch/arm64/configs/! Enabling manually..."
        echo "CONFIG_KSU=y" >> out/.config
    fi
    make O=out ARCH=arm64 olddefconfig
fi

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    AS=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-none-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    LLVM=1 LLVM_IAS=1 Image.gz || \
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    AS=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-none-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    LLVM=1 LLVM_IAS=1 Image.gz-dtb || \
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    AS=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-none-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    LLVM=1 LLVM_IAS=1 Image-dtb || \
exit $?

kernel=""
for f in out/arch/arm64/boot/Image.gz-dtb out/arch/arm64/boot/Image-dtb out/arch/arm64/boot/Image.gz; do
    if [ -f "$f" ]; then
        kernel="$f"
        break
    fi
done

if [ -n "$kernel" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    else
        git clone -q https://github.com/mi-msm8937/AnyKernel3 -b mi8937 AnyKernel3
    fi
    cp $kernel AnyKernel3/Image.gz 2>/dev/null || cp $kernel AnyKernel3/
    [ -f "out/arch/arm64/boot/dtb.img" ] && cp "out/arch/arm64/boot/dtb.img" AnyKernel3/
    [ -f "out/arch/arm64/boot/dtbo.img" ] && cp "out/arch/arm64/boot/dtbo.img" AnyKernel3/

    cd AnyKernel3
    echo "CiLIK Kernel - $DEVICE ($FEATURE) build" > banner.new
    [ -f "banner" ] && cat banner >> banner.new
    mv banner.new banner

    zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
    cd ..
    echo "Zip: $ZIPNAME"
else
    echo -e "\nCompilation failed!"
    exit 1
fi
