#!/bin/bash
set -euo pipefail

LUA_VERSION="v0.10.29R2"
LUA_TAR="${LUA_VERSION}.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/refs/tags/${LUA_TAR}"
LUA_DIR="lua-nginx-module-0.10.29R2"

NGINX_VERSION="nginx-1.28.1.tar.gz"
NGINX_URL="http://nginx.org/download/${NGINX_VERSION}"
NGINX_DIR="nginx-1.28.1"

MODULES_PATH="/usr/lib/nginx/modules"
LUA_LIB_PATH="/etc/nginx/lua"  
LUA_RESTY_PATH="${LUA_LIB_PATH}/resty"

LUA_RESTY_CORE="https://github.com/openresty/lua-resty-core.git"
LUA_RESTY_LRUCACHE="https://github.com/openresty/lua-resty-lrucache.git"

export LUAJIT_LIB="/usr/local/lib"
export LUAJIT_INC="/usr/local/include/luajit-2.1"

for cmd in wget tar git make nginx; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

if [ ! -d "$LUAJIT_INC" ]; then
  echo "Error: luajit 2.1 not found at $LUAJIT_INC. please install luajit 2.1 ."
  exit 1
fi

if [ ! -f "$LUA_TAR" ]; then
  wget -O "$LUA_TAR" "$LUA_URL" || { echo "Failed to download Lua module"; exit 1; }
fi
rm -rf "$LUA_DIR"
tar zxf "$LUA_TAR" || { echo "failed to extract $LUA_TARBALL"; exit 1; }

if [ ! -f "$NGINX_VERSION" ]; then
  wget -O "$NGINX_VERSION" "$NGINX_URL" || { echo "failed to download nginx"; exit 1; }
fi
rm -rf "$NGINX_DIR"
tar zxf "$NGINX_VERSION" || { echo "failed to extract $NGINX_VERSION"; exit 1; }

cd "$NGINX_DIR"
./configure --with-ld-opt="-lpcre" --with-compat --add-dynamic-module=../"$LUA_DIR" || { echo "configure failed"; exit 1; }
make modules || { echo "make failed"; exit 1; }

sudo mkdir -p "$MODULES_PATH"
sudo cp -f objs/ngx_http_lua_module.so "$MODULES_PATH/" || { echo "Failed to copy module"; exit 1; }

sudo mkdir -p /etc/nginx/modules
sudo cp -f "$MODULES_PATH/ngx_http_lua_module.so" /etc/nginx/modules/ || { echo "Failed to copy module to /etc/nginx/modules"; exit 1; }

cd ..

[ -d lua-resty-core ] || git clone "$LUA_RESTY_CORE"
[ -d lua-resty-lrucache ] || git clone "$LUA_RESTY_LRUCACHE"

sudo mkdir -p "$LUA_RESTY_PATH"
sudo cp -r lua-resty-core/lib/resty/* "$LUA_RESTY_PATH/" || { echo "Failed to copy lua-resty-core"; exit 1; }
sudo cp -f lua-resty-lrucache/lib/resty/lrucache.lua "$LUA_RESTY_PATH/" || { echo "Failed to copy lrucache"; exit 1; }

cat <<EOF

setup completed successfully!

1) include to  /etc/nginx/nginx.conf (before events{}):
    load_module ${MODULES_PATH}/ngx_http_lua_module.so;
    or
    load_module /etc/nginx/modules/ngx_http_lua_module.so;

2) add this inside http { } in nginx.conf:
    lua_package_path "${LUA_LIB_PATH}/?.lua;${LUA_RESTY_PATH}/?.lua;;";
    lua_socket_timeout 1000ms;

3) test + restart:
    sudo nginx -t
    sudo systemctl restart nginx
4) execute
   nginx -T 2>&1 | grep -nE 'load_module|ngx_http_lua_module'
EOF
