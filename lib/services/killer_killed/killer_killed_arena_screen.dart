import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/killer_killed_config.dart';

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
  double aimPulse = 0;
  bool justShot = false;
}

class _BloodMark {
  _BloodMark({
    required this.x,
    required this.y,
    required this.radius,
    required this.rotation,
  });

  final double x;
  final double y;
  final double radius;
  final double rotation;
}

class _KillerKilledArenaScreenState extends State<KillerKilledArenaScreen> {
  final _random = math.Random();
  final List<_Fighter> _fighters = [];
  final List<_BloodMark> _bloodMarks = [];

  Timer? _loop;
  Timer? _phaseTimer;
  _RoundPhase _phase = _RoundPhase.movement;
  double _remaining = KillerKilledConfig.movementSeconds.toDouble();
  Offset _stick = Offset.zero;
  int _round = 1;
  int? _activeShooterId;
  bool _laserVisible = false;
  String _centerMessage = '';
  double _messageOpacity = 0;
  DateTime _lastFrame = DateTime.now();
  double _time = 0;

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

  @override
  void initState() {
    super.initState();
    _buildFighters();
    _startMovementRound(first: true);
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  @override
  void dispose() {
    _loop?.cancel();
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _buildFighters() {
    _bloodMarks.clear();
    _fighters
      ..clear()
      ..add(
        _Fighter(
          id: 0,
          name: widget.playerName,
          isHuman: true,
          color: widget.playerColor,
          x: .5,
          y: .74,
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
          x: .5 + math.cos(theta) * .31,
          y: .5 + math.sin(theta) * .26,
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

    if (_phase == _RoundPhase.movement) {
      _remaining -= dt;
      _moveHuman(dt);
      _moveBots(dt);
      if (_remaining <= 0) _finishMovement();
    } else {
      for (final fighter in _fighters) {
        fighter.velocityX *= math.pow(.0008, dt).toDouble();
        fighter.velocityY *= math.pow(.0008, dt).toDouble();
      }
    }

    for (final fighter in _fighters) {
      final speed = math.sqrt(fighter.velocityX * fighter.velocityX + fighter.velocityY * fighter.velocityY);
      fighter.walkTime += dt * (1 + speed * 10);
      if (fighter.hitFlash > 0) fighter.hitFlash = math.max(0, fighter.hitFlash - dt * 2.7);
      if (fighter.aimPulse > 0) fighter.aimPulse = math.max(0, fighter.aimPulse - dt * 2.2);
      if (fighter.eliminated && fighter.fall < 1) {
        fighter.fall = math.min(1, fighter.fall + dt * 2.2);
      }
      if (fighter.justShot) {
        fighter.justShot = false;
      }
    }

    if (_messageOpacity > 0 && _phase == _RoundPhase.movement) {
      _messageOpacity = math.max(0, _messageOpacity - dt * .7);
    }
    setState(() {});
  }

  void _moveHuman(double dt) {
    final me = _fighters.first;
    if (me.eliminated) return;
    final speed = .24;
    final smoothing = 12.0;

    final targetVX = (_stick.distance >= .06) ? _stick.dx * speed : 0.0;
    final targetVY = (_stick.distance >= .06) ? _stick.dy * speed : 0.0;
    me.velocityX += (targetVX - me.velocityX) * (1 - math.exp(-smoothing * dt));
    me.velocityY += (targetVY - me.velocityY) * (1 - math.exp(-smoothing * dt));

    me.x = (me.x + me.velocityX * dt).clamp(.07, .93);
    me.y = (me.y + me.velocityY * dt).clamp(.09, .91);

    if (_stick.distance >= .06) {
      final targetAngle = math.atan2(_stick.dy, _stick.dx);
      me.angle = _lerpAngle(me.angle, targetAngle, 1 - math.exp(-13 * dt));
    }
  }

  void _moveBots(double dt) {
    final me = _fighters.first;
    for (final bot in _fighters.skip(1)) {
      if (bot.eliminated) continue;

      if (_random.nextDouble() < dt * 1.15) {
        if (_remaining < 2.2 && _random.nextDouble() < .68) {
          final targetX = me.x + (_random.nextDouble() - .5) * .25;
          final targetY = me.y + (_random.nextDouble() - .5) * .25;
          final targetAngle = math.atan2(targetY - bot.y, targetX - bot.x);
          bot.angle = _lerpAngle(bot.angle, targetAngle, .65);
        } else {
          bot.angle += (_random.nextDouble() - .5) * 1.55;
        }
      }

      final speed = .11 + _random.nextDouble() * .038;
      bot.velocityX = math.cos(bot.angle) * speed;
      bot.velocityY = math.sin(bot.angle) * speed;

      var nx = bot.x + bot.velocityX * dt;
      var ny = bot.y + bot.velocityY * dt;
      if (nx < .07 || nx > .93) {
        bot.angle = math.pi - bot.angle + (_random.nextDouble() - .5) * .35;
        nx = nx.clamp(.07, .93);
      }
      if (ny < .09 || ny > .91) {
        bot.angle = -bot.angle + (_random.nextDouble() - .5) * .35;
        ny = ny.clamp(.09, .91);
      }
      bot.x = nx;
      bot.y = ny;
    }
  }

  void _startMovementRound({bool first = false}) {
    _phaseTimer?.cancel();
    _phase = _RoundPhase.movement;
    _remaining = KillerKilledConfig.movementSeconds.toDouble();
    _activeShooterId = null;
    _laserVisible = false;
    _centerMessage = first ? 'تحرّك… لا أحد يراك' : 'الجولة $_round';
    _messageOpacity = 1;
  }

  void _finishMovement() {
    if (_phase != _RoundPhase.movement) return;
    _phase = _RoundPhase.reveal;
    _remaining = 0;
    _stick = Offset.zero;
    _centerMessage = 'انكشف الجميع';
    _messageOpacity = 1;
    for (final f in _fighters) {
      f.velocityX = 0;
      f.velocityY = 0;
    }
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 1100), _beginShooting);
  }

  Future<void> _beginShooting() async {
    if (!mounted || _phase == _RoundPhase.finished) return;
    _phase = _RoundPhase.shooting;
    final order = _fighters.where((f) => !f.eliminated).toList()..shuffle(_random);

    for (final shooter in order) {
      if (!mounted || shooter.eliminated || _phase == _RoundPhase.finished) continue;
      _activeShooterId = shooter.id;
      _laserVisible = false;
      shooter.aimPulse = 1;
      _centerMessage = shooter.isHuman ? 'دور ${shooter.name}' : 'دور لاعب ${shooter.id + 1}';
      _messageOpacity = 1;
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;

      _laserVisible = true;
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;

      final victim = _rayHit(shooter);
      shooter.justShot = true;
      if (victim != null) {
        victim.hearts = math.max(0, victim.hearts - 1);
        victim.hitFlash = 1;
        _bloodMarks.add(
          _BloodMark(
            x: victim.x + (_random.nextDouble() - .5) * .02,
            y: victim.y + (_random.nextDouble() - .5) * .02,
            radius: .028 + _random.nextDouble() * .018,
            rotation: _random.nextDouble() * math.pi,
          ),
        );
        if (victim.hearts == 0) {
          victim.eliminated = true;
        }
      }
      _laserVisible = false;
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 620));

      if (_fighters.where((f) => !f.eliminated).length <= 1) {
        _finishGame();
        return;
      }
    }

    _activeShooterId = null;
    _round++;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (mounted) _startMovementRound();
  }

