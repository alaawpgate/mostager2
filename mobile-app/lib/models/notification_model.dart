class NotificationLogModel {
  final int id;
  final String tenantName;
  final String notificationType;
  final String status;
  final String rawStatus;
  final String statusDetails;
  final String? sentAt;
  final String phoneNumber;
  final String messageContent;

  NotificationLogModel({
    required this.id,
    required this.tenantName,
    required this.notificationType,
    required this.status,
    this.rawStatus = '',
    this.statusDetails = '',
    this.sentAt,
    required this.phoneNumber,
    required this.messageContent,
  });

  factory NotificationLogModel.fromJson(Map<String, dynamic> json) {
    final raw = json['raw_status']?.toString() ?? json['status']?.toString() ?? '';
    final isOk = raw.contains('نجح') || raw.toLowerCase().contains('success');
    final cleanStatus = isOk ? 'نجح' : 'فشل';
    final details = json['status_details']?.toString() ?? (raw != cleanStatus ? raw : '');

    return NotificationLogModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      tenantName: json['tenant_name']?.toString() ?? 'مستأجر',
      notificationType: json['notification_type']?.toString() ?? 'إشعار',
      status: json['status']?.toString() ?? cleanStatus,
      rawStatus: raw,
      statusDetails: details,
      sentAt: json['sent_at']?.toString(),
      phoneNumber: json['phone_number']?.toString() ?? '',
      messageContent: json['message_content']?.toString() ?? '',
    );
  }

  bool get isSuccess =>
      status.contains('نجح') ||
      status.toLowerCase() == 'success' ||
      rawStatus.contains('نجح');
}

class MessageTemplateModel {
  final int id;
  final String name;
  final String type;
  final String content;
  final bool isActive;

  MessageTemplateModel({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    required this.isActive,
  });

  factory MessageTemplateModel.fromJson(Map<String, dynamic> json) {
    return MessageTemplateModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'عام',
      content: json['content']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'content': content,
      'is_active': isActive ? 1 : 0,
    };
  }
}
