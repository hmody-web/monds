import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';
import '../core/nav.dart';
import '../widgets/dot_background.dart';
import '../widgets/mundas_button.dart';
import '../widgets/mundas_card.dart';
import 'local/local_players_screen.dart';
import 'multiplayer/multiplayer_entry_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    Container(
                      width: width < 390 ? 128 : 148,
                      height: width < 390 ? 128 : 148,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: MundasColors.ink, width: 2.3),
                        boxShadow: const [BoxShadow(color: MundasColors.ink, offset: Offset(0, 7), blurRadius: 0)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('مندس', style: TextStyle(fontSize: 48, height: .95, color: MundasColors.ink)),
                    const SizedBox(height: 9),
                    const Text(
                      'ارسم بذكاء، اخدع أصدقاءك، واكتشف من المندس 👀',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: MundasColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: MundasButton(
                        label: 'العب على جهاز واحد',
                        icon: Icons.phone_iphone_rounded,
                        onPressed: () => Navigator.push(context, mundasRoute(const LocalPlayersScreen())),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: MundasButton(
                        label: 'العب مع أصدقائك',
                        icon: Icons.groups_2_rounded,
                        color: MundasColors.ink,
                        onPressed: () => Navigator.push(context, mundasRoute(const MultiplayerEntryScreen())),
                      ),
                    ),
                    const SizedBox(height: 24),
                    MundasCard(
                      color: MundasColors.paper,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(color: MundasColors.gold.withOpacity(.35), shape: BoxShape.circle),
                            child: const Icon(Icons.lightbulb_rounded, color: MundasColors.ink),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('شلون تنلعب؟', style: TextStyle(fontSize: 18)),
                                SizedBox(height: 4),
                                Text(
                                  'الكل يعرف الكلمة إلا المندس. كل لاعب يضيف جزءاً للرسم، وبعدها تصوّتون على الشخص المشبوه.',
                                  style: TextStyle(fontSize: 13.5, color: MundasColors.muted, height: 1.55),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('مجانية بالكامل • بدون حساب • اللعب المحلي بدون إنترنت', style: TextStyle(fontSize: 12, color: MundasColors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
