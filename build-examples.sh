#!/usr/bin/env bash
set -e

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
build_dir="$script_dir/build"

mkdir -p "$build_dir"
cd "$build_dir"

c3c compile --wincrt=none -O1 --macos-min-version 13.0 -L "$build_dir/libs" --libdir .. --lib usockets ../examples/echo-server.c3 -o echo-server
