# Noto — Windows installer
#
# Builds Noto for Windows and installs it to %LOCALAPPDATA%\Programs\Noto,
# creating a Start Menu shortcut. Uses .NET System.Drawing to generate the
# multi-resolution .ico from assets/icon.png so no external tools are needed.
#
# Usage:
#   .\install.ps1              # install
#   .\install.ps1 -Uninstall   # remove
#
# Requirements:
#   - Flutter SDK on PATH (https://docs.flutter.dev/get-started/install/windows)
#   - Visual Studio 2022 with the "Desktop development with C++" workload

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$AppName       = 'Noto'
$BinaryName    = 'noto'
$RepoRoot      = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir    = Join-Path $env:LOCALAPPDATA "Programs\$AppName"
$StartMenuDir  = [Environment]::GetFolderPath('StartMenu')
$ShortcutPath  = Join-Path $StartMenuDir "Programs\$AppName.lnk"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    $msg" -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "    $msg" -ForegroundColor Red }

if ($Uninstall) {
    Write-Step "Uninstalling $AppName"
    if (Test-Path $InstallDir) {
        Remove-Item -Recurse -Force $InstallDir
        Write-Ok "Removed $InstallDir"
    } else {
        Write-Warn2 "Install directory not present: $InstallDir"
    }
    if (Test-Path $ShortcutPath) {
        Remove-Item -Force $ShortcutPath
        Write-Ok "Removed Start Menu shortcut"
    }
    Write-Host ''
    Write-Warn2 "Your notes at $env:APPDATA\notes_app\ have NOT been touched."
    return
}

# --- 1. Prerequisites -------------------------------------------------------
Write-Step 'Checking prerequisites'

try { $null = Get-Command flutter -ErrorAction Stop } catch {
    Write-Err2 "Flutter not found on PATH."
    Write-Err2 "Install from https://docs.flutter.dev/get-started/install/windows"
    exit 1
}
Write-Ok "flutter: $((Get-Command flutter).Source)"

$doctorOut = & flutter doctor 2>&1 | Out-String
# Look for a passing check (✓ / √) on a line that mentions Visual Studio.
# A line like "[!] Visual Studio - missing components" should NOT pass.
$vsOk = $doctorOut -match '\[(?:√|✓|v)\][^\r\n]*Visual Studio'
if (-not $vsOk) {
    Write-Err2 "Visual Studio not detected (or incomplete) by 'flutter doctor'."
    Write-Err2 "Install VS 2022 with the 'Desktop development with C++' workload,"
    Write-Err2 "then run 'flutter doctor' until the Visual Studio line shows a check."
    exit 1
}
Write-Ok 'Visual Studio detected'

# --- 2. Generate Windows .ico from assets/icon.png --------------------------
Write-Step 'Generating Windows icon from assets/icon.png'

$SourcePng = Join-Path $RepoRoot 'assets\icon.png'
$IcoTarget = Join-Path $RepoRoot 'windows\runner\resources\app_icon.ico'

if (-not (Test-Path $SourcePng)) {
    Write-Err2 "Missing source PNG: $SourcePng"
    exit 1
}

# Back up Flutter's scaffolded .ico so recovery is one rename away if rc.exe
# rejects the custom-generated file for any reason.
if ((Test-Path $IcoTarget) -and -not (Test-Path "$IcoTarget.bak")) {
    Copy-Item -Path $IcoTarget -Destination "$IcoTarget.bak"
    Write-Ok "Backed up original icon → $IcoTarget.bak"
}

Add-Type -AssemblyName System.Drawing

$sizes = @(256, 128, 64, 48, 32, 16)
$pngBuffers = New-Object 'System.Collections.Generic.List[byte[]]'
$src = [System.Drawing.Image]::FromFile($SourcePng)
try {
    foreach ($size in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($src, 0, 0, $size, $size)
        $g.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBuffers.Add($ms.ToArray())
        $bmp.Dispose()
        $ms.Dispose()
    }
} finally {
    $src.Dispose()
}

$out = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($out)
$writer.Write([UInt16]0)                   # reserved
$writer.Write([UInt16]1)                   # type = icon
$writer.Write([UInt16]$sizes.Count)        # image count

