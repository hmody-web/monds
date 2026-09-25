import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;

import '../../models/guess_time_models.dart';
import '../../services/app_audio_service.dart';
import '../../services/guess_time/guess_time_game_controller.dart';
import '../../services/guess_time/guess_time_online_service.dart';
import 'guess_time_3d_world.dart';

class GuessTimeGameScreen extends StatefulWidget {
  const GuessTimeGameScreen._({
    super.key,
    required this.players,
    required this.online,
    this.identity,
    this.service,
    this.initialState,
  });

  factory GuessTimeGameScreen.offline({required List<GuessTimePlayer> players}) =>
      GuessTimeGameScreen._(players: players, online: false);

  factory GuessTimeGameScreen.online({
    required List<GuessTimePlayer> players,
    required GuessTimeOnlineIdentity identity,
    required GuessTimeOnlineService service,
    required GuessTimeOnlineState initialState,
  }) =>
      GuessTimeGameScreen._(
        players: players,
        online: true,
        identity: identity,
        service: service,
        initialState: initialState,
      );

  final List<GuessTimePlayer> players;
  final bool online;
  final GuessTimeOnlineIdentity? identity;
  final GuessTimeOnlineService? service;
  final GuessTimeOnlineState? initialState;

  @override
  State<GuessTimeGameScreen> createState() => _GuessTimeGameScreenState();
}

class _GuessTimeGameScreenState extends State<GuessTimeGameScreen> {
  final GuessTime3DWorld _world = GuessTime3DWorld();
  GuessTimeGameController? _local;
  GuessTimeOnlineState? _onlineState;
  Timer? _onlinePoll;
  Timer? _uiTicker;
  DateTime _stateReceivedAt = DateTime.now();

  bool _sceneReady = false;
  bool _showLoading = true;
  String? _sceneError;
  double _loadingProgress = 0;
  String _loadingStage = 'تجهيز الغرفة';
  bool _onlineBusy = false;
  String? _onlineError;
  GuessTimePhase _lastPhase = GuessTimePhase.waiting;
  int _lastRound = -1;
  bool _eliminationStarted = false;
  bool _shotSoundPlayed = false;
  bool _impactSoundPlayed = false;

  GuessTimePhase get phase => widget.online
      ? (_onlineState?.phase ?? GuessTimePhase.waiting)
      : (_local?.phase ?? GuessTimePhase.waiting);

  int get round => widget.online ? (_onlineState?.round ?? 0) : (_local?.round ?? 0);

