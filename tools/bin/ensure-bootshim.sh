#!/usr/bin/env bash
set -euo pipefail
ROOT=${ROOT:-$(git rev-parse --show-toplevel)}
BOOT="$ROOT/vendor/bootshim/out/BootShim.efi"
BOOTMOD="$ROOT/vendor/bootshim"
EDK="$BOOTMOD/ext/edk2"

if [ -f "$BOOT" ]; then
  echo "$BOOT"; exit 0
fi

echo "[build] BootShim.efi missing — building submodule"
(
  set -e
  cd "$BOOTMOD"
  mkdir -p "$EDK"
  if [ -f vendor/edk2.tar.xz ]; then
    tar -C "$EDK" -xJf vendor/edk2.tar.xz
  else
    echo "[info] vendor tar missing — fetching edk2 from codeload"
    curl -fsSL https://codeload.github.com/tianocore/edk2/tar.gz/refs/heads/master -o /tmp/edk2.tgz
    tar -xzf /tmp/edk2.tgz -C "" --strip-components=1
  [ -f "$EDK/edksetup.sh" ] || { echo "[fatal] edksetup.sh missing"; exit 2; }
  [ -d "$EDK/BaseTools" ]   || { echo "[fatal] BaseTools missing"; exit 2; }
  fi
  make -C "$EDK/BaseTools" -j1
  PYTHON_COMMAND=python3 PACKAGES_PATH="$PWD:$EDK" bash -lc \
    '. "$EDK/edksetup.sh" BaseTools && \
     build -a X64 -t GCC5 -b RELEASE \
       -p SowiwosPkg/SowiwosPkg.dsc \
       -m SowiwosPkg/Application/BootShim/BootShim.inf \
       -n 2 | tee out/bootshim.build.log && \
     find "$EDK/Build" -type f -iname "*BootShim*.efi" -exec cp {} out/BootShim.efi \;'
)
[ -f "$BOOT" ] || { echo "[fatal] BootShim.efi not produced"; exit 2; }
echo "$BOOT"
