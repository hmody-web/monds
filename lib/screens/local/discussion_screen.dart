import 'package:flutter/material.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/drawing_board.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import 'voting_screen.dart';

class DiscussionScreen extends StatelessWidget {
  final LocalGameSession session;
  const DiscussionScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MundasScaffold(
      title: 'وقت النقاش',
      showBack: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          children: [
            const Text('🗣️', style: TextStyle(fontSize: 46)),
            const SizedBox(height: 6),
            const Text('دافع عن رسمتك وشكّ بالآخرين', style: TextStyle(fontSize: 25)),
            const SizedBox(height: 4),
            const Text('لا تنطقون الكلمة السرية بصوت عالي.', style: TextStyle(color: MundasColors.muted)),
            const SizedBox(height: 14),
            Expanded(
              child: DrawingBoard(
                strokes: session.strokes,
                ownerIndex: -1,
                enabled: false,
                ink: 0,
                onInkChanged: (_) {},
                onStrokeFinished: (_) {},
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: MundasButton(
                label: 'روحوا للتصويت',
                icon: Icons.how_to_vote_rounded,
                color: MundasColors.ink,
                onPressed: () => Navigator.pushReplacement(context, mundasRoute(VotingScreen(session: session))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
