; CartoRig Atomic — Windows x64 installer for the native OpenFX bundle.
; Source project is independent from legacy CartoRig and third-party templates.
; Build with Inno Setup 6 on CI only — end users double-click one .exe.

#define MyAppName "CartoRig Atomic"
#define MyAppVersion "0.1.0-alpha"
#define MyCompany "CartoRig Contributors"
#define MyBundleName "CartoRigAtomic.ofx.bundle"

[Setup]
AppId={{AE5B0C88-D338-4C38-9783-2026AA9C2042}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyCompany}
DefaultDirName={commoncf64}\OFX\Plugins\{#MyBundleName}
DisableDirPage=yes
DisableProgramGroupPage=yes
UsePreviousAppDir=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
OutputDir=..\dist\installer
OutputBaseFilename=CartoRig-Atomic-Windows-x64-Setup
UninstallDisplayName=CartoRig Atomic (OpenFX)
ChangesAssociations=no
WizardStyle=modern
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "..\dist\ofx\Contents\Win64\CartoRigAtomic.ofx"; DestDir: "{app}\Contents\Win64"; Flags: ignoreversion
Source: "..\dist\ofx\Contents\Resources\cartorig-natural-earth-10m.catalog"; DestDir: "{app}\Contents\Resources"; Flags: ignoreversion
Source: "..\dist\ofx\Contents\Resources\natural-earth-manifest.json"; DestDir: "{app}\Contents\Resources"; Flags: ignoreversion
Source: "..\docs\implementation\NATIVE_CORE_V01.md"; DestDir: "{app}\Contents\Resources\Documentation"; Flags: ignoreversion

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
  if CheckForMutexes('DaVinci Resolve') then
  begin
    MsgBox('Close DaVinci Resolve before installing CartoRig Atomic.', mbError, MB_OK);
    Result := False;
  end;
end;
