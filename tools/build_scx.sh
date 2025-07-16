#!/bin/bash

set -e

cd scx
meson setup build --prefix $(realpath $(pwd)/../scx_install)
meson compile -C build
meson install -C build

echo "finish"
