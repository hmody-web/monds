import 'package:flutter/material.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/imposter_wheel_reveal.dart';
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
  bool showImposterWheel = false;
  bool wheelFinished = false;

  void _continueCaught() {
    Navigator.pushReplacement(
      context,
      mundasRoute(ImposterGuessScreen(session: widget.session)),
    );
  }

  void _finishWrongReveal() {
    widget.session.guessCorrect = true;
    Navigator.pushReplacement(
      context,
      mundasRoute(GameOverScreen(session: widget.session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accused = widget.session.players[widget.session.accusedIndex!];
    final caught = widget.session.accusedIndex == widget.session.imposterIndex;
    final imposter = widget.session.players[widget.session.imposterIndex];

    return MundasScaffold(
      title: showImposterWheel ? 'كشف المندس' : 'كشف التصويت',
      showBack: false,
      gameExit: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutBack,
              child: showImposterWheel
                  ? Column(
                      key: const ValueKey('wheel'),
                      children: [
                        ImposterWheelReveal(
                          playerNames: widget.session.players
                              .map((p) => p.name)
                              .toList(growable: false),
                          imposterName: imposter.name,
                          onFinished: () {
                            if (mounted) {
                              setState(() => wheelFinished = true);
                            }
                          },
                        ),
                        const SizedBox(height: 22),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 260),
                          opacity: wheelFinished ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !wheelFinished,
                            child: SizedBox(
                              width: double.infinity,
                              child: MundasButton(
                                label: 'عرض نتيجة الجولة',
                                icon: Icons.arrow_forward_rounded,
                                color: MundasColors.coral,
                                onPressed: _finishWrongReveal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('vote-reveal'),
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
                                        ? 'الفرصة الأخيرة للمندس'
                                        : 'كشف المندس الحقيقي',
                                    icon: Icons.arrow_forward_rounded,
                                    color: caught
                                        ? MundasColors.coral
                                        : MundasColors.primary,
                                    onPressed: caught
                                        ? _continueCaught
                                        : () => setState(
                                              () => showImposterWheel = true,
                                            ),
                                  ),
                                )
                              : const Text(
                                  'يتم الآن التحقق من النتيجة... 👀',
                                  key: ValueKey('waiting'),
                                  style: TextStyle(color: MundasColors.muted),
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
