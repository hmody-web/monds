import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../models/guess_time_models.dart';

class GuessTimeAudioCueSettings {
  GuessTimeAudioCueSettings({
    required this.sourceKey,
    this.enabled = true,
    this.volume = 1,
    this.rate = 1,
    this.delayMs = 0,
    this.startOffsetMs = 0,
    this.loop = false,
    this.customPath = '',
  });

  bool enabled;
  String sourceKey;
  String customPath;
  double volume;
  double rate;
  double delayMs;
  double startOffsetMs;
  bool loop;

  String get sourceDescription {
    if (sourceKey == GuessTimeAudioController.customSourceKey) {
      return customPath.isEmpty ? 'ملف مخصص غير محدد' : customPath;
    }
    return GuessTimeAudioController.availableSources[sourceKey] ?? sourceKey;
  }
}

class GuessTimeAudioSettings {
  final background = GuessTimeAudioCueSettings(
    sourceKey: 'background',
    volume: .26,
    rate: 1,
    loop: true,
  );

  final tankShot = GuessTimeAudioCueSettings(
    sourceKey: 'shot_tank',
    volume: .95,
    rate: 1,
  );

  final timeStart = GuessTimeAudioCueSettings(
    sourceKey: 'timestart',
    volume: .92,
    rate: 1,
  );

  final timeStop = GuessTimeAudioCueSettings(
    sourceKey: 'timebutton',
    volume: .92,
    rate: 1,
  );

  final tankMove = GuessTimeAudioCueSettings(
    sourceKey: 'tankmove',
    volume: .58,
    rate: 1,
    loop: true,
  );

  final tankHullTurn = GuessTimeAudioCueSettings(
    sourceKey: 'tankmove',
    volume: .42,
    rate: .78,
    loop: true,
  );

  final turretTurn = GuessTimeAudioCueSettings(
    sourceKey: 'tankmove',
    volume: .25,
    rate: 1.20,
    loop: true,
  );

  final gunTurn = GuessTimeAudioCueSettings(
    sourceKey: 'tankmove',
    volume: .20,
    rate: 1.42,
    loop: true,
  );

  final Map<GuessTimePhase, GuessTimeAudioCueSettings> screenTransitions = {
    for (final phase in GuessTimePhase.values)
      phase: GuessTimeAudioCueSettings(
        sourceKey: 'transition',
        volume: .62,
        rate: 1,
        enabled: phase != GuessTimePhase.waiting,
      ),
  };
}

class GuessTimeAudioController {
  GuessTimeAudioController();

  static const String customSourceKey = 'custom';

  static const Map<String, String> assetSources = <String, String>{
    'background': 'audio/background.mp3',
    'shot_tank': 'audio/shot_tank.mp3',
    'timestart': 'audio/timestart.mp3',
    'timebutton': 'audio/timebutton.mp3',
    'transition': 'audio/transion.mp3',
    'tankmove': 'audio/tankmove.mp3',
    'click': 'audio/u_u4pf5h7zip-click-345983.mp3',
    'pistol_old': 'audio/mrfriends-pistol-shot-233473.mp3',
    'footsteps': 'audio/freeeverythingxx-walking-up-the-stairs-268464.mp3',
    'piano': 'audio/ncprime-noncopyright-music-pianos-295174.mp3',
    'death': 'audio/410184-Monster_Within_-Hunter_-Hit-Accu-Damage02.mp3',
    'impact': 'audio/403621-HARD_FLESH_IMPACT_-Sharp_Metal_Object_Body_Hit_-Juicy_Gore_Blood_Spill_-04_004004_.mp3',
  };

  static const Map<String, String> availableSources = <String, String>{
    'background': 'background.mp3',
    'shot_tank': 'shot_tank.mp3',
    'timestart': 'timestart.mp3',
    'timebutton': 'timebutton.mp3',
    'transition': 'transion.mp3',
    'tankmove': 'tankmove.mp3',
    'click': 'صوت الضغط القديم',
    'pistol_old': 'صوت المسدس القديم',
    'footsteps': 'صوت المشي القديم',
    'piano': 'موسيقى البيانو القديمة',
    'death': 'صوت الموت القديم',
    'impact': 'صوت الاصطدام القديم',
    customSourceKey: 'اختيار ملف من الحاسوب',
  };

  final settings = GuessTimeAudioSettings();

  final AudioPlayer _backgroundPlayer = AudioPlayer();
  final AudioPlayer _shotPlayer = AudioPlayer();
  final AudioPlayer _timeStartPlayer = AudioPlayer();
  final AudioPlayer _timeStopPlayer = AudioPlayer();
  final AudioPlayer _screenPlayer = AudioPlayer();
  final AudioPlayer _tankMovePlayer = AudioPlayer();
  final AudioPlayer _tankHullTurnPlayer = AudioPlayer();
  final AudioPlayer _turretTurnPlayer = AudioPlayer();
  final AudioPlayer _gunTurnPlayer = AudioPlayer();
  final AudioPlayer _previewPlayer = AudioPlayer();

