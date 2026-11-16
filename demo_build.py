#!/usr/bin/env python3
"""
عرض توضيحي لعملية البناء - سيُنشئ مجلد distribution
"""

import os
import shutil
from pathlib import Path

def create_demo_distribution():
    """إنشاء مجلد distribution تجريبي لتوضيح الهيكل"""
    
    print("🎯 إنشاء مجلد distribution تجريبي...")
    
    # إنشاء مجلد distribution
    dist_dir = Path("distribution")
    if dist_dir.exists():
        shutil.rmtree(dist_dir)
    
    dist_dir.mkdir()
    print(f"✅ تم إنشاء مجلد: {dist_dir.absolute()}")
    
    # إنشاء ملف exe وهمي (للتوضيح فقط)
    fake_exe = dist_dir / "mostager.exe"
    with open(fake_exe, "w") as f:
        f.write("# هذا ملف تجريبي - سيتم استبداله بالملف الحقيقي بعد البناء\n")
    print(f"📁 ملف تجريبي: {fake_exe}")
    
    # نسخ قاعدة البيانات
    if Path("database.db").exists():
        shutil.copy2("database.db", dist_dir / "database.db")
        print("📊 تم نسخ قاعدة البيانات")
    
    # إنشاء ملف README
    readme_content = """# نظام إدارة المستأجرين - إصدار Windows

## كيفية التشغيل:
1. تأكد من وجود ملف database.db في نفس المجلد
2. شغل mostager.exe
3. سيفتح البرنامج تلقائياً

## ملاحظات:
- هذا مجلد تجريبي للتوضيح
- الملف الحقيقي سيتم إنشاؤه بعد تشغيل عملية البناء على Windows

## الخطوات التالية:
1. انسخ المشروع إلى جهاز Windows
2. شغل build_exe.bat
3. انتظر انتهاء العملية
4. ستجد الملف التنفيذي الحقيقي هنا

## متطلبات النظام:
- Windows 10 أو أحدث
- 4 GB RAM
- 100 MB مساحة فارغة
"""
    
    with open(dist_dir / "README.txt", "w", encoding="utf-8") as f:
        f.write(readme_content)
    print("📝 تم إنشاء ملف README")
    
    # إنشاء ملف batch للتشغيل
    run_bat = dist_dir / "run_mostager.bat"
    with open(run_bat, "w", encoding="utf-8") as f:
        f.write("""@echo off
chcp 65001 >nul
echo 🚀 تشغيل نظام إدارة المستأجرين
echo ================================

REM التحقق من وجود قاعدة البيانات
if not exist "database.db" (
    echo ⚠️  تحذير: ملف قاعدة البيانات غير موجود
    echo سيتم إنشاؤه تلقائياً عند أول تشغيل
    echo.
)

REM تشغيل البرنامج
echo 🔄 جاري تشغيل البرنامج...
mostager.exe

if errorlevel 1 (
    echo ❌ خطأ في تشغيل البرنامج
    echo تحقق من:
    echo - وجود ملف mostager.exe
    echo - صلاحيات التشغيل
    echo - برامج مكافحة الفيروسات
    pause
)
""")
    print("🔧 تم إنشاء ملف التشغيل")
    
    # عرض محتويات المجلد
    print("\n📂 محتويات مجلد distribution:")
    for item in dist_dir.iterdir():
        if item.is_file():
            size = item.stat().st_size
            print(f"   📄 {item.name} ({size} bytes)")
        else:
            print(f"   📁 {item.name}/")
    
    print(f"\n✅ تم إنشاء مجلد distribution في: {dist_dir.absolute()}")
    print("\n💡 هذا مجلد تجريبي للتوضيح. للحصول على الملف التنفيذي الحقيقي:")
    print("   1. انسخ المشروع إلى جهاز Windows")
    print("   2. شغل build_exe.bat")
    print("   3. انتظر انتهاء عملية البناء")

if __name__ == "__main__":
    create_demo_distribution()