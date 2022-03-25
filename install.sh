#!/bin/sh

# install wlua
git clone https://github.com/hanxi/wlua
cd wlua
make install
cd -

# install skynet-admin
git clone https://github.com/hanxi/skynet-admin.git
cd skynet-admin
git submodule update --init
cd -

