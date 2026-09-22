import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_card.dart';
import '../../widgets/mundas_scaffold.dart';
import 'role_reveal_screen.dart';

class GameOverScreen extends StatefulWidget {
  final LocalGameSession session;
  const GameOverScreen({super.key, required this.session});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;
    final imposterWins = !caught || widget.session.guessCorrect == true;
    final imposter = widget.session.players[widget.session.imposterIndex];

    return MundasScaffold(
      title: 'نتيجة الجولة',
      showBack: false,
      gameExit: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Text(
                  imposterWins ? '😎' : '🎉',
                  style: const TextStyle(fontSize: 84),
                ),
                const SizedBox(height: 8),
                Text(
                  imposterWins ? 'المندس فاز!' : 'الطاقم فاز!',
                  style: TextStyle(
                    fontSize: 40,
                    color: imposterWins
                        ? MundasColors.coral
                        : MundasColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .78, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.elasticOut,
                  builder: (_, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: MundasColors.coral,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'المندس كان',
                          style: TextStyle(
                            color: MundasColors.muted,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          imposter.name,
                          style: const TextStyle(
                            color: MundasColors.coral,
                            fontSize: 36,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  imposterWins
                      ? 'قدر ${imposter.name} يخدع المجموعة.'
                      : 'كشفتوا ${imposter.name} وما قدر يخمن الكلمة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MundasColors.muted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                MundasCard(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Text(
                        'الكلمة السرية',
                        style: TextStyle(color: MundasColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.session.secretWord,
                        style: const TextStyle(fontSize: 32),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 28),
                      Text(
                        '${widget.session.category.emoji} ${widget.session.category.nameAr}',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: MundasButton(
                    label: 'جولة ثانية بنفس المجموعة',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      widget.session.startRound();
                      Navigator.pushReplacement(
                        context,
                        mundasRoute(RoleRevealScreen(session: widget.session)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
