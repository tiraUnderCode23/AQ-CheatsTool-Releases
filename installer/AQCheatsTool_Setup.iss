; ============================================================================
; AQ CheatsTool - Professional Windows Installer
; Version 3.2.0 - Modern Dark UI with AQ///BIMMER Branding
; ============================================================================
; UI Design: Cyberpunk/Automotive Dark Theme
; Color Palette: Deep Navy + Cyan Accent
; ============================================================================

#define MyAppName "AQ CheatsTool"
#define MyAppVersion "3.2.0"
#define MyAppPublisher "AQ///BIMMER"
#define MyAppURL "https://aqbimmer.com"
#define MyAppExeName "aq_cheats_tool.exe"
#define MyAppDescription "BMW Professional Diagnostic & Customization Tool"

; ============================================================================
; AQ///BIMMER Color Palette (Delphi TColor = BGR format)
; ============================================================================
; Primary Background:  #0E1225 -> $25120E (Deep Navy)
; Card Background:     #1A2035 -> $35201A (Dark Blue-Grey)
; Accent Cyan:         #00D6C8 -> $C8D600 (Vibrant Teal)
; Success Green:       #22C55E -> $5EC522
; Text Primary:        #FFFFFF -> $FFFFFF (White)
; Text Secondary:      #B0B0B0 -> $B0B0B0 (Light Grey)
; Border Color:        #2A3045 -> $45302A
; ============================================================================

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
WizardSizePercent=120,100
WizardImageFile=wizard_image.bmp
WizardSmallImageFile=wizard_small.bmp
SetupLogging=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.WelcomeLabel2=This will install [name/ver] on your computer.%n%nAQ///BIMMER - BMW Professional Diagnostic Tool%n%n%nFeatures:%n  • BMW Coding & Customization%n  • Welcome Light Configuration%n  • MGU Unlock Tools%n  • CC-ID Messages Reference%n  • ZGW Search%n  • Professional Diagnostic Suite%n%n%nClick Next to continue.
english.InstallingLabel=Installing AQ CheatsTool - Please wait...
english.FinishedLabel=AQ CheatsTool has been successfully installed on your computer.%n%nThank you for choosing AQ///BIMMER!
english.AppTitle=AQ CheatsTool Setup

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Protected build with encrypted assets (bin.aqx)
Source: "protected_build\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Images folder (non-sensitive UI assets)
Source: "..\assets\images\*"; DestDir: "{app}\data\flutter_assets\assets\images"; Flags: ignoreversion recursesubdirs createallsubdirs
; Hero images
Source: "..\assets\hero_images\*"; DestDir: "{app}\data\flutter_assets\assets\hero_images"; Flags: ignoreversion recursesubdirs createallsubdirs
; Clock images
Source: "..\assets\clock_images\*"; DestDir: "{app}\data\flutter_assets\assets\clock_images"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
; Directories with restricted permissions
Name: "{app}\logs"; Permissions: admins-full users-readexec
Name: "{app}\temp"; Permissions: admins-full users-readexec
Name: "{app}\config"; Permissions: admins-full users-readexec
Name: "{app}\data"; Permissions: admins-full users-readexec

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
// ============================================================================
// AQ///BIMMER Brand Colors - Cyberpunk/Automotive Theme
// TColor format is BGR (not RGB!)
// ============================================================================
const
  // Primary Colors
  AQ_BG_PRIMARY = $25120E;      // #0E1225 - Deep Navy Background
  AQ_BG_CARD = $35201A;         // #1A2035 - Card/Panel Background
  AQ_BG_SURFACE = $45302A;      // #2A3045 - Surface/Border Color
  
  // Accent Colors
  AQ_ACCENT_CYAN = $C8D600;     // #00D6C8 - Vibrant Cyan/Teal (Primary Accent)
  AQ_ACCENT_BLUE = $F6823B;     // #3B82F6 - Blue accent
  AQ_SUCCESS = $5EC522;         // #22C55E - Success Green
  AQ_WARNING = $16F9F9;         // #F9F916 - Warning Yellow  
  AQ_ERROR = $4444EF;           // #EF4444 - Error Red
  
  // Text Colors
  AQ_TEXT_WHITE = $FFFFFF;      // #FFFFFF - Primary text (White)
  AQ_TEXT_LIGHT = $E0E0E0;      // #E0E0E0 - Light text
  AQ_TEXT_SECONDARY = $B0B0B0;  // #B0B0B0 - Secondary text (Grey)
  AQ_TEXT_MUTED = $808080;      // #808080 - Muted text

