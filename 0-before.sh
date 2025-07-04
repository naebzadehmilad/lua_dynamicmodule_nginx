export LUA_INCDIR=/usr/include/lua5.1 
export LUA_LIBDIR=/usr/lib/x86_64-linux-gnu
cp -r lua /etc/nginx/
apt -y install build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev git zip unzip  liblua5.1-dev luarocks || handle_error "Failed to install packages."
luarocks install lua-resty-core || handle_error "Failed to install lua-resty-core."
luarocks install lua-resty-http || handle_error "Failed to install lua-resty-http."
echo "Setting up PCRE symlink..."
 ln -sf /usr/lib/x86_64-linux-gnu/libpcre.so.1 /usr/lib/libpcre.so.1 || handle_error "Failed to create PCRE symlink."
ldconfig || handle_error "Failed to update library cache."
