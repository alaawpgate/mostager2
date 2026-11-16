#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os

print("=== نظام إدارة المستأجرين ===")
print(f"Python: {sys.version}")
print(f"المجلد: {os.getcwd()}")

try:
    # استيراد التطبيق
    print("1. استيراد التطبيق...")
    from app import AdminApp
    print("   ✅ تم بنجاح")
    
    # إنشاء التطبيق
    print("2. إنشاء التطبيق...")
    app = AdminApp()
    print("   ✅ تم بنجاح")
    
    # تشغيل الخادم
    print("3. تشغيل الخادم...")
    print("   🌐 الرابط: http://127.0.0.1:8080")
    print("   👤 المستخدم: admin")
    print("   🔑 كلمة المرور: admin123")
    print("   ⏹️  للإيقاف: Ctrl+C")
    print("=" * 40)
    
    app.app.run(
        host='127.0.0.1',
        port=8080,
        debug=False,
        use_reloader=False
    )
    
except Exception as e:
    print(f"❌ خطأ: {e}")
    import traceback
    traceback.print_exc()
    input("اضغط Enter للخروج...")