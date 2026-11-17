import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

/// يسمح بالاتصال بالسيرفر السحابي حتى في حال وجود اختلاف في توقيت شهادة SSL
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
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
