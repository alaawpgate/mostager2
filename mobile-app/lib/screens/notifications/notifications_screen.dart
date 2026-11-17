import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../models/notification_model.dart';
import '../../models/tenant_model.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  const NotificationsScreen({super.key, this.showAppBar = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Logs state
  bool _isLoadingLogs = true;
  String? _logsError;
  List<NotificationLogModel> _logs = [];

  // Templates state
  List<MessageTemplateModel> _templates = [];

  // Send message form state
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedNotifType = 'تنبيه استحقاق إيجار';
  bool _isSending = false;

  final List<String> _notifTypes = [
    'تنبيه استحقاق إيجار',
    'تنبيه نهاية عقد',
    'إشعار سداد',
    'تنبيه عام ومباشر',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLogs();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoadingLogs = true;
      _logsError = null;
    });

    final res = await ApiService.get(ApiEndpoints.notificationLogs, queryParams: {'limit': '50', 'offset': '0'});
    if (!mounted) return;

    if (res.success && res.data != null) {
      final json = res.data as Map<String, dynamic>;
      final list = (json['logs'] as List<dynamic>? ?? [])
          .map((item) => NotificationLogModel.fromJson(item as Map<String, dynamic>))
          .toList();
      setState(() {
        _logs = list;
        _isLoadingLogs = false;
      });
    } else {
      setState(() {
        _isLoadingLogs = false;
        _logsError = res.message ?? 'تعذر تحميل سجل الإشعارات';
      });
    }
  }

  Future<void> _fetchTemplates() async {
    final res = await ApiService.get(ApiEndpoints.notificationTemplates);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final json = res.data as Map<String, dynamic>;
      final list = (json['templates'] as List<dynamic>? ?? [])
          .map((item) => MessageTemplateModel.fromJson(item as Map<String, dynamic>))
          .toList();
      setState(() => _templates = list);
    }
  }

  Future<void> _sendNotificationViaApi() async {
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الهاتف أولاً'), backgroundColor: AppColors.warning),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة نص الرسالة المراد إرسالها'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSending = true);

    final res = await ApiService.post(
      ApiEndpoints.sendNotification,
      body: {
        'phone': phone,
        'tenant_name': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'مستأجر',
        'message': message,
        'notification_type': _selectedNotifType,
      },
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'تمت المعالجة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchLogs();
      _tabController.animateTo(0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'فشل الإرسال'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _openDirectWhatsApp() async {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent(_messageController.text.trim());
    final url = Uri.parse('https://wa.me/$phone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showTenantPicker() async {
    final res = await ApiService.get(ApiEndpoints.tenants);
    if (!mounted) return;
    if (!res.success || res.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل قائمة المستأجرين')),
      );
      return;
    }

    final json = res.data as Map<String, dynamic>;
    final list = (json['tenants'] as List<dynamic>? ?? [])
        .map((e) => TenantModel.fromJson(e as Map<String, dynamic>))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'اختر مستأجر لملء بيانات الإرسال تلقائياً',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final t = list[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(t.initialLetter, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(t.phone, textDirection: TextDirection.ltr),
                    onTap: () {
                      setState(() {
                        _nameController.text = t.name;
                        _phoneController.text = t.phone;
                        _messageController.text =
                            'مرحباً بك أستاذ ${t.name}، نود تذكيركم بموعد استحقاق الإيجار القادم. شاكرين حسن تعاونكم.';
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogDetail(NotificationLogModel log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              log.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: log.isSuccess ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 8),
            Text(log.notificationType, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستأجر: ${log.tenantName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('الهاتف: ${log.phoneNumber}', textDirection: TextDirection.ltr),
            const SizedBox(height: 4),
            Text('تاريخ الإرسال: ${log.sentAt ?? 'غير محدد'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            const Text('محتوى الرسالة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(log.messageContent, style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final cleanPhone = log.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
              final msg = Uri.encodeComponent(log.messageContent);
              launchUrl(Uri.parse('https://wa.me/$cleanPhone?text=$msg'), mode: LaunchMode.externalApplication);
            },
            child: const Text('إعادة الإرسال عبر واتساب'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'سجل التنبيهات'),
              Tab(icon: Icon(Icons.send_rounded, size: 20), text: 'إرسال رسالة فورية'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLogsTab(),
              _buildSendTab(),
            ],
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return Scaffold(body: content);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الرسائل والتنبيهات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث السجل',
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildLogsTab() {
    if (_isLoadingLogs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_logsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(_logsError!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchLogs, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            const Text('لا توجد تنبيهات مرسلة حتى الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('ستظهر الرسائل التلقائية والفورية هنا', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, index) {
          final log = _logs[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showLogDetail(log),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: log.isSuccess
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.danger.withValues(alpha: 0.12),
                          child: Icon(
                            log.isSuccess ? Icons.check_rounded : Icons.close_rounded,
                            size: 18,
                            color: log.isSuccess ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.tenantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(log.notificationType, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: log.isSuccess
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: log.isSuccess ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      log.messageContent,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(log.phoneNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                        Text(
                          log.sentAt != null ? log.sentAt!.split(' ')[0] : '',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Select from tenants button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.contacts_rounded, color: AppColors.primary),
            label: const Text('اختيار مستأجر من القائمة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            onPressed: _showTenantPicker,
          ),
          const SizedBox(height: 16),

          // Tenant Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم المستأجر',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),

          // Phone Number
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم هاتف الواتساب *',
              hintText: '0500000000',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // Notification Type Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedNotifType,
            decoration: const InputDecoration(
              labelText: 'نوع التنبيه',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
            items: _notifTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedNotifType = val);
            },
          ),
          const SizedBox(height: 14),

          // Templates list chips (if available)
          if (_templates.isNotEmpty) ...[
            const Text('قوالب رسائل جاهزة:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _templates.map((tpl) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ActionChip(
                      label: Text(tpl.name),
                      backgroundColor: AppColors.background,
                      onPressed: () {
                        setState(() {
                          _messageController.text = tpl.content;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Message content
          TextFormField(
            controller: _messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'نص الرسالة *',
              hintText: 'اكتب نص التنبيه أو تذكير الإيجار هنا...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              icon: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_isSending ? 'جاري الإرسال...' : 'إرسال عبر البوابة (Whats360)'),
              onPressed: _isSending ? null : _sendNotificationViaApi,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('فتح في تطبيق واتساب مباشرة'),
              onPressed: _openDirectWhatsApp,
            ),
          ),
        ],
      ),
    );
  }
}
