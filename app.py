from flask import Flask, render_template, request, redirect, url_for, session, jsonify, send_file
from werkzeug.utils import secure_filename
import sqlite3
import os
import json
from datetime import datetime, timedelta
import re
from bs4 import BeautifulSoup
import calendar
import urllib.parse

from whats360_service import Whats360Service
import config
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import atexit

class AdminApp:
    def __init__(self):
        self.app = Flask(__name__)
        self.app.secret_key = config.SECRET_KEY
        self.app.config['TEMPLATES_AUTO_RELOAD'] = True
        self.admin_username = config.ADMIN_USERNAME
        self.admin_password = config.ADMIN_PASSWORD
        
        # Whats360 Configuration
        self.whats360_service = Whats360Service(config.WHATS360_CLIENT_ID, config.WHATS360_API_KEY)
        
        # Scheduler Configuration
        self.scheduler = BackgroundScheduler()
        self.scheduler_running = False
        
        self.app.config['UPLOAD_FOLDER'] = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static', 'uploads')
        self.app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
        if not os.path.exists(self.app.config['UPLOAD_FOLDER']):
            os.makedirs(self.app.config['UPLOAD_FOLDER'])

        # Register custom Jinja filter for WhatsApp URL
        def format_whatsapp_url(phone, message="مرحباً، نود التواصل معكم بخصوص عقد الإيجار"):
            if not phone:
                return "#"
            clean = ''.join(filter(str.isdigit, str(phone)))
            if clean.startswith('0'):
                clean = clean[1:]
                if clean.startswith('1') and len(clean) == 10:
                    clean = '20' + clean
                elif len(clean) == 9:
                    clean = '966' + clean
                else:
                    clean = '20' + clean
            elif clean.startswith('20') or clean.startswith('966'):
                pass
            elif len(clean) == 10 and clean.startswith('1'):
                clean = '20' + clean
            text_param = f"&text={urllib.parse.quote(message)}" if message else ""
            return f"https://api.whatsapp.com/send?phone={clean}{text_param}"

        self.app.jinja_env.filters['whatsapp_url'] = format_whatsapp_url
        self.format_whatsapp_url = format_whatsapp_url

        self.init_db()
        self.setup_routes()
        
        # Start the notification scheduler
        self.start_scheduler()
    
    def init_db(self):
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tenants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tenant_name TEXT NOT NULL,
                tenant_phone TEXT,
                start_date TEXT,
                end_date TEXT,
                page_one_content TEXT NOT NULL,
                page_two_content TEXT NOT NULL,
                id_image TEXT,
                contract_image TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS settings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                days_before_month_end TEXT DEFAULT '5,4,3,2,1',
                days_before_contract_end INTEGER DEFAULT 30,
                monthly_message TEXT DEFAULT 'مرحبًا {{name}}، نذكّرك بقرب نهاية الشهر. يرجى سداد الإيجار.',
                contract_end_message TEXT DEFAULT 'عقدك سينتهي في {{end_date}}، تواصل معنا للتجديد.',
                send_hour INTEGER DEFAULT 3,
                send_minute INTEGER DEFAULT 30,
                send_period TEXT DEFAULT 'مساءً'
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS notifications_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tenant_id INTEGER,
                tenant_name TEXT,
                notification_type TEXT,
                status TEXT,
                sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (tenant_id) REFERENCES tenants (id)
            )
        ''')
        
        # Check if new columns exist, if not add them
        cursor.execute("PRAGMA table_info(tenants)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'tenant_phone' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN tenant_phone TEXT')
        if 'start_date' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN start_date TEXT')
        if 'end_date' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN end_date TEXT')
        
        # Check if new columns exist in settings, if not add them
        cursor.execute("PRAGMA table_info(settings)")
        settings_columns = [column[1] for column in cursor.fetchall()]
        
        if 'send_hour' not in settings_columns:
            cursor.execute('ALTER TABLE settings ADD COLUMN send_hour INTEGER DEFAULT 3')
        if 'send_minute' not in settings_columns:
            cursor.execute('ALTER TABLE settings ADD COLUMN send_minute INTEGER DEFAULT 30')
        if 'send_period' not in settings_columns:
            cursor.execute('ALTER TABLE settings ADD COLUMN send_period TEXT DEFAULT "مساءً"')
        
        # Add new contract fields
        if 'contract_type' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN contract_type TEXT')
        if 'payment_count' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN payment_count INTEGER')
        if 'check_images' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN check_images TEXT')
        if 'has_commitment' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN has_commitment TEXT')
        if 'maintenance_responsibility' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN maintenance_responsibility TEXT')
        if 'notes' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN notes TEXT')
        if 'commercial_license_number' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN commercial_license_number TEXT')
        if 'commercial_license_image' not in columns:
            cursor.execute('ALTER TABLE tenants ADD COLUMN commercial_license_image TEXT')
        
        # إنشاء جدول قوالب الرسائل
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS message_templates (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                template_name TEXT NOT NULL,
                template_type TEXT NOT NULL,
                template_content TEXT NOT NULL,
                is_active INTEGER DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # إنشاء جدول الرسائل المجدولة
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS scheduled_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tenant_id INTEGER,
                message_type TEXT NOT NULL,
                message_content TEXT NOT NULL,
                scheduled_date TEXT NOT NULL,
                scheduled_time TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                sent_at TIMESTAMP,
                FOREIGN KEY (tenant_id) REFERENCES tenants (id)
            )
        ''')
        
        # إنشاء جدول الرسائل الجماعية
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS bulk_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                campaign_name TEXT NOT NULL,
                message_content TEXT NOT NULL,
                target_group TEXT NOT NULL,
                total_recipients INTEGER DEFAULT 0,
                sent_count INTEGER DEFAULT 0,
                failed_count INTEGER DEFAULT 0,
                status TEXT DEFAULT 'draft',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                sent_at TIMESTAMP
            )
        ''')
        
        # إنشاء جدول تفاصيل الرسائل الجماعية
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS bulk_message_details (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                bulk_message_id INTEGER,
                tenant_id INTEGER,
                tenant_name TEXT,
                tenant_phone TEXT,
                status TEXT DEFAULT 'pending',
                sent_at TIMESTAMP,
                error_message TEXT,
                FOREIGN KEY (bulk_message_id) REFERENCES bulk_messages (id),
                FOREIGN KEY (tenant_id) REFERENCES tenants (id)
            )
        ''')
        
        # تحديث جدول سجل الإشعارات لإضافة معلومات إضافية
        cursor.execute("PRAGMA table_info(notifications_log)")
        notification_columns = [column[1] for column in cursor.fetchall()]
        
        if 'message_content' not in notification_columns:
            cursor.execute('ALTER TABLE notifications_log ADD COLUMN message_content TEXT')
        if 'phone_number' not in notification_columns:
            cursor.execute('ALTER TABLE notifications_log ADD COLUMN phone_number TEXT')
        if 'error_details' not in notification_columns:
            cursor.execute('ALTER TABLE notifications_log ADD COLUMN error_details TEXT')
        if 'whatsapp_url' not in notification_columns:
            cursor.execute('ALTER TABLE notifications_log ADD COLUMN whatsapp_url TEXT')
        
        # إدراج قوالب الرسائل الافتراضية
        cursor.execute('SELECT COUNT(*) FROM message_templates')
        if cursor.fetchone()[0] == 0:
            from config import (DEFAULT_RENTAL_REMINDER, DEFAULT_CONTRACT_EXPIRY, 
                              DEFAULT_WELCOME_MESSAGE, DEFAULT_PAYMENT_CONFIRMATION,
                              DEFAULT_MAINTENANCE_REQUEST, DEFAULT_CUSTOM_MESSAGE)
            
            templates = [
                ('تذكير الإيجار الافتراضي', 'rental_reminder', DEFAULT_RENTAL_REMINDER),
                ('انتهاء العقد الافتراضي', 'contract_expiry', DEFAULT_CONTRACT_EXPIRY),
                ('رسالة الترحيب الافتراضية', 'welcome', DEFAULT_WELCOME_MESSAGE),
                ('تأكيد الدفع الافتراضي', 'payment_confirmation', DEFAULT_PAYMENT_CONFIRMATION),
                ('طلب الصيانة الافتراضي', 'maintenance_request', DEFAULT_MAINTENANCE_REQUEST),
                ('الرسالة المخصصة الافتراضية', 'custom', DEFAULT_CUSTOM_MESSAGE)
            ]
            
            for template_name, template_type, template_content in templates:
                cursor.execute('''
                    INSERT INTO message_templates (template_name, template_type, template_content)
                    VALUES (?, ?, ?)
                ''', (template_name, template_type, template_content))
        
        # Initialize settings if empty
        cursor.execute('SELECT COUNT(*) FROM settings')
        if cursor.fetchone()[0] == 0:
            cursor.execute('INSERT INTO settings DEFAULT VALUES')
            
        # Create admin_profile table if not exists
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS admin_profile (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                password TEXT NOT NULL,
                full_name TEXT DEFAULT 'مدير النظام',
                email TEXT DEFAULT 'admin@mostager.com',
                avatar TEXT DEFAULT 'avatar.png',
                phone TEXT DEFAULT '',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('SELECT COUNT(*) FROM admin_profile')
        if cursor.fetchone()[0] == 0:
            cursor.execute('''
                INSERT INTO admin_profile (username, password, full_name, email, avatar, phone)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (config.ADMIN_USERNAME, config.ADMIN_PASSWORD, 'مدير النظام', 'admin@mostager.com', 'avatar.png', '01009931190'))

        conn.commit()
        conn.close()
    
    def get_admin_profile(self):
        try:
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT id, username, password, full_name, email, avatar, phone FROM admin_profile LIMIT 1')
            row = cursor.fetchone()
            conn.close()
            if row:
                return {
                    'id': row[0],
                    'username': row[1],
                    'password': row[2],
                    'full_name': row[3] or 'مدير النظام',
                    'email': row[4] or 'admin@mostager.com',
                    'avatar': row[5] or 'avatar.png',
                    'phone': row[6] or ''
                }
        except Exception as e:
            print(f"Error fetching admin profile: {e}")
        return {
            'id': 1,
            'username': config.ADMIN_USERNAME,
            'password': config.ADMIN_PASSWORD,
            'full_name': 'مدير النظام',
            'email': 'admin@mostager.com',
            'avatar': 'avatar.png',
            'phone': '01009931190'
        }
    
    def clean_phone_number(self, phone):
        """Clean and format phone number for WhatsApp"""
        if not phone:
            return phone
        
        # Remove all non-digit characters
        clean = ''.join(filter(str.isdigit, phone))
        print(f"[DEBUG] Original phone: {phone}, Cleaned digits: {clean}")
        
        # Handle Egyptian numbers
        if clean.startswith('0'):
            # Remove leading 0
            clean = clean[1:]
            print(f"[DEBUG] After removing leading 0: {clean}")
            
            # Check if it's Egyptian number (starts with 1 after removing 0)
            if clean.startswith('1') and len(clean) == 10:
                clean = '20' + clean  # Egypt country code
                print(f"[DEBUG] Egyptian number detected: {clean}")
            # Check if it's Saudi number (9 digits after removing 0)
            elif len(clean) == 9:
                clean = '966' + clean  # Saudi Arabia country code
                print(f"[DEBUG] Saudi number detected: {clean}")
            else:
                # Default to Egypt for other patterns
                clean = '20' + clean
                print(f"[DEBUG] Default to Egypt: {clean}")
        
        # If already has country code, keep as is
        elif clean.startswith('20') or clean.startswith('966'):
            print(f"[DEBUG] Already has country code: {clean}")
            pass
        
        # If it's 10 digits starting with 1, assume Egyptian
        elif clean.startswith('1') and len(clean) == 10:
            clean = '20' + clean
            print(f"[DEBUG] 10-digit Egyptian: {clean}")
        
        # If it's 9 digits, assume Saudi
        elif len(clean) == 9:
            clean = '966' + clean
            print(f"[DEBUG] 9-digit Saudi: {clean}")
        
        # If it's 11 digits starting with 1, assume Egyptian without country code
        elif clean.startswith('1') and len(clean) == 11:
            clean = '20' + clean
            print(f"[DEBUG] 11-digit Egyptian: {clean}")
        
        print(f"[DEBUG] Phone number cleaned: {phone} -> {clean}")
        return clean
    
    def extract_tenant_data(self, page_one_content):
        """Extract tenant data from HTML content"""
        soup = BeautifulSoup(page_one_content, 'html.parser')
        
        # Extract tenant name
        tenant_name = ""
        tenant_name_field = soup.find(id='tenant_name_field')
        if tenant_name_field:
            tenant_name = tenant_name_field.get_text(strip=True)
        
        # Extract phone number and dates
        tenant_phone = ""
        start_date = ""
        end_date = ""
        
        # Find all contenteditable cells
        editable_cells = soup.find_all('td', {'contenteditable': 'true'})
        
        # Look for patterns in the content
        for i, cell in enumerate(editable_cells):
            cell_text = cell.get_text(strip=True)
            
            # Skip empty cells
            if not cell_text:
                continue
            
            # Find the label cell (usually the previous cell)
            parent_row = cell.find_parent('tr')
            if parent_row:
                all_cells = parent_row.find_all('td')
                cell_index = all_cells.index(cell)
                
                # Check previous cells for labels
                for j in range(cell_index):
                    label_text = all_cells[j].get_text(strip=True)
                    
                    # Extract phone number
                    if 'MOBILE' in label_text and not tenant_phone:
                        # Check if this looks like a phone number
                        if re.match(r'^[\d\+\-\s\(\)]+$', cell_text) and len(cell_text) >= 7:
                            # Make sure it's in tenant section, not lessor section
                            section_header = cell.find_previous('div', class_='section-header')
                            if section_header and 'TENANT' in section_header.get_text():
                                tenant_phone = cell_text
                    
                    # Extract start date
                    elif 'START DATE' in label_text and not start_date:
                        start_date = cell_text
                    
                    # Extract end date
                    elif 'END DATE' in label_text and not end_date:
                        end_date = cell_text
        
        return tenant_name, tenant_phone, start_date, end_date
    
    def convert_12_to_24_hour(self, hour_12, period):
        """Convert 12-hour format to 24-hour format"""
        if period == "صباحاً":
            if hour_12 == 12:
                return 0
            else:
                return hour_12
        else:  # مساءً
            if hour_12 == 12:
                return 12
            else:
                return hour_12 + 12
    
    def get_tenants_for_monthly_notification(self, days_before_str):
        # للاختبار: إرجاع جميع المستأجرين الذين لديهم أرقام هواتف
        # في الإنتاج الفعلي، يجب استخدام المنطق الأصلي للتواريخ
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('SELECT id, tenant_name, tenant_phone FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != ""')
        tenants = cursor.fetchall()
        conn.close()
        return tenants  # إرجاع جميع المستأجرين لأغراض الاختبار
    
    def get_tenants_for_contract_notification(self, days_before):
        today = datetime.now()
        
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, tenant_name, tenant_phone, end_date 
            FROM tenants 
            WHERE tenant_phone IS NOT NULL AND tenant_phone != "" AND end_date IS NOT NULL AND end_date != ""
        ''')
        tenants = cursor.fetchall()
        conn.close()
        
        eligible_tenants = []
        for tenant in tenants:
            try:
                end_date = datetime.strptime(tenant[3], '%d/%m/%Y')
                days_until_end = (end_date - today).days
                # إرسال إشعار للمستأجرين الذين ينتهي عقدهم خلال المدة المحددة أو أقل
                if days_until_end <= days_before:
                    eligible_tenants.append(tenant)
            except:
                continue
        
        return eligible_tenants
    
    def was_notification_sent_today(self, tenant_id, notification_type):
        """Check if notification was already sent today for this tenant"""
        today = datetime.now().strftime('%Y-%m-%d')
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('''
            SELECT COUNT(*) FROM notifications_log 
            WHERE tenant_id = ? AND notification_type = ? AND DATE(sent_at) = ?
        ''', (tenant_id, notification_type, today))
        count = cursor.fetchone()[0]
        conn.close()
        return count > 0
    
    def check_and_send_notifications(self):
        """
        Check and send automatic notifications based on settings
        """
        try:
            print(f"[{datetime.now()}] Checking for notifications to send...")
            
            # Get settings from database
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM settings LIMIT 1')
            settings = cursor.fetchone()
            conn.close()
            
            if not settings:
                print("No settings found, skipping notification check")
                return
            
            days_before_month_end = settings[1]  # "5,4,3,2,1"
            days_before_contract_end = settings[2]  # 30
            monthly_message = settings[3]
            contract_end_message = settings[4]
            
            # Check for monthly notifications
            monthly_tenants = self.get_tenants_for_monthly_notification(days_before_month_end)
            if monthly_tenants:
                print(f"Found {len(monthly_tenants)} tenants for monthly notifications")
                for tenant in monthly_tenants:
                    # Check if notification was already sent today
                    if self.was_notification_sent_today(tenant[0], 'تذكير شهري تلقائي'):
                        print(f"Monthly notification already sent today to {tenant[1]}, skipping...")
                        continue
                    
                    message = monthly_message.replace('{{name}}', tenant[1])
                    status = self.send_notification(tenant[2], message, "rental_reminder", tenant[1])
                    self.log_notification(tenant[0], tenant[1], 'تذكير شهري تلقائي', status)
                    print(f"Sent monthly notification to {tenant[1]}: {status}")
            
            # Check for contract end notifications
            contract_tenants = self.get_tenants_for_contract_notification(days_before_contract_end)
            if contract_tenants:
                print(f"Found {len(contract_tenants)} tenants for contract end notifications")
                for tenant in contract_tenants:
                    # Check if notification was already sent today
                    if self.was_notification_sent_today(tenant[0], 'انتهاء عقد تلقائي'):
                        print(f"Notification already sent today to {tenant[1]}, skipping...")
                        continue
                    
                    message = contract_end_message.replace('{{name}}', tenant[1]).replace('{{end_date}}', tenant[3])
                    status = self.send_notification(tenant[2], message, "contract_expiry", tenant[1])
                    self.log_notification(tenant[0], tenant[1], 'انتهاء عقد تلقائي', status)
                    print(f"Sent contract end notification to {tenant[1]}: {status}")
            
            if not monthly_tenants and not contract_tenants:
                print("No notifications to send at this time")
                
        except Exception as e:
            print(f"Error in check_and_send_notifications: {str(e)}")
    
    def start_scheduler(self):
        """Start the notification scheduler"""
        try:
            if self.scheduler_running:
                return
            
            # Get current settings for schedule time
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT send_hour, send_minute, send_period FROM settings LIMIT 1')
            time_settings = cursor.fetchone()
            conn.close()
            
            if time_settings:
                hour_12 = time_settings[0] if time_settings[0] is not None else 3
                minute = time_settings[1] if time_settings[1] is not None else 30
                period = time_settings[2] if time_settings[2] is not None else "مساءً"
                hour = self.convert_12_to_24_hour(hour_12, period)
            else:
                hour, minute = 15, 30
            
            # Clear any existing jobs
            self.scheduler.remove_all_jobs()
            
            # Add the notification check job
            self.scheduler.add_job(
                func=self.check_and_send_notifications,
                trigger=CronTrigger(hour=hour, minute=minute),
                id='notification_check',
                name='Daily Notification Check',
                replace_existing=True
            )
            
            if not self.scheduler.running:
                self.scheduler.start()
                atexit.register(lambda: self.scheduler.shutdown())
            
            self.scheduler_running = True
            # Convert back to 12-hour format for display
            if hour == 0:
                display_hour = 12
                display_period = "صباحاً"
            elif hour < 12:
                display_hour = hour
                display_period = "صباحاً"
            elif hour == 12:
                display_hour = 12
                display_period = "مساءً"
            else:
                display_hour = hour - 12
                display_period = "مساءً"
            
            print(f"Scheduler started - notifications will be sent daily at {display_hour}:{minute:02d} {display_period} ({hour:02d}:{minute:02d})")
            
        except Exception as e:
            print(f"Error starting scheduler: {str(e)}")
    
    def update_scheduler_time(self, hour_12, minute, period):
        """Update scheduler time"""
        try:
            if self.scheduler_running:
                # Convert to 24-hour format
                hour_24 = self.convert_12_to_24_hour(hour_12, period)
                
                # Remove existing job
                self.scheduler.remove_job('notification_check')
                
                # Add new job with updated time
                self.scheduler.add_job(
                    func=self.check_and_send_notifications,
                    trigger=CronTrigger(hour=hour_24, minute=minute),
                    id='notification_check',
                    name='Daily Notification Check',
                    replace_existing=True
                )
                
                print(f"Scheduler time updated to {hour_12}:{minute:02d} {period} ({hour_24:02d}:{minute:02d})")
        except Exception as e:
            print(f"Error updating scheduler time: {str(e)}")
    
    def send_notification(self, phone, message, notification_type="general", tenant_name=""):
        """
        Send notification using Whats360 service
        
        Args:
            phone (str): Phone number
            message (str): Message text
            notification_type (str): Type of notification (rental_reminder, contract_expiry, welcome, general)
            tenant_name (str): Tenant name for personalized messages
            
        Returns:
            str: Status of the operation ("نجح" or "فشل")
        """
        try:
            # استخدام الرقم كما هو مخزن في قاعدة البيانات (01xxxxxxxxx)
            print(f"[DEBUG] Sending notification to {phone}, type: {notification_type}")
            
            if notification_type == "welcome":
                result = self.whats360_service.send_welcome_message(phone, tenant_name)
            else:
                # استخدام الطريقة البديلة المحسنة مع الرقم الأصلي
                result = self.whats360_service.send_text_message_alternative(phone, message)
            
            if result.get('success'):
                print(f"[DEBUG] Notification sent successfully to {phone}")
                return "نجح"
            else:
                error_msg = result.get('error', 'Unknown error')
                print(f"[ERROR] Whats360 Error: {error_msg}")
                
                # طباعة تفاصيل إضافية للتشخيص
                if result.get('details'):
                    print(f"[DEBUG] Error details: {result['details']}")
                if result.get('diagnosis'):
                    print(f"[DEBUG] Diagnosis: {result['diagnosis']}")
                
                # تحقق من نوع الخطأ لإعطاء رسالة أكثر وضوحاً
                if 'credit' in error_msg.lower() or 'dont have credits' in error_msg.lower():
                    print(f"[WARNING] Insufficient credits for sending message to {phone}")
                    return "فشل - رصيد غير كافي (تحقق من الرصيد في الإعدادات)"
                elif 'invalid' in error_msg.lower():
                    return "فشل - بيانات API غير صحيحة"
                elif 'phone' in error_msg.lower() or 'mobile' in error_msg.lower():
                    return f"فشل - رقم الهاتف غير صحيح ({phone})"
                else:
                    return f"فشل - {error_msg}"
                
        except Exception as e:
            print(f"[ERROR] Exception in send_notification: {str(e)}")
            return "فشل"
    
    def log_notification(self, tenant_id, tenant_name, notification_type, status, whatsapp_url=None, message_content=None, phone_number=None, error_details=None):
        """
        تسجيل تفاصيل الإشعار في قاعدة البيانات
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO notifications_log 
            (tenant_id, tenant_name, notification_type, status, whatsapp_url, message_content, phone_number, error_details)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (tenant_id, tenant_name, notification_type, status, whatsapp_url, message_content, phone_number, error_details))
        conn.commit()
        conn.close()
    

    
    def get_message_templates(self, template_type=None):
        """
        الحصول على قوالب الرسائل
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        if template_type:
            cursor.execute('SELECT * FROM message_templates WHERE template_type = ? AND is_active = 1', (template_type,))
        else:
            cursor.execute('SELECT * FROM message_templates WHERE is_active = 1')
        
        templates = cursor.fetchall()
        conn.close()
        return templates
    
    def save_message_template(self, template_name, template_type, template_content, template_id=None):
        """
        حفظ أو تحديث قالب رسالة
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        if template_id:
            cursor.execute('''
                UPDATE message_templates 
                SET template_name = ?, template_type = ?, template_content = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ''', (template_name, template_type, template_content, template_id))
        else:
            cursor.execute('''
                INSERT INTO message_templates (template_name, template_type, template_content)
                VALUES (?, ?, ?)
            ''', (template_name, template_type, template_content))
        
        conn.commit()
        conn.close()
    

    
    def schedule_message(self, tenant_id, message_type, message_content, scheduled_date, scheduled_time):
        """
        جدولة رسالة للإرسال لاحقاً
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO scheduled_messages (tenant_id, message_type, message_content, scheduled_date, scheduled_time)
            VALUES (?, ?, ?, ?, ?)
        ''', (tenant_id, message_type, message_content, scheduled_date, scheduled_time))
        conn.commit()
        conn.close()
    

    
    def get_scheduled_messages(self, status='pending'):
        """
        الحصول على الرسائل المجدولة
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        cursor.execute('''
            SELECT sm.*, t.tenant_name, t.tenant_phone 
            FROM scheduled_messages sm
            LEFT JOIN tenants t ON sm.tenant_id = t.id
            WHERE sm.status = ?
            ORDER BY sm.scheduled_date, sm.scheduled_time
        ''', (status,))
        messages = cursor.fetchall()
        conn.close()
        return messages
    
    def process_scheduled_messages(self):
        """
        معالجة الرسائل المجدولة المستحقة للإرسال
        """
        from datetime import datetime
        current_date = datetime.now().strftime('%Y-%m-%d')
        current_time = datetime.now().strftime('%H:%M')
        
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        # البحث عن الرسائل المستحقة للإرسال
        cursor.execute('''
            SELECT sm.*, t.tenant_name, t.tenant_phone 
            FROM scheduled_messages sm
            LEFT JOIN tenants t ON sm.tenant_id = t.id
            WHERE sm.status = 'pending' 
            AND sm.scheduled_date <= ? 
            AND sm.scheduled_time <= ?
        ''', (current_date, current_time))
        
        due_messages = cursor.fetchall()
        
        for message in due_messages:
            message_id, tenant_id, message_type, message_content, scheduled_date, scheduled_time, status, created_at, sent_at, tenant_name, tenant_phone = message
            
            if tenant_phone:
                # إرسال الرسالة
                send_status = self.send_notification(tenant_phone, message_content, message_type, tenant_name)
                
                # تحديث حالة الرسالة المجدولة
                cursor.execute('''
                    UPDATE scheduled_messages 
                    SET status = ?, sent_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', ('sent' if send_status == 'نجح' else 'failed', message_id))
                
                # تسجيل في سجل الإشعارات
                self.log_notification(
                    tenant_id, tenant_name, f'مجدولة - {message_type}', 
                    send_status, None, message_content, tenant_phone
                )
        
        conn.commit()
        conn.close()
    

    
    def create_bulk_message(self, campaign_name, message_content, target_group):
        """
        إنشاء حملة رسائل جماعية
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        # إنشاء الحملة
        cursor.execute('''
            INSERT INTO bulk_messages (campaign_name, message_content, target_group)
            VALUES (?, ?, ?)
        ''', (campaign_name, message_content, target_group))
        
        bulk_message_id = cursor.lastrowid
        
        # تحديد المستأجرين المستهدفين
        if target_group == 'all':
            cursor.execute('SELECT id, tenant_name, tenant_phone FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != ""')
        elif target_group == 'active_contracts':
            cursor.execute('''
                SELECT id, tenant_name, tenant_phone FROM tenants 
                WHERE tenant_phone IS NOT NULL AND tenant_phone != "" 
                AND end_date IS NOT NULL AND end_date > date('now')
            ''')
        elif target_group == 'expiring_contracts':
            cursor.execute('''
                SELECT id, tenant_name, tenant_phone FROM tenants 
                WHERE tenant_phone IS NOT NULL AND tenant_phone != "" 
                AND end_date IS NOT NULL AND end_date BETWEEN date('now') AND date('now', '+30 days')
            ''')
        
        recipients = cursor.fetchall()
        
        # إضافة تفاصيل المستلمين
        for recipient in recipients:
            cursor.execute('''
                INSERT INTO bulk_message_details (bulk_message_id, tenant_id, tenant_name, tenant_phone)
                VALUES (?, ?, ?, ?)
            ''', (bulk_message_id, recipient[0], recipient[1], recipient[2]))
        
        # تحديث عدد المستلمين
        cursor.execute('''
            UPDATE bulk_messages SET total_recipients = ? WHERE id = ?
        ''', (len(recipients), bulk_message_id))
        
        conn.commit()
        conn.close()
    

        
        return bulk_message_id
    
    def send_bulk_message(self, bulk_message_id):
        """
        إرسال الرسائل الجماعية
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        # الحصول على تفاصيل الحملة
        cursor.execute('SELECT * FROM bulk_messages WHERE id = ?', (bulk_message_id,))
        campaign = cursor.fetchone()
        
        if not campaign:
            return False
        
        # الحصول على المستلمين
        cursor.execute('''
            SELECT * FROM bulk_message_details 
            WHERE bulk_message_id = ? AND status = 'pending'
        ''', (bulk_message_id,))
        
        recipients = cursor.fetchall()
        sent_count = 0
        failed_count = 0
        
        for recipient in recipients:
            detail_id, _, tenant_id, tenant_name, tenant_phone, status, sent_at, error_message = recipient
            
            # تخصيص الرسالة
            personalized_message = campaign[2].replace('{{name}}', tenant_name)
            
            # إرسال الرسالة
            send_status = self.send_notification(tenant_phone, personalized_message, 'bulk', tenant_name)
            
            if send_status == 'نجح':
                sent_count += 1
                cursor.execute('''
                    UPDATE bulk_message_details 
                    SET status = 'sent', sent_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (detail_id,))
            else:
                failed_count += 1
                cursor.execute('''
                    UPDATE bulk_message_details 
                    SET status = 'failed', error_message = ?
                    WHERE id = ?
                ''', (send_status, detail_id))
            
            # تسجيل في سجل الإشعارات
            self.log_notification(
                tenant_id, tenant_name, f'جماعية - {campaign[1]}', 
                send_status, None, personalized_message, tenant_phone
            )
        
        # تحديث إحصائيات الحملة
        cursor.execute('''
            UPDATE bulk_messages 
            SET sent_count = ?, failed_count = ?, status = 'completed', sent_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ''', (sent_count, failed_count, bulk_message_id))
        
        conn.commit()
        conn.close()
    

        
        return True
    
    def send_welcome_message_to_tenant(self, tenant_id):
        """
        إرسال رسالة ترحيب للمستأجر الجديد
        """
        conn = sqlite3.connect('database.db')
        cursor = conn.cursor()
        
        # الحصول على بيانات المستأجر
        cursor.execute('SELECT tenant_name, tenant_phone FROM tenants WHERE id = ?', (tenant_id,))
        tenant = cursor.fetchone()
        
        if tenant and tenant[1]:  # إذا كان لديه رقم هاتف
            # الحصول على قالب رسالة الترحيب
            cursor.execute('SELECT template_content FROM message_templates WHERE template_type = "welcome" AND is_active = 1 LIMIT 1')
            template = cursor.fetchone()
            
            if template:
                welcome_message = template[0].replace('{{name}}', tenant[0])
                status = self.send_notification(tenant[1], welcome_message, 'welcome', tenant[0])
                
                # تسجيل الإشعار
                self.log_notification(
                    tenant_id, tenant[0], 'ترحيب', status, 
                    None, welcome_message, tenant[1]
                )
                
                conn.close()
                return status == 'نجح'
        
        conn.close()
        return False
    
    def setup_routes(self):
        @self.app.route('/static/uploads/<path:filename>')
        def serve_uploads(filename):
            from flask import send_from_directory
            return send_from_directory(self.app.config['UPLOAD_FOLDER'], filename)

        @self.app.context_processor
        def inject_admin():
            admin = self.get_admin_profile()
            return dict(current_admin=admin)

        @self.app.route('/')
        def index():
            if 'logged_in' in session:
                return redirect(url_for('dashboard'))
            return redirect(url_for('login'))
        
        @self.app.route('/login', methods=['GET', 'POST'])
        def login():
            if request.method == 'POST':
                username = request.form.get('username', '').strip()
                password = request.form.get('password', '').strip()
                
                admin = self.get_admin_profile()
                if (username == admin['username'] and password == admin['password']) or \
                   (username == self.admin_username and password == self.admin_password):
                    session['logged_in'] = True
                    session['admin_user'] = username
                    return redirect(url_for('dashboard'))
                else:
                    return render_template('login.html', error='اسم المستخدم أو كلمة المرور غير صحيحة')
            
            return render_template('login.html')
        
        @self.app.route('/forgot-password', methods=['GET', 'POST'])
        def forgot_password():
            admin = self.get_admin_profile()
            if request.method == 'POST':
                username_or_email = request.form.get('username_or_email', '').strip()
                new_password = request.form.get('new_password', '').strip()
                confirm_password = request.form.get('confirm_password', '').strip()
                
                if not username_or_email:
                    return render_template('forgot_password.html', error='يرجى إدخال اسم المستخدم أو البريد الإلكتروني')
                
                if username_or_email.lower() != admin['username'].lower() and \
                   username_or_email.lower() != admin['email'].lower():
                    return render_template('forgot_password.html', error='البيانات المدخلة لا تتطابق مع سجلات مدير النظام')
                
                if not new_password or len(new_password) < 4:
                    return render_template('forgot_password.html', error='كلمة المرور الجديدة يجب ألا تقل عن 4 خانات', username_or_email=username_or_email)
                
                if new_password != confirm_password:
                    return render_template('forgot_password.html', error='كلمتا المرور غير متطابقتين', username_or_email=username_or_email)
                
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                cursor.execute('UPDATE admin_profile SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', 
                               (new_password, admin['id']))
                conn.commit()
                conn.close()
                
                self.admin_password = new_password
                
                return render_template('login.html', success='تم استعادة وتعيين كلمة المرور بنجاح! يمكنك تسجيل الدخول الآن بكلمة المرور الجديدة')
                
            return render_template('forgot_password.html')
        
        @self.app.route('/profile', methods=['GET', 'POST'])
        def profile():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            admin = self.get_admin_profile()
            success = None
            error = None
            
            if request.method == 'POST':
                full_name = request.form.get('full_name', '').strip() or admin['full_name']
                username = request.form.get('username', '').strip() or admin['username']
                email = request.form.get('email', '').strip() or admin['email']
                phone = request.form.get('phone', '').strip() or admin['phone']
                current_password = request.form.get('current_password', '').strip()
                new_password = request.form.get('new_password', '').strip()
                confirm_password = request.form.get('confirm_password', '').strip()
                
                avatar_filename = admin.get('avatar') or 'avatar.png'
                if 'avatar' in request.files:
                    avatar_file = request.files['avatar']
                    if avatar_file and avatar_file.filename and avatar_file.filename.strip():
                        ext = os.path.splitext(avatar_file.filename)[1].lower()
                        allowed_exts = ['.jpg', '.jpeg', '.png', '.webp', '.svg', '.gif', '.jfif']
                        if ext in allowed_exts:
                            clean_name = f"avatar_admin_{datetime.now().strftime('%Y%m%d%H%M%S')}{ext}"
                            upload_folder = self.app.config.get('UPLOAD_FOLDER', 'static/uploads')
                            os.makedirs(upload_folder, exist_ok=True)
                            upload_path = os.path.join(upload_folder, clean_name)
                            avatar_file.save(upload_path)
                            avatar_filename = clean_name
                        else:
                            error = 'صيغة ملف الصورة غير مدعومة. يرجى اختيار صورة (JPG, PNG, WebP, SVG)'
                
                # Password change is strictly optional:
                # ONLY validate password if user filled in new_password or confirm_password
                updated_password = admin['password']
                if not error and (new_password or confirm_password):
                    if not current_password:
                        error = 'يرجى إدخال كلمة المرور الحالية لتأكيد تغيير كلمة المرور'
                    elif current_password != admin['password']:
                        error = 'كلمة المرور الحالية غير صحيحة'
                    elif len(new_password) < 4:
                        error = 'كلمة المرور الجديدة يجب ألا تقل عن 4 خانات'
                    elif new_password != confirm_password:
                        error = 'تأكيد كلمة المرور الجديدة غير متطابق مع كلمة المرور'
                    else:
                        updated_password = new_password
                
                if not error:
                    conn = sqlite3.connect('database.db')
                    cursor = conn.cursor()
                    cursor.execute('''
                        UPDATE admin_profile 
                        SET full_name = ?, username = ?, email = ?, phone = ?, avatar = ?, password = ?, updated_at = CURRENT_TIMESTAMP
                        WHERE id = ?
                    ''', (full_name, username, email, phone, avatar_filename, updated_password, admin['id']))
                    conn.commit()
                    conn.close()
                    
                    self.admin_username = username
                    self.admin_password = updated_password
                    session['admin_user'] = username
                    
                    admin = self.get_admin_profile()
                    success = 'تم تحديث بيانات الملف الشخصي والصورة بنجاح!'
            
            return render_template('profile.html', admin=admin, success=success, error=error)
        
        @self.app.route('/dashboard')
        def dashboard():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            stats = {
                'total_tenants': 0,
                'notifications_count': 0,
                'templates_count': 0,
                'scheduled_count': 0,
                'recent_tenants': []
            }
            try:
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                cursor.execute('SELECT COUNT(*) FROM tenants')
                stats['total_tenants'] = cursor.fetchone()[0]
                
                try:
                    cursor.execute('SELECT COUNT(*) FROM notifications_log')
                    stats['notifications_count'] = cursor.fetchone()[0]
                except Exception:
                    pass

                try:
                    cursor.execute('SELECT COUNT(*) FROM message_templates')
                    stats['templates_count'] = cursor.fetchone()[0]
                except Exception:
                    pass

                try:
                    cursor.execute('SELECT COUNT(*) FROM scheduled_messages')
                    stats['scheduled_count'] = cursor.fetchone()[0]
                except Exception:
                    pass

                cursor.execute('SELECT id, tenant_name, tenant_phone, start_date, end_date, created_at FROM tenants ORDER BY id DESC LIMIT 5')
                stats['recent_tenants'] = cursor.fetchall()
                conn.close()
            except Exception as e:
                print(f"Dashboard stats error: {e}")
                
            return render_template('dashboard.html', stats=stats)
        
        @self.app.route('/add-tenant', methods=['GET', 'POST'])
        def add_tenant():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            copy_id = request.args.get('copy_id')
            tenant_data = None
            
            if copy_id:
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                cursor.execute('SELECT * FROM tenants WHERE id = ?', (copy_id,))
                tenant_data = cursor.fetchone()
                conn.close()
            
            if request.method == 'POST':
                page_one_content = request.form['page_one_content']
                page_two_content = request.form['page_two_content']
                tenant_name = request.form['tenant_name']
                
                # Extract additional data from HTML content
                extracted_name, tenant_phone, start_date, end_date = self.extract_tenant_data(page_one_content)
                
                # Use extracted name if tenant_name is empty
                if not tenant_name.strip():
                    tenant_name = extracted_name
                
                # Get new contract fields
                contract_type = request.form.get('contract_type', '')
                payment_count = request.form.get('payment_count', '')
                commercial_license_number = request.form.get('commercial_license_number', '')
                has_commitment = request.form.get('has_commitment', '')
                maintenance_responsibility = request.form.get('maintenance_responsibility', '')
                notes = request.form.get('notes', '')
                
                # Handle file uploads
                id_image = None
                contract_image = None
                commercial_license_image = None
                
                if 'id_image' in request.files:
                    file = request.files['id_image']
                    if file and file.filename != '':
                        filename = secure_filename(file.filename)
                        filename = f"id_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                        file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                        id_image = filename
                
                if 'contract_image' in request.files:
                    file = request.files['contract_image']
                    if file and file.filename != '':
                        filename = secure_filename(file.filename)
                        filename = f"contract_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                        file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                        contract_image = filename
                
                if 'commercial_license_image' in request.files:
                    file = request.files['commercial_license_image']
                    if file and file.filename != '':
                        filename = secure_filename(file.filename)
                        filename = f"license_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                        file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                        commercial_license_image = filename
                
                # Handle check images
                check_images = []
                for key in request.files:
                    if key.startswith('check_image_'):
                        file = request.files[key]
                        if file and file.filename != '':
                            filename = secure_filename(file.filename)
                            filename = f"check_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                            file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                            check_images.append(filename)
                
                check_images_str = ','.join(check_images) if check_images else None
                
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                cursor.execute('''
                    INSERT INTO tenants (tenant_name, tenant_phone, start_date, end_date, page_one_content, page_two_content, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images, has_commitment, maintenance_responsibility, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (tenant_name, tenant_phone, start_date, end_date, page_one_content, page_two_content, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images_str, has_commitment, maintenance_responsibility, notes))
                conn.commit()
                conn.close()
                
                return redirect(url_for('view_tenants'))
            
            return render_template('add_tenant.html', tenant_data=tenant_data)
        
        @self.app.route('/view-tenants')
        def view_tenants():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            # Get all tenants
            cursor.execute('SELECT id, tenant_name, tenant_phone, start_date, end_date, created_at, page_one_content, page_two_content, updated_at, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images, has_commitment, maintenance_responsibility, notes FROM tenants ORDER BY created_at DESC')
            tenants_raw = cursor.fetchall()
            
            # Update tenants that don't have extracted data
            tenants = []
            for tenant in tenants_raw:
                tenant_id, tenant_name, tenant_phone, start_date, end_date, created_at, page_one_content, page_two_content, updated_at, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images, has_commitment, maintenance_responsibility, notes = tenant
                
                # If any of the extracted fields are missing, extract them
                if not tenant_phone or not start_date or not end_date:
                    extracted_name, extracted_phone, extracted_start, extracted_end = self.extract_tenant_data(page_one_content)
                    
                    # Update the database with extracted data
                    cursor.execute('''
                        UPDATE tenants 
                        SET tenant_phone = ?, start_date = ?, end_date = ?
                        WHERE id = ?
                    ''', (extracted_phone or tenant_phone, 
                          extracted_start or start_date, 
                          extracted_end or end_date, 
                          tenant_id))
                    
                    # Use extracted data for display
                    tenant_phone = extracted_phone or tenant_phone
                    start_date = extracted_start or start_date
                    end_date = extracted_end or end_date
                
                tenants.append((tenant_id, tenant_name, tenant_phone, start_date, end_date, created_at, page_one_content, page_two_content, updated_at, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images, has_commitment, maintenance_responsibility, notes))
            
            conn.commit()
            conn.close()
            
            # Calculate notification status for each tenant
            tenants_with_notifications = []
            for tenant in tenants:
                tenant_id, tenant_name, tenant_phone, start_date, end_date, created_at, page_one_content, page_two_content, updated_at, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images, has_commitment, maintenance_responsibility, notes = tenant
                
                # Check for rental reminder (monthly)
                rental_reminder = False
                contract_expiry = False
                
                if start_date and end_date:
                    try:
                        from datetime import datetime, timedelta
                        start_dt = datetime.strptime(start_date, '%Y-%m-%d')
                        end_dt = datetime.strptime(end_date, '%Y-%m-%d')
                        today = datetime.now()
                        
                        # Always show rental reminder for testing
                        rental_reminder = True
                        
                        # Always show contract expiry for testing
                        contract_expiry = True
                            
                    except:
                        pass
                
                tenants_with_notifications.append((tenant_id, tenant_name, tenant_phone, start_date, end_date, created_at, page_one_content, page_two_content, updated_at, id_image, contract_image, rental_reminder, contract_expiry))
            
            return render_template('view_tenants.html', tenants=tenants_with_notifications)
        
        @self.app.route('/view-tenant/<int:tenant_id>')
        def view_tenant(tenant_id):
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM tenants WHERE id = ?', (tenant_id,))
            tenant = cursor.fetchone()
            conn.close()
            
            if not tenant:
                return redirect(url_for('view_tenants'))
            
            return render_template('view_tenant.html', tenant=tenant)
        
        @self.app.route('/edit-tenant/<int:tenant_id>', methods=['GET', 'POST'])
        def edit_tenant(tenant_id):
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            if request.method == 'POST':
                page_one_content = request.form['page_one_content']
                page_two_content = request.form['page_two_content']
                tenant_name = request.form['tenant_name']
                
                # Extract additional data from HTML content
                extracted_name, tenant_phone, start_date, end_date = self.extract_tenant_data(page_one_content)
                
                # Use extracted name if tenant_name is empty
                if not tenant_name.strip():
                    tenant_name = extracted_name
                
                # Get new contract fields
                contract_type = request.form.get('contract_type', '')
                payment_count = request.form.get('payment_count', '')
                commercial_license_number = request.form.get('commercial_license_number', '')
                has_commitment = request.form.get('has_commitment', '')
                maintenance_responsibility = request.form.get('maintenance_responsibility', '')
                notes = request.form.get('notes', '')
                
                # Get current images
                cursor.execute('SELECT id_image, contract_image, commercial_license_image, check_images FROM tenants WHERE id = ?', (tenant_id,))
                current_data = cursor.fetchone()
                id_image = current_data[0] if current_data else None
                contract_image = current_data[1] if current_data else None
                commercial_license_image = current_data[2] if current_data else None
                current_check_images = current_data[3] if current_data else None
                
                # Handle file uploads
                if 'id_image' in request.files:
                    file = request.files['id_image']
                    if file and file.filename != '':
                        # Delete old file if exists
                        if id_image and os.path.exists(os.path.join(self.app.config['UPLOAD_FOLDER'], id_image)):
                            os.remove(os.path.join(self.app.config['UPLOAD_FOLDER'], id_image))
                        
                        filename = secure_filename(file.filename)
                        filename = f"id_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                        file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                        id_image = filename
                
                if 'contract_image' in request.files:
                    file = request.files['contract_image']
                    if file and file.filename != '':
                        # Delete old file if exists
                        if contract_image and os.path.exists(os.path.join(self.app.config['UPLOAD_FOLDER'], contract_image)):
                            os.remove(os.path.join(self.app.config['UPLOAD_FOLDER'], contract_image))
                        
                        filename = secure_filename(file.filename)
                        filename = f"contract_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                        file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                        contract_image = filename
                
                if 'commercial_license_image' in request.files:
                    file = request.files['commercial_license_image']
                    if file and file.filename != '':
                        # Delete old file if exists
                        if commercial_license_image and os.path.exists(os.path.join(self.app.config['UPLOAD_FOLDER'], commercial_license_image)):
                            os.remove(os.path.join(self.app.config['UPLOAD_FOLDER'], commercial_license_image))
                        
                        filename = secure_filename(file.filename)
                        filename = f"license_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                        file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                        commercial_license_image = filename
                
                # Handle removed check images
                removed_images = request.form.get('removed_check_images', '').split(',')
                removed_images = [img.strip() for img in removed_images if img.strip()]
                
                # Handle check images
                check_images = []
                if current_check_images:
                    current_images = current_check_images.split(',')
                    # Keep only images that weren't removed
                    check_images = [img for img in current_images if img not in removed_images]
                    
                    # Delete removed image files
                    for removed_img in removed_images:
                        if removed_img in current_images:
                            file_path = os.path.join(self.app.config['UPLOAD_FOLDER'], removed_img)
                            if os.path.exists(file_path):
                                os.remove(file_path)
                
                for key in request.files:
                    if key.startswith('check_image_'):
                        file = request.files[key]
                        if file and file.filename != '':
                            filename = secure_filename(file.filename)
                            filename = f"check_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}"
                            file.save(os.path.join(self.app.config['UPLOAD_FOLDER'], filename))
                            check_images.append(filename)
                
                check_images_str = ','.join(check_images) if check_images else None
                
                cursor.execute('''
                    UPDATE tenants 
                    SET tenant_name = ?, tenant_phone = ?, start_date = ?, end_date = ?, 
                        page_one_content = ?, page_two_content = ?, id_image = ?, contract_image = ?, 
                        contract_type = ?, payment_count = ?, commercial_license_number = ?, commercial_license_image = ?, 
                        check_images = ?, has_commitment = ?, maintenance_responsibility = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (tenant_name, tenant_phone, start_date, end_date, page_one_content, page_two_content, id_image, contract_image, contract_type, payment_count, commercial_license_number, commercial_license_image, check_images_str, has_commitment, maintenance_responsibility, notes, tenant_id))
                conn.commit()
                conn.close()
                
                return redirect(url_for('view_tenants'))
            
            cursor.execute('SELECT * FROM tenants WHERE id = ?', (tenant_id,))
            tenant = cursor.fetchone()
            conn.close()
            
            if not tenant:
                return redirect(url_for('view_tenants'))
            
            return render_template('edit_tenant.html', tenant=tenant)
        
        @self.app.route('/delete-tenant/<int:tenant_id>')
        def delete_tenant(tenant_id):
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('DELETE FROM tenants WHERE id = ?', (tenant_id,))
            conn.commit()
            conn.close()
            
            return redirect(url_for('view_tenants'))
        
        @self.app.route('/delete-check-image/<int:tenant_id>/<image_name>')
        def delete_check_image(tenant_id, image_name):
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT check_images FROM tenants WHERE id = ?', (tenant_id,))
            result = cursor.fetchone()
            
            if result and result[0]:
                check_images = result[0].split(',')
                if image_name in check_images:
                    check_images.remove(image_name)
                    new_check_images = ','.join(check_images) if check_images else None
                    cursor.execute('UPDATE tenants SET check_images = ? WHERE id = ?', (new_check_images, tenant_id))
                    
                    import os
                    file_path = os.path.join(self.app.config['UPLOAD_FOLDER'], image_name)
                    if os.path.exists(file_path):
                        os.remove(file_path)
            
            conn.commit()
            conn.close()
            return redirect(url_for('edit_tenant', tenant_id=tenant_id))
        
        @self.app.route('/update-tenant-data/<int:tenant_id>')
        def update_tenant_data(tenant_id):
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            # Get tenant data
            cursor.execute('SELECT page_one_content FROM tenants WHERE id = ?', (tenant_id,))
            result = cursor.fetchone()
            
            if result:
                page_one_content = result[0]
                extracted_name, extracted_phone, extracted_start, extracted_end = self.extract_tenant_data(page_one_content)
                
                # Update the database
                cursor.execute('''
                    UPDATE tenants 
                    SET tenant_phone = ?, start_date = ?, end_date = ?
                    WHERE id = ?
                ''', (extracted_phone, extracted_start, extracted_end, tenant_id))
                
                conn.commit()
            
            conn.close()
            return redirect(url_for('view_tenants'))
        
        @self.app.route('/settings')
        def settings():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM settings LIMIT 1')
            settings = cursor.fetchone()
            conn.close()
            
            saved = request.args.get('saved')
            
            return render_template('settings.html', 
                                 settings=settings,
                                 whats360_client_id=config.WHATS360_CLIENT_ID,
                                 whats360_api_key=config.WHATS360_API_KEY,
                                 saved=saved)
        
        @self.app.route('/settings', methods=['POST'])
        def update_settings():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            days_before_month_end = request.form['days_before_month_end']
            days_before_contract_end = request.form['days_before_contract_end']
            monthly_message = request.form['monthly_message']
            contract_end_message = request.form['contract_end_message']
            send_hour = request.form['send_hour']
            send_minute = request.form['send_minute']
            send_period = request.form['send_period']
            
            # Update Whats360 settings if provided
            whats360_client_id = request.form.get('whats360_client_id')
            whats360_api_key = request.form.get('whats360_api_key')
            
            if whats360_client_id and whats360_api_key:
                try:
                    with open('config.py', 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Replace the values
                    content = re.sub(r"WHATS360_CLIENT_ID = '[^']*'", f"WHATS360_CLIENT_ID = '{whats360_client_id}'", content)
                    content = re.sub(r"WHATS360_API_KEY = '[^']*'", f"WHATS360_API_KEY = '{whats360_api_key}'", content)
                    
                    with open('config.py', 'w', encoding='utf-8') as f:
                        f.write(content)
                    
                    # Update the service instance
                    self.whats360_service = Whats360Service(whats360_client_id, whats360_api_key)
                    
                except Exception as e:
                    print(f"Error updating Whats360 settings: {str(e)}")
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE settings 
                SET days_before_month_end = ?, days_before_contract_end = ?, 
                    monthly_message = ?, contract_end_message = ?, send_hour = ?, send_minute = ?, send_period = ?
                WHERE id = 1
            ''', (days_before_month_end, days_before_contract_end, monthly_message, contract_end_message, send_hour, send_minute, send_period))
            conn.commit()
            conn.close()
            
            # Update scheduler time if it's running
            try:
                hour = int(send_hour)
                minute = int(send_minute)
                self.update_scheduler_time(hour, minute, send_period)
            except:
                pass
            
            return redirect(url_for('settings', saved='true'))
        
        @self.app.route('/notifications')
        def notifications():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM notifications_log ORDER BY sent_at DESC')
            logs = cursor.fetchall()
            conn.close()
            
            return render_template('notifications.html', logs=logs)
        
        @self.app.route('/send-notifications')
        def send_notifications():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM settings LIMIT 1')
            settings = cursor.fetchone()
            
            # Get all tenants with phone numbers for monthly notifications
            cursor.execute('SELECT id, tenant_name, tenant_phone FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != ""')
            monthly_tenants = cursor.fetchall()
            
            # Get all tenants with end dates for contract notifications
            cursor.execute('''
                SELECT id, tenant_name, tenant_phone, end_date 
                FROM tenants 
                WHERE tenant_phone IS NOT NULL AND tenant_phone != "" AND end_date IS NOT NULL AND end_date != ""
            ''')
            contract_tenants = cursor.fetchall()
            
            conn.close()
            
            # Send monthly notifications to all tenants
            for tenant in monthly_tenants:
                message = settings[3].replace('{{name}}', tenant[1])
                status = self.send_notification(tenant[2], message, "rental_reminder", tenant[1])
                self.log_notification(tenant[0], tenant[1], 'شهري', status)
            
            # Send contract end notifications to all tenants with end dates
            for tenant in contract_tenants:
                message = settings[4].replace('{{name}}', tenant[1]).replace('{{end_date}}', tenant[3])
                status = self.send_notification(tenant[2], message, "contract_expiry", tenant[1])
                self.log_notification(tenant[0], tenant[1], 'انتهاء عقد', status)
            
            return redirect(url_for('notifications'))
        
        @self.app.route('/preview-message')
        def preview_message():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            message_type = request.args.get('type', 'monthly')
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM settings LIMIT 1')
            settings = cursor.fetchone()
            cursor.execute('SELECT tenant_name, end_date FROM tenants LIMIT 1')
            sample_tenant = cursor.fetchone()
            conn.close()
            
            if message_type == 'monthly':
                message = settings[3].replace('{{name}}', sample_tenant[0] if sample_tenant else 'اسم المستأجر')
            else:
                message = settings[4].replace('{{name}}', sample_tenant[0] if sample_tenant else 'اسم المستأجر').replace('{{end_date}}', sample_tenant[1] if sample_tenant and sample_tenant[1] else 'تاريخ الانتهاء')
            
            return jsonify({'message': message})
        
        @self.app.route('/send-test-message', methods=['POST'])
        def send_test_message():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            message_type = request.args.get('type')
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM settings WHERE id = 1')
            settings = cursor.fetchone()
            
            cursor.execute('SELECT tenant_name, tenant_phone FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != "" LIMIT 1')
            sample_tenant = cursor.fetchone()
            conn.close()
            
            if not sample_tenant:
                return jsonify({'message': 'لا يوجد مستأجرين بأرقام هواتف للاختبار'})
            
            if message_type == 'monthly':
                message = settings[3].replace('{{name}}', sample_tenant[0])
            else:
                message = settings[4].replace('{{name}}', sample_tenant[0]).replace('{{end_date}}', '31/12/2024')
            
            notification_type = "rental_reminder" if message_type == 'monthly' else "contract_expiry"
            status = self.send_notification(sample_tenant[1], message, notification_type, sample_tenant[0])
            
            if status == "نجح":
                return jsonify({'message': f'تم إرسال الرسالة التجريبية إلى {sample_tenant[0]} بنجاح'})
            else:
                return jsonify({'message': 'فشل في إرسال الرسالة التجريبية'})
        
        @self.app.route('/reports')
        def reports():
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            # إجمالي المستأجرين
            cursor.execute('SELECT COUNT(*) FROM tenants')
            total_tenants = cursor.fetchone()[0]
            
            # المستأجرين مع أرقام هواتف
            cursor.execute('SELECT COUNT(*) FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != ""')
            tenants_with_phone = cursor.fetchone()[0]
            
            # المستأجرين مع تواريخ انتهاء
            cursor.execute('SELECT COUNT(*) FROM tenants WHERE end_date IS NOT NULL AND end_date != ""')
            tenants_with_end_date = cursor.fetchone()[0]
            
            # إجمالي التنبيهات المرسلة
            cursor.execute('SELECT COUNT(*) FROM notifications_log')
            total_notifications = cursor.fetchone()[0]
            
            # التنبيهات الناجحة
            cursor.execute('SELECT COUNT(*) FROM notifications_log WHERE status = "نجح"')
            successful_notifications = cursor.fetchone()[0]
            
            # التنبيهات حسب النوع
            cursor.execute('SELECT notification_type, COUNT(*) FROM notifications_log GROUP BY notification_type')
            notifications_by_type = cursor.fetchall()
            
            # آخر 10 تنبيهات
            cursor.execute('SELECT tenant_name, notification_type, status, sent_at FROM notifications_log ORDER BY sent_at DESC LIMIT 10')
            recent_notifications = cursor.fetchall()
            
            # معالجة الفلاتر
            filter_type = request.args.get('filter_type', '')
            days_filter = int(request.args.get('days_filter', 30))
            filtered_tenants = []
            
            print(f"Filter type: {filter_type}, Days filter: {days_filter}")  # Debug
            
            if filter_type:
                print(f"Processing filter: {filter_type}")  # Debug
                
                if filter_type == 'expiring_soon':
                    # العقود قاربت على الانتهاء
                    cursor.execute('''
                        SELECT id, tenant_name, tenant_phone, start_date, end_date 
                        FROM tenants 
                        WHERE end_date IS NOT NULL AND end_date != ""
                    ''')
                    all_tenants = cursor.fetchall()
                    print(f"Found {len(all_tenants)} tenants with end dates")  # Debug
                    
                    today = datetime.now()
                    
                    for tenant in all_tenants:
                        try:
                            end_date_str = tenant[4]
                            print(f"Processing tenant {tenant[1]} with end date: {end_date_str}")  # Debug
                            
                            try:
                                end_date = datetime.strptime(end_date_str, '%d/%m/%Y')
                            except:
                                try:
                                    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
                                except:
                                    continue
                            
                            days_diff = (end_date - today).days
                            
                            if 0 <= days_diff <= days_filter:
                                filtered_tenants.append(tenant + (days_diff,))
                                
                        except Exception as e:
                            print(f"Error processing tenant {tenant[1]}: {e}")
                            continue
                            
                elif filter_type == 'expired':
                    # العقود المنتهية
                    cursor.execute('''
                        SELECT id, tenant_name, tenant_phone, start_date, end_date 
                        FROM tenants 
                        WHERE end_date IS NOT NULL AND end_date != ""
                    ''')
                    all_tenants = cursor.fetchall()
                    today = datetime.now()
                    
                    for tenant in all_tenants:
                        try:
                            end_date_str = tenant[4]
                            try:
                                end_date = datetime.strptime(end_date_str, '%d/%m/%Y')
                            except:
                                try:
                                    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
                                except:
                                    continue
                            
                            days_diff = (end_date - today).days
                            
                            if days_diff < 0:
                                filtered_tenants.append(tenant)
                        except Exception as e:
                            continue
                            
                elif filter_type == 'no_phone':
                    cursor.execute('''
                        SELECT id, tenant_name, tenant_phone, start_date, end_date 
                        FROM tenants 
                        WHERE tenant_phone IS NULL OR tenant_phone = ""
                    ''')
                    filtered_tenants = cursor.fetchall()
                    
                elif filter_type == 'all_tenants':
                    cursor.execute('''
                        SELECT id, tenant_name, tenant_phone, start_date, end_date 
                        FROM tenants
                    ''')
                    filtered_tenants = cursor.fetchall()
                
                print(f"Final filtered tenants count: {len(filtered_tenants)}")  # Debug
            
            # المستأجرين الذين ينتهي عقدهم قريباً (للإحصائيات)
            today = datetime.now()
            cursor.execute('''
                SELECT tenant_name, end_date, tenant_phone 
                FROM tenants 
                WHERE end_date IS NOT NULL AND end_date != ""
            ''')
            all_tenants = cursor.fetchall()
            
            # تصنيف المستأجرين حسب فترة انتهاء العقد
            expiring_this_week = []
            expiring_this_month = []
            expiring_next_month = []
            expired_contracts = []
            
            for tenant in all_tenants:
                try:
                    try:
                        end_date = datetime.strptime(tenant[1], '%d/%m/%Y')
                    except:
                        try:
                            end_date = datetime.strptime(tenant[1], '%Y-%m-%d')
                        except:
                            continue
                    
                    days_diff = (end_date - today).days
                    
                    if days_diff < 0:
                        expired_contracts.append((tenant[0], tenant[1], tenant[2], abs(days_diff)))
                    elif days_diff <= 7:
                        expiring_this_week.append((tenant[0], tenant[1], tenant[2], days_diff))
                    elif days_diff <= 30:
                        expiring_this_month.append((tenant[0], tenant[1], tenant[2], days_diff))
                    elif days_diff <= 60:
                        expiring_next_month.append((tenant[0], tenant[1], tenant[2], days_diff))
                except:
                    continue
            
            conn.close()
            
            return render_template('reports.html', 
                                 total_tenants=total_tenants,
                                 tenants_with_phone=tenants_with_phone,
                                 tenants_with_end_date=tenants_with_end_date,
                                 total_notifications=total_notifications,
                                 successful_notifications=successful_notifications,
                                 notifications_by_type=notifications_by_type,
                                 recent_notifications=recent_notifications,
                                 expiring_this_week=expiring_this_week,
                                 expiring_this_month=expiring_this_month,
                                 expiring_next_month=expiring_next_month,
                                 expired_contracts=expired_contracts,
                                 filtered_tenants=filtered_tenants)
        
        @self.app.route('/download-image/<int:tenant_id>/<image_type>')
        def download_image(tenant_id, image_type):
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            if image_type == 'id':
                cursor.execute('SELECT id_image, tenant_name FROM tenants WHERE id = ?', (tenant_id,))
            elif image_type == 'contract':
                cursor.execute('SELECT contract_image, tenant_name FROM tenants WHERE id = ?', (tenant_id,))
            elif image_type == 'license':
                cursor.execute('SELECT commercial_license_image, tenant_name FROM tenants WHERE id = ?', (tenant_id,))
            else:
                conn.close()
                return redirect(url_for('view_tenants'))
            
            result = cursor.fetchone()
            conn.close()
            
            if not result or not result[0]:
                return redirect(url_for('view_tenant', tenant_id=tenant_id))
            
            image_filename = result[0]
            tenant_name = result[1]
            file_path = os.path.join(self.app.config['UPLOAD_FOLDER'], image_filename)
            
            if not os.path.exists(file_path):
                return redirect(url_for('view_tenant', tenant_id=tenant_id))
            
            # Create download filename
            file_extension = os.path.splitext(image_filename)[1]
            if image_type == 'id':
                download_name = f"صورة_هوية_{tenant_name}{file_extension}"
            else:
                download_name = f"صورة_عقد_{tenant_name}{file_extension}"
            
            return send_file(file_path, as_attachment=True, download_name=download_name)






        @self.app.route('/clear-tenants-data', methods=['POST'])
        def clear_tenants_data():
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مصرح'})
            
            try:
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                
                # حذف جميع المستأجرين
                cursor.execute('DELETE FROM tenants')
                
                # حذف سجل الإشعارات
                cursor.execute('DELETE FROM notifications_log')
                
                conn.commit()
                conn.close()
                
                return jsonify({'success': True, 'message': 'تم حذف بيانات المستأجرين والتقارير بنجاح'})
                
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في حذف البيانات: {str(e)}'})
        
        @self.app.route('/clear-all-data', methods=['POST'])
        def clear_all_data():
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مصرح'})
            
            try:
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                
                # حذف جميع المستأجرين
                cursor.execute('DELETE FROM tenants')
                
                # حذف سجل الإشعارات
                cursor.execute('DELETE FROM notifications_log')
                
                # إعادة تعيين الإعدادات للقيم الافتراضية
                cursor.execute('DELETE FROM settings')
                cursor.execute('INSERT INTO settings DEFAULT VALUES')
                
                conn.commit()
                conn.close()
                
                return jsonify({'success': True, 'message': 'تم حذف جميع البيانات بنجاح'})
                
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في حذف البيانات: {str(e)}'})

        @self.app.route('/send-rental-reminder', methods=['POST'])
        def send_rental_reminder():
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            tenant_id = data.get('tenant_id')
            
            print(f"[DEBUG] Sending rental reminder for tenant ID: {tenant_id}")
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT tenant_name, tenant_phone FROM tenants WHERE id = ?', (tenant_id,))
            tenant = cursor.fetchone()
            conn.close()
            
            if not tenant:
                print(f"[ERROR] Tenant not found with ID: {tenant_id}")
                return jsonify({'success': False, 'message': 'المستأجر غير موجود'})
            
            tenant_name, tenant_phone = tenant
            print(f"[DEBUG] Tenant found: {tenant_name}, Phone: {tenant_phone}")
            
            if not tenant_phone:
                return jsonify({'success': False, 'message': 'رقم الهاتف غير متوفر'})
            
            # Clean and format phone number
            clean_phone = self.clean_phone_number(tenant_phone)
            print(f"[DEBUG] Cleaned phone number: {clean_phone}")
            
            message = f"""🏠 تذكير بدفع الإيجار

عزيزي/عزيزتي {tenant_name}،

نذكركم بأن موعد دفع الإيجار قد حان.
يرجى سداد المبلغ في أقرب وقت ممكن.

شكراً لتعاونكم
إدارة العقارات"""
            
            try:
                print(f"[DEBUG] Attempting to send message to {clean_phone}")
                # Try both methods
                result = self.whats360_service.send_text_message(clean_phone, message)
                print(f"[DEBUG] First method result: {result}")
                
                if not result.get('success'):
                    print("[DEBUG] First method failed, trying URL method")
                    # Try URL method if first method fails
                    result = self.whats360_service.send_text_message_url(clean_phone, message)
                    print(f"[DEBUG] Second method result: {result}")
                
                # Log the notification
                self.log_notification(tenant_id, tenant_name, 'تذكير إيجار يدوي', 'نجح' if result.get('success') else 'فشل')
                
                if result.get('success'):
                    return jsonify({'success': True, 'message': 'تم إرسال التذكير بنجاح'})
                else:
                    error_msg = result.get('error', 'خطأ غير معروف')
                    print(f"[ERROR] Failed to send message: {error_msg}")
                    return jsonify({'success': False, 'message': f"فشل في الإرسال: {error_msg}"})
            except Exception as e:
                print(f"[ERROR] Exception in send_rental_reminder: {str(e)}")
                return jsonify({'success': False, 'message': f'خطأ: {str(e)}'})

        @self.app.route('/send-contract-expiry', methods=['POST'])
        def send_contract_expiry():
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            tenant_id = data.get('tenant_id')
            
            print(f"[DEBUG] Sending contract expiry reminder for tenant ID: {tenant_id}")
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT tenant_name, tenant_phone, end_date FROM tenants WHERE id = ?', (tenant_id,))
            tenant = cursor.fetchone()
            conn.close()
            
            if not tenant:
                print(f"[ERROR] Tenant not found with ID: {tenant_id}")
                return jsonify({'success': False, 'message': 'المستأجر غير موجود'})
            
            tenant_name, tenant_phone, end_date = tenant
            print(f"[DEBUG] Tenant found: {tenant_name}, Phone: {tenant_phone}, End Date: {end_date}")
            
            if not tenant_phone:
                return jsonify({'success': False, 'message': 'رقم الهاتف غير متوفر'})
            
            # Clean and format phone number
            clean_phone = self.clean_phone_number(tenant_phone)
            print(f"[DEBUG] Cleaned phone number: {clean_phone}")
            
            message = f"""📋 تذكير بانتهاء العقد

عزيزي/عزيزتي {tenant_name}،

نود إعلامكم بأن عقد الإيجار سينتهي في {end_date if end_date else 'غير محدد'}.
يرجى التواصل معنا لتجديد العقد أو ترتيب إجراءات التسليم.

شكراً لتعاونكم
إدارة العقارات"""
            
            try:
                print(f"[DEBUG] Attempting to send contract expiry message to {clean_phone}")
                # Try both methods
                result = self.whats360_service.send_text_message(clean_phone, message)
                print(f"[DEBUG] First method result: {result}")
                
                if not result.get('success'):
                    print("[DEBUG] First method failed, trying URL method")
                    # Try URL method if first method fails
                    result = self.whats360_service.send_text_message_url(clean_phone, message)
                    print(f"[DEBUG] Second method result: {result}")
                
                # Log the notification
                self.log_notification(tenant_id, tenant_name, 'تذكير انتهاء عقد يدوي', 'نجح' if result.get('success') else 'فشل')
                
                if result.get('success'):
                    return jsonify({'success': True, 'message': 'تم إرسال التذكير بنجاح'})
                else:
                    error_msg = result.get('error', 'خطأ غير معروف')
                    print(f"[ERROR] Failed to send contract expiry message: {error_msg}")
                    return jsonify({'success': False, 'message': f"فشل في الإرسال: {error_msg}"})
            except Exception as e:
                print(f"[ERROR] Exception in send_contract_expiry: {str(e)}")
                return jsonify({'success': False, 'message': f'خطأ: {str(e)}'})

        @self.app.route('/test-api-connection', methods=['POST'])
        def test_api_connection():
            """Test Whats360 API connection"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            test_phone = data.get('phone', '201234567890')
            
            try:
                print(f"[DEBUG] Testing API with phone: {test_phone}")
                
                # Test message
                test_message = "رسالة اختبار من نظام إدارة المستأجرين"
                
                # Try first method
                result1 = self.whats360_service.send_text_message(test_phone, test_message)
                print(f"[DEBUG] Method 1 result: {result1}")
                
                if result1.get('success'):
                    return jsonify({
                        'success': True,
                        'message': 'تم إرسال رسالة الاختبار بنجاح ✅',
                        'method': 'POST method',
                        'details': result1
                    })
                
                # Try second method if first fails
                result2 = self.whats360_service.send_text_message_url(test_phone, test_message)
                print(f"[DEBUG] Method 2 result: {result2}")
                
                if result2.get('success'):
                    return jsonify({
                        'success': True,
                        'message': 'تم إرسال رسالة الاختبار بنجاح ✅ (الطريقة الثانية)',
                        'method': 'GET method',
                        'details': result2
                    })
                
                # All methods failed
                return jsonify({
                    'success': False,
                    'message': 'فشل في إرسال رسالة الاختبار بجميع الطرق',
                    'method1_error': result1.get('error', 'غير معروف'),
                    'method2_error': result2.get('error', 'غير معروف'),
                    'details': {
                        'method1': result1,
                        'method2': result2
                    }
                })
                    
            except Exception as e:
                print(f"[ERROR] API Connection test failed: {str(e)}")
                return jsonify({
                    'success': False, 
                    'message': f'فشل في الاتصال: {str(e)}'
                })

        @self.app.route('/check-account-status', methods=['POST'])
        def check_account_status():
            """Check Whats360 account status"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                print(f"[DEBUG] Checking account status...")
                result = self.whats360_service.check_account_status()
                print(f"[DEBUG] Account status result: {result}")
                
                if result.get('success'):
                    return jsonify({
                        'success': True,
                        'message': 'تم فحص حالة الحساب بنجاح ✅',
                        'endpoint': result.get('endpoint'),
                        'data': result.get('data')
                    })
                else:
                    return jsonify({
                        'success': False,
                        'message': 'فشل في فحص حالة الحساب',
                        'error': result.get('error')
                    })
                    
            except Exception as e:
                print(f"[ERROR] Account status check failed: {str(e)}")
                return jsonify({
                    'success': False,
                    'message': f'خطأ في فحص الحساب: {str(e)}'
                })

        @self.app.route('/check-balance', methods=['POST'])
        def check_balance():
            """Check Whats360 account balance"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                print(f"[DEBUG] Checking account balance...")
                result = self.whats360_service.get_account_balance()
                print(f"[DEBUG] Balance result: {result}")
                
                if result.get('success'):
                    balance = result.get('balance', 0)
                    return jsonify({
                        'success': True,
                        'message': f'💰 الرصيد المتاح: {balance}',
                        'balance': balance,
                        'data': result.get('data')
                    })
                else:
                    return jsonify({
                        'success': False,
                        'message': 'فشل في فحص الرصيد',
                        'error': result.get('error')
                    })
                    
            except Exception as e:
                print(f"[ERROR] Balance check failed: {str(e)}")
                return jsonify({
                    'success': False,
                    'message': f'خطأ في فحص الرصيد: {str(e)}'
                })

        @self.app.route('/diagnose-whats360', methods=['POST'])
        def diagnose_whats360():
            """تشخيص شامل لحالة Whats360"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                print(f"[DEBUG] Running comprehensive diagnosis...")
                result = self.whats360_service.diagnose_connection()
                print(f"[DEBUG] Diagnosis result: {result}")
                
                return jsonify({
                    'success': True,
                    'message': 'تم التشخيص بنجاح',
                    'diagnosis': result
                })
                    
            except Exception as e:
                print(f"[ERROR] Diagnosis failed: {str(e)}")
                return jsonify({
                    'success': False,
                    'message': f'خطأ في التشخيص: {str(e)}'
                })

        @self.app.route('/test-specific-number', methods=['POST'])
        def test_specific_number():
            """اختبار رقم محدد مع تشخيص مفصل"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            phone = data.get('phone', '01009931190')  # الرقم الافتراضي بالشكل المحلي
            name = data.get('name', 'صاحب النظام')
            
            try:
                print(f"[DEBUG] Testing specific number: {phone}")
                
                # رسالة اختبار
                test_message = f"🧪 اختبار النظام\n\nمرحباً {name}،\n\nهذه رسالة اختبار للتأكد من عمل النظام.\n\nالوقت: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                
                # محاولة الإرسال بالطريقة البديلة مع الرقم الأصلي
                result = self.whats360_service.send_text_message_alternative(phone, test_message)
                
                print(f"[DEBUG] Test result: {result}")
                
                return jsonify({
                    'success': result.get('success', False),
                    'message': result.get('error', 'تم الإرسال بنجاح') if not result.get('success') else 'تم إرسال الرسالة بنجاح ✅',
                    'phone_original': phone,
                    'phone_cleaned': phone,  # الآن نستخدم نفس الرقم
                    'details': result.get('details', []),
                    'diagnosis': result.get('diagnosis', {})
                })
                
            except Exception as e:
                print(f"[ERROR] Exception in test_specific_number: {str(e)}")
                return jsonify({
                    'success': False,
                    'message': f'خطأ: {str(e)}',
                    'phone_original': phone,
                    'phone_cleaned': phone
                })

        @self.app.route('/test-whats360', methods=['POST'])
        def test_whats360():
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            phone = data.get('phone')
            name = data.get('name', 'المستخدم')
            message_type = data.get('message_type', 'text')
            template_id = data.get('template_id')
            
            if not phone:
                return jsonify({'success': False, 'message': 'رقم الهاتف مطلوب'})
            
            clean_phone = self.clean_phone_number(phone)
            
            try:
                print(f"[DEBUG] Testing Whats360 with phone: {clean_phone}, type: {message_type}")
                
                if message_type == 'welcome':
                    result = self.whats360_service.send_welcome_message(clean_phone, name)
                elif message_type == 'template':
                    if not template_id:
                        return jsonify({'success': False, 'message': 'معرف القالب مطلوب'})
                    result = self.whats360_service.send_template_message(clean_phone, int(template_id))
                else:  # text message
                    test_message = f"🧪 رسالة تجريبية من نظام إدارة المستأجرين\n\nمرحباً {name}،\n\nهذه رسالة اختبار للتأكد من عمل النظام بشكل صحيح.\n\nإدارة العقارات"
                    result = self.whats360_service.send_text_message(clean_phone, test_message)
                    
                    # Try URL method if first method fails
                    if not result.get('success'):
                        print("[DEBUG] First method failed, trying URL method")
                        result = self.whats360_service.send_text_message_url(clean_phone, test_message)
                
                print(f"[DEBUG] Test result: {result}")
                
                if result.get('success'):
                    return jsonify({'success': True, 'message': 'تم إرسال الرسالة التجريبية بنجاح ✅'})
                else:
                    error_msg = result.get('error', 'خطأ غير معروف')
                    return jsonify({'success': False, 'message': f"فشل في الإرسال: {error_msg}"})
            except Exception as e:
                print(f"[ERROR] Exception in test_whats360: {str(e)}")
                return jsonify({'success': False, 'message': f'خطأ: {str(e)}'})

        # ===== مسارات نظام الرسائل المحسن =====
        
        @self.app.route('/message-center')
        def message_center():
            """مركز الرسائل الرئيسي"""
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            # إحصائيات سريعة
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            # عدد القوالب
            cursor.execute('SELECT COUNT(*) FROM message_templates WHERE is_active = 1')
            templates_count = cursor.fetchone()[0]
            
            # عدد الرسائل المجدولة المعلقة
            cursor.execute('SELECT COUNT(*) FROM scheduled_messages WHERE status = "pending"')
            pending_scheduled = cursor.fetchone()[0]
            
            # عدد الحملات النشطة
            cursor.execute('SELECT COUNT(*) FROM bulk_messages WHERE status = "draft"')
            draft_campaigns = cursor.fetchone()[0]
            
            # آخر الرسائل المرسلة
            cursor.execute('''
                SELECT tenant_name, notification_type, status, sent_at 
                FROM notifications_log 
                ORDER BY sent_at DESC LIMIT 5
            ''')
            recent_messages = cursor.fetchall()
            
            conn.close()
            
            return render_template('message_center.html', 
                                 templates_count=templates_count,
                                 pending_scheduled=pending_scheduled,
                                 draft_campaigns=draft_campaigns,
                                 recent_messages=recent_messages)
        
        @self.app.route('/message-templates')
        def message_templates():
            """إدارة قوالب الرسائل"""
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            templates = self.get_message_templates()
            from config import MESSAGE_TYPES
            return render_template('message_templates.html', templates=templates, message_types=MESSAGE_TYPES)
        
        @self.app.route('/save-template', methods=['POST'])
        def save_template():
            """حفظ قالب رسالة"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            template_name = data.get('template_name')
            template_type = data.get('template_type')
            template_content = data.get('template_content')
            template_id = data.get('template_id')
            
            try:
                self.save_message_template(template_name, template_type, template_content, template_id)
                return jsonify({'success': True, 'message': 'تم حفظ القالب بنجاح'})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في الحفظ: {str(e)}'})
        
        @self.app.route('/delete-template/<int:template_id>', methods=['POST'])
        def delete_template(template_id):
            """حذف قالب رسالة"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                cursor.execute('UPDATE message_templates SET is_active = 0 WHERE id = ?', (template_id,))
                conn.commit()
                conn.close()
                return jsonify({'success': True, 'message': 'تم حذف القالب بنجاح'})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في الحذف: {str(e)}'})
        
        @self.app.route('/bulk-messages')
        def bulk_messages():
            """إدارة الرسائل الجماعية"""
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM bulk_messages ORDER BY created_at DESC')
            campaigns = cursor.fetchall()
            conn.close()
            
            return render_template('bulk_messages.html', campaigns=campaigns)
        
        @self.app.route('/create-bulk-message', methods=['POST'])
        def create_bulk_message_route():
            """إنشاء حملة رسائل جماعية"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            campaign_name = data.get('campaign_name')
            message_content = data.get('message_content')
            target_group = data.get('target_group')
            
            try:
                bulk_message_id = self.create_bulk_message(campaign_name, message_content, target_group)
                return jsonify({'success': True, 'message': 'تم إنشاء الحملة بنجاح', 'campaign_id': bulk_message_id})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في إنشاء الحملة: {str(e)}'})
        
        @self.app.route('/send-bulk-message/<int:campaign_id>', methods=['POST'])
        def send_bulk_message_route(campaign_id):
            """إرسال حملة رسائل جماعية"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                success = self.send_bulk_message(campaign_id)
                if success:
                    return jsonify({'success': True, 'message': 'تم إرسال الحملة بنجاح'})
                else:
                    return jsonify({'success': False, 'message': 'فشل في إرسال الحملة'})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في الإرسال: {str(e)}'})
        
        @self.app.route('/scheduled-messages')
        def scheduled_messages():
            """إدارة الرسائل المجدولة"""
            if 'logged_in' not in session:
                return redirect(url_for('login'))
            
            pending_messages = self.get_scheduled_messages('pending')
            sent_messages = self.get_scheduled_messages('sent')
            failed_messages = self.get_scheduled_messages('failed')
            
            return render_template('scheduled_messages.html', 
                                 pending_messages=pending_messages,
                                 sent_messages=sent_messages,
                                 failed_messages=failed_messages)
        
        @self.app.route('/schedule-message', methods=['POST'])
        def schedule_message_route():
            """جدولة رسالة"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            tenant_id = data.get('tenant_id')
            message_type = data.get('message_type')
            message_content = data.get('message_content')
            scheduled_date = data.get('scheduled_date')
            scheduled_time = data.get('scheduled_time')
            
            try:
                self.schedule_message(tenant_id, message_type, message_content, scheduled_date, scheduled_time)
                return jsonify({'success': True, 'message': 'تم جدولة الرسالة بنجاح'})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في الجدولة: {str(e)}'})
        
        @self.app.route('/send-custom-message', methods=['POST'])
        def send_custom_message():
            """إرسال رسالة مخصصة"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            data = request.get_json()
            tenant_id = data.get('tenant_id')
            message_content = data.get('message_content')
            
            try:
                conn = sqlite3.connect('database.db')
                cursor = conn.cursor()
                cursor.execute('SELECT tenant_name, tenant_phone FROM tenants WHERE id = ?', (tenant_id,))
                tenant = cursor.fetchone()
                conn.close()
                
                if tenant and tenant[1]:
                    # تخصيص الرسالة
                    personalized_message = message_content.replace('{{name}}', tenant[0])
                    
                    # إرسال الرسالة
                    status = self.send_notification(tenant[1], personalized_message, 'custom', tenant[0])
                    
                    # تسجيل الإشعار
                    self.log_notification(
                        tenant_id, tenant[0], 'رسالة مخصصة', status,
                        None, personalized_message, tenant[1]
                    )
                    
                    if status == 'نجح':
                        return jsonify({'success': True, 'message': 'تم إرسال الرسالة بنجاح'})
                    else:
                        return jsonify({'success': False, 'message': f'فشل في الإرسال: {status}'})
                else:
                    return jsonify({'success': False, 'message': 'المستأجر غير موجود أو لا يملك رقم هاتف'})
                    
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في الإرسال: {str(e)}'})
        
        @self.app.route('/send-welcome-message/<int:tenant_id>', methods=['POST'])
        def send_welcome_message_route(tenant_id):
            """إرسال رسالة ترحيب"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                success = self.send_welcome_message_to_tenant(tenant_id)
                if success:
                    return jsonify({'success': True, 'message': 'تم إرسال رسالة الترحيب بنجاح'})
                else:
                    return jsonify({'success': False, 'message': 'فشل في إرسال رسالة الترحيب'})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في الإرسال: {str(e)}'})
        
        @self.app.route('/process-scheduled-messages', methods=['POST'])
        def process_scheduled_messages_route():
            """معالجة الرسائل المجدولة المستحقة"""
            if 'logged_in' not in session:
                return jsonify({'success': False, 'message': 'غير مسموح'})
            
            try:
                self.process_scheduled_messages()
                return jsonify({'success': True, 'message': 'تم معالجة الرسائل المجدولة'})
            except Exception as e:
                return jsonify({'success': False, 'message': f'خطأ في المعالجة: {str(e)}'})
        
        @self.app.route('/api/tenants')
        def api_tenants():
            """API لجلب قائمة المستأجرين"""
            if 'logged_in' not in session:
                return jsonify({'error': 'غير مسموح'})
            
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT id, tenant_name, tenant_phone FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != ""')
            tenants = cursor.fetchall()
            conn.close()
            
            tenants_list = []
            for tenant in tenants:
                tenants_list.append({
                    'id': tenant[0],
                    'tenant_name': tenant[1],
                    'tenant_phone': tenant[2]
                })
            
            return jsonify(tenants_list)

        # =========================================================================
        # 📱 REST API FOR MOBILE APP (/api/v1/...)
        # =========================================================================

        @self.app.route('/api/v1/health', methods=['GET'])
        def api_health():
            return jsonify({
                'status': 'ok',
                'app': 'mostager-api',
                'version': '1.0.0',
                'timestamp': datetime.now().isoformat()
            })

        @self.app.route('/api/v1/auth/login', methods=['POST'])
        def api_auth_login():
            data = request.get_json(silent=True) or request.form
            username = data.get('username', '').strip()
            password = data.get('password', '').strip()
            
            admin = self.get_admin_profile()
            if (username == admin['username'] and password == admin['password']) or \
               (username == self.admin_username and password == self.admin_password):
                import base64
                token = base64.b64encode(f"{username}:{datetime.now().timestamp()}".encode()).decode()
                session['logged_in'] = True
                return jsonify({
                    'success': True,
                    'message': 'تم تسجيل الدخول بنجاح',
                    'token': token,
                    'user': {
                        'id': admin['id'],
                        'username': admin['username'],
                        'full_name': admin['full_name'],
                        'email': admin['email'],
                        'avatar': admin['avatar'],
                        'phone': admin['phone']
                    }
                })
            return jsonify({'success': False, 'message': 'بيانات الدخول غير صحيحة'}), 401

        @self.app.route('/api/v1/auth/profile', methods=['GET', 'PUT'])
        def api_auth_profile():
            admin = self.get_admin_profile()
            if request.method == 'GET':
                return jsonify({'success': True, 'profile': admin})
            
            data = request.get_json(silent=True) or request.form
            full_name = data.get('full_name', admin['full_name']).strip()
            username = data.get('username', admin['username']).strip()
            email = data.get('email', admin['email']).strip()
            phone = data.get('phone', admin['phone']).strip()
            new_password = data.get('new_password', '').strip()
            
            updated_password = admin['password']
            if new_password:
                if len(new_password) < 4:
                    return jsonify({'success': False, 'message': 'كلمة المرور يجب أن تكون 4 خانات على الأقل'}), 400
                updated_password = new_password
                
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE admin_profile 
                SET full_name = ?, username = ?, email = ?, phone = ?, password = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ''', (full_name, username, email, phone, updated_password, admin['id']))
            conn.commit()
            conn.close()
            
            return jsonify({'success': True, 'message': 'تم تحديث الملف الشخصي بنجاح', 'profile': self.get_admin_profile()})

        @self.app.route('/api/v1/dashboard/stats', methods=['GET'])
        def api_dashboard_stats():
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            cursor.execute('SELECT COUNT(*) FROM tenants')
            total_tenants = cursor.fetchone()[0]
            
            try:
                cursor.execute('SELECT COUNT(*) FROM notifications_log')
                notifications_count = cursor.fetchone()[0]
            except Exception:
                notifications_count = 0
                
            try:
                cursor.execute('SELECT COUNT(*) FROM scheduled_messages')
                scheduled_count = cursor.fetchone()[0]
            except Exception:
                scheduled_count = 0

            try:
                cursor.execute('SELECT COUNT(*) FROM message_templates')
                templates_count = cursor.fetchone()[0]
            except Exception:
                templates_count = 0

            cursor.execute('SELECT id, tenant_name, tenant_phone, start_date, end_date, created_at FROM tenants ORDER BY id DESC LIMIT 5')
            recent_rows = cursor.fetchall()
            recent_tenants = []
            for r in recent_rows:
                recent_tenants.append({
                    'id': r[0],
                    'name': r[1],
                    'phone': r[2],
                    'start_date': r[3],
                    'end_date': r[4],
                    'created_at': r[5]
                })
            conn.close()

            return jsonify({
                'success': True,
                'stats': {
                    'total_tenants': total_tenants,
                    'notifications_count': notifications_count,
                    'scheduled_count': scheduled_count,
                    'templates_count': templates_count,
                    'recent_tenants': recent_tenants
                }
            })

        @self.app.route('/api/v1/tenants', methods=['GET', 'POST'])
        def api_v1_tenants():
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            if request.method == 'GET':
                search = request.args.get('search', '').strip()
                filter_type = request.args.get('filter_type', '').strip()
                
                query = 'SELECT id, tenant_name, tenant_phone, start_date, end_date, created_at, contract_type, id_image, contract_image FROM tenants'
                params = []
                
                if search:
                    query += ' WHERE tenant_name LIKE ? OR tenant_phone LIKE ?'
                    params.extend([f'%{search}%', f'%{search}%'])
                
                query += ' ORDER BY id DESC'
                cursor.execute(query, params)
                rows = cursor.fetchall()
                conn.close()
                
                tenants_data = []
                for r in rows:
                    tenants_data.append({
                        'id': r[0],
                        'tenant_name': r[1],
                        'tenant_phone': r[2],
                        'start_date': r[3],
                        'end_date': r[4],
                        'created_at': r[5],
                        'contract_type': r[6] if len(r) > 6 else 'عقد إيجار',
                        'id_image': r[7] if len(r) > 7 else None,
                        'contract_image': r[8] if len(r) > 8 else None,
                        'whatsapp_url': self.format_whatsapp_url(r[2])
                    })
                return jsonify({'success': True, 'count': len(tenants_data), 'tenants': tenants_data})
                
            elif request.method == 'POST':
                data = request.get_json(silent=True) or request.form
                name = data.get('tenant_name', '').strip()
                phone = data.get('tenant_phone', '').strip()
                start_date = data.get('start_date', '').strip()
                end_date = data.get('end_date', '').strip()
                contract_type = data.get('contract_type', 'سكني')
                notes = data.get('notes', '')
                
                if not name:
                    conn.close()
                    return jsonify({'success': False, 'message': 'اسم المستأجر مطلوب'}), 400
                
                cursor.execute('''
                    INSERT INTO tenants (tenant_name, tenant_phone, start_date, end_date, contract_type, notes, page_one_content, page_two_content)
                    VALUES (?, ?, ?, ?, ?, ?, '', '')
                ''', (name, phone, start_date, end_date, contract_type, notes))
                conn.commit()
                new_id = cursor.lastrowid
                conn.close()
                
                return jsonify({'success': True, 'message': 'تم إضافة المستأجر بنجاح', 'tenant_id': new_id}), 201

        @self.app.route('/api/v1/tenants/<int:tenant_id>', methods=['GET', 'PUT', 'DELETE'])
        def api_v1_tenant_detail(tenant_id):
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            
            if request.method == 'GET':
                cursor.execute('SELECT * FROM tenants WHERE id = ?', (tenant_id,))
                t = cursor.fetchone()
                conn.close()
                if not t:
                    return jsonify({'success': False, 'message': 'المستأجر غير موجود'}), 404
                
                return jsonify({
                    'success': True,
                    'tenant': {
                        'id': t[0],
                        'name': t[1],
                        'phone': t[6] if len(t) > 6 else None,
                        'start_date': t[7] if len(t) > 7 else None,
                        'end_date': t[8] if len(t) > 8 else None,
                        'id_image': t[9] if len(t) > 9 else None,
                        'contract_image': t[10] if len(t) > 10 else None,
                        'contract_type': t[11] if len(t) > 11 else None,
                        'payment_count': t[12] if len(t) > 12 else None,
                        'check_images': t[13] if len(t) > 13 else None,
                        'has_commitment': t[14] if len(t) > 14 else None,
                        'maintenance_responsibility': t[15] if len(t) > 15 else None,
                        'notes': t[16] if len(t) > 16 else None,
                        'commercial_license_number': t[17] if len(t) > 17 else None,
                        'commercial_license_image': t[18] if len(t) > 18 else None,
                        'created_at': t[4] if len(t) > 4 else None,
                        'updated_at': t[5] if len(t) > 5 else None,
                        'whatsapp_url': self.format_whatsapp_url(t[6] if len(t) > 6 else '')
                    }
                })
                
            elif request.method == 'PUT':
                data = request.get_json(silent=True) or request.form
                name = data.get('tenant_name')
                phone = data.get('tenant_phone')
                start_date = data.get('start_date')
                end_date = data.get('end_date')
                contract_type = data.get('contract_type')
                notes = data.get('notes')
                
                cursor.execute('''
                    UPDATE tenants 
                    SET tenant_name = COALESCE(?, tenant_name),
                        tenant_phone = COALESCE(?, tenant_phone),
                        start_date = COALESCE(?, start_date),
                        end_date = COALESCE(?, end_date),
                        contract_type = COALESCE(?, contract_type),
                        notes = COALESCE(?, notes),
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (name, phone, start_date, end_date, contract_type, notes, tenant_id))
                conn.commit()
                conn.close()
                return jsonify({'success': True, 'message': 'تم تحديث بيانات المستأجر بنجاح'})
                
            elif request.method == 'DELETE':
                cursor.execute('DELETE FROM tenants WHERE id = ?', (tenant_id,))
                conn.commit()
                conn.close()
                return jsonify({'success': True, 'message': 'تم حذف المستأجر بنجاح'})

        @self.app.route('/api/v1/tenants/<int:tenant_id>/upload', methods=['POST'])
        def api_v1_tenant_upload(tenant_id):
            """رفع مستندات أو صور شيكات لمستأجر محدد عبر تطبيق الموبايل"""
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('SELECT id, check_images FROM tenants WHERE id = ?', (tenant_id,))
            t = cursor.fetchone()
            if not t:
                conn.close()
                return jsonify({'success': False, 'message': 'المستأجر غير موجود'}), 404

            image_type = request.form.get('image_type', 'check').lower()
            if 'image' not in request.files:
                conn.close()
                return jsonify({'success': False, 'message': 'يرجى إرفاق ملف الصورة'}), 400

            file = request.files['image']
            if not file or not file.filename:
                conn.close()
                return jsonify({'success': False, 'message': 'اسم الملف غير صالح'}), 400

            ext = os.path.splitext(file.filename)[1].lower()
            if ext not in ['.jpg', '.jpeg', '.png', '.webp', '.svg']:
                conn.close()
                return jsonify({'success': False, 'message': 'صيغة الصورة غير مدعومة'}), 400

            upload_folder = self.app.config.get('UPLOAD_FOLDER', 'static/uploads')
            os.makedirs(upload_folder, exist_ok=True)
            clean_name = f"{image_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{tenant_id}{ext}"
            file.save(os.path.join(upload_folder, clean_name))

            if image_type == 'id':
                cursor.execute('UPDATE tenants SET id_image = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', (clean_name, tenant_id))
            elif image_type == 'contract':
                cursor.execute('UPDATE tenants SET contract_image = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', (clean_name, tenant_id))
            elif image_type == 'license':
                cursor.execute('UPDATE tenants SET commercial_license_image = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', (clean_name, tenant_id))
            elif image_type == 'check':
                current_checks = t[1] or ''
                new_checks = f"{current_checks},{clean_name}" if current_checks else clean_name
                cursor.execute('UPDATE tenants SET check_images = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', (new_checks, tenant_id))

            conn.commit()
            conn.close()
            return jsonify({'success': True, 'message': 'تم رفع الصورة وحفظها بنجاح', 'filename': clean_name, 'image_url': f"/static/uploads/{clean_name}"})

        @self.app.route('/api/v1/auth/forgot-password', methods=['POST'])
        def api_v1_auth_forgot_password():
            """استعادة كلمة المرور عبر API الموبايل"""
            data = request.get_json(silent=True) or request.form
            username_or_email = data.get('username_or_email', '').strip()
            new_password = data.get('new_password', '').strip()
            confirm_password = data.get('confirm_password', '').strip()

            admin = self.get_admin_profile()
            if not username_or_email:
                return jsonify({'success': False, 'message': 'اسم المستخدم أو البريد الإلكتروني مطلوب'}), 400

            if username_or_email.lower() != admin['username'].lower() and \
               username_or_email.lower() != admin['email'].lower():
                return jsonify({'success': False, 'message': 'البيانات غير متطابقة مع سجلات المدير'}), 404

            if not new_password or len(new_password) < 4:
                return jsonify({'success': False, 'message': 'كلمة المرور الجديدة يجب ألا تقل عن 4 خانات'}), 400

            if new_password != confirm_password:
                return jsonify({'success': False, 'message': 'كلمتا المرور غير متطابقتين'}), 400

            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            cursor.execute('UPDATE admin_profile SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', (new_password, admin['id']))
            conn.commit()
            conn.close()
            self.admin_password = new_password

            return jsonify({'success': True, 'message': 'تم استعادة وتعيين كلمة المرور بنجاح'})

        @self.app.route('/api/v1/reports', methods=['GET'])
        def api_v1_reports():
            """جلب تقرير وإحصائيات شاملة للموبايل"""
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()

            cursor.execute('SELECT COUNT(*) FROM tenants')
            total_tenants = cursor.fetchone()[0]

            cursor.execute('SELECT COUNT(*) FROM tenants WHERE tenant_phone IS NOT NULL AND tenant_phone != ""')
            tenants_with_phone = cursor.fetchone()[0]

            cursor.execute('SELECT COUNT(*) FROM tenants WHERE end_date IS NOT NULL AND end_date != ""')
            tenants_with_end_date = cursor.fetchone()[0]

            cursor.execute('SELECT COUNT(*) FROM notifications_log')
            total_notifications = cursor.fetchone()[0]

            cursor.execute('SELECT COUNT(*) FROM notifications_log WHERE status = "نجح"')
            successful_notifications = cursor.fetchone()[0]

            cursor.execute('SELECT notification_type, COUNT(*) FROM notifications_log GROUP BY notification_type')
            type_rows = cursor.fetchall()
            by_type = [{'type': r[0], 'count': r[1]} for r in type_rows]

            filter_type = request.args.get('filter_type', '').strip()
            days_filter = int(request.args.get('days_filter', 30))
            filtered_tenants = []

            if filter_type:
                cursor.execute('SELECT id, tenant_name, tenant_phone, start_date, end_date FROM tenants WHERE end_date IS NOT NULL AND end_date != ""')
                all_t = cursor.fetchall()
                today = datetime.now()

                for t in all_t:
                    end_str = t[4]
                    parsed_end = None
                    for fmt in ['%d/%m/%Y', '%Y-%m-%d']:
                        try:
                            parsed_end = datetime.strptime(end_str, fmt)
                            break
                        except:
                            pass
                    if not parsed_end:
                        continue
                    days_diff = (parsed_end - today).days

                    if filter_type == 'expiring_soon' and 0 <= days_diff <= days_filter:
                        filtered_tenants.append({
                            'id': t[0], 'tenant_name': t[1], 'tenant_phone': t[2],
                            'start_date': t[3], 'end_date': t[4], 'days_remaining': days_diff,
                            'whatsapp_url': self.format_whatsapp_url(t[2])
                        })
                    elif filter_type == 'expired' and days_diff < 0:
                        filtered_tenants.append({
                            'id': t[0], 'tenant_name': t[1], 'tenant_phone': t[2],
                            'start_date': t[3], 'end_date': t[4], 'days_overdue': abs(days_diff),
                            'whatsapp_url': self.format_whatsapp_url(t[2])
                        })

            conn.close()

            success_rate = round((successful_notifications / total_notifications * 100), 1) if total_notifications > 0 else 0
            return jsonify({
                'success': True,
                'summary': {
                    'total_tenants': total_tenants,
                    'tenants_with_phone': tenants_with_phone,
                    'tenants_with_end_date': tenants_with_end_date,
                    'total_notifications': total_notifications,
                    'successful_notifications': successful_notifications,
                    'success_rate_percent': success_rate,
                    'notifications_by_type': by_type
                },
                'filtered_count': len(filtered_tenants),
                'filtered_tenants': filtered_tenants
            })

        @self.app.route('/api/v1/notifications/logs', methods=['GET'])
        def api_v1_notifications_logs():
            """سجل الإشعارات المرسلة مع الترقيم والبحث"""
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()
            limit = int(request.args.get('limit', 20))
            offset = int(request.args.get('offset', 0))

            cursor.execute('SELECT id, tenant_name, notification_type, status, sent_at, phone_number, message_content FROM notifications_log ORDER BY id DESC LIMIT ? OFFSET ?', (limit, offset))
            rows = cursor.fetchall()
            cursor.execute('SELECT COUNT(*) FROM notifications_log')
            total = cursor.fetchone()[0]
            conn.close()

            logs = []
            for r in rows:
                logs.append({
                    'id': r[0],
                    'tenant_name': r[1],
                    'notification_type': r[2],
                    'status': r[3],
                    'sent_at': r[4],
                    'phone_number': r[5],
                    'message_content': r[6]
                })

            return jsonify({'success': True, 'total': total, 'logs': logs})

        @self.app.route('/api/v1/notifications/send', methods=['POST'])
        def api_v1_notifications_send():
            """إرسال إشعار فوري لمستأجر عبر Whats360 API"""
            data = request.get_json(silent=True) or request.form
            tenant_id = data.get('tenant_id')
            phone = data.get('phone', '').strip()
            message = data.get('message', '').strip()
            notif_type = data.get('notification_type', 'تنبيه مباشر')

            if not phone and tenant_id:
                conn = sqlite3.connect('database.db')
                c = conn.cursor()
                c.execute('SELECT tenant_phone, tenant_name FROM tenants WHERE id = ?', (tenant_id,))
                t = c.fetchone()
                conn.close()
                if t:
                    phone = t[0]

            if not phone:
                return jsonify({'success': False, 'message': 'رقم هاتف المستأجر مطلوب'}), 400

            clean_phone = self.clean_phone_number(phone)
            whatsapp_url = self.format_whatsapp_url(phone, message)

            # محاولة الإرسال الفعلي عبر Whats360
            send_success = False
            error_msg = None
            try:
                res = self.whats360_service.send_whatsapp_message(clean_phone, message)
                if res.get('success'):
                    send_success = True
                else:
                    error_msg = res.get('error', 'فشل الإرسال عبر المزود')
            except Exception as e:
                error_msg = str(e)

            # تسجيل الإشعار في السجل
            try:
                conn = sqlite3.connect('database.db')
                c = conn.cursor()
                c.execute('''
                    INSERT INTO notifications_log (tenant_id, tenant_name, notification_type, status, message_content, phone_number, error_details, whatsapp_url)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (tenant_id, data.get('tenant_name', 'مستأجر'), notif_type, 'نجح' if send_success else 'فشل', message, clean_phone, error_msg, whatsapp_url))
                conn.commit()
                conn.close()
            except:
                pass

            return jsonify({
                'success': True,
                'sent_via_api': send_success,
                'error': error_msg,
                'whatsapp_url': whatsapp_url,
                'message': 'تمت معالجة التنبيه بنجاح' if send_success else 'تعذر الإرسال الآلي، يمكنك استخدام رابط الواتساب المباشر'
            })

        @self.app.route('/api/v1/notifications/templates', methods=['GET', 'POST'])
        def api_v1_templates():
            """إدارة قوالب الرسائل"""
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()

            if request.method == 'GET':
                cursor.execute('SELECT id, template_name, template_type, template_content, is_active FROM message_templates ORDER BY id ASC')
                rows = cursor.fetchall()
                conn.close()
                templates = [{'id': r[0], 'name': r[1], 'type': r[2], 'content': r[3], 'is_active': bool(r[4])} for r in rows]
                return jsonify({'success': True, 'templates': templates})

            elif request.method == 'POST':
                data = request.get_json(silent=True) or request.form
                name = data.get('name', '').strip()
                t_type = data.get('type', 'عام').strip()
                content = data.get('content', '').strip()

                if not name or not content:
                    conn.close()
                    return jsonify({'success': False, 'message': 'اسم القالب والمحتوى مطلوبان'}), 400

                cursor.execute('INSERT INTO message_templates (template_name, template_type, template_content) VALUES (?, ?, ?)', (name, t_type, content))
                conn.commit()
                new_id = cursor.lastrowid
                conn.close()
                return jsonify({'success': True, 'message': 'تمت إضافة القالب بنجاح', 'template_id': new_id}), 201

        @self.app.route('/api/v1/notifications/templates/<int:template_id>', methods=['PUT', 'DELETE'])
        def api_v1_template_detail(template_id):
            """تعديل أو حذف قالب محدد"""
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()

            if request.method == 'PUT':
                data = request.get_json(silent=True) or request.form
                name = data.get('name')
                t_type = data.get('type')
                content = data.get('content')
                is_active = data.get('is_active')

                cursor.execute('''
                    UPDATE message_templates 
                    SET template_name = COALESCE(?, template_name),
                        template_type = COALESCE(?, template_type),
                        template_content = COALESCE(?, template_content),
                        is_active = COALESCE(?, is_active),
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (name, t_type, content, is_active, template_id))
                conn.commit()
                conn.close()
                return jsonify({'success': True, 'message': 'تم تحديث القالب بنجاح'})

            elif request.method == 'DELETE':
                cursor.execute('DELETE FROM message_templates WHERE id = ?', (template_id,))
                conn.commit()
                conn.close()
                return jsonify({'success': True, 'message': 'تم حذف القالب بنجاح'})

        @self.app.route('/api/v1/settings', methods=['GET', 'PUT'])
        def api_v1_settings():
            """جلب وتحديث إعدادات النظام وتوقيت التنبيهات اليومية"""
            conn = sqlite3.connect('database.db')
            cursor = conn.cursor()

            if request.method == 'GET':
                cursor.execute('SELECT days_before_month_end, days_before_contract_end, send_hour, send_minute, send_period, monthly_message, contract_end_message FROM settings LIMIT 1')
                row = cursor.fetchone()
                conn.close()
                if not row:
                    return jsonify({'success': False, 'message': 'لا توجد إعدادات مسجلة'}), 404

                return jsonify({
                    'success': True,
                    'settings': {
                        'days_before_month_end': row[0],
                        'days_before_contract_end': row[1],
                        'send_hour': row[2],
                        'send_minute': row[3],
                        'send_period': row[4],
                        'monthly_message': row[5],
                        'contract_end_message': row[6],
                        'whats360_configured': bool(getattr(self.whats360_service, 'client_id', None) and getattr(self.whats360_service, 'api_key', None))
                    }
                })

            elif request.method == 'PUT':
                data = request.get_json(silent=True) or request.form
                days_month = data.get('days_before_month_end')
                days_contract = data.get('days_before_contract_end')
                send_hour = data.get('send_hour')
                send_minute = data.get('send_minute')
                send_period = data.get('send_period')
                monthly_msg = data.get('monthly_message')
                contract_msg = data.get('contract_end_message')

                cursor.execute('''
                    UPDATE settings 
                    SET days_before_month_end = COALESCE(?, days_before_month_end),
                        days_before_contract_end = COALESCE(?, days_before_contract_end),
                        send_hour = COALESCE(?, send_hour),
                        send_minute = COALESCE(?, send_minute),
                        send_period = COALESCE(?, send_period),
                        monthly_message = COALESCE(?, monthly_message),
                        contract_end_message = COALESCE(?, contract_end_message)
                    WHERE id = 1
                ''', (days_month, days_contract, send_hour, send_minute, send_period, monthly_msg, contract_msg))
                conn.commit()
                conn.close()
                return jsonify({'success': True, 'message': 'تم حفظ وتحديث الإعدادات بنجاح'})

        @self.app.route('/api/v1/settings/whats360-status', methods=['GET'])
        def api_v1_whats360_status():
            """فحص حالة اتصال بوابة Whats360"""
            status = self.whats360_service.check_account_status()
            return jsonify({'success': True, 'status': status})

        @self.app.route('/api/v1/docs', methods=['GET'])
        def api_v1_docs():
            """دليل توثيقي كامل لجميع نقاط نهاية API لتطبيق الموبايل"""
            return jsonify({
                'title': 'نظام مُستأجِر - REST API v1 Documentation',
                'version': '1.0.0',
                'base_url': request.host_url + 'api/v1',
                'endpoints': [
                    {'path': '/health', 'methods': ['GET'], 'description': 'فحص الاتصال وحالة السيرفر'},
                    {'path': '/auth/login', 'methods': ['POST'], 'description': 'تسجيل الدخول واستخراج Token المشرف'},
                    {'path': '/auth/profile', 'methods': ['GET', 'PUT'], 'description': 'جلب وتحديث الملف الشخصي للمشرف'},
                    {'path': '/auth/forgot-password', 'methods': ['POST'], 'description': 'استعادة وتعيين كلمة المرور'},
                    {'path': '/dashboard/stats', 'methods': ['GET'], 'description': 'إحصائيات لوحة التحكم والاشتراكات'},
                    {'path': '/tenants', 'methods': ['GET', 'POST'], 'description': 'قائمة المستأجرين مع البحث والفلترة، وإضافة مستأجر جديد'},
                    {'path': '/tenants/<id>', 'methods': ['GET', 'PUT', 'DELETE'], 'description': 'تفاصيل، تعديل، وحذف مستأجر'},
                    {'path': '/tenants/<id>/upload', 'methods': ['POST'], 'description': 'رفع صور ومستندات المستأجر (هوية، عقد، ترخيص، شيكات)'},
                    {'path': '/reports', 'methods': ['GET'], 'description': 'تقارير العقود المنتهية والقاربة على الانتهاء ومعدل التسليم'},
                    {'path': '/notifications/logs', 'methods': ['GET'], 'description': 'سجل الرسائل والتنبيهات الصادرة'},
                    {'path': '/notifications/send', 'methods': ['POST'], 'description': 'إرسال تنبيه واتساب مباشر لمستأجر'},
                    {'path': '/notifications/templates', 'methods': ['GET', 'POST'], 'description': 'عرض وإنشاء قوالب الرسائل'},
                    {'path': '/notifications/templates/<id>', 'methods': ['PUT', 'DELETE'], 'description': 'تعديل وحذف قالب'},
                    {'path': '/settings', 'methods': ['GET', 'PUT'], 'description': 'إعدادات النظام وأوقات التنبيه التلقائي'},
                    {'path': '/settings/whats360-status', 'methods': ['GET'], 'description': 'فحص حالة اتصال مزود Whats360'}
                ]
            })

        @self.app.route('/logout')
        def logout():
            session.pop('logged_in', None)
            return redirect(url_for('login'))
    
    def run(self, debug=True):
        self.app.run(debug=debug, port=8080)

if __name__ == '__main__':
    app = AdminApp()
    app.run()