#!/bin/bash

# تعيين الترميز
export LC_ALL=en_US.UTF-8

echo ""
echo "========================================"
echo "       نظام إدارة المستأجرين"
echo "========================================"
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
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

echo "✅ تم العثور على Python"
$PYTHON_CMD --version

# التحقق من وجود الملفات المطلوبة
if [ ! -f "app.py" ]; then
    echo "❌ خطأ: ملف app.py غير موجود"
    exit 1
fi

if [ ! -f "config.py" ]; then
    echo "❌ خطأ: ملف config.py غير موجود"
    exit 1
fi

echo "✅ تم العثور على الملفات المطلوبة"

# التحقق من البيئة الافتراضية
if [ -f "venv/bin/python" ]; then
    echo "✅ استخدام البيئة الافتراضية"
    PYTHON_CMD="venv/bin/python"
else
    echo "⚠️  استخدام Python العام"
fi

# تثبيت المتطلبات
echo ""
echo "📦 تثبيت/تحديث المتطلبات..."
$PYTHON_CMD -m pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "❌ خطأ في تثبيت المتطلبات"
    exit 1
fi

echo ""
echo "🚀 بدء تشغيل النظام..."
echo "📍 العنوان: http://localhost:8080"
echo "⏹️  للإيقاف: اضغط Ctrl+C"
echo "========================================"
echo ""

# تشغيل التطبيق
$PYTHON_CMD run_project.py

echo ""
echo "✅ تم إنهاء التطبيق"