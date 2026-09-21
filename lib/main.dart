import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/mundas_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  runZonedGuarded(
    () {
      runApp(const MundasApp());

      // لا نؤخر تشغيل أول Frame بانتظار platform channel على iOS.
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]),
      );

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF4FAF8),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught Dart error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
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
        final mediaQuery = MediaQuery.maybeOf(context);
        final content = child ?? const SizedBox.shrink();

        if (mediaQuery == null) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: content,
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: const TextScaler.linear(1),
            ),
            child: content,
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
