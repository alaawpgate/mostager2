#!/usr/bin/env python3
"""
أداة إدارة ومزامنة الملفات مع سيرفر معظم/مستأجر عبر FTP
Server Synchronization & File Manager Tool
"""

import os
import sys
import ftplib
import argparse
from pathlib import Path

# بيانات الاتصال بالسيرفر
FTP_HOST = os.environ.get('MOSTAGER_FTP_HOST', '65.21.196.230')
FTP_USER = os.environ.get('MOSTAGER_FTP_USER', 'virilax')
FTP_PASS = os.environ.get('MOSTAGER_FTP_PASS', '3187226asD@@')
REMOTE_BASE_DIR = 'public_html/mostager.virilax.shop'

def get_ftp_connection():
    """إنشاء اتصال مع السيرفر عبر FTP"""
    try:
        ftp = ftplib.FTP(FTP_HOST, timeout=30)
        ftp.login(FTP_USER, FTP_PASS)
        # الدخول لمجلد الموقع
        for part in REMOTE_BASE_DIR.split('/'):
            if part:
                if part not in ftp.nlst():
                    ftp.mkd(part)
                ftp.cwd(part)
        return ftp
    except Exception as e:
        print(f"❌ فشل الاتصال بالسيرفر: {e}")
        sys.exit(1)

def ensure_remote_dir(ftp, remote_path):
    """إنشاء المجلدات البعيدة إذا لم تكن موجودة"""
    parts = remote_path.strip('/').split('/')
    current = ftp.pwd()
    for part in parts:
        if not part:
            continue
        try:
            ftp.cwd(part)
        except ftplib.error_perm:
            try:
                ftp.mkd(part)
                ftp.cwd(part)
            except Exception:
                pass
    ftp.cwd(current)

def upload_file(ftp, local_file_path, remote_file_name=None):
    """رفع ملف واحد إلى السيرفر"""
    if not os.path.exists(local_file_path):
        print(f"❌ الملف المحلي غير موجود: {local_file_path}")
        return False

    remote_name = remote_file_name or os.path.basename(local_file_path)
    
    # التأكد من المسار البعيد إذا كان يحتوي مجلدات
    if '/' in remote_name:
        remote_dir = os.path.dirname(remote_name)
        ensure_remote_dir(ftp, remote_dir)

    print(f"⬆️  جاري رفع: {local_file_path} -> {remote_name} ...", end="", flush=True)
    try:
        with open(local_file_path, 'rb') as f:
            ftp.storbinary(f'STOR {remote_name}', f)
        print(" ✅ تم بنجاح")
        return True
    except Exception as e:
        print(f" ❌ خطأ: {e}")
        return False

def upload_directory(ftp, local_dir_path, remote_dir_name=""):
    """رفع مجلد بالكامل مع جميع محتوياته"""
    local_dir_path = Path(local_dir_path)
    if not local_dir_path.is_dir():
        print(f"❌ المجلد المحلي غير موجود: {local_dir_path}")
        return

    for root, dirs, files in os.walk(local_dir_path):
        # تجاهل مجلدات النظام المؤقتة ومجلدات البيئة الافتراضية الكبيرة
        if any(ignored in root for ignored in ['__pycache__', '.git', 'venv', '.dart_tool', 'build']):
            continue

        rel_dir = os.path.relpath(root, local_dir_path)
        target_dir = os.path.join(remote_dir_name, rel_dir).replace('\\', '/').strip('./')
        
        if target_dir:
            ensure_remote_dir(ftp, target_dir)

        for filename in files:
            if filename.startswith('.') and filename != '.htaccess':
                continue
            local_file = os.path.join(root, filename)
            remote_file = os.path.join(target_dir, filename).replace('\\', '/').strip('/')
            upload_file(ftp, local_file, remote_file)

def download_file(ftp, remote_file_name, local_file_path=None):
    """تحميل ملف من السيرفر"""
    local_path = local_file_path or os.path.basename(remote_file_name)
    print(f"⬇️  جاري تحميل: {remote_file_name} -> {local_path} ...", end="", flush=True)
    try:
        with open(local_path, 'wb') as f:
            ftp.retrbinary(f'RETR {remote_file_name}', f.write)
        print(" ✅ تم بنجاح")
        return True
    except Exception as e:
        print(f" ❌ خطأ: {e}")
        return False

