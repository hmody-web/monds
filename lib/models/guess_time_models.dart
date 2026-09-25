import 'dart:ui';

import 'killer_killed_avatar.dart';

enum GuessTimePhase {
  waiting,
  reveal,
  countdown,
  timing,
  roundResults,
  finalResults,
  elimination,
  finished,
}

class GuessTimePlayer {
  GuessTimePlayer({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.isBot,
    required this.avatar,
    this.isLocal = false,
  });

  final String id;
  final String name;
  final int colorIndex;
  final bool isBot;
  final bool isLocal;
  final KillerKilledAvatar avatar;

  int targetMs = 0;
  int? stoppedMs;
  int totalErrorMs = 0;
  bool locked = false;

  int get currentErrorMs => stoppedMs == null ? 1 << 30 : (stoppedMs! - targetMs).abs();

  GuessTimePlayer copyPublic() {
    final result = GuessTimePlayer(
      id: id,
      name: name,
      colorIndex: colorIndex,
      isBot: isBot,
      avatar: avatar,
      isLocal: isLocal,
    );
    result
      ..targetMs = targetMs
      ..stoppedMs = stoppedMs
      ..totalErrorMs = totalErrorMs
      ..locked = locked;
    return result;
  }
}

class GuessTimeStanding {
  const GuessTimeStanding({
    required this.player,
    required this.rank,
    required this.errorMs,
  });

  final GuessTimePlayer player;
  final int rank;
  final int errorMs;
}

abstract final class GuessTimePalette {
  static const colors = <Color>[
    Color(0xFFE84B4B),
    Color(0xFF3F7CFF),
    Color(0xFFF4C84E),
    Color(0xFF35C77A),
  ];

  static const names = <String>['أحمر', 'أزرق', 'أصفر', 'أخضر'];
}

String formatGuessTime(int ms, {bool signed = false}) {
  final negative = ms < 0;
  final value = ms.abs();
  final seconds = value ~/ 1000;
  final hundredths = (value % 1000) ~/ 10;
  final sign = signed ? (negative ? '−' : '+') : '';
  return '$sign${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
}
