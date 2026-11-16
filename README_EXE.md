# نظام إدارة المستأجرين - إصدار Windows

## كيفية إنشاء الملف التنفيذي

### الخطوات البسيطة:

1. **تأكد من تثبيت Python:**
   - حمل Python من: https://python.org
   - اختر "Add Python to PATH" أثناء التثبيت

2. **افتح Command Prompt كمدير:**
   - اضغط Windows + R
   - اكتب `cmd`
   - اضغط Ctrl + Shift + Enter

3. **انتقل إلى مجلد المشروع:**
   ```cmd
   cd "C:\path\to\mostager-3"
   ```

4. **شغل ملف البناء:**
   ```cmd
   build_exe.bat
   ```

5. **انتظر انتهاء العملية** (قد تستغرق 5-10 دقائق)

6. **ستجد الملف التنفيذي في:**
   ```
   distribution\mostager.exe
   ```

## استكشاف الأخطاء الشائعة

### "Python is not recognized"
- أعد تثبيت Python واختر "Add to PATH"
- أعد تشغيل Command Prompt

### "Permission denied"
- شغل Command Prompt كمدير
- عطل برنامج مكافحة الفيروسات مؤقتاً

### "Module not found"
- تأكد من الاتصال بالإنترنت
- شغل: `pip install -r requirements.txt`

## تشغيل البرنامج

1. انسخ مجلد `distribution` إلى أي مكان
2. شغل `mostager.exe`
3. سيفتح البرنامج في المتصفح تلقائياً

## متطلبات النظام

- Windows 10 أو أحدث
- 4 GB RAM
- 100 MB مساحة فارغة
- اتصال بالإنترنت

## الدعم الفني

إذا واجهت مشاكل:
1. تحقق من ملف `mostager.log`
2. تأكد من وجود `database.db`
3. شغل البرنامج كمدير
4. أضف استثناء في Windows Defender

---

**نصيحة:** احتفظ بنسخة من مجلد المشروع الأصلي للتحديثات المستقبلية.