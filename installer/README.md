# AQ CheatsTool Installer Builder

هذا المجلد يحتوي على جميع الملفات اللازمة لإنشاء ملف تثبيت Windows احترافي ومحمي.

## 🔒 نظام الحماية

### مستويات الحماية:
1. **تشفير XOR** - جميع الملفات الحساسة (attachments, data, guides) مشفرة في `bin.aqx`
2. **Flutter Obfuscation** - الكود مشوش باستخدام `--obfuscate`
3. **NTFS Permissions** - صلاحيات Windows تمنع التعديل غير المصرح
4. **Runtime Extraction** - الملفات تُستخرج إلى `%TEMP%` فقط عند التشغيل
5. **Cleanup on Uninstall** - حذف الملفات المؤقتة عند إلغاء التثبيت

### الملفات المحمية:
- `assets/attachments/*` - أدوات SSH, PuTTY, MGU files
- `assets/data/*` - ملفات JSON, XML التكوين
- `assets/guides/*` - أدلة HTML

### الملفات غير المشفرة (للواجهة):
- `assets/images/*` - صور UI
- `assets/hero_images/*` - صور البطل
- `assets/clock_images/*` - صور الساعات

## المتطلبات

1. **Flutter SDK** - مثبت ومضاف إلى PATH
2. **Inno Setup 6** - قم بتحميله من: https://jrsoftware.org/isdl.php
3. **PowerShell 5.1+** - متوفر في Windows 10/11

## 🚀 البناء المحمي (موصى به)

```powershell
# من مجلد installer - يقوم بالتشفير والبناء معاً:
.\build_protected.ps1
```

هذا السكربت يقوم بـ:
1. بناء Flutter مع obfuscation
2. تشفير الملفات الحساسة إلى `bin.aqx`
3. إزالة الملفات غير المشفرة من البناء
4. إنشاء ملف التثبيت المحمي

## البناء السريع (للتطوير فقط)

> ⚠️ **تحذير:** لا تستخدم هذا للإصدار العام!

### الطريقة 1: استخدام ملف BAT
```batch
# انقر مرتين على الملف:
BUILD.bat
```

### الطريقة 2: استخدام PowerShell
```powershell
# من مجلد installer:
.\build_installer.ps1
```

## الملفات

| الملف | الوصف |
|-------|-------|
| `AQCheatsTool_Setup.iss` | سكربت Inno Setup (يستخدم protected_build) |
| `AQCheatsTool_Protected.iss` | سكربت النسخة المحمية |
| `build_protected.ps1` | ⭐ سكربت البناء المحمي (موصى به) |
| `build_installer.ps1` | سكربت البناء العادي |
| `protected_build/` | مجلد البناء المحمي مع `bin.aqx` |
| `create_images.ps1` | إنشاء صور المثبت تلقائياً |
| `BUILD.bat` | ملف batch للبناء السريع |
| `license.txt` | اتفاقية الترخيص |
| `readme.txt` | معلومات ما قبل التثبيت |
| `wizard_image.bmp` | صورة المعالج الجانبية (164×314) |
| `wizard_small.bmp` | أيقونة صغيرة (55×55) |

## خطوات البناء يدوياً

1. **بناء تطبيق Flutter:**
   ```powershell
   cd "D:\Flutter apps\flutter_app"
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

2. **إنشاء صور المثبت:**
   ```powershell
   cd installer
   .\create_images.ps1
   ```

3. **تشغيل Inno Setup:**
   - افتح `AQCheatsTool_Setup.iss` في Inno Setup
   - اضغط Ctrl+F9 للبناء
   - أو من سطر الأوامر:
   ```powershell
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "AQCheatsTool_Setup.iss"
   ```

## المخرجات

بعد البناء الناجح، ستجد:
- `output\AQCheatsTool_Setup_v2.0.0.exe` - ملف التثبيت
- `output\AQCheatsTool_Setup_v2.0.0.sha256.txt` - ملف التحقق

## تخصيص الصور

لإنشاء صور مخصصة:

### wizard_image.bmp (164×314 pixels)
- الصورة الجانبية الظاهرة أثناء التثبيت
- استخدم الثيم الداكن مع ألوان التطبيق
- أضف شعار AQ///BIMMER

### wizard_small.bmp (55×55 pixels)
- الأيقونة الصغيرة في أعلى اليمين
- استخدم شعار AQ أو أيقونة التطبيق

**ملاحظة:** احفظ كـ 24-bit BMP

## استكشاف الأخطاء

### خطأ "Inno Setup not found"
تأكد من تثبيت Inno Setup وإضافته للمسار أو عدّل متغير `$InnoSetupPath` في السكربت.

### خطأ "Flutter build failed"
```powershell
flutter doctor
flutter clean
flutter pub get
```

### خطأ في الصلاحيات
شغّل PowerShell كمسؤول:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## الدعم

- WhatsApp: +972528180757
- Telegram: @aqbimmer
- Website: https://aqbimmer.com

---
Copyright © 2024-2026 AQ///BIMMER
