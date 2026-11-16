@echo off
chcp 65001 >nul
title نظام إدارة المستأجرين

echo.
echo ========================================
echo        نظام إدارة المستأجرين
echo ========================================
echo.

REM التحقق من وجود Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ خطأ: Python غير مثبت أو غير موجود في PATH
    echo.
    echo 💡 يرجى تثبيت Python من: https://python.org/downloads/
    echo    تأكد من اختيار "Add Python to PATH" أثناء التثبيت
    pause
    exit /b 1
)

echo ✅ تم العثور على Python
python --version

REM التحقق من وجود الملفات المطلوبة
if not exist "app.py" (
    echo ❌ خطأ: ملف app.py غير موجود
    pause
    exit /b 1
)

if not exist "config.py" (
    echo ❌ خطأ: ملف config.py غير موجود
    pause
    exit /b 1
)

echo ✅ تم العثور على الملفات المطلوبة

REM التحقق من البيئة الافتراضية
if exist "venv\Scripts\python.exe" (
    echo ✅ استخدام البيئة الافتراضية
    set PYTHON_EXE=venv\Scripts\python.exe
) else (
    echo ⚠️  استخدام Python العام
    set PYTHON_EXE=python
)

REM تثبيت المتطلبات
echo.
echo 📦 تثبيت/تحديث المتطلبات...
%PYTHON_EXE% -m pip install -r requirements.txt
if errorlevel 1 (
    echo ❌ خطأ في تثبيت المتطلبات
    pause
    exit /b 1
)

echo.
echo 🚀 بدء تشغيل النظام...
echo 📍 العنوان: http://localhost:8080
echo ⏹️  للإيقاف: اضغط Ctrl+C
echo ========================================
echo.

REM تشغيل التطبيق
%PYTHON_EXE% run_project.py

echo.
echo ✅ تم إنهاء التطبيق
pause