import requests
import json
import base64

class Whats360Service:
    def __init__(self, client_id, api_key):
        self.client_id = client_id
        self.api_key = api_key
        self.base_url = "https://apis.whats360.live/api/user/v2"
        
        self.headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}',
        }
        
        print(f"✅ Whats360 Service initialized")
    
    def send_text_message(self, mobile, text):
        """
        إرسال رسالة نصية عبر Whats360 API
        """
        print(f"📱 إرسال رسالة إلى: {mobile}")
        
        # تحويل الرقم للشكل المحلي إذا كان يبدأ بـ 20
        if mobile.startswith('20') and len(mobile) == 13:
            mobile = '0' + mobile[2:]
            print(f"📱 تم تحويل الرقم إلى: {mobile}")
        
        url = f"{self.base_url}/send_message"
        body = {
            'client_id': self.client_id,
            'mobile': mobile,
            'text': text
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=body, timeout=30)
            print(f"📡 استجابة API: {response.status_code}")
            print(f"📡 محتوى الاستجابة: {response.text}")
            
            if response.ok:
                data = response.json()
                if data.get('success'):
                    return {
                        'success': True, 
                        'message': '✅ تم إرسال الرسالة بنجاح!',
                        'data': data
                    }
                else:
                    error_msg = data.get('msg', 'خطأ غير معروف')
                    if 'credit' in error_msg.lower() or 'dont have credits' in error_msg.lower():
                        return {
                            'success': False, 
                            'error': '❌ الرصيد غير كافي في حساب Whats360. يرجى شحن الرصيد من الموقع الرسمي.'
                        }
                    else:
                        return {
                            'success': False, 
                            'error': f'❌ فشل الإرسال: {error_msg}'
                        }
            else:
                return {
                    'success': False, 
                    'error': f'❌ خطأ HTTP: {response.status_code}'
                }
                
        except requests.exceptions.Timeout:
            return {'success': False, 'error': '❌ انتهت مهلة الاتصال'}
        except requests.exceptions.ConnectionError:
            return {'success': False, 'error': '❌ خطأ في الاتصال بالإنترنت'}
        except Exception as e:
            return {'success': False, 'error': f'❌ خطأ: {str(e)}'}
    
    def send_text_message_url(self, mobile, text):
        """
        إرسال رسالة نصية عبر GET method (طريقة بديلة)
        """
        print(f"📱 إرسال رسالة (GET) إلى: {mobile}")
        
        # استخراج الـ UID من الـ client_id
        try:
            decoded = base64.b64decode(self.client_id + '==')
            client_data = json.loads(decoded)
            uid = client_data.get('uid', self.client_id)
        except:
            uid = self.client_id
        
        # تحويل الرقم للشكل المحلي إذا كان يبدأ بـ 20
        if mobile.startswith('20') and len(mobile) == 13:
            mobile = '0' + mobile[2:]
            print(f"📱 تم تحويل الرقم إلى: {mobile}")
        
        url = f"{self.base_url}/send_message_url"
        params = {
            'client_id': uid,
            'mobile': mobile,
            'text': text,
            'token': self.api_key
        }
        
        try:
            response = requests.get(url, params=params, timeout=30)
            print(f"📡 استجابة API (GET): {response.status_code}")
            print(f"📡 محتوى الاستجابة: {response.text}")
            
            if response.ok:
                data = response.json()
                if data.get('success'):
                    return {
                        'success': True, 
                        'message': '✅ تم إرسال الرسالة بنجاح (GET)!',
                        'data': data
                    }
                else:
                    error_msg = data.get('msg', 'خطأ غير معروف')
                    if 'credit' in error_msg.lower() or 'dont have credits' in error_msg.lower():
                        return {
                            'success': False, 
                            'error': '❌ الرصيد غير كافي في حساب Whats360. يرجى شحن الرصيد من الموقع الرسمي.'
                        }
                    else:
                        return {
                            'success': False, 
                            'error': f'❌ فشل الإرسال (GET): {error_msg}'
                        }
            else:
                return {
                    'success': False, 
                    'error': f'❌ خطأ HTTP (GET): {response.status_code}'
                }
                
        except Exception as e:
            return {'success': False, 'error': f'❌ خطأ (GET): {str(e)}'}
    
    def send_text_message_v3(self, mobile, text):
        """
        طريقة ثالثة لإرسال الرسائل - تجربة endpoints مختلفة
        """
        print(f"📱 إرسال رسالة (طريقة ثالثة) إلى: {mobile}")
        
        # تجربة endpoints مختلفة
        endpoints = [
            {'url': f"{self.base_url}/send_message", 'method': 'POST'},
            {'url': f"{self.base_url}/sendMessage", 'method': 'POST'},
            {'url': f"{self.base_url}/send", 'method': 'POST'},
            {'url': f"{self.base_url}/message/send", 'method': 'POST'},
            {'url': "https://api.whats360.live/v1/send", 'method': 'POST'},
        ]
        
        for endpoint in endpoints:
            try:
                print(f"📡 تجربة endpoint: {endpoint['url']}")
                
                # تجربة تنسيقات مختلفة للبيانات
                payloads = [
                    {
                        'client_id': self.client_id,
                        'mobile': mobile,
                        'text': text
                    },
                    {
                        'clientId': self.client_id,
                        'phone': mobile,
                        'message': text
                    },
                    {
                        'client_id': self.client_id,
                        'phone_number': mobile,
                        'message_text': text
                    },
                    {
                        'uid': self.client_id,
                        'mobile': mobile,
                        'text': text,
                        'token': self.api_key
                    }
                ]
                
                for i, payload in enumerate(payloads):
                    print(f"📡 تجربة payload {i+1}: {payload}")
                    
                    response = requests.post(
                        endpoint['url'], 
                        headers=self.headers, 
                        json=payload, 
                        timeout=30
                    )
                    
                    print(f"📡 استجابة {endpoint['url']} (payload {i+1}): {response.status_code}")
                    print(f"📡 محتوى الاستجابة: {response.text}")
                    
                    if response.ok:
                        try:
                            data = response.json()
                            if data.get('success') or data.get('status') == 'success':
                                return {
                                    'success': True,
                                    'message': '✅ تم إرسال الرسالة بنجاح (طريقة ثالثة)!',
                                    'data': data,
                                    'endpoint_used': endpoint['url'],
                                    'payload_used': i+1
                                }
                        except json.JSONDecodeError:
                            continue
                            
            except Exception as e:
                print(f"[ERROR] خطأ في endpoint {endpoint['url']}: {str(e)}")
                continue
        
        return {
            'success': False,
            'error': '❌ فشل في جميع endpoints الجديدة'
        }
    
    def check_account_status(self):
        """
        التحقق من حالة الحساب والرصيد المتاح
        """
        print(f"🔍 فحص حالة الحساب...")
        
        url = f"{self.base_url}/account_status"
        body = {
            'client_id': self.client_id
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=body, timeout=30)
            print(f"📡 استجابة فحص الحساب: {response.status_code}")
            print(f"📡 محتوى الاستجابة: {response.text}")
            
            if response.ok:
                data = response.json()
                return {
                    'success': True,
                    'data': data,
                    'endpoint': url
                }
            else:
                return {
                    'success': False,
                    'error': f'❌ خطأ HTTP: {response.status_code}',
                    'endpoint': url
                }
                
        except Exception as e:
            return {'success': False, 'error': f'❌ خطأ: {str(e)}', 'endpoint': url}
    
    def get_account_balance(self):
        """
        الحصول على رصيد الحساب
        """
        print(f"💰 فحص رصيد الحساب...")
        
        # محاولة طرق مختلفة لفحص الرصيد
        methods = [
            {'url': f"{self.base_url}/balance", 'method': 'POST', 'body': {'client_id': self.client_id}},
            {'url': f"{self.base_url}/account_balance", 'method': 'POST', 'body': {'client_id': self.client_id}},
            {'url': f"{self.base_url}/user_balance", 'method': 'GET', 'params': {'client_id': self.client_id, 'token': self.api_key}}
        ]
        
        for i, method in enumerate(methods, 1):
            try:
                print(f"💰 محاولة الطريقة {i}: {method['url']}")
                
                if method['method'] == 'POST':
                    response = requests.post(method['url'], headers=self.headers, json=method['body'], timeout=30)
                else:
                    response = requests.get(method['url'], params=method['params'], timeout=30)
                
                print(f"📡 استجابة فحص الرصيد (طريقة {i}): {response.status_code}")
                print(f"📡 محتوى الاستجابة: {response.text}")
                
                if response.ok:
                    try:
                        data = response.json()
                        if data.get('success'):
                            balance = data.get('balance', data.get('credit', 0))
                            return {
                                'success': True,
                                'balance': balance,
                                'message': f'💰 الرصيد المتاح: {balance}',
                                'data': data,
                                'method_used': i
                            }
                        elif i == len(methods):  # آخر محاولة
                            return {
                                'success': False,
                                'error': data.get('msg', data.get('message', 'فشل في الحصول على الرصيد'))
                            }
                    except json.JSONDecodeError:
                        if i == len(methods):
                            return {
                                'success': False,
                                'error': 'استجابة غير صحيحة من الخادم'
                            }
                        continue
                elif i == len(methods):  # آخر محاولة
                    return {
                        'success': False,
                        'error': f'❌ خطأ HTTP: {response.status_code}'
                    }
                    
            except Exception as e:
                if i == len(methods):  # آخر محاولة
                    return {'success': False, 'error': f'❌ خطأ: {str(e)}'}
                continue
        
        return {'success': False, 'error': 'فشل في جميع طرق فحص الرصيد'}
    
    def diagnose_connection(self):
        """
        تشخيص شامل لحالة الاتصال والحساب
        """
        print(f"🔍 بدء التشخيص الشامل...")
        
        results = {
            'client_id_valid': False,
            'api_key_valid': False,
            'connection_ok': False,
            'balance_available': False,
            'balance_amount': 0,
            'errors': []
        }
        
        # فحص صحة Client ID
        try:
            if self.client_id and len(self.client_id) > 10:
                results['client_id_valid'] = True
            else:
                results['errors'].append('Client ID غير صحيح أو فارغ')
        except:
            results['errors'].append('خطأ في فحص Client ID')
        
        # فحص صحة API Key
        try:
            if self.api_key and len(self.api_key) > 20:
                results['api_key_valid'] = True
            else:
                results['errors'].append('API Key غير صحيح أو فارغ')
        except:
            results['errors'].append('خطأ في فحص API Key')
        
        # فحص الاتصال
        try:
            url = f"{self.base_url}/test"
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                results['connection_ok'] = True
            else:
                results['errors'].append(f'فشل الاتصال: HTTP {response.status_code}')
        except Exception as e:
            results['errors'].append(f'خطأ في الاتصال: {str(e)}')
        
        # فحص الرصيد
        balance_result = self.get_account_balance()
        if balance_result.get('success'):
            results['balance_available'] = True
            results['balance_amount'] = balance_result.get('balance', 0)
        else:
            results['errors'].append(f"فشل فحص الرصيد: {balance_result.get('error', 'خطأ غير معروف')}")
        
        return results
    
    def send_text_message_alternative(self, mobile, text):
        """
        طريقة بديلة لإرسال الرسائل مع تشخيص أفضل
        """
        print(f"📱 إرسال رسالة (طريقة بديلة) إلى: {mobile}")
        
        # تجربة تنسيقات مختلفة للرقم
        phone_formats = []
        
        # تنظيف الرقم الأساسي
        clean_mobile = mobile.strip()
        
        # إضافة تنسيقات مختلفة
        if clean_mobile.startswith('20') and len(clean_mobile) == 13:
            phone_formats.append('0' + clean_mobile[2:])  # 01xxxxxxxxx
            phone_formats.append(clean_mobile)  # 201xxxxxxxxx
            phone_formats.append('+' + clean_mobile)  # +201xxxxxxxxx
        elif clean_mobile.startswith('01') and len(clean_mobile) == 11:
            phone_formats.append(clean_mobile)  # 01xxxxxxxxx
            phone_formats.append('20' + clean_mobile[1:])  # 201xxxxxxxxx
            phone_formats.append('+20' + clean_mobile[1:])  # +201xxxxxxxxx
        else:
            phone_formats.append(clean_mobile)
        
        print(f"📱 تنسيقات الأرقام للاختبار: {phone_formats}")
        
        results = []
        
        # تجربة كل تنسيق مع كل طريقة
        for i, phone_format in enumerate(phone_formats):
            print(f"📱 اختبار التنسيق {i+1}: {phone_format}")
            
            # محاولة الطريقة الأولى (POST)
            result1 = self.send_text_message(phone_format, text)
            if result1.get('success'):
                print(f"✅ نجح الإرسال بالتنسيق: {phone_format} (POST)")
                return result1
            
            results.append(f"POST مع {phone_format}: {result1.get('error')}")
            
            # محاولة الطريقة الثانية (GET)
            result2 = self.send_text_message_url(phone_format, text)
            if result2.get('success'):
                print(f"✅ نجح الإرسال بالتنسيق: {phone_format} (GET)")
                return result2
            
            results.append(f"GET مع {phone_format}: {result2.get('error')}")
            
            # محاولة الطريقة الثالثة (endpoints مختلفة)
            result3 = self.send_text_message_v3(phone_format, text)
            if result3.get('success'):
                print(f"✅ نجح الإرسال بالتنسيق: {phone_format} (طريقة ثالثة)")
                return result3
            
            results.append(f"طريقة ثالثة مع {phone_format}: {result3.get('error')}")
        
        print(f"[DEBUG] فشل جميع المحاولات")
        
        # إذا فشلت جميع المحاولات، قم بالتشخيص
        diagnosis = self.diagnose_connection()
        
        return {
            'success': False,
            'error': 'فشل في جميع طرق الإرسال (3 طرق × تنسيقات متعددة)',
            'details': results,
            'diagnosis': diagnosis,
            'phone_formats_tried': phone_formats
        }