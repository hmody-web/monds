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
    WidgetsBinding.instance.addPostFrameCallback((_) => HapticFeedback.heavyImpact());
  }

  @override
  Widget build(BuildContext context) {
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;
    final imposterWins = !caught || widget.session.guessCorrect == true;
    final imposter = widget.session.players[widget.session.imposterIndex];
    return MundasScaffold(
      title: 'نتيجة الجولة',
      showBack: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Text(imposterWins ? '😎' : '🎉', style: const TextStyle(fontSize: 84)),
                const SizedBox(height: 8),
                Text(imposterWins ? 'المندس فاز!' : 'الطاقم فاز!', style: TextStyle(fontSize: 40, color: imposterWins ? MundasColors.coral : MundasColors.primary)),
                const SizedBox(height: 10),
                Text(imposterWins ? 'قدر ${imposter.name} يخدع المجموعة.' : 'كشفتوا ${imposter.name} وما قدر يخمن الكلمة.', textAlign: TextAlign.center, style: const TextStyle(color: MundasColors.muted, fontSize: 16)),
                const SizedBox(height: 20),
                MundasCard(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Text('الكلمة السرية', style: TextStyle(color: MundasColors.muted)),
                      const SizedBox(height: 4),
                      Text(widget.session.secretWord, style: const TextStyle(fontSize: 32)),
                      const Divider(height: 28),
                      Text('${widget.session.category.emoji} ${widget.session.category.nameAr}', style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, child: MundasButton(label: 'جولة ثانية بنفس المجموعة', icon: Icons.refresh_rounded, onPressed: () {
                  widget.session.startRound();
                  Navigator.pushReplacement(context, mundasRoute(RoleRevealScreen(session: widget.session)));
                })),
                const SizedBox(height: 10),
                TextButton.icon(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), icon: const Icon(Icons.home_rounded), label: const Text('العودة للرئيسية')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
