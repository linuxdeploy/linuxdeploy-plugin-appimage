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
REPO_ROOT=$(readlink -f $(dirname $(dirname "$0")))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

case "$ARCH" in
    x86_64|i386|aarch64|armhf)
        ;;
    *)
        echo "Architecture not supported: $ARCH" 1>&2
        exit 1
        ;;
esac

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/usr -DUSE_CCACHE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo

make -j$(nproc)

make install DESTDIR=AppDir

AIK_ARCH="$ARCH"
[ "$ARCH" == "i386" ] && AIK_ARCH="i686"

bash "$REPO_ROOT"/ci/build-bundle.sh

mv linuxdeploy-plugin-appimage-bundle AppDir/

# cannot use a simple symlink because the AppRun script in appimagetool does not use bash and cannot use $BASH_SOURCE
# therefore, a symlink would alter $0, causing the script to detect the wrong path
# we use a similar script here to avoid this AppImage from depending on bash
cat > AppDir/usr/bin/appimagetool <<\EOF
#! /bin/bash
set -euo pipefail

this_dir="$(readlink -f "$(dirname "$0")")"

# make appimagetool prefer the bundled mksquashfs
export PATH="$this_dir"/usr/bin:"$PATH"

exec "$this_dir"/../../linuxdeploy-plugin-appimage-bundle/usr/bin/appimagetool "$@"

EOF
chmod +x AppDir/usr/bin/appimagetool

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage
chmod +x linuxdeploy-"$ARCH".AppImage

# qemu is not happy about the AppImage type 2 magic bytes, so we need to "fix" that
dd if=/dev/zero bs=1 count=3 seek=8 conv=notrunc of=linuxdeploy-"$ARCH".AppImage

export UPD_INFO="gh-releases-zsync|linuxdeploy|linuxdeploy-plugin-appimage|continuous|linuxdeploy-plugin-appimage-$ARCH.AppImage"

# deploy linuxdeploy-plugin-appimage
./linuxdeploy-"$ARCH".AppImage --appimage-extract-and-run \
     --appdir AppDir -d "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-appimage.svg
find AppDir

AppDir/AppRun --appdir AppDir

mv linuxdeploy-plugin-appimage*.AppImage* "$OLD_CWD"/
