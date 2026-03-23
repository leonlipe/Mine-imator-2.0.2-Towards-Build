# Building Mine-imator 2.0.2 Towards

## What actually runs

The shipping app is the **native C++/Qt executable** built from [`CppProject`](../CppProject). Game logic lives as GML under [`GmProject/scripts`](../GmProject/scripts) (GameMaker **resource** layout), but it is **transpiled to C++** by [`CppGen`](../CppGen) and compiled into that binary.

You **do not need the GameMaker IDE** to build or run Mine-imator from this repository. You need:

1. **Toolchain** — MSVC (VS 2022 Build Tools or full VS), **CMake**, **.NET 8 SDK** (for CppGen).
2. **`DEV_DIR`** — a working folder (convention: `C:\Dev`) for Qt and third-party **sources** referenced by CMake (see [`CppProject/BUILD.md`](../CppProject/BUILD.md)).
3. **Qt 5.15.9 static build** at `%DEV_DIR%\Qt\5.15.9\build` (or `-Win32` variant if you flip `WINDOWS_32BIT` in CMake).
4. **Prebuilt static libraries** under [`CppProject/External/Win64`](../CppProject/External) (zip, zlib, OpenAL, FFmpeg pieces, x264, etc.) as described in `CppProject/BUILD.md`.

The upstream docs assume a long one-time Qt build; there is no small automatic download for that step.

## Two-step workflow (recommended)

From the **repository root** in PowerShell:

```powershell
# 1) Prerequisites (winget). Optional: persist DEV_DIR for your user account.
.\Scripts\Setup-DevEnvironment.ps1 -SetUserDevDirEnv

# 2) One-time: complete Qt + External libs per CppProject/BUILD.md (too large to script here).

# 3) Generate C++ from GML, compile, stage Release\, and create a shareable .zip
.\Scripts\Build-FromCpp.ps1
```

`Build-Release.ps1` is a thin wrapper around `Build-FromCpp.ps1` (same flags).

### Build script flags (power users)

| Flag | Effect |
|------|--------|
| `Build-FromCpp.ps1 -SkipCppGen` | Skip GML→C++ when `Generated` is already up to date. |
| `Build-FromCpp.ps1 -NoZip` | Do not create `Release\Mine-imator-2.0.2-…-Win64.zip` after staging. |
| `Build-FromCpp.ps1 -FreshZip` | Before creating the ZIP, **delete everything** under `Release\Projects`, `Schematics`, and `Skins` so the archive is a clean distributable (your local projects/skins in those folders are removed). |

Version string in the ZIP filename is read from `#macro mineimator_version_sub` in `GmProject\scripts\macros\macros.gml` (falls back to `Towards-Build` if missing).

### What the build does

| Step | Action |
|------|--------|
| **CppGen** | Parses `GmProject\` (`.yyp`, `scripts\`, `sprites\`, `shaders\`) and writes `CppProject\Generated\`, copies sprites/shaders as needed. |
| **CMake** | Configures `CppProject` with the Visual Studio 2022 x64 generator (Windows) and builds **Release**. |
| **Stage** | Copies `Mine-imator.exe`, `GmProject\datafiles\Data` → `Release\Data`, `Particles` → `Release\Particles`, and creates empty `Schematics`, `Projects`, `Skins`. |
| **ZIP** | Packs everything under `Release\` **except** existing `.zip` files into `Mine-imator-2.0.2-<version-sub>-Win64.zip` for distribution. |

If **Mine-imator is still running**, the linker, `Copy-Item` to `Release\Mine-imator.exe`, or **`Compress-Archive`** (ZIP reads every file under `Release\`) can fail. `Build-FromCpp.ps1` then **force-closes** any process named `Mine-imator` and **retries** the CMake build, the copy, and/or the ZIP step once.

CppGen may ask to copy shaders back into `GmProject`; the script pipes **`n`** so the run stays non-interactive.

**Note:** `GmProject\scripts\` (lowercase) are GameMaker assets. Automation and build entry points live in **`Scripts\`** (capital **S**) at the repo root — there is no separate README inside `Scripts\`; this file is the canonical script documentation.

## Editing GML without GameMaker

- Edit `.gml` files under `GmProject/scripts/...` in any editor.
- Adding new script **folders** may require updating `Mine-imator.yyp` (JSON) by hand or opening the IDE once; routine edits to existing scripts do not need the IDE.
- After GML changes, run `Scripts\Build-FromCpp.ps1` (or `-SkipCppGen` only if you did not touch GML and Generated is up to date).

## GameMaker IDE (optional)

The IDE is optional: asset browser, room editor (if any), and automatic `.yyp` maintenance. It is **not** required to produce `Mine-imator.exe` once the C++ pipeline above works.

## macOS / Linux

`Setup-DevEnvironment.ps1` is Windows-oriented. Install CMake, Clang/LLVM, OpenMP, and Qt per `CppProject/BUILD.md`, set `DEV_DIR`, then run CppGen and CMake manually (same arguments as in `Build-FromCpp.ps1`, adapted for your generator). ZIP packaging is Windows-only in the script; use `zip` manually for releases.

## Verification (mesh import)

1. Run `Release\Mine-imator.exe`.
2. Import `Docs\samples\teddy.obj` (or drag-drop).
3. Confirm the mesh appears in preview and timeline.

## Formatting (C++)

Use [`.clang-format`](../.clang-format) with `clang-format` on individual files. GML: [`.editorconfig`](../.editorconfig) only.
