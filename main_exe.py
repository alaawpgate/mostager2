#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
نظام مُستأجِر لإدارة العقارات والعقود - مشغل سطح المكتب (Windows Desktop Launcher)
Enterprise-grade launcher with persistent AppData storage, zero CMD window,
automatic database seeding, and robust crash recovery.
"""

import sys
import os
import shutil
import socket
import logging
from logging.handlers import RotatingFileHandler
import threading
import time

# 1. تحديد مسار الحزمة (Bundle Directory) ومسار بيانات المستخدم (AppData Directory)
if getattr(sys, 'frozen', False):
    # تشغيل كملف تنفيذي مجمع بواسطة PyInstaller
    bundle_dir = sys._MEIPASS
    exe_dir = os.path.dirname(sys.executable)
else:
    # تشغيل مباشر عبر بايثون في بيئة التطوير
    bundle_dir = os.path.dirname(os.path.abspath(__file__))
    exe_dir = bundle_dir

# إضافة مسار الحزمة إلى مسارات البحث في بايثون
if bundle_dir not in sys.path:
    sys.path.insert(0, bundle_dir)

def resolve_data_directory():
    """
    تحديد وتجهيز مجلد حفظ البيانات الدائمة داخل AppData في نظام ويندوز
    لضمان عدم الكتابة داخل Program Files وتجنب مشاكل الصلاحيات وضياع البيانات عند التحديث.
    """
    if os.environ.get('MOSTAGER_DATA_DIR'):
        target_dir = os.environ['MOSTAGER_DATA_DIR']
    elif sys.platform == 'win32' or getattr(sys, 'frozen', False):
        appdata_base = os.environ.get('APPDATA') or os.path.expanduser('~')
        target_dir = os.path.join(appdata_base, 'Mostager')
    else:
        # وضع التطوير على Mac/Linux
        target_dir = bundle_dir

    os.makedirs(target_dir, exist_ok=True)
    uploads_dir = os.path.join(target_dir, 'uploads')
    os.makedirs(uploads_dir, exist_ok=True)
    
    return target_dir, uploads_dir

data_dir, uploads_dir = resolve_data_directory()

# توجيه مجلد العمل الحالي إلى مجلد البيانات
# هذا يضمن أن أي استدعاء لـ sqlite3.connect('database.db') يتعامل مباشرة مع قاعدة بيانات AppData
os.chdir(data_dir)

# 2. إعداد نظام السجلات (Logging System)
log_file = os.path.join(data_dir, 'mostager.log')
log_handler = RotatingFileHandler(log_file, maxBytes=3 * 1024 * 1024, backupCount=2, encoding='utf-8')
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[log_handler, logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger('MostagerLauncher')

def show_native_error(title, message):
    """عرض رسالة خطأ رسومية أصلية في حال حدوث عطل غير متوقع"""
    logger.critical(f"FATAL ERROR: {title} - {message}")
    if sys.platform == 'win32':
        try:
            import ctypes
            ctypes.windll.user32.MessageBoxW(0, message, title, 0x10 | 0x0)
            return
        except Exception:
            pass
    print(f"\n[ERROR] {title}: {message}\n")

def seed_persistent_data():
    """
    نسخ قاعدة البيانات والمرفقات الافتراضية عند التشغيل لأول مرة فقط
    دون المساس بأي بيانات تم تعديلها أو إضافتها لاحقاً.
    """
    dest_db = os.path.join(data_dir, 'database.db')
    source_db = os.path.join(bundle_dir, 'database.db')
    
    if not os.path.exists(dest_db):
        if os.path.exists(source_db):
            logger.info(f"نسخ قاعدة البيانات الأولية من {source_db} إلى {dest_db}...")
            shutil.copy2(source_db, dest_db)
        else:
            logger.info("قاعدة البيانات الأولية غير موجودة في الحزمة، سيتم إنشاؤها تلقائياً.")
    else:
        logger.info(f"تم العثور على قاعدة البيانات الحالية في: {dest_db}")

    # نسخ الملفات الافتراضية إلى مجلد المرفقات إذا كان فارغاً
    source_uploads = os.path.join(bundle_dir, 'static', 'uploads')
    if os.path.exists(source_uploads) and not os.listdir(uploads_dir):
        logger.info("نسخ الملفات الافتراضية الأولية إلى مجلد المرفقات الدائم...")
        for item in os.listdir(source_uploads):
            s = os.path.join(source_uploads, item)
            d = os.path.join(uploads_dir, item)
            if os.path.isfile(s) and not os.path.exists(d):
                try:
                    shutil.copy2(s, d)
                except Exception as e:
                    logger.warning(f"تعذر نسخ المرفق الافتراضي {item}: {e}")

def find_available_port(start_port=8080, max_attempts=15):
    """البحث عن منفذ متاح للتشغيل في حال كان المنفذ 8080 مشغولاً"""
    for port in range(start_port, start_port + max_attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(('127.0.0.1', port)) != 0:
                return port
    return start_port

def wait_for_server(port, timeout=25):
    """انتظار بدء استجابة خادم Flask"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(1)
                if sock.connect_ex(('127.0.0.1', port)) == 0:
                    logger.info(f"الخادم المحلي جاهز للاستخدام على المنفذ {port}")
                    return True
        except Exception:
            pass
        time.sleep(0.3)
    logger.error("انتهت مهلة انتظار تشغيل الخادم الداخلي")
    return False

