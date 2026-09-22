import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import 'game_over_screen.dart';

class ImposterGuessScreen extends StatefulWidget {
  final LocalGameSession session;
  const ImposterGuessScreen({super.key, required this.session});

  @override
  State<ImposterGuessScreen> createState() => _ImposterGuessScreenState();
}

class _ImposterGuessScreenState extends State<ImposterGuessScreen> {
  String? selected;

  void _submit() {
    if (selected == null) return;
    widget.session.guessCorrect = selected == widget.session.secretWord;
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      mundasRoute(GameOverScreen(session: widget.session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imposter = widget.session.players[widget.session.imposterIndex];
    return MundasScaffold(
      title: 'الفرصة الأخيرة',
      showBack: false,
      gameExit: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const Text('🕵️', style: TextStyle(fontSize: 72)),
                Text(
                  '${imposter.name}، ما الكلمة السرية؟',
                  style: const TextStyle(fontSize: 29),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Text(
                  'الفئة: ${widget.session.category.nameAr}',
                  style: const TextStyle(color: MundasColors.muted),
                ),
                const SizedBox(height: 10),
                const Text(
                  'اختر إجابة واحدة من الخيارات الستة',
                  style: TextStyle(color: MundasColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 22),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.15,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: widget.session.imposterChoices.length,
                  itemBuilder: (context, index) {
                    final option = widget.session.imposterChoices[index];
                    final active = selected == option;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => selected = option);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active ? MundasColors.coral : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? MundasColors.ink : MundasColors.line,
                            width: active ? 2.4 : 1.4,
                          ),
                          boxShadow: active
                              ? const [
                                  BoxShadow(
                                    color: MundasColors.shadow,
                                    offset: Offset(0, 5),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          option,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? Colors.white : MundasColors.ink,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: MundasButton(
                    label: 'تأكيد الاختيار',
                    icon: Icons.psychology_alt_rounded,
                    color: MundasColors.coral,
                    onPressed: selected == null ? null : _submit,
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
