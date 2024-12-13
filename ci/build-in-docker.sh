#! /bin/bash

set -euxo pipefail

if [[ "${ARCH:-}" == "" ]]; then
    echo "Usage: env ARCH=... bash $0"
    exit 1
fi

case "$ARCH" in
    x86_64)
        platform=linux/amd64
        ;;
    i386)
        platform=linux/i386
        ;;
    armhf)
        platform=linux/arm/v7
        ;;
    aarch64)
        platform=linux/arm64/v8
        ;;
    *)
        echo "unknown architecture: $ARCH"
        exit 2
        ;;
esac

image=debian:stable

repo_root="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")"/..)"

# run the build with the current user to
#   a) make sure root is not required for builds
#   b) allow the build scripts to "mv" the binaries into the /out directory
uid="$(id -u)"

# make sure Docker image is up to date
docker pull --platform "$platform" "$image"

docker run \
    --platform "$platform" \
    --rm \
    -i \
    -e ARCH \
    -e GITHUB_ACTIONS \
    -e GITHUB_RUN_NUMBER \
    -e OUT_UID="$uid" \
    -v "$repo_root":/source:ro \
    -v "$PWD":/out \
    -w /out \
    --tmpfs /docker-ramdisk:exec,mode=777 \
    "$image" \
    bash -exo pipefail \
<<\EOF

apt-get update
apt-get install -y gcc g++ cmake git wget file curl ninja-build

bash -euxo pipefail ci/build-appimage.sh

EOF