def start_flask_server(port):
    """بدء تشغيل خادم التطبيق الداخلي في خيط منفصل"""
    try:
        from app import AdminApp
        admin_app = AdminApp()
        
        # ربط مجلد المرفقات بمجلد AppData الدائم
        admin_app.app.config['UPLOAD_FOLDER'] = uploads_dir
        
        logger.info(f"بدء تشغيل Flask على http://127.0.0.1:{port}...")
        admin_app.app.run(
            host='127.0.0.1',
            port=port,
            debug=False,
            use_reloader=False,
            threaded=True
        )
    except Exception as e:
        logger.exception(f"خطأ غير متوقع أثناء تشغيل خادم Flask: {e}")
        show_native_error(
            "خطأ في خادم التطبيق الداخلي",
            f"حدث خطأ أثناء تشغيل خادم التطبيق:\n{e}\n\nيرجى مراجعة ملف السجل:\n{log_file}"
        )

def main():
    logger.info("=" * 60)
    logger.info("تشغيل نظام مُستأجِر لإدارة العقارات والعقود (إصدار سطح المكتب)")
    logger.info(f"مسار حزمة التطبيق (Bundle): {bundle_dir}")
    logger.info(f"مسار بيانات المستخدم (AppData): {data_dir}")
    logger.info("=" * 60)

    # 1. تهيئة ملفات وقواعد بيانات المستخدم
    seed_persistent_data()

    # 2. تحديد المنفذ المتاح
    port = find_available_port(8080)

    # 3. تشغيل الخادم في الخلفية (Daemon Thread)
    flask_thread = threading.Thread(target=start_flask_server, args=(port,), daemon=True)
    flask_thread.start()

    # 4. التحقق من جاهزية السيرفر
    if not wait_for_server(port):
        show_native_error(
            "تعذر تشغيل النظام",
            f"لم يستجب الخادم المحلي على المنفذ {port}.\nيرجى التحقق من جدار الحماية أو فحص ملف السجل:\n{log_file}"
        )
        sys.exit(1)

    # 5. تشغيل نافذة واجهة المستخدم الأصلية عبر pywebview
    try:
        import webview
        
        icon_path = os.path.join(bundle_dir, 'app.ico')
        if not os.path.exists(icon_path):
            icon_path = os.path.join(bundle_dir, 'static', 'img', 'app.ico')

        window_url = f'http://127.0.0.1:{port}'
        logger.info(f"فتح نافذة سطح المكتب الرسومية على: {window_url}")

        window = webview.create_window(
            title='نظام مُستأجِر - منظومة إدارة العقارات والمستأجرين',
            url=window_url,
            width=1280,
            height=840,
            min_size=(960, 640),
            resizable=True,
            fullscreen=False,
            confirm_close=True,
            background_color='#0b1324'
        )

        # تشغيل WebView (تستخدم Edge Chromium تلقائياً في ويندوز 10 و 11)
        webview.start(debug=False)
        logger.info("تم إغلاق البرنامج بنجاح من قِبل المستخدم.")

    except Exception as e:
        logger.exception(f"خطأ أثناء فتح نافذة سطح المكتب: {e}")
        show_native_error(
            "خطأ في واجهة العرض",
            f"تعذر فتح نافذة العرض الرسومية:\n{e}\n\nيرجى التأكد من توفر Microsoft Edge WebView2 على الجهاز."
        )
        sys.exit(1)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        logger.exception(f"خطأ غير معالج: {e}")
        show_native_error("خطأ غير متوقع", f"حدث خطأ غير متوقع:\n{e}\n\nالسجل: {log_file}")
        sys.exit(1)
