# Noto — Windows installer
#
# Builds Noto for Windows and installs it to %LOCALAPPDATA%\Programs\Noto,
# creating a Start Menu shortcut. The app icon is committed at
# windows/runner/resources/app_icon.ico, generated from assets/icon.png.
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

# --- 2. Build ---------------------------------------------------------------
Push-Location $RepoRoot
try {
    Write-Step 'Resolving dependencies (flutter pub get)'
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

    Write-Step 'Patching pub cache'
    # Two upstream build blockers, fixed rather than suppressed:
    # local_auth_windows passes MSVC's obsolete /await switch, which forces
    # <experimental/coroutine> and fails on current toolsets (STL1011); and
    # flutter_quill <= 11.5.1 lacks TextInputClient.onFocusReceived,
    # required by Flutter >= 3.44.
    & dart run tool/patch_pub_cache.dart
    if ($LASTEXITCODE -ne 0) { throw 'patching pub cache failed' }

    Write-Step 'Building Noto for Windows (release)'
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Err2 ''
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

# --- 3. Install -------------------------------------------------------------
Write-Step "Installing to $InstallDir"
if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Recurse -Path (Join-Path $BuildDir '*') -Destination $InstallDir
Write-Ok 'Copied release files'

$ExePath = Join-Path $InstallDir "$BinaryName.exe"

# --- 4. Start Menu shortcut -------------------------------------------------
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
