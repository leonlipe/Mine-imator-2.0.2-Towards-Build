<#
.SYNOPSIS
  Install common build prerequisites on Windows (no GameMaker).

.DESCRIPTION
  Uses winget where possible:
    - .NET 8 SDK (for CppGen)
    - CMake
    - Visual Studio 2022 Build Tools with MSVC v143 (C++ workload)

  This script does NOT download Qt, FFmpeg, OpenAL, libzip, or x264 — those live under %DEV_DIR%
  and must be built or copied per [CppProject/BUILD.md](../CppProject/BUILD.md). The previous
  upstream workflow assumed C:\Dev with a long one-time Qt static build.

  After prerequisites:
    1. Set user env DEV_DIR (e.g. C:\Dev) — this script can offer to set it.
    2. Follow CppProject/BUILD.md for External\Win64 libs and Qt 5.15.9 prefix at %DEV_DIR%\Qt\5.15.9\build
    3. Run .\Scripts\Build-FromCpp.ps1

.PARAMETER DevDir
  Directory for Qt/sources (DEV_DIR). Default C:\Dev

.PARAMETER SkipWinget
  Only print checklist; do not run winget.

.EXAMPLE
  .\Scripts\Setup-DevEnvironment.ps1
  .\Scripts\Setup-DevEnvironment.ps1 -DevDir D:\Dev
#>
[CmdletBinding()]
param(
    [string] $DevDir = "C:\Dev",
    [switch] $SkipWinget,
    [switch] $SetUserDevDirEnv
)

$ErrorActionPreference = "Stop"

function Test-Winget {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

Write-Host @"

Mine-imator Towards — developer setup (C++ path, no GameMaker IDE)
================================================================

The game is built from CppProject. GML under GmProject/scripts is transpiled by CppGen into C++.

You need:
  [1] .NET 8 SDK, CMake, MSVC (this script can install via winget)
  [2] DEV_DIR = folder for Qt + source deps (default: $DevDir)
  [3] Qt 5.15.x static build at: %DEV_DIR%\Qt\5.15.9\build  (see CppProject/BUILD.md — large one-time build)
  [4] Prebuilt static libs under: CppProject\External\Win64  (zip, zlib, OpenAL, FFmpeg pieces, x264 — see BUILD.md)

"@

if ($SetUserDevDirEnv) {
    [Environment]::SetEnvironmentVariable("DEV_DIR", $DevDir, "User")
    $env:DEV_DIR = $DevDir
    Write-Host "Set user DEV_DIR=$DevDir (restart shell to pick up everywhere)."
}

if ($SkipWinget) {
    Write-Host "SkipWinget: exiting after checklist."
    exit 0
}

if (-not (Test-Winget)) {
    Write-Warning "winget not found. Install App Installer / winget, or install manually:"
    Write-Host "  - .NET 8 SDK: https://dotnet.microsoft.com/download/dotnet/8.0"
    Write-Host "  - CMake: https://cmake.org/download/"
    Write-Host "  - VS 2022 Build Tools + C++: https://visualstudio.microsoft.com/downloads/"
    exit 1
}

Write-Host "Installing packages via winget (may require admin / UAC)..."
# .NET 8 SDK
winget install --id Microsoft.DotNet.SDK.8 --accept-package-agreements --accept-source-agreements -e
# CMake
winget install --id Kitware.CMake --accept-package-agreements --accept-source-agreements -e
# MSVC Build Tools + Windows SDK
winget install --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements -e `
    --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

Write-Host @"

Next steps (manual — too large to automate here):
  - Open CppProject\BUILD.md and complete External + Qt steps for your DEV_DIR.
  - If DEV_DIR is not set: setx DEV_DIR `"$DevDir`"
  - Build from repo root:  .\Scripts\Build-FromCpp.ps1

Optional: re-run with -SetUserDevDirEnv to persist DEV_DIR for your user.

"@
