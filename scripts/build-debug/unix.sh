#!/usr/bin/env bash

set -e

echo "Building debug Sucata CLI for Unix..."

echo "Building debug sucata CLI..."
EXTRA_FLAGS=()
if [ "$(uname -s)" = "Darwin" ]; then
  OPENSSL_PREFIX=$(brew --prefix openssl@3 2>/dev/null || true)
  if [ -z "$OPENSSL_PREFIX" ] || [ ! -d "$OPENSSL_PREFIX/lib" ]; then
    echo "OpenSSL 3 not found. Install it with: brew install openssl@3" >&2
    exit 1
  fi
  EXTRA_FLAGS+=(-extra-linker-flags:"-L$OPENSSL_PREFIX/lib")
fi

odin build src/ -out:sucata -debug -sanitize:address "${EXTRA_FLAGS[@]}"

echo "Done!"
