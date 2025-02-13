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

env DESTDIR=linuxdeploy-plugin-appimage-bundle ninja -v install

# linuxdeploy-plugin-appimage-bundle appimagetool
wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-"$AIK_ARCH".AppImage

chmod +x appimagetool-"$AIK_ARCH".AppImage

# as usual, qemu is not happy about the AppImage type 2 magic bytes
# let's "fix" that
dd if=/dev/zero bs=1 count=3 seek=8 conv=notrunc of=appimagetool-"$AIK_ARCH".AppImage

./appimagetool-"$AIK_ARCH".AppImage --appimage-extract
mv squashfs-root/ linuxdeploy-plugin-appimage-bundle/appimagetool-prefix/

# cannot use a simple symlink because the AppRun script in appimagetool does not use bash and cannot use $BASH_SOURCE
# therefore, a symlink would alter $0, causing the script to detect the wrong path
# we use a similar script here to avoid this AppImage from depending on bash
cat > linuxdeploy-plugin-appimage-bundle/usr/bin/appimagetool <<\EOF
#! /bin/bash
set -euo pipefail

this_dir="$(readlink -f "$(dirname "$0")")"

exec "$this_dir"/../../appimagetool-prefix/AppRun "$@"
EOF
chmod +x linuxdeploy-plugin-appimage-bundle/usr/bin/appimagetool

mv linuxdeploy-plugin-appimage-bundle "$OLD_CWD"
