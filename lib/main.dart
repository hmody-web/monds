import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/mundas_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF4FAF8),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const MundasApp());
}

class MundasApp extends StatelessWidget {
  const MundasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مندس',
      theme: buildMundasTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
          child: child!,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
