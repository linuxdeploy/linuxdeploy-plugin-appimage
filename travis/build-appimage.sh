#! /bin/bash

set -e
set -x

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" linuxdeploy-plugin-appimage-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname "$0")))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

if [ "$ARCH" == "x86_64" ]; then
    EXTRA_CMAKE_ARGS=()
elif [ "$ARCH" == "i386" ]; then
    EXTRA_CMAKE_ARGS=("-DCMAKE_TOOLCHAIN_FILE=$REPO_ROOT/cmake/toolchains/i386-linux-gnu.cmake")
elif [ "$ARCH" == "armhf" ]; then
    EXTRA_CMAKE_ARGS=()
elif [ "$ARCH" == "aarch64" ]; then
    EXTRA_CMAKE_ARGS=()
else
    echo "Architecture not supported: $ARCH" 1>&2
    exit 1
fi

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/usr -DUSE_CCACHE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo "${EXTRA_CMAKE_ARGS[@]}"

make -j$(nproc)

make install DESTDIR=AppDir

AIK_ARCH="$ARCH"
[ "$ARCH" == "i386" ] && AIK_ARCH="i686"

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage
chmod +x linuxdeploy-"$ARCH".AppImage

# bundle appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-"$AIK_ARCH".AppImage

chmod +x appimagetool-"$AIK_ARCH".AppImage

sed -i 's/AI\x02/\x00\x00\x00/' {appimagetool,linuxdeploy}*.AppImage

./appimagetool-"$AIK_ARCH".AppImage --appimage-extract
mv squashfs-root/ AppDir/appimagetool-prefix/
ln -s ../../appimagetool-prefix/AppRun AppDir/usr/bin/appimagetool

export UPD_INFO="gh-releases-zsync|linuxdeploy|linuxdeploy-plugin-appimage|continuous|linuxdeploy-plugin-appimage-$ARCH.AppImage"

# deploy linuxdeploy-plugin-appimage
sed -i 's|AI\x02|\x00\x00\x00|' linuxdeploy-"$ARCH".AppImage
./linuxdeploy-"$ARCH".AppImage --appimage-extract-and-run \
     --appdir AppDir -d "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.svg

AppDir/AppRun --appdir AppDir

mv linuxdeploy-plugin-appimage*.AppImage* "$OLD_CWD"/