  final Map<AudioPlayer, Timer> _delayTimers = <AudioPlayer, Timer>{};
  bool _prepared = false;
  bool _backgroundRequested = false;
  bool _tankMoving = false;
  bool _tankHullTurning = false;
  bool _turretTurning = false;
  bool _gunTurning = false;

  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;
    try {
      await Future.wait([
        _backgroundPlayer.setReleaseMode(ReleaseMode.loop),
        _shotPlayer.setReleaseMode(ReleaseMode.stop),
        _timeStartPlayer.setReleaseMode(ReleaseMode.stop),
        _timeStopPlayer.setReleaseMode(ReleaseMode.stop),
        _screenPlayer.setReleaseMode(ReleaseMode.stop),
        _tankMovePlayer.setReleaseMode(ReleaseMode.loop),
        _tankHullTurnPlayer.setReleaseMode(ReleaseMode.loop),
        _turretTurnPlayer.setReleaseMode(ReleaseMode.loop),
        _gunTurnPlayer.setReleaseMode(ReleaseMode.loop),
        _previewPlayer.setReleaseMode(ReleaseMode.stop),
      ]);
    } catch (_) {}
  }

  Source? _sourceFor(GuessTimeAudioCueSettings cue) {
    if (!cue.enabled) return null;
    if (cue.sourceKey == customSourceKey) {
      final path = cue.customPath.trim();
      if (path.isEmpty) return null;
      return DeviceFileSource(path);
    }
    final asset = assetSources[cue.sourceKey];
    if (asset == null) return null;
    return AssetSource(asset);
  }

  Duration _positionFor(GuessTimeAudioCueSettings cue) {
    final negativeDelaySkip = cue.delayMs < 0 ? -cue.delayMs : 0.0;
    final ms = (cue.startOffsetMs + negativeDelaySkip).clamp(0.0, 600000.0);
    return Duration(milliseconds: ms.round());
  }

  Future<void> _configurePlayer(
    AudioPlayer player,
    GuessTimeAudioCueSettings cue, {
    required bool loop,
  }) async {
    await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await player.setVolume(cue.volume.clamp(0.0, 1.0).toDouble());
    await player.setPlaybackRate(cue.rate.clamp(.25, 3.0).toDouble());
  }

  Future<void> _play(
    AudioPlayer player,
    GuessTimeAudioCueSettings cue, {
    bool? forceLoop,
    bool restart = true,
  }) async {
    final source = _sourceFor(cue);
    _delayTimers.remove(player)?.cancel();
    if (source == null) {
      try {
        await player.stop();
      } catch (_) {}
      return;
    }

    Future<void> fire() async {
      try {
        await _configurePlayer(player, cue, loop: forceLoop ?? cue.loop);
        if (restart) await player.stop();
        await player.play(source, position: _positionFor(cue));
      } catch (_) {}
    }

    final delay = cue.delayMs > 0 ? cue.delayMs.round() : 0;
    if (delay <= 0) {
      await fire();
      return;
    }
    _delayTimers[player] = Timer(Duration(milliseconds: delay), () {
      _delayTimers.remove(player);
      unawaited(fire());
    });
  }

  Future<void> startBackground() async {
    _backgroundRequested = true;
    await prepare();
    await _play(_backgroundPlayer, settings.background, forceLoop: true);
  }

  Future<void> restartBackground() async {
    if (!_backgroundRequested) return;
    await _backgroundPlayer.stop();
    await _play(_backgroundPlayer, settings.background, forceLoop: true);
  }

  Future<void> playShot() => _play(_shotPlayer, settings.tankShot);
  Future<void> playTimeStart() => _play(_timeStartPlayer, settings.timeStart);
  Future<void> playTimeStop() => _play(_timeStopPlayer, settings.timeStop);

  Future<void> playTimeStopWithVolumeScale(double scale) async {
    final base = settings.timeStop;
    final source = _sourceFor(base);
    if (source == null) return;
    final player = AudioPlayer();
    try {
      final effectiveVolume = (base.volume * scale).clamp(0.0, 1.0).toDouble();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(effectiveVolume);
      await player.setPlaybackRate(base.rate.clamp(.25, 3.0).toDouble());
      final delay = base.delayMs > 0 ? base.delayMs.round() : 0;
      if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
      await player.play(source, position: _positionFor(base));
      try {
        await player.onPlayerComplete.first.timeout(const Duration(seconds: 30));
      } catch (_) {}
    } catch (_) {
      // A spatial feedback sound must never block gameplay.
    } finally {
      await player.dispose();
    }
  }

  Future<void> playScreenTransition(GuessTimePhase phase) async {
    final cue = settings.screenTransitions[phase];
    if (cue == null) return;
    await _play(_screenPlayer, cue);
  }

  Future<void> setTankMotionState({
    required bool moving,
    required bool hullTurning,
    required bool turretTurning,
    required bool gunTurning,
  }) async {
    await prepare();
    if (_tankMoving != moving) {
      _tankMoving = moving;
      if (moving) {
        await _play(_tankMovePlayer, settings.tankMove, forceLoop: true);
      } else {
        _delayTimers.remove(_tankMovePlayer)?.cancel();
        await _tankMovePlayer.stop();
      }
    }
    if (_tankHullTurning != hullTurning) {
      _tankHullTurning = hullTurning;
      if (hullTurning) {
        await _play(_tankHullTurnPlayer, settings.tankHullTurn, forceLoop: true);
      } else {
        _delayTimers.remove(_tankHullTurnPlayer)?.cancel();
        await _tankHullTurnPlayer.stop();
      }
    }
    if (_turretTurning != turretTurning) {
      _turretTurning = turretTurning;
      if (turretTurning) {
        await _play(_turretTurnPlayer, settings.turretTurn, forceLoop: true);
      } else {
        _delayTimers.remove(_turretTurnPlayer)?.cancel();
        await _turretTurnPlayer.stop();
      }
    }
    if (_gunTurning != gunTurning) {
      _gunTurning = gunTurning;
      if (gunTurning) {
        await _play(_gunTurnPlayer, settings.gunTurn, forceLoop: true);
      } else {
        _delayTimers.remove(_gunTurnPlayer)?.cancel();
        await _gunTurnPlayer.stop();
      }
    }
  }

  Future<void> stopTankMotion() => setTankMotionState(
        moving: false,
        hullTurning: false,
        turretTurning: false,
        gunTurning: false,
      );

  Future<void> applyLiveTuning() async {
    try {
      await Future.wait([
        _backgroundPlayer.setVolume(settings.background.volume.clamp(0.0, 1.0).toDouble()),
        _backgroundPlayer.setPlaybackRate(settings.background.rate.clamp(.25, 3.0).toDouble()),
        _tankMovePlayer.setVolume(settings.tankMove.volume.clamp(0.0, 1.0).toDouble()),
        _tankMovePlayer.setPlaybackRate(settings.tankMove.rate.clamp(.25, 3.0).toDouble()),
        _tankHullTurnPlayer.setVolume(settings.tankHullTurn.volume.clamp(0.0, 1.0).toDouble()),
        _tankHullTurnPlayer.setPlaybackRate(settings.tankHullTurn.rate.clamp(.25, 3.0).toDouble()),
        _turretTurnPlayer.setVolume(settings.turretTurn.volume.clamp(0.0, 1.0).toDouble()),
        _turretTurnPlayer.setPlaybackRate(settings.turretTurn.rate.clamp(.25, 3.0).toDouble()),
        _gunTurnPlayer.setVolume(settings.gunTurn.volume.clamp(0.0, 1.0).toDouble()),
        _gunTurnPlayer.setPlaybackRate(settings.gunTurn.rate.clamp(.25, 3.0).toDouble()),
      ]);
    } catch (_) {}
  }

  Future<void> refreshTankMotionSources() async {
    final moving = _tankMoving;
    final hull = _tankHullTurning;
    final turret = _turretTurning;
    final gun = _gunTurning;
    _tankMoving = _tankHullTurning = _turretTurning = _gunTurning = false;
    await Future.wait([
      _tankMovePlayer.stop(),
      _tankHullTurnPlayer.stop(),
      _turretTurnPlayer.stop(),
      _gunTurnPlayer.stop(),
    ]);
    await setTankMotionState(
      moving: moving,
      hullTurning: hull,
      turretTurning: turret,
      gunTurning: gun,
    );
  }

  Future<void> testCue(GuessTimeAudioCueSettings cue) async {
    await prepare();
    await _previewPlayer.stop();
    final preview = GuessTimeAudioCueSettings(
      sourceKey: cue.sourceKey,
      customPath: cue.customPath,
      enabled: cue.enabled,
      volume: cue.volume,
      rate: cue.rate,
      delayMs: cue.delayMs,
      startOffsetMs: cue.startOffsetMs,
      loop: cue.loop,
    );
    await _play(_previewPlayer, preview, forceLoop: cue.loop);
  }

  Future<void> stopPreview() async {
    _delayTimers.remove(_previewPlayer)?.cancel();
    try {
      await _previewPlayer.stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    _backgroundRequested = false;
    for (final timer in _delayTimers.values) {
      timer.cancel();
    }
    _delayTimers.clear();
    _tankMoving = _tankHullTurning = _turretTurning = _gunTurning = false;
    try {
      await Future.wait([
        _backgroundPlayer.stop(),
        _shotPlayer.stop(),
        _timeStartPlayer.stop(),
        _timeStopPlayer.stop(),
        _screenPlayer.stop(),
        _tankMovePlayer.stop(),
        _tankHullTurnPlayer.stop(),
        _turretTurnPlayer.stop(),
        _gunTurnPlayer.stop(),
        _previewPlayer.stop(),
      ]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stopAll();
    await Future.wait([
      _backgroundPlayer.dispose(),
      _shotPlayer.dispose(),
      _timeStartPlayer.dispose(),
      _timeStopPlayer.dispose(),
      _screenPlayer.dispose(),
      _tankMovePlayer.dispose(),
      _tankHullTurnPlayer.dispose(),
      _turretTurnPlayer.dispose(),
      _gunTurnPlayer.dispose(),
      _previewPlayer.dispose(),
    ]);
  }
}
