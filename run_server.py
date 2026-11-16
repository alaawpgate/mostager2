#!/usr/bin/env python3

import sys
import os
from flask import Flask

print("=== Flask Server Startup ===")
print(f"Python: {sys.version}")
print(f"Working directory: {os.getcwd()}")

# إنشاء تطبيق Flask بسيط للاختبار
app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <h1>نظام إدارة المستأجرين</h1>
    <p>الخادم يعمل بنجاح!</p>
    <a href="/login">تسجيل الدخول</a>
    '''

@app.route('/login')
def login():
    return '''
    <h2>تسجيل الدخول</h2>
    <form method="post">
        <p>اسم المستخدم: admin</p>
        <p>كلمة المرور: admin123</p>
        <button type="submit">دخول</button>
    </form>
    '''

if __name__ == '__main__':
    print("Starting Flask server...")
    print("URL: http://localhost:8080")
    print("Press Ctrl+C to stop")
    
    try:
        app.run(
            host='0.0.0.0',
            port=8080,
            debug=True,
            use_reloader=False
        )
    except KeyboardInterrupt:
        print("\nServer stopped")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()