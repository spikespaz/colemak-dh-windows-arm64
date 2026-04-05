# Colemak-DH for Windows ARM64

This is documentation and scripts to build and install Colemak Mod-DH properly on Windows for ARM64.

![!Colemak Mod-DH, US ANSI](https://colemakmods.github.io/mod-dh/gfx/about/colemak_dh_main_ansi.png)

Upstream: <https://github.com/colemakmods/mod-dh>

Homepage: <https://colemakmods.github.io/mod-dh>

This repository: <https://github.com/spikespaz/colemak-dh-windows-arm64>

## Prerequisites:

### Visual Studio Build Tools for ARM64

1. Visit <https://my.visualstudio.com/downloads>
2. Search "Build Tools for Visual Studio 2026"
3. Change the "Architecture" column to `arm64`, download
5. Open PowerShell, and `cd ~\Downloads`
6. Run [VS Build Tools Install Command](#vs-build-tools-install-command)

<details>
<summary id="vs-build-tools-install-command"><b>VS Build Tools Install Command</b></summary>

```ps
.\vs_BuildTools.exe `
   --add Microsoft.VisualStudio.Component.VC.CoreBuildTools `
   --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 `
   --add Microsoft.Component.MSBuild `
   --add Microsoft.VisualStudio.Component.Windows11SDK.22621 `
   --passive --wait --norestart
```
</details>

### Microsoft Keyboard Layout Creator 1.4

1. Visit <https://www.microsoft.com/en-us/download/details.aspx?id=102134>
2. Download, run (extract), and start `setup.exe`

## Building:

1. Install [prerequisites](#prerequisites)
2. Clone this repository
3. Open PowerShell, `cd` to this project
2. Run `. .\shell.ps1`
4. Run `.\build.ps1`

Portable installer files are in `output/`.

## Installing

### From CI artifact

Pre-built installer files are available from the [latest CI run](https://github.com/spikespaz/colemak-dh-windows-arm64/actions/workflows/build-windows-arm64.yml). Download the `colemak_dh_ansi_us-arm64` artifact, extract it, and run:

```ps
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then reboot.

### From source

1. Open PowerShell, `cd` to this project
2. [Build `colemak_dh_ansi_us.dll`](#building)
3. Run `cd output`
4. Run `powershell -ExecutionPolicy Bypass -File .\install.ps1`
5. Reboot

You can now switch between your default layout and Colemak-DH with <kbd>Super</kbd>+<kbd>Space</kbd>.

## Uninstalling

You can uninstall the layout the same way as with any other program.
Go to *Settings* > *Apps* > *Installed apps* > scroll to *Colemak-DH (US)* > *...* > *Uninstall*, then reboot.

## License

For the packaging scripts portion of this repository:
```
Copyright (c) Jacob Birkett
Provided under the MIT License.
```

The file `colemak_dh_ansi_us.klc` is public domain, its parent repository (<https://github.com/colemakmods/mod-dh>) is Creative Commons Zero v1.0 Universal.
