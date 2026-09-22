import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/mundas_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MundasApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF4FAF8),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  });
}

class MundasApp extends StatelessWidget {
  const MundasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مندس',
      theme: buildMundasTheme(),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final mediaQuery = MediaQuery.maybeOf(context);
        final rtl = Directionality(
          textDirection: TextDirection.rtl,
          child: content,
        );
        if (mediaQuery == null) return rtl;
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: const TextScaler.linear(1)),
          child: rtl,
        );
      },
      home: const SplashScreen(),
    );
  }
}