$offset = 6 + (16 * $sizes.Count)
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $sz = $sizes[$i]
    $data = $pngBuffers[$i]
    $dim = if ($sz -ge 256) { 0 } else { $sz }   # 0 means 256
    $writer.Write([byte]$dim)                # width
    $writer.Write([byte]$dim)                # height
    $writer.Write([byte]0)                   # palette
    $writer.Write([byte]0)                   # reserved
    $writer.Write([UInt16]1)                 # color planes
    $writer.Write([UInt16]32)                # bits per pixel
    $writer.Write([UInt32]$data.Length)
    $writer.Write([UInt32]$offset)
    $offset += $data.Length
}
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $writer.Write($pngBuffers[$i])
}
$writer.Flush()
[System.IO.File]::WriteAllBytes($IcoTarget, $out.ToArray())
$writer.Dispose()
$out.Dispose()

Write-Ok "Wrote $IcoTarget ($($sizes.Count) sizes)"

# --- 3. Build ---------------------------------------------------------------
Push-Location $RepoRoot
try {
    Write-Step 'Resolving dependencies (flutter pub get)'
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

    Write-Step 'Patching pub cache'
    # quill_native_bridge_windows 0.0.2 calls GlobalAlloc(GMEM_MOVEABLE, ...),
    # a constant win32 >= 5.0 removed, and flutter_quill <= 11.5.1 does not
    # implement TextInputClient.onFocusReceived, required by Flutter >= 3.44.
    # Without these patches the release build fails to compile.
    & dart run tool/patch_pub_cache.dart
    if ($LASTEXITCODE -ne 0) { throw 'patching pub cache failed' }

    Write-Step 'Building Noto for Windows (release)'
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Err2 ''
        Write-Err2 "If the failure was at Runner.rc / rc.exe (icon resource),"
        Write-Err2 "restore the scaffolded icon and rebuild manually:"
        Write-Err2 "  Copy-Item -Force `"$IcoTarget.bak`" `"$IcoTarget`""
        Write-Err2 "  flutter build windows --release"
        throw 'flutter build windows --release failed'
    }
} finally {
    Pop-Location
}

$BuildDir = Join-Path $RepoRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path $BuildDir)) {
    Write-Err2 "Build output not found at $BuildDir"
    exit 1
}
$ExeInBuild = Join-Path $BuildDir "$BinaryName.exe"
if (-not (Test-Path $ExeInBuild)) {
    Write-Err2 "Expected $BinaryName.exe in $BuildDir but didn't find it."
    Write-Err2 'Check that windows/CMakeLists.txt sets BINARY_NAME = "noto".'
    exit 1
}
Write-Ok "Release bundle: $BuildDir"

# --- 4. Install -------------------------------------------------------------
Write-Step "Installing to $InstallDir"
if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Recurse -Path (Join-Path $BuildDir '*') -Destination $InstallDir
Write-Ok 'Copied release files'

$ExePath = Join-Path $InstallDir "$BinaryName.exe"

# --- 5. Start Menu shortcut -------------------------------------------------
Write-Step 'Creating Start Menu shortcut'
$shortcutParent = Split-Path -Parent $ShortcutPath
if (-not (Test-Path $shortcutParent)) {
    New-Item -ItemType Directory -Force -Path $shortcutParent | Out-Null
}
$wshell = New-Object -ComObject WScript.Shell
$lnk = $wshell.CreateShortcut($ShortcutPath)
$lnk.TargetPath       = $ExePath
$lnk.WorkingDirectory = $InstallDir
$lnk.IconLocation     = "$ExePath, 0"
$lnk.Description      = 'Noto — local encrypted notes'
$lnk.Save()
Write-Ok "Shortcut: $ShortcutPath"

Write-Host ''
Write-Host "$AppName installed successfully." -ForegroundColor Green
Write-Host "Launch it from the Start Menu, or run:" -ForegroundColor Green
Write-Host "  $ExePath" -ForegroundColor Green
Write-Host ''
Write-Host "To uninstall later:  .\install.ps1 -Uninstall" -ForegroundColor Gray
