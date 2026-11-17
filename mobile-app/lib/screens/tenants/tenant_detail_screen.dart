import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../models/tenant_model.dart';
import 'add_edit_tenant_screen.dart';

class TenantDetailScreen extends StatefulWidget {
  final int tenantId;

  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  TenantModel? _tenant;

  @override
  void initState() {
    super.initState();
    _fetchTenantDetail();
  }

  Future<void> _fetchTenantDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.get(ApiEndpoints.tenantDetail(widget.tenantId));
    if (!mounted) return;

    if (res.success && res.data != null) {
      final json = res.data as Map<String, dynamic>;
      final tenantData = json['tenant'] as Map<String, dynamic>? ?? {};
      setState(() {
        _tenant = TenantModel.fromJson(tenantData);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res.message ?? 'تعذر تحميل بيانات المستأجر';
      });
    }
  }

  Future<void> _deleteTenant() async {
    if (_tenant == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستأجر'),
        content: Text('هل أنت متأكد من حذف المستأجر "${_tenant!.name}"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await ApiService.delete(ApiEndpoints.tenantDetail(widget.tenantId));
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المستأجر بنجاح'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'فشل الحذف'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _openWhatsApp({String? customMessage}) async {
    if (_tenant == null || _tenant!.phone.isEmpty) return;
    final cleanPhone = _tenant!.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent(
      customMessage ?? 'السلام عليكم أستاذ ${_tenant!.name}، تحية طيبة من إدارة العقار.',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _makeCall() async {
    if (_tenant == null || _tenant!.phone.isEmpty) return;
    final cleanPhone = _tenant!.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  void _showSendMessageDialog() {
    final controller = TextEditingController(
      text: 'السلام عليكم أستاذ ${_tenant?.name}، نود تذكيركم بموعد استحقاق الإيجار القادم. شاكرين حسن تعاونكم.',
    );
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إرسال تنبيه واتساب للمستأجر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المستأجر: ${_tenant?.name} (${_tenant?.phone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب نص الرسالة...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openWhatsApp(customMessage: controller.text.trim());
              },
              child: const Text('فتح في تطبيق واتساب'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      setDialogState(() => isSending = true);
                      final res = await ApiService.post(
                        ApiEndpoints.sendNotification,
                        body: {
                          'tenant_id': widget.tenantId,
                          'phone': _tenant?.phone,
                          'tenant_name': _tenant?.name,
                          'message': controller.text.trim(),
                          'notification_type': 'تنبيه مباشر',
                        },
                      );
                      setDialogState(() => isSending = false);
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(res.message ?? 'تمت المعالجة'),
                          backgroundColor: res.success ? AppColors.success : AppColors.warning,
                        ),
                      );
                    },
              child: isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال عبر البوابة (API)'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'غير محدد';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy/MM/dd', 'ar').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tenant?.name ?? 'تفاصيل المستأجر'),
        actions: [
          if (_tenant != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل',
              onPressed: () async {
                final res = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditTenantScreen(tenant: _tenant),
                  ),
                );
                if (res == true) {
                  _fetchTenantDetail();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              tooltip: 'حذف',
              onPressed: _deleteTenant,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchTenantDetail, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final t = _tenant!;
    final isExpired = t.isExpired;
    final remainingDays = t.remainingDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Profile Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: isExpired
                        ? AppColors.danger.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      t.initialLetter,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? AppColors.danger : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      t.phone.isNotEmpty ? t.phone : 'لا يوجد رقم هاتف',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t.contractType,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? AppColors.danger.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isExpired ? 'العقد منتهي' : (remainingDays != null ? 'ساري (متبقي $remainingDays يوم)' : 'العقد ساري'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons Bar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('واتساب'),
                  onPressed: () => _openWhatsApp(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('اتصال مباشر'),
                  onPressed: _makeCall,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
                tooltip: 'إرسال تنبيه مخصص',
                onPressed: _showSendMessageDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contract Dates Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('فترة العقد والتواريخ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildDetailRow('تاريخ بداية العقد', _formatDate(t.startDate)),
                  const Divider(height: 16, color: AppColors.border),
                  _buildDetailRow('تاريخ نهاية العقد', _formatDate(t.endDate)),
                  if (t.createdAt != null) ...[
                    const Divider(height: 16, color: AppColors.border),
                    _buildDetailRow('تاريخ التسجيل بالنظام', _formatDate(t.createdAt)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Additional Info / Notes Card
          if (t.notes != null && t.notes!.trim().isNotEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notes_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('الملاحظات والشروط', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.notes!,
                      style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Commercial details if available
          if (t.commercialLicenseNumber != null && t.commercialLicenseNumber!.isNotEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.business_center_outlined, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('بيانات السجل التجاري', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('رقم السجل التجاري', t.commercialLicenseNumber!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
