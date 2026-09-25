import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/guess_time_models.dart';

class GuessTimeGameController extends ChangeNotifier {
  GuessTimeGameController({
    required List<GuessTimePlayer> players,
    int? seed,
  })  : players = players,
        _random = math.Random(seed ?? DateTime.now().microsecondsSinceEpoch);

  static const int totalRounds = 5;
  static const int maxTimingMs = 30000;

  final List<GuessTimePlayer> players;
  final math.Random _random;
  final Stopwatch _phaseWatch = Stopwatch();
  Timer? _timer;
  final Map<String, int> _botStopAt = {};

  GuessTimePhase phase = GuessTimePhase.waiting;
  int round = 0;
  int countdown = 3;
  int timingElapsedMs = 0;
  List<int> screenOwners = List<int>.filled(28, 0);
  List<GuessTimeStanding> roundStandings = const [];
  List<GuessTimeStanding> finalStandings = const [];
  String? loserId;

  bool get allLocked => players.every((p) => p.locked);

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 25), (_) => _tick());
    _startRound(1);
  }

  void _startRound(int value) {
    round = value;
    phase = GuessTimePhase.reveal;
    countdown = 3;
    timingElapsedMs = 0;
    roundStandings = const [];
    _botStopAt.clear();

    for (final player in players) {
      player
        ..targetMs = 4200 + _random.nextInt(9801)
        ..stoppedMs = null
        ..locked = false;
    }

    final owners = <int>[];
    for (var i = 0; i < 28; i++) {
      owners.add(i % players.length);
    }
    owners.shuffle(_random);
    screenOwners = owners;
    _restartPhaseWatch();
    notifyListeners();
  }

  void _restartPhaseWatch() {
    _phaseWatch
      ..reset()
      ..start();
  }

  void _tick() {
    final elapsed = _phaseWatch.elapsedMilliseconds;
    switch (phase) {
      case GuessTimePhase.reveal:
        if (elapsed >= 2200) {
          phase = GuessTimePhase.countdown;
          countdown = 3;
          _restartPhaseWatch();
          notifyListeners();
        }
        break;
      case GuessTimePhase.countdown:
        final next = (3 - elapsed ~/ 1000).clamp(0, 3).toInt();
        if (next != countdown) {
          countdown = next;
          notifyListeners();
        }
        if (elapsed >= 3000) _beginTiming();
        break;
      case GuessTimePhase.timing:
        timingElapsedMs = elapsed;
        for (final player in players.where((p) => p.isBot && !p.locked)) {
          final planned = _botStopAt[player.id];
          if (planned != null && elapsed >= planned) {
            _lock(player, planned);
          }
        }
        if (elapsed >= maxTimingMs) {
          for (final player in players.where((p) => !p.locked)) {
            _lock(player, maxTimingMs);
          }
        }
        if (allLocked) _showRoundResults();
        notifyListeners();
        break;
      case GuessTimePhase.roundResults:
        if (elapsed >= 5200) {
          if (round < totalRounds) {
            _startRound(round + 1);
          } else {
            _showFinalResults();
          }
        }
        break;
      case GuessTimePhase.finalResults:
        if (elapsed >= 6500) {
          phase = GuessTimePhase.elimination;
          _restartPhaseWatch();
          notifyListeners();
        }
        break;
      case GuessTimePhase.elimination:
        if (elapsed >= 9000) {
          phase = GuessTimePhase.finished;
          _restartPhaseWatch();
          notifyListeners();
        }
        break;
      case GuessTimePhase.waiting:
      case GuessTimePhase.finished:
        break;
    }
  }

  void _beginTiming() {
    phase = GuessTimePhase.timing;
    timingElapsedMs = 0;
    _restartPhaseWatch();
    for (final player in players.where((p) => p.isBot)) {
      final accuracy = 90 + _random.nextInt(650);
      final rareMiss = _random.nextDouble() < .12 ? 500 + _random.nextInt(900) : 0;
      final direction = _random.nextBool() ? 1 : -1;
      _botStopAt[player.id] = (player.targetMs + direction * (accuracy + rareMiss)).clamp(450, maxTimingMs).toInt();
    }
    notifyListeners();
  }

  bool press(String playerId) {
    if (phase != GuessTimePhase.timing) return false;
    final player = players.where((p) => p.id == playerId).firstOrNull;
    if (player == null || player.locked || player.isBot) return false;
    _lock(player, _phaseWatch.elapsedMilliseconds.clamp(0, maxTimingMs).toInt());
    if (allLocked) _showRoundResults();
    notifyListeners();
    return true;
  }

  void _lock(GuessTimePlayer player, int ms) {
    if (player.locked) return;
    player
      ..locked = true
      ..stoppedMs = ms;
  }

  void _showRoundResults() {
    if (phase == GuessTimePhase.roundResults) return;
    for (final player in players) {
      final stopped = player.stoppedMs ?? maxTimingMs;
      player
        ..stoppedMs = stopped
        ..locked = true
        ..totalErrorMs += (stopped - player.targetMs).abs();
    }
    final ordered = players.map((p) => p.copyPublic()).toList()
      ..sort((a, b) => a.currentErrorMs.compareTo(b.currentErrorMs));
    roundStandings = [
      for (var i = 0; i < ordered.length; i++)
        GuessTimeStanding(player: ordered[i], rank: i + 1, errorMs: ordered[i].currentErrorMs),
    ];
    phase = GuessTimePhase.roundResults;
    _restartPhaseWatch();
    notifyListeners();
  }

  void _showFinalResults() {
    final ordered = players.map((p) => p.copyPublic()).toList()
      ..sort((a, b) => a.totalErrorMs.compareTo(b.totalErrorMs));
    finalStandings = [
      for (var i = 0; i < ordered.length; i++)
        GuessTimeStanding(player: ordered[i], rank: i + 1, errorMs: ordered[i].totalErrorMs),
    ];
    loserId = ordered.last.id;
    phase = GuessTimePhase.finalResults;
    _restartPhaseWatch();
    notifyListeners();
  }

  int phaseElapsedMs() => _phaseWatch.elapsedMilliseconds;

  void restart() {
    for (final p in players) {
      p.totalErrorMs = 0;
    }
    loserId = null;
    finalStandings = const [];
    _startRound(1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phaseWatch.stop();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
