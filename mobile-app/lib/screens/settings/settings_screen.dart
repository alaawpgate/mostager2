import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../models/settings_model.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool showAppBar;
  const SettingsScreen({super.key, this.showAppBar = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  SystemSettingsModel? _settings;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _whats360Status;

  // Editing Controllers
  final _daysMonthController = TextEditingController();
  final _daysContractController = TextEditingController();
  final _monthlyMsgController = TextEditingController();
  final _contractMsgController = TextEditingController();
  bool _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    _userProfile = StorageService.getUser();
    _loadSettingsAndStatus();
  }

  @override
  void dispose() {
    _daysMonthController.dispose();
    _daysContractController.dispose();
    _monthlyMsgController.dispose();
    _contractMsgController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndStatus() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait([
      ApiService.get(ApiEndpoints.settings),
      ApiService.get(ApiEndpoints.whats360Status),
      ApiService.get(ApiEndpoints.profile),
    ]);

    if (!mounted) return;

    final settingsRes = results[0];
    final statusRes = results[1];
    final profileRes = results[2];

    if (profileRes.success && profileRes.data != null) {
      final json = profileRes.data as Map<String, dynamic>;
      final profile = json['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        await StorageService.saveUser(profile);
        _userProfile = profile;
      }
    }

    if (settingsRes.success && settingsRes.data != null) {
      final json = settingsRes.data as Map<String, dynamic>;
      final s = SystemSettingsModel.fromJson(json['settings'] as Map<String, dynamic>? ?? {});
      _settings = s;
      _daysMonthController.text = s.daysBeforeMonthEnd.toString();
      _daysContractController.text = s.daysBeforeContractEnd.toString();
      _monthlyMsgController.text = s.monthlyMessage;
      _contractMsgController.text = s.contractEndMessage;
    }

    if (statusRes.success && statusRes.data != null) {
      final json = statusRes.data as Map<String, dynamic>;
      _whats360Status = json['status'] as Map<String, dynamic>? ?? {};
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);

    final payload = {
      'days_before_month_end': int.tryParse(_daysMonthController.text.trim()) ?? 5,
      'days_before_contract_end': int.tryParse(_daysContractController.text.trim()) ?? 30,
      'monthly_message': _monthlyMsgController.text.trim(),
      'contract_end_message': _contractMsgController.text.trim(),
    };

    final res = await ApiService.put(ApiEndpoints.settings, body: payload);

    if (!mounted) return;
    setState(() => _isSavingSettings = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'فشل حفظ الإعدادات'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    bool isTesting = false;
    String? testResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إعدادات رابط السيرفر (API)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل رابط خادم بايثون المشغل لديك:\n'
                  '• المحاكي (Emulator): http://10.0.2.2:8080/api/v1\n'
                  '• جهاز حقيقي (WiFi): http://192.168.x.x:8080/api/v1\n'
                  '• السيرفر السحابي: https://example.com/api/v1',
                  style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الخادم',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    testResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: testResult!.contains('نجح') ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        testResult = null;
                      });
                      try {
                        final testRes = await ApiService.get('/health', timeout: const Duration(seconds: 4));
                        setDialogState(() {
                          isTesting = false;
                          testResult = testRes.success ? '✅ نجح الاتصال بالخادم!' : '❌ تعذر الاتصال بالخادم';
                        });
                      } catch (_) {
                        setDialogState(() {
                          isTesting = false;
                          testResult = '❌ خطأ في الاتصال';
                        });
                      }
                    },
              child: isTesting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('اختبار الاتصال'),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = controller.text.trim();
                await StorageService.setCustomBaseUrl(url.isEmpty ? null : url);
                if (!mounted) return;
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadSettingsAndStatus();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (newPassController.text != confirmPassController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
                        );
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      setDialogState(() => isSaving = true);
                      final res = await ApiService.put(
                        ApiEndpoints.profile,
                        body: {
                          'old_password': oldPassController.text,
                          'new_password': newPassController.text,
                        },
                      );
                      setDialogState(() => isSaving = false);
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(res.message ?? 'تمت المعالجة'),
                          backgroundColor: res.success ? AppColors.success : AppColors.danger,
                        ),
                      );
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من النظام؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearAuth();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            onRefresh: _loadSettingsAndStatus,
            color: AppColors.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 14),
                  _buildServerConfigCard(),
                  const SizedBox(height: 14),
                  _buildWhats360Card(),
                  const SizedBox(height: 14),
                  _buildAutomatedScheduleCard(),
                  const SizedBox(height: 14),
                  _buildAppInfoCard(),
                  const SizedBox(height: 20),
                  // Logout Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج من الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: _logout,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );

    if (!widget.showAppBar) {
      return Scaffold(body: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadSettingsAndStatus,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildProfileCard() {
    final fullName = _userProfile?['full_name'] ?? 'مدير النظام';
    final username = _userProfile?['username'] ?? 'admin';
    final email = _userProfile?['email'] ?? '';
    final avatar = _userProfile?['avatar']?.toString();
    final hasCustomAvatar = avatar != null && avatar.isNotEmpty && avatar != 'avatar.png' && avatar != 'null';
    final avatarUrl = hasCustomAvatar ? '${ApiEndpoints.uploadsBase}/$avatar' : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    )
                  : const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('@$username ${email.isNotEmpty ? "• $email" : ""}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            TextButton(
              onPressed: _showChangePasswordDialog,
              child: const Text('تغيير الرمز'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dns_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('عنوان خادم النظام (API Server)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Text(ApiService.baseUrl, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('تعديل عنوان السيرفر'),
                onPressed: _showServerConfigDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhats360Card() {
    final status = _whats360Status?['status']?.toString() ?? 'غير متصل';
    final isConnected = status.contains('متصل') || status.toLowerCase().contains('connected') || _settings?.whats360Configured == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 20),
                const SizedBox(width: 8),
                const Text('بوابة الواتساب (Whats360)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isConnected ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isConnected ? 'متصل' : 'غير متصل',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isConnected ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isConnected
                  ? 'بوابة الإرسال الآلي للرسائل تعمل وترسل الإشعارات والتذكيرات تلقائياً.'
                  : 'يمكنك استخدام الإرسال المباشر عبر تطبيق الواتساب أو ضبط مفاتيح Whats360 في خادم بايثون.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomatedScheduleCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('توقيت التنبيهات التلقائية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _daysMonthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'قبل نهاية الشهر بـ (أيام)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _daysContractController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'قبل نهاية العقد بـ (أيام)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _monthlyMsgController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'نص التذكير الشهري التلقائي',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contractMsgController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'نص تذكير انتهاء العقد التلقائي',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingSettings ? null : _saveSettings,
                child: _isSavingSettings
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ إعدادات التنبيهات'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            'نظام مُستأجِر للإدارة العقارية - النسخة الذكية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            'الإصدار 2.5.0 • جميع الحقوق محفوظة © 2026',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
