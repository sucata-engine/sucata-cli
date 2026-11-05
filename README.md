# Sucata CLI

The `sucata` command-line tool for the [Sucata](https://sucata.dev) 2D game engine — used to `run` a game during development, `build` it into a standalone distributable, and compile custom `.glsl` shaders. It drives the sibling [sucata-player](https://github.com/sucata-engine/sucata-player) runtime, which contains the actual engine.

Written in [Odin](https://odin-lang.org/).

## Commands

| Command | Purpose |
|---|---|
| `sucata run <main.lua>` | Run a game through the `sucata-player` runtime in dev mode. |
| `sucata build <main.lua>` | Package a game into a native, OS-specific distributable. |
| `sucata shader build\|create <file.glsl>` | Compile or scaffold a custom shader. |
| `sucata update` | Self-update the CLI. |
| `sucata version` | Print CLI/engine version. |

## Setup project

1. Install [odin](https://odin-lang.org/) version: dev-2026-04-nightly:a896fb2
2. Install the shared libs, you can use `./scripts/install-shared/unix.sh` or `./scripts/install-shared/win.ps1` (it also builds LuaJIT via `scripts/install-luajit`; on Windows run it from a "x64 Native Tools Command Prompt for VS")
3. Now you can edit!

## Build project

Just use the script for build a debug version: 
`./scripts/build-debug/unix.sh` or `./scripts/build-debug/win.ps1`

or release version:
`./scripts/build-release/unix.sh` or `./scripts/build-release/win.ps1`