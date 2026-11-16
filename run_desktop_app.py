#!/usr/bin/env python3
"""
تشغيل نظام إدارة المستأجرين كتطبيق سطح مكتب
Desktop Application Launcher for Tenant Management System
"""

import os
import sys
import time
import threading

def check_requirements():
    """التحقق من المتطلبات"""
    try:
        import webview
        import flask
        print("✅ جميع المكتبات المطلوبة متوفرة")
        return True
    except ImportError as e:
        print(f"❌ مكتبة مفقودة: {e}")
        print("💡 قم بتثبيت المتطلبات:")
        print("   pip install -r requirements.txt")
        print("   pip install pywebview")
        return False

def start_flask_server():
    """تشغيل خادم Flask في الخلفية"""
    try:
        from app import AdminApp
        admin_app = AdminApp()
        admin_app.app.run(
            host='127.0.0.1', 
            port=8080, 
            debug=False, 
            use_reloader=False,
            threaded=True
        )
    except Exception as e:
        print(f"❌ خطأ في تشغيل الخادم: {e}")

def create_desktop_window():
    """إنشاء نافذة التطبيق"""
    try:
        import webview
        
        # إنشاء النافذة
        window = webview.create_window(
            title='نظام إدارة المستأجرين',
            url='http://127.0.0.1:8080',
            width=1200,
            height=800,
            min_size=(800, 600),
            resizable=True,
            maximized=False,
            on_top=False,
            shadow=True
        )
        
        return window
    except Exception as e:
        print(f"❌ خطأ في إنشاء النافذة: {e}")
        return None

def main():
    """الدالة الرئيسية"""
    print("🏠 نظام إدارة المستأجرين")
    print("🖥️  تطبيق سطح المكتب")
    print("=" * 40)
    
    # التحقق من المتطلبات
    if not check_requirements():
        input("اضغط Enter للخروج...")
        return False
    
    print("🚀 بدء تشغيل التطبيق...")
    
    try:
        # تشغيل Flask في خيط منفصل
        print("⚙️  تشغيل الخادم الداخلي...")
        flask_thread = threading.Thread(target=start_flask_server, daemon=True)
        flask_thread.start()
        
        # انتظار قليل لبدء الخادم
        print("⏳ انتظار بدء الخادم...")
        time.sleep(3)
        
        # إنشاء نافذة التطبيق
        print("🖼️  إنشاء نافذة التطبيق...")
        window = create_desktop_window()
        
        if window:
            print("✅ تم تشغيل التطبيق بنجاح!")
            print("📝 يمكنك الآن استخدام نظام إدارة المستأجرين")
            print("⏹️  لإغلاق التطبيق: أغلق النافذة")
            print("=" * 40)
            
            # تشغيل التطبيق
            import webview
            webview.start(debug=False)
            
        else:
            print("❌ فشل في إنشاء نافذة التطبيق")
            return False
            
    except KeyboardInterrupt:
        print("\n⏹️  تم إيقاف التطبيق بواسطة المستخدم")
    except Exception as e:
        print(f"❌ خطأ غير متوقع: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    print("✅ تم إغلاق التطبيق بنجاح")
    return True

if __name__ == "__main__":
    success = main()
    if not success:
        print("\n❌ فشل في تشغيل التطبيق")
        input("اضغط Enter للخروج...")
        sys.exit(1)