  _Fighter? _rayHit(_Fighter shooter) {
    final dx = math.cos(shooter.angle);
    final dy = math.sin(shooter.angle);
    _Fighter? best;
    var bestT = double.infinity;

    for (final target in _fighters) {
      if (target.id == shooter.id || target.eliminated) continue;
      final vx = target.x - shooter.x;
      final vy = target.y - shooter.y;
      final t = vx * dx + vy * dy;
      if (t <= 0 || t > 1.2) continue;
      final closestX = shooter.x + dx * t;
      final closestY = shooter.y + dy * t;
      final distance = math.sqrt(math.pow(target.x - closestX, 2) + math.pow(target.y - closestY, 2));
      if (distance < .074 && t < bestT) {
        bestT = t;
        best = target;
      }
    }
    return best;
  }

  void _finishGame() {
    _phase = _RoundPhase.finished;
    _activeShooterId = null;
    _laserVisible = false;
    final winner = _fighters.where((f) => !f.eliminated).firstOrNull;
    _centerMessage = winner == null
        ? 'انتهت الجولة'
        : winner.isHuman
            ? 'فزت! 🎉'
            : 'الفائز لاعب ${winner.id + 1}';
    _messageOpacity = 1;
    setState(() {});
  }

  void _restart() {
    _round = 1;
    _buildFighters();
    _startMovementRound(first: true);
    setState(() {});
  }

