# Colemak-DH for Windows ARM64

This is documentation and scripts to build and install Colemak Mod-DH properly on Windows for ARM64.

![!Colemak Mod-DH, US ANSI](https://colemakmods.github.io/mod-dh/gfx/about/colemak_dh_main_ansi.png)

Upstream: <https://github.com/colemakmods/mod-dh>

Homepage: <https://colemakmods.github.io/mod-dh>

This repository: <https://github.com/spikespaz/colemak-dh-windows-arm64>

## Prerequisites:

1. Visit <https://my.visualstudio.com/downloads>
2. Search "Build Tools for Visual Studio 2026"
2. Change the "Architecture" column to `arm64`
3. Download
4. Open PowerShell, and `cd ~\Downloads`
5. Run [this command](#vs-build-tools-install-command)
5. Visit <https://www.microsoft.com/en-us/download/details.aspx?id=102134>
6. Download, run (extract), and start `setup.exe`

## Building:

1. Install [prerequisites](#prerequisites)
2. Clone this repository
3. Open PowerShell, `cd` to this project
4. Run `./build.ps1` (change execution policy)

Portable installer files are in `output/`.

## Installing:

1. Open PowerShell, `cd` to this project
2. [Build `colemak_dh_ansi_us.dll`](#building)
3. Run `cd output`
4. Run `.\install.ps1`
5. Reboot

You can now switch between your default layout and Colemak-DH with <kbd>Super</kbd>+<kbd>Space</kbd>.

## Uninstalling

You can uninstall the layout the same way as with any other program.
Go to *Settings* > *Apps* > *Installed apps* > scroll to *Colemak-DH (US)* > *...* > *Uninstall*, then reboot.

### VS Build Tools Install Command

```ps
.\vs_BuildTools.exe `
   --add Microsoft.VisualStudio.Component.VC.CoreBuildTools `
   --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 `
   --add Microsoft.Component.MSBuild `
   --add Microsoft.VisualStudio.Component.Windows11SDK.22621 `
   --passive --wait --norestart
```