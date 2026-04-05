$ErrorActionPreference = 'Stop'

if (-not (Get-Command kbdutool.exe -ErrorAction SilentlyContinue)) {
    $env:Path += ';C:\Program Files (x86)\Microsoft Keyboard Layout Creator 1.4\bin\i386'
    Get-Command kbdutool.exe | Out-Null
}

$needEnv =
    -not (Get-Command cl.exe -ErrorAction SilentlyContinue) -or
    -not (Get-Command rc.exe -ErrorAction SilentlyContinue) -or
    -not (Get-Command link.exe -ErrorAction SilentlyContinue) -or
    -not $env:INCLUDE -or
    -not $env:LIB

if (-not $needEnv) {
    return
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (Test-Path $vswhere) {
    $vsInstallPath = & $vswhere -latest -products '*' -property installationPath 2>$null
    if ($vsInstallPath) {
        $vcvarsall = Join-Path $vsInstallPath 'VC\Auxiliary\Build\vcvarsall.bat'
    }
}

if (-not $vcvarsall -or -not (Test-Path $vcvarsall)) {
    throw "vcvarsall.bat not found. Install Visual Studio or Build Tools with the C++ ARM64 workload."
}

$envDump = cmd /c "`"$vcvarsall`" arm64 >nul && set"

foreach ($line in $envDump) {
    if ($line -match '^(.*?)=(.*)$') {
        Set-Item -Path "env:$($Matches[1])" -Value $Matches[2]
    }
}

foreach ($tool in 'cl.exe','rc.exe','link.exe') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool still not found after importing vcvarsall arm64 environment"
    }
}

if (-not $env:INCLUDE) { throw 'INCLUDE is still empty after importing vcvarsall arm64 environment' }
if (-not $env:LIB) { throw 'LIB is still empty after importing vcvarsall arm64 environment' }

if (-not (Get-Command kbdutool.exe -ErrorAction SilentlyContinue)) {
    $env:Path += ';C:\Program Files (x86)\Microsoft Keyboard Layout Creator 1.4\bin\i386'
    Get-Command kbdutool.exe | Out-Null
}
