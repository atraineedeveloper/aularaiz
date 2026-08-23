#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif

[Setup]
AppId={{8AD2F102-5CED-43FF-91E4-2D4D75031ED8}
AppName=AulaRaíz
AppVersion={#AppVersion}
AppVerName=AulaRaíz {#AppVersion}
AppPublisher=MindTzijib
DefaultDirName={localappdata}\Programs\AulaRaiz
DefaultGroupName=AulaRaíz
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=AulaRaiz-Setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\aularaiz.exe
VersionInfoCompany=MindTzijib
VersionInfoDescription=AulaRaíz Installer
VersionInfoProductName=AulaRaíz
VersionInfoVersion={#AppVersion}.0

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\AulaRaíz"; Filename: "{app}\aularaiz.exe"

[Run]
Filename: "{app}\aularaiz.exe"; Description: "Abrir AulaRaíz"; Flags: nowait postinstall skipifsilent
