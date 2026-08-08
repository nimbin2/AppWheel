#!/usr/bin/env bash
#
# build-portable.sh — build an appwheel binary that runs across distros.
#
# The trick: compile inside an OLDER Ubuntu (default 22.04 / glibc 2.35). glibc is
# forward-compatible, so a binary built there runs on that Ubuntu release and
# anything newer — fixing "GLIBC_2.xx not found" errors you get when you build on
# a bleeding-edge distro (Arch, Fedora rawhide, ...) and run on Ubuntu.
#
# SDL3 is linked statically (no libSDL3.so needed on the target) and pinned to a
# known-good release. SDL still loads the system's Wayland/X11 libraries at runtime
# via dlopen, so this is NOT a fully-static binary — that approach doesn't work for
# SDL. It links only glibc dynamically, against an old-enough version.
#
# Requires Docker or Podman on the machine you run this from.
#
# Usage:
#   ./build-portable.sh                 # ubuntu:22.04, SDL release-3.2.14
#   ./build-portable.sh 20.04           # older glibc (2.31) -> wider compatibility
#   SDL_TAG=release-3.2.30 ./build-portable.sh   # a different SDL release
#
# Note: newer SDL releases sometimes add X11 checks (e.g. XTEST) that need extra
# -dev packages. If you bump SDL_TAG and configure fails on a missing package,
# add it to the apt line below (or install it and re-run).

set -euo pipefail

UBUNTU_TAG="${1:-22.04}"
SDL_TAG="${SDL_TAG:-release-3.2.14}"

ENGINE="$(command -v docker || command -v podman || true)"
if [ -z "$ENGINE" ]; then
    echo "error: need docker or podman installed to run this." >&2
    exit 1
fi

echo ">> building appwheel in ubuntu:$UBUNTU_TAG against SDL $SDL_TAG"
echo ">> (this compiles SDL3 from source; give it a few minutes)"

"$ENGINE" run --rm -e SDL_TAG="$SDL_TAG" -v "$PWD":/src -w /src "ubuntu:$UBUNTU_TAG" bash -euc '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    # Complete dependency set for SDL 3.2.x video (X11 + Wayland + GL). No audio /
    # input-device libs: we build SDL video-only below, so those arent needed.
    apt-get install -y --no-install-recommends \
        build-essential git cmake pkg-config ca-certificates file \
        libx11-dev libxext-dev libxcursor-dev libxi-dev libxfixes-dev libxrandr-dev \
        libxss-dev libxrender-dev libxinerama-dev libxkbcommon-dev \
        libwayland-dev wayland-protocols libgl1-mesa-dev libegl1-mesa-dev

    # Clone the pinned SDL into a container-local dir (not your mounted repo), so
    # this never reuses a previous checkout and never clutters your project.
    git clone --depth 1 --branch "$SDL_TAG" https://github.com/libsdl-org/SDL /tmp/SDL

    # Video-only SDL: appwheel only uses SDL_INIT_VIDEO, so switch off audio,
    # input-device and misc subsystems. Smaller build, fewer dependencies.
    cmake -S /tmp/SDL -B /tmp/SDL/build \
        -DCMAKE_BUILD_TYPE=Release -DSDL_STATIC=ON -DSDL_SHARED=OFF \
        -DSDL_AUDIO=OFF -DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF -DSDL_SENSOR=OFF \
        -DSDL_CAMERA=OFF -DSDL_POWER=OFF -DSDL_DBUS=OFF -DSDL_IBUS=OFF \
        -DSDL_TEST_LIBRARY=OFF -DSDL_EXAMPLES=OFF >/dev/null
    cmake --build /tmp/SDL/build -j"$(nproc)"
    cmake --install /tmp/SDL/build >/dev/null
    ldconfig
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}"

    # Build appwheel (in /src, your mounted repo) with SDL baked in.
    make static
    strip appwheel 2>/dev/null || true

    echo
    echo ">> built against $(ldd --version | head -1)"
    echo ">> ldd of the result:"
    ldd appwheel || true
'

echo
echo ">> done. ./appwheel should now run on Ubuntu $UBUNTU_TAG and newer"
echo ">> (and other distros whose glibc is at least that version)."