  @override
  void initState() {
    super.initState();
    _onlineState = widget.initialState;
    if (!widget.online) {
      _local = GuessTimeGameController(players: widget.players)..addListener(_onLocalChanged);
    }
    _prepareLandscapeAndScene();
    if (widget.online) {
      _stateReceivedAt = DateTime.now();
      _onlinePoll = Timer.periodic(const Duration(milliseconds: 320), (_) => _pollOnline());
      _syncPhaseEffects();
    }
    _uiTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      _syncEliminationAudio();
      setState(() {});
    });
  }

  Future<void> _prepareLandscapeAndScene() async {
    setState(() {
      _loadingProgress = .02;
      _loadingStage = 'تجهيز العرض الأفقي';
    });
    await _forceLandscape();
    if (!mounted) return;
    await _initializeScene();
  }

  Future<void> _forceLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {
      // Desktop targets such as Windows do not need orientation locking.
    }
  }

  Future<void> _restoreOrientation() async {
    try {
      // Empty list hands orientation control back to the app/platform defaults.
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    } catch (_) {}
  }

  Future<void> _initializeScene() async {
    try {
      setState(() {
        _loadingProgress = .05;
        _loadingStage = 'تحميل أصوات اللعبة';
      });
      await AppAudioService.preloadArenaAudio();
      if (!mounted) return;

      await _world.initialize(
        players: widget.players,
        onProgress: (progress, stage) {
          if (!mounted) return;
          setState(() {
            // Reserve the final part of the bar for SceneView GPU warm-up.
            _loadingProgress = .08 + progress * .84;
            _loadingStage = stage;
          });
        },
      );
      if (!mounted) return;

      _world
        ..setViewerIndex(_viewerIndex())
        ..resetLook();

      // Build SceneView behind the still-visible loading overlay so its GPU
      // resources compile before the player sees the room.
      setState(() {
        _sceneReady = true;
        _loadingProgress = .95;
        _loadingStage = 'تجهيز المشهد النهائي';
      });
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;

      if (widget.online) {
        _applyOnlineVisuals();
      } else {
        _local!.start();
        _applyLocalVisuals();
      }

      setState(() {
        _loadingProgress = 1;
        _loadingStage = 'جاهز';
        _showLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showLoading = false;
        _sceneError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_restoreOrientation());
    _onlinePoll?.cancel();
    _uiTicker?.cancel();
    _local?.removeListener(_onLocalChanged);
    _local?.dispose();
    AppAudioService.stopArenaAudio();
    super.dispose();
  }

  void _onLocalChanged() {
    if (!mounted) return;
    _applyLocalVisuals();
    setState(() {});
  }

  void _applyLocalVisuals() {
    final controller = _local;
    if (controller == null || !_sceneReady) return;
    if (_lastRound != controller.round) {
      _world.setScreenOwners(controller.screenOwners, playerTimes: widget.players.take(4).map((p) => p.targetMs).toList());
      _lastRound = controller.round;
    }
    _world
      ..setViewerIndex(_viewerIndex())
      ..setPlayerScreenTexts(_screenTexts())
      ..setBigScreenState(controller.phase);
    _syncPhaseEffects();
  }

  Future<void> _pollOnline() async {
    if (_onlineBusy || !mounted) return;
    _onlineBusy = true;
    try {
      final state = await widget.service!.state(widget.identity!);
      if (!mounted) return;
      _onlineState = state;
      _stateReceivedAt = DateTime.now();
      _mergeOnlinePlayers(state);
      _onlineError = null;
      _applyOnlineVisuals();
      setState(() {});
    } on GuessTimeOnlineException catch (e) {
      if (mounted) setState(() => _onlineError = e.message);
    } finally {
      _onlineBusy = false;
    }
  }

  void _mergeOnlinePlayers(GuessTimeOnlineState state) {
    for (final remote in state.players) {
      for (final local in widget.players) {
        if (local.id != remote.id) continue;
        local
          ..targetMs = remote.targetMs
          ..stoppedMs = remote.stoppedMs
          ..locked = remote.stoppedMs != null
          ..totalErrorMs = remote.totalErrorMs;
      }
    }
  }

  void _applyOnlineVisuals() {
    final state = _onlineState;
    if (state == null || !_sceneReady) return;
    if (_lastRound != state.round && state.screenOwners.isNotEmpty) {
      _world.setScreenOwners(state.screenOwners, playerTimes: widget.players.take(4).map((p) => p.targetMs).toList());
      _lastRound = state.round;
    }
    _world
      ..setViewerIndex(_viewerIndex())
      ..setPlayerScreenTexts(_screenTexts())
      ..setBigScreenState(state.phase);
    _syncPhaseEffects();
  }

  void _syncPhaseEffects() {
    final current = phase;
    if (current != _lastPhase) _lastPhase = current;
    if (current == GuessTimePhase.elimination) _ensureEliminationStarted();
  }

  void _ensureEliminationStarted() {
    if (_eliminationStarted || !_sceneReady) return;
    _eliminationStarted = true;
    final loser = _loserId();
    final index = widget.players.indexWhere((p) => p.id == loser);
    _world.startElimination(index < 0 ? widget.players.length - 1 : index);
    _shotSoundPlayed = false;
    _impactSoundPlayed = false;
  }

  void _syncEliminationAudio() {
    if (phase != GuessTimePhase.elimination || !_eliminationStarted) return;
    final elapsed = _phaseElapsedMs();
    if (!_shotSoundPlayed && elapsed >= 5100) {
      _shotSoundPlayed = true;
      AppAudioService.playPistolShot();
    }
    if (!_impactSoundPlayed && (_world.impactTriggered || elapsed >= 5850)) {
      _impactSoundPlayed = true;
      AppAudioService.playDamageHit();
      AppAudioService.playDeath();
    }
  }

  int _phaseElapsedMs() {
    if (!widget.online) return _local?.phaseElapsedMs() ?? 0;
    final state = _onlineState;
    if (state == null) return 0;
    final estimatedServerNow = state.serverNowMs + DateTime.now().difference(_stateReceivedAt).inMilliseconds;
    return math.max(0, estimatedServerNow - state.phaseStartedAtMs);
  }

  int _countdownValue() {
    if (!widget.online) return _local?.countdown ?? 0;
    return (3 - _phaseElapsedMs() ~/ 1000).clamp(0, 3).toInt();
  }

  List<int> _owners() => widget.online ? (_onlineState?.screenOwners ?? const []) : (_local?.screenOwners ?? const []);

  String? _loserId() => widget.online ? _onlineState?.loserId : _local?.loserId;

  int _viewerIndex() {
    if (widget.online) {
      final id = widget.identity?.playerId;
      if (id != null) {
        final index = widget.players.indexWhere((p) => p.id == id);
        if (index >= 0) return index;
      }
    }
    final local = widget.players.indexWhere((p) => p.isLocal);
    return local >= 0 ? local : 0;
  }

  List<String> _screenTexts() {
    final values = <String>[];
    for (var i = 0; i < 4; i++) {
      final player = i < widget.players.length ? widget.players[i] : null;
      if (player == null) {
        values.add('00.00');
        continue;
      }
      final text = switch (phase) {
        GuessTimePhase.waiting => '00.00',
        GuessTimePhase.reveal || GuessTimePhase.countdown || GuessTimePhase.timing => formatGuessTime(player.targetMs),
        GuessTimePhase.roundResults || GuessTimePhase.finalResults || GuessTimePhase.elimination || GuessTimePhase.finished => formatGuessTime(player.stoppedMs ?? player.targetMs),
      };
      values.add(text);
    }
    return values;
  }

  List<GuessTimeStanding> _roundStandings() {
    if (!widget.online) return _local?.roundStandings ?? const [];
    final state = _onlineState;
    if (state == null) return const [];
    final result = <GuessTimeStanding>[];
    for (var i = 0; i < state.roundRanking.length; i++) {
      final player = _player(state.roundRanking[i]);
      if (player == null) continue;
      result.add(
        GuessTimeStanding(
          player: player.copyPublic(),
          rank: i + 1,
          errorMs: player.currentErrorMs,
        ),
      );
    }
    return result;
  }

  List<GuessTimeStanding> _finalStandings() {
    if (!widget.online) return _local?.finalStandings ?? const [];
    final state = _onlineState;
    if (state == null) return const [];
    final result = <GuessTimeStanding>[];
    for (var i = 0; i < state.finalRanking.length; i++) {
      final player = _player(state.finalRanking[i]);
      if (player == null) continue;
      result.add(
        GuessTimeStanding(
          player: player.copyPublic(),
          rank: i + 1,
          errorMs: player.totalErrorMs,
        ),
      );
    }
    return result;
  }

  GuessTimePlayer? _player(String id) {
    for (final p in widget.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _canPress(GuessTimePlayer player) {
    if (phase != GuessTimePhase.timing || player.locked || player.isBot) return false;
    if (widget.online) return player.id == widget.identity!.playerId;
    return player.isLocal;
  }

  Future<void> _press(GuessTimePlayer player) async {
    if (!_canPress(player)) return;
    final index = widget.players.indexOf(player);
    _world.animatePress(index);
    AppAudioService.playClick();
    if (!widget.online) {
      _local!.press(player.id);
      return;
    }
    // Lock locally immediately for responsive feedback; the authoritative time
    // still comes back from the server on the next poll.
    player.locked = true;
    setState(() {});
    try {
      await widget.service!.action(widget.identity!, 'stop');
      await _pollOnline();
    } on GuessTimeOnlineException catch (e) {
      player.locked = false;
      if (mounted) setState(() => _onlineError = e.message);
    }
  }

  Future<void> _rematch() async {
    if (!widget.online) {
      _world.resetForRematch();
      _eliminationStarted = false;
      _shotSoundPlayed = false;
      _impactSoundPlayed = false;
      _lastPhase = GuessTimePhase.waiting;
      _lastRound = -1;
      _local!.restart();
      return;
    }
    if (!widget.identity!.isHost) return;
    try {
      await widget.service!.action(widget.identity!, 'rematch');
      _world.resetForRematch();
      _eliminationStarted = false;
      _shotSoundPlayed = false;
      _impactSoundPlayed = false;
      _lastPhase = GuessTimePhase.waiting;
      _lastRound = -1;
      await _pollOnline();
    } on GuessTimeOnlineException catch (e) {
      if (mounted) setState(() => _onlineError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: phase == GuessTimePhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  Positioned.fill(child: _buildScene()),
                  if (_sceneReady) ..._stationTimerLabels(size),
                  if (_sceneReady) ..._stationButtons(size),
                  if (_sceneReady) _bigScreenOverlay(size),
                  _topHud(),
                  if (_onlineError != null) _errorBanner(),
                  if (_showLoading) _loadingOverlay(),
                  if (_sceneError != null) _sceneErrorOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScene() {
    if (!_sceneReady) return const ColoredBox(color: Colors.black);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        _world.lookByDragDelta(details.delta);
        if (mounted) setState(() {});
      },
      child: SceneView(
        _world.scene,
        cameraBuilder: (_) => _world.cameraFor(phase: phase),
        warmUp: true,
      ),
    );
  }

  List<Widget> _screenTimeLabels(Size size) {
    return const [];
  }

  List<Widget> _stationTimerLabels(Size size) {
    if (phase == GuessTimePhase.elimination || phase == GuessTimePhase.finished) {
      return const [];
    }
    final result = <Widget>[];
    for (var i = 0; i < widget.players.length && i < 4; i++) {
      final player = widget.players[i];
      final point = _world.projectStationDisplay(i, size, phase);
      if (point == null) continue;
      String text;
      if (player.stoppedMs != null &&
          (player.locked ||
              phase == GuessTimePhase.roundResults ||
              phase == GuessTimePhase.finalResults)) {
        text = formatGuessTime(player.stoppedMs!);
      } else if (phase == GuessTimePhase.reveal ||
          phase == GuessTimePhase.countdown ||
          phase == GuessTimePhase.waiting) {
        text = '00.00';
      } else {
        // Keep the stopwatch itself hidden (the point of the game is guessing),
        // but keep a clearly visible timer display on the station while timing.
        text = '00.00';
      }
      final isViewer = i == _viewerIndex();
      final timerWidth = isViewer ? 116.0 : 92.0;
      final timerFont = isViewer ? 22.0 : 17.0;
      final timerColor =
          GuessTimePalette.colors[player.colorIndex.clamp(0, 3).toInt()];
      result.add(
        Positioned(
          left: point.dx - timerWidth * .5,
          top: point.dy - (isViewer ? 18 : 14),
          width: timerWidth,
          child: IgnorePointer(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isViewer ? 8 : 6,
                vertical: isViewer ? 5 : 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xE60A0D0E),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: timerColor, width: isViewer ? 2 : 1.25),
                boxShadow: const [
                  BoxShadow(color: Color(0x99000000), blurRadius: 8),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: timerColor,
                  fontSize: timerFont,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: .8,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return result;
  }

  List<Widget> _stationButtons(Size size) {
    final result = <Widget>[];
    for (var i = 0; i < widget.players.length && i < 4; i++) {
      final p = widget.players[i];
      final point = _world.projectButton(i, size, phase);
      if (point == null) continue;
      final canPress = _canPress(p);
      final locked = p.locked;
      final color = GuessTimePalette.colors[p.colorIndex.clamp(0, 3).toInt()];
      result.add(
        Positioned(
          left: point.dx - 35,
          top: point.dy - 35,
          width: 70,
          height: 70,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canPress ? () => _press(p) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canPress ? color.withOpacity(.15) : Colors.transparent,
                border: Border.all(color: canPress ? Colors.white.withOpacity(.55) : Colors.transparent, width: 2),
                boxShadow: canPress ? [BoxShadow(color: color.withOpacity(.42), blurRadius: 20)] : null,
              ),
              alignment: Alignment.center,
              child: canPress || locked
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: locked ? Colors.white.withOpacity(.88) : color),
                      child: Icon(locked ? Icons.check_rounded : Icons.touch_app_rounded, color: locked ? color : Colors.white, size: 18),
                    )
                  : null,
            ),
          ),
        ),
      );
    }
    return result;
  }

  Widget _bigScreenOverlay(Size size) {
    final point = _world.projectBigScreen(size, phase);
    if (point == null) return const SizedBox.shrink();
    final width = math.min(size.width * .48, 430.0);
    Widget child;

    switch (phase) {
      case GuessTimePhase.reveal:
        child = Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الجولة $round / 5', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          const Text('احفظ وقت لونك', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ]);
        break;
      case GuessTimePhase.countdown:
        child = Text('${_countdownValue() == 0 ? 'ابدأ' : _countdownValue()}', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900));
        break;
      case GuessTimePhase.timing:
        final locked = widget.players.where((p) => p.locked).length;
        child = Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('خَمِّن الآن', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('$locked / ${widget.players.length} ثبّتوا أوقاتهم', style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
        ]);
        break;
      case GuessTimePhase.roundResults:
        child = _rankingContent(_roundStandings(), title: 'نتيجة الجولة $round', finalResult: false);
        break;
      case GuessTimePhase.finalResults:
        child = _rankingContent(_finalStandings(), title: 'الترتيب النهائي', finalResult: true);
        break;
      case GuessTimePhase.elimination:
        final loser = _player(_loserId() ?? '');
        child = Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ELIMINATION', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 5),
          Text(loser?.name ?? 'الخاسر', style: const TextStyle(color: Color(0xFFFFD2D2), fontSize: 14)),
        ]);
        break;
      case GuessTimePhase.finished:
        final standings = _finalStandings();
        child = Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆 الفائز', style: TextStyle(color: Colors.white, fontSize: 13)),
          if (standings.isNotEmpty) Text(standings.first.player.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _screenAction('إعادة', Icons.replay_rounded, _canRematch() ? _rematch : null),
            const SizedBox(width: 8),
            _screenAction('خروج', Icons.exit_to_app_rounded, () => Navigator.pop(context)),
          ]),
        ]);
        break;
      case GuessTimePhase.waiting:
        child = const Text('استعد', style: TextStyle(color: Colors.white, fontSize: 24));
        break;
    }

    final overlayHeight = phase == GuessTimePhase.roundResults || phase == GuessTimePhase.finalResults ? 170.0 : 110.0;
    return Positioned(
      left: point.dx - width / 2,
      top: point.dy - overlayHeight / 2,
      width: width,
      height: overlayHeight,
      child: IgnorePointer(
        ignoring: phase != GuessTimePhase.finished,
        child: Center(child: child),
      ),
    );
  }

  Widget _rankingContent(List<GuessTimeStanding> standings, {required String title, required bool finalResult}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        for (final s in standings.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text(_medal(s.rank), style: const TextStyle(color: Colors.white, fontSize: 11))),
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: GuessTimePalette.colors[s.player.colorIndex.clamp(0, 3).toInt()])),
                const SizedBox(width: 6),
                Expanded(child: Text(s.player.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5))),
                Text(
                  finalResult
                      ? 'Σ ${(s.errorMs / 1000).toStringAsFixed(2)} ث'
                      : '${formatGuessTime(s.player.targetMs)} → ${formatGuessTime(s.player.stoppedMs ?? 0)}  •  ±${(s.errorMs / 1000).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 8.8),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _medal(int rank) => switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '4' };

  bool _canRematch() => !widget.online || widget.identity!.isHost;

  Widget _screenAction(String label, IconData icon, VoidCallback? action) => InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Colors.white.withOpacity(action == null ? .06 : .14), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 9))]),
        ),
      );

  Widget _topHud() {
    final me = widget.online ? _player(widget.identity!.playerId) : null;
    return Positioned(
      left: 14,
      right: 14,
      top: MediaQuery.paddingOf(context).top + 10,
      child: Row(
        children: [
          InkWell(
            onTap: _confirmExit,
            borderRadius: BorderRadius.circular(14),
            child: Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xCC071014), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)), child: const Icon(Icons.close_rounded, color: Colors.white)),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xCC071014), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
            child: Text('الجولة ${round.clamp(0, 5)} / 5', style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ),
          const Spacer(),
          if (widget.online && me != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC071014), borderRadius: BorderRadius.circular(14), border: Border.all(color: GuessTimePalette.colors[me.colorIndex].withOpacity(.65))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: GuessTimePalette.colors[me.colorIndex])), const SizedBox(width: 6), Text(me.name, style: const TextStyle(color: Colors.white, fontSize: 10.5))]),
            ),
        ],
      ),
    );
  }

  Widget _errorBanner() => Positioned(
        left: 20,
        right: 20,
        bottom: 22,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xE6A62828), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
          child: Text(_onlineError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
        ),
      );

  Widget _loadingOverlay() {
    final percent = (_loadingProgress * 100).round().clamp(0, 100);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, color: Color(0xFF35C77A), size: 60),
                  const SizedBox(height: 15),
                  const Text('خمن الوقت', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  Text(_loadingStage, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 18),
                  ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: _loadingProgress, minHeight: 7, backgroundColor: const Color(0xFF172024), color: const Color(0xFF35C77A))),
                  const SizedBox(height: 8),
                  Text('$percent%', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  if (widget.online && _onlineState?.phase == GuessTimePhase.reveal) ...[
                    const SizedBox(height: 18),
                    _loadingTargetHint(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingTargetHint() {
    final me = _player(widget.identity?.playerId ?? '');
    if (me == null || me.targetMs <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: GuessTimePalette.colors[me.colorIndex].withOpacity(.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: GuessTimePalette.colors[me.colorIndex].withOpacity(.5))),
      child: Text('احفظ وقتك: ${formatGuessTime(me.targetMs)}', style: const TextStyle(color: Colors.white, fontSize: 15)),
    );
  }

  Widget _sceneErrorOverlay() => Positioned.fill(
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 45),
                const SizedBox(height: 12),
                const Text('تعذر تشغيل غرفة خمن الوقت', style: TextStyle(color: Colors.white, fontSize: 17)),
                const SizedBox(height: 8),
                Text(_sceneError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
              ]),
            ),
          ),
        ),
      );

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الخروج من اللعبة؟'),
        content: const Text('الجولة الحالية لن تُكمل على هذا الجهاز.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('خروج')),
        ],
      ),
    );
    if (exit == true && mounted) Navigator.pop(context);
  }
}
