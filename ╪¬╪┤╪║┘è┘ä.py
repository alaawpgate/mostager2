#!/usr/bin/env python3
"""
تشغيل نظام إدارة المستأجرين كتطبيق سطح مكتب
الطريقة الأبسط والأسرع
"""

print("🏠 نظام إدارة المستأجرين")
print("🖥️  تطبيق سطح المكتب")
print("=" * 30)

try:
    print("🚀 بدء التشغيل...")
    
    # استيراد المكتبات
    import webview
    import threading
    import time
    from app import AdminApp
    
    def start_server():
        """تشغيل الخادم"""
        app = AdminApp()
        app.app.run(host='127.0.0.1', port=8080, debug=False, use_reloader=False)
    
    print("⚙️  تشغيل الخادم...")
    # تشغيل الخادم في خيط منفصل
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    
    # انتظار بدء الخادم
    time.sleep(2)
    
    print("🖼️  فتح النافذة...")
    # إنشاء نافذة التطبيق
    webview.create_window(
        'نظام إدارة المستأجرين',
        'http://127.0.0.1:8080',
        width=1200,
        height=800,
        min_size=(800, 600)
    )
    
    print("✅ تم تشغيل التطبيق!")
    print("⏹️  لإغلاق البرنامج: أغلق النافذة")
    
    # تشغيل التطبيق
    webview.start()
    
except ImportError as e:
    print(f"❌ مكتبة مفقودة: {e}")
    print("💡 قم بتشغيل: pip install -r requirements.txt")
except Exception as e:
    print(f"❌ خطأ: {e}")
    
print("✅ تم إغلاق التطبيق")