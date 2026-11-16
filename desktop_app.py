import webview
import threading
from app import AdminApp

def start_flask_app():
    """Start Flask app in a separate thread"""
    admin_app = AdminApp()
    admin_app.app.run(host='127.0.0.1', port=8080, debug=False, use_reloader=False)

def main():
    # Start Flask app in background thread
    flask_thread = threading.Thread(target=start_flask_app, daemon=True)
    flask_thread.start()
    
    # Wait a moment for Flask to start
    import time
    time.sleep(2)
    
    # Create and start webview window
    webview.create_window(
        title='نظام إدارة المستأجرين',
        url='http://127.0.0.1:8080',
        width=1200,
        height=800,
        min_size=(800, 600)
    )
    
    webview.start()

if __name__ == '__main__':
    main()