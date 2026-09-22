import 'dart:async';
import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';
import '../core/nav.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, mundasRoute(const HomeScreen()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MundasColors.primary,
      body: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .82, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (_, value, child) => Opacity(
              opacity: value.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(scale: value, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 218,
                  height: 218,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(52),
                    border: Border.all(color: MundasColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: MundasColors.ink,
                        offset: Offset(0, 10),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45),
                    child: Image.asset(
                      'assets/images/app_icon_1024.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'مندس',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    height: .95,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'منو يعرف السر؟ 👀',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
