# 📋 AQ///BIMMER - توثيق نظام إدارة المستخدمين
## User Registration, Activation & Management System Documentation

> **الإصدار:** Flutter Windows Desktop Application
> **التاريخ:** December 2024
> **للاستخدام:** تدريب برنامج الإدارة على التحديثات الجديدة

---

## 📁 هيكل الملفات والمجلدات

```
flutter_app/
├── lib/
│   ├── core/
│   │   └── providers/
│   │       └── activation_provider.dart      # المزود الرئيسي للتفعيل
│   └── features/
│       ├── activation/
│       │   └── activation_screen.dart        # شاشة التسجيل والتفعيل
│       └── user_management/
│           └── user_management_tab.dart      # تبويب إدارة المستخدمين
```

---

## 🔧 إعدادات GitHub

### التوكنات والمستودع
```dart
// GitHub Configuration
static const List<String> _githubTokens = [
    // Tokens are loaded from secure storage or environment variables
    String.fromEnvironment('GITHUB_TOKEN', defaultValue: ''),
];

static const String _repoOwner = 'tiraUnderCode23';
static const String _repoName = 'AQ';
static const String _githubBranch = 'main';
static const String _usersFile = 'users.json';
```

### ملفات البيانات على GitHub
| الملف | الوصف |
|-------|-------|
| `users.json` | قائمة المستخدمين المسجلين والنشطين |
| `applications.json` | طلبات التسجيل المعلقة (pending) |
| `activations/{email}_activation.dat` | ملفات التفعيل لكل مستخدم |

---

## 👤 هيكل بيانات المستخدم

### User Object in `users.json`
```json
{
    "id": "1702345678901",
    "name": "اسم المستخدم",
    "email": "user@example.com",
    "phone": "+972528180757",
    "password": "sha256_hashed_password",
    "hwid": "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6",
    "registration_date": "2024-12-06T12:00:00.000Z",
    "last_active": "2024-12-06T14:30:00.000Z",
    "last_login": "2024-12-06T14:30:00.000Z",
    "activations": 1,
    "status": "active",
    "platform": "windows"
}
```

### Application Object in `applications.json` (طلبات معلقة)
```json
{
    "id": "1702345678901",
    "name": "اسم المستخدم الجديد",
    "email": "newuser@example.com",
    "phone": "+972528180757",
    "password": "sha256_hashed_password",
    "hwid": "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6",
    "registration_time": "2024-12-06T12:00:00.000Z",
    "status": "pending",
    "platform": "windows"
}
```

### Activation File (`activations/{email}_activation.dat`)
```
XXXXX-XXXXXXXX-XXXXX
```
- صيغة الملف: نص عادي يحتوي على كود التفعيل فقط
- اسم الملف: `{email.replaceAll('@', '_at_').replaceAll('.', '_dot_')}_activation.dat`
- مثال: `user_at_example_dot_com_activation.dat`

---

## 🔄 سير عمل التسجيل (Registration Flow)

### 1. التسجيل الجديد
```
[المستخدم] → [شاشة التسجيل] → [إدخال البيانات] → [إرسال للسيرفر]
                                    ↓
                    [applications.json] ← [إضافة طلب جديد]
                                    ↓
                        [حالة: pending]
```

### 2. خطوات التسجيل في الكود
```dart
Future<bool> registerUser({
  required String name,
  required String email,
  required String phone,
  required String password,
}) async {
  // 1. التحقق من عدم وجود الإيميل مسبقاً
  // 2. الحصول على applications.json
  // 3. تشفير كلمة المرور (SHA256)
  // 4. إنشاء كائن التسجيل الجديد
  // 5. إضافة الطلب إلى applications.json
  // 6. رفع التحديث إلى GitHub
}
```

### 3. البيانات المطلوبة للتسجيل
| الحقل | النوع | مطلوب | الوصف |
|-------|-------|-------|-------|
| `name` | String | ✅ | اسم المستخدم الكامل |
| `email` | String | ✅ | البريد الإلكتروني (فريد) |
| `phone` | String | ✅ | رقم الهاتف |
| `password` | String | ✅ | كلمة المرور (يتم تشفيرها) |
| `hwid` | String | تلقائي | معرف الجهاز الفريد |
| `platform` | String | تلقائي | نظام التشغيل |

---

## ✅ سير عمل الموافقة (Approval Flow)

