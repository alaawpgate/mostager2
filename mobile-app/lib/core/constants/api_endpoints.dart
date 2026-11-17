import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  // Default development Base URL
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8080/api/v1';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 maps to host localhost in Android emulator
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://127.0.0.1:8080/api/v1';
  }

  static String get uploadsBase {
    final base = defaultBaseUrl.replaceAll('/api/v1', '');
    return '$base/static/uploads';
  }

  static String resolveUploadUrl(String? filename, {String? customBaseUrl}) {
    if (filename == null || filename.isEmpty || filename == 'null') return '';
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    final root = (customBaseUrl ?? defaultBaseUrl).replaceAll('/api/v1', '');
    if (filename == 'avatar.png') {
      return '$root/static/avatar.png';
    }
    return '$root/static/uploads/$filename';
  }

  // Auth
  static const String login = '/auth/login';
  static const String profile = '/auth/profile';
  static const String forgotPassword = '/auth/forgot-password';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';

  // Tenants
  static const String tenants = '/tenants';
  static String tenantDetail(int id) => '/tenants/$id';
  static String tenantUpload(int id) => '/tenants/$id/upload';

  // Reports
  static const String reports = '/reports';

  // Notifications
  static const String notificationLogs = '/notifications/logs';
  static const String sendNotification = '/notifications/send';
  static const String notificationTemplates = '/notifications/templates';

  // Settings
  static const String settings = '/settings';
  static const String whats360Status = '/settings/whats360-status';
}
