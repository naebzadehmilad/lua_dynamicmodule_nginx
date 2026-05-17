#!/bin/bash
set -euo pipefail

export http_proxy="${http_proxy:-http://PROXY:port}"
export https_proxy="${https_proxy:-http://PROXY:port}"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"

LUA_VERSION="v0.10.29R2"
LUA_TAR="${LUA_VERSION}.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/refs/tags/${LUA_TAR}"
LUA_DIR="lua-nginx-module-0.10.29R2"

NDK_VERSION="v0.3.4"
NDK_TAR="${NDK_VERSION}.tar.gz"
NDK_URL="https://github.com/vision5/ngx_devel_kit/archive/refs/tags/${NDK_TAR}"
NDK_DIR="ngx_devel_kit-0.3.4"

NGINX_RELEASE="1.28.3"
NGINX_TAR="nginx-${NGINX_RELEASE}.tar.gz"
NGINX_URL="http://nginx.org/download/${NGINX_TAR}"
NGINX_DIR="nginx-${NGINX_RELEASE}"

RESTY_CORE_VERSION="v0.1.32R1"
RESTY_LRUCACHE_VERSION="v0.15"
RESTY_CORE_URL="https://github.com/openresty/lua-resty-core.git"
RESTY_LRUCACHE_URL="https://github.com/openresty/lua-resty-lrucache.git"

MODULES_PATH="/usr/lib/nginx/modules"
ETC_MODULES_PATH="/etc/nginx/modules"
LUA_LIB_PATH="/etc/nginx/lua"
LUA_RESTY_PATH="${LUA_LIB_PATH}/resty"

WORK_DIR="$(pwd)"

for cmd in wget tar git make nginx awk sudo; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

INSTALLED_NGINX_VERSION="$(nginx -v 2>&1 | awk -F/ '{print $2}' | awk '{print $1}')"
if [ "$INSTALLED_NGINX_VERSION" != "$NGINX_RELEASE" ]; then
  echo "Error: installed nginx is ${INSTALLED_NGINX_VERSION:-unknown}, but this module must be built for nginx $NGINX_RELEASE."
  echo "Install nginx $NGINX_RELEASE first, then run this script again."
  exit 1
fi

NGINX_BUILD_OPTIONS="$(nginx -V 2>&1 || true)"
if [[ "$NGINX_BUILD_OPTIONS" != *"--with-compat"* ]]; then
  echo "Error: installed nginx was not built with --with-compat."
  echo "Install an nginx $NGINX_RELEASE package that supports compatible dynamic modules."
  exit 1
fi

detect_luajit() {
  if [ -d /usr/local/include/luajit-2.1 ] && [ -e /usr/local/lib/libluajit-5.1.so ]; then
    export LUAJIT_INC="/usr/local/include/luajit-2.1"
    export LUAJIT_LIB="/usr/local/lib"
    return
  fi

  if [ -d /usr/include/luajit-2.1 ] && [ -e /usr/lib/x86_64-linux-gnu/libluajit-5.1.so ]; then
    export LUAJIT_INC="/usr/include/luajit-2.1"
    export LUAJIT_LIB="/usr/lib/x86_64-linux-gnu"
    return
  fi

  echo "Error: LuaJIT 2.1 headers/library not found."
  echo "Install it with ./1-luajit.sh or: sudo apt install libluajit-5.1-dev"
  exit 1
}

download_if_missing() {
  local output="$1"
  local url="$2"

  if [ ! -f "$output" ]; then
    wget -O "$output" "$url"
  fi
}

clone_tag() {
  local dir="$1"
  local url="$2"
  local tag="$3"

  rm -rf "$dir"
  git clone --branch "$tag" --depth 1 "$url" "$dir"
}

detect_luajit

cd "$WORK_DIR"

download_if_missing "$LUA_TAR" "$LUA_URL"
rm -rf "$LUA_DIR"
tar zxf "$LUA_TAR"

download_if_missing "$NDK_TAR" "$NDK_URL"
rm -rf "$NDK_DIR"
tar zxf "$NDK_TAR"

download_if_missing "$NGINX_TAR" "$NGINX_URL"
rm -rf "$NGINX_DIR"
tar zxf "$NGINX_TAR"

clone_tag "lua-resty-core" "$RESTY_CORE_URL" "$RESTY_CORE_VERSION"
clone_tag "lua-resty-lrucache" "$RESTY_LRUCACHE_URL" "$RESTY_LRUCACHE_VERSION"

cd "$WORK_DIR/$NGINX_DIR"
./configure \
  --with-compat \
  --with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" \
  --add-dynamic-module="../${NDK_DIR}" \
  --add-dynamic-module="../${LUA_DIR}"

make modules

sudo mkdir -p "$MODULES_PATH" "$ETC_MODULES_PATH"
sudo cp -f objs/ndk_http_module.so "$MODULES_PATH/"
sudo cp -f objs/ngx_http_lua_module.so "$MODULES_PATH/"
sudo cp -f objs/ndk_http_module.so "$ETC_MODULES_PATH/"
sudo cp -f objs/ngx_http_lua_module.so "$ETC_MODULES_PATH/"

cd "$WORK_DIR"
sudo rm -rf "$LUA_RESTY_PATH"
sudo mkdir -p "$LUA_RESTY_PATH"
sudo cp -r lua-resty-core/lib/resty/* "$LUA_RESTY_PATH/"
sudo cp -f lua-resty-lrucache/lib/resty/lrucache.lua "$LUA_RESTY_PATH/"

echo
echo "Installed versions:"
grep -n "ngx_http_lua_module" "$WORK_DIR/lua-resty-core/lib/resty/core/base.lua" || true

cat <<EOF

setup completed successfully!

1) Add these lines to /etc/nginx/nginx.conf before events{}:
    load_module ${MODULES_PATH}/ndk_http_module.so;
    load_module ${MODULES_PATH}/ngx_http_lua_module.so;

   Alternative path:
    load_module ${ETC_MODULES_PATH}/ndk_http_module.so;
    load_module ${ETC_MODULES_PATH}/ngx_http_lua_module.so;

2) Add this inside http { }:
    lua_package_path "${LUA_LIB_PATH}/?.lua;${LUA_LIB_PATH}/?/init.lua;;";
    lua_socket_timeout 1000ms;

3) Test and restart:
    sudo nginx -t
    sudo systemctl restart nginx

4) Verify loaded modules:
    nginx -T 2>&1 | grep -nE 'load_module|ndk_http_module|ngx_http_lua_module|lua_package_path'
EOF
