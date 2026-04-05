[CmdletBinding()]
param(
    [switch]$SkipArchive
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$KlcPath = Join-Path $ProjectRoot 'colemak_dh_ansi_us.klc'
$SourceDir = Join-Path $ProjectRoot 'source'
$BuildDir = Join-Path $ProjectRoot 'build'
$OutputDir = Join-Path $ProjectRoot 'output'

$SourceBase = 'cdh_us'
$OutputBase = 'colemak_dh_ansi_us'
$OutputArch = "arm64"

$SourceC   = Join-Path $SourceDir "$SourceBase.C"
$SourceRC  = Join-Path $SourceDir "$SourceBase.RC"
$SourceDEF = Join-Path $SourceDir "$SourceBase.DEF"

$BuildOBJ = Join-Path $BuildDir "$SourceBase.obj"
$BuildRES = Join-Path $BuildDir "$SourceBase.RES"

$BuildDLL = Join-Path $BuildDir "$OutputBase.dll"
$OutputDLL = Join-Path $OutputDir "$OutputBase.dll"

$InstallScript = Join-Path $ProjectRoot 'install.ps1'
$UninstallScript = Join-Path $ProjectRoot 'uninstall.ps1'

function Require-Command([string]$Name) {
    Get-Command $Name | Out-Null
}

Require-Command kbdutool.exe
Require-Command cl.exe
Require-Command rc.exe
Require-Command link.exe

if (-not (Test-Path $KlcPath)) { throw "KLC file not found: $KlcPath" }
if (-not (Test-Path $InstallScript)) { throw "install.ps1 not found: $InstallScript" }
if (-not (Test-Path $UninstallScript)) { throw "uninstall.ps1 not found: $UninstallScript" }

Remove-Item $SourceDir, $BuildDir, $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $SourceDir, $BuildDir, $OutputDir | Out-Null

Push-Location $SourceDir
try {
    & kbdutool.exe -u -s $KlcPath
    if ($LASTEXITCODE -ne 0) { throw "kbdutool failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

if (-not (Test-Path $SourceC)) { throw "Generated source missing: $SourceC" }
if (-not (Test-Path $SourceRC)) { throw "Generated resource missing: $SourceRC" }
if (-not (Test-Path $SourceDEF)) { throw "Generated def missing: $SourceDEF" }

& cl.exe /nologo /TC /c $SourceC /Fo$BuildOBJ
if ($LASTEXITCODE -ne 0) { throw "cl failed with exit code $LASTEXITCODE" }

& rc.exe /r /fo $BuildRES $SourceRC
if ($LASTEXITCODE -ne 0) { throw "rc failed with exit code $LASTEXITCODE" }

& link.exe /dll /machine:arm64 /def:$SourceDEF /out:$BuildDLL /NOIMPLIB $BuildOBJ $BuildRES
if ($LASTEXITCODE -ne 0) { throw "link failed with exit code $LASTEXITCODE" }

Copy-Item $BuildDLL $OutputDLL -Force
Copy-Item $InstallScript (Join-Path $OutputDir 'install.ps1') -Force
Copy-Item $UninstallScript (Join-Path $OutputDir 'uninstall.ps1') -Force

$NoteFile = Join-Path $OutputDir 'NOTE.txt'
@"
The file $OutputBase.dll included here is a reference copy of the DLL
installed to %WINDIR%\System32. It is not used at runtime.

Source: https://github.com/spikespaz/colemak-dh-windows-arm64
"@ | Set-Content -Path $NoteFile -Encoding UTF8

Write-Host "Built: $OutputDLL" -ForegroundColor Green

if (-not $SkipArchive) {
    $ArchivePath = Join-Path $OutputDir "$OutputBase-${OutputArch}.zip"

    Compress-Archive `
        -Path (Join-Path $OutputDir '*') `
        -DestinationPath $ArchivePath `
        -CompressionLevel Optimal

    Write-Host "Archived: $ArchivePath" -ForegroundColor Green
}
