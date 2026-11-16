@echo off
chcp 65001 >nul
title نظام إدارة المستأجرين - تطبيق سطح المكتب

cls
echo.
echo ████████████████████████████████████████
echo          نظام إدارة المستأجرين
echo        تطبيق سطح المكتب المتكامل
echo ████████████████████████████████████████
echo.

REM التحقق من وجود Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ خطأ: Python غير مثبت
    echo.
    echo 💡 يرجى تثبيت Python من: https://python.org/downloads/
    echo    تأكد من اختيار "Add Python to PATH"
    echo.
    pause
    exit /b 1
)

echo ✅ تم العثور على Python
python --version

REM التحقق من الملفات المطلوبة
if not exist "main.py" (
    if not exist "desktop_app.py" (
        echo ❌ خطأ: ملفات التطبيق غير موجودة
        pause
        exit /b 1
    )
)

echo ✅ ملفات التطبيق موجودة

REM تحديد Python المستخدم
if exist "venv\Scripts\python.exe" (
    echo ✅ استخدام البيئة الافتراضية
    set PYTHON_EXE=venv\Scripts\python.exe
) else (
    echo ⚠️  استخدام Python العام
    set PYTHON_EXE=python
)

REM تثبيت المتطلبات
echo.
echo 📦 التحقق من المتطلبات...
%PYTHON_EXE% -c "import webview, flask" >nul 2>&1
if errorlevel 1 (
    echo 📥 تثبيت المكتبات المطلوبة...
    %PYTHON_EXE% -m pip install -r requirements.txt
    if errorlevel 1 (
        echo ❌ فشل في تثبيت المتطلبات
        pause
        exit /b 1
    )
)

echo ✅ جميع المتطلبات متوفرة

echo.
echo 🚀 بدء تشغيل التطبيق...
echo 🖥️  سيتم فتح نافذة البرنامج...
echo ⏹️  لإغلاق البرنامج: أغلق النافذة
echo.
echo ████████████████████████████████████████
echo.

REM تشغيل التطبيق
if exist "main.py" (
    %PYTHON_EXE% main.py
) else if exist "desktop_app.py" (
    %PYTHON_EXE% desktop_app.py
) else (
    %PYTHON_EXE% run_desktop_app.py
)

echo.
echo ✅ تم إغلاق التطبيق
echo شكراً لاستخدام نظام إدارة المستأجرين
echo.
pause