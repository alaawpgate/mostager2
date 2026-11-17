import sys
import os
import traceback

# Add application directory to path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

try:
    from app import AdminApp
    admin_instance = AdminApp()
    application = admin_instance.app
except Exception as e:
    err_msg = traceback.format_exc()
    try:
        with open(os.path.join(current_dir, 'passenger_error.log'), 'w') as f:
            f.write(err_msg)
    except Exception:
        pass

    def application(environ, start_response):
        start_response('500 Internal Server Error', [('Content-Type', 'text/plain; charset=utf-8')])
        return [f"خطأ أثناء تحميل النظام:\n\n{err_msg}".encode('utf-8')]

if __name__ == '__main__':
    application.run()
