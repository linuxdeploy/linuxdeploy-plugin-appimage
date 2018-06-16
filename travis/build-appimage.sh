#! /bin/bash

set -e
set -x

# use RAM disk if possible
if [ "$BIONIC" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" AppImageUpdate-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname $0)))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/usr -DUSE_CCACHE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo

make -j$(nproc)

make install DESTDIR=AppDir

# bundle appimagetool
pushd AppDir/usr/bin/; wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage; chmod +x appimagetool*.AppImage; popd

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy*.AppImage
./linuxdeploy-x86_64.AppImage -n linuxdeploy-plugin-appimage --appdir AppDir --init-appdir -v0 \
    -d "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.svg

AppDir/AppRun --appdir AppDir

mv linuxdeploy-plugin-appimage*.AppImage "$OLD_CWD"/
