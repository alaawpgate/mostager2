@echo off
chcp 65001 >nul
title نظام إدارة المستأجرين

echo.
echo 🏠 نظام إدارة المستأجرين
echo 🖥️  تطبيق سطح المكتب
echo ========================
echo.

if exist "venv\Scripts\python.exe" (
    echo ✅ تشغيل البرنامج...
    venv\Scripts\python.exe تشغيل.py
) else (
    echo ✅ تشغيل البرنامج...
    python تشغيل.py
)

echo.
pause