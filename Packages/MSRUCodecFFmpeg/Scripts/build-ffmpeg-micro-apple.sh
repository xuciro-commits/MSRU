#!/bin/bash

set -euo pipefail


# ============================================================
# MSRU FFmpeg Micro — Apple Platforms
#
# Builds:
#
#   macOS
#       arm64
#
#   iOS Device
#       arm64
#
#   iOS Simulator
#       arm64
#       x86_64
#
# FFmpeg configuration:
#
#   libavcodec
#   libavutil
#   libswresample
#   DCA / DTS decoder
#   DCA parser
#
# Everything else remains disabled.
# ============================================================


# ============================================================
# Error reporting
# ============================================================

trap '
status=$?
echo
echo "============================================================"
echo "MSRU FFmpeg Micro BUILD FAILED"
echo "Line:    $LINENO"
echo "Command: $BASH_COMMAND"
echo "Status:  $status"
echo "============================================================"
exit $status
' ERR


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(
    cd "$(dirname "$0")"
    pwd
)"

PACKAGE_DIR="$(
    cd "$SCRIPT_DIR/.."
    pwd
)"

BUILD_ROOT="$PACKAGE_DIR/.build-ffmpeg"

SOURCE_ROOT="$BUILD_ROOT/source"

TARGET_ROOT="$BUILD_ROOT/targets"

VENDOR_DIR="$PACKAGE_DIR/Vendor"

XCFRAMEWORK="$VENDOR_DIR/MSRUFFmpegMicro.xcframework"


# ============================================================
# Versions
# ============================================================

FFMPEG_VERSION="9.0.2"

MACOS_MIN_VERSION="15.0"

IOS_MIN_VERSION="18.0"

ARCHIVE_NAME="ffmpeg-${FFMPEG_VERSION}.tar.xz"

ARCHIVE_URL="https://ffmpeg.org/releases/${ARCHIVE_NAME}"

ARCHIVE_PATH="$BUILD_ROOT/$ARCHIVE_NAME"


# ============================================================
# Host
# ============================================================

CPU_COUNT="$(
    sysctl -n hw.ncpu
)"


# ============================================================
# Intro
# ============================================================

echo
echo "============================================================"
echo "MSRU FFmpeg Micro — Apple"
echo "============================================================"
echo
echo "FFmpeg:        $FFMPEG_VERSION"
echo "macOS min:     $MACOS_MIN_VERSION"
echo "iOS min:       $IOS_MIN_VERSION"
echo
echo "Targets:"
echo "  macOS             arm64"
echo "  iOS               arm64"
echo "  iOS Simulator     arm64"
echo "  iOS Simulator     x86_64"
echo


# ============================================================
# Clean
# ============================================================

echo "→ Clean"

rm -rf "$BUILD_ROOT"

mkdir -p "$BUILD_ROOT"
mkdir -p "$TARGET_ROOT"
mkdir -p "$VENDOR_DIR"

rm -rf "$XCFRAMEWORK"


# ============================================================
# Download
# ============================================================

echo
echo "→ Download FFmpeg $FFMPEG_VERSION"
echo

curl \
    --fail \
    --location \
    --output "$ARCHIVE_PATH" \
    "$ARCHIVE_URL"


# ============================================================
# Extract
# ============================================================

echo
echo "→ Extract FFmpeg"
echo

mkdir -p "$SOURCE_ROOT"

tar \
    -xf "$ARCHIVE_PATH" \
    -C "$SOURCE_ROOT" \
    --strip-components=1


# ============================================================
# Build one architecture
#
# Arguments:
#
#   $1 identifier
#   $2 SDK
#   $3 architecture
#   $4 deployment compiler flag
#   $5 disable x86 asm: yes / no
# ============================================================