var
  // Custom UI elements
  LogoLabel_AQ: TNewStaticText;
  LogoLabel_Slash: TNewStaticText;
  LogoLabel_Bimmer: TNewStaticText;
  FooterLabel: TNewStaticText;

// ============================================================================
// Custom styling procedure - applies AQ///BIMMER theme to all wizard elements
// ============================================================================
procedure InitializeWizard();
var
  LogoTop: Integer;
begin
  // ==========================================
  // Main Form Background
  // ==========================================
  WizardForm.Color := AQ_BG_PRIMARY;
  
  // ==========================================
  // Main Panel (Top header area)
  // ==========================================
  WizardForm.MainPanel.Color := AQ_BG_CARD;
  
  // ==========================================
  // Inner Page (Content area)
  // ==========================================
  WizardForm.InnerPage.Color := AQ_BG_PRIMARY;
  
  // ==========================================
  // Page Title & Description
  // ==========================================
  WizardForm.PageNameLabel.Font.Color := AQ_TEXT_WHITE;
  WizardForm.PageNameLabel.Font.Size := 14;
  WizardForm.PageNameLabel.Font.Style := [fsBold];
  WizardForm.PageNameLabel.Font.Name := 'Segoe UI';
  
  WizardForm.PageDescriptionLabel.Font.Color := AQ_ACCENT_CYAN;
  WizardForm.PageDescriptionLabel.Font.Size := 9;
  WizardForm.PageDescriptionLabel.Font.Name := 'Segoe UI';
  
  // ==========================================
  // Welcome Page Labels
  // ==========================================
  WizardForm.WelcomeLabel1.Font.Color := AQ_TEXT_WHITE;
  WizardForm.WelcomeLabel1.Font.Size := 18;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  WizardForm.WelcomeLabel1.Font.Name := 'Segoe UI';
  
  WizardForm.WelcomeLabel2.Font.Color := AQ_TEXT_LIGHT;
  WizardForm.WelcomeLabel2.Font.Size := 10;
  WizardForm.WelcomeLabel2.Font.Name := 'Segoe UI';

  // ==========================================
  // Finished Page Labels
  // ==========================================
  WizardForm.FinishedHeadingLabel.Font.Color := AQ_SUCCESS;
  WizardForm.FinishedHeadingLabel.Font.Size := 18;
  WizardForm.FinishedHeadingLabel.Font.Style := [fsBold];
  WizardForm.FinishedHeadingLabel.Font.Name := 'Segoe UI';
  
  WizardForm.FinishedLabel.Font.Color := AQ_TEXT_LIGHT;
  WizardForm.FinishedLabel.Font.Size := 10;
  WizardForm.FinishedLabel.Font.Name := 'Segoe UI';

  // ==========================================
  // License Page - CRITICAL FIX: White text on dark background
  // ==========================================
  WizardForm.LicenseLabel1.Font.Color := AQ_TEXT_WHITE;
  WizardForm.LicenseLabel1.Font.Size := 10;
  WizardForm.LicenseLabel1.Font.Name := 'Segoe UI';
  
  // License memo box - dark background with WHITE text (fixes readability!)
  WizardForm.LicenseMemo.Color := AQ_BG_CARD;
  WizardForm.LicenseMemo.Font.Color := AQ_TEXT_WHITE;
  WizardForm.LicenseMemo.Font.Size := 9;
  WizardForm.LicenseMemo.Font.Name := 'Consolas';
  
  // Radio buttons - CRITICAL FIX: Make visible with white text
  WizardForm.LicenseAcceptedRadio.Font.Color := AQ_TEXT_WHITE;
  WizardForm.LicenseAcceptedRadio.Font.Size := 10;
  WizardForm.LicenseAcceptedRadio.Font.Name := 'Segoe UI';
  
  WizardForm.LicenseNotAcceptedRadio.Font.Color := AQ_TEXT_WHITE;
  WizardForm.LicenseNotAcceptedRadio.Font.Size := 10;
  WizardForm.LicenseNotAcceptedRadio.Font.Name := 'Segoe UI';

  // ==========================================
  // Info Before Page (readme.txt)
  // ==========================================
  WizardForm.InfoBeforeClickLabel.Font.Color := AQ_TEXT_WHITE;
  WizardForm.InfoBeforeClickLabel.Font.Size := 10;
  
  WizardForm.InfoBeforeMemo.Color := AQ_BG_CARD;
  WizardForm.InfoBeforeMemo.Font.Color := AQ_TEXT_WHITE;
  WizardForm.InfoBeforeMemo.Font.Size := 9;
  WizardForm.InfoBeforeMemo.Font.Name := 'Consolas';

  // ==========================================
  // Select Directory Page
  // ==========================================
  WizardForm.SelectDirLabel.Font.Color := AQ_TEXT_WHITE;
  WizardForm.SelectDirLabel.Font.Size := 10;
  
  WizardForm.SelectDirBrowseLabel.Font.Color := AQ_TEXT_SECONDARY;
  WizardForm.SelectDirBrowseLabel.Font.Size := 9;
  
  WizardForm.DirEdit.Color := AQ_BG_CARD;
  WizardForm.DirEdit.Font.Color := AQ_TEXT_WHITE;
  WizardForm.DirEdit.Font.Size := 10;

  // ==========================================
  // Components/Tasks Pages
  // ==========================================
  WizardForm.ComponentsList.Color := AQ_BG_CARD;
  WizardForm.ComponentsList.Font.Color := AQ_TEXT_WHITE;
  WizardForm.ComponentsList.Font.Size := 10;
  
  WizardForm.TasksList.Color := AQ_BG_CARD;
  WizardForm.TasksList.Font.Color := AQ_TEXT_WHITE;
  WizardForm.TasksList.Font.Size := 10;

  // ==========================================
  // Ready Page
  // ==========================================
  WizardForm.ReadyMemo.Color := AQ_BG_CARD;
  WizardForm.ReadyMemo.Font.Color := AQ_TEXT_WHITE;
  WizardForm.ReadyMemo.Font.Size := 9;
  WizardForm.ReadyMemo.Font.Name := 'Consolas';

  // ==========================================
  // Installing Page - Progress indicators
  // ==========================================
  WizardForm.StatusLabel.Font.Color := AQ_ACCENT_CYAN;
  WizardForm.StatusLabel.Font.Size := 10;
  WizardForm.StatusLabel.Font.Style := [fsBold];
  WizardForm.StatusLabel.Font.Name := 'Segoe UI';
  
  WizardForm.FilenameLabel.Font.Color := AQ_TEXT_SECONDARY;
  WizardForm.FilenameLabel.Font.Size := 8;
  WizardForm.FilenameLabel.Font.Name := 'Segoe UI';

  // ==========================================
  // Run List (post-install options)
  // ==========================================
  WizardForm.RunList.Color := AQ_BG_PRIMARY;
  WizardForm.RunList.Font.Color := AQ_TEXT_WHITE;
  WizardForm.RunList.Font.Size := 10;

  // ==========================================
  // Buttons - Modern flat style
  // ==========================================
  WizardForm.NextButton.Font.Color := AQ_BG_PRIMARY;
  WizardForm.NextButton.Font.Size := 10;
  WizardForm.NextButton.Font.Style := [fsBold];
  WizardForm.NextButton.Font.Name := 'Segoe UI';
  
  WizardForm.BackButton.Font.Color := AQ_TEXT_WHITE;
  WizardForm.BackButton.Font.Size := 10;
  WizardForm.BackButton.Font.Name := 'Segoe UI';
  
  WizardForm.CancelButton.Font.Color := AQ_TEXT_WHITE;
  WizardForm.CancelButton.Font.Size := 10;
  WizardForm.CancelButton.Font.Name := 'Segoe UI';

  // ==========================================
  // Hide default bevels (cleaner look)
  // ==========================================
  WizardForm.Bevel.Visible := False;
  WizardForm.Bevel1.Visible := False;

  // ==========================================
  // Custom Logo in header area - AQ///BIMMER branding
  // ==========================================
  LogoTop := 10;
  
  // AQ in Cyan
  LogoLabel_AQ := TNewStaticText.Create(WizardForm);
  LogoLabel_AQ.Parent := WizardForm.MainPanel;
  LogoLabel_AQ.Caption := 'AQ';
  LogoLabel_AQ.Font.Color := AQ_ACCENT_CYAN;
  LogoLabel_AQ.Font.Size := 16;
  LogoLabel_AQ.Font.Style := [fsBold];
  LogoLabel_AQ.Font.Name := 'Segoe UI';
  LogoLabel_AQ.Left := 12;
  LogoLabel_AQ.Top := LogoTop;
  LogoLabel_AQ.AutoSize := True;
  
  // /// in White
  LogoLabel_Slash := TNewStaticText.Create(WizardForm);
  LogoLabel_Slash.Parent := WizardForm.MainPanel;
  LogoLabel_Slash.Caption := '///';
  LogoLabel_Slash.Font.Color := AQ_TEXT_WHITE;
  LogoLabel_Slash.Font.Size := 16;
  LogoLabel_Slash.Font.Style := [fsBold];
  LogoLabel_Slash.Font.Name := 'Segoe UI';
  LogoLabel_Slash.Left := LogoLabel_AQ.Left + LogoLabel_AQ.Width;
  LogoLabel_Slash.Top := LogoTop;
  LogoLabel_Slash.AutoSize := True;
  
  // BIMMER in White
  LogoLabel_Bimmer := TNewStaticText.Create(WizardForm);
  LogoLabel_Bimmer.Parent := WizardForm.MainPanel;
  LogoLabel_Bimmer.Caption := 'BIMMER';
  LogoLabel_Bimmer.Font.Color := AQ_TEXT_WHITE;
  LogoLabel_Bimmer.Font.Size := 16;
  LogoLabel_Bimmer.Font.Style := [fsBold];
  LogoLabel_Bimmer.Font.Name := 'Segoe UI';
  LogoLabel_Bimmer.Left := LogoLabel_Slash.Left + LogoLabel_Slash.Width;
  LogoLabel_Bimmer.Top := LogoTop;
  LogoLabel_Bimmer.AutoSize := True;

  // ==========================================
  // Footer copyright
  // ==========================================
  FooterLabel := TNewStaticText.Create(WizardForm);
  FooterLabel.Parent := WizardForm;
  FooterLabel.Caption := '© 2024-2026 AQ///BIMMER - BMW Professional Diagnostic Tool';
  FooterLabel.Font.Color := AQ_TEXT_MUTED;
  FooterLabel.Font.Size := 8;
  FooterLabel.Font.Name := 'Segoe UI';
  FooterLabel.Left := 10;
  FooterLabel.Top := WizardForm.ClientHeight - 22;
  FooterLabel.AutoSize := True;
