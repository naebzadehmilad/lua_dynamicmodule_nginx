#!/bin/bash

LUA_VERSION="v0.10.28.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/$LUA_VERSION"
LUA_DIR="lua-nginx-module-0.10.28"

NGINX_VERSION="nginx-1.26.3.tar.gz"
NGINX_URL="http://nginx.org/download/$NGINX_VERSION"
NGINX_DIR="nginx-1.26.3"

MODULES_PATH="/usr/lib/nginx/modules/"
LUA_LIB_PATH="/etc/nginx/lua/resty"

LUA_RESTY_CORE="https://github.com/openresty/lua-resty-core.git"
LUA_RESTY_LRUCACHE="https://github.com/openresty/lua-resty-lrucache.git"

export LUAJIT_LIB="/usr/local/lib/lua"
export LUAJIT_INC="/usr/local/include/luajit-2.1"

for cmd in wget tar git make; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required but not installed. Please install it."
        exit 1
    fi
done

if [ ! -d "$LUAJIT_INC" ]; then
    echo "Error: LuaJIT 2.1 not found at $LUAJIT_INC. Please install LuaJIT 2.1 first."
    exit 1
fi

if [ ! -f "$LUA_VERSION" ]; then
    wget "$LUA_URL" || { echo "Failed to download Lua module"; exit 1; }
fi
tar zxvf "$LUA_VERSION" || { echo "Failed to extract $LUA_VERSION"; exit 1; }

if [ ! -f "$NGINX_VERSION" ]; then
    wget "$NGINX_URL" || { echo "Failed to download Nginx"; exit 1; }
fi
tar zxvf "$NGINX_VERSION" || { echo "Failed to extract $NGINX_VERSION"; exit 1; }

cd "$NGINX_DIR" || { echo "Failed to enter $NGINX_DIR"; exit 1; }
./configure --with-ld-opt="-lpcre" --with-compat --add-dynamic-module=../"$LUA_DIR" || { echo "Configure failed"; exit 1; }
make modules || { echo "Make failed"; exit 1; }

sudo mkdir -p "$MODULES_PATH"
sudo cp -r objs/ngx_http_lua_module.so "$MODULES_PATH" || { echo "Failed to copy module"; exit 1; }

git clone "$LUA_RESTY_CORE" || { echo "Failed to clone lua-resty-core"; exit 1; }
git clone "$LUA_RESTY_LRUCACHE" || { echo "Failed to clone lua-resty-lrucache"; exit 1; }

sudo mkdir -p "$LUA_LIB_PATH"
sudo cp -r ./lua-resty-core/lib/resty/* "$LUA_LIB_PATH/" || { echo "Failed to copy lua-resty-core"; exit 1; }
sudo cp -r ./lua-resty-lrucache/lib/resty/lrucache.lua "$LUA_LIB_PATH/" || { echo "Failed to copy lrucache"; exit 1; }

cat <<EOF

Setup completed successfully!

1. Add the following line
    load_module $MODULES_PATH/ngx_http_lua_module.so;

2. Add  to  'http' block in your nginx.conf:
    lua_package_path "$LUA_LIB_PATH/?.lua;;";
    lua_socket_timeout 1000ms;

3. Restart Nginx to apply changes:
    sudo systemctl restart nginx
EOF
