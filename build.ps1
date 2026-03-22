[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$KlcPath = Join-Path $ProjectRoot 'colemak_dh_ansi_us.klc'
$SourceDir = Join-Path $ProjectRoot 'source'
$BuildDir = Join-Path $ProjectRoot 'build'
$OutputDir = Join-Path $ProjectRoot 'output'

$SourceBase = 'cdh_us'
$OutputBase = 'colemak_dh_ansi_us'

$SourceC   = Join-Path $SourceDir "$SourceBase.C"
$SourceRC  = Join-Path $SourceDir "$SourceBase.RC"
$SourceDEF = Join-Path $SourceDir "$SourceBase.DEF"

$BuildOBJ = Join-Path $BuildDir "$SourceBase.obj"
$BuildRES = Join-Path $BuildDir "$SourceBase.RES"

$BuildDLL = Join-Path $BuildDir "$OutputBase.dll"
$OutputDLL = Join-Path $OutputDir "$OutputBase.dll"

function Require-Command([string]$Name) {
    Get-Command $Name | Out-Null
}

Require-Command kbdutool.exe
Require-Command cl.exe
Require-Command rc.exe
Require-Command link.exe

if (-not (Test-Path $KlcPath)) {
    throw "KLC file not found: $KlcPath"
}

Remove-Item $SourceDir, $BuildDir, $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $SourceDir, $BuildDir, $OutputDir | Out-Null

Push-Location $SourceDir
try {
    & kbdutool.exe -u -s $KlcPath
    if ($LASTEXITCODE -ne 0) {
        throw "kbdutool failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path $SourceC)) {
    throw "Generated source missing: $SourceC"
}
if (-not (Test-Path $SourceRC)) {
    throw "Generated resource missing: $SourceRC"
}
if (-not (Test-Path $SourceDEF)) {
    throw "Generated def missing: $SourceDEF"
}

& cl.exe /nologo /TC /c $SourceC /Fo$BuildOBJ
if ($LASTEXITCODE -ne 0) {
    throw "cl failed with exit code $LASTEXITCODE"
}

& rc.exe /r /fo $BuildRES $SourceRC
if ($LASTEXITCODE -ne 0) {
    throw "rc failed with exit code $LASTEXITCODE"
}

& link.exe /dll /machine:arm64 /def:$SourceDEF /out:$BuildDLL /NOIMPLIB $BuildOBJ $BuildRES
if ($LASTEXITCODE -ne 0) {
    throw "link failed with exit code $LASTEXITCODE"
}

Copy-Item $BuildDLL $OutputDLL -Force

Write-Host "Built: $OutputDLL" -ForegroundColor Green
