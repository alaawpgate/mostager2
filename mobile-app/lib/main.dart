import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_colors.dart';
import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const MostagerApp());
}

class MostagerApp extends StatelessWidget {
  const MostagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مُستأجِر - إدارة العقارات والعقود',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      // Arabic RTL Configuration
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;
  bool _serverOnline = false;
  String _statusMessage = 'جاري التحقق من الاتصال بالنظام...';

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'جاري الاتصال بالخادم: ${ApiService.baseUrl}...';
    });

    final res = await ApiService.get('/health');
    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _serverOnline = res.success;
      if (res.success) {
        _statusMessage = 'تم الاتصال بالنظام بنجاح ✅';
      } else {
        _statusMessage = res.message ?? 'تعذر الوصول إلى الخادم';
      }
    });
  }

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعدادات رابط السيرفر (API)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل رابط خادم بايثون المشغل لديك:\n'
              '• في المحاكي (Android Emulator): http://10.0.2.2:8080/api/v1\n'
              '• في الهاتف الحقيقي (واي فاي): http://IP_المحلي:8080/api/v1\n'
              '• في الماك أو المتصفح: http://127.0.0.1:8080/api/v1',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'رابط الخادم',
                hintText: 'http://127.0.0.1:8080/api/v1',
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await StorageService.saveBaseUrl(newUrl);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _checkServerConnection();
              }
            },
            child: const Text('حفظ واختبار'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated Brand Logo
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/img/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.home_work_rounded,
                        size: 54,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App Brand Name & Tagline
                const Text(
                  'مُستأجِر',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'إدارة العقارات والعقود والتنبيهات الذكية',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),

                const Spacer(),

                // Connection Status Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white12,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isChecking)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryLight,
                          ),
                        )
                      else
                        Icon(
                          _serverOnline ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: _serverOnline ? AppColors.success : AppColors.warning,
                          size: 22,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
                        tooltip: 'تغيير عنوان السيرفر',
                        onPressed: _showServerSettingsDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Retry Button if offline
                if (!_isChecking && !_serverOnline)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة محاولة الاتصال'),
                      onPressed: _checkServerConnection,
                    ),
                  ),

                const SizedBox(height: 24),
                const Text(
                  'الإصدار 2.5.0 • منصة إدارة العقارات المتكاملة',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
