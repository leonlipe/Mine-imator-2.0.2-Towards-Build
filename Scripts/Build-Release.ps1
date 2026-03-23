<#
.SYNOPSIS
  Alias for Build-FromCpp.ps1 — produces ./Release (+ optional .zip) without GameMaker.

.DESCRIPTION
  Historically this script also mentioned Igor/GameMaker; the supported OSS workflow is C++ only.
  Forwards all parameters to Build-FromCpp.ps1 (including -SkipCppGen, -NoZip, -FreshZip).
#>
[CmdletBinding()]
param(
    [string] $Configuration = "Release",
    [string] $CppBuildDir = "",
    [switch] $SkipCppGen,
    [switch] $NoZip,
    [switch] $FreshZip
)

$here = $PSScriptRoot
$child = Join-Path $here "Build-FromCpp.ps1"
& $child -Configuration $Configuration -CppBuildDir $CppBuildDir -SkipCppGen:$SkipCppGen -NoZip:$NoZip -FreshZip:$FreshZip
