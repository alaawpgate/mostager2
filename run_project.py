#!/usr/bin/env python3
"""
ملف تشغيل المشروع - نظام إدارة المستأجرين
يمكن تشغيله من سطر الأوامر بالأمر: python run_project.py
"""

import os
import sys
import subprocess
import platform

def check_python_version():
    """التحقق من إصدار Python"""
    if sys.version_info < (3, 8):
        print("❌ خطأ: يتطلب Python 3.8 أو أحدث")
        print(f"الإصدار الحالي: {sys.version}")
        return False
    return True

def check_virtual_environment():
    """التحقق من البيئة الافتراضية"""
    venv_path = os.path.join(os.path.dirname(__file__), 'venv')
    if os.path.exists(venv_path):
        print("✅ تم العثور على البيئة الافتراضية")
        return venv_path
    return None

def activate_virtual_environment(venv_path):
    """تفعيل البيئة الافتراضية"""
    system = platform.system().lower()
    
    if system == "windows":
        activate_script = os.path.join(venv_path, 'Scripts', 'activate.bat')
        python_exe = os.path.join(venv_path, 'Scripts', 'python.exe')
    else:
        activate_script = os.path.join(venv_path, 'bin', 'activate')
        python_exe = os.path.join(venv_path, 'bin', 'python')
    
    if os.path.exists(python_exe):
        return python_exe
    return None

def install_requirements():
    """تثبيت المتطلبات"""
    requirements_file = os.path.join(os.path.dirname(__file__), 'requirements.txt')
    if os.path.exists(requirements_file):
        print("📦 تثبيت المتطلبات...")
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-r', requirements_file])
            print("✅ تم تثبيت المتطلبات بنجاح")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ خطأ في تثبيت المتطلبات: {e}")
            return False
    return True

def run_application():
    """تشغيل التطبيق كبرنامج سطح مكتب"""
    print("🚀 بدء تشغيل نظام إدارة المستأجرين...")
    print("=" * 50)
    
    # التحقق من إصدار Python
    if not check_python_version():
        return False
    
    # التحقق من البيئة الافتراضية
    venv_path = check_virtual_environment()
    python_exe = sys.executable
    
    if venv_path:
        venv_python = activate_virtual_environment(venv_path)
        if venv_python:
            python_exe = venv_python
            print(f"🔧 استخدام البيئة الافتراضية: {venv_path}")
    
    # تثبيت المتطلبات
    if not install_requirements():
        return False
    
    # تشغيل التطبيق كبرنامج سطح مكتب
    try:
        print("\n🖥️  تشغيل البرنامج...")
        print("🚀 سيتم فتح نافذة التطبيق...")
        print("⏹️  لإغلاق البرنامج: أغلق النافذة")
        print("=" * 50)
        
        # تشغيل main.py أو desktop_app.py
        main_path = os.path.join(os.path.dirname(__file__), 'main.py')
        desktop_path = os.path.join(os.path.dirname(__file__), 'desktop_app.py')
        
        if os.path.exists(main_path):
            subprocess.run([python_exe, main_path])
        elif os.path.exists(desktop_path):
            subprocess.run([python_exe, desktop_path])
        else:
            # تشغيل مباشر
            import webview
            import threading
            from app import AdminApp
            
            def start_flask_app():
                admin_app = AdminApp()
                admin_app.app.run(host='127.0.0.1', port=8080, debug=False, use_reloader=False)
            
            # تشغيل Flask في خيط منفصل
            flask_thread = threading.Thread(target=start_flask_app, daemon=True)
            flask_thread.start()
            
            # انتظار قليل لبدء Flask
            import time
            time.sleep(2)
            
            # إنشاء وتشغيل نافذة التطبيق
            webview.create_window(
                title='نظام إدارة المستأجرين',
                url='http://127.0.0.1:8080',
                width=1200,
                height=800,
                min_size=(800, 600),
                resizable=True
            )
            
            webview.start()
            
    except KeyboardInterrupt:
        print("\n⏹️  تم إغلاق البرنامج بواسطة المستخدم")
        return True
    except ImportError as e:
        print(f"❌ خطأ في استيراد المكتبات: {e}")
        print("💡 تأكد من تثبيت جميع المتطلبات بالأمر:")
        print("   pip install -r requirements.txt")
        print("   pip install pywebview")
        return False
    except Exception as e:
        print(f"❌ خطأ في تشغيل التطبيق: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """الدالة الرئيسية"""
    print("🏠 نظام إدارة المستأجرين")
    print("=" * 30)
    
    # التحقق من وجود الملفات المطلوبة
    required_files = ['app.py', 'config.py']
    missing_files = []
    
    for file in required_files:
        if not os.path.exists(os.path.join(os.path.dirname(__file__), file)):
            missing_files.append(file)
    
    if missing_files:
        print(f"❌ ملفات مفقودة: {', '.join(missing_files)}")
        return False
    
    # تشغيل التطبيق
    return run_application()

if __name__ == "__main__":
    success = main()
    if not success:
        print("\n❌ فشل في تشغيل التطبيق")
        sys.exit(1)
    else:
        print("\n✅ تم إنهاء التطبيق بنجاح")