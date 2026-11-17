import 'package:flutter/material.dart';
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

    final payload = {
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
      'payment_count': int.tryParse(_paymentCountController.text.trim()) ?? 1,
      'payment_terms': _paymentTermsController.text.trim(),
      'start_date': _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : '',
      'end_date': _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : '',

      // 4. Terms & Notes
      'maintenance_responsibility': _maintenanceController.text.trim(),
      'has_commitment': _commitmentController.text.trim(),
      'commercial_license_number': _licenseNumberController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    final ApiResponse<dynamic> res;
    if (widget.isEditing) {
      res = await ApiService.put(
        ApiEndpoints.tenantDetail(widget.tenant!.id),
        body: payload,
      );
    } else {
      res = await ApiService.post(
        ApiEndpoints.tenants,
        body: payload,
      );
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
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.people_alt_rounded, size: 19), text: 'أطراف العقد'),
                Tab(icon: Icon(Icons.apartment_rounded, size: 19), text: 'الوحدة والعقار'),
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 19), text: 'العقد والمالية'),
                Tab(icon: Icon(Icons.gavel_rounded, size: 19), text: 'الشروط والملاحظات'),
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
            _buildTermsTab(),
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

  // TAB 4: Terms, Legal & Notes
  Widget _buildTermsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('الشروط والالتزامات القانونية / TERMS', Icons.gavel_rounded, Colors.teal.shade800),
          const SizedBox(height: 12),

          // Commercial License
          TextFormField(
            controller: _licenseNumberController,
            decoration: const InputDecoration(
              labelText: 'رقم الرخصة التجارية (للعقود التجارية)',
              prefixIcon: Icon(Icons.business_center_outlined),
              hintText: 'مثال: CN-1029384',
            ),
          ),
          const SizedBox(height: 14),

          // Maintenance Responsibility
          TextFormField(
            controller: _maintenanceController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'مسؤولية الصيانة والخدمات',
              prefixIcon: Icon(Icons.build_circle_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // Commitment
          TextFormField(
            controller: _commitmentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'التعهد والالتزام والشروط الخاصة',
              prefixIcon: Icon(Icons.handshake_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // General Notes
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات إضافية للمستأجر',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
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
