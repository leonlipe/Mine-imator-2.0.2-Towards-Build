<#
.SYNOPSIS
  Generate C++ from GML (CppGen) and build the native Mine-imator executable — no GameMaker IDE.

.DESCRIPTION
  Mine-imator ships as a Qt/C++ app (CppProject) with logic transpiled from GmProject/*.gml via CppGen.
  This script:
    1. Runs CppGen (.NET 8) with explicit paths (stdin "n" skips interactive shader copy prompt).
    2. Configures and builds CppProject with CMake (Visual Studio generator on Windows).
    3. Copies Mine-imator.exe + runtime folders into ./Release.
  4. Unless -NoZip: creates Mine-imator-2.0.2-<version>-Win64.zip in ./Release for distribution.

  Use -FreshZip to wipe Release\\Projects, Schematics, and Skins before zipping (clean shareable archive; your local
  copies in those folders are removed).

  If CMake link, copying to Release\\Mine-imator.exe, or creating the ZIP fails because the app still has files open,
  the script force-closes processes named Mine-imator and retries the failing step once.

  You still need Qt + prebuilt External libs under %DEV_DIR% as described in CppProject/BUILD.md.
#>
[CmdletBinding()]
param(
    [string] $Configuration = "Release",
    [string] $CppBuildDir = "",
    [switch] $SkipCppGen,
    [switch] $NoZip,
    [switch] $FreshZip
)

$ErrorActionPreference = "Stop"

function Stop-MineImatorProcesses {
    $procs = Get-Process -Name "Mine-imator" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        Write-Warning "Force-closing Mine-imator (PID $($p.Id)) so the build can overwrite the executable."
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    if ($procs) {
        Start-Sleep -Seconds 1
    }
}

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Release = Join-Path $Root "Release"
New-Item -ItemType Directory -Force -Path $Release | Out-Null

$GmProject = Join-Path $Root "GmProject"
$CppGenProjDir = Join-Path $Root "CppGen\CppGen"
$CppGenCsproj = Join-Path $CppGenProjDir "CppGen.csproj"
$GmlJson = Join-Path $Root "CppGen\gml.json"
$GenOut = Join-Path $Root "CppProject\Generated"
$SprOut = Join-Path $Root "CppProject\Asset\Sprites"
$ShOut = Join-Path $Root "CppProject\Asset\Shaders"
$CppRoot = Join-Path $Root "CppProject"

if (-not (Test-Path (Join-Path $GmProject "Mine-imator.yyp"))) {
    Write-Error "GameMaker project not found: $GmProject\Mine-imator.yyp"
}
if (-not (Test-Path $GmlJson)) {
    Write-Error "Missing CppGen spec: $GmlJson"
}
if (-not (Test-Path $CppGenCsproj)) {
    Write-Error "Missing CppGen project: $CppGenCsproj"
}

if (-not $SkipCppGen) {
    Write-Host "=== CppGen: GML -> C++ ==="
    Push-Location $CppGenProjDir
    try {
        # Pipe "n" to decline copying shaders back into GmProject (non-interactive)
        "n" | dotnet run --project $CppGenCsproj -- `
            $GmProject `
            $GenOut `
            $SprOut `
            $ShOut `
            $GmlJson
        if ($LASTEXITCODE -ne 0) { Write-Error "CppGen failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }
}

if ($CppBuildDir -eq "") {
    $CppBuildDir = Join-Path $CppRoot "build-release"
}
New-Item -ItemType Directory -Force -Path $CppBuildDir | Out-Null

$isWin = ($null -ne $env:WINDIR)

Write-Host "=== CMake: configure ==="
if ($isWin) {
    cmake -S $CppRoot -B $CppBuildDir -G "Visual Studio 17 2022" -A x64
} else {
    cmake -S $CppRoot -B $CppBuildDir -DCMAKE_BUILD_TYPE=$Configuration
}
if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configure failed with exit code $LASTEXITCODE"
}

Write-Host "=== CMake: build ($Configuration) ==="
if ($isWin) {
    cmake --build $CppBuildDir --config $Configuration --parallel
} else {
    cmake --build $CppBuildDir --parallel
}
if ($LASTEXITCODE -ne 0) {
    Write-Warning "CMake build failed (exit $LASTEXITCODE). Retrying once after closing any running Mine-imator (often fixes LNK1104 / locked EXE)."
    Stop-MineImatorProcesses
    if ($isWin) {
        cmake --build $CppBuildDir --config $Configuration --parallel
    } else {
        cmake --build $CppBuildDir --parallel
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "CMake build failed after retry; exit code $LASTEXITCODE"
    }
}

$exe = Get-ChildItem -Path $CppBuildDir -Filter "Mine-imator.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) {
    Write-Error "Mine-imator.exe not found under $CppBuildDir"
}

$releaseExe = Join-Path $Release "Mine-imator.exe"
try {
    Copy-Item -Path $exe.FullName -Destination $releaseExe -Force -ErrorAction Stop
} catch {
    Write-Warning "Copy to Release failed (file may be in use): $($_.Exception.Message)"
    Stop-MineImatorProcesses
    Copy-Item -Path $exe.FullName -Destination $releaseExe -Force -ErrorAction Stop
}
Write-Host "Copied executable -> $releaseExe"

# Runtime layout next to the .exe (see AppHandler.cpp RELEASE_MODE)
$dataSrc = Join-Path $Root "GmProject\datafiles\Data"
if (Test-Path $dataSrc) {
    $dataDst = Join-Path $Release "Data"
    New-Item -ItemType Directory -Force -Path $dataDst | Out-Null
    Copy-Item -Path (Join-Path $dataSrc "*") -Destination $dataDst -Recurse -Force
    Write-Host "Copied datafiles\Data -> Release\Data"
}

$partSrc = Join-Path $Root "GmProject\datafiles\Particles"
if (Test-Path $partSrc) {
    $partDst = Join-Path $Release "Particles"
    New-Item -ItemType Directory -Force -Path $partDst | Out-Null
    Copy-Item -Path (Join-Path $partSrc "*") -Destination $partDst -Recurse -Force
    Write-Host "Copied datafiles\Particles -> Release\Particles"
}

foreach ($extra in @("Schematics", "Projects", "Skins")) {
    $d = Join-Path $Release $extra
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

if ($FreshZip) {
    Write-Host "=== FreshZip: emptying Projects, Schematics, Skins (clean distributable layout) ==="
    foreach ($extra in @("Schematics", "Projects", "Skins")) {
        $d = Join-Path $Release $extra
        if (Test-Path $d) {
            Get-ChildItem -Path $d -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

if (-not $NoZip) {
    $macrosPath = Join-Path $Root "GmProject\scripts\macros\macros.gml"
    $verTag = "Towards-Build"
    if (Test-Path $macrosPath) {
        $m = Select-String -Path $macrosPath -Pattern 'mineimator_version_sub\s+"([^"]+)"' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($m -and $m.Matches.Count -gt 0) {
            $verTag = $m.Matches[0].Groups[1].Value
        }
    }
    $safeVer = ($verTag -replace '[<>:"/\\|?*]', '-' -replace '\s+', '-')
    $zipName = "Mine-imator-2.0.2-$safeVer-Win64.zip"
    $zipPath = Join-Path $Release $zipName
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    $toZip = @(Get-ChildItem -Path $Release -Force | Where-Object { $_.Name -notlike '*.zip' })
    if ($toZip.Count -eq 0) {
        Write-Warning "Release folder has nothing to zip (unexpected)."
    }
    else {
        Write-Host "=== ZIP (shareable build): $zipName ==="
        try {
            Compress-Archive -Path ($toZip | ForEach-Object { $_.FullName }) -DestinationPath $zipPath -CompressionLevel Optimal -Force -ErrorAction Stop
        } catch {
            Write-Warning "ZIP failed (often Mine-imator.exe still running / file locked): $($_.Exception.Message)"
            Stop-MineImatorProcesses
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
            Compress-Archive -Path ($toZip | ForEach-Object { $_.FullName }) -DestinationPath $zipPath -CompressionLevel Optimal -Force -ErrorAction Stop
        }
        Write-Host "Created: $zipPath"
    }
}

Write-Host "=== Done. Run: $Release\Mine-imator.exe ==="
