@echo off
chcp 65001 >nul
title بناء برنامج مُستأجِر لنظام Windows

echo ============================================================
echo      نظام مُستأجِر - بناء حزمة التثبيت لنظام Windows
echo ============================================================
echo.

:: 1. التحقق من توفر بايثون
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [خطأ] لم يتم العثور على Python مثبت على هذا الجهاز!
    echo يرجى تثبيت Python 3.10 أو 3.11 وتفعيل خيار "Add Python to PATH".
    pause
    exit /b 1
)

echo [1/4] تثبيت وتحديث متطلبات بايثون...
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
if %ERRORLEVEL% NEQ 0 (
    echo [خطأ] حدث خطأ أثناء تثبيت المكتبات!
    pause
    exit /b 1
)

echo.
echo [2/4] تنظيف مخلفات البناء السابقة...
if exist "build" rmdir /s /q "build"
if exist "dist" rmdir /s /q "dist"
if exist "dist_setup" rmdir /s /q "dist_setup"
if exist "dist_portable" rmdir /s /q "dist_portable"

echo.
echo [3/4] تجميع البرنامج التنفيذي عبر PyInstaller...
pyinstaller --clean mostager.spec
if not exist "dist\mostager.exe" (
    echo [خطأ] فشل تجميع mostager.exe!
    pause
    exit /b 1
)
echo [نجاح] تم إنشاء ملف dist\mostager.exe بنجاح!

echo.
echo [4/4] بناء ملف التثبيت Setup.exe عبر Inno Setup...
set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%INNO_PATH%" (
    set "INNO_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

if exist "%INNO_PATH%" (
    "%INNO_PATH%" "installer\mostager.iss"
    if exist "dist_setup\Setup.exe" (
        copy "dist_setup\Setup.exe" "dist_setup\Mostager-Setup-v2.5.0.exe" >nul
        echo [نجاح] تم إنشاء ملف التثبيت النهائي بنجاح في: dist_setup\Setup.exe
    )
) else (
    echo [تنبيه] لم يتم العثور على Inno Setup 6 مثبت على المسار الافتراضي!
    echo تم إنشاء ملف mostager.exe بنجاح في مجلد dist\
    echo لإنشاء Setup.exe، يرجى تثبيت Inno Setup من: https://jrsoftware.org/isdl.php
)

:: إنشاء نسخة محمولة مضغوطة
echo.
echo إنشاء النسخة المحمولة (Portable)...
mkdir "dist_portable\Mostager" 2>nul
copy "dist\mostager.exe" "dist_portable\Mostager\" >nul
copy "app.ico" "dist_portable\Mostager\" >nul
copy "avatar.png" "dist_portable\Mostager\" >nul

echo.
echo ============================================================
echo               اكتملت عملية البناء بنجاح!
echo ============================================================
echo.
echo الملفات الناتجة:
echo  1. ملف التثبيت: dist_setup\Setup.exe
echo  2. الملف التنفيذي المباشر: dist\mostager.exe
echo.
pause
