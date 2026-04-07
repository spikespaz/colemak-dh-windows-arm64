# Colemak-DH for Windows ARM64

This is documentation and scripts to build and install Colemak Mod-DH properly on Windows for ARM64.

![!Colemak Mod-DH, US ANSI](https://colemakmods.github.io/mod-dh/gfx/about/colemak_dh_main_ansi.png)

Upstream: <https://github.com/colemakmods/mod-dh>

Homepage: <https://colemakmods.github.io/mod-dh>

This repository: <https://github.com/spikespaz/colemak-dh-windows-arm64>

## Prerequisites

### Visual Studio with C++ ARM64 tools

Any edition (Community, Enterprise, or Build Tools) works — `shell.ps1` finds it via `vswhere.exe`.

Install with at least these components:

```ps
.\vs_BuildTools.exe `
   --add Microsoft.VisualStudio.Component.VC.CoreBuildTools `
   --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 `
   --add Microsoft.Component.MSBuild `
   --add Microsoft.VisualStudio.Component.Windows11SDK.22621 `
   --passive --wait --norestart
```

### Microsoft Keyboard Layout Creator 1.4

1. Download [MSKLC.exe](https://www.microsoft.com/en-us/download/details.aspx?id=102134)
2. Extract it: `.\MSKLC.exe -y -o MSKLC`
3. Admin-install the MSI (bypasses .NET 3.5 dependency):
   ```ps
   msiexec /a MSKLC\MSKLC\MSKLC.msi /qn TARGETDIR="$PWD\msklc-install"
   ```
4. Copy `kbdutool.exe` and its dependencies to the expected path:
   ```ps
   $dst = 'C:\Program Files (x86)\Microsoft Keyboard Layout Creator 1.4\bin\i386'
   New-Item -ItemType Directory -Force $dst | Out-Null
   Copy-Item msklc-install\pfiles\MSKLC\bin\i386\* $dst -Force
   ```

## Building

1. Install [prerequisites](#prerequisites)
2. Clone this repository
3. Open PowerShell, `cd` to this project
4. Run `. .\shell.ps1`
5. Run `.\build.ps1`

Installer files are in `output/`.

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
4. Run `.\install.ps1` (or `powershell -ExecutionPolicy Bypass -File .\install.ps1` if downloaded from CI)
5. Reboot

You can now switch between your default layout and Colemak-DH with <kbd>Super</kbd>+<kbd>Space</kbd>.

## Uninstalling

You can uninstall the layout the same way as with any other program.
Go to <kbd>Settings</kbd> → <kbd>Apps</kbd> → <kbd>Installed apps</kbd> → <kbd>Colemak-DH (US)</kbd> → <kbd>...</kbd> → <kbd>Uninstall</kbd>, then reboot.

## License

For the packaging scripts portion of this repository:
```
Copyright (c) Jacob Birkett
Provided under the MIT License.
```

The file `colemak_dh_ansi_us.klc` is public domain, its parent repository (<https://github.com/colemakmods/mod-dh>) is Creative Commons Zero v1.0 Universal.
