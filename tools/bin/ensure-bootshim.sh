#!/usr/bin/env bash
set -euo pipefail
ROOT=${ROOT:-$(git rev-parse --show-toplevel)}
BOOTMOD="$ROOT/vendor/bootshim"
BOOT="$BOOTMOD/out/BootShim.efi"
EDK="$BOOTMOD/ext/edk2"

need(){ command -v "$1" >/dev/null || { echo "[fatal] missing $1"; exit 9; }; }
need curl; need tar; need make; need python3

if [ -f "$BOOT" ]; then
  echo "$BOOT"; exit 0
fi

echo "[build] BootShim.efi missing — building submodule"
(
  set -e
  cd "$BOOTMOD"
  rm -rf "$EDK" && mkdir -p "$EDK"

  if [ -f vendor/edk2.tar.xz ]; then
    echo "[info] using vendored edk2.tar.xz"
    tar -C "$EDK" -xJf vendor/edk2.tar.xz
  else
    echo "[info] vendor tar missing — fetching edk2 from codeload"
    TMPTGZ="$(mktemp)"
    curl -fsSL https://codeload.github.com/tianocore/edk2/tar.gz/refs/heads/master -o "$TMPTGZ"
    # flatten the leading directory
    tar -xzf "$TMPTGZ" -C "$EDK" --strip-components=1
    rm -f "$TMPTGZ"
  fi

  # hard sanity checks before we try to build
  [ -f "$EDK/edksetup.sh" ] || { echo "[fatal] edksetup.sh missing under $EDK"; exit 2; }
  [ -d "$EDK/BaseTools" ]   || { echo "[fatal] BaseTools missing under $EDK"; exit 2; }

  make -C "$EDK/BaseTools" -j1
  export PYTHON_COMMAND=python3
  export PACKAGES_PATH="$PWD:$EDK"

  bash -lc '
    set -e
    . "$EDK/edksetup.sh" BaseTools
    mkdir -p out
    build -a X64 -t GCC5 -b RELEASE \
      -p SowiwosPkg/SowiwosPkg.dsc \
      -m SowiwosPkg/Application/BootShim/BootShim.inf \
      -n 2 | tee out/bootshim.build.log
    find "$EDK/Build" -type f -iname "*BootShim*.efi" -exec cp -v {} out/BootShim.efi \; || true
  '
)

[ -f "$BOOT" ] || { echo "[fatal] BootShim.efi not produced"; exit 2; }
echo "$BOOT"
