#!/usr/bin/env python3
"""
ملف تشغيل الخادم مع معالجة الأخطاء
"""

import sys
import os
import traceback

def main():
    try:
        print("=== بدء تشغيل نظام إدارة المستأجرين ===")
        print(f"Python Version: {sys.version}")
        print(f"Working Directory: {os.getcwd()}")
        
        # استيراد التطبيق
        from app import AdminApp
        
        # إنشاء وتشغيل التطبيق
        app = AdminApp()
        print("✅ تم إنشاء التطبيق بنجاح")
        
        print("🚀 بدء تشغيل الخادم على http://localhost:8080")
        print("للإيقاف اضغط Ctrl+C")
        
        app.run(debug=True)
        
    except ImportError as e:
        print(f"❌ خطأ في الاستيراد: {e}")
        print("تأكد من تثبيت جميع المتطلبات:")
        print("pip3 install flask beautifulsoup4 apscheduler")
        
    except Exception as e:
        print(f"❌ خطأ في تشغيل التطبيق: {e}")
        print("\nتفاصيل الخطأ:")
        traceback.print_exc()
        
    except KeyboardInterrupt:
        print("\n🛑 تم إيقاف الخادم")

if __name__ == '__main__':
    main()