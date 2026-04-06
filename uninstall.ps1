[CmdletBinding()]
param(
    [string]$DllName = 'colemak_dh_ansi_us.dll',
    [string]$LayoutKey = 'a0010409',
    [string]$UninstallKeyName = 'ColemakDH_US',
    [string]$InstallDir = "$env:ProgramFiles\Colemak-DH (US)",
    [switch]$RemoveFromCurrentUserPreload,
	[switch]$Silent,
	[string]$LogFile,
	[switch]$DllOnly,
	[switch]$Elevated
)

$principal = New-Object Security.Principal.WindowsPrincipal `
    ([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $Elevated -and
    -not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    if (-not $Silent) {
        Write-Host "Requesting administrative privileges..."
    }

    $logFile = Join-Path ([IO.Path]::GetTempPath()) "colemak-dh-uninstall-$PID.log"

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

    while (-not $Silent -and $proc.ExitCode -eq 2) {
        Write-Host "Switch to another layout (Super+Space), then press Enter to retry." -ForegroundColor Yellow
        Write-Host "Or press Ctrl+C to keep the reboot-scheduled deletion." -ForegroundColor Yellow
        Read-Host

        $logFile = Join-Path ([IO.Path]::GetTempPath()) "colemak-dh-uninstall-$PID.log"
        $retryArgs = @(
            '-ExecutionPolicy', 'Bypass',
            '-File', "`"$PSCommandPath`"",
            '-Elevated', '-DllOnly',
            '-LogFile', "`"$logFile`"",
            '-DllName', "`"$DllName`""
        )

        $proc = Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList $retryArgs `
            -Wait `
            -PassThru

        if (Test-Path $logFile) {
            Get-Content $logFile | ForEach-Object { Write-Host $_ }
            Remove-Item $logFile -ErrorAction SilentlyContinue
        }
    }

    if (-not $Silent -and $proc.ExitCode -ne 0 -and $proc.ExitCode -ne 2) {
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

if (-not $DllOnly) {
    if ($RemoveFromCurrentUserPreload) {
        Remove-CurrentUserPreloadEntry
    }

    if (Test-Path $LayoutRegPath) {
        Remove-Item -Path $LayoutRegPath -Recurse -Force
    }

    if (Test-Path $UninstallRegPath) {
        Remove-Item -Path $UninstallRegPath -Recurse -Force
    }
}

if (Test-Path $TargetDll) {
    try {
        Remove-Item $TargetDll -Force
    }
    catch {
        Write-Log "Could not remove DLL -- it is in use." -Warning
        Move-FileOnReboot $TargetDll
        Write-Log "Scheduled deletion on reboot as fallback."
        exit 2
    }
}

if (-not $DllOnly) {
    $InstalledNote = Join-Path $InstallDir 'NOTE.txt'

    $cleanupCmd = @(
        'timeout /t 2 /nobreak >nul'
        "del /f /q `"$InstalledNote`" 2>nul"
        "del /f /q `"$InstalledUninstallScript`""
        "rmdir `"$InstallDir`" 2>nul"
    ) -join "`r`n"
    Start-Process -FilePath cmd.exe -ArgumentList '/c', $cleanupCmd -WindowStyle Hidden
}

Write-Log "Uninstalled." -Color Green

if (-not $Silent -and -not $LogFile) {
    Read-Host "Press Enter to close"
}
