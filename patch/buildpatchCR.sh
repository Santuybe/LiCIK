#!/bin/bash

BUILD_SCRIPT=$1
DEVICE=$2
KERNEL_ROOT=$(dirname "$BUILD_SCRIPT")
MAKEFILE="$KERNEL_ROOT/Makefile"

if [ -z "$DEVICE" ]; then
    echo "Error: Device name not provided!"
    echo "Usage: $0 [build.sh path] [device_name]"
    exit 1
fi

if [ -f "$BUILD_SCRIPT" ]; then
    echo "Patching $BUILD_SCRIPT for $DEVICE (Droidspaces inline)..."

    # Update DEFCONFIG in build.sh
    # Standard format: DEFCONFIG="surya_defconfig"
    # We change it to "${DEVICE}_defconfig" or similar
    # For santoni it might be santoni_defconfig. Let's assume [device]_defconfig
    sed -i "s/^DEFCONFIG=.*/DEFCONFIG=\"${DEVICE}_defconfig\"/" "$BUILD_SCRIPT"

    # Insert droidspaces.config and droidspaces-additional.config into the make command
    # We use regex to find 'make ... $DEFCONFIG' and append the configs
    sed -i 's/\(make[[:space:]].*\$DEFCONFIG\)/\1 droidspaces.config droidspaces-additional.config/' "$BUILD_SCRIPT"

    # Replace ZIPNAME prefix from Shinigami to LiCIK
    # Standard format: ZIPNAME="Shinigami-surya-$(date '+%Y%m%d-%H%M').zip"
    sed -i "s/ZIPNAME=\"Shinigami-[^-]*/ZIPNAME=\"LiCIK-$DEVICE/" "$BUILD_SCRIPT"

    # Add banner patching logic after AnyKernel3 is cloned in build.sh
    # We look for 'cd AnyKernel3' and append our banner patch
    if ! grep -q "CiLIK Kernel" "$BUILD_SCRIPT"; then
        sed -i "/cd AnyKernel3/a \	sed -i 's/.*$/CiLIK Kernel - $DEVICE build/' banner" "$BUILD_SCRIPT"
    fi

    echo "Patching build.sh completed."
else
    echo "Error: File $BUILD_SCRIPT not found!"
    exit 1
fi

if [ -f "$MAKEFILE" ]; then
    echo "Patching $MAKEFILE for kernel versioning..."

    # Check if EXTRAVERSION exists
    if grep -q "^EXTRAVERSION =" "$MAKEFILE"; then
        sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-$DEVICE/" "$MAKEFILE"
    else
        # Insert after SUBLEVEL
        sed -i "/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-$DEVICE" "$MAKEFILE"
    fi

    echo "Patching Makefile completed."
else
    echo "Warning: Makefile not found at $MAKEFILE"
fi