### 1. عملية الموافقة من برنامج الإدارة
```
[طلب معلق في applications.json]
           ↓
[المسؤول يراجع الطلب في برنامج الإدارة]
           ↓
[الموافقة على الطلب]
           ↓
    ┌──────┴──────┐
    ↓             ↓
[نقل إلى      [إنشاء ملف
users.json]   activation.dat]
    ↓             ↓
    └──────┬──────┘
           ↓
[إرسال كود التفعيل للمستخدم]
           ↓
[حالة: active]
```

### 2. إنشاء ملف التفعيل
```dart
// إنشاء اسم الملف
String _emailToFilename(String email) {
  return email.replaceAll('@', '_at_').replaceAll('.', '_dot_');
}

String _getActivationFilePath(String email) {
  return 'activations/${_emailToFilename(email)}_activation.dat';
}

// مثال:
// email: "user@example.com"
// filepath: "activations/user_at_example_dot_com_activation.dat"
```

### 3. صيغة كود التفعيل
```dart
static String generateActivationCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  
  String part1 = List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  String part2 = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  String part3 = List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  
  return '$part1-$part2-$part3';  // مثال: ABCD5-EFGH1234-JKLM9
}
```

---

## 🔐 سير عمل التفعيل (Activation Flow)

### 1. التفعيل بالكود
```dart
Future<bool> activateWithKey(String key) async {
  // 1. جلب جميع المستخدمين من users.json و applications.json
  // 2. البحث عن مستخدم بكود تفعيل مطابق
  // 3. التحقق من HWID
  // 4. تحديث HWID إذا كان فارغاً
  // 5. حفظ التفعيل محلياً
}
```

### 2. التفعيل عبر البريد وكلمة المرور
```dart
Future<bool> login(String email, String password) async {
  // 1. جلب المستخدمين من GitHub
  // 2. البحث عن المستخدم بالإيميل
  // 3. التحقق من كلمة المرور (SHA256)
  // 4. التحقق من وجود ملف التفعيل
  // 5. التحقق من HWID
  // 6. حفظ التفعيل
}
```

### 3. التحقق التلقائي من التفعيل
```dart
Future<bool> verifyActivationWithGitHub() async {
  // 1. التحقق من وجود ملف التفعيل على GitHub
  // 2. جلب بيانات المستخدمين
  // 3. التحقق من تطابق HWID
  // 4. تأكيد حالة التفعيل
}
```

---

## 🔑 نظام HWID (Hardware ID)

### توليد HWID
```dart
Future<void> _generateHWID() async {
  final deviceInfo = DeviceInfoPlugin();
  String deviceId = '';

  if (Platform.isWindows) {
    final windowsInfo = await deviceInfo.windowsInfo;
    deviceId = '${windowsInfo.computerName}_${windowsInfo.deviceId}';
  }
  // ... باقي المنصات

  // تشفير بـ SHA256 وأخذ أول 32 حرف
  final bytes = utf8.encode(deviceId);
  final digest = sha256.convert(bytes);
  _hwid = digest.toString().substring(0, 32).toUpperCase();
}
```

### خصائص HWID
- **الطول:** 32 حرف
- **الصيغة:** أحرف كبيرة وأرقام (Hex)
- **الفريدية:** فريد لكل جهاز
- **التوافق:** متوافق مع نسخة Python

---

## 📊 حالات المستخدم (User States)

| الحالة | الوصف | الموقع |
|--------|-------|--------|
| `pending` | طلب تسجيل معلق | `applications.json` |
| `active` | مستخدم نشط ومفعل | `users.json` + `activation.dat` |
| `inactive` | مستخدم غير نشط | `users.json` بدون `activation.dat` |
| `expired` | انتهت صلاحيته | `users.json` + فحص التاريخ |

---

## 🔄 تحديث البيانات على GitHub

### تحديث HWID للمستخدم
```dart
Future<bool> _updateUserHWID(String email, String hwid) async {
  // 1. جلب users.json الحالي مع SHA
  // 2. تعديل HWID للمستخدم
  // 3. إضافة last_login
  // 4. رفع التحديث مع commit message
}
```

### حذف التسجيل
```dart
Future<bool> deleteRegistration() async {
  // 1. حذف ملف التفعيل من GitHub
  // 2. إزالة المستخدم من users.json
  // 3. مسح البيانات المحلية
}
```

---

## 💾 التخزين المحلي (Local Storage)

