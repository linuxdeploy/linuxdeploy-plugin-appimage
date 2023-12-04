#! /bin/bash

set -euxo pipefail

# use RAM disk if possible
if [ "${CI:-}" == "" ] && [ -d /docker-ramdisk ]; then
    TEMP_BASE=/docker-ramdisk
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" linuxdeploy-plugin-appimage-build-XXXXXX)

cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT="$(readlink -f "$(dirname "$(dirname "$0")")")"
OLD_CWD="$(readlink -f .)"

pushd "$BUILD_DIR"

bash "$REPO_ROOT"/ci/build-bundle.sh

mv linuxdeploy-plugin-appimage-bundle AppDir

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage
chmod +x linuxdeploy-"$ARCH".AppImage

export UPD_INFO="gh-releases-zsync|linuxdeploy|linuxdeploy-plugin-appimage|continuous|linuxdeploy-plugin-appimage-$ARCH.AppImage"

# deploy linuxdeploy-plugin-appimage
./linuxdeploy-"$ARCH".AppImage --appimage-extract-and-run \
     --appdir AppDir -d "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.svg

AppDir/AppRun --appdir AppDir

mv linuxdeploy-plugin-appimage*.AppImage* "$OLD_CWD"/
