#!/bin/bash
set -euo pipefail

# export http_proxy="http://127.0.0.1:8080"
# export https_proxy="http://127.0.0.1:8080"
# export HTTP_PROXY="$http_proxy"
# export HTTPS_PROXY="$https_proxy"

LUAJIT_VERSION=luajit2
LUAJIT_URL=https://github.com/openresty/$LUAJIT_VERSION.git

for cmd in git make; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

if [ ! -d "$LUAJIT_VERSION" ]; then
  git clone "$LUAJIT_URL"
fi

cd "$LUAJIT_VERSION"
make -j"$(nproc)"
sudo make install
sudo ldconfig
