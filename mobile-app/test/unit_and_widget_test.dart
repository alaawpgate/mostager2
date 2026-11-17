import 'package:flutter_test/flutter_test.dart';
import 'package:mostager_app/models/tenant_model.dart';
import 'package:mostager_app/models/notification_model.dart';
import 'package:mostager_app/models/settings_model.dart';

void main() {
  group('TenantModel Tests', () {
    test('JSON deserialization and initialLetter', () {
      final json = {
        'id': 101,
        'tenant_name': 'سعيد الغامدي',
        'tenant_phone': '0555123456',
        'start_date': '2025-01-01',
        'end_date': '2030-01-01',
        'contract_type': 'سكني',
        'notes': 'شقة رقم 4',
      };

      final tenant = TenantModel.fromJson(json);

      expect(tenant.id, 101);
      expect(tenant.name, 'سعيد الغامدي');
      expect(tenant.phone, '0555123456');
      expect(tenant.initialLetter, 'س');
      expect(tenant.contractType, 'سكني');
      expect(tenant.isExpired, isFalse);
    });

    test('Expired contract check', () {
      final json = {
        'id': 102,
        'name': 'عبدالرحمن الشهري',
        'phone': '0501112233',
        'start_date': '2020-01-01',
        'end_date': '2021-01-01',
        'contract_type': 'تجاري',
      };

      final tenant = TenantModel.fromJson(json);
      expect(tenant.isExpired, isTrue);
      expect(tenant.remainingDays, isNotNull);
      expect(tenant.remainingDays! < 0, isTrue);
    });

    test('JSON serialization toJson()', () {
      final tenant = TenantModel(
        id: 1,
        name: 'فيصل بن خالد',
        phone: '0544445555',
        startDate: '2025-05-01',
        endDate: '2026-05-01',
        contractType: 'سكني',
        notes: 'ملاحظة خاصة',
      );

      final map = tenant.toJson();
      expect(map['tenant_name'], 'فيصل بن خالد');
      expect(map['tenant_phone'], '0544445555');
      expect(map['contract_type'], 'سكني');
      expect(map['notes'], 'ملاحظة خاصة');
    });

    test('Full Tenancy Contract structured fields parsing', () {
      final json = {
        'id': 200,
        'tenant_name': 'علاء مصطفي',
        'tenant_phone': '01009931190',
        'start_date': '20/7/2024',
        'end_date': '21/4/2025',
        'contract_type': 'جديد',
        'unit_usage': 'Family Residence',
        'unit_number': '504',
        'property_number': 'PROPA56720313',
        'location': 'TOWN CENTER',
        'block_number': 'A',
        'plot_number': '5',
        'unit_type': '3 BHK',
        'contract_number': 'RENT25061768',
        'rent_amount': '28000.00',
        'payment_count': 12,
        'check_images': 'check1.jpg,check2.jpg',
        'lessor_name': 'علاء مصطفي',
      };

      final tenant = TenantModel.fromJson(json);
      expect(tenant.unitNumber, '504');
      expect(tenant.propertyNumber, 'PROPA56720313');
      expect(tenant.location, 'TOWN CENTER');
      expect(tenant.unitType, '3 BHK');
      expect(tenant.rentAmount, 28000.0);
      expect(tenant.paymentCount, 12);
      expect(tenant.checkCount, 2);
      expect(tenant.checkImagesList.length, 2);
      expect(tenant.formattedRentAmount, '28000 درهم');
      expect(tenant.displayUnitInfo, contains('وحدة 504'));
      expect(tenant.displayUnitInfo, contains('PROPA56720313'));
    });
  });

  group('Notification & Template Models Tests', () {
    test('NotificationLogModel parsing and status check', () {
      final json = {
        'id': 42,
        'tenant_name': 'خالد محمد',
        'notification_type': 'تنبيه استحقاق إيجار',
        'status': 'نجح',
        'sent_at': '2026-05-01 10:00:00',
        'phone_number': '0500000000',
        'message_content': 'نود تذكيركم بموعد الإيجار',
      };

      final log = NotificationLogModel.fromJson(json);
      expect(log.id, 42);
      expect(log.tenantName, 'خالد محمد');
      expect(log.isSuccess, isTrue);
    });

    test('NotificationLogModel failure with details does not crash', () {
      final json = {
        'id': 112,
        'tenant_name': 'علاء مصطفي',
        'notification_type': 'تذكير شهري تلقائي',
        'status': 'فشل',
        'raw_status': 'فشل - فشل في جميع طرق الإرسال (3 طرق × تنسيقات متعددة)',
        'status_details': 'فشل - فشل في جميع طرق الإرسال (3 طرق × تنسيقات متعددة)',
        'sent_at': '2026-11-16 12:59:06',
        'phone_number': '0501112233',
        'message_content': 'رسالة تجريبية',
      };

      final log = NotificationLogModel.fromJson(json);
      expect(log.isSuccess, isFalse);
      expect(log.status, 'فشل');
      expect(log.statusDetails, contains('فشل في جميع طرق الإرسال'));
    });

    test('MessageTemplateModel serialization', () {
      final template = MessageTemplateModel(
        id: 3,
        name: 'قالب نهاية العقد',
        type: 'عقود',
        content: 'عقدك سينتهي قريباً',
        isActive: true,
      );

      final map = template.toJson();
      expect(map['name'], 'قالب نهاية العقد');
      expect(map['is_active'], 1);
    });
  });

  group('SystemSettingsModel Tests', () {
    test('SystemSettingsModel parsing and JSON mapping', () {
      final json = {
        'days_before_month_end': 7,
        'days_before_contract_end': 45,
        'send_hour': 11,
        'send_minute': 30,
        'send_period': 'AM',
        'monthly_message': 'تذكير إيجار',
        'contract_end_message': 'تذكير عقد',
        'whats360_configured': true,
      };

      final settings = SystemSettingsModel.fromJson(json);
      expect(settings.daysBeforeMonthEnd, 7);
      expect(settings.daysBeforeContractEnd, 45);
      expect(settings.whats360Configured, isTrue);

      final out = settings.toJson();
      expect(out['days_before_month_end'], 7);
      expect(out['send_hour'], 11);
    });
  });
}
