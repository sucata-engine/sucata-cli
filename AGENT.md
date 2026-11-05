# AGENT.md — sucata-cli

## What this is

`sucata-cli` is the developer-facing command-line tool for the [Sucata](https://sucata.dev) 2D game engine (Odin + Lua, in the spirit of Love2D/Godot). It is the `sucata` command that game developers run in their terminal — analogous to the `love` CLI for Love2D. It does **not** contain the engine runtime itself; it drives a separate sibling project, [sucata-player](../sucata-player/AGENT.md), which is the actual engine/runtime executable that plays a game.

Written entirely in [Odin](https://odin-lang.org/).

Responsibilities:
- `sucata run <file>` — launch a game (a Lua entry file) through the `sucata-player` binary during development.
- `sucata build <file>` — package a game's Lua/assets into a distributable, OS-specific executable by cloning `sucata-player` and embedding the assets.
- `sucata shader build|create` — compile custom `.glsl` shaders (via bundled `sokol-shdc`) into the engine's `.schd` shader format, or scaffold new shader templates.
- `sucata update` — self-update by re-running the install script.
- `sucata version` — print CLI/engine version info.

## Directory layout

```
sucata-cli/
├── src/                  Odin source (see "Packages" below)
├── scripts/
│   ├── build-debug/      odin build ... -debug -sanitize:address
│   ├── build-release/    odin build ... (optimized, no debug flags)
│   ├── install-luajit/   builds LuaJIT (same pinned commit as sucata-player) into src/luajit/lib/<os>/
│   └── install-shared/   clones the `http` shared Odin lib into $(odin root)/shared and runs install-luajit
├── sokol-shdc/           Prebuilt sokol-shdc compiler binaries (linux, linux-arm, osx, osx-arm)
├── assets/               Default engine icons embedded at compile time (icons/*.ico, *.icns, *.png)
├── sucata                Compiled CLI binary (build artifact, checked in — not source)
└── README.md
```

Note: unlike `sucata-player`, this project does **not** link `sokol` directly (it never renders anything) — `scripts/install-shared` only clones `odin-http`, not `sokol-odin`. There is no `ols.json` or other project config file here.

## Packages under `src/`

| Package | Path | Responsibility |
|---|---|---|
| `main` | `src/main.odin` | Entry point. Locates the sibling `sucata-player` binary, queries its `--version`, sets up logging, calls `cli.main()`. |
| `cli` | `src/cli/` | Command dispatch. `interfaces.odin` defines the `Command` struct (name, handler, subcommands); `cli.odin` recursively resolves subcommands from `os.args`; `main.odin` registers the root command tree (`run`, `build`, `version`, `shader`, `update`). Each subcommand has its own file: `build.odin`, `run.odin`, `shader.odin`, `update.odin`, `version.odin`. |
| `build` | `src/build/` | Turns a game project into a distributable. `assets.odin` walks Lua `require(...)`/`"src://..."` references, compiles `.lua` files to stripped LuaJIT bytecode (via `lua_compile.odin`, which calls `string.dump(fn, true)` on the embedded LuaJIT VM, so the output matches the LuaJIT inside `sucata-player`), optionally recompresses opaque images as JPEG when `--optimize` is passed (`optimize_images.odin`, skips anything with an alpha channel and never resizes, so atlas UVs stay valid), LZ4-compresses everything into a single `assets.scta` archive (manifest + payload), and returns a SHA-256 hash of it. `engine.odin`'s `clone_engine` copies the prebuilt `sucata-player` binary and appends a `SUCATA_BUILD_<hash>` trailer so the player can find its embedded assets at runtime; it also handles per-OS packaging (Windows: bundles `lua51.dll`/`SDL3.dll`, strips console subsystem, embeds `.ico`; Linux: writes a sidecar icon; macOS: builds a full `.app` bundle). |
| `luajit` | `src/luajit/` | LuaJIT 2.1 binding (copy of `sucata-player/src/luajit/luajit.odin`; keep both in sync). |
| `common` | `src/common/` | Small shared types (`Asset_Entry`, `Asset_Archive`) and colored console print helpers (`print_error`, `print_success`, etc). |
| `filesystem` | `src/filesystem/` | Resolves `src://`/`data://`/`build://` virtual paths to real ones; locates the CLI's own folder and the sibling `sucata-player[.exe]` binary; sets up per-OS data directories. |
| `shader_builder` (dir: `shaderbuilder/`) | `src/shaderbuilder/` | The shader compilation pipeline (see below). |
| `update` | `src/update/` | Checks the latest published `VERSION` on GitHub and re-runs the public install script (`install_unix.sh` / `install_windows.ps1`) to self-update. |

## Shader pipeline (`src/shaderbuilder/`)

Input is a hand-written `.glsl` file using `sokol-shdc`'s `@vs`/`@fs`/`@program` annotation syntax. `sucata shader build <file>`:
1. `sokolshader.odin` invokes the bundled `sokol-shdc` binary (picked per host OS/arch from `sokol-shdc/`) with `-l glsl430:hlsl5:metal_macos:wgsl -f bare_yaml`, producing a reflection YAML.
2. `yaml.odin` parses that YAML with a small hand-rolled parser (no external dependency).
3. `json.odin` inlines the actual compiled shader source for each stage and marshals the result to JSON.
4. `builder.odin` orchestrates the above and writes the final `<name>.schd` file next to the source `.glsl`.

`sucata shader create <file> [--post-processing|-pp] [--font|-f]` (`create.odin`) just scaffolds a starter `.glsl` from a built-in template.

## Build/engine assembly

Important: this CLI never compiles the engine from source. `sucata build` **copies** the prebuilt `sucata-player` binary (found next to the CLI executable) and appends a build-header trailer identifying the packaged assets. The real engine build lives in the [sucata-player](../sucata-player/AGENT.md) repo — `sucata-cli` and `sucata-player` are expected to be built and shipped together, with the player binary sitting alongside the CLI binary at runtime.

## Dev workflow

1. Install Odin (version pinned in `README.md`, currently `dev-2026-04-nightly:a896fb2`).
2. `./scripts/install-shared/unix.sh` (or `win.ps1`) — clones the `http` shared lib into Odin's `shared:` collection and builds LuaJIT. The LuaJIT commit must match `sucata-player`, since bytecode is only guaranteed to load on the same LuaJIT build.
3. Build: `./scripts/build-debug/unix.sh` (debug + ASan) or `./scripts/build-release/unix.sh` (optimized). Both invoke `odin build src/ -out:sucata [...]`.
4. For CLI commands to actually work end-to-end (`run`/`build`), a built `sucata-player` binary must exist alongside the `sucata` binary — build that from the sibling `sucata-player` repo first.

## Related

- [sucata-player/AGENT.md](../sucata-player/AGENT.md) — the engine/runtime this CLI drives.
- `docs/` (sibling repo, mkdocs site) — user-facing Lua API reference and getting-started guides at sucata.dev.
