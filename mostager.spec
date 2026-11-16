# -*- mode: python ; coding: utf-8 -*-

import os
import sys

block_cipher = None

# قائمة الملفات والمجلدات الثابتة المطلوبة للتشغيل
datas = [
    ('templates', 'templates'),
    ('static', 'static'),
    ('database.db', '.'),
    ('avatar.png', '.'),
    ('app.ico', '.'),
    ('contract_page_one.html', '.'),
    ('contract_page_tow.html', '.'),
]

# قائمة الوحدات البرمجية التي قد لا يكتشفها المحلل التلقائي
hiddenimports = [
    'flask',
    'pywebview',
    'pywebview.platforms.winforms',
    'pywebview.platforms.edgechromium',
    'pywebview.platforms.mshtml',
    'sqlite3',
    'apscheduler',
    'apscheduler.schedulers.background',
    'apscheduler.triggers.cron',
    'beautifulsoup4',
    'bs4',
    'requests',
    'werkzeug',
    'jinja2',
    'markupsafe',
    'itsdangerous',
    'click',
    'blinker',
    'pytz',
    'tzlocal',
    'six',
    'urllib3',
    'certifi',
    'charset_normalizer',
    'idna',
    'soupsieve',
    'clr',
    'System.Windows.Forms',
    'System.Threading',
    'System.Drawing',
]

a = Analysis(
    ['main_exe.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib', 'numpy', 'scipy', 'pandas', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='mostager',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='app.ico',
)
