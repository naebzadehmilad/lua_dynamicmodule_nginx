#!/bin/bash
set -euo pipefail

# export http_proxy="http://127.0.0.1:8080"
# export https_proxy="http://127.0.0.1:8080"
# export HTTP_PROXY="$http_proxy"
# export HTTPS_PROXY="$https_proxy"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script with sudo: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt update
apt -y install \
  build-essential \
  ca-certificates \
  git \
  libluajit-5.1-dev \
  libpcre2-dev \
  libpcre3 \
  libpcre3-dev \
  libssl-dev \
  luarocks \
  unzip \
  wget \
  zip \
  zlib1g-dev

luarocks install lua-resty-core
luarocks install lua-resty-http

ldconfig
