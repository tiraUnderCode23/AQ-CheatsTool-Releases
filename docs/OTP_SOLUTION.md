# حل مشكلة عدم إرسال OTP للمستخدمين

## المشكلة
لا يتم إرسال رسائل OTP للمستخدمين الجدد عبر WhatsApp.

## السبب
1. **قاعدة 24 ساعة**: WhatsApp Business API لا يسمح بإرسال رسائل للمستخدمين الذين لم يراسلوك في آخر 24 ساعة
2. **القوالب غير معتمدة**: جميع القوالب الحالية إما مرفوضة (REJECTED) أو في انتظار الموافقة (PENDING)

## الحل

### الخطوة 1: إنشاء قالب Authentication OTP

1. اذهب إلى: https://business.facebook.com/wa/manage/message-templates/?waba_id=576625715530014

2. اضغط على **Create Template**

3. اختر الإعدادات التالية:
   - **Category**: `AUTHENTICATION` (هذا النوع يتم الموافقة عليه تلقائياً)
   - **Name**: `verification_code`
   - **Language**: `English` أو اللغة المطلوبة

4. في قسم **Template Content**:
   - اختر **Copy Code Button** لإضافة زر نسخ الكود
   - Body سيكون تلقائياً: "Your verification code is {{1}}"

5. اضغط **Submit**

### الخطوة 2: انتظار الموافقة
- قوالب **AUTHENTICATION** عادة تتم الموافقة عليها خلال دقائق
- قوالب **UTILITY** قد تستغرق ساعات إلى أيام

### الخطوة 3: التحقق من الموافقة

شغل هذا الأمر للتحقق:
```bash
dart run test/get_templates.dart
```

يجب أن ترى `verification_code` بحالة `APPROVED`.

## ملاحظات هامة

### إذا تم رفض القالب:
- تأكد من استخدام فئة `AUTHENTICATION` وليس `UTILITY`
- لا تضف محتوى إضافي غير ضروري
- استخدم صيغة بسيطة: "Your verification code is {{1}}"

### حل بديل مؤقت:
اطلب من المستخدمين إرسال رسالة "Hi" إلى رقم الأعمال أولاً:
- **رقم الأعمال**: +972 52-486-4281

هذا يفتح نافذة 24 ساعة يمكن خلالها إرسال رسائل نصية عادية.

## روابط مفيدة
- [Meta Business Suite](https://business.facebook.com/wa/manage/)
- [Message Templates](https://business.facebook.com/wa/manage/message-templates/?waba_id=576625715530014)
- [WhatsApp API Documentation](https://developers.facebook.com/docs/whatsapp/business-management-api/authentication-templates)
