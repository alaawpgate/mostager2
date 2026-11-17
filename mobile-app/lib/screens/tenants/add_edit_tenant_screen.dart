import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../models/tenant_model.dart';

class AddEditTenantScreen extends StatefulWidget {
  final TenantModel? tenant;

  const AddEditTenantScreen({super.key, this.tenant});

  bool get isEditing => tenant != null;

  @override
  State<AddEditTenantScreen> createState() => _AddEditTenantScreenState();
}

class _AddEditTenantScreenState extends State<AddEditTenantScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // 1. Parties Controllers (Lessor & Tenant)
  late TextEditingController _lessorNameController;
  late TextEditingController _lessorPhoneController;
  late TextEditingController _lessorIdController;

  late TextEditingController _tenantNameController;
  late TextEditingController _tenantPhoneController;
  late TextEditingController _tenantIdNumberController;

  // 2. Leased Unit & Property Controllers
  String _unitUsage = 'سكن عائلي / Family Residence';
  String _unitType = '3 BHK';
  late TextEditingController _unitNumberController;
  late TextEditingController _propertyNumberController;
  late TextEditingController _locationController;
  late TextEditingController _blockNumberController;
  late TextEditingController _plotNumberController;
  late TextEditingController _makaniNumberController;
  late TextEditingController _etihadWeNumberController;

  // 3. Contract & Financials Controllers
  late TextEditingController _contractNumberController;
  String _contractType = 'جديد';
  late TextEditingController _rentAmountController;
  late TextEditingController _contractPeriodController;
  late TextEditingController _paymentCountController;
  late TextEditingController _paymentTermsController;
  DateTime? _startDate;
  DateTime? _endDate;

  // 4. Terms, Legal & Notes Controllers
  late TextEditingController _maintenanceController;
  late TextEditingController _commitmentController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _notesController;

  // 5. File Attachments (ID, Contract, License, Cheques)
  File? _idImageFile;
  File? _contractImageFile;
  File? _licenseImageFile;
  final List<File> _checkImageFiles = [];

  bool _isSaving = false;

  final List<String> _unitUsages = [
    'سكن عائلي / Family Residence',
    'تجاري / Commercial',
    'مكتبي / Office',
    'صناعي / Industrial',
  ];

  final List<String> _unitTypes = [
    '3 BHK',
    '2 BHK',
    '1 BHK',
    'Studio / ستوديو',
    'محل تجاري / Shop',
    'مكتب / Office',
    'معرض / Showroom',
    'مستودع / Warehouse',
  ];

  final List<String> _contractTypes = ['جديد', 'تجديد'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final t = widget.tenant;

    // 1. Parties
    _lessorNameController = TextEditingController(text: t?.lessorName ?? 'علاء مصطفي');
    _lessorPhoneController = TextEditingController(text: t?.lessorPhone ?? '01009931190');
    _lessorIdController = TextEditingController(text: t?.lessorId ?? '784-1965-3975208-7');

    _tenantNameController = TextEditingController(text: t?.name ?? '');
    _tenantPhoneController = TextEditingController(text: t?.phone ?? '');
    _tenantIdNumberController = TextEditingController(text: t?.tenantIdNumber ?? '');

    // 2. Unit
    if (t?.unitUsage != null && t!.unitUsage!.isNotEmpty) {
      _unitUsage = t.unitUsage!;
      if (!_unitUsages.contains(_unitUsage)) _unitUsages.add(_unitUsage);
    }
    if (t?.unitType != null && t!.unitType!.isNotEmpty) {
      _unitType = t.unitType!;
      if (!_unitTypes.contains(_unitType)) _unitTypes.add(_unitType);
    }
    _unitNumberController = TextEditingController(text: t?.unitNumber ?? '504');
    _propertyNumberController = TextEditingController(text: t?.propertyNumber ?? 'PROPA56720313');
    _locationController = TextEditingController(text: t?.location ?? 'TOWN CENTER');
    _blockNumberController = TextEditingController(text: t?.blockNumber ?? 'A');
    _plotNumberController = TextEditingController(text: t?.plotNumber ?? '5');
    _makaniNumberController = TextEditingController(text: t?.makaniNumber ?? '********');
    _etihadWeNumberController = TextEditingController(text: t?.etihadWeNumber ?? '2000034793');

    // 3. Contract & Financials
    _contractNumberController = TextEditingController(text: t?.contractNumber ?? 'RENT25061768');
    if (t?.contractType != null && _contractTypes.contains(t!.contractType)) {
      _contractType = t.contractType;
    }
    _rentAmountController = TextEditingController(
      text: t?.rentAmount != null ? t!.rentAmount!.toStringAsFixed(0) : '28000',
    );
    _contractPeriodController = TextEditingController(text: t?.contractPeriod ?? 'One Year');
    _paymentCountController = TextEditingController(
      text: t?.paymentCount != null ? t!.paymentCount.toString() : '12',
    );
    _paymentTermsController = TextEditingController(text: t?.paymentTerms ?? '');

    if (t?.startDate != null && t!.startDate!.isNotEmpty) {
      _startDate = _parseDate(t.startDate!);
    } else {
      _startDate = DateTime.now();
    }

    if (t?.endDate != null && t!.endDate!.isNotEmpty) {
      _endDate = _parseDate(t.endDate!);
    } else {
      _endDate = _startDate?.add(const Duration(days: 365));
    }

    // 4. Terms & Notes
    _maintenanceController = TextEditingController(
      text: t?.maintenanceResponsibility ?? 'الصيانة الداخلية على المستأجر والأساسية على المالك',
    );
    _commitmentController = TextEditingController(
      text: t?.hasCommitment ?? 'الالتزام بقوانين الإيجار المعمول بها وعدم التأجير من الباطن',
    );
    _licenseNumberController = TextEditingController(text: t?.commercialLicenseNumber ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        final p = dateStr.split('/');
        if (p.length == 3) {
          return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        }
      }
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lessorNameController.dispose();
    _lessorPhoneController.dispose();
    _lessorIdController.dispose();
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    _tenantIdNumberController.dispose();
    _unitNumberController.dispose();
    _propertyNumberController.dispose();
    _locationController.dispose();
    _blockNumberController.dispose();
    _plotNumberController.dispose();
    _makaniNumberController.dispose();
    _etihadWeNumberController.dispose();
    _contractNumberController.dispose();
    _rentAmountController.dispose();
    _contractPeriodController.dispose();
    _paymentCountController.dispose();
    _paymentTermsController.dispose();
    _maintenanceController.dispose();
    _commitmentController.dispose();
    _licenseNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? (_startDate?.add(const Duration(days: 365)) ?? DateTime.now()));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate == null || _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<File?> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('التقاط بالكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      return File(picked.path);
    }
    return null;
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى التحقق من ملء الحقول المطلوبة (اسم المستأجر ورقم الهاتف)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final fields = <String, String>{
      // 1. Parties
      'lessor_name': _lessorNameController.text.trim(),
      'lessor_phone': _lessorPhoneController.text.trim(),
      'lessor_id': _lessorIdController.text.trim(),
      'tenant_name': _tenantNameController.text.trim(),
      'tenant_phone': _tenantPhoneController.text.trim(),
      'tenant_id_number': _tenantIdNumberController.text.trim(),

      // 2. Unit
      'unit_usage': _unitUsage,
      'unit_type': _unitType,
      'unit_number': _unitNumberController.text.trim(),
      'property_number': _propertyNumberController.text.trim(),
      'location': _locationController.text.trim(),
      'block_number': _blockNumberController.text.trim(),
      'plot_number': _plotNumberController.text.trim(),
      'makani_number': _makaniNumberController.text.trim(),
      'etihad_we_number': _etihadWeNumberController.text.trim(),

      // 3. Contract & Financials
      'contract_number': _contractNumberController.text.trim(),
      'contract_type': _contractType,
      'rent_amount': _rentAmountController.text.trim(),
      'contract_period': _contractPeriodController.text.trim(),
      'payment_count': _paymentCountController.text.trim(),
      'payment_terms': _paymentTermsController.text.trim(),
      'start_date': _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : '',
      'end_date': _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : '',

      // 4. Terms & Notes (تفاصيل العقد الإضافية)
      'maintenance_responsibility': _maintenanceController.text.trim(),
      'has_commitment': _commitmentController.text.trim(),
      'commercial_license_number': _licenseNumberController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    final ApiResponse<dynamic> res;
    final endpoint = widget.isEditing
        ? ApiEndpoints.tenantDetail(widget.tenant!.id)
        : ApiEndpoints.tenants;
    final method = widget.isEditing ? 'PUT' : 'POST';

    final hasFiles = _idImageFile != null ||
        _contractImageFile != null ||
        _licenseImageFile != null ||
        _checkImageFiles.isNotEmpty;

    if (hasFiles) {
      res = await ApiService.submitTenantMultipart(
        endpoint: endpoint,
        method: method,
        fields: fields,
        idImage: _idImageFile,
        contractImage: _contractImageFile,
        licenseImage: _licenseImageFile,
        checkImages: _checkImageFiles.isNotEmpty ? _checkImageFiles : null,
      );
    } else {
      if (widget.isEditing) {
        res = await ApiService.put(endpoint, body: fields);
      } else {
        res = await ApiService.post(endpoint, body: fields);
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'تم تحديث بيانات العقد والمستأجر بنجاح'
                : 'تم إنشاء المستأجر وتوثيق العقد الإلكتروني بنجاح',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'تعذر حفظ بيانات المستأجر'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل بيانات العقد' : 'تسجيل وتوثيق عقد إيجار'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEFF2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF334155),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'أطراف العقد'),
                Tab(icon: Icon(Icons.apartment_rounded, size: 18), text: 'الوحدة والعقار'),
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'العقد والمالية'),
                Tab(icon: Icon(Icons.post_add_rounded, size: 18), text: 'تفاصيل العقد الإضافية'),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPartiesTab(),
            _buildUnitTab(),
            _buildContractTab(),
            _buildAdditionalDetailsTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(
            _isSaving ? 'جارِ حفظ العقد...' : (widget.isEditing ? 'تحديث وحفظ العقد' : 'توثيق وحفظ العقد الإلكتروني'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: _isSaving ? null : _saveTenant,
        ),
      ),
    );
  }

  // TAB 1: Parties (Lessor & Tenant)
  Widget _buildPartiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('بيانات المؤجر (المالك / LEASOR)', Icons.badge_outlined, Colors.brown.shade800),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lessorNameController,
            decoration: const InputDecoration(
              labelText: 'اسم المؤجر / Name *',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lessorPhoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم هاتف المؤجر / Mobile No.',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lessorIdController,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم هوية المؤجر / ID #',
              prefixIcon: Icon(Icons.credit_card_rounded),
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('بيانات المستأجر (الطرف الثاني / TENANT)', Icons.person_pin_rounded, AppColors.primary),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tenantNameController,
            decoration: const InputDecoration(
              labelText: 'اسم المستأجر بالكامل / Tenant Name *',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'يرجى إدخال اسم المستأجر';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tenantPhoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم هاتف المستأجر (واتساب) / Mobile No. *',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'يرجى إدخال رقم الهاتف للتواصل والتنبيهات';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tenantIdNumberController,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهوية الوطنية / الإقامة / ID #',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Leased Unit & Property
  Widget _buildUnitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('تفاصيل الوحدة المؤجرة والعقار / LEASED UNIT', Icons.apartment_rounded, Colors.teal.shade800),
          const SizedBox(height: 12),

          // Unit Usage
          DropdownButtonFormField<String>(
            initialValue: _unitUsage,
            decoration: const InputDecoration(
              labelText: 'استخدام الوحدة / UNIT USAGE',
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
            items: _unitUsages.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _unitUsage = val);
            },
          ),
          const SizedBox(height: 12),

          // Unit Type
          DropdownButtonFormField<String>(
            initialValue: _unitType,
            decoration: const InputDecoration(
              labelText: 'نوع الوحدة / UNIT TYPE',
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
            items: _unitTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _unitType = val);
            },
          ),
          const SizedBox(height: 12),

          // Unit No & Property No
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unitNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الوحدة / UNIT No. *',
                    prefixIcon: Icon(Icons.pin_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _propertyNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم العقار / PROPERTY No.',
                    prefixIcon: Icon(Icons.domain_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'المنطقة والموقع / LOCATION',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Block & Plot No
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _blockNumberController,
                  decoration: const InputDecoration(
                    labelText: 'المربع / BLOCK No.',
                    prefixIcon: Icon(Icons.grid_view_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _plotNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم القطعة / PLOT No.',
                    prefixIcon: Icon(Icons.crop_square_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Makani & Electricity
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _makaniNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم مكاني / MAKANI No.',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _etihadWeNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الكهرباء / ETIHAD WE',
                    prefixIcon: Icon(Icons.bolt_rounded),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 3: Contract & Financials
  Widget _buildContractTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('بيانات العقد والمالية / CONTRACT DETAILS', Icons.description_outlined, Colors.indigo.shade800),
          const SizedBox(height: 12),

          // Contract No & Contract Type
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _contractNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم العقد / CONTRACT NO *',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _contractType,
                  decoration: const InputDecoration(
                    labelText: 'نوع العقد',
                  ),
                  items: _contractTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _contractType = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rent Amount & Period
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _rentAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'القيمة الإيجارية السنوية (درهم) *',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _contractPeriodController,
                  decoration: const InputDecoration(
                    labelText: 'مدة العقد / PERIOD',
                    prefixIcon: Icon(Icons.timelapse_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Start Date & End Date Pickers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تاريخ بدء العقد / START', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _startDate != null ? DateFormat('yyyy/MM/dd').format(_startDate!) : 'اختر التاريخ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تاريخ انتهاء العقد / END', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _endDate != null ? DateFormat('yyyy/MM/dd').format(_endDate!) : 'اختر التاريخ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cheques / Payments Count
          TextFormField(
            controller: _paymentCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد الدفعات والشيكات / PAYMENT COUNT',
              prefixIcon: Icon(Icons.receipt_rounded),
            ),
          ),
          const SizedBox(height: 12),

          // Payment Terms
          TextFormField(
            controller: _paymentTermsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'شروط الدفع والتسليم / PAYMENT & OTHER TERMS',
              prefixIcon: Icon(Icons.notes_rounded),
              hintText: 'مثال: سداد عبر 4 شيكات بنكية مؤجلة متساوية القيمة',
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: تفاصيل العقد الإضافية (Exact match for http://127.0.0.1:8080/add-tenant)
  Widget _buildAdditionalDetailsTab() {
    final t = widget.tenant;
    final existingIdUrl = t?.idImage != null ? ApiEndpoints.resolveUploadUrl(t!.idImage, customBaseUrl: ApiService.baseUrl) : null;
    final existingContractUrl = t?.contractImage != null ? ApiEndpoints.resolveUploadUrl(t!.contractImage, customBaseUrl: ApiService.baseUrl) : null;
    final existingLicenseUrl = t?.commercialLicenseImage != null ? ApiEndpoints.resolveUploadUrl(t!.commercialLicenseImage, customBaseUrl: ApiService.baseUrl) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('تفاصيل العقد الإضافية', Icons.post_add_rounded, const Color(0xFF6B2B2B)),
          const SizedBox(height: 14),

          // 1. نوع العقد (جديد / تجديد) & عدد الدفعات / الشيكات
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _contractType,
                  decoration: const InputDecoration(
                    labelText: 'نوع العقد',
                    prefixIcon: Icon(Icons.article_outlined),
                  ),
                  items: _contractTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _contractType = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _paymentCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الدفعات / الشيكات',
                    prefixIcon: Icon(Icons.receipt_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. رقم الرخصة التجارية
          TextFormField(
            controller: _licenseNumberController,
            decoration: const InputDecoration(
              labelText: 'رقم الرخصة التجارية',
              prefixIcon: Icon(Icons.business_center_outlined),
              hintText: 'مثال: CN-1029384',
            ),
          ),
          const SizedBox(height: 14),

          // 3. صورة الرخصة التجارية
          _buildImagePickerCard(
            title: 'صورة الرخصة التجارية',
            icon: Icons.badge_outlined,
            localFile: _licenseImageFile,
            existingRemoteUrl: existingLicenseUrl,
            onPick: () async {
              final img = await _pickImage(context);
              if (img != null) setState(() => _licenseImageFile = img);
            },
            onRemove: () {
              setState(() => _licenseImageFile = null);
            },
          ),

          // 4. صور الشيكات (+ إضافة صورة شيك أخرى)
          _buildCheckImagesSection(),

          // 5. التعهد
          TextFormField(
            controller: _commitmentController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'التعهد',
              prefixIcon: Icon(Icons.handshake_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // 6. الصيانة
          TextFormField(
            controller: _maintenanceController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'الصيانة',
              prefixIcon: Icon(Icons.build_circle_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // 7. ملاحظات
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 18),

          // 8. وثائق الهوية والعقد الورقي
          _buildSectionHeader('المستندات الأساسية (الهوية والعقد)', Icons.folder_shared_outlined, AppColors.primary),
          const SizedBox(height: 12),

          _buildImagePickerCard(
            title: 'صورة الهوية',
            icon: Icons.person_pin_rounded,
            localFile: _idImageFile,
            existingRemoteUrl: existingIdUrl,
            onPick: () async {
              final img = await _pickImage(context);
              if (img != null) setState(() => _idImageFile = img);
            },
            onRemove: () {
              setState(() => _idImageFile = null);
            },
          ),

          _buildImagePickerCard(
            title: 'صورة العقد',
            icon: Icons.description_outlined,
            localFile: _contractImageFile,
            existingRemoteUrl: existingContractUrl,
            onPick: () async {
              final img = await _pickImage(context);
              if (img != null) setState(() => _contractImageFile = img);
            },
            onRemove: () {
              setState(() => _contractImageFile = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerCard({
    required String title,
    required IconData icon,
    File? localFile,
    String? existingRemoteUrl,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasImage = localFile != null || (existingRemoteUrl != null && existingRemoteUrl.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasImage ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
          width: hasImage ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: hasImage ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              if (hasImage)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('حذف', style: TextStyle(fontSize: 12)),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (localFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                localFile,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (existingRemoteUrl != null && existingRemoteUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                existingRemoteUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 60,
                  alignment: Alignment.center,
                  color: AppColors.background,
                  child: const Text('تعذر تحميل الصورة السابقة', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18, color: AppColors.primary),
              label: Text('اختيار / التقاط $title', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              onPressed: onPick,
            ),
        ],
      ),
    );
  }

  Widget _buildCheckImagesSection() {
    final existingRemoteChecks = widget.tenant?.checkImagesList ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'صور الشيكات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_checkImageFiles.length + existingRemoteChecks.length} شيك',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Existing remote checks
          if (existingRemoteChecks.isNotEmpty) ...[
            const Text(
              'الشيكات المرفوعة سابقاً:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: existingRemoteChecks.map((filename) {
                final url = ApiEndpoints.resolveUploadUrl(filename, customBaseUrl: ApiService.baseUrl);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 70,
                      height: 70,
                      color: AppColors.background,
                      child: const Icon(Icons.broken_image, size: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Locally picked checks
          if (_checkImageFiles.isNotEmpty) ...[
            const Text(
              'الشيكات الجديدة المضافة:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_checkImageFiles.length, (idx) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _checkImageFiles[idx],
                        width: 75,
                        height: 75,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      left: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _checkImageFiles.removeAt(idx);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 10),
          ],

          // The exact web button: "إضافة صورة شيك أخرى"
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
            label: const Text('إضافة صورة شيك أخرى', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final img = await _pickImage(context);
              if (img != null) {
                setState(() {
                  _checkImageFiles.add(img);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
