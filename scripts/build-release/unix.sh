#!/usr/bin/env bash

set -e

echo "Building Sucata CLI for Unix..."

echo "Building sucata CLI..."
odin build src/ -out:sucata -o:speed

echo "Done!"
