#!/usr/bin/env bash

set -e

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$SCRIPTS_DIR/install-luajit/unix.sh"
