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
  final String? updatedAt;
  final String contractType;
  final String? notes;
  final String? idImage;
  final String? contractImage;
  final String? checkImages;
  final String? whatsappUrl;
  final int? paymentCount;
  final String? commercialLicenseNumber;
  final String? commercialLicenseImage;
  final String? hasCommitment;
  final String? maintenanceResponsibility;

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
    this.updatedAt,
    this.contractType = 'سكني',
    this.notes,
    this.idImage,
    this.contractImage,
    this.checkImages,
    this.whatsappUrl,
    this.paymentCount,
    this.commercialLicenseNumber,
    this.commercialLicenseImage,
    this.hasCommitment,
    this.maintenanceResponsibility,
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
      updatedAt: json['updated_at']?.toString(),
      contractType: json['contract_type']?.toString() ?? 'سكني',
      notes: json['notes']?.toString(),
      idImage: json['id_image']?.toString(),
      contractImage: json['contract_image']?.toString(),
      checkImages: json['check_images']?.toString(),
      whatsappUrl: json['whatsapp_url']?.toString(),
      paymentCount: json['payment_count'] is int
          ? json['payment_count']
          : int.tryParse(json['payment_count']?.toString() ?? ''),
      commercialLicenseNumber: json['commercial_license_number']?.toString(),
      commercialLicenseImage: json['commercial_license_image']?.toString(),
      hasCommitment: json['has_commitment']?.toString(),
      maintenanceResponsibility: json['maintenance_responsibility']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenant_name': name,
      'tenant_phone': phone,
      'start_date': startDate,
      'end_date': endDate,
      'contract_type': contractType,
      'notes': notes,
      if (buildingName != null) 'building_name': buildingName,
      if (unitNumber != null) 'unit_number': unitNumber,
      if (rentAmount != null) 'rent_amount': rentAmount,
    };
  }

  String get initialLetter {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'م';
    return trimmed.substring(0, 1);
  }

  bool get isExpired {
    if (endDate == null || endDate!.isEmpty) return false;
    try {
      final end = DateTime.parse(endDate!);
      return DateTime.now().isAfter(end);
    } catch (_) {
      return false;
    }
  }

  int? get remainingDays {
    if (endDate == null || endDate!.isEmpty) return null;
    try {
      final end = DateTime.parse(endDate!);
      final diff = end.difference(DateTime.now()).inDays;
      return diff;
    } catch (_) {
      return null;
    }
  }
}
