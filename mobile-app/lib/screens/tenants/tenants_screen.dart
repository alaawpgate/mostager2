import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../models/tenant_model.dart';
import 'add_edit_tenant_screen.dart';
import 'tenant_detail_screen.dart';

class TenantsScreen extends StatefulWidget {
  final bool showAppBar;
  const TenantsScreen({super.key, this.showAppBar = true});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  String? _errorMessage;
  List<TenantModel> _allTenants = [];
  List<TenantModel> _filteredTenants = [];
  String _selectedFilter = 'الكل'; // 'الكل', 'سكني', 'تجاري', 'منتهي'

  @override
  void initState() {
    super.initState();
    _fetchTenants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTenants({String? search}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final res = await ApiService.get(ApiEndpoints.tenants, queryParams: queryParams);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final json = res.data as Map<String, dynamic>;
      final list = (json['tenants'] as List<dynamic>? ?? [])
          .map((item) => TenantModel.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _allTenants = list;
        _applyLocalFilter();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res.message ?? 'تعذر تحميل قائمة المستأجرين';
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchTenants(search: query);
    });
  }

  void _applyLocalFilter() {
    if (_selectedFilter == 'الكل') {
      _filteredTenants = List.from(_allTenants);
    } else if (_selectedFilter == 'سكني') {
      _filteredTenants = _allTenants.where((t) => t.contractType.contains('سكني')).toList();
    } else if (_selectedFilter == 'تجاري') {
      _filteredTenants = _allTenants.where((t) => t.contractType.contains('تجاري')).toList();
    } else if (_selectedFilter == 'منتهي') {
      _filteredTenants = _allTenants.where((t) => t.isExpired).toList();
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyLocalFilter();
    });
  }

  Future<void> _deleteTenant(TenantModel tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستأجر'),
        content: Text('هل أنت متأكد من حذف بيانات المستأجر "${tenant.name}"؟\nلا يمكن التراجع عن هذه الخطوة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await ApiService.delete(ApiEndpoints.tenantDetail(tenant.id));
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المستأجر بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchTenants(search: _searchController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'فشل حذف المستأجر'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent('مرحباً بك أستاذ $name، نتمنى لك يوماً سعيداً من إدارة العقارات.');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')),
        );
      }
    } catch (_) {}
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
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
    final content = RefreshIndicator(
      onRefresh: () => _fetchTenants(search: _searchController.text),
      color: AppColors.primary,
      child: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _filteredTenants.isEmpty
                        ? _buildEmptyState()
                        : _buildTenantsList(),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return Scaffold(
        body: content,
        floatingActionButton: _buildFab(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المستأجرين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث القائمة',
            onPressed: () => _fetchTenants(search: _searchController.text),
          ),
        ],
      ),
      body: content,
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text(
        'إضافة مستأجر',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AddEditTenantScreen()),
        );
        if (result == true) {
          _fetchTenants(search: _searchController.text);
        }
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search Input Field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو رقم الهاتف...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _fetchTenants();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', _allTenants.length),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'سكني',
                  _allTenants.where((t) => t.contractType.contains('سكني')).length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'تجاري',
                  _allTenants.where((t) => t.contractType.contains('تجاري')).length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'منتهي',
                  _allTenants.where((t) => t.isExpired).length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => _setFilter(label),
    );
  }

  Widget _buildTenantsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _filteredTenants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final tenant = _filteredTenants[index];
        return _buildTenantCard(tenant);
      },
    );
  }

  Widget _buildTenantCard(TenantModel tenant) {
    final isExpired = tenant.isExpired;
    final remainingDays = tenant.remainingDays;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isExpired
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final res = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TenantDetailScreen(tenantId: tenant.id),
            ),
          );
          if (res == true) {
            _fetchTenants(search: _searchController.text);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Avatar, Name, Contract Badge, Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tenant Avatar (Image or Initial)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isExpired
                          ? AppColors.danger.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: (tenant.hasIdImage && tenant.idImage != null && tenant.idImage!.isNotEmpty)
                        ? Image.network(
                            '${ApiEndpoints.uploadsBase}/${tenant.idImage}',
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            errorBuilder: (_, _, _) => Text(
                              tenant.initialLetter,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isExpired ? AppColors.danger : AppColors.primary,
                              ),
                            ),
                          )
                        : Text(
                            tenant.initialLetter,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isExpired ? AppColors.danger : AppColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: tenant.contractType.contains('تجاري')
                                    ? Colors.amber.shade50
                                    : AppColors.primaryLight.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tenant.contractType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tenant.contractType.contains('تجاري')
                                      ? Colors.amber.shade900
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            if (isExpired) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'منتهي',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ] else if (remainingDays != null && remainingDays <= 30) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'متبقي $remainingDays يوم',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) async {
                      if (val == 'edit') {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditTenantScreen(tenant: tenant),
                          ),
                        );
                        if (res == true) {
                          _fetchTenants(search: _searchController.text);
                        }
                      } else if (val == 'delete') {
                        _deleteTenant(tenant);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('تعديل البيانات'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('حذف المستأجر', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Leased Unit & Property Highlights
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tenant.displayUnitInfo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (tenant.contractNumber != null && tenant.contractNumber!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        tenant.contractNumber!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Financial & Cheques Row
              Row(
                children: [
                  // Rent Value
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 13, color: Colors.teal.shade800),
                        const SizedBox(width: 4),
                        Text(
                          tenant.formattedRentAmount,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Cheques count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 13, color: Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Text(
                          '${tenant.paymentCount ?? tenant.checkCount} دفعة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // End date
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        tenant.endDate != null ? _formatDate(tenant.endDate) : 'عقد ساري',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isExpired ? AppColors.danger : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Document Attachments Indicators
              Row(
                children: [
                  _buildDocBadge('الهوية', tenant.hasIdImage),
                  const SizedBox(width: 6),
                  _buildDocBadge('العقد الورقي', tenant.hasContractImage),
                  const SizedBox(width: 6),
                  _buildDocBadge('الشيكات (${tenant.checkCount})', tenant.checkCount > 0),
                  if (tenant.hasLicenseImage || (tenant.commercialLicenseNumber != null && tenant.commercialLicenseNumber!.isNotEmpty)) ...[
                    const SizedBox(width: 6),
                    _buildDocBadge('الرخصة', tenant.hasLicenseImage),
                  ],
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),

              // Details: Phone & Dates
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      tenant.phone.isNotEmpty ? tenant.phone : 'لا يوجد هاتف',
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.date_range_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    tenant.endDate != null ? 'ينتهي: ${_formatDate(tenant.endDate)}' : 'عقد ساري',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired ? AppColors.danger : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Action Buttons Row: WhatsApp, Call, View
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('واتساب', style: TextStyle(fontSize: 12)),
                      onPressed: tenant.phone.isNotEmpty
                          ? () => _openWhatsApp(tenant.phone, tenant.name)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.call_outlined, size: 16),
                      label: const Text('اتصال', style: TextStyle(fontSize: 12)),
                      onPressed: tenant.phone.isNotEmpty
                          ? () => _makeCall(tenant.phone)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'عرض الملف الكامل',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    onPressed: () async {
                      final res = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TenantDetailScreen(tenantId: tenant.id),
                        ),
                      );
                      if (res == true) {
                        _fetchTenants(search: _searchController.text);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocBadge(String label, bool isAttached) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isAttached
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAttached
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAttached ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 11,
            color: isAttached ? AppColors.success : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isAttached ? FontWeight.bold : FontWeight.normal,
              color: isAttached ? AppColors.success : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            const Text(
              'لا يوجد مستأجرين مطابقين للبحث',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'جرّب تغيير كلمات البحث أو الفلاتر المختارة',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مستأجر جديد'),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditTenantScreen()),
                );
                if (result == true) {
                  _fetchTenants(search: _searchController.text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'حدث خطأ أثناء تحميل المستأجرين',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              onPressed: () => _fetchTenants(search: _searchController.text),
            ),
          ],
        ),
      ),
    );
  }
}
