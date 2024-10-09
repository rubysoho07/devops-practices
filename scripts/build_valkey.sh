#!/bin/bash

curl -L -O https://github.com/valkey-io/valkey/archive/refs/tags/8.0.1.tar.gz

tar xfz 8.0.1.tar.gz

cd valkey-8.0.1

make MALLOC=libc

make install 