# AQ CheatsTool - Professional Wizard Image Generator
# Creates wizard images with AQ Brand Identity

Add-Type -AssemblyName System.Drawing

# AQ Brand Colors (from app_theme.dart)
$darkBg = [System.Drawing.Color]::FromArgb(26, 26, 46)        # #1a1a2e
$cardBg = [System.Drawing.Color]::FromArgb(22, 33, 62)        # #16213e  
$surface = [System.Drawing.Color]::FromArgb(15, 52, 96)       # #0f3460
$primaryBlue = [System.Drawing.Color]::FromArgb(59, 130, 246) # #3b82f6
$accentCyan = [System.Drawing.Color]::FromArgb(0, 255, 208)   # #00ffd0
$successGreen = [System.Drawing.Color]::FromArgb(34, 197, 94) # #22c55e
$textWhite = [System.Drawing.Color]::White

$installerDir = "D:\Flutter apps\flutter_app\installer"
$iconPath = "D:\Flutter apps\flutter_app\windows\runner\resources\app_icon.ico"

Write-Host "Creating AQ CheatsTool Wizard Images..." -ForegroundColor Cyan

# ====== WIZARD IMAGE (164x314) ======
$width = 164
$height = 314
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Create gradient background
$gradientRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
$gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $gradientRect,
    $darkBg,
    $cardBg,
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
$graphics.FillRectangle($gradientBrush, $gradientRect)

# Add accent line at top
$accentBrush = New-Object System.Drawing.SolidBrush($accentCyan)
$graphics.FillRectangle($accentBrush, 0, 0, $width, 3)

# Try to load and draw the app icon
try {
    if (Test-Path $iconPath) {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
        $iconBitmap = $icon.ToBitmap()
        
        # Scale icon to 64x64 and center it
        $iconSize = 64
        $iconX = ($width - $iconSize) / 2
        $iconY = 60
        $graphics.DrawImage($iconBitmap, $iconX, $iconY, $iconSize, $iconSize)
        $iconBitmap.Dispose()
        $icon.Dispose()
        Write-Host "  Icon loaded successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not load icon, drawing placeholder" -ForegroundColor Yellow
    # Draw placeholder circle
    $circleBrush = New-Object System.Drawing.SolidBrush($primaryBlue)
    $graphics.FillEllipse($circleBrush, 50, 60, 64, 64)
}

# Draw brand text
$titleFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$subtitleFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$footerFont = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Regular)

$whiteBrush = New-Object System.Drawing.SolidBrush($textWhite)
$cyanBrush = New-Object System.Drawing.SolidBrush($accentCyan)

# App name
$titleFormat = New-Object System.Drawing.StringFormat
$titleFormat.Alignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString("AQ", $titleFont, $cyanBrush, ($width/2), 140, $titleFormat)
$graphics.DrawString("CheatsTool", $titleFont, $whiteBrush, ($width/2), 160, $titleFormat)

# Subtitle
$graphics.DrawString("BMW Professional", $subtitleFont, $whiteBrush, ($width/2), 190, $titleFormat)
$graphics.DrawString("Diagnostic Tool", $subtitleFont, $whiteBrush, ($width/2), 205, $titleFormat)

# Draw decorative elements
$pen = New-Object System.Drawing.Pen($accentCyan, 1)
$graphics.DrawLine($pen, 30, 235, ($width - 30), 235)

# Features list
$featureFont = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Regular)
$graphics.DrawString("BMW Coding", $featureFont, $whiteBrush, ($width/2), 245, $titleFormat)
$graphics.DrawString("Welcome Light", $featureFont, $whiteBrush, ($width/2), 258, $titleFormat)
$graphics.DrawString("MGU Unlock", $featureFont, $whiteBrush, ($width/2), 271, $titleFormat)

# Footer
$graphics.DrawString("v2.0.0", $footerFont, $cyanBrush, ($width/2), ($height - 20), $titleFormat)

# Bottom accent line
$graphics.FillRectangle($accentBrush, 0, ($height - 3), $width, 3)

# Save wizard image
$wizardPath = Join-Path $installerDir "wizard_image.bmp"
$bitmap.Save($wizardPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
Write-Host "Created: $wizardPath" -ForegroundColor Green

# Cleanup
$graphics.Dispose()
$bitmap.Dispose()
$gradientBrush.Dispose()
$accentBrush.Dispose()
$titleFont.Dispose()
$subtitleFont.Dispose()
$footerFont.Dispose()
$featureFont.Dispose()
$whiteBrush.Dispose()
$cyanBrush.Dispose()
$pen.Dispose()

# ====== WIZARD SMALL IMAGE (55x55) ======
$smallWidth = 55
$smallHeight = 55
$smallBitmap = New-Object System.Drawing.Bitmap($smallWidth, $smallHeight)
$smallGraphics = [System.Drawing.Graphics]::FromImage($smallBitmap)
$smallGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Background
$smallGradientRect = New-Object System.Drawing.Rectangle(0, 0, $smallWidth, $smallHeight)
$smallGradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $smallGradientRect,
    $darkBg,
    $cardBg,
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
)
$smallGraphics.FillRectangle($smallGradientBrush, $smallGradientRect)

# Try to draw icon
try {
    if (Test-Path $iconPath) {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
        $iconBitmap = $icon.ToBitmap()
        
        # Scale icon to fit
        $iconSize = 40
        $iconX = ($smallWidth - $iconSize) / 2
        $iconY = ($smallHeight - $iconSize) / 2
        $smallGraphics.DrawImage($iconBitmap, $iconX, $iconY, $iconSize, $iconSize)
        $iconBitmap.Dispose()
        $icon.Dispose()
    }
} catch {
    # Draw placeholder
    $circleBrush = New-Object System.Drawing.SolidBrush($primaryBlue)
    $smallGraphics.FillEllipse($circleBrush, 7, 7, 40, 40)
    $circleBrush.Dispose()
}

# Border
$borderPen = New-Object System.Drawing.Pen($accentCyan, 2)
$smallGraphics.DrawRectangle($borderPen, 1, 1, ($smallWidth - 3), ($smallHeight - 3))

# Save small image
$smallPath = Join-Path $installerDir "wizard_small.bmp"
$smallBitmap.Save($smallPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
Write-Host "Created: $smallPath" -ForegroundColor Green

# Cleanup
$smallGraphics.Dispose()
$smallBitmap.Dispose()
$smallGradientBrush.Dispose()
$borderPen.Dispose()

Write-Host ""
Write-Host "All wizard images created successfully!" -ForegroundColor Green
Write-Host "Ready to build installer." -ForegroundColor Cyan
