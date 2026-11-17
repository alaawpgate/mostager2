import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _isChecking = true;
  bool _serverOnline = false;
  String _statusMessage = 'جاري الاتصال بنظام مُستأجِر...';

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();
    _checkServerConnection();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'جاري التحقق من الاتصال بالخادم...';
    });

    final res = await ApiService.get('/health', timeout: const Duration(seconds: 4));
    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _serverOnline = res.success;
      if (res.success) {
        _statusMessage = 'تم الاتصال بالنظام بنجاح ✅';
      } else {
        _statusMessage = res.message ?? 'تعذر الوصول إلى الخادم المحلي';
      }
    });

    if (res.success) {
      Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _navigateToNextScreen();
      });
    }
  }

  void _navigateToNextScreen() {
    final nextScreen = StorageService.hasToken()
        ? const DashboardScreen()
        : const LoginScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, anim, secAnim) => nextScreen,
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
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
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط الخادم',
                hintText: 'http://127.0.0.1:8080/api/v1',
                prefixIcon: Icon(Icons.link_rounded),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF070D18), // Very dark navy
              Color(0xFF0B1324), // Brand dark navy
              Color(0xFF0F172A), // Deep slate
              Color(0xFF092928), // Deep emerald glow
            ],
            stops: [0.0, 0.4, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Animated Logo Section
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Ambient Glow Aura
                          Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 45,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Outer Luxury Ring
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primaryLight,
                                  Color(0xFF0D9488),
                                  Color(0xFF1E293B),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0B1324),
                              ),
                              padding: const EdgeInsets.all(4),
                              // High-Definition Logo Image
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/img/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.apartment_rounded,
                                    size: 58,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Brand Title & Slogan
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'مُستأجِر',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Text(
                        'المنظومة الذكية لإدارة العقارات والعقود والتنبيهات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),

              // Server Status Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isChecking)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryLight,
                          ),
                        )
                      else
                        Icon(
                          _serverOnline ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
                          color: _serverOnline ? AppColors.success : AppColors.warning,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                        tooltip: 'ضبط عنوان الخادم',
                        onPressed: _showServerSettingsDialog,
                      ),
                    ],
                  ),
                ),
              ),

              // If offline or taking long, show manual continue button
              if (!_serverOnline && !_isChecking) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('إعادة الفحص'),
                          onPressed: _checkServerConnection,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _navigateToNextScreen,
                          child: const Text('تخطي والدخول'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Version & Copyright
              const Text(
                'نظام مُستأجِر للإدارة العقارية • الإصدار 2.5.0',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
