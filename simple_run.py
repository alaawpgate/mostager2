#!/usr/bin/env python3

print("Starting simple Flask server...")

try:
    from app import AdminApp
    
    print("Creating AdminApp...")
    admin_app = AdminApp()
    
    print("Starting server on http://localhost:8080")
    print("Press Ctrl+C to stop")
    
    # تشغيل الخادم على جميع الواجهات 0.0.0.0 للسماح باتصال تطبيق الموبايل والأجهزة الأخرى
    admin_app.app.run(
        host='0.0.0.0',
        port=8080,
        debug=False,
        use_reloader=False,
        threaded=True
    )
    
except KeyboardInterrupt:
    print("\nServer stopped by user")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()