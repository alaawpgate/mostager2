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

class _AddEditTenantScreenState extends State<AddEditTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;

  String _contractType = 'سكني';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  final List<String> _contractTypes = ['سكني', 'تجاري', 'عقد إيجار موحد', 'أخرى'];

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    _nameController = TextEditingController(text: t?.name ?? '');
    _phoneController = TextEditingController(text: t?.phone ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');

    if (t != null && _contractTypes.contains(t.contractType)) {
      _contractType = t.contractType;
    }

    if (t?.startDate != null && t!.startDate!.isNotEmpty) {
      try {
        _startDate = DateTime.parse(t.startDate!);
      } catch (_) {}
    }

    if (t?.endDate != null && t!.endDate!.isNotEmpty) {
      try {
        _endDate = DateTime.parse(t.endDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = {
      'tenant_name': _nameController.text.trim(),
      'tenant_phone': _phoneController.text.trim(),
      'contract_type': _contractType,
      'start_date': _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : '',
      'end_date': _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : '',
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
            widget.isEditing ? 'تم تحديث بيانات المستأجر بنجاح' : 'تم إضافة المستأجر الجديد بنجاح',
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
    final title = widget.isEditing ? 'تعديل بيانات المستأجر' : 'إضافة مستأجر جديد';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isEditing
                            ? 'قم بتعديل البيانات المطلوبة ثم اضغط حفظ التغييرات'
                            : 'أدخل البيانات الأساسية لعقد المستأجر الجديد لإدراجه بالنظام',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستأجر الكامل *',
                  hintText: 'مثال: محمد عبدالله السعيد',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال اسم المستأجر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف المستأجر (واتساب) *',
                  hintText: '+966500000000 أو 0500000000',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال رقم الهاتف للتواصل والإشعارات';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Contract Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: _contractType,
                decoration: const InputDecoration(
                  labelText: 'نوع العقد',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: _contractTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _contractType = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ بداية العقد',
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        child: Text(
                          _startDate != null
                              ? DateFormat('yyyy/MM/dd').format(_startDate!)
                              : 'اختر التاريخ',
                          style: TextStyle(
                            fontSize: 13,
                            color: _startDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ نهاية العقد',
                          prefixIcon: Icon(Icons.event_available_outlined, size: 20),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('yyyy/MM/dd').format(_endDate!)
                              : 'اختر التاريخ',
                          style: TextStyle(
                            fontSize: 13,
                            color: _endDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes Field
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية (اختياري)',
                  hintText: 'أية شروط خاصة، رقم الشقة، طريقة الدفع...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 50),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTenant,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          widget.isEditing ? 'حفظ التعديلات' : 'إضافة المستأجر',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