build_target() {

    local identifier="$1"
    local sdk="$2"
    local arch="$3"
    local deployment_flag="$4"
    local disable_x86asm="$5"


    local target_dir="$TARGET_ROOT/$identifier"

    local build_dir="$target_dir/build"

    local install_dir="$target_dir/install"

    local headers_dir="$target_dir/Headers"

    local combined_library="$target_dir/libMSRUFFmpegMicro.a"


    local sdk_path
    local cc
    local ar
    local ranlib


    sdk_path="$(
        xcrun \
            --sdk "$sdk" \
            --show-sdk-path
    )"


    cc="$(
        xcrun \
            --sdk "$sdk" \
            --find clang
    )"


    ar="$(
        xcrun \
            --sdk "$sdk" \
            --find ar
    )"


    ranlib="$(
        xcrun \
            --sdk "$sdk" \
            --find ranlib
    )"


    echo
    echo "============================================================"
    echo "Build target: $identifier"
    echo "============================================================"
    echo
    echo "SDK:          $sdk"
    echo "SDK path:     $sdk_path"
    echo "Architecture: $arch"
    echo "Compiler:     $cc"
    echo


    mkdir -p "$build_dir"
    mkdir -p "$install_dir"
    mkdir -p "$headers_dir"


    # ========================================================
    # Optional architecture configuration
    # ========================================================

    local extra_config=""


    if [[ "$disable_x86asm" == "yes" ]]; then

        extra_config="--disable-x86asm"

    fi


    # ========================================================
    # Configure
    # ========================================================

    echo "→ Configure $identifier"
    echo


    cd "$build_dir"


    "$SOURCE_ROOT/configure" \
        --prefix="$install_dir" \
        \
        --target-os=darwin \
        --arch="$arch" \
        \
        --cc="$cc" \
        --ar="$ar" \
        --ranlib="$ranlib" \
        \
        --sysroot="$sdk_path" \
        \
        --enable-cross-compile \
        \
        --disable-shared \
        --enable-static \
        --enable-pic \
        \
        --disable-programs \
        --disable-doc \
        --disable-debug \
        \
        --disable-network \
        --disable-autodetect \
        \
        --disable-avdevice \
        --disable-avfilter \
        --disable-avformat \
        --disable-swscale \
        \
        --enable-avcodec \
        --enable-avutil \
        --enable-swresample \
        \
        --disable-everything \
        \
        --enable-decoder=dca \
        --enable-parser=dca \
        \
        $extra_config \
        \
        --extra-cflags="-arch $arch $deployment_flag" \
        --extra-ldflags="-arch $arch $deployment_flag"


    # ========================================================
    # Build
    # ========================================================

    echo
    echo "→ Build $identifier"
    echo


    make \
        -j"$CPU_COUNT"


    # ========================================================
    # Install
    # ========================================================

    echo
    echo "→ Install $identifier"
    echo


    make install


    # ========================================================
    # Verify libraries
    # ========================================================

    echo
    echo "→ Verify $identifier"
    echo


    test \
        -f "$install_dir/lib/libavcodec.a"


    test \
        -f "$install_dir/lib/libavutil.a"


    test \
        -f "$install_dir/lib/libswresample.a"


    # ========================================================
    # Merge static libraries
    # ========================================================

    echo
    echo "→ Merge $identifier"
    echo


    xcrun libtool \
        -static \
        -o "$combined_library" \
        "$install_dir/lib/libavcodec.a" \
        "$install_dir/lib/libswresample.a" \
        "$install_dir/lib/libavutil.a"


    "$ranlib" \
        "$combined_library"


    # ========================================================
    # Headers
    # ========================================================

    echo
    echo "→ Prepare headers $identifier"
    echo


    cp -R \
        "$install_dir/include/libavcodec" \
        "$headers_dir/"


    cp -R \
        "$install_dir/include/libavutil" \
        "$headers_dir/"


    cp -R \
        "$install_dir/include/libswresample" \
        "$headers_dir/"


    # ========================================================
    # Umbrella Header
    # ========================================================

    cat > "$headers_dir/MSRUFFmpegMicro.h" <<'EOF'
#ifndef MSRU_FFMPEG_MICRO_H
#define MSRU_FFMPEG_MICRO_H

#include <libavcodec/avcodec.h>
#include <libavcodec/codec.h>
#include <libavcodec/codec_id.h>
#include <libavcodec/packet.h>

#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/mathematics.h>
#include <libavutil/samplefmt.h>

#include <libswresample/swresample.h>

#endif
EOF


    # ========================================================
    # Module Map
    # ========================================================

    cat > "$headers_dir/module.modulemap" <<'EOF'
module MSRUFFmpegMicro [system] {

    umbrella header "MSRUFFmpegMicro.h"

    export *
}
EOF


    # ========================================================
    # Result
    # ========================================================

    echo
    echo "→ Built $identifier"
    echo


    file \
        "$combined_library"


    du \
        -h "$combined_library"
}


# ============================================================
# macOS arm64
# ============================================================

build_target \
    "macos-arm64" \
    "macosx" \
    "arm64" \
    "-mmacosx-version-min=${MACOS_MIN_VERSION}" \
    "no"


# ============================================================
# iOS Device arm64
# ============================================================

build_target \
    "ios-arm64" \
    "iphoneos" \
    "arm64" \
    "-miphoneos-version-min=${IOS_MIN_VERSION}" \
    "no"


