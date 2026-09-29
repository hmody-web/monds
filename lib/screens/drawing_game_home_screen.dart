import 'package:flutter/material.dart';

import '../core/nav.dart';
import '../widgets/arcade_game_shell.dart';
import 'local/local_players_screen.dart';
import 'multiplayer/multiplayer_entry_screen.dart';

class DrawingGameHomeScreen extends StatelessWidget {
  const DrawingGameHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ArcadeGameShell(
      title: 'خمن من الرسم',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ArcadePanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اختر طريقة اللعب',
                  style: TextStyle(
                    fontFamily: 'PCB',
                    color: Color(0xFFFFF1B0),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                ArcadePrimaryButton(
                  label: 'ابدأ اللعب',
                  onPressed: () => Navigator.push(
                    context,
                    mundasRoute(const LocalPlayersScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                ArcadePrimaryButton(
                  label: 'العب مع صديق',
                  icon: Icons.groups_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    mundasRoute(const MultiplayerEntryScreen()),
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