### البيانات المحفوظة محلياً
```dart
// SharedPreferences keys
'isActivated'       // bool - هل التطبيق مفعل
'email'             // String - إيميل المستخدم
'activationCode'    // String - كود التفعيل
'username'          // String - اسم المستخدم
'phoneNumber'       // String - رقم الهاتف
'activationDate'    // String - تاريخ التفعيل
'expirationDate'    // String - تاريخ الانتهاء
'pendingEmail'      // String - إيميل التسجيل المعلق
'registrationStatus'// String - حالة التسجيل
```

---

## 🛡️ إدارة Rate Limit

### آلية تبديل التوكنات
```dart
static void _rotateToken() {
  _currentTokenIndex = (_currentTokenIndex + 1) % _githubTokens.length;
}

static Future<void> _checkRateLimit() async {
  if (_rateLimitRemaining <= 10) {
    final resetTime = _rateLimitReset - currentTime;
    if (resetTime > 0) {
      await Future.delayed(Duration(seconds: resetTime + 1));
    }
  }
}
```

---

## 🎨 واجهة التفعيل (UI)

### أوضاع شاشة التفعيل
```dart
int _currentMode = 0;
// 0 = إدخال مفتاح التفعيل (Key)
// 1 = تسجيل الدخول (Login)
// 2 = تسجيل جديد (Register)
```

### الحقول المطلوبة حسب الوضع
| الوضع | الحقول |
|-------|--------|
| Key | كود التفعيل فقط |
| Login | البريد الإلكتروني + كلمة المرور |
| Register | الاسم + البريد + الهاتف + كلمة المرور + تأكيد كلمة المرور |

---

## 📱 التوافق مع نسخة Python

### التوافق الكامل مع:
- `main.py` - التطبيق الرئيسي
- `adminTool.py` - أداة الإدارة
- `po.py` - النسخة المحمولة
- `user_management_tab.py` - تبويب إدارة المستخدمين

### الوظائف المتوافقة:
| Flutter | Python |
|---------|--------|
| `registerUser()` | `register()` |
| `activateWithKey()` | `activate()` |
| `verifyActivationWithGitHub()` | `verify_activation()` |
| `_generateHWID()` | `generate_hwid()` |
| `_emailToFilename()` | filename formatting |

---

## 🔍 API Endpoints

### GitHub Raw URL
```
https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{file}
```

### GitHub API URL
```
https://api.github.com/repos/{owner}/{repo}/contents/{file}
```

### أمثلة:
```
# users.json
https://raw.githubusercontent.com/tiraUnderCode23/AQ/main/users.json
https://api.github.com/repos/tiraUnderCode23/AQ/contents/users.json

# activation file
https://api.github.com/repos/tiraUnderCode23/AQ/contents/activations/{filename}
```

---

## ⚙️ خطوات إضافة مستخدم جديد (للمسؤول)

### 1. من برنامج الإدارة:
1. فتح قسم إدارة المستخدمين
2. اختيار الطلب المعلق من `applications.json`
3. مراجعة البيانات
4. الضغط على "موافقة" أو "Generate Activation Code"
5. يتم تلقائياً:
   - نقل المستخدم إلى `users.json`
   - إنشاء ملف `activations/{email}_activation.dat`
   - إرسال الكود للمستخدم

### 2. يدوياً عبر GitHub:
1. إضافة المستخدم إلى `users.json`
2. إنشاء ملف في `activations/` بصيغة الاسم الصحيحة
3. كتابة كود التفعيل في الملف

---

## 📞 معلومات الدعم

```dart
// في رسائل التفعيل
subject = "AQ///BIMMER Activation Key";
body = """
  Dear {user_name},
  Welcome to AQ///BIMMER!
  
  Please use this code to activate your account.
  
  For support:
  - WhatsApp: +972528180757
""";
```

---

## 🔐 ملاحظات أمنية

1. **كلمات المرور:** يتم تشفيرها بـ SHA256 قبل الحفظ
2. **HWID:** يتم ربط كل تفعيل بجهاز محدد
3. **التوكنات:** استخدام توكنات متعددة مع تبديل تلقائي
4. **التحقق المزدوج:** فحص ملف التفعيل + بيانات المستخدم

---

## 📝 تحديثات وملاحظات إضافية

- نظام التفعيل يدعم الفحص التلقائي عند بدء التطبيق
- يمكن للمستخدم حذف تسجيله وإعادة التسجيل بجهاز جديد
- دعم كامل لـ Windows, macOS, Linux, Android, iOS
- التطبيق يتحقق من انتهاء الصلاحية تلقائياً

---

*آخر تحديث: December 2024*
*للاستفسارات التقنية: مراجعة ملفات الكود المصدري*
