#!/usr/bin/env python3

from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <html>
    <head>
        <title>نظام إدارة المستأجرين</title>
        <meta charset="utf-8">
    </head>
    <body>
        <h1>نظام إدارة المستأجرين</h1>
        <p>الخادم يعمل بنجاح!</p>
        <a href="/test">اختبار</a>
    </body>
    </html>
    '''

@app.route('/test')
def test():
    return '<h2>الاختبار نجح!</h2><a href="/">العودة</a>'

if __name__ == '__main__':
    print("Starting basic server...")
    print("URL: http://127.0.0.1:8080")
    app.run(host='127.0.0.1', port=8080, debug=True)