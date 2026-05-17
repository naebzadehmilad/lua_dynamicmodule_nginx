#!/bin/bash
set -euo pipefail

# export http_proxy="http://127.0.0.1:8080"
# export https_proxy="http://127.0.0.1:8080"
# export HTTP_PROXY="$http_proxy"
# export HTTPS_PROXY="$https_proxy"

LUA_VERSION="v0.10.29R2"
LUA_TAR="${LUA_VERSION}.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/refs/tags/${LUA_TAR}"
LUA_DIR="lua-nginx-module-0.10.29R2"

NDK_VERSION="v0.3.3"
NDK_TAR="${NDK_VERSION}.tar.gz"
NDK_URL="https://github.com/vision5/ngx_devel_kit/archive/refs/tags/${NDK_TAR}"
NDK_DIR="ngx_devel_kit-0.3.3"

NGINX_RELEASE="1.28.3"
NGINX_VERSION="nginx-${NGINX_RELEASE}.tar.gz"
NGINX_URL="http://nginx.org/download/${NGINX_VERSION}"
NGINX_DIR="nginx-${NGINX_RELEASE}"

MODULES_PATH="/usr/lib/nginx/modules"
ETC_MODULES_PATH="/etc/nginx/modules"
LUA_LIB_PATH="/etc/nginx/lua"
LUA_RESTY_PATH="${LUA_LIB_PATH}/resty"

LUA_RESTY_CORE="https://github.com/openresty/lua-resty-core.git"
LUA_RESTY_LRUCACHE="https://github.com/openresty/lua-resty-lrucache.git"

for cmd in wget tar git make nginx awk; do
  if ! command -v "$cmd" &>/dev/null; then
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
  echo "Install an nginx 1.28.3 package that supports compatible dynamic modules."
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

detect_luajit

if [ ! -f "$LUA_TAR" ]; then
  wget -O "$LUA_TAR" "$LUA_URL" || { echo "Failed to download Lua module"; exit 1; }
fi
rm -rf "$LUA_DIR"
tar zxf "$LUA_TAR" || { echo "failed to extract $LUA_TAR"; exit 1; }

if [ ! -f "$NDK_TAR" ]; then
  wget -O "$NDK_TAR" "$NDK_URL" || { echo "failed to download ngx_devel_kit"; exit 1; }
fi
rm -rf "$NDK_DIR"
tar zxf "$NDK_TAR" || { echo "failed to extract $NDK_TAR"; exit 1; }

if [ ! -f "$NGINX_VERSION" ]; then
  wget -O "$NGINX_VERSION" "$NGINX_URL" || { echo "failed to download nginx"; exit 1; }
fi
rm -rf "$NGINX_DIR"
tar zxf "$NGINX_VERSION" || { echo "failed to extract $NGINX_VERSION"; exit 1; }

cd "$NGINX_DIR"
./configure \
  --with-compat \
  --with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" \
  --add-dynamic-module=../"$NDK_DIR" \
  --add-dynamic-module=../"$LUA_DIR" || { echo "configure failed"; exit 1; }
make modules || { echo "make failed"; exit 1; }

sudo mkdir -p "$MODULES_PATH"
sudo cp -f objs/ndk_http_module.so "$MODULES_PATH/" || { echo "Failed to copy ndk module"; exit 1; }
sudo cp -f objs/ngx_http_lua_module.so "$MODULES_PATH/" || { echo "Failed to copy module"; exit 1; }

sudo mkdir -p "$ETC_MODULES_PATH"
sudo cp -f "$MODULES_PATH/ndk_http_module.so" "$ETC_MODULES_PATH/" || { echo "Failed to copy ndk module to $ETC_MODULES_PATH"; exit 1; }
sudo cp -f "$MODULES_PATH/ngx_http_lua_module.so" "$ETC_MODULES_PATH/" || { echo "Failed to copy module to $ETC_MODULES_PATH"; exit 1; }

cd ..

[ -d lua-resty-core ] || git clone "$LUA_RESTY_CORE"
[ -d lua-resty-lrucache ] || git clone "$LUA_RESTY_LRUCACHE"

sudo mkdir -p "$LUA_RESTY_PATH"
sudo cp -r lua-resty-core/lib/resty/* "$LUA_RESTY_PATH/" || { echo "Failed to copy lua-resty-core"; exit 1; }
sudo cp -f lua-resty-lrucache/lib/resty/lrucache.lua "$LUA_RESTY_PATH/" || { echo "Failed to copy lrucache"; exit 1; }

cat <<EOF

setup completed successfully!

1) include to  /etc/nginx/nginx.conf (before events{}):
    load_module ${MODULES_PATH}/ndk_http_module.so;
    load_module ${MODULES_PATH}/ngx_http_lua_module.so;
    or
    load_module ${ETC_MODULES_PATH}/ndk_http_module.so;
    load_module /etc/nginx/modules/ngx_http_lua_module.so;

2) add this inside http { } in nginx.conf:
    lua_package_path "${LUA_LIB_PATH}/?.lua;${LUA_RESTY_PATH}/?.lua;;";
    lua_socket_timeout 1000ms;

3) test + restart:
    sudo nginx -t
    sudo systemctl restart nginx
4) execute
   nginx -T 2>&1 | grep -nE 'load_module|ndk_http_module|ngx_http_lua_module'
EOF