  double _lerpAngle(double a, double b, double t) {
    final diff = ((b - a + math.pi * 3) % (math.pi * 2)) - math.pi;
    return a + diff * t;
  }

  @override
  Widget build(BuildContext context) {
    final me = _fighters.first;
    final movement = _phase == _RoundPhase.movement;

    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ArenaPainter(
                  fighters: _fighters,
                  bloodMarks: _bloodMarks,
                  humanId: me.id,
                  hideOpponents: movement,
                  activeShooterId: _activeShooterId,
                  laserVisible: _laserVisible,
                  time: _time,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: _hud(),
            ),
            if (_messageOpacity > 0)
              Positioned(
                top: 104,
                left: 24,
                right: 24,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _messageOpacity,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xDD0A0F19),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
                        ),
                        child: Text(
                          _centerMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (movement && !me.eliminated)
              Positioned(
                left: 22,
                bottom: 28,
                child: _Joystick(
                  onChanged: (value) => _stick = value,
                  onReleased: () => _stick = Offset.zero,
                ),
              ),
            if (_phase == _RoundPhase.finished)
              Positioned(
                left: 22,
                right: 22,
                bottom: 26,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _restart,
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(54, 54),
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hud() {
    final me = _fighters.first;
    final secs = _remaining.ceil().clamp(0, KillerKilledConfig.movementSeconds);
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xCC0B101A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xD90B101A),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      List.filled(me.hearts, '❤️').join(' '),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.playerName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                if (_phase == _RoundPhase.movement) ...[
                  Text('$secs', style: const TextStyle(color: Colors.white, fontSize: 27, height: 1)),
                  const SizedBox(width: 8),
                  const Text('تحرّك', style: TextStyle(color: Colors.white60, fontSize: 10)),
                ] else
                  Text(
                    _phase == _RoundPhase.reveal ? 'انكشاف' : 'إطلاق',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({
    required this.fighters,
    required this.bloodMarks,
    required this.humanId,
    required this.hideOpponents,
    required this.activeShooterId,
    required this.laserVisible,
    required this.time,
  });

  final List<_Fighter> fighters;
  final List<_BloodMark> bloodMarks;
  final int humanId;
  final bool hideOpponents;
  final int? activeShooterId;
  final bool laserVisible;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final arena = Rect.fromLTWH(18, 86, size.width - 36, size.height - 144);
    _drawBackdrop(canvas, size);
    final focus = fighters.first;
    final cameraOffset = Offset(
      math.sin(time * .55) * 6 - (focus.x - .5) * 12,
      math.cos(time * .48) * 4 - (focus.y - .56) * 8,
    );

    canvas.save();
    canvas.translate(cameraOffset.dx, cameraOffset.dy);

    _drawRooftop(canvas, arena);
    _drawBlood(canvas, arena);

    final ordered = fighters.toList()..sort((a, b) => a.y.compareTo(b.y));
    for (final fighter in ordered) {
      if (hideOpponents && fighter.id != humanId) continue;
      _drawFighter(canvas, arena, fighter);
    }

    if (laserVisible && activeShooterId != null) {
      final shooter = fighters.where((f) => f.id == activeShooterId).firstOrNull;
      if (shooter != null && !shooter.eliminated) _drawLaser(canvas, arena, shooter);
    }

    canvas.restore();
  }

  void _drawBackdrop(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1224), Color(0xFF070B13), Color(0xFF03050A)],
        stops: [0.0, 0.52, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -.45),
        radius: .95,
        colors: [const Color(0x552F6DFF), const Color(0x002F6DFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final skyline = Paint()..color = const Color(0xFF0D172D);
    for (var i = 0; i < 11; i++) {
      final w = 26.0 + (i % 4) * 10;
      final h = 34.0 + (i % 5) * 18;
      final x = i * (size.width / 10) - 14;
      canvas.drawRect(Rect.fromLTWH(x, 108 - h, w, h), skyline);

      final winPaint = Paint()..color = const Color(0xAA58A6FF);
      for (var r = 0; r < 4; r++) {
        final wy = 112 - h + 8 + r * 10;
        if (wy > 100) continue;
        canvas.drawRect(Rect.fromLTWH(x + 5, wy, 4, 3), winPaint);
        canvas.drawRect(Rect.fromLTWH(x + 14, wy, 4, 3), winPaint);
      }
    }

    final moon = Paint()..color = const Color(0x18FFFFFF);
    canvas.drawCircle(Offset(size.width * .79, 46), 16, moon);
  }

  Offset _project(Rect arena, double x, double y) {
    final plane = Rect.fromLTWH(arena.left + 10, arena.top + 28, arena.width - 20, arena.height - 64);
    final localX = (x - y) * plane.width * .40;
    final localY = (x + y) * plane.height * .23;
    final baseX = plane.center.dx + localX;
    final baseY = plane.top + localY;
    return Offset(baseX, baseY);
  }

  void _drawRooftop(Canvas canvas, Rect arena) {
    final plane = Rect.fromLTWH(arena.left + 10, arena.top + 28, arena.width - 20, arena.height - 64);
    final floor = Path()
      ..moveTo(plane.center.dx, plane.top)
      ..lineTo(plane.right, plane.center.dy)
      ..lineTo(plane.center.dx, plane.bottom)
      ..lineTo(plane.left, plane.center.dy)
      ..close();

    // Shadow under rooftop slab.
    final shadow = Path.from(floor).shift(const Offset(0, 18));
    canvas.drawPath(shadow, Paint()..color = Colors.black.withOpacity(.35));

    // Rooftop slab sides.
    final rightSide = Path()
      ..moveTo(plane.right, plane.center.dy)
      ..lineTo(plane.center.dx, plane.bottom)
      ..lineTo(plane.center.dx, plane.bottom + 26)
      ..lineTo(plane.right, plane.center.dy + 26)
      ..close();
    canvas.drawPath(
      rightSide,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2736), Color(0xFF0B1119)],
        ).createShader(Rect.fromLTRB(plane.center.dx, plane.center.dy, plane.right, plane.bottom + 26)),
    );

