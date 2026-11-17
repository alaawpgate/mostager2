class TenantModel {
  final int id;
  final String name;
  final String phone;
  final String? startDate;
  final String? endDate;
  final String contractType;
  final String? createdAt;
  final String? updatedAt;
  final String? whatsappUrl;

  // Leased Unit & Property Details
  final String? unitUsage;
  final String? unitNumber;
  final String? propertyNumber;
  final String? location;
  final String? blockNumber;
  final String? plotNumber;
  final String? unitType;
  final String? makaniNumber;
  final String? etihadWeNumber;

  // Contract & Financial Details
  final String? contractNumber;
  final double? rentAmount;
  final String? contractPeriod;
  final int? paymentCount;
  final String? paymentTerms;

  // Lessor Details
  final String? lessorName;
  final String? lessorPhone;
  final String? lessorId;

  // Tenant Additional Details
  final String? tenantIdNumber;
  final String? commercialLicenseNumber;
  final String? commercialLicenseImage;
  final String? hasCommitment;
  final String? maintenanceResponsibility;
  final String? notes;

  // Document Images
  final String? idImage;
  final String? contractImage;
  final String? checkImages;
  final List<String> checkImagesList;
  final bool hasIdImage;
  final bool hasContractImage;
  final bool hasLicenseImage;
  final int checkCount;

  // HTML Electronic Contract Content
  final String? pageOneContent;
  final String? pageTwoContent;

  TenantModel({
    required this.id,
    required this.name,
    required this.phone,
    this.startDate,
    this.endDate,
    this.contractType = 'عقد إيجار',
    this.createdAt,
    this.updatedAt,
    this.whatsappUrl,
    this.unitUsage,
    this.unitNumber,
    this.propertyNumber,
    this.location,
    this.blockNumber,
    this.plotNumber,
    this.unitType,
    this.makaniNumber,
    this.etihadWeNumber,
    this.contractNumber,
    this.rentAmount,
    this.contractPeriod,
    this.paymentCount,
    this.paymentTerms,
    this.lessorName,
    this.lessorPhone,
    this.lessorId,
    this.tenantIdNumber,
    this.commercialLicenseNumber,
    this.commercialLicenseImage,
    this.hasCommitment,
    this.maintenanceResponsibility,
    this.notes,
    this.idImage,
    this.contractImage,
    this.checkImages,
    this.checkImagesList = const [],
    this.hasIdImage = false,
    this.hasContractImage = false,
    this.hasLicenseImage = false,
    this.checkCount = 0,
    this.pageOneContent,
    this.pageTwoContent,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    // Parse check images list
    List<String> checks = [];
    if (json['check_images_list'] is List) {
      checks = (json['check_images_list'] as List).map((e) => e.toString()).toList();
    } else if (json['check_images'] != null && json['check_images'].toString().isNotEmpty) {
      checks = json['check_images'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    double? parsedAmount;
    final rawAmount = json['rent_amount'] ?? json['contract_amount'];
    if (rawAmount != null) {
      final clean = rawAmount.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      parsedAmount = double.tryParse(clean);
    }

    final parsedPaymentCount = json['payment_count'] is int
        ? json['payment_count'] as int
        : int.tryParse(json['payment_count']?.toString() ?? '');

    final idImg = json['id_image']?.toString();
    final contractImg = json['contract_image']?.toString();
    final licenseImg = json['commercial_license_image']?.toString();

    return TenantModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? json['tenant_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['tenant_phone']?.toString() ?? '',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      contractType: json['contract_type']?.toString() ?? 'عقد إيجار',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      whatsappUrl: json['whatsapp_url']?.toString(),

      // Unit & Property
      unitUsage: json['unit_usage']?.toString(),
      unitNumber: json['unit_number']?.toString(),
      propertyNumber: json['property_number']?.toString(),
      location: json['location']?.toString(),
      blockNumber: json['block_number']?.toString(),
      plotNumber: json['plot_number']?.toString(),
      unitType: json['unit_type']?.toString(),
      makaniNumber: json['makani_number']?.toString(),
      etihadWeNumber: json['etihad_we_number']?.toString(),

      // Contract & Financials
      contractNumber: json['contract_number']?.toString(),
      rentAmount: parsedAmount,
      contractPeriod: json['contract_period']?.toString(),
      paymentCount: parsedPaymentCount,
      paymentTerms: json['payment_terms']?.toString(),

      // Lessor
      lessorName: json['lessor_name']?.toString(),
      lessorPhone: json['lessor_phone']?.toString(),
      lessorId: json['lessor_id']?.toString(),

      // Tenant
      tenantIdNumber: json['tenant_id_number']?.toString(),
      commercialLicenseNumber: json['commercial_license_number']?.toString(),
      commercialLicenseImage: licenseImg,
      hasCommitment: json['has_commitment']?.toString(),
      maintenanceResponsibility: json['maintenance_responsibility']?.toString(),
      notes: json['notes']?.toString(),

      // Images
      idImage: idImg,
      contractImage: contractImg,
      checkImages: json['check_images']?.toString(),
      checkImagesList: checks,
      hasIdImage: json['has_id_image'] == true || (idImg != null && idImg.isNotEmpty),
      hasContractImage: json['has_contract_image'] == true || (contractImg != null && contractImg.isNotEmpty),
      hasLicenseImage: json['has_license_image'] == true || (licenseImg != null && licenseImg.isNotEmpty),
      checkCount: json['check_count'] is int ? json['check_count'] : checks.length,

      // Electronic Pages
      pageOneContent: json['page_one_content']?.toString(),
      pageTwoContent: json['page_two_content']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenant_name': name,
      'tenant_phone': phone,
      'start_date': startDate,
      'end_date': endDate,
      'contract_type': contractType,
      'unit_usage': unitUsage,
      'unit_number': unitNumber,
      'property_number': propertyNumber,
      'location': location,
      'block_number': blockNumber,
      'plot_number': plotNumber,
      'unit_type': unitType,
      'makani_number': makaniNumber,
      'etihad_we_number': etihadWeNumber,
      'contract_number': contractNumber,
      'rent_amount': rentAmount,
      'contract_period': contractPeriod,
      'payment_count': paymentCount,
      'payment_terms': paymentTerms,
      'lessor_name': lessorName,
      'lessor_phone': lessorPhone,
      'lessor_id': lessorId,
      'tenant_id_number': tenantIdNumber,
      'commercial_license_number': commercialLicenseNumber,
      'has_commitment': hasCommitment,
      'maintenance_responsibility': maintenanceResponsibility,
      'notes': notes,
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
      DateTime? end;
      if (endDate!.contains('/')) {
        final parts = endDate!.split('/');
        if (parts.length == 3) {
          end = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else {
        end = DateTime.parse(endDate!);
      }
      if (end != null) {
        return DateTime.now().isAfter(end);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  int? get remainingDays {
    if (endDate == null || endDate!.isEmpty) return null;
    try {
      DateTime? end;
      if (endDate!.contains('/')) {
        final parts = endDate!.split('/');
        if (parts.length == 3) {
          end = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else {
        end = DateTime.parse(endDate!);
      }
      if (end != null) {
        return end.difference(DateTime.now()).inDays;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String get displayUnitInfo {
    final parts = <String>[];
    if (unitNumber != null && unitNumber!.isNotEmpty) {
      parts.add('وحدة $unitNumber');
    }
    if (unitType != null && unitType!.isNotEmpty) {
      parts.add(unitType!);
    }
    if (propertyNumber != null && propertyNumber!.isNotEmpty) {
      parts.add('عقار $propertyNumber');
    }
    if (location != null && location!.isNotEmpty) {
      parts.add(location!);
    }
    return parts.isEmpty ? 'وحدة سكنية مسجلة' : parts.join(' • ');
  }

  String get formattedRentAmount {
    if (rentAmount == null) return 'غير محدد';
    return '${rentAmount!.toStringAsFixed(0)} درهم';
  }

  bool get isResidential {
    final usage = (unitUsage ?? '').toLowerCase();
    final cType = contractType.toLowerCase();
    return usage.contains('سكن') ||
        usage.contains('residence') ||
        usage.contains('family') ||
        cType.contains('سكن') ||
        cType.contains('residen');
  }

  bool get isCommercial {
    final usage = (unitUsage ?? '').toLowerCase();
    final cType = contractType.toLowerCase();
    final lic = (commercialLicenseNumber ?? '').trim();
    return usage.contains('تجار') ||
        usage.contains('commercial') ||
        usage.contains('office') ||
        usage.contains('shop') ||
        usage.contains('محل') ||
        usage.contains('مكتب') ||
        cType.contains('تجار') ||
        cType.contains('commercial') ||
        lic.isNotEmpty;
  }
}
