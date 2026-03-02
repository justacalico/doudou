[Setup]
AppId=B9F6E402-0CAE-4045-BDE6-14BD6C39C4EA
AppVersion=1.12.2+27
AppName=Doudou
AppPublisher=openlyst
AppPublisherURL=https://gitlab.com/openlyst/doudou
AppSupportURL=https://gitlab.com/openlyst/doudou
AppUpdatesURL=https://gitlab.com/openlyst/doudou
DefaultDirName={autopf}\doudou
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=doudou-1.12.2
Compression=lzma
SolidCompression=yes
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest
LicenseFile=..\..\LICENSE
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\doudou.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\doudou"; Filename: "{app}\doudou.exe"
Name: "{autodesktop}\doudou"; Filename: "{app}\doudou.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\doudou.exe"; Description: "{cm:LaunchProgram,{#StringChange('doudou', '&', '&&')}}"; Flags: nowait postinstall skipifsilent
