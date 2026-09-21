import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import 'imposter_guess_screen.dart';
import 'game_over_screen.dart';

class RevealResultScreen extends StatefulWidget {
  final LocalGameSession session;
  const RevealResultScreen({super.key, required this.session});

  @override
  State<RevealResultScreen> createState() => _RevealResultScreenState();
}

class _RevealResultScreenState extends State<RevealResultScreen> {
  bool revealed = false;

  void _reveal() {
    HapticFeedback.heavyImpact();
    setState(() => revealed = true);
  }

  void _continue() {
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;
    if (caught) {
      Navigator.pushReplacement(context, mundasRoute(ImposterGuessScreen(session: widget.session)));
    } else {
      widget.session.guessCorrect = true;
      Navigator.pushReplacement(context, mundasRoute(GameOverScreen(session: widget.session)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accused = widget.session.players[widget.session.accusedIndex!];
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;
    return MundasScaffold(
      title: 'كشف التصويت',
      showBack: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Text(revealed ? (caught ? '😈' : '😳') : '👀', style: const TextStyle(fontSize: 76)),
                const SizedBox(height: 16),
                Text(revealed ? (caught ? 'كشفتم المندس!' : 'مو هو المندس!') : 'أكثر شخص عليه شك...', style: const TextStyle(fontSize: 33), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(accused.name, style: TextStyle(fontSize: 44, color: revealed && caught ? MundasColors.coral : MundasColors.ink)),
                const SizedBox(height: 16),
                if (revealed)
                  Text(
                    caught ? 'باقي فرصة أخيرة للمندس: إذا عرف الكلمة، يسرق الفوز.' : 'المندس خدعكم ونجا من التصويت.',
                    style: const TextStyle(color: MundasColors.muted, fontSize: 16, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: MundasButton(
                    label: revealed ? (caught ? 'خلي المندس يخمن' : 'شوفوا النتيجة') : 'اكشف',
                    icon: revealed ? Icons.arrow_forward_rounded : Icons.visibility_rounded,
                    color: revealed && caught ? MundasColors.coral : MundasColors.primary,
                    onPressed: revealed ? _continue : _reveal,
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
