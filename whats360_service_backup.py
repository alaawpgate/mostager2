import requests
import json

class Whats360Service:
    def __init__(self, client_id, api_key):
        self.client_id = client_id
        self.api_key = api_key
        self.base_url = "https://apis.whats360.live/api/user/v2"
        
        self.headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}',
        }
        
        print(f"Whats360 Service initialized:")
        print(f"  Client ID: {client_id}")
        print(f"  API Key: {api_key[:20]}...")
        print(f"  Base URL: {self.base_url}")
    
    def send_text_message(self, mobile, text):
        """
        Send a text message via Whats360 API
        """
        url = f"{self.base_url}/send_message"
        body = {
            'client_id': self.client_id,
            'mobile': mobile,
            'text': text
        }
        
        try:
            print(f"Whats360 Debug - Making request to: {url}")
            print(f"Whats360 Debug - Headers: {self.headers}")
            print(f"Whats360 Debug - Body: {body}")
            
            response = requests.post(url, headers=self.headers, json=body, timeout=30)
            
            print(f"Whats360 Debug - Response Status: {response.status_code}")
            print(f"Whats360 Debug - Response Text: {response.text}")
            
            if response.ok:
                try:
                    data = response.json()
                    print(f"[DEBUG] API Response JSON: {data}")
                    
                    if data.get('success'):
                        return {
                            'success': True,
                            'message': data.get('message', 'Message sent successfully'),
                            'data': data
                        }
                    else:
                        # Handle specific error messages
                        error_msg = data.get('message') or data.get('msg') or data.get('error')
                        if 'credits' in str(error_msg).lower():
                            return {
                                'success': False,
                                'error': 'رصيد غير كافي في حساب Whats360. يرجى شحن الرصيد.',
                                'data': data
                            }
                        else:
                            return {
                                'success': False,
                                'error': error_msg or f'فشل في الإرسال: {data}',
                                'data': data
                            }
                except:
                    if response.status_code == 200:
                        return {
                            'success': True,
                            'message': 'Message sent successfully',
                            'data': {'response': response.text}
                        }
                    else:
                        return {
                            'success': False,
                            'error': f'استجابة غير متوقعة: {response.text}',
                            'data': {}
                        }
            else:
                return {
                    'success': False,
                    'error': f'خطأ HTTP {response.status_code}: {response.text}',
                    'status_code': response.status_code
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': f'خطأ في الاتصال: {str(e)}',
                'exception': str(e)
            }

    def send_text_message_url(self, mobile, text):
        """
        Send a text message via Whats360 API using GET method with URL parameters
        """
        url = f"{self.base_url}/send_message_url"
        
        params = {
            'client_id': self.client_id,
            'mobile': mobile,
            'text': text,
            'token': self.api_key
        }
        
        try:
            print(f"Whats360 Debug - Making GET request to: {url}")
            print(f"Whats360 Debug - Params: {params}")
            
            response = requests.get(url, params=params, timeout=30)
            
            print(f"Whats360 Debug - URL Response Status: {response.status_code}")
            print(f"Whats360 Debug - URL Response Text: {response.text}")
            
            if response.ok:
                try:
                    data = response.json()
                    print(f"[DEBUG] URL API Response JSON: {data}")
                    
                    if data.get('success') or data.get('status') == 'success' or response.status_code == 200:
                        return {
                            'success': True,
                            'message': data.get('message', 'Message sent successfully (URL method)'),
                            'data': data
                        }
                    else:
                        return {
                            'success': False,
                            'error': data.get('message') or data.get('msg') or data.get('error') or f'URL method failed: {data}',
                            'data': data
                        }
                except:
                    if response.status_code == 200:
                        return {
                            'success': True,
                            'message': 'Message sent successfully (URL method)',
                            'data': {'response': response.text}
                        }
                    else:
                        return {
                            'success': False,
                            'error': f'URL method non-JSON response: {response.text}',
                            'data': {}
                        }
            else:
                return {
                    'success': False,
                    'error': f'URL method HTTP {response.status_code}: {response.text}',
                    'status_code': response.status_code
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': f'URL method error: {str(e)}',
                'exception': str(e)
            }

    def send_rental_reminder(self, mobile, tenant_name):
        """
        Send rental payment reminder message
        """
        # Clean phone number
        if mobile.startswith('0'):
            mobile = '20' + mobile[1:]
        elif not mobile.startswith('20'):
            mobile = '20' + mobile
            
        print(f"[DEBUG] Cleaned phone number: {mobile}")
        
        reminder_text = f"""🏠 تذكير بدفع الإيجار

عزيزي/عزيزتي {tenant_name}،

نذكركم بأن موعد دفع الإيجار قد حان.
يرجى سداد المبلغ في أقرب وقت ممكن.

شكراً لتعاونكم
إدارة العقارات"""
        
        # Try first method
        result = self.send_text_message(mobile, reminder_text)
        print(f"[DEBUG] First method result: {result}")
        
        if not result.get('success'):
            print("[DEBUG] First method failed, trying URL method")
            result = self.send_text_message_url(mobile, reminder_text)
            print(f"[DEBUG] URL method result: {result}")
        
        return result

    def send_contract_expiry_reminder(self, mobile, tenant_name, expiry_date):
        """
        Send contract expiry reminder message
        """
        # Clean phone number
        if mobile.startswith('0'):
            mobile = '20' + mobile[1:]
        elif not mobile.startswith('20'):
            mobile = '20' + mobile
            
        print(f"[DEBUG] Cleaned phone number: {mobile}")
        
        expiry_text = f"""⚠️ تنبيه انتهاء العقد

عزيزي/عزيزتي {tenant_name}،

نود إعلامكم بأن عقد الإيجار سينتهي في: {expiry_date}

يرجى التواصل معنا لتجديد العقد أو ترتيب إجراءات التسليم.

شكراً لتعاونكم
إدارة العقارات"""
        
        # Try first method
        result = self.send_text_message(mobile, expiry_text)
        print(f"[DEBUG] First method result: {result}")
        
        if not result.get('success'):
            print("[DEBUG] First method failed, trying URL method")
            result = self.send_text_message_url(mobile, expiry_text)
            print(f"[DEBUG] URL method result: {result}")
        
        return result

    def send_welcome_message(self, mobile, tenant_name):
        """
        Send welcome message to new tenant
        """
        # Clean phone number
        if mobile.startswith('0'):
            mobile = '20' + mobile[1:]
        elif not mobile.startswith('20'):
            mobile = '20' + mobile
            
        welcome_text = f"""🏠 مرحباً بك في عقاراتنا

عزيزي/عزيزتي {tenant_name}،

نرحب بك كمستأجر جديد في عقاراتنا.

نتمنى لك إقامة سعيدة ومريحة.

في حالة وجود أي استفسارات، لا تتردد في التواصل معنا.

شكراً لاختيارك لنا

إدارة العقارات
        """.strip()
        
        return self.send_text_message(mobile, welcome_text)