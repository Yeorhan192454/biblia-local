; Instalador do Windows (Inno Setup). Rodado pelo GitHub Actions.
#define AppVersion GetEnv("APP_VERSION")

[Setup]
AppId={{6B1C2E7A-4F0D-4C59-9E3B-7A1B5D0C2F11}
AppName=Bíblia Local
AppVersion={#AppVersion}
AppPublisher=Bíblia Local
DefaultDirName={autopf}\Biblia Local
DefaultGroupName=Bíblia Local
OutputDir=..\dist
OutputBaseFilename=BibliaLocal-{#AppVersion}-windows-instalador
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Bíblia Local"; Filename: "{app}\biblia_local.exe"
Name: "{autodesktop}\Bíblia Local"; Filename: "{app}\biblia_local.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\biblia_local.exe"; Description: "{cm:LaunchProgram,Bíblia Local}"; Flags: nowait postinstall skipifsilent
; atualização automática (instalador rodado em modo silencioso pelo app): reabre o app no fim
Filename: "{app}\biblia_local.exe"; Flags: nowait runasoriginaluser; Check: WizardSilent
