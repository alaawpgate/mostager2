#!/usr/bin/env python3

import sys
import traceback
import signal
import time

def signal_handler(sig, frame):
    print('\nReceived interrupt signal, shutting down...')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

print("=== Debug Flask Server ===")

try:
    print("Step 1: Importing Flask...")
    from flask import Flask
    print("✓ Flask imported")
    
    print("Step 2: Creating Flask app...")
    app = Flask(__name__)
    print("✓ Flask app created")
    
    print("Step 3: Adding routes...")
    @app.route('/')
    def home():
        return '<h1>Server is running!</h1><p>نظام إدارة المستأجرين</p>'
    
    @app.route('/test')
    def test():
        return '<h2>Test page works!</h2>'
    
    print("✓ Routes added")
    
    print("Step 4: Starting server...")
    print("Server will be available at: http://localhost:8080")
    print("Press Ctrl+C to stop")
    
    # تشغيل الخادم مع معالجة الأخطاء
    app.run(
        host='127.0.0.1',
        port=8080,
        debug=True,
        use_reloader=False,
        threaded=True
    )
    
except KeyboardInterrupt:
    print("\n✓ Server stopped by user")
except Exception as e:
    print(f"\n✗ Error occurred: {e}")
    print("Full traceback:")
    traceback.print_exc()
    
print("Script ended")