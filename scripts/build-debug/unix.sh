#!/usr/bin/env bash

set -e

echo "Building debug Sucata CLI for Unix..."

echo "Building debug sucata CLI..."
odin build src/ -out:sucata -debug -sanitize:address

echo "Done!"
