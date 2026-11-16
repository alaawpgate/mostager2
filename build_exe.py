#!/usr/bin/env python3
"""
سكريبت لبناء ملف تنفيذي (.exe) من تطبيق نظام إدارة المستأجرين
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def install_requirements():
    """تثبيت المتطلبات اللازمة"""
    print("🔧 تثبيت المتطلبات...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✅ تم تثبيت المتطلبات بنجاح")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ خطأ في تثبيت المتطلبات: {e}")
        return False

def clean_build_dirs():
    """تنظيف مجلدات البناء السابقة"""
    print("🧹 تنظيف مجلدات البناء السابقة...")
    dirs_to_clean = ['build', 'dist', '__pycache__']
    
    for dir_name in dirs_to_clean:
        if os.path.exists(dir_name):
            shutil.rmtree(dir_name)
            print(f"   حُذف مجلد: {dir_name}")
    
    # حذف ملفات .pyc
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file.endswith('.pyc'):
                os.remove(os.path.join(root, file))

def build_executable():
    """بناء الملف التنفيذي"""
    print("🏗️  بناء الملف التنفيذي...")
    
    try:
        # استخدام ملف spec المخصص
        cmd = [sys.executable, "-m", "PyInstaller", "--clean", "mostager.spec"]
        
        print("تشغيل الأمر:", " ".join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ تم بناء الملف التنفيذي بنجاح!")
            
            # التحقق من وجود الملف
            exe_path = Path("dist/mostager.exe")
            if exe_path.exists():
                size_mb = exe_path.stat().st_size / (1024 * 1024)
                print(f"📁 مسار الملف: {exe_path.absolute()}")
                print(f"📏 حجم الملف: {size_mb:.1f} MB")
                return True
            else:
                print("❌ لم يتم العثور على الملف التنفيذي")
                return False
        else:
            print("❌ خطأ في بناء الملف التنفيذي:")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ خطأ غير متوقع: {e}")
        return False

def create_distribution_package():
    """إنشاء حزمة التوزيع"""
    print("📦 إنشاء حزمة التوزيع...")
    
    dist_dir = Path("distribution")
    if dist_dir.exists():
        shutil.rmtree(dist_dir)
    
    dist_dir.mkdir()
    
    # نسخ الملف التنفيذي
    exe_source = Path("dist/mostager.exe")
    if exe_source.exists():
        shutil.copy2(exe_source, dist_dir / "mostager.exe")
    
    # إنشاء ملف README
    readme_content = """# نظام إدارة المستأجرين

## تشغيل البرنامج
1. تأكد من وجود ملف database.db في نفس مجلد البرنامج
2. قم بتشغيل mostager.exe
3. سيفتح البرنامج في نافذة المتصفح تلقائياً

## متطلبات النظام
- Windows 10 أو أحدث
- .NET Framework 4.7.2 أو أحدث (مثبت افتراضياً في Windows 10)

## الدعم الفني
في حالة مواجهة أي مشاكل، تأكد من:
- إغلاق برامج مكافحة الفيروسات مؤقتاً
- تشغيل البرنامج كمدير (Run as Administrator)
- التأكد من عدم حجب Windows Defender للبرنامج
"""
    
    with open(dist_dir / "README.txt", "w", encoding="utf-8") as f:
        f.write(readme_content)
    
    # نسخ قاعدة البيانات إذا كانت موجودة
    if Path("database.db").exists():
        shutil.copy2("database.db", dist_dir / "database.db")
    
    print(f"✅ تم إنشاء حزمة التوزيع في: {dist_dir.absolute()}")

def main():
    """الدالة الرئيسية"""
    print("🚀 بدء عملية بناء الملف التنفيذي لنظام إدارة المستأجرين")
    print("=" * 60)
    
    # التحقق من وجود الملفات المطلوبة
    required_files = ["main.py", "app.py", "config.py", "requirements.txt"]
    missing_files = [f for f in required_files if not os.path.exists(f)]
    
    if missing_files:
        print(f"❌ ملفات مفقودة: {', '.join(missing_files)}")
        return False
    
    # تنظيف المجلدات
    clean_build_dirs()
    
    # تثبيت المتطلبات
    if not install_requirements():
        return False
    
    # بناء الملف التنفيذي
    if not build_executable():
        return False
    
    # إنشاء حزمة التوزيع
    create_distribution_package()
    
    print("\n" + "=" * 60)
    print("🎉 تم الانتهاء بنجاح!")
    print("📁 ستجد الملف التنفيذي في مجلد: distribution/")
    print("💡 يمكنك نسخ محتويات مجلد distribution إلى أي جهاز Windows وتشغيل البرنامج")
    
    return True

if __name__ == "__main__":
    success = main()
    if not success:
        sys.exit(1)