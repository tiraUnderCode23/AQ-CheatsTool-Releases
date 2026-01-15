<# 
.SYNOPSIS
    Build and package AQ CheatsTool Windows Installer

.DESCRIPTION
    This script builds the Flutter application for Windows,
    creates installer images, and generates the Setup.exe using Inno Setup.

.NOTES
    Author: AQ///BIMMER
    Version: 3.2.0
    Requires: Flutter SDK, Inno Setup 6.x
#>

param(
    [switch]$SkipBuild,
    [switch]$SkipImages,
    [string]$InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$InstallerDir = $PSScriptRoot
$OutputDir = Join-Path $InstallerDir "output"
$AssetsDir = Join-Path $ProjectRoot "assets\images"

# Colors for output
function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Step($Message) {
    Write-ColorOutput "Cyan" "`n▶ $Message"
}

function Write-Success($Message) {
    Write-ColorOutput "Green" "✓ $Message"
}

function Write-Error($Message) {
    Write-ColorOutput "Red" "✗ $Message"
}

# Banner
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              AQ CheatsTool - Installer Builder               ║
║                       Version 3.2.0                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Step 1: Check prerequisites
Write-Step "Checking prerequisites..."

# Check Flutter
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Success "Flutter found: $flutterVersion"
} catch {
    Write-Error "Flutter not found. Please install Flutter SDK."
    exit 1
}

# Check Inno Setup
if (Test-Path $InnoSetupPath) {
    Write-Success "Inno Setup found at: $InnoSetupPath"
} else {
    # Try alternative paths
    $altPaths = @(
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    
    $found = $false
    foreach ($path in $altPaths) {
        if (Test-Path $path) {
            $InnoSetupPath = $path
            $found = $true
            Write-Success "Inno Setup found at: $InnoSetupPath"
            break
        }
    }
    
    if (-not $found) {
        Write-ColorOutput "Yellow" "⚠ Inno Setup not found. Please install from: https://jrsoftware.org/isinfo.php"
        Write-ColorOutput "Yellow" "  After installation, run this script again."
        
        # Open download page
        Start-Process "https://jrsoftware.org/isdl.php"
        exit 1
    }
}

# Step 2: Create output directory
Write-Step "Creating output directory..."
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
Write-Success "Output directory ready: $OutputDir"

# Step 3: Build Flutter application
if (-not $SkipBuild) {
    Write-Step "Building Flutter application for Windows..."
    
    Push-Location $ProjectRoot
    try {
        # Clean and get dependencies
        Write-Host "  Cleaning previous build..." -ForegroundColor Gray
        flutter clean | Out-Null
        
        Write-Host "  Getting dependencies..." -ForegroundColor Gray
        flutter pub get
        
        Write-Host "  Building release version..." -ForegroundColor Gray
        # Load tokens from environment or config file
        $githubToken = $env:GITHUB_TOKEN
        if ($githubToken) {
            flutter build windows --release --dart-define="GITHUB_TOKEN=$githubToken"
        } else {
            Write-Warning "GITHUB_TOKEN not set in environment. Building without token."
            flutter build windows --release
        }
        
        Write-Success "Flutter build completed successfully!"
    } catch {
        Write-Error "Flutter build failed: $_"
        Pop-Location
        exit 1
    }
    Pop-Location
} else {
    Write-ColorOutput "Yellow" "⚠ Skipping Flutter build (--SkipBuild flag)"
}

# Step 4: Create installer images (if not exist)
if (-not $SkipImages) {
    Write-Step "Checking installer images..."
    
    $wizardImage = Join-Path $InstallerDir "wizard_image.bmp"
    $wizardSmallImage = Join-Path $InstallerDir "wizard_small.bmp"
    
    if (-not (Test-Path $wizardImage) -or -not (Test-Path $wizardSmallImage)) {
        Write-ColorOutput "Yellow" "⚠ Installer images not found. Creating placeholder images..."
        
        # Create a simple PowerShell script to generate BMP images
        # For now, we'll create a note about this
        $imageNote = @"
INSTALLER IMAGES NEEDED
=======================

For the best visual experience, please create these BMP images:

1. wizard_image.bmp (164 x 314 pixels)
   - Left side banner image shown during installation
   - Use dark theme matching the app (black/cyan colors)
   - Include AQ///BIMMER logo and BMW styling

2. wizard_small.bmp (55 x 55 pixels)
   - Small icon shown in top-right corner
   - Use the app icon or AQ logo

You can use any image editor to create these files.
Save them as 24-bit BMP format in the installer folder.

For now, the installer will work without custom images.
"@
        $imageNote | Out-File (Join-Path $InstallerDir "CREATE_IMAGES.txt") -Encoding UTF8
        Write-ColorOutput "Yellow" "  See CREATE_IMAGES.txt for instructions"
    } else {
        Write-Success "Installer images found"
    }
}

# Step 5: Verify build output exists
Write-Step "Verifying build output..."
$buildOutput = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
if (Test-Path $buildOutput) {
    $exeFile = Join-Path $buildOutput "aq_cheats_tool.exe"
    if (Test-Path $exeFile) {
        $fileInfo = Get-Item $exeFile
        Write-Success "Build output found: $($fileInfo.Length / 1MB) MB"
    } else {
        Write-Error "Executable not found in build output!"
        exit 1
    }
} else {
    Write-Error "Build output directory not found: $buildOutput"
    exit 1
}

# Step 6: Run Inno Setup compiler
Write-Step "Compiling installer with Inno Setup..."

$issFile = Join-Path $InstallerDir "AQCheatsTool_Setup.iss"
if (-not (Test-Path $issFile)) {
    Write-Error "Inno Setup script not found: $issFile"
    exit 1
}

try {
    $process = Start-Process -FilePath $InnoSetupPath -ArgumentList "`"$issFile`"" -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Success "Installer compiled successfully!"
    } else {
        Write-Error "Inno Setup failed with exit code: $($process.ExitCode)"
        exit 1
    }
} catch {
    Write-Error "Failed to run Inno Setup: $_"
    exit 1
}

# Step 7: Verify output
Write-Step "Verifying installer output..."
$setupFile = Get-ChildItem -Path $OutputDir -Filter "AQCheatsTool_Setup_*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($setupFile) {
    $sizeMB = [math]::Round($setupFile.Length / 1MB, 2)
    Write-Success "Installer created: $($setupFile.Name) ($sizeMB MB)"
    
    # Calculate hash for verification
    $hash = Get-FileHash -Path $setupFile.FullName -Algorithm SHA256
    Write-Host "  SHA256: $($hash.Hash)" -ForegroundColor Gray
    
    # Save hash to file
    "$($setupFile.Name)`nSHA256: $($hash.Hash)`nCreated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | 
        Out-File (Join-Path $OutputDir "$($setupFile.BaseName).sha256.txt") -Encoding UTF8
} else {
    Write-Error "Installer file not found in output directory!"
    exit 1
}

# Done!
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    BUILD COMPLETED!                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "Installer location: $($setupFile.FullName)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the installer on a clean Windows machine"
Write-Host "  2. Verify all features work correctly"
Write-Host "  3. Upload to distribution server"
Write-Host ""

# Open output folder
explorer.exe $OutputDir
