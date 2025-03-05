#!/bin/bash

LUA_VERSION=v0.10.28.tar.gz
LUA_URL=https://github.com/openresty/lua-nginx-module/archive/$LUA_VERSION
LUA_DIR=lua-nginx-module-0.10.28

NGINX_VERSION=nginx-1.25.0.tar.gz
NGINX_URL=http://nginx.org/download/$NGINX_VERSION
NGINX_DIR=nginx-1.25.0

MODULES_PATH=/usr/lib/nginx/modules/

LUA_RESTY_CORE=https://github.com/openresty/lua-resty-core.git
LUA_RESTY_LRUCACHE=https://github.com/openresty/lua-resty-lrucache.git

#NDK_URL=https://github.com/simpl/ngx_devel_kit/archive/v0.3.1.tar.gz
#NDK_DIR=ngx_devel_kit-0.3.1

export LUAJIT_LIB=/usr/local/lib/lua && export LUAJIT_INC=/usr/local/include/luajit-2.1

# Download Lua Nginx Module
if [ ! -f "$LUA_VERSION" ]; then
    wget $LUA_URL
fi
tar zxvf $LUA_VERSION

# Download Nginx
if [ ! -f "$NGINX_VERSION" ]; then
    wget $NGINX_URL
fi
tar zxvf $NGINX_VERSION

# Download NDK
#wget $NDK_URL
#tar zxvf $NDK_VERSION

#cd $NGINX_DIR && ./configure --with-compat --add-dynamic-module=../$LUA_DIR --add-dynamic-module=../$NDK_DIR && make modules && cp -r objs/ngx_http_lua_module.so objs/ngx_http_ndk_module.so $MODULES_PATH
cd $NGINX_DIR && ./configure --with-ld-opt=-lpcre  --with-compat --add-dynamic-module=../$LUA_DIR  && make modules && cp -r objs/ngx_http_lua_module.so $MODULES_PATH

# Clone Lua-resty-core and Lua-resty-lrucache
git clone $LUA_RESTY_CORE
git clone $LUA_RESTY_LRUCACHE


mkdir -p /etc/nginx/lua/resty
cp -r ./lua-resty-core/lib/resty/* /etc/nginx/lua/resty/
cp -r ./lua-resty-lrucache/lib/resty/lrucache.lua /etc/nginx/lua/resty/

echo -e '\nload_module modules/ngx_http_lua_module.so;\n'
#echo -e 'load_module modules/ngx_http_ndk_module.so;\n'
echo -e "\nPlease add the following directives to the http block in your nginx.conf file:\n"
echo 'lua_package_path "/etc/nginx/lua/?.lua;;";'
echo 'lua_socket_timeout 1000ms;'
