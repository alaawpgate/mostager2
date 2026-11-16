#!/bin/bash

echo ""
echo "🏠 نظام إدارة المستأجرين"
echo "🖥️  تطبيق سطح المكتب"
echo "========================"
echo ""

if [ -f "venv/bin/python" ]; then
    echo "✅ تشغيل البرنامج..."
    venv/bin/python تشغيل.py
elif command -v python3 &> /dev/null; then
    echo "✅ تشغيل البرنامج..."
    python3 تشغيل.py
else
    echo "✅ تشغيل البرنامج..."
    python تشغيل.py
fi

echo ""