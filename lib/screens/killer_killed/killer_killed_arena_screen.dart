import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

import '../../core/killer_killed_config.dart';
import '../../services/app_audio_service.dart';
import 'killer_killed_3d_world.dart';

class KillerKilledArenaScreen extends StatefulWidget {
  final int botCount;
  final Color playerColor;
  final String playerName;

  const KillerKilledArenaScreen({
    super.key,
    required this.botCount,
    required this.playerColor,
    this.playerName = 'محمد',
  });

  @override
  State<KillerKilledArenaScreen> createState() => _KillerKilledArenaScreenState();
}

enum _RoundPhase { movement, reveal, shooting, finished }

class _Fighter {
  _Fighter({
    required this.id,
    required this.name,
    required this.isHuman,
    required this.color,
    required this.x,
    required this.y,
    required this.angle,
  });

  final int id;
  final String name;
  final bool isHuman;
  final Color color;

  double x;
  double y;
  double angle;
  double velocityX = 0;
  double velocityY = 0;
  double walkTime = 0;
  int hearts = KillerKilledConfig.startingHearts;
  bool eliminated = false;
  double fall = 0;
  double hitFlash = 0;
  double shotFlash = 0;
}

class _ArenaObstacle {
  const _ArenaObstacle(this.x, this.y, this.halfW, this.halfH);

  final double x;
  final double y;
  final double halfW;
  final double halfH;
}

class _KillerKilledArenaScreenState extends State<KillerKilledArenaScreen> {
  static const _palette = <Color>[
    Color(0xFF2F6DFF),
    Color(0xFFE84A5F),
    Color(0xFF14B87A),
    Color(0xFFFFB020),
    Color(0xFF9B5DE5),
    Color(0xFF00B8D9),
    Color(0xFFF15BB5),
    Color(0xFFF2F4F8),
    Color(0xFFFF7A35),
  ];

  final _random = math.Random();
  final List<_Fighter> _fighters = [];
  final KillerKilled3DWorld _world = KillerKilled3DWorld();

  Timer? _loop;
  Timer? _phaseTimer;
  _RoundPhase _phase = _RoundPhase.movement;
  double _remaining = KillerKilledConfig.movementSeconds.toDouble();
  Offset _stick = Offset.zero;
  double _cameraOrbit = 0;
  double _cameraPitch = 0;
  double _cameraZoom = 1.0;
  double _rightGestureStartZoom = 1.0;
  Offset _rightGestureLastFocal = Offset.zero;
  int _round = 1;
  int? _activeShooterId;
  String _centerMessage = '';
  double _messageOpacity = 0;
  DateTime _lastFrame = DateTime.now();
  double _time = 0;
  bool _sceneReady = false;
  bool _gameStarted = false;
  bool _loadingVisible = true;
  double _loadingProgress = 0;
  String _loadingStage = 'تجهيز اللعبة…';
  DateTime? _loadingStartedAt;
  Object? _sceneError;
  _ArenaObstacle? _currentObstacle;

  @override
  void initState() {
    super.initState();
    AppAudioService.suppressGlobalClick = true;
    _buildFighters();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    unawaited(_prepareGame());
  }

