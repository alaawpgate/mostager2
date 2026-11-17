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

class _TenantDetailScreenState extends State<TenantDetailScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  TenantModel? _tenant;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchTenantDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        _errorMessage = res.message ?? 'تعذر تحميل بيانات المستأجر والعقد';
      });
    }
  }

  Future<void> _deleteTenant() async {
    if (_tenant == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستأجر'),
        content: Text('هل أنت متأكد من حذف ملف المستأجر "${_tenant!.name}"؟ لا يمكن التراجع عن هذه الخطوة.'),
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

  void _openContractPrint() async {
    if (_tenant == null) return;
    final base = ApiService.baseUrl.replaceAll('/api/v1', '');
    final url = Uri.parse('$base/api/v1/tenants/${_tenant!.id}/contract');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط وثيقة العقد')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  void _previewImageFullscreen(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.black,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                            SizedBox(height: 8),
                            Text('تعذر تحميل الصورة', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'غير محدد';
    try {
      if (dateStr.contains('/')) return dateStr;
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
        title: Text(_tenant?.name ?? 'ملف المستأجر والعقد'),
        actions: [
          if (_tenant != null) ...[
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'تحميل وطباعة العقد (A4 PDF)',
              onPressed: _openContractPrint,
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'تعديل بيانات العقد',
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
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                        tabs: [
                          const Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'بيانات وشروط العقد'),
                          const Tab(icon: Icon(Icons.folder_shared_outlined, size: 18), text: 'المستندات الرسمية'),
                          Tab(
                            icon: const Icon(Icons.receipt_long_outlined, size: 18),
                            text: 'سجل الشيكات (${_tenant!.checkCount})',
                          ),
                          const Tab(icon: Icon(Icons.print_outlined, size: 18), text: 'وثيقة العقد (A4)'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTermsTab(),
                          _buildDocsTab(),
                          _buildChecksTab(),
                          _buildContractA4Tab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // TAB 1: Terms, Details & Contract Specs
  Widget _buildTermsTab() {
    final t = _tenant!;
    final isExpired = t.isExpired;
    final remainingDays = t.remainingDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Profile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isExpired
                              ? AppColors.danger.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: (t.hasIdImage && t.idImage != null && t.idImage!.isNotEmpty)
                            ? Image.network(
                                '${ApiEndpoints.uploadsBase}/${t.idImage}',
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                errorBuilder: (_, _, _) => Text(
                                  t.initialLetter,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isExpired ? AppColors.danger : AppColors.primary,
                                  ),
                                ),
                              )
                            : Text(
                                t.initialLetter,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isExpired ? AppColors.danger : AppColors.primary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isExpired
                                        ? AppColors.danger.withValues(alpha: 0.1)
                                        : AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isExpired ? 'عقد منتهي' : (remainingDays != null ? 'ساري (متبقي $remainingDays يوم)' : 'عقد ساري'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isExpired ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t.contractType,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF25D366),
                            side: const BorderSide(color: Color(0xFF25D366)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: const Text('واتساب فوري', style: TextStyle(fontSize: 12)),
                          onPressed: t.phone.isNotEmpty ? () => _openWhatsApp() : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: const Text('اتصال مباشر', style: TextStyle(fontSize: 12)),
                          onPressed: t.phone.isNotEmpty ? () => _makeCall() : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4 Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'فترة العقد',
                  '${_formatDate(t.startDate)} - ${_formatDate(t.endDate)}',
                  Icons.calendar_month_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickStat(
                  'القيمة الإيجارية',
                  t.formattedRentAmount,
                  Icons.payments_rounded,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'الدفعات والشيكات',
                  '${t.paymentCount ?? t.checkCount} دفعة',
                  Icons.receipt_rounded,
                  Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickStat(
                  'الوحدة المؤجرة',
                  'وحدة ${t.unitNumber ?? "---"}',
                  Icons.apartment_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Section: Leased Unit & Property Details
          _buildInfoCard(
            title: 'تفاصيل الوحدة المؤجرة والعقار',
            icon: Icons.apartment_rounded,
            color: Colors.teal.shade800,
            items: [
              {'label': 'استخدام الوحدة', 'value': t.unitUsage ?? 'غير محدد'},
              {'label': 'رقم الوحدة', 'value': t.unitNumber ?? 'غير مسجل'},
              {'label': 'نوع الوحدة', 'value': t.unitType ?? 'غير مسجل'},
              {'label': 'رقم العقار', 'value': t.propertyNumber ?? 'غير مسجل'},
              {'label': 'المنطقة والموقع', 'value': t.location ?? 'غير مسجل'},
              {'label': 'المربع / القطعة', 'value': 'مربع ${t.blockNumber ?? "-"} • قطعة ${t.plotNumber ?? "-"}'},
              {'label': 'رقم مكاني', 'value': t.makaniNumber ?? 'غير مسجل'},
              {'label': 'رقم الكهرباء (اتحاد)', 'value': t.etihadWeNumber ?? 'غير مسجل'},
            ],
          ),

          const SizedBox(height: 14),

          // Section: Contract Details
          _buildInfoCard(
            title: 'بيانات العقد والمالية',
            icon: Icons.receipt_long_rounded,
            color: Colors.indigo.shade800,
            items: [
              {'label': 'رقم العقد', 'value': t.contractNumber ?? 'RENT25061768'},
              {'label': 'القيمة السنوية', 'value': t.formattedRentAmount},
              {'label': 'مدة العقد', 'value': t.contractPeriod ?? 'سنة واحدة'},
              {'label': 'تاريخ البدء', 'value': _formatDate(t.startDate)},
              {'label': 'تاريخ الانتهاء', 'value': _formatDate(t.endDate)},
              {'label': 'عدد الدفعات', 'value': '${t.paymentCount ?? t.checkCount} دفعات / شيكات'},
              {'label': 'شروط وطريقة الدفع', 'value': t.paymentTerms?.isNotEmpty == true ? t.paymentTerms! : 'دفعات متفق عليها'},
            ],
          ),

          const SizedBox(height: 14),

          // Section: Parties Details
          _buildInfoCard(
            title: 'أطراف العقد (المؤجر والمستأجر)',
            icon: Icons.people_alt_rounded,
            color: Colors.brown.shade800,
            items: [
              {'label': 'اسم المؤجر', 'value': t.lessorName ?? 'علاء مصطفي'},
              {'label': 'هاتف المؤجر', 'value': t.lessorPhone ?? '01009931190'},
              {'label': 'هوية المؤجر', 'value': t.lessorId ?? '784-1965-3975208-7'},
              {'label': 'اسم المستأجر', 'value': t.name},
              {'label': 'هاتف المستأجر', 'value': t.phone},
              {'label': 'هوية المستأجر', 'value': t.tenantIdNumber?.isNotEmpty == true ? t.tenantIdNumber! : 'غير مسجلة'},
            ],
          ),

          const SizedBox(height: 14),

          // Section: Maintenance, Commitments & Notes
          _buildInfoCard(
            title: 'الالتزامات والشروط والملاحظات',
            icon: Icons.gavel_rounded,
            color: AppColors.primary,
            items: [
              {'label': 'مسؤولية الصيانة', 'value': t.maintenanceResponsibility?.isNotEmpty == true ? t.maintenanceResponsibility! : 'الصيانة الاعتيادية حسب العقد'},
              {'label': 'التعهد والالتزام', 'value': t.hasCommitment?.isNotEmpty == true ? t.hasCommitment! : 'الالتزام بقوانين الإيجار المعمول بها'},
              {'label': 'رقم الرخصة التجارية', 'value': t.commercialLicenseNumber?.isNotEmpty == true ? t.commercialLicenseNumber! : 'لا توجد رخصة تجارية مسجلة'},
              {'label': 'ملاحظات إضافية', 'value': t.notes?.isNotEmpty == true ? t.notes! : 'لا توجد ملاحظات'},
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // TAB 2: Documents & Attachments
  Widget _buildDocsTab() {
    final t = _tenant!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDocCard(
            title: 'الهوية الوطنية / الإقامة',
            subtitle: 'إثبات هوية المستأجر الشخصية المسجلة',
            imageFileName: t.idImage,
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildDocCard(
            title: 'نسخة العقد الورقي الموقّع',
            subtitle: 'النسخة الأصلية الموقعة والمختومة للعقد',
            imageFileName: t.contractImage,
            icon: Icons.draw_outlined,
          ),
          const SizedBox(height: 14),
          _buildDocCard(
            title: 'الرخصة التجارية',
            subtitle: 'السجل والترخيص التجاري المعتمد للمنشأة',
            imageFileName: t.commercialLicenseImage,
            icon: Icons.business_outlined,
          ),
        ],
      ),
    );
  }

  // TAB 3: Cheques Record & Gallery
  Widget _buildChecksTab() {
    final t = _tenant!;
    if (t.checkImagesList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'لا توجد صور شيكات مرفقة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'يمكنك رفع صور الشيكات وتحديث الدفعات من خلال تعديل العقد أو لوحة التحكم',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: t.checkImagesList.length,
      itemBuilder: (ctx, index) {
        final img = t.checkImagesList[index];
        final url = '${ApiEndpoints.uploadsBase}/$img';
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _previewImageFullscreen(url, 'شيك دفعة #${index + 1} - ${t.name}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.receipt_outlined, size: 36, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'شيك دفعة #${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 4: A4 Electronic Tenancy Contract Preview
  Widget _buildContractA4Tab() {
    final t = _tenant!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Action banner to download/print the exact A4 contract
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'وثيقــــة عقــــد إيجــــار الرسمية (A4)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      Text(
                        'نسخة طبق الأصل معتمدة رقمياً بالبيانات المحدثة',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('تحميل PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openContractPrint,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEFF2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const TabBar(
              indicator: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                color: AppColors.primary,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF334155),
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: 'الصفحة الأولى (بيانات العقد)'),
                Tab(text: 'الصفحة الثانية (الشروط القانونية)'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildA4PageOne(t),
                _buildA4PageTwo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildA4PageOne(TenantModel t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A4 Header
            const Center(
              child: Column(
                children: [
                  Text(
                    'وثيقــــة عقــــد إيجــــار',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6B2B2B)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'TENANCY CONTRACT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Leasor Details Table
            _buildA4SectionHeader('LEASOR DETAILS', 'تفاصيل المؤجر'),
            _buildA4TableRow('NAME:', t.lessorName ?? 'علاء مصطفي', ': الاسم'),
            _buildA4TableRow('MOBILE No.', t.lessorPhone ?? '01009931190', 'رقم الهاتف'),
            _buildA4TableRow('ID #', t.lessorId ?? '784-1965-3975208-7', 'رقم الهوية'),

            const SizedBox(height: 14),

            // Tenant Details Table
            _buildA4SectionHeader('TENANT DETAILS', 'تفاصيل المستأجر'),
            _buildA4TableRow('NAME:', t.name, ': الاسم'),
            _buildA4TableRow('MOBILE No.', t.phone, 'رقم الهاتف'),
            _buildA4TableRow('ID #', t.tenantIdNumber?.isNotEmpty == true ? t.tenantIdNumber! : '784-1965-5905376-2', 'رقم الهوية'),

            const SizedBox(height: 14),

            // Leased Unit Details Table
            _buildA4SectionHeader('LEASED UNIT DETAILS', 'تفاصيل الوحدة المؤجرة'),
            _buildA4TableRow('UNIT USAGE', t.unitUsage ?? 'سكن عائلي', 'استخدام الوحدة'),
            _buildA4TableRow('UNIT No.', t.unitNumber ?? '504', 'رقم الوحدة'),
            _buildA4TableRow('PROPERTY No.', t.propertyNumber ?? 'PROPA56720313', 'رقم العقار'),
            _buildA4TableRow('LOCATION', t.location ?? 'TOWN CENTER', 'المنطقة'),
            _buildA4TableRow('BLOCK No.', t.blockNumber ?? 'A', 'المربع'),
            _buildA4TableRow('PLOT No.', t.plotNumber ?? '5', 'رقم القطعة'),
            _buildA4TableRow('UNIT TYPE', t.unitType ?? '3 BHK', 'نوع الوحدة'),
            _buildA4TableRow('MAKANI No.', t.makaniNumber ?? '********', 'رقم مكاني'),
            _buildA4TableRow('ETIHAD WE No.', t.etihadWeNumber ?? '2000034793', 'رقم الكهرباء'),

            const SizedBox(height: 14),

            // Contract Details Table
            _buildA4SectionHeader('CONTRACT DETAILS', 'تفاصيل العقد'),
            _buildA4TableRow('CONTRACT NO', t.contractNumber ?? 'RENT25061768', 'رقم العقد'),
            _buildA4TableRow('AMOUNT (AED)', t.formattedRentAmount, 'قيمة العقد'),
            _buildA4TableRow('PERIOD', t.contractPeriod ?? 'One Year', 'مدة العقد'),
            _buildA4TableRow('START DATE', _formatDate(t.startDate), 'تاريخ البدء'),
            _buildA4TableRow('END DATE', _formatDate(t.endDate), 'تاريخ الانتهاء'),
            _buildA4TableRow('PAYMENT TERMS', t.paymentTerms?.isNotEmpty == true ? t.paymentTerms! : '${t.paymentCount ?? 1} دفعات', 'شروط الدفع'),

            const SizedBox(height: 24),

            // Official Stamp Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6B2B2B), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    'هذا العقد معتمد رقمياً ومسجل رسمياً بنظام مُستأجِر',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6B2B2B), fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This is a digitally certified tenancy contract',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildA4PageTwo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Column(
                children: [
                  Text(
                    'الشروط والأحكام القانونية المعتمدة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B2B2B)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'GENERAL TERMS & CONDITIONS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(height: 24, thickness: 1.5),
            _buildLegalArticle(
              'البند الأول: الغرض من الإيجار',
              'يقر المستأجر بأنه عاين المأجور المعاينة التامة النافية للجهالة وتَسَلَّمه بحالة جيدة وصالحة للاستعمال وفق الغرض المحدد في الصفحة الأولى، ويلتزم بعدم تغيير نوع الاستخدام أو التأجير من الباطن إلا بموافقة خطية من المؤجر.',
            ),
            _buildLegalArticle(
              'البند الثاني: سداد القيمة الإيجارية',
              'يلتزم المستأجر بسداد الأقساط الإيجارية في مواعيد استحقاقها المحددة وفق الشيكات المسلمة للمؤجر، وفي حال ارتداد أي شيك يحق للمؤجر اتخاذ الإجراءات القانونية اللازمة.',
            ),
            _buildLegalArticle(
              'البند الثالث: أعمال الصيانة والخدمات',
              'يلتزم المستأجر بالمحافظة على العين المؤجرة وإجراء الصيانة الداخلية الدورية الناتجة عن الاستهلاك، وتكون الصيانة الإنشائية والأساسية على عاتق المؤجر ما لم يكن الضرر ناشئاً عن سوء الاستخدام.',
            ),
            _buildLegalArticle(
              'البند الرابع: فواتير الخدمات العامة',
              'يلتزم المستأجر بسداد فواتير استهلاك الكهرباء والماء (اتحاد للماء والكهرباء) والغاز والخدمات ورسوم الصرف الصحي طوال فترة سريان العقد وحتى تسليم الوحدة خالية.',
            ),
            _buildLegalArticle(
              'البند الخامس: الإخلاء وانتهاء العقد',
              'يلتزم المستأجر بإخطار المؤجر خطياً برغبته في التجديد أو الإخلاء قبل موعد انتهاء العقد بمدة لا تقل عن 60 يوماً، وتسليم العين المؤجرة بحالتها الأصلية.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade50,
              child: const Text(
                'تخضع هذه الوثيقة وتفسير بنودها للقوانين والتشريعات العقارية المعتمدة لدى بلدية الفجيرة وقانون تنظيم العلاقة بين المؤجر والمستأجر رقم (1) لسنة 2011.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalArticle(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildA4SectionHeader(String en, String ar) {
    return Container(
      color: const Color(0xFF6B2B2B),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(en, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(ar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildA4TableRow(String enLabel, String value, String arLabel) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.black26),
          right: BorderSide(color: Colors.black26),
          bottom: BorderSide(color: Colors.black26),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.all(6),
            color: Colors.grey.shade100,
            child: Text(enLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              alignment: Alignment.center,
              child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          Container(
            width: 90,
            padding: const EdgeInsets.all(6),
            color: Colors.grey.shade100,
            alignment: Alignment.centerRight,
            child: Text(arLabel, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, String>> items,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          item['label']!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item['value']!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard({
    required String title,
    required String subtitle,
    required String? imageFileName,
    required IconData icon,
  }) {
    final hasImg = imageFileName != null && imageFileName.isNotEmpty;
    final imageUrl = hasImg ? '${ApiEndpoints.uploadsBase}/$imageFileName' : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasImg ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasImg ? AppColors.success.withValues(alpha: 0.3) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    hasImg ? 'مرفقة' : 'غير مرفقة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasImg ? AppColors.success : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasImg)
            InkWell(
              onTap: () => _previewImageFullscreen(imageUrl, title),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('اضغط للمعاينة المكبرة', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(icon, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const Text('لا يوجد مستند مرفق لهذا الحقل', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
