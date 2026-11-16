#!/usr/bin/env python3
"""
اختبار سريع لبناء الملف التنفيذي
"""

import subprocess
import sys
import os

def test_build():
    """اختبار بناء الملف التنفيذي"""
    print("🧪 اختبار بناء الملف التنفيذي...")
    
    try:
        # تشغيل PyInstaller مباشرة
        cmd = [
            sys.executable, "-m", "PyInstaller",
            "--onefile",
            "--windowed",
            "--name=mostager_test",
            "--add-data=templates;templates",
            "--add-data=static;static",
            "--hidden-import=flask",
            "--hidden-import=pywebview",
            "--hidden-import=sqlite3",
            "main_exe.py"
        ]
        
        print("تشغيل الأمر:", " ".join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ نجح الاختبار!")
            exe_path = "dist/mostager_test.exe"
            if os.path.exists(exe_path):
                size = os.path.getsize(exe_path) / (1024 * 1024)
                print(f"📁 الملف: {exe_path}")
                print(f"📏 الحجم: {size:.1f} MB")
            return True
        else:
            print("❌ فشل الاختبار:")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ خطأ: {e}")
        return False

if __name__ == "__main__":
    test_build()