; Inno Setup script for the Noto Windows installer.
;
; Built in CI by .github/workflows/release.yml, which passes the version:
;   ISCC.exe /DAppVersion=1.0.0 installer\noto.iss
;
; Inno Setup 6 ships preinstalled on GitHub's windows runners, so producing
; the installer downloads nothing.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName      "Noto"
#define AppPublisher "Noto contributors"
#define AppExeName   "noto.exe"
#define AppUrl       "https://github.com/AngelAragonMartinez/noto_app"

[Setup]
; Never change AppId: it is how Windows recognises an existing installation
; and offers an upgrade instead of a second copy.
AppId={{5E986D9C-6E42-4E2F-8F2D-CA6B183394B5}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#AppVersion}

; Per-user install under %LOCALAPPDATA%\Programs\Noto. PrivilegesRequired=lowest
; means no UAC prompt and no administrator account needed — the app writes only
; to the user's own profile, so machine-wide installation would buy nothing.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

OutputDir=..\dist
OutputBaseFilename=Noto-{#AppVersion}-windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
LicenseFile=..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

; No [UninstallDelete] on purpose. Uninstalling removes only what was
; installed; notes in %APPDATA%\Noto contributors\Noto\notes_app are the
; user's data and must survive.

[Code]
// Starts Noto in the language chosen in this wizard.
//
// Written as the same `locale` file the app already reads, so no code in the
// app has to know the installer exists.
//
// Only when that file is absent. On an upgrade the user may have switched
// language inside Noto since installing, and resetting that to whatever the
// wizard happens to be showing would undo their choice.
procedure CurStepChanged(CurStep: TSetupStep);
var
  DataDir: string;
  LocaleFile: string;
  Code: string;
begin
  if CurStep <> ssPostInstall then
    Exit;

  DataDir := ExpandConstant('{userappdata}\Noto contributors\Noto\notes_app');
  LocaleFile := DataDir + '\locale';

  if FileExists(LocaleFile) then
    Exit;

  if ActiveLanguage = 'spanish' then
    Code := 'es'
  else
    Code := 'en';

  if not DirExists(DataDir) then
    if not ForceDirectories(DataDir) then
      Exit;

  // Best effort: failing to seed the language must never fail the install.
  SaveStringToFile(LocaleFile, Code, False);
end;
