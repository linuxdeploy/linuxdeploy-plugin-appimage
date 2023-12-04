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

case "$ARCH" in
    x86_64|armhf|aarch64)
        AIK_ARCH="$ARCH"
        ;;
    i386)
        AIK_ARCH="i686"
        ;;
    *)
        echo "Architecture not supported: $ARCH" 1>&2
        exit 1
        ;;
esac

cmake -G Ninja "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/usr -DUSE_CCACHE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo "${EXTRA_CMAKE_ARGS[@]}"

nprocs="$(nproc)"
[[ "$nprocs" -gt 2 ]] && nprocs="$(nproc --ignore=1)"

ninja -v -j"$nprocs"

env DESTDIR=AppDir ninja -v install

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage
chmod +x linuxdeploy-"$ARCH".AppImage

# bundle appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-"$AIK_ARCH".AppImage

chmod +x appimagetool-"$AIK_ARCH".AppImage

./appimagetool-"$AIK_ARCH".AppImage --appimage-extract
mv squashfs-root/ AppDir/appimagetool-prefix/
ln -s ../../appimagetool-prefix/AppRun AppDir/usr/bin/appimagetool

export UPD_INFO="gh-releases-zsync|linuxdeploy|linuxdeploy-plugin-appimage|continuous|linuxdeploy-plugin-appimage-$ARCH.AppImage"

# deploy linuxdeploy-plugin-appimage
./linuxdeploy-"$ARCH".AppImage --appimage-extract-and-run \
     --appdir AppDir -d "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.svg

AppDir/AppRun --appdir AppDir

mv linuxdeploy-plugin-appimage*.AppImage* "$OLD_CWD"/
