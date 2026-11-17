import os
import sys

# Set working directory to this script's directory
current_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(current_dir)
sys.path.insert(0, current_dir)

from app import AdminApp
from waitress import serve

print("Initializing AdminApp for production...")
admin_app = AdminApp()
application = admin_app.app

if __name__ == '__main__':
    PORT = 19080
    print(f"Starting Waitress on 127.0.0.1:{PORT}...")
    serve(application, host='127.0.0.1', port=PORT, threads=8)
