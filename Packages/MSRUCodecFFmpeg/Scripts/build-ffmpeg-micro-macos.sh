#!/bin/bash

set -euo pipefail


# ============================================================
# MSRU FFmpeg Micro
#
# macOS arm64
#
# 只构建：
# - libavcodec
# - libavutil
# - libswresample
# - DCA / DTS decoder
# - DCA parser
#
# 不包含：
# - ffmpeg CLI
# - ffplay
# - ffprobe
# - AV1
# - H264
# - HEVC
# - subtitles
# - networking
# - video filters
# - external libraries
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

BUILD_DIR="$BUILD_ROOT/build"

INSTALL_DIR="$BUILD_ROOT/install"

VENDOR_DIR="$PACKAGE_DIR/Vendor"

HEADERS_DIR="$BUILD_ROOT/Headers"

COMBINED_LIBRARY="$BUILD_ROOT/libMSRUFFmpegMicro.a"

XCFRAMEWORK="$VENDOR_DIR/MSRUFFmpegMicro.xcframework"


# ============================================================
# Version
# ============================================================

FFMPEG_VERSION="9.0.2"

ARCHIVE_NAME="ffmpeg-${FFMPEG_VERSION}.tar.xz"

ARCHIVE_URL="https://ffmpeg.org/releases/${ARCHIVE_NAME}"

ARCHIVE_PATH="$BUILD_ROOT/$ARCHIVE_NAME"


# ============================================================
# Toolchain
# ============================================================

SDK_PATH="$(
    xcrun --sdk macosx --show-sdk-path
)"

CC="$(
    xcrun --sdk macosx --find clang
)"

AR="$(
    xcrun --sdk macosx --find ar
)"

RANLIB="$(
    xcrun --sdk macosx --find ranlib
)"


CPU_COUNT="$(
    sysctl -n hw.ncpu
)"


echo
echo "============================================================"
echo "MSRU FFmpeg Micro"
echo "============================================================"
echo
echo "FFmpeg:       $FFMPEG_VERSION"
echo "SDK:          $SDK_PATH"
echo "Compiler:     $CC"
echo "Architecture: arm64"
echo


# ============================================================
# Clean
# ============================================================

rm -rf "$BUILD_ROOT"

mkdir -p "$BUILD_ROOT"

mkdir -p "$VENDOR_DIR"


rm -rf "$XCFRAMEWORK"


# ============================================================
# Download
# ============================================================

echo
echo "→ Download FFmpeg"
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


mkdir -p "$BUILD_DIR"

mkdir -p "$INSTALL_DIR"


# ============================================================
# Configure
# ============================================================

echo
echo "→ Configure Micro Build"
echo


cd "$BUILD_DIR"


"$SOURCE_ROOT/configure" \
    --prefix="$INSTALL_DIR" \
    \
    --target-os=darwin \
    --arch=arm64 \
    \
    --cc="$CC" \
    --ar="$AR" \
    --ranlib="$RANLIB" \
    \
    --sysroot="$SDK_PATH" \
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
    --extra-cflags="-arch arm64 -mmacosx-version-min=15.0" \
    --extra-ldflags="-arch arm64 -mmacosx-version-min=15.0"


# ============================================================
# Build
# ============================================================

echo
echo "→ Build"
echo


make \
    -j"$CPU_COUNT"


echo
echo "→ Install"
echo


make install


# ============================================================
# Verify
# ============================================================

echo
echo "→ Verify libraries"
echo


test -f "$INSTALL_DIR/lib/libavcodec.a"

test -f "$INSTALL_DIR/lib/libavutil.a"

test -f "$INSTALL_DIR/lib/libswresample.a"


echo
echo "libavcodec:"
du -h "$INSTALL_DIR/lib/libavcodec.a"


echo
echo "libavutil:"
du -h "$INSTALL_DIR/lib/libavutil.a"


echo
echo "libswresample:"
du -h "$INSTALL_DIR/lib/libswresample.a"


# ============================================================
# Merge Static Libraries
# ============================================================

echo
echo "→ Merge static libraries"
echo


xcrun libtool \
    -static \
    -o "$COMBINED_LIBRARY" \
    "$INSTALL_DIR/lib/libavcodec.a" \
    "$INSTALL_DIR/lib/libswresample.a" \
    "$INSTALL_DIR/lib/libavutil.a"


echo
echo "Combined:"
du -h "$COMBINED_LIBRARY"


# ============================================================
# Prepare Public Headers
# ============================================================

echo
echo "→ Prepare headers"
echo


mkdir -p "$HEADERS_DIR"


cp -R \
    "$INSTALL_DIR/include/libavcodec" \
    "$HEADERS_DIR/"


cp -R \
    "$INSTALL_DIR/include/libavutil" \
    "$HEADERS_DIR/"


cp -R \
    "$INSTALL_DIR/include/libswresample" \
    "$HEADERS_DIR/"


# ============================================================
# Umbrella Header
# ============================================================

cat > "$HEADERS_DIR/MSRUFFmpegMicro.h" <<'EOF'
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


# ============================================================
# Module Map
# ============================================================

cat > "$HEADERS_DIR/module.modulemap" <<'EOF'
module MSRUFFmpegMicro [system] {

    umbrella header "MSRUFFmpegMicro.h"

    export *
}
EOF


# ============================================================
# Create Static-Library XCFramework
# ============================================================

echo
echo "→ Create XCFramework"
echo


xcodebuild \
    -create-xcframework \
    \
    -library "$COMBINED_LIBRARY" \
    -headers "$HEADERS_DIR" \
    \
    -output "$XCFRAMEWORK"


# ============================================================
# License
# ============================================================

mkdir -p "$VENDOR_DIR/Licenses"


if [
    -f "$SOURCE_ROOT/COPYING.LGPLv2.1"
]; then

    cp \
        "$SOURCE_ROOT/COPYING.LGPLv2.1" \
        "$VENDOR_DIR/Licenses/"
fi


if [
    -f "$SOURCE_ROOT/COPYING.LGPLv3"
]; then

    cp \
        "$SOURCE_ROOT/COPYING.LGPLv3" \
        "$VENDOR_DIR/Licenses/"
fi


# ============================================================
# Final Verification
# ============================================================

echo
echo "→ Final artifact"
echo


find \
    "$XCFRAMEWORK" \
    -maxdepth 4 \
    -print


echo
echo "============================================================"
echo "MSRU FFmpeg Micro ✓"
echo "============================================================"
echo
echo "$XCFRAMEWORK"
echo
