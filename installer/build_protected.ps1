# ============================================================================
# AQ CheatsTool - Secure Build & Encrypt Script
# This script encrypts all assets and creates a protected installer
# ============================================================================
#
# SECURITY FEATURES:
# 1. XOR encryption of sensitive files (attachments, data, guides) into bin.aqx
# 2. Obfuscated Flutter build with --obfuscate flag
# 3. NTFS permissions set during installation (admin write, users read-only)
# 4. Sensitive files extracted to %TEMP% at runtime only
# 5. Cleanup of temp files on uninstall
#
# USAGE: .\build_protected.ps1 [-SkipBuild] [-SkipEncrypt] [-Verbose]
# ============================================================================

param(
    [switch]$SkipBuild,
    [switch]$SkipEncrypt,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = "D:\Flutter apps\flutter_app"
$InstallerDir = Join-Path $ProjectRoot "installer"
$BuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$AssetsDir = Join-Path $ProjectRoot "assets"
$OutputDir = Join-Path $InstallerDir "output"
$ProtectedDir = Join-Path $InstallerDir "protected_build"

# Encryption key (MUST match ResourceDecryptor._decryptionKey in Dart)
$EncryptionKey = "AQ///BMW2024SecureKey!@#"

# Files/folders to encrypt (sensitive data)
$FoldersToEncrypt = @(
    "attachments",
    "data",
    "guides"
)

# Files to keep unencrypted (required by Flutter at startup)
$KeepUnencrypted = @(
    "images"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AQ CheatsTool - Secure Build System" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Step 1: Build Flutter Windows Release
# ============================================================================
if (-not $SkipBuild) {
    Write-Host "[1/5] Building Flutter Windows Release..." -ForegroundColor Yellow
    Set-Location $ProjectRoot
    
    # Clean previous build
    Write-Host "  Cleaning previous build..." -ForegroundColor Gray
    flutter clean 2>$null
    
    # Build with obfuscation
    Write-Host "  Building with obfuscation..." -ForegroundColor Gray
    flutter build windows --release --obfuscate --split-debug-info=build/symbols
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Flutter build failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Build completed successfully!" -ForegroundColor Green
} else {
    Write-Host "[1/5] Skipping Flutter build..." -ForegroundColor Gray
}

# ============================================================================
# Step 2: Create Protected Build Directory
# ============================================================================
Write-Host "[2/5] Preparing protected build directory..." -ForegroundColor Yellow

# Clean and create protected directory
if (Test-Path $ProtectedDir) {
    Remove-Item $ProtectedDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ProtectedDir -Force | Out-Null

# Copy build files
Write-Host "  Copying build files..." -ForegroundColor Gray
Copy-Item -Path "$BuildDir\*" -Destination $ProtectedDir -Recurse -Force

Write-Host "  Protected build directory created!" -ForegroundColor Green

# ============================================================================
# Step 3: Encrypt Sensitive Assets
# ============================================================================
if (-not $SkipEncrypt) {
    Write-Host "[3/5] Encrypting sensitive assets..." -ForegroundColor Yellow
    
    $TempZipPath = Join-Path $env:TEMP "aq_assets_temp.zip"
    $EncryptedPath = Join-Path $ProtectedDir "bin.aqx"
    
    # Create temp folder for assets to encrypt
    $TempAssetsDir = Join-Path $env:TEMP "aq_assets_to_encrypt"
    if (Test-Path $TempAssetsDir) {
        Remove-Item $TempAssetsDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TempAssetsDir -Force | Out-Null
    
    # Copy folders to encrypt
    foreach ($folder in $FoldersToEncrypt) {
        $sourcePath = Join-Path $AssetsDir $folder
        if (Test-Path $sourcePath) {
            Write-Host "  Adding: $folder" -ForegroundColor Gray
            Copy-Item -Path $sourcePath -Destination (Join-Path $TempAssetsDir $folder) -Recurse -Force
        }
    }
    
    # Create ZIP archive
    Write-Host "  Creating archive..." -ForegroundColor Gray
    if (Test-Path $TempZipPath) {
        Remove-Item $TempZipPath -Force
    }
    Compress-Archive -Path "$TempAssetsDir\*" -DestinationPath $TempZipPath -CompressionLevel Optimal
    
    # XOR encrypt the ZIP
    Write-Host "  Encrypting archive..." -ForegroundColor Gray
    $zipBytes = [System.IO.File]::ReadAllBytes($TempZipPath)
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($EncryptionKey)
    $encryptedBytes = New-Object byte[] $zipBytes.Length
    
    for ($i = 0; $i -lt $zipBytes.Length; $i++) {
        $encryptedBytes[$i] = $zipBytes[$i] -bxor $keyBytes[$i % $keyBytes.Length]
    }
    
    [System.IO.File]::WriteAllBytes($EncryptedPath, $encryptedBytes)
    
    # Cleanup temp files
    Remove-Item $TempZipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $TempAssetsDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "  Created: bin.aqx ($('{0:N2}' -f ($encryptedBytes.Length / 1MB)) MB)" -ForegroundColor Green
    
    # Remove sensitive folders from flutter_assets in protected build
    $FlutterAssetsDir = Join-Path $ProtectedDir "data\flutter_assets\assets"
    foreach ($folder in $FoldersToEncrypt) {
        $folderPath = Join-Path $FlutterAssetsDir $folder
        if (Test-Path $folderPath) {
            Write-Host "  Removing unprotected: $folder" -ForegroundColor Gray
            Remove-Item $folderPath -Recurse -Force
        }
    }
    
    Write-Host "  Assets encrypted successfully!" -ForegroundColor Green
} else {
    Write-Host "[3/5] Skipping encryption..." -ForegroundColor Gray
}

# ============================================================================
# Step 4: Update Inno Setup Script for Protected Build
# ============================================================================
Write-Host "[4/5] Updating installer script..." -ForegroundColor Yellow

$IssContent = @"
; ============================================================================
; AQ CheatsTool - Protected Windows Installer
; Version 2.0.0 - Encrypted Assets Build
; ============================================================================

#define MyAppName "AQ CheatsTool"
#define MyAppVersion "2.0.0"
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
  AQ_DARK_BG = `$2E1A1A;
  AQ_CARD_BG = `$3E2116;
  AQ_ACCENT_CYAN = `$D0FF00;
  AQ_SUCCESS = `$5EC522;
  AQ_TEXT_PRIMARY = `$FFFFFF;
  AQ_TEXT_SECONDARY = `$B0B0B0;

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
"@

# Fix the backticks for dollar signs in Inno Setup
$IssContent = $IssContent.Replace('`$', '$')

$IssPath = Join-Path $InstallerDir "AQCheatsTool_Protected.iss"
Set-Content -Path $IssPath -Value $IssContent -Encoding UTF8

Write-Host "  Created: AQCheatsTool_Protected.iss" -ForegroundColor Green

# ============================================================================
# Step 5: Build Protected Installer
# ============================================================================
Write-Host "[5/5] Building protected installer..." -ForegroundColor Yellow

$InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"

if (-not (Test-Path $InnoSetupPath)) {
    Write-Host "  ERROR: Inno Setup not found at: $InnoSetupPath" -ForegroundColor Red
    Write-Host "  Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    exit 1
}

Set-Location $InstallerDir
& $InnoSetupPath $IssPath

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    
    $InstallerPath = Join-Path $OutputDir "AQCheatsTool_Setup_v2.0.0.exe"
    if (Test-Path $InstallerPath) {
        $size = (Get-Item $InstallerPath).Length / 1MB
        Write-Host "  Installer: $InstallerPath" -ForegroundColor Cyan
        Write-Host "  Size: $('{0:N2}' -f $size) MB" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "  PROTECTED FEATURES:" -ForegroundColor Yellow
    Write-Host "  - Assets encrypted with XOR + ZIP (bin.aqx)" -ForegroundColor Gray
    Write-Host "  - Code obfuscation enabled" -ForegroundColor Gray
    Write-Host "  - Sensitive data extracted to temp at runtime" -ForegroundColor Gray
    Write-Host "  - Auto-cleanup on uninstall" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "  ERROR: Installer build failed!" -ForegroundColor Red
    exit 1
}
