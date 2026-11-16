
# إعدادات Whats360 API
# يجب تحديث هذه القيم بالقيم الفعلية من حسابك في Whats360
WHATS360_CLIENT_ID = 'eyJ1aWQiOiJtWUhGaEdJN1c5Z0RaSzI0SmxCNHM5T3JScXB6OFRXWiIsImNsaWVudF9pZCI6ImFsYWEifQ=='
WHATS360_API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJtWUhGaEdJN1c5Z0RaSzI0SmxCNHM5T3JScXB6OFRXWiIsInJvbGUiOiJ1c2VyIiwiaWF0IjoxNzUzNjIxOTYxfQ.9c10gQhwKrwwwnz8RdS9EWKXSp_LMa3ejFac919Q1pU'

# إعدادات عامة للتطبيق
ADMIN_USERNAME = 'admin'
ADMIN_PASSWORD = 'admin123'
SECRET_KEY = 'your-secret-key-here'

# إعدادات قاعدة البيانات
DATABASE_NAME = 'database.db'

# إعدادات الملفات المرفوعة
UPLOAD_FOLDER = 'static/uploads'
MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB

# رسائل افتراضية للإشعارات
DEFAULT_RENTAL_REMINDER = """
🏠 تذكير بدفع الإيجار

عزيزي/عزيزتي {{name}}،

نذكركم بأن موعد دفع الإيجار قد حان.
يرجى سداد المبلغ في أقرب وقت ممكن.

شكراً لتعاونكم
إدارة العقارات
"""

DEFAULT_CONTRACT_EXPIRY = """
📋 تذكير بانتهاء العقد

عزيزي/عزيزتي {{name}}،

نود إعلامكم بأن عقد الإيجار سينتهي في {{end_date}}.
يرجى التواصل معنا لتجديد العقد أو ترتيب إجراءات التسليم.

شكراً لتعاونكم
إدارة العقارات
"""

# رسائل إضافية للنظام المحسن
DEFAULT_WELCOME_MESSAGE = """
🎉 مرحباً بك في إدارة العقارات

عزيزي/عزيزتي {{name}}،

نرحب بك كمستأجر جديد لدينا.
نتمنى لك إقامة مريحة وسعيدة.

للاستفسارات والدعم الفني، يرجى التواصل معنا.

مع أطيب التحيات
إدارة العقارات
"""

DEFAULT_PAYMENT_CONFIRMATION = """
✅ تأكيد استلام الدفعة

عزيزي/عزيزتي {{name}}،

تم استلام دفعة الإيجار بنجاح.
المبلغ: {{amount}}
التاريخ: {{date}}

شكراً لالتزامكم بمواعيد السداد.

إدارة العقارات
"""

DEFAULT_MAINTENANCE_REQUEST = """
🔧 طلب صيانة

عزيزي/عزيزتي {{name}}،

تم استلام طلب الصيانة الخاص بكم.
سيتم التواصل معكم قريباً لتحديد موعد الصيانة.

نوع الطلب: {{request_type}}
الوصف: {{description}}

إدارة العقارات
"""

DEFAULT_CUSTOM_MESSAGE = """
📢 رسالة من إدارة العقارات

عزيزي/عزيزتي {{name}}،

{{message_content}}

مع أطيب التحيات
إدارة العقارات
"""

# أنواع الرسائل المتاحة
MESSAGE_TYPES = {
    'rental_reminder': 'تذكير إيجار',
    'contract_expiry': 'انتهاء عقد',
    'welcome': 'ترحيب',
    'payment_confirmation': 'تأكيد دفع',
    'maintenance_request': 'طلب صيانة',
    'custom': 'رسالة مخصصة',
    'general': 'عام'
}