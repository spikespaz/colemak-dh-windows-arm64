[CmdletBinding()]
param(
    [string]$DllName = 'colemak_dh_ansi_us.dll',
    [string]$LayoutKey = 'a0010409',
    [string]$LayoutText = 'Colemak-DH (US)',
    [string]$LayoutId = '00f8',
    [string]$UninstallKeyName = 'ColemakDH_US',
    [string]$InstallDir = "$env:ProgramFiles\Colemak-DH (US)",
    [switch]$AddToCurrentUserPreload,
	[switch]$Silent,
	[string]$LogFile,
	[switch]$Elevated
)

$principal = New-Object Security.Principal.WindowsPrincipal `
    ([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $Elevated -and
    -not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    if (-not $Silent) {
        Write-Host "Requesting administrative privileges..."
    }

    $logFile = Join-Path ([IO.Path]::GetTempPath()) "colemak-dh-install-$PID.log"

    $argumentList = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"",
        '-Elevated',
        '-LogFile', "`"$logFile`""
    )

    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        if ($entry.Key -in @('Elevated', 'LogFile')) { continue }

        $argumentList += "-$($entry.Key)"

        if ($entry.Value -isnot [System.Management.Automation.SwitchParameter]) {
            $argumentList += "`"$($entry.Value)`""
        }
    }

    $proc = Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList $argumentList `
        -Wait `
        -PassThru

    if (-not $Silent -and (Test-Path $logFile)) {
        Get-Content $logFile | ForEach-Object { Write-Host $_ }
        Remove-Item $logFile -ErrorAction SilentlyContinue
    }

    if (-not $Silent -and $proc.ExitCode -ne 0) {
        Write-Host "Elevated process exited with code $($proc.ExitCode)" -ForegroundColor Red
    }

    exit $proc.ExitCode
}

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [ConsoleColor]$Color = 'White', [switch]$Warning)
    if ($Warning) { Write-Warning $Message } else { Write-Host $Message -ForegroundColor $Color }
    if ($LogFile) { Add-Content -Path $LogFile -Value $Message }
}

trap {
    if ($LogFile) { Add-Content -Path $LogFile -Value "ERROR: $_" }
    break
}

Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
'@

function Move-FileOnReboot([string]$ExistingPath, $NewPath = [NullString]::Value) {
    $MOVEFILE_REPLACE_EXISTING = 0x1
    $MOVEFILE_DELAY_UNTIL_REBOOT = 0x4
    $flags = $MOVEFILE_DELAY_UNTIL_REBOOT
    if ($NewPath -ne [NullString]::Value) { $flags = $flags -bor $MOVEFILE_REPLACE_EXISTING }

    if (-not [Win32.Native]::MoveFileEx($ExistingPath, $NewPath, $flags)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "MoveFileEx failed for '$ExistingPath' -> '$NewPath' with Win32 error $code"
    }
}

function Get-StringProp($Path, $Name) {
    try { (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Ensure-Dir([string]$Path) {
    New-Item -ItemType Directory -Force $Path | Out-Null
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceDll = Join-Path $ScriptDir $DllName
$SourceUninstallScript = Join-Path $ScriptDir 'uninstall.ps1'
$SourceNote = Join-Path $ScriptDir 'NOTE.txt'

$TargetDll = Join-Path $env:WINDIR "System32\$DllName"
$InstalledUninstallScript = Join-Path $InstallDir 'uninstall.ps1'
$InstalledNote = Join-Path $InstallDir 'NOTE.txt'

$LayoutRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$LayoutKey"
$PreloadRegPath = "HKCU:\Keyboard Layout\Preload"
$UninstallRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"

if (-not (Test-Path $SourceDll)) { throw "DLL not found next to script: $SourceDll" }
if (-not (Test-Path $SourceUninstallScript)) { throw "uninstall.ps1 not found next to script: $SourceUninstallScript" }

$sourceHash = (Get-FileHash $SourceDll -Algorithm SHA256).Hash
$targetExists = Test-Path $TargetDll
$targetHash = if ($targetExists) { (Get-FileHash $TargetDll -Algorithm SHA256).Hash } else { $null }

$layoutOwned =
    (Test-Path $LayoutRegPath) -and
    (Get-StringProp $LayoutRegPath 'Layout File') -eq $DllName

$uninstallOwned = Test-Path $UninstallRegPath

if ($targetExists -and $targetHash -eq $sourceHash -and $layoutOwned -and $uninstallOwned) {
    Write-Log "Already installed." -Color Yellow
} else {
    Ensure-Dir $InstallDir
    Copy-Item $SourceUninstallScript $InstalledUninstallScript -Force
    if (Test-Path $SourceNote) { Copy-Item $SourceNote $InstalledNote -Force }

    if (-not $targetExists) {
        Copy-Item $SourceDll $TargetDll -Force
    } else {
        try {
            Copy-Item $SourceDll $TargetDll -Force
        }
        catch {
            if (-not $layoutOwned -and -not $uninstallOwned) {
                throw "$DllName is pending deletion from a previous uninstall. Reboot, or switch to another layout (Super+Space) and uninstall again, before reinstalling."
            }

            $stagedDll = Join-Path $InstallDir $DllName
            Copy-Item $SourceDll $stagedDll -Force
            Write-Log "Could not replace loaded DLL immediately. Scheduled replacement on reboot." -Warning
            Move-FileOnReboot $stagedDll $TargetDll
        }
    }
}

New-Item -Path $LayoutRegPath -Force | Out-Null
New-ItemProperty -Path $LayoutRegPath -Name 'Layout File' -PropertyType String -Value $DllName -Force | Out-Null
New-ItemProperty -Path $LayoutRegPath -Name 'Layout Text' -PropertyType String -Value $LayoutText -Force | Out-Null
New-ItemProperty -Path $LayoutRegPath -Name 'Layout Id'   -PropertyType String -Value $LayoutId -Force | Out-Null

if ($AddToCurrentUserPreload) {
    if (-not (Test-Path $PreloadRegPath)) {
        New-Item -Path $PreloadRegPath -Force | Out-Null
    }

    $item = Get-ItemProperty -Path $PreloadRegPath
    $existing = @{}
    foreach ($p in $item.PSObject.Properties) {
        if ($p.Name -match '^\d+$') {
            $existing[[int]$p.Name] = [string]$p.Value
        }
    }

    if (-not ($existing.Values -contains $LayoutKey)) {
        $slot = 1
        while ($existing.ContainsKey($slot)) { $slot++ }
        New-ItemProperty -Path $PreloadRegPath -Name ([string]$slot) -PropertyType String -Value $LayoutKey -Force | Out-Null
    }
}

$uninstallCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$InstalledUninstallScript`" -DllName `"$DllName`" -LayoutKey `"$LayoutKey`" -UninstallKeyName `"$UninstallKeyName`" -InstallDir `"$InstallDir`""
$quietUninstallCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$InstalledUninstallScript`" -Silent -DllName `"$DllName`" -LayoutKey `"$LayoutKey`" -UninstallKeyName `"$UninstallKeyName`" -InstallDir `"$InstallDir`""

New-Item -Path $UninstallRegPath -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'DisplayName'          -PropertyType String -Value $LayoutText -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'DisplayVersion'       -PropertyType String -Value '1.0' -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'Publisher'            -PropertyType String -Value 'Jacob Birkett' -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'InstallLocation'      -PropertyType String -Value $InstallDir -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'UninstallString'      -PropertyType String -Value $uninstallCmd -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'QuietUninstallString' -PropertyType String -Value $quietUninstallCmd -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'DisplayIcon'          -PropertyType String -Value "$env:WINDIR\System32\ddores.dll,30" -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'NoModify'             -PropertyType DWord  -Value 1 -Force | Out-Null
New-ItemProperty -Path $UninstallRegPath -Name 'NoRepair'             -PropertyType DWord  -Value 1 -Force | Out-Null
$installedBytes = (Get-Item $SourceDll).Length + (Get-Item $SourceUninstallScript).Length
if (Test-Path $SourceNote) { $installedBytes += (Get-Item $SourceNote).Length }
New-ItemProperty -Path $UninstallRegPath -Name 'EstimatedSize'        -PropertyType DWord  -Value ([math]::Ceiling($installedBytes / 1KB)) -Force | Out-Null

Write-Log "Installed or repaired." -Color Green
Write-Log "Sign out and sign back in, or reboot, if the layout was in use." -Color Green

if (-not $Silent -and -not $LogFile) {
    Read-Host "Press Enter to close"
}