  Future<void> _prepareGame() async {
    _loadingStartedAt = DateTime.now();
    try {
      _setLoading(.03, 'تجهيز وضع العرض');
      await _enterLandscapeMode();

      _setLoading(.10, 'تحميل المؤثرات الصوتية');
      await AppAudioService.preloadArenaAudio();

      _setLoading(.16, 'تشغيل محرك اللعبة');
      await _world.initialize(
        onProgress: (progress, stage) {
          _setLoading(.16 + progress * .58, stage);
        },
      );

      _setLoading(.77, 'إنشاء اللاعبين');
      for (final fighter in _fighters) {
        _world.addFighter(fighter.id, fighter.color);
      }
      _world.setObstacle(visible: false);
      _sync3D();

      if (!mounted) return;
      setState(() => _sceneReady = true);

      // Mount SceneView behind the loading screen and give the GPU a short
      // warm-up window. The loading screen remains visible until both assets
      // and the rendered scene are actually ready.
      _setLoading(.88, 'تهيئة الكاميرا والإضاءة');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _setLoading(.93, 'إحماء المشهد ثلاثي الأبعاد');
      await _smoothLoadingToReady();

      if (!mounted) return;
      _startMovementRound(first: true);
      _gameStarted = true;
      await AppAudioService.startKillerKilledMusic();
      _setLoading(1, 'جاهز للقتال');
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() => _loadingVisible = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sceneError = error;
        _loadingVisible = false;
      });
    }
  }

  void _setLoading(double progress, String stage) {
    if (!mounted) return;
    final next = progress.clamp(_loadingProgress, 1.0).toDouble();
    setState(() {
      _loadingProgress = next;
      _loadingStage = stage;
    });
  }

  Future<void> _smoothLoadingToReady() async {
    const minimumLoadingTime = Duration(milliseconds: 4600);
    final started = _loadingStartedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(started);
    final remaining = minimumLoadingTime - elapsed;
    if (remaining.inMilliseconds <= 0) return;

    final startProgress = _loadingProgress;
    final steps = math.max(1, remaining.inMilliseconds ~/ 80);
    for (var i = 1; i <= steps; i++) {
      if (!mounted) return;
      final t = i / steps;
      final eased = 1 - math.pow(1 - t, 2).toDouble();
      _setLoading(startProgress + (.985 - startProgress) * eased, 'وضع اللمسات الأخيرة');
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  void dispose() {
    _loop?.cancel();
    _phaseTimer?.cancel();
    AppAudioService.suppressGlobalClick = false;
    unawaited(AppAudioService.stopArenaAudio());
    unawaited(_leaveLandscapeMode());
    super.dispose();
  }

  Future<void> _enterLandscapeMode() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // Desktop/web previews do not always implement orientation channels.
    }
  }

  Future<void> _leaveLandscapeMode() async {
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Keep browser/desktop testing safe when platform controls are absent.
    }
  }

  void _buildFighters() {
    _fighters
      ..clear()
      ..add(
        _Fighter(
          id: 0,
          name: widget.playerName,
          isHuman: true,
          color: widget.playerColor,
          x: .50,
          y: .75,
          angle: -math.pi / 2,
        ),
      );

    for (var i = 0; i < widget.botCount; i++) {
      final theta = (math.pi * 2 / widget.botCount) * i;
      _fighters.add(
        _Fighter(
          id: i + 1,
          name: 'BOT ${i + 1}',
          isHuman: false,
          color: _palette[(i + 1) % _palette.length],
          x: .5 + math.cos(theta) * .30,
          y: .5 + math.sin(theta) * .25,
          angle: theta + math.pi,
        ),
      );
    }
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastFrame).inMicroseconds / 1000000).clamp(0.0, .05);
    _lastFrame = now;
    _time += dt;

    if (!_gameStarted) return;

    if (_phase == _RoundPhase.movement) {
      _remaining -= dt;
      _moveHuman(dt);
      _moveBots(dt);
      _resolveFighterCollisions();
      if (_remaining <= 0) _finishMovement();
    } else {
      for (final fighter in _fighters) {
        fighter.velocityX *= math.pow(.0008, dt).toDouble();
        fighter.velocityY *= math.pow(.0008, dt).toDouble();
      }
    }

    for (final fighter in _fighters) {
      final speed = math.sqrt(fighter.velocityX * fighter.velocityX + fighter.velocityY * fighter.velocityY);
      if (!fighter.eliminated) {
        fighter.walkTime += dt * (1 + speed * 13);
      }
      if (fighter.hitFlash > 0) {
        fighter.hitFlash = math.max(0, fighter.hitFlash - dt * 2.7);
      }
      if (fighter.shotFlash > 0) {
        fighter.shotFlash = math.max(0, fighter.shotFlash - dt);
      }
      if (fighter.eliminated && fighter.fall < 1) {
        fighter.fall = math.min(1, fighter.fall + dt * 2.15);
      }
    }

    if (_messageOpacity > 0 && _phase == _RoundPhase.movement) {
      _messageOpacity = math.max(0, _messageOpacity - dt * .7);
    }

    _sync3D();
    setState(() {});
  }

  void _handleRightLookDrag(Offset delta) {
    if (!_gameStarted || _fighters.isEmpty || _phase == _RoundPhase.finished) return;

    final me = _fighters.first;
    const yawSensitivity = 0.0062;
    const pitchSensitivity = 0.0048;

    // Requested mirrored right-side look controls: dragging right turns/looks
    // left, dragging left turns/looks right; dragging up lowers the camera and
    // dragging down raises it.
    final yawDelta = -delta.dx * yawSensitivity;
    final pitchDelta = delta.dy * pitchSensitivity;

    if (_phase == _RoundPhase.movement && !me.eliminated) {
      // While moving, horizontal dragging turns the actual fighter. The camera
      // only follows that heading; it never auto-orbits on its own.
      me.angle = _normalizeAngle(me.angle + yawDelta);
      _cameraOrbit = 0;
    } else {
      // During reveal/shooting/death, the fighter's aim stays frozen. Horizontal
      // dragging only inspects the scene with the camera.
      _cameraOrbit = _normalizeAngle(_cameraOrbit + yawDelta);
    }

    // Vertical dragging always controls camera elevation. No spring-back and no
    // automatic movement: the angle stays exactly where the player leaves it.
    _cameraPitch = (_cameraPitch + pitchDelta).clamp(-0.23, 0.50).toDouble();
  }


  void _handleRightScaleStart(ScaleStartDetails details) {
    _rightGestureStartZoom = _cameraZoom;
    _rightGestureLastFocal = details.localFocalPoint;
  }

  void _handleRightScaleUpdate(ScaleUpdateDetails details) {
    if (!_gameStarted || _fighters.isEmpty || _phase == _RoundPhase.finished) return;

    // One finger behaves exactly like the previous free-look surface.
    // With two fingers, the same gesture also supports a deliberately limited
    // pinch zoom so the camera never gets excessively close/far from gameplay.
    final delta = details.localFocalPoint - _rightGestureLastFocal;
    _rightGestureLastFocal = details.localFocalPoint;
    if (delta.distanceSquared > 0) {
      _handleRightLookDrag(delta);
    }

    if (details.pointerCount >= 2) {
      _cameraZoom = (_rightGestureStartZoom * details.scale)
          .clamp(0.86, 1.18)
          .toDouble();
    }
  }


  void _handleMoveStickChanged(Offset value) {
    if (!_gameStarted || _fighters.isEmpty) return;
    _stick = value;
    final me = _fighters.first;
    final shouldWalk = _phase == _RoundPhase.movement && !me.eliminated && value.distance >= .04;
    if (shouldWalk) {
      unawaited(AppAudioService.startWalking());
    } else {
      unawaited(AppAudioService.stopWalking());
    }
  }

  void _releaseMoveStick() {
    _stick = Offset.zero;
    unawaited(AppAudioService.stopWalking());
  }

  void _moveHuman(double dt) {
    final me = _fighters.first;
    if (me.eliminated) return;

    final forwardInput = (-_stick.dy).clamp(-1.0, 1.0).toDouble();
    // Mirror only left/right movement on the left joystick. Forward/backward
    // remains unchanged.
    final strafeInput = (-_stick.dx).clamp(-1.0, 1.0).toDouble();
    if (forwardInput.abs() < .04 && strafeInput.abs() < .04) {
      me.velocityX = 0;
      me.velocityY = 0;
      return;
    }

    final forwardSpeed = forwardInput >= 0 ? .245 : .175;
    const strafeSpeed = .205;
    const smoothing = 22.0;

    final forwardX = math.cos(me.angle);
    final forwardY = math.sin(me.angle);
    final rightX = -math.sin(me.angle);
    final rightY = math.cos(me.angle);

    var targetVX = forwardX * forwardInput * forwardSpeed + rightX * strafeInput * strafeSpeed;
    var targetVY = forwardY * forwardInput * forwardSpeed + rightY * strafeInput * strafeSpeed;

    // Keep diagonal movement from becoming faster than forward movement.
    final targetSpeed = math.sqrt(targetVX * targetVX + targetVY * targetVY);
    if (targetSpeed > .245) {
      final scale = .245 / targetSpeed;
      targetVX *= scale;
      targetVY *= scale;
    }

    me.velocityX += (targetVX - me.velocityX) * (1 - math.exp(-smoothing * dt));
    me.velocityY += (targetVY - me.velocityY) * (1 - math.exp(-smoothing * dt));

    me.x = (me.x + me.velocityX * dt).clamp(.055, .945);
    me.y = (me.y + me.velocityY * dt).clamp(.055, .945);
  }


  void _moveBots(double dt) {
    final me = _fighters.first;
    for (final bot in _fighters.skip(1)) {
      if (bot.eliminated) continue;

      if (_random.nextDouble() < dt * 1.15) {
        if (_remaining < 2.25 && _random.nextDouble() < .70) {
          final targetX = me.x + (_random.nextDouble() - .5) * .28;
          final targetY = me.y + (_random.nextDouble() - .5) * .28;
          final targetAngle = math.atan2(targetY - bot.y, targetX - bot.x);
          bot.angle = _lerpAngle(bot.angle, targetAngle, .62);
        } else {
          bot.angle += (_random.nextDouble() - .5) * 1.55;
        }
      }

      final speed = .108 + _random.nextDouble() * .044;
      bot.velocityX = math.cos(bot.angle) * speed;
      bot.velocityY = math.sin(bot.angle) * speed;

      var nx = bot.x + bot.velocityX * dt;
      var ny = bot.y + bot.velocityY * dt;
      if (nx < .055 || nx > .945) {
        bot.angle = math.pi - bot.angle + (_random.nextDouble() - .5) * .30;
        nx = nx.clamp(.055, .945);
      }
      if (ny < .055 || ny > .945) {
        bot.angle = -bot.angle + (_random.nextDouble() - .5) * .30;
        ny = ny.clamp(.055, .945);
      }
      bot.x = nx;
      bot.y = ny;
    }
  }

  void _resolveFighterCollisions() {
    const minDistance = .082;
    final humanIsMoving = _stick.distance >= .04;

    for (var i = 0; i < _fighters.length; i++) {
      final a = _fighters[i];
      if (a.eliminated) continue;
      for (var j = i + 1; j < _fighters.length; j++) {
        final b = _fighters[j];
        if (b.eliminated) continue;

        var dx = b.x - a.x;
        var dy = b.y - a.y;
        var dist = math.sqrt(dx * dx + dy * dy);
        if (dist >= minDistance) continue;
        if (dist < .0001) {
          final angle = _random.nextDouble() * math.pi * 2;
          dx = math.cos(angle) * .001;
          dy = math.sin(angle) * .001;
          dist = .001;
        }

        final overlap = minDistance - dist;
        final nx = dx / dist;
        final ny = dy / dist;

        // If the user is not touching the joystick, bots are pushed away from
        // the player instead of moving the player. This guarantees zero
        // autonomous drift between/at the start of rounds.
        if (a.isHuman && !humanIsMoving) {
          b.x = (b.x + nx * overlap).clamp(.055, .945);
          b.y = (b.y + ny * overlap).clamp(.055, .945);
          continue;
        }
        if (b.isHuman && !humanIsMoving) {
          a.x = (a.x - nx * overlap).clamp(.055, .945);
          a.y = (a.y - ny * overlap).clamp(.055, .945);
          continue;
        }

        final push = overlap / 2;
        a.x = (a.x - nx * push).clamp(.055, .945);
        a.y = (a.y - ny * push).clamp(.055, .945);
        b.x = (b.x + nx * push).clamp(.055, .945);
        b.y = (b.y + ny * push).clamp(.055, .945);
      }
    }
  }

  void _startMovementRound({bool first = false}) {
    _phaseTimer?.cancel();
    unawaited(AppAudioService.stopWalking());
    _phase = _RoundPhase.movement;
    _remaining = KillerKilledConfig.movementSeconds.toDouble();
    _activeShooterId = null;
    _stick = Offset.zero;
    _cameraOrbit = 0;
    if (_fighters.isNotEmpty) {
      _fighters.first.velocityX = 0;
      _fighters.first.velocityY = 0;
    }
    _currentObstacle = null;
    if (_world.ready) _world.setObstacle(visible: false);
    _centerMessage = first ? 'اليسار للحركة • اسحب يمين الشاشة للنظر والالتفاف' : 'الجولة $_round';
    _messageOpacity = 1;
  }

  _ArenaObstacle _randomizeObstacle() {
    for (var attempt = 0; attempt < 40; attempt++) {
      final candidate = _ArenaObstacle(
        .18 + _random.nextDouble() * .64,
        .18 + _random.nextDouble() * .64,
        .073,
        .057,
      );
      var valid = true;
      for (final fighter in _fighters.where((f) => !f.eliminated)) {
        final dx = (fighter.x - candidate.x).abs();
        final dy = (fighter.y - candidate.y).abs();
        if (dx < candidate.halfW + .06 && dy < candidate.halfH + .06) {
          valid = false;
          break;
        }
      }
      if (valid) return candidate;
    }
    return const _ArenaObstacle(.5, .5, .073, .057);
  }

  void _finishMovement() {
    if (_phase != _RoundPhase.movement) return;
    unawaited(AppAudioService.stopWalking());
    _phase = _RoundPhase.reveal;
    _remaining = 0;
    _stick = Offset.zero;
    _centerMessage = 'انكشف الجميع • الآن الالتفاف بالكاميرا فقط';
    _messageOpacity = 1;
    _currentObstacle = _randomizeObstacle();
    for (final fighter in _fighters) {
      fighter.velocityX = 0;
      fighter.velocityY = 0;
    }
    if (_world.ready && _currentObstacle != null) {
      _world.setObstacle(visible: true, x: _currentObstacle!.x, y: _currentObstacle!.y);
    }
    _sync3D();
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 1050), _beginShooting);
  }

  Future<void> _beginShooting() async {
    if (!mounted || _phase == _RoundPhase.finished) return;
    _phase = _RoundPhase.shooting;
    final order = _fighters.where((f) => !f.eliminated).toList()..shuffle(_random);

    for (final shooter in order) {
      if (!mounted || shooter.eliminated || _phase == _RoundPhase.finished) continue;
      _activeShooterId = shooter.id;
      _centerMessage = shooter.isHuman ? 'دور ${shooter.name}' : 'دور لاعب ${shooter.id + 1}';
      _messageOpacity = 1;
      _sync3D();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 620));
      if (!mounted) return;

      final victim = _rayHit(shooter);
      unawaited(AppAudioService.playPistolShot());
      shooter.shotFlash = .22;
      if (victim != null) {
        victim.hearts = math.max(0, victim.hearts - 1);
        victim.hitFlash = 1;
        unawaited(AppAudioService.playDamageHit());
        if (_sceneReady) _world.addBlood(victim.x, victim.y);
        if (victim.hearts == 0) {
          victim.eliminated = true;
          // Let the flesh impact land first, then layer the kill cue a moment
          // later so a fatal hit sounds heavier instead of replacing the hit.
          Future<void>.delayed(const Duration(milliseconds: 95), () {
            unawaited(AppAudioService.playDeath());
          });
        }
      }

      _sync3D();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 720));

      if (_fighters.where((f) => !f.eliminated).length <= 1) {
        _finishGame();
        return;
      }
    }

    _activeShooterId = null;
    _round++;
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (mounted) _startMovementRound();
  }

  _Fighter? _rayHit(_Fighter shooter) {
    final dx = math.cos(shooter.angle);
    final dy = math.sin(shooter.angle);
    final limit = _rayLimitT(shooter);
    _Fighter? best;
    var bestT = double.infinity;

    for (final target in _fighters) {
      if (target.id == shooter.id || target.eliminated) continue;
      final vx = target.x - shooter.x;
      final vy = target.y - shooter.y;
      final t = vx * dx + vy * dy;
      if (t <= 0 || t >= limit) continue;
      final closestX = shooter.x + dx * t;
      final closestY = shooter.y + dy * t;
      final distance = math.sqrt(math.pow(target.x - closestX, 2) + math.pow(target.y - closestY, 2));
      if (distance < .066 && t < bestT) {
        bestT = t;
        best = target;
      }
    }
    return best;
  }

  double _rayLimitT(_Fighter shooter) {
    final dx = math.cos(shooter.angle);
    final dy = math.sin(shooter.angle);
    var limit = 2.0;

    if (dx > .0001) limit = math.min(limit, (.955 - shooter.x) / dx);
    if (dx < -.0001) limit = math.min(limit, (.045 - shooter.x) / dx);
    if (dy > .0001) limit = math.min(limit, (.955 - shooter.y) / dy);
    if (dy < -.0001) limit = math.min(limit, (.045 - shooter.y) / dy);

    final obstacle = _currentObstacle;
    if (obstacle != null && _phase != _RoundPhase.movement) {
      final hit = _rayRectIntersection(
        shooter.x,
        shooter.y,
        dx,
        dy,
        obstacle.x - obstacle.halfW,
        obstacle.x + obstacle.halfW,
        obstacle.y - obstacle.halfH,
        obstacle.y + obstacle.halfH,
      );
      if (hit != null && hit > .015) limit = math.min(limit, hit);
    }
    return limit.clamp(.04, 2.0);
  }

  double? _rayRectIntersection(
    double ox,
    double oy,
    double dx,
    double dy,
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) {
    var tMin = -double.infinity;
    var tMax = double.infinity;

    if (dx.abs() < .000001) {
      if (ox < minX || ox > maxX) return null;
    } else {
      var t1 = (minX - ox) / dx;
      var t2 = (maxX - ox) / dx;
      if (t1 > t2) {
        final temp = t1;
        t1 = t2;
        t2 = temp;
      }
      tMin = math.max(tMin, t1);
      tMax = math.min(tMax, t2);
    }

    if (dy.abs() < .000001) {
      if (oy < minY || oy > maxY) return null;
    } else {
      var t1 = (minY - oy) / dy;
      var t2 = (maxY - oy) / dy;
      if (t1 > t2) {
        final temp = t1;
        t1 = t2;
        t2 = temp;
      }
      tMin = math.max(tMin, t1);
      tMax = math.min(tMax, t2);
    }

    if (tMax < math.max(0, tMin)) return null;
    return tMin >= 0 ? tMin : tMax;
  }

  void _finishGame() {
    unawaited(AppAudioService.stopWalking());
    _phase = _RoundPhase.finished;
    _activeShooterId = null;
    final winner = _fighters.where((f) => !f.eliminated).firstOrNull;
    _centerMessage = winner == null
        ? 'انتهت الجولة'
        : winner.isHuman
            ? 'فزت! 🎉'
            : 'الفائز لاعب ${winner.id + 1}';
    _messageOpacity = 1;
    _sync3D();
    setState(() {});
  }

  void _restart() {
    _round = 1;
    _world.clearBlood();
    _buildFighters();
    _startMovementRound(first: true);
    _sync3D();
    setState(() {});
  }

  void _sync3D() {
    if (!_world.ready) return;
    final movement = _phase == _RoundPhase.movement;
    final spectating = _fighters.isNotEmpty && _fighters.first.eliminated;
    for (final fighter in _fighters) {
      final speed = math.sqrt(fighter.velocityX * fighter.velocityX + fighter.velocityY * fighter.velocityY);
      final active = fighter.id == _activeShooterId;
      final visible = fighter.eliminated || spectating || !movement || fighter.isHuman;
      final showLaser = !fighter.eliminated && _phase != _RoundPhase.movement;
      // Visual laser intentionally extends far beyond the arena. Bullet hit
      // logic still uses _rayLimitT independently.
      const laserLength = 60.0;

      _world.updateFighter(
        id: fighter.id,
        x: fighter.x,
        y: fighter.y,
        angle: fighter.angle,
        walkTime: fighter.walkTime,
        speed: speed,
        fall: fighter.fall,
        visible: visible,
        activeShooter: active,
        laserVisible: showLaser,
        laserLength: laserLength,
        shotFlash: fighter.shotFlash,
        hitFlash: fighter.hitFlash,
      );
    }

    final obstacle = _currentObstacle;
    _world.setObstacle(
      visible: obstacle != null && _phase != _RoundPhase.movement,
      x: obstacle?.x ?? .5,
      y: obstacle?.y ?? .5,
    );
  }

  double _lerpAngle(double a, double b, double t) {
    final diff = ((b - a + math.pi * 3) % (math.pi * 2)) - math.pi;
    return a + diff * t;
  }

  double _normalizeAngle(double value) {
    return ((value + math.pi) % (math.pi * 2)) - math.pi;
  }

  @override
  Widget build(BuildContext context) {
    final me = _fighters.first;
    final movement = _phase == _RoundPhase.movement;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
          builder: (context, constraints) {
            final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Positioned.fill(child: _buildScene(me)),
                if (_gameStarted && _phase != _RoundPhase.finished)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: constraints.maxWidth * .50,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onScaleStart: _handleRightScaleStart,
                      onScaleUpdate: _handleRightScaleUpdate,
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (_gameStarted && _sceneReady) ..._buildLabels(viewSize, me),
                if (_gameStarted)
                  Positioned(top: 12, left: 14, right: 14, child: _hud()),
                if (_gameStarted && _messageOpacity > 0)
                  Positioned(
                    top: 90,
                    left: 24,
                    right: 24,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _messageOpacity,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xE30A0F19),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white24),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 18),
                              ],
                            ),
                            child: Text(
                              _centerMessage,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_gameStarted && movement && !me.eliminated)
                  Positioned(
                    left: 24,
                    bottom: 22,
                    child: _Joystick(
                      axis: null,
                      centerIcon: null,
                      onChanged: _handleMoveStickChanged,
                      onReleased: _releaseMoveStick,
                    ),
                  ),
                if (_gameStarted && _phase == _RoundPhase.finished)
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 26,
                    child: _finishedActions(),
                  ),
                if (_loadingVisible)
                  Positioned.fill(child: _buildLoadingOverlay()),
              ],
            );
          },
        ),
    );
  }

  Widget _buildLoadingOverlay() {
    final percent = (_loadingProgress * 100).round().clamp(0, 100);
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 38),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: .92, end: 1.06),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.playerColor.withOpacity(.55), width: 1.4),
                        boxShadow: [
                          BoxShadow(color: widget.playerColor.withOpacity(.20), blurRadius: 28, spreadRadius: 3),
                        ],
                      ),
                      child: Icon(Icons.gps_fixed_rounded, color: widget.playerColor, size: 34),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'قاتل ومقتول',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _loadingStage,
                      key: ValueKey(_loadingStage),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111722),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: _loadingProgress),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Container(
                              width: constraints.maxWidth * value.clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.playerColor.withOpacity(.72),
                                    widget.playerColor,
                                    Colors.white.withOpacity(.92),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(color: widget.playerColor.withOpacity(.55), blurRadius: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '$percent%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      const Text(
                        'جاري تجهيز الساحة والموارد',
                        style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScene(_Fighter me) {
    if (_sceneError != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_rounded, color: Colors.white54, size: 44),
            const SizedBox(height: 12),
            const Text(
              'تعذر تشغيل محرك 3D',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '$_sceneError',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (!_sceneReady) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2F6DFF)),
              ),
              SizedBox(height: 12),
              Text('تجهيز الساحة ثلاثية الأبعاد…', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: SceneView(
        _world.scene,
        cameraBuilder: (elapsed) => _world.cameraFor(
          seconds: elapsed.inMicroseconds / 1000000,
          playerX: me.x,
          playerY: me.y,
          playerAngle: me.angle,
          cameraOrbit: _cameraOrbit,
          cameraPitch: _cameraPitch,
          cameraZoom: _cameraZoom,
          spectatorAmount: me.fall,
        ),
        warmUp: true,
      ),
    );
  }

  List<Widget> _buildLabels(Size size, _Fighter me) {
    final movement = _phase == _RoundPhase.movement;
    final result = <Widget>[];

    for (final fighter in _fighters) {
      if (fighter.eliminated) continue;
      if (movement && !fighter.isHuman && !me.eliminated) continue;
      final point = _world.labelScreenPoint(
        x: fighter.x,
        y: fighter.y,
        seconds: _time,
        playerX: me.x,
        playerY: me.y,
        playerAngle: me.angle,
        cameraOrbit: _cameraOrbit,
        cameraPitch: _cameraPitch,
        cameraZoom: _cameraZoom,
        spectatorAmount: me.fall,
        viewSize: size,
      );
      if (point == null) continue;

      final hearts = List.filled(fighter.hearts, '❤️').join(' ');
      final labelWidth = fighter.isHuman ? 108.0 : 82.0;
      result.add(
        Positioned(
          left: point.dx - labelWidth / 2,
          top: point.dy - 22,
          width: labelWidth,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: fighter.eliminated ? .48 : 1,
              duration: const Duration(milliseconds: 220),
              child: Transform.scale(
                scale: fighter.hitFlash > 0 ? 1.08 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hearts,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                    if (fighter.isHuman) ...[
                      const SizedBox(height: 3),
                      Text(
                        fighter.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            const Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                            Shadow(color: fighter.color.withOpacity(.55), blurRadius: 10),
                          ],
                        ),
                      ),
                    ] else
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 22,
                        height: 3,
                        decoration: BoxDecoration(
                          color: fighter.color,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [BoxShadow(color: fighter.color.withOpacity(.45), blurRadius: 8)],
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
    return result;
  }

  Widget _hud() {
    final alive = _fighters.where((fighter) => !fighter.eliminated).length;
    final secs = _remaining.ceil().clamp(0, KillerKilledConfig.movementSeconds);

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        InkWell(
          onTap: () {
            unawaited(AppAudioService.playClick());
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xD90B101A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 9),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xD90B101A),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_2_rounded, color: Colors.white54, size: 17),
              const SizedBox(width: 5),
              Text('$alive', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Container(width: 1, height: 18, color: Colors.white12),
              const SizedBox(width: 10),
              Text(
                'الجولة $_round',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xDF09101A),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _phase == _RoundPhase.movement ? widget.playerColor.withOpacity(.38) : Colors.white12),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_phase == _RoundPhase.movement) ...[
                Text(
                  '$secs',
                  style: const TextStyle(color: Colors.white, fontSize: 27, height: 1, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                const Text('تحرّك', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700)),
              ] else ...[
                Icon(
                  _phase == _RoundPhase.reveal ? Icons.visibility_rounded : Icons.gps_fixed_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  _phase == _RoundPhase.reveal ? 'انكشاف' : 'إطلاق',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _finishedActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              unawaited(AppAudioService.playClick());
              _restart();
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('إعادة اللعب'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: widget.playerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: () {
            unawaited(AppAudioService.playClick());
            Navigator.pop(context);
          },
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(54, 54),
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Joystick extends StatefulWidget {
  const _Joystick({
    required this.onChanged,
    required this.onReleased,
    required this.axis,
    required this.centerIcon,
  });

  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;
  final Axis? axis;
  final IconData? centerIcon;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  static const double _radius = 54;
  static const double _knobRadius = 22;

  void _update(Offset local) {
    final raw = local - const Offset(_radius, _radius);
    final maxTravel = _radius - _knobRadius;
    Offset d;

    if (widget.axis == Axis.vertical) {
      final y = raw.dy.clamp(-maxTravel, maxTravel).toDouble();
      d = Offset(0, y);
    } else if (widget.axis == Axis.horizontal) {
      final x = raw.dx.clamp(-maxTravel, maxTravel).toDouble();
      d = Offset(x, 0);
    } else {
      // Free 360° movement joystick: forward/back + left/right strafe.
      final length = raw.distance;
      d = length > maxTravel && length > 0
          ? raw * (maxTravel / length)
          : raw;
    }

    setState(() => _knob = d);
    widget.onChanged(Offset(d.dx / maxTravel, d.dy / maxTravel));
  }


  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: Container(
        width: _radius * 2,
        height: _radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x42151C28),
          border: Border.all(color: Colors.white24, width: 1.3),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 22)],
        ),
        child: Center(
          child: Transform.translate(
            offset: _knob,
            child: Container(
              width: _knobRadius * 2,
              height: _knobRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xDDE9EDF4),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
              ),
              child: widget.centerIcon == null
                  ? null
                  : Icon(
                      widget.centerIcon,
                      size: 19,
                      color: const Color(0xFF29313D),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
