#!/bin/bash

BUILD_SCRIPT=$1

if [ -f "$BUILD_SCRIPT" ]; then
    echo "Patching $BUILD_SCRIPT menggunakan metode inline config..."

    # Cari baris yang menjalankan make defconfig dan tambahkan file config droidspaces di belakangnya
    # Contoh perubahan: make surya_defconfig -> make surya_defconfig droidspaces.config droidspaces-additional.config
    sed -i 's/\(make.*_defconfig\)/\1 droidspaces.config droidspaces-additional.config/' "$BUILD_SCRIPT"

    echo "Patching selesai."
else
    echo "Error: $BUILD_SCRIPT tidak ditemukan!"
    exit 1
fi
