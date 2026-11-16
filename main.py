import webview
import threading
from app import AdminApp

def start_flask():
    app = AdminApp()
    app.app.run(host='127.0.0.1', port=8080, debug=False)

if __name__ == '__main__':
    # Start Flask in a separate thread
    flask_thread = threading.Thread(target=start_flask)
    flask_thread.daemon = True
    flask_thread.start()
    
    # Create and start the webview window
    webview.create_window('نظام إدارة المستأجرين', 'http://127.0.0.1:8080', width=1200, height=800)
    webview.start()