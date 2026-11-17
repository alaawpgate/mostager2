class TenantModel {
  final int id;
  final String name;
  final String phone;
  final String? startDate;
  final String? endDate;
  final String? buildingName;
  final String? unitNumber;
  final double? rentAmount;
  final String? createdAt;

  TenantModel({
    required this.id,
    required this.name,
    required this.phone,
    this.startDate,
    this.endDate,
    this.buildingName,
    this.unitNumber,
    this.rentAmount,
    this.createdAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? json['tenant_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['tenant_phone']?.toString() ?? '',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      buildingName: json['building_name']?.toString(),
      unitNumber: json['unit_number']?.toString(),
      rentAmount: json['rent_amount'] != null
          ? double.tryParse(json['rent_amount'].toString())
          : null,
      createdAt: json['created_at']?.toString(),
    );
  }

  String get initialLetter {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'م';
    return trimmed.substring(0, 1);
  }
}
