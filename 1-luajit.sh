#!/bin/bash
LUAJIT_VERSION=luajit2
LUAJIT_URL=https://github.com/openresty/$LUAJIT_VERSION.git
echo $LUAJIT_VERSION
if [ ! -d "$LUAJIT_VERSION" ]; then
git clone  $LUAJIT_URL
fi
cd ./$LUAJIT_VERSION &&  make install
