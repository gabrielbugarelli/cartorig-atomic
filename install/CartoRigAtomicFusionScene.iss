; CartoRig Atomic — Fusion Scene, Windows user-space installer.
; Source contract: CR-PS-2.0. All package contents are written from zero.
; Installs one Comp script; editors do not need Python, Lua or a terminal.

#define AppName "CartoRig Atomic - Fusion Scene"
#define AppVersion "0.2.0-dev"

[Setup]
AppId={{7B984B49-3F1E-45FC-9FE9-F2026F021B07}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=CartoRig Atomic Contributors
DefaultDirName={userappdata}\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp
DisableDirPage=yes
DisableProgramGroupPage=yes
UsePreviousAppDir=no
PrivilegesRequired=lowest
OutputDir=..\dist\installer
OutputBaseFilename=CartoRig-Atomic-Fusion-Scene-Windows-Dev
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=CartoRig Atomic - Fusion Scene (Development Build)
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\dist\CartoRig Scene.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\fusion\fuses\CartoRigAtomicLand.fuse"; DestDir: "{userappdata}\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses"; Flags: ignoreversion
Source: "..\dist\CartoRigAtomic_Data\places.tsv"; DestDir: "{app}\CartoRigAtomic_Data"; Flags: ignoreversion
Source: "..\dist\CartoRigAtomic_Data\cartorig-data-manifest.json"; DestDir: "{app}\CartoRigAtomic_Data"; Flags: ignoreversion
Source: "..\dist\CartoRigAtomic_Data\geometry.tsv"; DestDir: "{app}\CartoRigAtomic_Data"; Flags: ignoreversion
Source: "..\dist\CartoRigAtomic_Data\cartorig-geometry-manifest.json"; DestDir: "{app}\CartoRigAtomic_Data"; Flags: ignoreversion

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
  if MsgBox('Please close DaVinci Resolve before installation. This developer build installs the Fusion Scene script only. Continue?', mbConfirmation, MB_YESNO) <> IDYES then
    Result := False;
end;
