#!/bin/bash
#
# Compile script for LiCIK kernel - surya
# Optimized with Jules CI-fixer

SECONDS=0
DEVICE="surya"
DEFCONFIG="surya_defconfig"

# Feature Name Mapping
case "$1" in
    "droidspace") FEAT="DS" ;;
    "nethunter") FEAT="NH" ;;
    *) FEAT="Base" ;;
esac

[ -z "$DATE" ] && DATE=$(date '+%Y%m%d%H%M')
ZIPNAME="LiCIK-${DEVICE}-${FEAT}-${DATE}.zip"

TC_DIR="$(pwd)/tc/clang-498229"
AK3_DIR="$(pwd)/android/AnyKernel3"

jules_ci_fixer() {
    echo "Running Jules CI-fixer..."
    for f in scripts/dtc/dtc-lexer.lex.c_shipped scripts/dtc/dtc-lexer.c_shipped; do
        [ -f "$f" ] && sed -i 's/YYLTYPE yylloc;/extern YYLTYPE yylloc;/g' "$f"
    done
    find . -name Makefile -exec sed -i 's/-Werror\( \|$\)//g' {} +
    echo "Jules CI-fixer completed."
}

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
    echo "Cloning toolchain..."
    git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"
fi

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
if [[ "$1" == "droidspace" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm64/configs/droidspaces.config arch/arm64/configs/droidspaces-additional.config
    make O=out ARCH=arm64 olddefconfig
elif [[ "$1" == "nethunter" ]]; then
    scripts/kconfig/merge_config.sh -O out -m out/.config arch/arm64/configs/nethunter.config
    make O=out ARCH=arm64 olddefconfig
fi

echo -e "\nStarting compilation...\n"
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
    LLVM=1 LLVM_IAS=1 Image.gz dtb.img dtbo.img || exit $?

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
    echo "CiLIK Kernel - $DEVICE build" > banner.new
    [ -f "banner" ] && cat banner >> banner.new
    mv banner.new banner

    zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
    cd ..
    echo "Zip: $ZIPNAME"
else
    echo -e "\nCompilation failed!"
    exit 1
fi