# ============================================================
# iOS Simulator arm64
# ============================================================

build_target \
    "ios-simulator-arm64" \
    "iphonesimulator" \
    "arm64" \
    "-mios-simulator-version-min=${IOS_MIN_VERSION}" \
    "no"


# ============================================================
# iOS Simulator x86_64
#
# Disable handwritten x86 assembly so MSRU does not require
# nasm/yasm for this small DTS-only build.
# ============================================================

build_target \
    "ios-simulator-x86_64" \
    "iphonesimulator" \
    "x86_64" \
    "-mios-simulator-version-min=${IOS_MIN_VERSION}" \
    "yes"


# ============================================================
# Merge iOS Simulator architectures
# ============================================================

echo
echo "============================================================"
echo "Create iOS Simulator universal library"
echo "============================================================"
echo


SIMULATOR_ROOT="$TARGET_ROOT/ios-simulator-universal"

SIMULATOR_LIBRARY="$SIMULATOR_ROOT/libMSRUFFmpegMicro.a"

SIMULATOR_HEADERS="$SIMULATOR_ROOT/Headers"


mkdir -p "$SIMULATOR_ROOT"


lipo \
    -create \
    "$TARGET_ROOT/ios-simulator-arm64/libMSRUFFmpegMicro.a" \
    "$TARGET_ROOT/ios-simulator-x86_64/libMSRUFFmpegMicro.a" \
    -output "$SIMULATOR_LIBRARY"


rm -rf "$SIMULATOR_HEADERS"


cp -R \
    "$TARGET_ROOT/ios-simulator-arm64/Headers" \
    "$SIMULATOR_HEADERS"


xcrun ranlib \
    "$SIMULATOR_LIBRARY"


echo "→ Simulator architectures"

lipo \
    -info "$SIMULATOR_LIBRARY"


# ============================================================
# Create XCFramework
# ============================================================

echo
echo "============================================================"
echo "Create XCFramework"
echo "============================================================"
echo


xcodebuild \
    -create-xcframework \
    \
    -library \
        "$TARGET_ROOT/macos-arm64/libMSRUFFmpegMicro.a" \
    -headers \
        "$TARGET_ROOT/macos-arm64/Headers" \
    \
    -library \
        "$TARGET_ROOT/ios-arm64/libMSRUFFmpegMicro.a" \
    -headers \
        "$TARGET_ROOT/ios-arm64/Headers" \
    \
    -library \
        "$SIMULATOR_LIBRARY" \
    -headers \
        "$SIMULATOR_HEADERS" \
    \
    -output \
        "$XCFRAMEWORK"


# ============================================================
# Licenses
# ============================================================

echo
echo "→ Copy licenses"
echo


LICENSE_DIR="$VENDOR_DIR/Licenses"

mkdir -p "$LICENSE_DIR"


if [[ -f "$SOURCE_ROOT/COPYING.LGPLv2.1" ]]; then

    cp \
        "$SOURCE_ROOT/COPYING.LGPLv2.1" \
        "$LICENSE_DIR/"

fi


if [[ -f "$SOURCE_ROOT/COPYING.LGPLv3" ]]; then

    cp \
        "$SOURCE_ROOT/COPYING.LGPLv3" \
        "$LICENSE_DIR/"

fi


# ============================================================
# Final Verification
# ============================================================

echo
echo "============================================================"
echo "Verify XCFramework"
echo "============================================================"
echo


plutil \
    -p "$XCFRAMEWORK/Info.plist"


echo
echo "Libraries:"
echo


find \
    "$XCFRAMEWORK" \
    -type f \
    -name '*.a' \
    -print


echo
echo "Architectures:"
echo


while IFS= read -r library
do

    echo
    echo "$library"

    lipo \
        -info "$library"

done < <(
    find \
        "$XCFRAMEWORK" \
        -type f \
        -name '*.a' \
        -print
)


# ============================================================
# DCA Verification
# ============================================================

echo
echo "DCA symbols:"
echo


while IFS= read -r library
do

    echo
    echo "$library"


    nm \
        "$library" \
        2>/dev/null \
        |
        grep -E \
            'ff_dca_decoder|avpriv_dca_convert_bitstream' \
        |
        head \
            -10 \
        ||
        true

done < <(
    find \
        "$XCFRAMEWORK" \
        -type f \
        -name '*.a' \
        -print
)


# ============================================================
# Complete
# ============================================================

echo
echo "============================================================"
echo "MSRU FFmpeg Micro — Apple ✓"
echo "============================================================"
echo
echo "$XCFRAMEWORK"
echo