end;

// ============================================================================
// Page change handler - refresh styling on each page
// ============================================================================
procedure CurPageChanged(CurPageID: Integer);
begin
  case CurPageID of
    wpWelcome:
      begin
        WizardForm.WelcomeLabel1.Font.Color := AQ_TEXT_WHITE;
        WizardForm.WelcomeLabel2.Font.Color := AQ_TEXT_LIGHT;
      end;
    wpLicense:
      begin
        WizardForm.LicenseMemo.Font.Color := AQ_TEXT_WHITE;
        WizardForm.LicenseAcceptedRadio.Font.Color := AQ_TEXT_WHITE;
        WizardForm.LicenseNotAcceptedRadio.Font.Color := AQ_TEXT_WHITE;
      end;
    wpSelectDir:
      begin
        WizardForm.SelectDirLabel.Font.Color := AQ_TEXT_WHITE;
        WizardForm.DirEdit.Font.Color := AQ_TEXT_WHITE;
      end;
    wpReady:
      begin
        WizardForm.ReadyMemo.Font.Color := AQ_TEXT_WHITE;
      end;
    wpFinished:
      begin
        WizardForm.FinishedLabel.Font.Color := AQ_TEXT_LIGHT;
        WizardForm.FinishedHeadingLabel.Font.Color := AQ_SUCCESS;
        WizardForm.RunList.Font.Color := AQ_TEXT_WHITE;
        WizardForm.RunList.Color := AQ_BG_PRIMARY;
      end;
  end;
