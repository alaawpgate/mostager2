@echo off
chcp 65001 >nul
title نظام إدارة المستأجرين - برنامج سطح المكتب

echo.
echo 🏠 نظام إدارة المستأجرين
echo ========================
echo 🖥️  تشغيل كبرنامج سطح مكتب
echo.

REM تشغيل مع البيئة الافتراضية إذا كانت موجودة
if exist "venv\Scripts\python.exe" (
    echo ✅ استخدام البيئة الافتراضية
    echo 🚀 بدء تشغيل البرنامج...
    venv\Scripts\python.exe main.py
) else (
    echo ⚠️  استخدام Python العام
    echo 🚀 بدء تشغيل البرنامج...
    python main.py
)

echo.
echo ✅ تم إغلاق البرنامج
pause