#!/bin/bash

handle_error() {
    echo "Error: $1"
    exit 1
}

echo "Installing necessary packages..."
apt -y install build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev git zip unzip libluajit-5.1-2 luarocks || handle_error "Failed to install packages."

echo "Installing LuaRocks modules..."
luarocks install lua-resty-core || handle_error "Failed to install lua-resty-core."
luarocks install lua-resty-http || handle_error "Failed to install lua-resty-http."

# variables
LUAJIT_VERSION=luajit2
LUAJIT_URL=https://github.com/openresty/$LUAJIT_VERSION.git
LUAJIT_DIR=$LUAJIT_VERSION
LUA_VERSION=v0.10.27.tar.gz
LUA_URL=https://github.com/openresty/lua-nginx-module/archive/$LUA_VERSION
LUA_DIR=lua-nginx-module-0.10.27
NGINX_VERSION=nginx-1.25.0.tar.gz
NGINX_URL=http://nginx.org/download/$NGINX_VERSION
NGINX_DIR=nginx-1.25.0
PCRE_VERSION=pcre-8.44.tar.gz
PCRE_URL=https://sourceforge.net/projects/pcre/files/pcre/8.44/pcre-8.44.tar.gz/download
PCRE_DIR=pcre-8.44
MODULES_PATH=/usr/lib/nginx/modules/
LUA_RESTY_CORE=https://github.com/openresty/lua-resty-core.git
LUA_RESTY_LRUCACHE=https://github.com/openresty/lua-resty-lrucache.git


###
sudo ln -s /usr/local/lib/libpcre.so.1 /usr/lib/libpcre.so.1
ldconfig

echo "Installing LuaJIT..."
if [ ! -d "$LUAJIT_DIR" ]; then
    git clone $LUAJIT_URL || handle_error "Failed to clone LuaJIT repository."
fi
cd $LUAJIT_DIR || handle_error "Failed to change directory to $LUAJIT_DIR."
make clean
make || handle_error "Failed to build LuaJIT."
sudo make install || handle_error "Failed to install LuaJIT."
cd ..

export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

if ! luajit -v >/dev/null 2>&1; then
    handle_error "LuaJIT is not installed correctly or not found in PATH."
fi

echo "Downloading and extracting Lua Nginx Module..."
if [ ! -f "$LUA_VERSION" ]; then
    wget $LUA_URL || handle_error "Failed to download Lua Nginx Module."
fi
tar zxvf $LUA_VERSION || handle_error "Failed to extract Lua Nginx Module."

echo "Downloading and extracting Nginx..."
if [ ! -f "$NGINX_VERSION" ]; then
    wget $NGINX_URL || handle_error "Failed to download Nginx."
fi
tar zxvf $NGINX_VERSION || handle_error "Failed to extract Nginx."

echo "Downloading and extracting PCRE..."
if [ ! -f "$PCRE_VERSION" ]; then
    wget -O $PCRE_VERSION $PCRE_URL || handle_error "Failed to download PCRE."
fi
tar zxvf $PCRE_VERSION || handle_error "Failed to extract PCRE."
cd $PCRE_DIR || handle_error "Failed to change directory to $PCRE_DIR."
./configure || handle_error "Failed to configure PCRE."
make || handle_error "Failed to build PCRE."
sudo make install || handle_error "Failed to install PCRE."
cd ..

echo "Configuring and building Nginx with Lua module..."
cd $NGINX_DIR || handle_error "Failed to change directory to $NGINX_DIR."
./configure --with-compat --with-pcre=../$PCRE_DIR --with-pcre-jit --with-ld-opt="-lpcre -lluajit-5.1" --add-dynamic-module=../$LUA_DIR || handle_error "Failed to configure Nginx."
make modules || handle_error "Failed to build Nginx modules."
sudo cp -r objs/ngx_http_lua_module.so $MODULES_PATH || handle_error "Failed to copy Nginx Lua module."
cd ..

echo "Cloning Lua-resty-core and Lua-resty-lrucache..."
git clone $LUA_RESTY_CORE || handle_error "Failed to clone lua-resty-core."
git clone $LUA_RESTY_LRUCACHE || handle_error "Failed to clone lua-resty-lrucache."

echo "Copying Lua-resty modules..."
mkdir -p /etc/nginx/lua/resty || handle_error "Failed to create directory /etc/nginx/lua/resty."
cp -r lua-resty-core/lib/resty/* /etc/nginx/lua/resty/ || handle_error "Failed to copy lua-resty-core modules."
cp -r lua-resty-lrucache/lib/resty/lrucache.lua /etc/nginx/lua/resty/ || handle_error "Failed to copy lua-resty-lrucache module."

echo "Configuration instructions:"
echo -e '\nload_module modules/ngx_http_lua_module.so;\n'
echo -e "\nPlease add the following directives to the http block in your nginx.conf file:\n"
echo 'lua_package_path "/etc/nginx/lua/?.lua;;";'
echo 'lua_socket_timeout 1000ms;'