def list_files(ftp, sub_dir=""):
    """عرض قائمة الملفات الموجودة على السيرفر"""
    current = ftp.pwd()
    if sub_dir:
        try:
            ftp.cwd(sub_dir)
        except Exception as e:
            print(f"❌ تعذر فتح المجلد {sub_dir}: {e}")
            return
    
    print(f"\n📂 محتويات السيرفر في ({ftp.pwd()}):")
    print("-" * 50)
    lines = []
    ftp.dir(lines.append)
    for line in lines:
        print(line)
    print("-" * 50)
    ftp.cwd(current)

def sync_core_project(ftp):
    """مزامنة ملفات المشروع الأساسية والضرورية لتشغيل النظام"""
    print("\n🚀 بدء مزامنة ملفات النظام الأساسية مع السيرفر:")
    print("=" * 50)

    # 1. الملفات المفردة الأساسية
    core_files = [
        'app.py',
        'database.db',
        'passenger_wsgi.py',
        '.htaccess',
        'requirements-server.txt',
        'requirements.txt',
        'simple_run.py',
    ]

    for filename in core_files:
        if os.path.exists(filename):
            upload_file(ftp, filename)

    # 2. مجلدات القوالب والملفات الثابتة
    if os.path.exists('templates'):
        print("\n📁 مزامنة مجلد القوالب (templates)...")
        upload_directory(ftp, 'templates', 'templates')

    if os.path.exists('static'):
        print("\n📁 مزامنة المجلد الثابت والمرفوعات (static)...")
        upload_directory(ftp, 'static', 'static')

    print("\n✅ اكتملت مزامنة جميع ملفات النظام بنجاح!")

def main():
    parser = argparse.ArgumentParser(description="أداة التواصل ومزامنة الملفات مع السيرفر")
    subparsers = parser.add_subparsers(dest="command")

    # أمر الفحص والاتصال
    subparsers.add_parser("check", help="فحص الاتصال بالسيرفر والمسار")

    # أمر المزامنة الشاملة
    subparsers.add_parser("sync", help="مزامنة ملفات المشروع وقاعدة البيانات والقوالب بالكامل")

    # أمر رفع ملف أو مجلد
    upload_parser = subparsers.add_parser("upload", help="رفع ملف أو مجلد محدد إلى السيرفر")
    upload_parser.add_argument("path", help="مسار الملف أو المجلد المحلي")
    upload_parser.add_argument("--remote", "-r", help="الاسم أو المسار البعيد (اختياري)", default=None)

    # أمر تحميل ملف
    download_parser = subparsers.add_parser("download", help="تحميل ملف محدد من السيرفر")
    download_parser.add_argument("remote_file", help="اسم الملف على السيرفر")
    download_parser.add_argument("--local", "-l", help="المسار المحلي للحفظ (اختياري)", default=None)

    # أمر عرض الملفات
    list_parser = subparsers.add_parser("list", help="عرض الملفات على السيرفر")
    list_parser.add_argument("dir", nargs="?", default="", help="مجلد فرعي (اختياري)")

    args = parser.parse_args()

    if not args.command:
        # الوضع الافتراضي عند تشغيل الملف مباشرة بدون باراميترات هو المزامنة
        print("📡 جاري الاتصال بالسيرفر لبدء المزامنة التلقائية...")
        ftp = get_ftp_connection()
        sync_core_project(ftp)
        ftp.quit()
        return

    ftp = get_ftp_connection()

    if args.command == "check":
        print(f"✅ تم الاتصال بنجاح!")
        print(f"📍 المسار الحالي على السيرفر: {ftp.pwd()}")
        print(f"📊 عدد الملفات في المجلد: {len(ftp.nlst())}")

    elif args.command == "sync":
        sync_core_project(ftp)

    elif args.command == "upload":
        if os.path.isdir(args.path):
            upload_directory(ftp, args.path, args.remote or os.path.basename(args.path.rstrip('/\\')))
        else:
            upload_file(ftp, args.path, args.remote)

    elif args.command == "download":
        download_file(ftp, args.remote_file, args.local)

    elif args.command == "list":
        list_files(ftp, args.dir)

    ftp.quit()

if __name__ == '__main__':
    main()
