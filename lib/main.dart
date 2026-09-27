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

  await _applyImmersiveFullscreen();
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
    await _applyImmersiveFullscreen();
  });
}

Future<void> _applyImmersiveFullscreen() async {
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

class MundasApp extends StatefulWidget {
  const MundasApp({super.key});

  @override
  State<MundasApp> createState() => _MundasAppState();
}

class _MundasAppState extends State<MundasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyImmersiveFullscreen();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyImmersiveFullscreen();
    }
  }

  Widget _immersiveContent(BuildContext context, Widget content) {
    final mediaQuery = MediaQuery.maybeOf(context);
    Widget result = Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );

    if (mediaQuery != null) {
      // Keep the app visually edge-to-edge, but restore a REAL transparent
      // top safety inset to every SafeArea in the app. The Scaffold/background
      // still paints behind the notch; only top text/buttons are pushed down.
      // This avoids the old coloured safety band while protecting every page.
      final view = View.of(context);
      final physicalTop = view.viewPadding.top / view.devicePixelRatio;
      final safeTop = (physicalTop > mediaQuery.viewPadding.top
              ? physicalTop
              : mediaQuery.viewPadding.top) +
          8.0;
      result = MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: const TextScaler.linear(1),
          padding: EdgeInsets.only(top: safeTop),
          viewPadding: EdgeInsets.only(top: safeTop),
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
      title: 'Sooky',
      theme: buildMundasTheme(),
      locale: kIsWeb ? DevicePreview.locale(context) : null,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();

        if (kIsWeb) {
          return DevicePreview.appBuilder(
            context,
            Builder(
              builder: (previewContext) =>
                  _immersiveContent(previewContext, content),
            ),
          );
        }

        return _immersiveContent(context, content);
      },
      home: const SplashScreen(),
    );
  }
}
