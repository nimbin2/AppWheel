#!/usr/bin/env bash
#
# build-portable.sh — build an appwheel binary that runs across distros.
#
# The trick: compile inside an OLDER Ubuntu (default 22.04 / glibc 2.35). glibc is
# forward-compatible, so a binary built there runs on that Ubuntu release and
# anything newer — fixing "GLIBC_2.xx not found" errors you get when you build on
# a bleeding-edge distro (Arch, Fedora rawhide, ...) and run on Ubuntu.
#
# SDL3 is linked statically (no libSDL3.so needed on the target). SDL still loads
# the system's Wayland/X11 libraries at runtime via dlopen, which is why this is
# NOT a fully-static binary — that approach doesn't work for SDL. This one links
# only glibc dynamically, against an old-enough version.
#
# Requires Docker or Podman on the machine you run this from.
#
# Usage:
#   ./build-portable.sh            # build against ubuntu:22.04
#   ./build-portable.sh 20.04      # even older glibc (2.31), wider compatibility

set -euo pipefail
TAG="${1:-22.04}"

ENGINE="$(command -v docker || command -v podman || true)"
if [ -z "$ENGINE" ]; then
    echo "error: need docker or podman installed to run this." >&2
    exit 1
fi

echo ">> building appwheel inside ubuntu:$TAG (this compiles SDL3, give it a few minutes)"

"$ENGINE" run --rm -v "$PWD":/src -w /src "ubuntu:$TAG" bash -euc '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        build-essential git cmake pkg-config ca-certificates file \
        libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev \
        libwayland-dev wayland-protocols libxkbcommon-dev libgl1-mesa-dev libegl1-mesa-dev

    if [ ! -d SDL ]; then
        git clone --depth 1 https://github.com/libsdl-org/SDL
    fi
    cmake -S SDL -B SDL/build -DCMAKE_BUILD_TYPE=Release -DSDL_STATIC=ON -DSDL_SHARED=OFF >/dev/null
    cmake --build SDL/build -j"$(nproc)"
    cmake --install SDL/build >/dev/null
    ldconfig

    make static
    strip appwheel 2>/dev/null || true

    echo
    echo ">> built against $(ldd --version | head -1)"
    echo ">> ldd of the result:"
    ldd appwheel || true
'

echo
echo ">> done. ./appwheel should now run on Ubuntu $TAG and newer (and other"
echo ">> distros whose glibc is at least that version)."
