; ============================================================================
; AQ CheatsTool - Protected Windows Installer
; Version 3.2.0 - Encrypted Assets Build
; ============================================================================

#define MyAppName "AQ CheatsTool"
#define MyAppVersion "3.2.0"
#define MyAppPublisher "AQ///BIMMER"
#define MyAppURL "https://aqbimmer.com"
#define MyAppExeName "aq_cheats_tool.exe"
#define MyAppDescription "BMW Professional Diagnostic & Customization Tool"

[Setup]
AppId={{A8B7C6D5-E4F3-2A1B-9C8D-7E6F5A4B3C2D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=license.txt
InfoBeforeFile=readme.txt
OutputDir=output
OutputBaseFilename=AQCheatsTool_Setup_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=120
WizardImageFile=wizard_image.bmp
WizardSmallImageFile=wizard_small.bmp
SetupLogging=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.WelcomeLabel2=This will install [name/ver] on your computer.%n%nAQ///BIMMER - BMW Professional Diagnostic Tool%n%n%nFeatures:%n  - BMW Coding & Customization%n  - Welcome Light Configuration%n  - MGU Unlock Tools%n  - CC-ID Messages Reference%n  - ZGW Search%n  - Professional Diagnostic Suite%n%n%nClick Next to continue.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Protected build with encrypted assets
Source: "protected_build\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Images folder (non-sensitive, needed for UI)
Source: "..\assets\images\*"; DestDir: "{app}\data\flutter_assets\assets\images"; Flags: ignoreversion recursesubdirs createallsubdirs
; Hero images
Source: "..\assets\hero_images\*"; DestDir: "{app}\data\flutter_assets\assets\hero_images"; Flags: ignoreversion recursesubdirs createallsubdirs
; Clock images
Source: "..\assets\clock_images\*"; DestDir: "{app}\data\flutter_assets\assets\clock_images"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
Name: "{app}\logs"
Name: "{app}\temp"
Name: "{app}\config"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "{#MyAppDescription}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent shellexec

[UninstallRun]
Filename: "taskkill"; Parameters: "/F /IM {#MyAppExeName}"; Flags: runhidden; RunOnceId: "KillApp"

[Registry]
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"

[Code]
const
  AQ_DARK_BG = $2E1A1A;
  AQ_CARD_BG = $3E2116;
  AQ_ACCENT_CYAN = $D0FF00;
  AQ_SUCCESS = $5EC522;
  AQ_TEXT_PRIMARY = $FFFFFF;
  AQ_TEXT_SECONDARY = $B0B0B0;

var
  BrandLabel: TNewStaticText;
  
procedure InitializeWizard();
begin
  WizardForm.Color := AQ_DARK_BG;
  WizardForm.MainPanel.Color := AQ_CARD_BG;
  WizardForm.InnerPage.Color := AQ_DARK_BG;
  
  WizardForm.PageNameLabel.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.PageNameLabel.Font.Size := 14;
  WizardForm.PageNameLabel.Font.Style := [fsBold];
  
  WizardForm.PageDescriptionLabel.Font.Color := AQ_ACCENT_CYAN;
  WizardForm.WelcomeLabel1.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.WelcomeLabel1.Font.Size := 16;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  WizardForm.WelcomeLabel2.Font.Color := AQ_TEXT_PRIMARY;
  
  WizardForm.FinishedLabel.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.FinishedHeadingLabel.Font.Color := AQ_SUCCESS;
  WizardForm.FinishedHeadingLabel.Font.Size := 16;
  WizardForm.FinishedHeadingLabel.Font.Style := [fsBold];
  
  WizardForm.LicenseAcceptedRadio.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.LicenseNotAcceptedRadio.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.LicenseLabel1.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.LicenseMemo.Color := AQ_CARD_BG;
  WizardForm.LicenseMemo.Font.Color := AQ_TEXT_PRIMARY;
  
  WizardForm.SelectDirLabel.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.SelectDirBrowseLabel.Font.Color := AQ_TEXT_SECONDARY;
  WizardForm.DirEdit.Color := AQ_CARD_BG;
  WizardForm.DirEdit.Font.Color := AQ_TEXT_PRIMARY;
  
  WizardForm.TasksList.Color := AQ_CARD_BG;
  WizardForm.TasksList.Font.Color := AQ_TEXT_PRIMARY;
  
  WizardForm.ReadyMemo.Color := AQ_CARD_BG;
  WizardForm.ReadyMemo.Font.Color := AQ_TEXT_PRIMARY;
  
  WizardForm.InfoBeforeClickLabel.Font.Color := AQ_TEXT_PRIMARY;
  WizardForm.InfoBeforeMemo.Color := AQ_CARD_BG;
  WizardForm.InfoBeforeMemo.Font.Color := AQ_TEXT_PRIMARY;
  
  WizardForm.StatusLabel.Font.Color := AQ_ACCENT_CYAN;
  WizardForm.FilenameLabel.Font.Color := AQ_TEXT_SECONDARY;
  
  WizardForm.NextButton.Font.Style := [fsBold];
  WizardForm.Bevel.Visible := False;
  WizardForm.Bevel1.Visible := False;
  
  BrandLabel := TNewStaticText.Create(WizardForm);
  BrandLabel.Parent := WizardForm;
  BrandLabel.Caption := 'AQ///BIMMER - BMW Professional Diagnostic Tool';
  BrandLabel.Font.Color := AQ_ACCENT_CYAN;
  BrandLabel.Font.Size := 8;
  BrandLabel.Font.Style := [fsBold];
  BrandLabel.Left := 10;
  BrandLabel.Top := WizardForm.ClientHeight - 25;
  BrandLabel.AutoSize := True;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  case CurPageID of
    wpWelcome:
      begin
        WizardForm.WelcomeLabel1.Font.Color := AQ_TEXT_PRIMARY;
        WizardForm.WelcomeLabel2.Font.Color := AQ_TEXT_PRIMARY;
      end;
    wpFinished:
      begin
        WizardForm.FinishedLabel.Font.Color := AQ_TEXT_PRIMARY;
        WizardForm.FinishedHeadingLabel.Font.Color := AQ_SUCCESS;
        WizardForm.RunList.Font.Color := AQ_TEXT_PRIMARY;
        WizardForm.RunList.Color := AQ_DARK_BG;
      end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataPath, TempPath: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Clean up extracted files and app data
    TempPath := ExpandConstant('{%TEMP}\AQ_Attachments');
    if DirExists(TempPath) then
      DelTree(TempPath, True, True, True);
      
    if MsgBox('Remove all application data and settings?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      AppDataPath := ExpandConstant('{localappdata}\{#MyAppName}');
      if DirExists(AppDataPath) then
        DelTree(AppDataPath, True, True, True);
    end;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;