    final leftSide = Path()
      ..moveTo(plane.left, plane.center.dy)
      ..lineTo(plane.center.dx, plane.bottom)
      ..lineTo(plane.center.dx, plane.bottom + 26)
      ..lineTo(plane.left, plane.center.dy + 26)
      ..close();
    canvas.drawPath(
      leftSide,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151F2D), Color(0xFF070B12)],
        ).createShader(Rect.fromLTRB(plane.left, plane.center.dy, plane.center.dx, plane.bottom + 26)),
    );

    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF253244), Color(0xFF141C28), Color(0xFF0A1018)],
          stops: [0.0, 0.42, 1.0],
        ).createShader(plane),
    );

    // Tile grid.
    final major = Paint()..color = Colors.white.withOpacity(.045)..strokeWidth = 1.2;
    final minor = Paint()..color = Colors.white.withOpacity(.022)..strokeWidth = 1;
    for (var i = 0; i <= 8; i++) {
      final t = i / 8;
      final a = _project(arena, t, 0);
      final b = _project(arena, t, 1);
      canvas.drawLine(a, b, i.isEven ? major : minor);
      final c = _project(arena, 0, t);
      final d = _project(arena, 1, t);
      canvas.drawLine(c, d, i.isEven ? major : minor);
    }

    final edge = Paint()..color = const Color(0x882F6DFF)..strokeWidth = 2;
    canvas.drawPath(floor, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x992F6DFF));

    // Blue accent rails.
    canvas.drawLine(Offset(plane.center.dx, plane.top), Offset(plane.right, plane.center.dy), edge);
    canvas.drawLine(Offset(plane.center.dx, plane.top), Offset(plane.left, plane.center.dy), edge);

    // Neon crosshair lines.
    canvas.drawLine(_project(arena, .5, 0), _project(arena, .5, 1), Paint()..color = const Color(0x332F6DFF)..strokeWidth = 2.5);
    canvas.drawLine(_project(arena, 0, .5), _project(arena, 1, .5), Paint()..color = const Color(0x332F6DFF)..strokeWidth = 2.5);

    // Obstacles as 3D cuboids.
    for (final entry in const [
      _Obstacle(.22, .30, .08, .06),
      _Obstacle(.74, .30, .08, .06),
      _Obstacle(.37, .63, .09, .07),
      _Obstacle(.67, .69, .09, .07),
    ]) {
      _drawObstacle(canvas, arena, entry);
    }
  }

  void _drawObstacle(Canvas canvas, Rect arena, _Obstacle obstacle) {
    final center = _project(arena, obstacle.x, obstacle.y);
    final topW = 28.0 + obstacle.w * 95;
    final topH = 16.0 + obstacle.h * 70;
    final depth = 12.0;

    final top = Path()
      ..moveTo(center.dx, center.dy - topH / 2)
      ..lineTo(center.dx + topW / 2, center.dy)
      ..lineTo(center.dx, center.dy + topH / 2)
      ..lineTo(center.dx - topW / 2, center.dy)
      ..close();
    final right = Path()
      ..moveTo(center.dx + topW / 2, center.dy)
      ..lineTo(center.dx, center.dy + topH / 2)
      ..lineTo(center.dx, center.dy + topH / 2 + depth)
      ..lineTo(center.dx + topW / 2, center.dy + depth)
      ..close();
    final left = Path()
      ..moveTo(center.dx - topW / 2, center.dy)
      ..lineTo(center.dx, center.dy + topH / 2)
      ..lineTo(center.dx, center.dy + topH / 2 + depth)
      ..lineTo(center.dx - topW / 2, center.dy + depth)
      ..close();

    canvas.drawPath(left, Paint()..color = const Color(0xFF10161F));
    canvas.drawPath(right, Paint()..color = const Color(0xFF18212F));
    canvas.drawPath(top, Paint()..color = const Color(0xFF273140));
    canvas.drawPath(top, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = const Color(0x882F6DFF));
    canvas.drawLine(center.translate(-topW * .25, -2), center.translate(topW * .25, -2), Paint()..color = const Color(0x332F6DFF));
  }

  void _drawBlood(Canvas canvas, Rect arena) {
    for (final blood in bloodMarks) {
      final p = _project(arena, blood.x, blood.y);
      final scale = 55 + blood.radius * 420;
      canvas.save();
      canvas.translate(p.dx, p.dy + 9);
      canvas.rotate(blood.rotation);
      final paint = Paint()..color = const Color(0xA8A30F24);
      final core = Path()
        ..addOval(Rect.fromCenter(center: Offset.zero, width: scale * .56, height: scale * .26))
        ..addOval(Rect.fromCenter(center: Offset(-scale * .18, 2), width: scale * .16, height: scale * .08))
        ..addOval(Rect.fromCenter(center: Offset(scale * .20, -1), width: scale * .14, height: scale * .07));
      canvas.drawPath(core, paint);
      canvas.restore();
    }
  }

  void _drawFighter(Canvas canvas, Rect arena, _Fighter fighter) {
    final base = _project(arena, fighter.x, fighter.y);
    final scale = .78 + fighter.y * .26;
    final fall = Curves.easeOut.transform(fighter.fall);
    final bob = math.sin(fighter.walkTime * 7.2) * 1.4 * (fighter.eliminated ? 0 : 1);
    final sway = math.sin(fighter.walkTime * 6.5 + fighter.id) * 0.2;
    final facing = Offset(math.cos(fighter.angle), math.sin(fighter.angle));
    final side = Offset(-facing.dy, facing.dx);
    final walk = math.sin(fighter.walkTime * 7.5) * (0.8 + (fighter.velocityX.abs() + fighter.velocityY.abs()) * 22);
    final shooterGlow = fighter.id == activeShooterId ? .95 : 0.0;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: base.translate(0, 18), width: 38 * scale, height: 14 * scale),
      Paint()..color = Colors.black.withOpacity(.40),
    );

    canvas.save();
    canvas.translate(base.dx, base.dy + bob);
    canvas.rotate(fall * 1.2 * (fighter.eliminated ? 1 : 0));
    canvas.scale(scale, scale * (1 - fall * .28));

    if (fighter.hitFlash > 0) {
      canvas.drawCircle(Offset.zero, 28 + fighter.hitFlash * 12, Paint()..color = const Color(0x66F94144).withOpacity(fighter.hitFlash * .55));
    }
    if (shooterGlow > 0) {
      canvas.drawCircle(Offset.zero, 30, Paint()..color = fighter.color.withOpacity(.10 + fighter.aimPulse * .18));
    }

    // Feet.
    final bootPaint = Paint()..color = const Color(0xFF0A0F16);
    final leftLegSwing = walk * .95;
    final rightLegSwing = -walk * .95;
    final leftFoot = Offset(-7 + leftLegSwing * .22, 15 + leftLegSwing.abs() * .08);
    final rightFoot = Offset(7 + rightLegSwing * .22, 15 + rightLegSwing.abs() * .08);
    canvas.drawOval(Rect.fromCenter(center: leftFoot, width: 10, height: 5), bootPaint);
    canvas.drawOval(Rect.fromCenter(center: rightFoot, width: 10, height: 5), bootPaint);

    // Legs.
    final pantsPaint = Paint()..color = const Color(0xFF121824);
    canvas.drawLine(const Offset(-5, -2), leftFoot, pantsPaint..strokeWidth = 7..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(5, -2), rightFoot, pantsPaint..strokeWidth = 7..strokeCap = StrokeCap.round);

    // Torso core.
    final torso = RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -26, 18, 26), const Radius.circular(8));
    canvas.drawRRect(torso, Paint()..color = const Color(0xFF1A202A));

    // Coat tails and outer coat.
    final coatColor = const Color(0xFF12171F);
    final innerAccent = Paint()..color = fighter.color.withOpacity(.82);
    final leftTail = Path()
      ..moveTo(-10, -14)
      ..quadraticBezierTo(-18 - sway * 6, 6, -16, 19)
      ..quadraticBezierTo(-8, 18, -3, 9)
      ..close();
    final rightTail = Path()
      ..moveTo(10, -14)
      ..quadraticBezierTo(18 + sway * 6, 5, 15, 20)
      ..quadraticBezierTo(8, 17, 3, 9)
      ..close();
    canvas.drawPath(leftTail, Paint()..color = coatColor);
    canvas.drawPath(rightTail, Paint()..color = coatColor);
    canvas.drawPath(
      Path()
        ..moveTo(-11, -24)
        ..quadraticBezierTo(-15, -6, -12, 10)
        ..lineTo(0, 14)
        ..lineTo(12, 10)
        ..quadraticBezierTo(15, -6, 11, -24)
        ..close(),
      Paint()..color = coatColor,
    );
    canvas.drawLine(const Offset(-9, -21), const Offset(-4, 7), Paint()..color = fighter.color.withOpacity(.65)..strokeWidth = 1.6);
    canvas.drawLine(const Offset(9, -21), const Offset(4, 7), Paint()..color = fighter.color.withOpacity(.65)..strokeWidth = 1.6);
    canvas.drawPath(
      Path()
        ..moveTo(-6, -10)
        ..lineTo(0, 12)
        ..lineTo(6, -10)
        ..close(),
      innerAccent,
    );

    // Arms.
    final armPaint = Paint()..color = const Color(0xFF171C25)..strokeWidth = 6.5..strokeCap = StrokeCap.round;
    final aimDir = facing * 12.5;
    final armLift = fighter.id == activeShooterId ? 1.0 : 0.6;
    final leftHand = Offset(-7, -11) + aimDir * armLift + side * -1.4;
    final rightHand = Offset(4, -12) + aimDir * armLift + side * 1.2;
    canvas.drawLine(const Offset(-7, -17), leftHand, armPaint);
    canvas.drawLine(const Offset(7, -17), rightHand, armPaint);

    // Collar / mask.
    final mask = Path()
      ..moveTo(-13, -29)
      ..lineTo(13, -29)
      ..lineTo(8, -18)
      ..lineTo(-8, -18)
      ..close();
    canvas.drawPath(mask, Paint()..color = const Color(0xFF090D13));

    // Head.
    canvas.drawOval(const Rect.fromLTWH(-8, -39, 16, 19), Paint()..color = const Color(0xFFE7B18E));

    // Hat brim and crown.
    canvas.drawOval(const Rect.fromLTWH(-19, -39, 38, 8), Paint()..color = const Color(0xFF080B11));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -48, 20, 14), const Radius.circular(6)),
      Paint()..color = const Color(0xFF0D1118),
    );
    canvas.drawRect(const Rect.fromLTWH(-10, -37.6, 20, 3), Paint()..color = fighter.color);

    // Eyes / mask top.
    final eyeGlow = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(4.8, -29), width: 5.5, height: 2.7), eyeGlow);
    canvas.drawCircle(const Offset(6, -29), 1.25, Paint()..color = const Color(0xFF64E0FF));

    // Gun.
    final muzzleAnchor = Offset(3, -13) + facing * 12 + side * 1.5;
    final gunGrip = Offset(1, -13) + facing * 7.5 + side * 0.8;
    canvas.drawLine(gunGrip, muzzleAnchor, Paint()..color = const Color(0xFF2F3744)..strokeWidth = 5.0..strokeCap = StrokeCap.round);
    canvas.drawLine(gunGrip.translate(-2, 1), gunGrip.translate(0, 7), Paint()..color = const Color(0xFF1D242F)..strokeWidth = 3.3..strokeCap = StrokeCap.round);
    canvas.drawCircle(muzzleAnchor, 2.5, Paint()..color = fighter.color);
    if (fighter.justShot) {
      canvas.drawCircle(muzzleAnchor, 5.5, Paint()..color = Colors.white.withOpacity(.85));
    }

    // Billboard hearts + name for human player only.
    if (fighter.isHuman) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${List.filled(fighter.hearts, '❤️').join(' ')}\n${fighter.name}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            height: 1.25,
            shadows: [Shadow(color: Colors.black, blurRadius: 5)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -73));
    }

    canvas.restore();
  }

  void _drawLaser(Canvas canvas, Rect arena, _Fighter shooter) {
    final origin = _project(arena, shooter.x, shooter.y).translate(0, -10);
    final dx = math.cos(shooter.angle);
    final dy = math.sin(shooter.angle);
    final end = _project(arena, shooter.x + dx * 1.45, shooter.y + dy * 1.45);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [shooter.color.withOpacity(.98), shooter.color.withOpacity(.16), shooter.color.withOpacity(0)],
      ).createShader(Rect.fromPoints(origin, end))
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, end, paint);
    canvas.drawCircle(origin, 4.5, Paint()..color = shooter.color.withOpacity(.9));
    canvas.drawCircle(end, 3.4, Paint()..color = shooter.color.withOpacity(.18));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) => true;
}

class _Obstacle {
  const _Obstacle(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;
}

class _Joystick extends StatefulWidget {
  const _Joystick({required this.onChanged, required this.onReleased});

  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  static const double _radius = 54;
  static const double _knobRadius = 22;

  void _update(Offset local) {
    var d = local - const Offset(_radius, _radius);
    if (d.distance > _radius - _knobRadius) {
      d = Offset.fromDirection(d.direction, _radius - _knobRadius);
    }
    setState(() => _knob = d);
    widget.onChanged(Offset(d.dx / (_radius - _knobRadius), d.dy / (_radius - _knobRadius)));
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: Container(
        width: _radius * 2,
        height: _radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x55151C28),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)],
        ),
        child: Center(
          child: Transform.translate(
            offset: _knob,
            child: Container(
              width: _knobRadius * 2,
              height: _knobRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.88),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
