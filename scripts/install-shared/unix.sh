#!/usr/bin/env bash

set -e

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

ODIN_ROOT=$(odin root)
ODIN_SHARED="$ODIN_ROOT/shared"

cd $ODIN_SHARED

rm -rf http

git clone https://github.com/laytan/odin-http.git
mv ./odin-http ./http
rm -rf odin-http
"$SCRIPTS_DIR/install-luajit/unix.sh"
