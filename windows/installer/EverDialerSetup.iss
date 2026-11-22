; Ever Dialer PC - Inno Setup Script
#define MyAppName "Ever Dialer PC"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Ever Dialer"
#define MyAppURL "https://github.com/hari161008/Ever-Dialer-PC"
#define MyAppExeName "ever_dialer_pc.exe"

[Setup]
; App Identity
AppId={{9B78B457-3DF1-4682-A0FB-9BD0DFB4947E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Destination Folder & Privileges
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog
OutputDir=Output
OutputBaseFilename=Ever Dialer {#MyAppVersion} Setup Recommended
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Close running application before installing
CloseApplications=force
CloseApplicationsFilter=ever_dialer_pc.exe,bt_sync_daemon.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/F /IM bt_sync_daemon.exe /T"; Flags: runhidden; RunOnceId: "KillDaemon"
Filename: "taskkill.exe"; Parameters: "/F /IM ever_dialer_pc.exe /T"; Flags: runhidden; RunOnceId: "KillApp"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\*"
Type: files; Name: "{autodesktop}\{#MyAppName}.lnk"
Type: files; Name: "{autoprograms}\{#MyAppName}.lnk"
Type: files; Name: "{userappdata}\Microsoft\Windows\Start Menu\Programs\Startup\{#MyAppName}.lnk"
Type: filesandordirs; Name: "{%USERPROFILE}\.cache\everdialer"
Type: filesandordirs; Name: "{localappdata}\Ever Dialer PC"
Type: filesandordirs; Name: "{userappdata}\ever_dialer_pc"
