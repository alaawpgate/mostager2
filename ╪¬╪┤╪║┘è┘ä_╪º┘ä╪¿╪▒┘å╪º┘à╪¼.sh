#!/bin/bash

# تعيين الترميز
export LC_ALL=en_US.UTF-8

clear
echo ""
echo "████████████████████████████████████████"
echo "         نظام إدارة المستأجرين"
echo "       تطبيق سطح المكتب المتكامل"
echo "████████████████████████████████████████"
echo ""

# التحقق من وجود Python
if ! command -v python3 &> /dev/null; then
    if ! command -v python &> /dev/null; then
        echo "❌ خطأ: Python غير مثبت"
        echo ""
        echo "💡 لتثبيت Python:"
        echo "   macOS: brew install python3"
        echo "   Ubuntu/Debian: sudo apt install python3 python3-pip"
        echo "   CentOS/RHEL: sudo yum install python3 python3-pip"
        echo ""
        read -p "اضغط Enter للخروج..."
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

echo "✅ تم العثور على Python"
$PYTHON_CMD --version

# التحقق من الملفات المطلوبة
if [ ! -f "main.py" ] && [ ! -f "desktop_app.py" ]; then
    echo "❌ خطأ: ملفات التطبيق غير موجودة"
    read -p "اضغط Enter للخروج..."
    exit 1
fi

echo "✅ ملفات التطبيق موجودة"

# تحديد Python المستخدم
if [ -f "venv/bin/python" ]; then
    echo "✅ استخدام البيئة الافتراضية"
    PYTHON_CMD="venv/bin/python"
else
    echo "⚠️  استخدام Python العام"
fi

# التحقق من المتطلبات
echo ""
echo "📦 التحقق من المتطلبات..."
$PYTHON_CMD -c "import webview, flask" &> /dev/null
if [ $? -ne 0 ]; then
    echo "📥 تثبيت المكتبات المطلوبة..."
    $PYTHON_CMD -m pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "❌ فشل في تثبيت المتطلبات"
        read -p "اضغط Enter للخروج..."
        exit 1
    fi
fi

echo "✅ جميع المتطلبات متوفرة"

echo ""
echo "🚀 بدء تشغيل التطبيق..."
echo "🖥️  سيتم فتح نافذة البرنامج..."
echo "⏹️  لإغلاق البرنامج: أغلق النافذة"
echo ""
echo "████████████████████████████████████████"
echo ""

# تشغيل التطبيق
if [ -f "main.py" ]; then
    $PYTHON_CMD main.py
elif [ -f "desktop_app.py" ]; then
    $PYTHON_CMD desktop_app.py
else
    $PYTHON_CMD run_desktop_app.py
fi

echo ""
echo "✅ تم إغلاق التطبيق"
echo "شكراً لاستخدام نظام إدارة المستأجرين"
echo ""