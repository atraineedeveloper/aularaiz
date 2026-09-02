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
ChangesEnvironment=yes
UninstallDisplayIcon={app}\aularaiz.exe
VersionInfoCompany=MindTzijib
VersionInfoDescription=AulaRaíz Installer
VersionInfoProductName=AulaRaíz
VersionInfoVersion={#AppVersion}.0

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Exposes aula.cmd / aularaiz.cmd / aularaiz-agent.exe as terminal commands by
; adding {app}\automation\bin to the per-user PATH. preservestringtype keeps the
; existing value type, and NeedsAddPath prevents duplicates on reinstall/update.
[Registry]
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\automation\bin"; Flags: preservestringtype; Check: NeedsAddPath('{app}\automation\bin')

[Icons]
Name: "{autoprograms}\AulaRaíz"; Filename: "{app}\aularaiz.exe"

[Run]
Filename: "{app}\aularaiz.exe"; Description: "Abrir AulaRaíz"; Flags: nowait postinstall skipifsilent

[Code]
function NeedsAddPath(Param: string): Boolean;
var
  OrigPath: string;
  AppDir: string;
begin
  AppDir := Param;
  if not RegQueryStringValue(
    HKEY_CURRENT_USER, 'Environment', 'Path', OrigPath) then
    OrigPath := '';
  Result := Pos(
    ';' + Uppercase(AppDir) + ';', ';' + Uppercase(OrigPath) + ';') = 0;
end;
