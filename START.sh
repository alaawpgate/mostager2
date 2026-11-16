#!/bin/bash

echo ""
echo "🏠 نظام إدارة المستأجرين"
echo "========================"
echo "🖥️  تشغيل كبرنامج سطح مكتب"
echo ""

# تشغيل مع البيئة الافتراضية إذا كانت موجودة
if [ -f "venv/bin/python" ]; then
    echo "✅ استخدام البيئة الافتراضية"
    echo "🚀 بدء تشغيل البرنامج..."
    venv/bin/python main.py
elif command -v python3 &> /dev/null; then
    echo "⚠️  استخدام Python3 العام"
    echo "🚀 بدء تشغيل البرنامج..."
    python3 main.py
else
    echo "⚠️  استخدام Python العام"
    echo "🚀 بدء تشغيل البرنامج..."
    python main.py
fi

echo ""
echo "✅ تم إغلاق البرنامج"