#!/bin/bash

BUILD_SCRIPT=$1
KERNEL_ROOT=$(dirname "$BUILD_SCRIPT")
MAKEFILE="$KERNEL_ROOT/Makefile"

if [ -f "$BUILD_SCRIPT" ]; then
    echo "Patching $BUILD_SCRIPT for crDroid surya (Droidspaces inline)..."

    # Insert droidspaces.config and droidspaces-additional.config into the make command
    # We use regex to find 'make ... $DEFCONFIG' and append the configs
    sed -i 's/\(make[[:space:]].*\$DEFCONFIG\)/\1 droidspaces.config droidspaces-additional.config/' "$BUILD_SCRIPT"

    # Replace ZIPNAME prefix from Shinigami to LiCIK
    sed -i 's/ZIPNAME="Shinigami/ZIPNAME="LiCIK/' "$BUILD_SCRIPT"

    echo "Patching build.sh completed."
else
    echo "Error: File $BUILD_SCRIPT not found!"
    exit 1
fi

if [ -f "$MAKEFILE" ]; then
    echo "Patching $MAKEFILE for kernel versioning..."

    # Check if EXTRAVERSION exists
    if grep -q "^EXTRAVERSION =" "$MAKEFILE"; then
        sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION = -LiCIK-surya/' "$MAKEFILE"
    else
        # Insert after SUBLEVEL
        sed -i '/^SUBLEVEL =/a EXTRAVERSION = -LiCIK-surya' "$MAKEFILE"
    fi

    echo "Patching Makefile completed."
else
    echo "Warning: Makefile not found at $MAKEFILE"
fi
