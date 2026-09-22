import 'package:flutter/material.dart';
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
  final controller = TextEditingController();

  String normalize(String v) => v.trim().replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  void _submit() {
    final correct = normalize(controller.text) == normalize(widget.session.secretWord);
    widget.session.guessCorrect = correct;
    Navigator.pushReplacement(context, mundasRoute(GameOverScreen(session: widget.session)));
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
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                const Text('🕵️', style: TextStyle(fontSize: 74)),
                Text('${imposter.name}، شنو كانت الكلمة؟', style: const TextStyle(fontSize: 28), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('الفئة: ${widget.session.category.nameAr}', style: const TextStyle(color: MundasColors.muted)),
                const SizedBox(height: 24),
                TextField(controller: controller, autofocus: true, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(), decoration: const InputDecoration(hintText: 'اكتب الكلمة السرية...')),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: MundasButton(label: 'هذا تخميني', icon: Icons.psychology_alt_rounded, color: MundasColors.coral, onPressed: _submit)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
