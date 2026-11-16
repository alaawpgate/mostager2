#!/usr/bin/env python3
"""
ملف تشغيل مبسط لنظام إدارة المستأجرين كتطبيق سطح مكتب
"""

import os
import sys

def main():
    print("🏠 نظام إدارة المستأجرين")
    print("=" * 30)
    
    try:
        # تشغيل التطبيق كبرنامج سطح مكتب
        print("🚀 بدء تشغيل البرنامج...")
        print("🖥️  سيتم فتح نافذة التطبيق...")
        print("⏹️  لإغلاق البرنامج: أغلق النافذة")
        print("=" * 30)
        
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
        print("\n⏹️  تم إغلاق البرنامج")
    except ImportError as e:
        print(f"❌ خطأ: {e}")
        print("💡 تأكد من تثبيت المتطلبات:")
        print("   pip install -r requirements.txt")
        print("   pip install pywebview")
    except Exception as e:
        print(f"❌ خطأ: {e}")

if __name__ == "__main__":
    main()