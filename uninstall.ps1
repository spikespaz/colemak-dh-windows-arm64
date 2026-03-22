[CmdletBinding()]
param(
    [string]$DllName = 'colemak_dh_ansi_us.dll',
    [string]$LayoutKey = 'a0010409',
    [string]$UninstallKeyName = 'ColemakDH_US',
    [string]$InstallDir = "$env:ProgramFiles\Colemak-DH (US)",
    [switch]$RemoveFromCurrentUserPreload,
	[switch]$Silent
)

$principal = New-Object Security.Principal.WindowsPrincipal `
    ([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    if (-not $Silent) {
        Write-Host "Requesting administrative privileges..."
        Write-Host "Waiting for elevated process to complete..."
    }

    $argumentList = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath
    )

    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        $argumentList += "-$($entry.Key)"
        if ($entry.Value -isnot [System.Management.Automation.SwitchParameter]) {
            $argumentList += [string]$entry.Value
        }
    }

    $proc = Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList $argumentList `
        -Wait `
        -PassThru

    if (-not $Silent) {
        Write-Host ""
        Write-Host "Elevated process exited with code $($proc.ExitCode)"
    }

    exit $proc.ExitCode
}

$ErrorActionPreference = 'Stop'

Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
'@

function Move-FileOnReboot([string]$ExistingPath, [string]$NewPath = $null) {
    $MOVEFILE_REPLACE_EXISTING = 0x1
    $MOVEFILE_DELAY_UNTIL_REBOOT = 0x4
    $flags = $MOVEFILE_DELAY_UNTIL_REBOOT
    if ($NewPath) { $flags = $flags -bor $MOVEFILE_REPLACE_EXISTING }

    if (-not [Win32.Native]::MoveFileEx($ExistingPath, $NewPath, $flags)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "MoveFileEx failed for '$ExistingPath' -> '$NewPath' with Win32 error $code"
    }
}

$ThisScript = $MyInvocation.MyCommand.Path
$TargetDll = Join-Path $env:WINDIR "System32\$DllName"
$InstalledUninstallScript = Join-Path $InstallDir 'uninstall.ps1'

$LayoutRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$LayoutKey"
$PreloadRegPath = "HKCU:\Keyboard Layout\Preload"
$UninstallRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallKeyName"

function Remove-CurrentUserPreloadEntry {
    if (-not (Test-Path $PreloadRegPath)) { return }

    $item = Get-ItemProperty -Path $PreloadRegPath
    $numericProps = @(
        $item.PSObject.Properties |
        Where-Object { $_.Name -match '^\d+$' } |
        Sort-Object { [int]$_.Name }
    )

    $remaining = @()
    foreach ($p in $numericProps) {
        if ([string]$p.Value -ne $LayoutKey) {
            $remaining += [string]$p.Value
        }
    }

    foreach ($p in $numericProps) {
        Remove-ItemProperty -Path $PreloadRegPath -Name $p.Name -ErrorAction SilentlyContinue
    }

    for ($i = 0; $i -lt $remaining.Count; $i++) {
        New-ItemProperty -Path $PreloadRegPath -Name ([string]($i + 1)) -PropertyType String -Value $remaining[$i] -Force | Out-Null
    }
}

if ($RemoveFromCurrentUserPreload) {
    Remove-CurrentUserPreloadEntry
}

if (Test-Path $LayoutRegPath) {
    Remove-Item -Path $LayoutRegPath -Recurse -Force
}

if (Test-Path $UninstallRegPath) {
    Remove-Item -Path $UninstallRegPath -Recurse -Force
}

if (Test-Path $TargetDll) {
    try {
        Remove-Item $TargetDll -Force
    }
    catch {
        Write-Warning "Could not remove DLL immediately. Scheduled deletion on reboot."
        Move-FileOnReboot $TargetDll
    }
}

$cleanupCmd = @"
ping 127.0.0.1 -n 3 >nul
del /f /q "$InstalledUninstallScript"
rmdir "$InstallDir" 2>nul
"@

Start-Process -FilePath cmd.exe -ArgumentList '/c', $cleanupCmd -WindowStyle Hidden

if (-not $Silent) {
    Write-Host "Uninstalled." -ForegroundColor Green
    Write-Host "If the DLL was in use, reboot to complete removal." -ForegroundColor Green
    Read-Host "Press Enter to close"
}
