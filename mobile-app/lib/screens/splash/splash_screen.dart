import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Primary entrance animation controller
  late AnimationController _entranceController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _chipsSlide;
  late Animation<double> _chipsFade;
  late Animation<double> _progressFade;

  // Continuous ambient / breathing animation controller
  late AnimationController _ambientController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowRotation;

  // Connection checking state
  bool _isChecking = true;
  bool _serverOnline = false;
  String _statusText = 'جاري الاتصال بالسيرفر السحابي...';
  double _loadProgress = 0.15;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation (Staggered forward build-up)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeIn),
      ),
    );

    _chipsSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _chipsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 0.9, curve: Curves.easeIn),
      ),
    );

    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. Ambient continuous loop (Aurora orbs + Ring rotation + Breathing aura)
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _ambientController,
        curve: Curves.easeInOut,
      ),
    );

    _glowRotation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _ambientController,
        curve: Curves.linear,
      ),
    );

    _entranceController.forward();
    _startStartupSequence();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _startStartupSequence() async {
    // Stage 1: Initializing local state
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _loadProgress = 0.45;
      _statusText = 'مزامنة الإعدادات والتشفير...';
    });

    // Stage 2: Check server connectivity
    final startTime = DateTime.now();
    final res = await ApiService.get('/health', timeout: const Duration(seconds: 4));
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;

    // Ensure smooth visual pacing (at least 1500ms total)
    if (elapsed < 1200) {
      await Future.delayed(Duration(milliseconds: 1200 - elapsed));
    }
    if (!mounted) return;

    if (res.success) {
      setState(() {
        _isChecking = false;
        _serverOnline = true;
        _loadProgress = 1.0;
        _statusText = 'النظام متصل وجاهز • جاري الدخول';
      });

      // Smooth exit transition
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _navigateToNextScreen();
    } else {
      setState(() {
        _isChecking = false;
        _serverOnline = false;
        _loadProgress = 0.85;
        _statusText = 'تعذر الاتصال المباشر • يمكنك المتابعة أو الفحص';
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
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, anim, secAnim) => nextScreen,
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dns_rounded, color: AppColors.primaryLight, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'إعدادات السيرفر السحابي',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عنوان الخادم المتصل به التطبيق:',
              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'https://mostager.virilax.shop/api/v1',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primaryLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await StorageService.saveBaseUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {
                  _isChecking = true;
                  _statusText = 'جاري التحقق من العنوان الجديد...';
                });
                _startStartupSequence();
              }
            },
            child: Text(
              'حفظ واختبار',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF040812), // Ultra deep midnight
      body: Stack(
        children: [
          // 1. Dynamic Animated Ambient Glow Canvas
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) {
              final sinVal = math.sin(_ambientController.value * 2 * math.pi);
              final cosVal = math.cos(_ambientController.value * 2 * math.pi);

              return Stack(
                children: [
                  // Top Emerald / Teal Aurora Orb
                  Positioned(
                    top: -60 + (sinVal * 25),
                    right: -40 + (cosVal * 30),
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF0D9488).withValues(alpha: 0.35 + (sinVal * 0.08)),
                            const Color(0xFF14B8A6).withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Center-Left Indigo / Cyan Deep Glow
                  Positioned(
                    top: size.height * 0.38 + (cosVal * 20),
                    left: -90 + (sinVal * 20),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: 0.25),
                            const Color(0xFF0F766E).withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Teal Anchor Flare
                  Positioned(
                    bottom: -80 - (sinVal * 20),
                    left: size.width * 0.2,
                    child: Container(
                      width: 340,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF0F766E).withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.75],
                        ),
                      ),
                    ),
                  ),

                  // Floating Subtitle Bokeh Particles
                  CustomPaint(
                    size: Size(size.width, size.height),
                    painter: _LuxuryParticlesPainter(
                      progress: _ambientController.value,
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. Top Bar (Discreet Settings Button)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: FadeTransition(
                  opacity: _progressFade,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
                      tooltip: 'إعدادات السيرفر',
                      onPressed: _showServerSettingsDialog,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Main Centerpiece (Hero Animated Logo, Title & Features)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // HERO LOGO CONTAINER WITH ROTATING GLOW RING
                  AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: child,
                        ),
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _ambientController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Ambient Breathing Halo
                            Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 175,
                                height: 175,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF14B8A6).withValues(alpha: 0.38),
                                      blurRadius: 55,
                                      spreadRadius: 8,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                                      blurRadius: 40,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Continuous Rotating Gradient Neon Orbit Ring
                            Transform.rotate(
                              angle: _glowRotation.value,
                              child: Container(
                                width: 154,
                                height: 154,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      const Color(0xFF2DD4BF), // Bright neon teal
                                      const Color(0xFF0EA5E9), // Neon cyan
                                      Colors.transparent,
                                      const Color(0xFF0D9488).withValues(alpha: 0.2),
                                      const Color(0xFF2DD4BF),
                                    ],
                                    stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Glassmorphic Inner Frame
                            Container(
                              width: 144,
                              height: 144,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF08101E),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 25,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Center(
                                child: Image.asset(
                                  'assets/img/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.apartment_rounded,
                                    size: 64,
                                    color: Color(0xFF2DD4BF),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // BRAND NAME & EMBLEM
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'مُستأجِر',
                                style: GoogleFonts.cairo(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Animated Breathing Cyan Accent Dot
                              AnimatedBuilder(
                                animation: _ambientController,
                                builder: (context, _) {
                                  return Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2DD4BF),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2DD4BF).withValues(
                                            alpha: 0.6 + (math.sin(_ambientController.value * 2 * math.pi) * 0.3),
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Luxury Enterprise Tagline Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  const Color(0xFF0D9488).withValues(alpha: 0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: Color(0xFF2DD4BF),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'المنظومة السحابية لإدارة وتوثيق العقود العقارية',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 3 HIGH-TECH FEATURE CHIPS
                  SlideTransition(
                    position: _chipsSlide,
                    child: FadeTransition(
                      opacity: _chipsFade,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFeatureBadge(Icons.domain_rounded, 'إدارة الوحدات'),
                          const SizedBox(width: 8),
                          _buildFeatureBadge(Icons.auto_graph_rounded, 'متابعة الشيكات'),
                          const SizedBox(width: 8),
                          _buildFeatureBadge(Icons.chat_bubble_outline_rounded, 'تنبيهات واتساب'),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // 4. ANIMATED MODERN PROGRESS CAPSULE
                  FadeTransition(
                    opacity: _progressFade,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1324).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _serverOnline
                                  ? AppColors.success.withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.10),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Status Indicator Icon / Spinner
                                  if (_isChecking)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                                      ),
                                    )
                                  else if (_serverOnline)
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  const SizedBox(width: 12),

                                  // Status text
                                  Expanded(
                                    child: Text(
                                      _statusText,
                                      style: GoogleFonts.cairo(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _serverOnline ? Colors.white : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),

                                  // Version or latency pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'v2.5',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Sleek Smooth Glowing Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 4,
                                      width: double.infinity,
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                    AnimatedFractionallySizedBox(
                                      duration: const Duration(milliseconds: 600),
                                      curve: Curves.easeOutCubic,
                                      widthFactor: _loadProgress,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0D9488),
                                              Color(0xFF2DD4BF),
                                              Color(0xFF38BDF8),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Offline/Retry Actions (Only when server check fails)
                        if (!_serverOnline && !_isChecking) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded, size: 17),
                                  label: Text('إعادة المحاولة', style: GoogleFonts.cairo(fontSize: 12)),
                                  onPressed: () {
                                    setState(() {
                                      _isChecking = true;
                                      _loadProgress = 0.3;
                                      _statusText = 'جاري إعادة الاتصال...';
                                    });
                                    _startStartupSequence();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                                  label: Text('الدخول المباشر', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: _navigateToNextScreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Footer Copyright
                  FadeTransition(
                    opacity: _progressFade,
                    child: Text(
                      'نظام مُستأجِر للإدارة العقارية المتكاملة © 2026',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2DD4BF)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Floating Bokeh / Light Particles Painter
class _LuxuryParticlesPainter extends CustomPainter {
  final double progress;

  _LuxuryParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaints = [
      Paint()
        ..color = const Color(0xFF2DD4BF).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      Paint()
        ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      Paint()
        ..color = const Color(0xFF14B8A6).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    ];

    // Seeded fixed particles with smooth floating sine drift
    const particles = [
      {'x': 0.15, 'y': 0.22, 'r': 6.0, 'speed': 1.0, 'p': 0},
      {'x': 0.85, 'y': 0.18, 'r': 8.5, 'speed': 1.4, 'p': 1},
      {'x': 0.72, 'y': 0.45, 'r': 5.0, 'speed': 0.8, 'p': 2},
      {'x': 0.28, 'y': 0.58, 'r': 9.0, 'speed': 1.2, 'p': 0},
      {'x': 0.90, 'y': 0.75, 'r': 7.0, 'speed': 1.5, 'p': 1},
      {'x': 0.12, 'y': 0.82, 'r': 8.0, 'speed': 0.9, 'p': 2},
      {'x': 0.48, 'y': 0.12, 'r': 4.5, 'speed': 1.1, 'p': 0},
      {'x': 0.62, 'y': 0.88, 'r': 6.5, 'speed': 1.3, 'p': 1},
    ];

    for (final p in particles) {
      final speed = p['speed'] as double;
      final paintIdx = p['p'] as int;
      final baseRadius = p['r'] as double;

      final dy = math.sin((progress * speed * 2 * math.pi) + (p['x'] as double) * 5) * 14;
      final dx = math.cos((progress * speed * 2 * math.pi) + (p['y'] as double) * 5) * 10;

      final cx = (p['x'] as double) * size.width + dx;
      final cy = (p['y'] as double) * size.height + dy;

      canvas.drawCircle(
        Offset(cx, cy),
        baseRadius + (math.sin(progress * 2 * math.pi) * 1.5),
        particlePaints[paintIdx],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LuxuryParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
