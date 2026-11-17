import sys
import os

# Add application directory to path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

# Set up virtual environment site-packages if present
venv_dir = os.path.join(current_dir, 'venv')
if os.path.exists(venv_dir):
    # Search for python3.x site-packages
    lib_dir = os.path.join(venv_dir, 'lib')
    if os.path.exists(lib_dir):
        for entry in os.listdir(lib_dir):
            sp = os.path.join(lib_dir, entry, 'site-packages')
            if os.path.exists(sp):
                sys.path.insert(0, sp)
                break

from app import AdminApp

# WSGI application callable required by cPanel / Phusion Passenger / LiteSpeed
admin_instance = AdminApp()
application = admin_instance.app

if __name__ == '__main__':
    application.run()
