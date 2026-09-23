import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/floating_preview.dart';
import 'core/mundas_theme.dart';
import 'screens/splash_screen.dart';
import 'services/app_audio_service.dart';
import 'widgets/app_click_sound_layer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prepare the short global click sound up-front. Playback still waits for
  // an actual user gesture, which keeps web/mobile autoplay policies happy.
  await AppAudioService.prepareGlobalClick();

  // On Windows this turns the app itself into a frameless, phone-sized,
  // always-on-top preview window. Other platforms are left unchanged.
  await configureFloatingPreviewWindow();

  runApp(
    DevicePreview(
      enabled: kIsWeb && kDebugMode,
      builder: (_) => const MundasApp(),
    ),
  );

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
      locale: kIsWeb ? DevicePreview.locale(context) : null,
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();

        // Keep Device Preview simulation active only on Chrome/Web.
        if (kIsWeb) {
          content = DevicePreview.appBuilder(context, content);
        }

        final mediaQuery = MediaQuery.maybeOf(context);
        Widget rtl = Directionality(
          textDirection: TextDirection.rtl,
          child: content,
        );

        if (mediaQuery != null) {
          rtl = MediaQuery(
            data: mediaQuery.copyWith(textScaler: const TextScaler.linear(1)),
            child: rtl,
          );
        }

        return AppClickSoundLayer(
          child: FloatingPreviewShell(child: rtl),
        );
      },
      home: const SplashScreen(),
    );
  }
}
