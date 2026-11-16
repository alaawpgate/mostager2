@echo off
chcp 65001 >nul
echo 🚀 بناء ملف تنفيذي لنظام إدارة المستأجرين
echo ================================================

REM التحقق من وجود Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python غير مثبت على النظام
    echo يرجى تثبيت Python 3.8 أو أحدث من: https://python.org
    pause
    exit /b 1
)

REM تشغيل سكريبت البناء
python build_exe.py

if errorlevel 1 (
    echo ❌ فشل في بناء الملف التنفيذي
    pause
    exit /b 1
)

echo.
echo ✅ تم بناء الملف التنفيذي بنجاح!
echo 📁 ستجد الملف في مجلد: distribution\mostager.exe
echo.
pause