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

  await _applyTrueEdgeToEdge();
  await AppAudioService.prepareGlobalClick();
  await configureFloatingPreviewWindow();

  runApp(
    DevicePreview(
      enabled: kIsWeb && kDebugMode,
      builder: (_) => const MundasApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await _applyTrueEdgeToEdge();
  });
}
  Future<void> _applyTrueEdgeToEdge() async {
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

class MundasApp extends StatelessWidget {
  const MundasApp({super.key});

  Widget _edgeToEdgeContent(BuildContext context, Widget content) {
    final mediaQuery = MediaQuery.maybeOf(context);
    Widget result = Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );

    if (mediaQuery != null) {
      // Zero the inherited system padding for the whole app. This makes even
      // existing SafeArea widgets transparent to top/bottom insets, allowing
      // backgrounds and UI to extend beneath iOS/Android system bars.
      result = MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: const TextScaler.linear(1),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
        ),
        child: result,
      );
    }

    return AppClickSoundLayer(
      child: FloatingPreviewShell(child: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مندس',
      theme: buildMundasTheme(),
      locale: kIsWeb ? DevicePreview.locale(context) : null,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();

        if (kIsWeb) {
          // Apply zero safe-area padding *inside* DevicePreview's simulated
          // MediaQuery too, so Chrome preview matches real iPhone/Android.
          return DevicePreview.appBuilder(
            context,
            Builder(
              builder: (previewContext) =>
                  _edgeToEdgeContent(previewContext, content),
            ),
          );
        }

        return _edgeToEdgeContent(context, content);
      },
      home: const SplashScreen(),
    );
  }
}
