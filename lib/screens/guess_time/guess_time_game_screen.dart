import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
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
  final Map<String, int?> _lastStoppedMs = <String, int?>{};
  final Set<String> _localPressFeedbackHandled = <String>{};
  final Set<String> _buttonPressInFlight = <String>{};
  bool _developerCtrlHeld = false;
  bool _developerAltHeld = false;
  bool _ctrlAltDeveloperLatch = false;

  bool get _layoutDeveloperMode => GuessTime3DWorld.layoutDeveloperMode;

  GuessTimePhase get phase => _layoutDeveloperMode
      ? GuessTimePhase.waiting
      : (widget.online
          ? (_onlineState?.phase ?? GuessTimePhase.waiting)
          : (_local?.phase ?? GuessTimePhase.waiting));

  int get round => _layoutDeveloperMode
      ? 0
      : (widget.online ? (_onlineState?.round ?? 0) : (_local?.round ?? 0));

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleDeveloperKeyboard);
    _onlineState = widget.initialState;
    for (final player in widget.players) {
      _lastStoppedMs[player.id] = player.stoppedMs;
    }
    if (!widget.online) {
      _local = GuessTimeGameController(players: widget.players)..addListener(_onLocalChanged);
    }
    _prepareLandscapeAndScene();
    if (widget.online && !_layoutDeveloperMode) {
      _stateReceivedAt = DateTime.now();
      _onlinePoll = Timer.periodic(const Duration(milliseconds: 320), (_) => _pollOnline());
      _syncPhaseEffects();
    }
    _uiTicker = Timer.periodic(
      Duration(milliseconds: _layoutDeveloperMode ? 120 : 50),
      (_) {
        if (!mounted) return;
        if (!_layoutDeveloperMode) {
          _syncEliminationAudio();
          if (_sceneReady) _sync3DDisplays();
        }
        setState(() {});
      },
    );
  }

  bool _handleDeveloperKeyboard(KeyEvent event) {
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      _developerCtrlHeld = event is! KeyUpEvent;
      if (event is KeyUpEvent) _ctrlAltDeveloperLatch = false;
    } else if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      _developerAltHeld = event is! KeyUpEvent;
      if (event is KeyUpEvent) _ctrlAltDeveloperLatch = false;
    }

    if (event is KeyDownEvent && _developerCtrlHeld && _developerAltHeld) {
      if (_ctrlAltDeveloperLatch) return true;
      _ctrlAltDeveloperLatch = true;
      unawaited(_switchRuntimeDeveloperMode(!GuessTime3DWorld.layoutDeveloperMode));
      return true;
    }

    if (!_layoutDeveloperMode) return false;
    if (event is KeyUpEvent) return false;

    // Toggle free camera only once per physical Caps-Lock press.
    if (key == LogicalKeyboardKey.capsLock && event is KeyDownEvent) {
      _world.toggleDeveloperFreeCameraFromKeyboard();
      if (mounted) setState(() {});
      return true;
    }

    // Enter always restarts/plays the currently selected tank victim path.
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        event is KeyDownEvent) {
      _world.playSelectedTankDeveloperPathFromKeyboard();
      if (mounted) setState(() {});
      return true;
    }

    if (!_world.developerFreeCameraEnabled) return false;
    final step = _world.developerCameraKeyboardStep;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_developerCtrlHeld) {
        _world.moveDeveloperFreeCameraFromKeyboard(up: step);
      } else {
        _world.moveDeveloperFreeCameraFromKeyboard(forward: step);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_developerCtrlHeld) {
        _world.moveDeveloperFreeCameraFromKeyboard(up: -step);
      } else {
        _world.moveDeveloperFreeCameraFromKeyboard(forward: -step);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _world.moveDeveloperFreeCameraFromKeyboard(right: -step);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _world.moveDeveloperFreeCameraFromKeyboard(right: step);
      return true;
    }
    return false;
  }

  Future<void> _switchRuntimeDeveloperMode(bool enableDeveloper) async {
    if (!_sceneReady) return;
    if (enableDeveloper) {
      _local?.restart();
      _onlinePoll?.cancel();
      _onlinePoll = null;
      _world
        ..resetForRematch()
        ..setRuntimeDeveloperMode(true)
        ..setScreenOwners(List<int>.generate(28, (i) => i % (widget.players.isEmpty ? 1 : math.min(4, widget.players.length).toInt())))
        ..setPlayerScreenTexts(List<String>.generate(4, (i) => const ['07.50', '09.25', '11.00', '12.75'][i]))
        ..setStationTimerTexts(const ['00.00', '00.00', '00.00', '00.00']);
    } else {
      _world
        ..setRuntimeDeveloperMode(false)
        ..resetForRematch();
      _localPressFeedbackHandled.clear();
      _buttonPressInFlight.clear();
      if (widget.online) {
        _stateReceivedAt = DateTime.now();
        _onlinePoll ??= Timer.periodic(const Duration(milliseconds: 320), (_) => _pollOnline());
        _applyOnlineVisuals();
      } else {
        _local!
          ..restart()
          ..start();
        _applyLocalVisuals();
      }
    }
    if (mounted) setState(() {});
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

      if (_layoutDeveloperMode) {
        _world
          ..setScreenOwners(List<int>.generate(28, (i) => i % (widget.players.isEmpty ? 1 : math.min(4, widget.players.length).toInt())))
          ..setPlayerScreenTexts(List<String>.generate(4, (i) => const ['07.50', '09.25', '11.00', '12.75'][i]))
          ..setStationTimerTexts(const ['00.00', '00.00', '00.00', '00.00']);
      } else if (widget.online) {
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
    HardwareKeyboard.instance.removeHandler(_handleDeveloperKeyboard);
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
  }

  void _applyLocalVisuals() {
    final controller = _local;
    if (controller == null || !_sceneReady) return;
    if (_lastRound != controller.round) {
      _world.setScreenOwners(controller.screenOwners, playerTimes: widget.players.take(4).map((p) => p.targetMs).toList());
      _lastRound = controller.round;
    }
    _sync3DDisplays();
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
    _sync3DDisplays();
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
      values.add(player == null || phase == GuessTimePhase.waiting
          ? '00.00'
          : formatGuessTime(player.targetMs));
    }
    return values;
  }

  List<String> _stationTimerTexts() {
    // The timer uses lightweight 3D seven-segment meshes, so a 20 fps digit
    // refresh stays responsive without uploading textures to the GPU.
    final elapsed = (_phaseElapsedMs() ~/ 50) * 50;
    return [
      for (var i = 0; i < 4; i++)
        if (i >= widget.players.length)
          '00.00'
        else
          switch (phase) {
            GuessTimePhase.timing => formatGuessTime(widget.players[i].stoppedMs ?? elapsed),
            GuessTimePhase.roundResults ||
            GuessTimePhase.finalResults ||
            GuessTimePhase.elimination ||
            GuessTimePhase.finished => formatGuessTime(widget.players[i].stoppedMs ?? 0),
            _ => '00.00',
          },
    ];
  }


  Future<void> _playDistanceButtonClick(int playerIndex) async {
    final viewer = _viewerIndex();
    final distance = _world.stationDistance(viewer, playerIndex);
    final scale = playerIndex == viewer
        ? 1.0
        : (1.0 - distance / 7.0).clamp(.16, .72).toDouble();
    final volume = (AppAudioService.effectsVolume * .82 * scale)
        .clamp(0.0, 1.0)
        .toDouble();
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.play(
        AssetSource('audio/u_u4pf5h7zip-click-345983.mp3'),
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2))
            .then((_) => player.dispose()),
      );
    } catch (_) {
      await player.dispose();
    }
  }

  void _syncOtherPlayerPressFeedback() {
    for (var i = 0; i < widget.players.length && i < 4; i++) {
      final player = widget.players[i];
      final previous = _lastStoppedMs[player.id];
      final current = player.stoppedMs;
      if (previous == null && current != null) {
        final alreadyHandled = _localPressFeedbackHandled.remove(player.id);
        if (!alreadyHandled) {
          _world.animatePress(i);
          unawaited(_playDistanceButtonClick(i));
        }
      }
      _lastStoppedMs[player.id] = current;
    }
  }

  void _sync3DDisplays() {
    if (!_sceneReady) return;
    _syncOtherPlayerPressFeedback();
    _world
      ..setViewerIndex(_viewerIndex())
      ..setPlayerScreenTexts(_screenTexts())
      ..setStationTimerTexts(_stationTimerTexts())
      ..setPlayerBehavior(
        phase: phase,
        elapsedMs: _phaseElapsedMs(),
        locked: [for (final p in widget.players.take(4)) p.locked],
      )
      ..setBigScreenDisplay(
        phase: phase,
        round: round,
        countdown: _countdownValue(),
        lockedCount: widget.players.where((p) => p.locked).length,
        totalPlayers: widget.players.length,
        roundStandings: _roundStandings(),
        finalStandings: _finalStandings(),
        loserName: _player(_loserId() ?? '')?.name,
      );
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
    if (_layoutDeveloperMode) return false;
    if (phase != GuessTimePhase.timing || player.locked || player.isBot) return false;
    if (widget.online) return player.id == widget.identity!.playerId;
    return player.isLocal;
  }

  Future<void> _press(GuessTimePlayer player) async {
    if (!_canPress(player) || _buttonPressInFlight.contains(player.id)) return;
    _buttonPressInFlight.add(player.id);
    final index = widget.players.indexOf(player);
    _localPressFeedbackHandled.add(player.id);
    _world.animatePress(index);
    AppAudioService.playClick();
    try {
      if (!widget.online) {
        _local!.press(player.id);
        return;
      }
      // Lock locally immediately for responsive feedback; the authoritative time
      // still comes back from the server on the next poll.
      player.locked = true;
      if (mounted) setState(() {});
      await widget.service!.action(widget.identity!, 'stop');
      await _pollOnline();
    } on GuessTimeOnlineException catch (e) {
      _localPressFeedbackHandled.remove(player.id);
      player.locked = false;
      if (mounted) setState(() => _onlineError = e.message);
    } finally {
      _buttonPressInFlight.remove(player.id);
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
                  if (_sceneReady) ..._stationButtons(size),
                  if (_sceneReady && phase == GuessTimePhase.finished) _bigScreenOverlay(size),
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

  List<Widget> _stationTimerLabels(Size size) => const [];

  List<Widget> _stationButtons(Size size) {
    final result = <Widget>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < widget.players.length && i < 4; i++) {
      final p = widget.players[i];
      final point = _world.projectButton(i, size, phase);
      if (point == null) continue;
      final canPress = _canPress(p);
      final color = GuessTimePalette.colors[p.colorIndex.clamp(0, 3).toInt()];
      final pulse = (math.sin(nowMs / 230.0) + 1.0) * .5;
      const hitSize = 128.0;
      result.add(
        Positioned(
          left: point.dx - hitSize * .5,
          top: point.dy - hitSize * .5,
          width: hitSize,
          height: hitSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (canPress)
                IgnorePointer(
                  child: Container(
                    width: 58 + pulse * 8,
                    height: 58 + pulse * 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(.26 + pulse * .12),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(.12 + pulse * .10),
                          blurRadius: 12 + pulse * 7,
                          spreadRadius: 1 + pulse * 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: canPress
                      ? (_) => unawaited(_press(p))
                      : null,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return result;
  }

  Widget _bigScreenOverlay(Size size) {
    if (phase != GuessTimePhase.finished) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _screenAction('إعادة', Icons.replay_rounded, _canRematch() ? _rematch : null),
          const SizedBox(width: 8),
          _screenAction('خروج', Icons.exit_to_app_rounded, () => Navigator.pop(context)),
        ],
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
