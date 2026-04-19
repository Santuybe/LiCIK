#!/bin/bash
#
# Compile script for LiCIK kernel - msm8937 (LineageOS)
# Based on original script by Adithya R.
# Optimized with Jules CI-fixer

SECONDS=0 # builtin bash timer
DEVICE="msm8937"
DEFCONFIG="msm8937_defconfig"
ZIPNAME="LiCIK-${DEVICE}-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-498229"
AK3_DIR="$(pwd)/android/AnyKernel3"

# Jules CI-fixer: Fixes common build errors in CI environments
jules_ci_fixer() {
    echo "Running Jules CI-fixer..."

    # 1. Fix multiple definition of yylloc (common with modern bison)
    if [ -f "scripts/dtc/dtc-lexer.lex.c_shipped" ]; then
        sed -i 's/YYLTYPE yylloc;/extern YYLTYPE yylloc;/g' scripts/dtc/dtc-lexer.lex.c_shipped
    fi

    # 2. Remove -Werror to prevent failures on warnings
    find . -name Makefile -exec sed -i 's/-Werror//g' {} +

    # 3. Fix scripts/config.c if needed (common on newer hosts)
    if [ -f "scripts/mod/mk_elfconfig.c" ]; then
        sed -i 's/defined(elf_nf)/defined(__elf_nf)/g' scripts/mod/mk_elfconfig.c || true
    fi

    echo "Jules CI-fixer completed."
}

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

# Apply Fixes
jules_ci_fixer

# Patch Makefile for branding dynamically
sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-$DEVICE/" Makefile
if ! grep -q "^EXTRAVERSION =" Makefile; then
    sed -i "/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-$DEVICE" Makefile
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG $FEATURE_CONFIGS

echo -e "\nStarting compilation...\n"
# msm8937 might need different Image targets or CC/LD flags depending on kernel version
# We use a broad set of LLVM tools as provided in the toolchain
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AS=llvm-as \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    LLVM=1 LLVM_IAS=1 Image.gz dtb.img dtbo.img || \
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AS=llvm-as \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    LLVM=1 LLVM_IAS=1 Image.gz-dtb || \
make -j$(nproc --all) O=out ARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AS=llvm-as \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-gnu- \
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

dtb="out/arch/arm64/boot/dtb.img"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -n "$kernel" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    else
        git clone -q https://github.com/surya-aosp/AnyKernel3 -b shinigami AnyKernel3
    fi
    cp $kernel AnyKernel3/Image.gz 2>/dev/null || cp $kernel AnyKernel3/
    [ -f "$dtb" ] && cp "$dtb" AnyKernel3/
    [ -f "$dtbo" ] && cp "$dtbo" AnyKernel3/

    cd AnyKernel3
    # Patch Banner
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