end;

// ============================================================================
// Installation step handler - apply security permissions
// ============================================================================
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Installing AQ CheatsTool...';
    Log('Starting installation of AQ CheatsTool...');
  end;
  
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Setting security permissions...';
    
    // Set NTFS permissions to protect application files
    Exec('icacls.exe', ExpandConstant('"{app}" /inheritance:r /grant:r Administrators:(OI)(CI)F /grant:r Users:(OI)(CI)RX'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    
    // Extra protection for encrypted assets
    if FileExists(ExpandConstant('{app}\bin.aqx')) then
    begin
      Exec('icacls.exe', ExpandConstant('"{app}\bin.aqx" /inheritance:r /grant:r Administrators:F /grant:r Users:R'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
    
    // Protect data folder
    Exec('icacls.exe', ExpandConstant('"{app}\data" /inheritance:r /grant:r Administrators:(OI)(CI)F /grant:r Users:(OI)(CI)RX'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    
    WizardForm.StatusLabel.Caption := 'Installation completed successfully!';
    WizardForm.StatusLabel.Font.Color := AQ_SUCCESS;
    Log('AQ CheatsTool installation completed. Security permissions applied.');
  end;
end;

// ============================================================================
// Uninstall cleanup
// ============================================================================
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataPath, TempPath: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Clean up extracted temp files
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

// ============================================================================
// Setup initialization
// ============================================================================
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
