#!/usr/bin/env bash

set -e

LUAJIT_COMMIT=ea9eb7edb5eac4a9d175d74523db34fac0fa5180

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_DIR="$ROOT_DIR/temp/luajit-build"

case "$(uname -s)" in
  Darwin) LIB_OS=darwin ;;
  Linux) LIB_OS=linux ;;
  *) echo "Unsupported OS for building LuaJIT: $(uname -s)" >&2; exit 1 ;;
esac

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
git clone https://github.com/LuaJIT/LuaJIT.git "$WORK_DIR"
git -C "$WORK_DIR" checkout "$LUAJIT_COMMIT"

if [ "$LIB_OS" = "darwin" ]; then
  export MACOSX_DEPLOYMENT_TARGET=11.0
fi

make -C "$WORK_DIR" -j"$(getconf _NPROCESSORS_ONLN)" amalg BUILDMODE=static

mkdir -p "$ROOT_DIR/src/luajit/lib/$LIB_OS"
cp "$WORK_DIR/src/libluajit.a" "$ROOT_DIR/src/luajit/lib/$LIB_OS/libluajit.a"
rm -rf "$WORK_DIR"

echo "LuaJIT installed at src/luajit/lib/$LIB_OS/libluajit.a"
