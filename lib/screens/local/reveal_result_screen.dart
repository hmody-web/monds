import 'package:flutter/material.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import '../../widgets/suspense_reveal.dart';
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

  void _continue() {
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;
    if (caught) {
      Navigator.pushReplacement(
        context,
        mundasRoute(ImposterGuessScreen(session: widget.session)),
      );
    } else {
      widget.session.guessCorrect = true;
      Navigator.pushReplacement(
        context,
        mundasRoute(GameOverScreen(session: widget.session)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accused = widget.session.players[widget.session.accusedIndex!];
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;

    return MundasScaffold(
      title: 'كشف التصويت',
      showBack: false,
      gameExit: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                SuspenseReveal(
                  accusedName: accused.name,
                  isImposter: caught,
                  onRevealed: () {
                    if (mounted) setState(() => revealed = true);
                  },
                ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: revealed
                      ? SizedBox(
                          key: const ValueKey('continue'),
                          width: double.infinity,
                          child: MundasButton(
                            label: caught
                                ? 'خلي المندس يخمن'
                                : 'اكشف المندس الحقيقي',
                            icon: Icons.arrow_forward_rounded,
                            color: caught
                                ? MundasColors.coral
                                : MundasColors.primary,
                            onPressed: _continue,
                          ),
                        )
                      : const Text(
                          'لا تستعجلون... النتيجة جاية 👀',
                          key: ValueKey('waiting'),
                          style: TextStyle(color: MundasColors.muted),
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
