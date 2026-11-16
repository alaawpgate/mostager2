# 🚀 تعليمات تشغيل المشروع

## نظام إدارة المستأجرين

هذا المشروع هو نظام إدارة المستأجرين مبني بـ Flask ويمكن تشغيله بعدة طرق.

---

## 📋 المتطلبات الأساسية

- Python 3.8 أو أحدث
- pip (مدير حزم Python)
- اتصال بالإنترنت (لتثبيت المكتبات)

---

## 🖥️ طرق التشغيل

### 1️⃣ التشغيل التلقائي (الأسهل)

#### على Windows:
```cmd
# انقر مرتين على الملف أو شغله من cmd
run_project.bat
```

#### على macOS/Linux:
```bash
# في Terminal
./run_project.sh
```

### 2️⃣ التشغيل باستخدام Python

```bash
# تشغيل مباشر
python run_project.py

# أو
python3 run_project.py
```

### 3️⃣ التشغيل اليدوي

```bash
# 1. تثبيت المتطلبات
pip install -r requirements.txt

# 2. تشغيل التطبيق
python simple_run.py
```

### 4️⃣ التشغيل مع البيئة الافتراضية

```bash
# إنشاء البيئة الافتراضية (إذا لم تكن موجودة)
python -m venv venv

# تفعيل البيئة الافتراضية
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# تثبيت المتطلبات
pip install -r requirements.txt

# تشغيل التطبيق
python simple_run.py
```

---

## 🌐 الوصول للتطبيق

بعد تشغيل المشروع بنجاح:

- **العنوان:** http://localhost:8080
- **المتصفح:** افتح أي متصفح واذهب للعنوان أعلاه

---

## 🔧 استكشاف الأخطاء

### خطأ: "Python is not recognized"
**الحل:**
- تأكد من تثبيت Python
- أضف Python إلى PATH
- أعد تشغيل Terminal/CMD

### خطأ: "Module not found"
**الحل:**
```bash
pip install -r requirements.txt
```

### خطأ: "Permission denied"
**الحل:**
```bash
# على macOS/Linux
chmod +x run_project.sh

# على Windows: شغل CMD كمدير
```

### خطأ: "Port already in use"
**الحل:**
- أغلق أي تطبيق يستخدم المنفذ 8080
- أو غير المنفذ في الكود

---

## 📁 ملفات التشغيل

| الملف | الوصف | النظام |
|-------|--------|---------|
| `run_project.py` | ملف Python الرئيسي | جميع الأنظمة |
| `run_project.bat` | ملف تشغيل Windows | Windows |
| `run_project.sh` | ملف تشغيل Unix | macOS/Linux |
| `simple_run.py` | تشغيل مبسط | جميع الأنظمة |

---

## 🎯 الميزات

- ✅ تشغيل تلقائي للمتطلبات
- ✅ دعم البيئة الافتراضية
- ✅ رسائل خطأ واضحة
- ✅ دعم جميع أنظمة التشغيل
- ✅ واجهة ويب سهلة الاستخدام

---

## 📞 الدعم الفني

إذا واجهت أي مشاكل:

1. تأكد من تثبيت Python 3.8+
2. تأكد من وجود جميع الملفات
3. جرب تشغيل `pip install -r requirements.txt`
4. تحقق من رسائل الخطأ في Terminal/CMD

---

## 🎉 تهانينا!

إذا رأيت رسالة "Starting server on http://localhost:8080" فقد تم تشغيل المشروع بنجاح!

افتح المتصفح واذهب إلى: **http://localhost:8080**