import 'tenant_model.dart';

class DashboardStatsModel {
  final int totalTenants;
  final int notificationsCount;
  final int scheduledCount;
  final int templatesCount;
  final List<TenantModel> recentTenants;

  DashboardStatsModel({
    required this.totalTenants,
    required this.notificationsCount,
    required this.scheduledCount,
    required this.templatesCount,
    required this.recentTenants,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    final recentRaw = json['recent_tenants'] as List<dynamic>? ?? [];
    return DashboardStatsModel(
      totalTenants: json['total_tenants'] is int
          ? json['total_tenants']
          : int.tryParse(json['total_tenants']?.toString() ?? '0') ?? 0,
      notificationsCount: json['notifications_count'] is int
          ? json['notifications_count']
          : int.tryParse(json['notifications_count']?.toString() ?? '0') ?? 0,
      scheduledCount: json['scheduled_count'] is int
          ? json['scheduled_count']
          : int.tryParse(json['scheduled_count']?.toString() ?? '0') ?? 0,
      templatesCount: json['templates_count'] is int
          ? json['templates_count']
          : int.tryParse(json['templates_count']?.toString() ?? '0') ?? 0,
      recentTenants: recentRaw
          .map((item) => TenantModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
