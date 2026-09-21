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
#   visionOS Device
#       arm64
#   visionOS Simulator
#       arm64 / x86_64
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

# Keep installed binaries intact until every build and verification succeeds.
BUILD_CACHE="$PACKAGE_DIR/.build-ffmpeg"
LOCK_DIR="$PACKAGE_DIR/.build-ffmpeg.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Another build owns $LOCK_DIR; inspect it before retrying." >&2
    exit 1
fi
STAGING_VENDOR=""
BACKUP_VENDOR=""
INSTALLED_VENDOR="$PACKAGE_DIR/Vendor"
cleanup() {
    local status=$?
    if [[ -n "$BACKUP_VENDOR" && -d "$BACKUP_VENDOR" ]]; then
        if [[ ! -e "$INSTALLED_VENDOR" ]]; then
            mv "$BACKUP_VENDOR" "$INSTALLED_VENDOR" || return 1
        elif [[ $status -eq 0 ]]; then
            rm -rf "$BACKUP_VENDOR"
        fi
    fi
    if [[ -n "$STAGING_VENDOR" && -d "$STAGING_VENDOR" ]]; then
        rm -rf "$STAGING_VENDOR"
    fi
    rmdir "$LOCK_DIR"
    return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$BUILD_CACHE"
BUILD_ROOT="$(mktemp -d "$BUILD_CACHE/run.XXXXXX")"
STAGING_VENDOR="$(mktemp -d "$PACKAGE_DIR/.vendor-stage.XXXXXX")"
BACKUP_VENDOR="$STAGING_VENDOR.previous"
if [[ -d "$INSTALLED_VENDOR" ]]; then
    cp -R "$INSTALLED_VENDOR/." "$STAGING_VENDOR/"
fi

SOURCE_ROOT="$BUILD_ROOT/source"

TARGET_ROOT="$BUILD_ROOT/targets"

VENDOR_DIR="$STAGING_VENDOR"

XCFRAMEWORK="$VENDOR_DIR/MSRUFFmpegMicro.xcframework"


# ============================================================
# Versions
# ============================================================

FFMPEG_VERSION="9.0.2"

MACOS_MIN_VERSION="15.0"

IOS_MIN_VERSION="18.0"
VISIONOS_MIN_VERSION="2.0"

ARCHIVE_NAME="ffmpeg-${FFMPEG_VERSION}.tar.xz"

ARCHIVE_URL="https://ffmpeg.org/releases/${ARCHIVE_NAME}"

ARCHIVE_PATH="$BUILD_CACHE/$ARCHIVE_NAME"


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
echo "  visionOS          arm64"
echo "  visionOS Simulator arm64 + x86_64"
echo


# ============================================================
# Clean
# ============================================================

echo "→ Clean"

# Each run has its own directory; retain failed compiler logs for diagnosis.
# Only remove the copied framework inside the staging directory.

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

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    curl --fail --location --output "$BUILD_ROOT/$ARCHIVE_NAME.partial" "$ARCHIVE_URL"
    mv "$BUILD_ROOT/$ARCHIVE_NAME.partial" "$ARCHIVE_PATH"
else
    echo "→ Reuse cached $ARCHIVE_NAME"
fi


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
        --disable-swscale \
        \
        --enable-avcodec \
        --enable-avformat \
        --enable-avutil \
        --enable-swresample \
        \
        --disable-everything \
        \
        --enable-protocol=file \
        --enable-demuxer=dts,dtshd,ape,dsf,iff \
        --enable-decoder=dca,ape,dsd_lsbf,dsd_msbf,dsd_lsbf_planar,dsd_msbf_planar \
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
        -f "$install_dir/lib/libavformat.a"


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
        "$install_dir/lib/libavformat.a" \
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
        "$install_dir/include/libavformat" \
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

#include <libavformat/avformat.h>
#include <libavformat/avio.h>

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


# visionOS uses target triples rather than iOS deployment flags.
build_target "xros-arm64" "xros" "arm64" \
    "-target arm64-apple-xros${VISIONOS_MIN_VERSION}" "no"
build_target "xros-simulator-arm64" "xrsimulator" "arm64" \
    "-target arm64-apple-xros${VISIONOS_MIN_VERSION}-simulator" "no"
build_target "xros-simulator-x86_64" "xrsimulator" "x86_64" \
    "-target x86_64-apple-xros${VISIONOS_MIN_VERSION}-simulator" "yes"


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


XROS_SIMULATOR_ROOT="$TARGET_ROOT/xros-simulator-universal"
mkdir -p "$XROS_SIMULATOR_ROOT"
lipo -create \
    "$TARGET_ROOT/xros-simulator-arm64/libMSRUFFmpegMicro.a" \
    "$TARGET_ROOT/xros-simulator-x86_64/libMSRUFFmpegMicro.a" \
    -output "$XROS_SIMULATOR_ROOT/libMSRUFFmpegMicro.a"
cp -R "$TARGET_ROOT/xros-simulator-arm64/Headers" "$XROS_SIMULATOR_ROOT/Headers"
xcrun ranlib "$XROS_SIMULATOR_ROOT/libMSRUFFmpegMicro.a"

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
    -library "$TARGET_ROOT/xros-arm64/libMSRUFFmpegMicro.a" \
    -headers "$TARGET_ROOT/xros-arm64/Headers" \
    -library "$XROS_SIMULATOR_ROOT/libMSRUFFmpegMicro.a" \
    -headers "$XROS_SIMULATOR_ROOT/Headers" \
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
# Symbol Verification (Fail-fast Gate)
# ============================================================

echo
echo "Verifying required symbols across all libraries..."
echo

REQUIRED_SYMBOLS=(
    "ff_dca_decoder"
    "ff_ape_decoder"
    "ff_dsd_lsbf_decoder"
    "ff_dsd_msbf_decoder"
    "ff_dsd_lsbf_planar_decoder"
    "ff_dsd_msbf_planar_decoder"
    "ff_dts_demuxer"
    "ff_ape_demuxer"
    "ff_dsf_demuxer"
    "ff_iff_demuxer"
    "ff_file_protocol"
)

while IFS= read -r library
do
    echo "Checking $library..."
    for sym in "${REQUIRED_SYMBOLS[@]}"; do
        if ! nm "$library" 2>/dev/null | grep -E " [TSD] _?${sym}$" >/dev/null; then
            echo "ERROR: Required symbol '$sym' missing in $library" >&2
            exit 1
        fi
    done
    echo "  ✓ All required symbols present"
done < <(
    find \
        "$XCFRAMEWORK" \
        -type f \
        -name '*.a' \
        -print
)


# Publish only after all commands above have succeeded. EXIT restores the previous
# vendor directory if publication fails between the two same-filesystem renames.
if [[ -e "$INSTALLED_VENDOR" ]]; then
    mv "$INSTALLED_VENDOR" "$BACKUP_VENDOR"
fi
mv "$STAGING_VENDOR" "$INSTALLED_VENDOR"
echo "Installed: $INSTALLED_VENDOR/MSRUFFmpegMicro.xcframework"

# ============================================================
# Complete
# ============================================================

echo
echo "============================================================"
echo "MSRU FFmpeg Micro — Apple ✓"
echo "============================================================"
echo
echo "$INSTALLED_VENDOR/MSRUFFmpegMicro.xcframework"
echo
