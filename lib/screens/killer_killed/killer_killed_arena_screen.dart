import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/killer_killed_config.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/app_audio_service.dart';
import 'killer_killed_3d_world.dart';

class KillerKilledArenaScreen extends StatefulWidget {
  final int botCount;
  final KillerKilledAvatar playerAvatar;
  final String playerName;

  const KillerKilledArenaScreen({
    super.key,
    required this.botCount,
    required this.playerAvatar,
    this.playerName = 'محمد',
  });

  Color get playerColor => const Color(0xFF219587);

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
    required this.avatar,
    required this.x,
    required this.y,
    required this.angle,
  });

  final int id;
  final String name;
  final bool isHuman;
  final Color color;
  final KillerKilledAvatar avatar;

  double x;
  double y;
  double angle;
  double velocityX = 0;
  double velocityY = 0;
  double walkTime = 0;
  // Local movement intent used only by the 3D locomotion pose. Keeping it
  // separate from velocity lets the character animate forward, backward and
  // sideways differently while the gameplay/camera heading remains stable.
  double moveForward = 0;
  double moveStrafe = 0;
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
  final _random = math.Random();
  final List<_Fighter> _fighters = [];
  final KillerKilled3DWorld _world = KillerKilled3DWorld();

  Timer? _loop;
  Timer? _phaseTimer;
  _RoundPhase _phase = _RoundPhase.movement;
  double _remaining = KillerKilledConfig.movementSeconds.toDouble();
  Offset _stick = Offset.zero;
  Offset _smoothedStick = Offset.zero;
  double? _movementHeadingAnchor;
  bool _movementInputActive = false;

  double _cameraOrbit = 0;
  double _cameraPitch = 0;
  double _cameraZoom = .69;
  double _rightGestureStartZoom = .69;
  Offset _rightGestureLastFocal = Offset.zero;
  double _cameraDistance = 2.17;
  double _cameraOffsetX = .32;
  double _cameraOffsetY = .70;
  double _cameraYawOffset = 11 * math.pi / 180;

  // Camera follow is deliberately smoothed separately from gameplay movement.
  // This keeps the fighter centered without the old heavy/jumpy feel.
  double _cameraFollowX = .50;
  double _cameraFollowY = .75;
  double _cameraFollowAngle = -math.pi / 2;
  bool _cameraFollowInitialized = false;

  double _preRevealCameraOrbit = 0;
  double _preRevealCameraPitch = 0;
  bool _hasPreRevealCameraView = false;
  double _musicVolume = .15;
  double _effectsVolume = 1.0;
  bool _paused = false;
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

      _setLoading(.07, 'تحميل إعدادات اللعب');
      await _loadGameSettings();

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
        _world.addFighter(fighter.id, fighter.avatar, fighter.color);
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
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } catch (_) {
      // Desktop/web previews do not always implement orientation channels.
    }
  }

  Future<void> _leaveLandscapeMode() async {
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } catch (_) {
      // Keep browser/desktop testing safe when platform controls are absent.
    }
  }

  Future<void> _loadGameSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicVolume = prefs.getDouble('kk_music_volume') ?? .15;
      _effectsVolume = prefs.getDouble('kk_effects_volume') ?? 1.0;
      final cameraDefaultsV5 = prefs.getBool('kk_camera_defaults_v5') ?? false;
      if (!cameraDefaultsV5) {
        // One-time migration to the latest approved default third-person camera.
        // After this migration, anything the player saves remains persistent.
        _cameraDistance = 2.17;
        _cameraOffsetX = .32;
        _cameraOffsetY = .70;
        _cameraYawOffset = 11 * math.pi / 180;
        _cameraZoom = .69;
        await Future.wait([
          prefs.setDouble('kk_camera_distance', _cameraDistance),
          prefs.setDouble('kk_camera_offset_x', _cameraOffsetX),
          prefs.setDouble('kk_camera_offset_y', _cameraOffsetY),
          prefs.setDouble('kk_camera_yaw_offset', _cameraYawOffset),
          prefs.setDouble('kk_camera_zoom', _cameraZoom),
          prefs.setBool('kk_camera_defaults_v5', true),
        ]);
      } else {
        _cameraDistance = prefs.getDouble('kk_camera_distance') ?? 2.17;
        _cameraOffsetX = prefs.getDouble('kk_camera_offset_x') ?? .32;
        _cameraOffsetY = prefs.getDouble('kk_camera_offset_y') ?? .70;
        _cameraYawOffset = prefs.getDouble('kk_camera_yaw_offset') ?? 11 * math.pi / 180;
        _cameraZoom = prefs.getDouble('kk_camera_zoom') ?? .69;
      }
      await AppAudioService.setMusicVolume(_musicVolume);
      await AppAudioService.setEffectsVolume(_effectsVolume);
    } catch (_) {
      // Keep defaults if persistent storage is unavailable.
    }
  }

  Future<void> _saveGameSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setDouble('kk_music_volume', _musicVolume),
        prefs.setDouble('kk_effects_volume', _effectsVolume),
        prefs.setDouble('kk_camera_distance', _cameraDistance),
        prefs.setDouble('kk_camera_offset_x', _cameraOffsetX),
        prefs.setDouble('kk_camera_offset_y', _cameraOffsetY),
        prefs.setDouble('kk_camera_yaw_offset', _cameraYawOffset),
        prefs.setDouble('kk_camera_zoom', _cameraZoom),
      ]);
    } catch (_) {}
  }

  Future<void> _waitGameplay(Duration duration) async {
    var remainingMs = duration.inMilliseconds;
    while (mounted && remainingMs > 0 && _phase != _RoundPhase.finished) {
      const slice = 40;
      await Future<void>.delayed(const Duration(milliseconds: slice));
      if (!_paused) remainingMs -= slice;
    }
  }

  Future<void> _playDeathCueAfterImpact() async {
    await _waitGameplay(const Duration(milliseconds: 95));
    if (mounted) await AppAudioService.playDeath();
  }

  void _pauseGame() {
    if (_paused || !_gameStarted || _phase == _RoundPhase.finished) return;
    unawaited(AppAudioService.playClick());
    unawaited(AppAudioService.stopWalking());
    unawaited(AppAudioService.pauseKillerKilledMusic());
    setState(() {
      _paused = true;
      _stick = Offset.zero;
      _smoothedStick = Offset.zero;
      _movementInputActive = false;
      _movementHeadingAnchor = null;
    });
  }

  void _resumeGame() {
    if (!_paused) return;
    unawaited(AppAudioService.playClick());
    _lastFrame = DateTime.now();
    setState(() => _paused = false);
    unawaited(AppAudioService.resumeKillerKilledMusic());
  }

  Future<void> _exitPausedGame() async {
    unawaited(AppAudioService.playClick());
    await AppAudioService.stopArenaAudio();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showSettings() async {
    unawaited(AppAudioService.playClick());
    final oldMusic = _musicVolume;
    final oldEffects = _effectsVolume;
    final oldDistance = _cameraDistance;
    final oldOffsetX = _cameraOffsetX;
    final oldOffsetY = _cameraOffsetY;
    final oldYaw = _cameraYawOffset;
    final oldZoom = _cameraZoom;

    var saved = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            void refresh(VoidCallback change) {
              setState(change);
              setModalState(() {});
            }

            Widget stepper({
              required String title,
              required String value,
              required IconData minusIcon,
              required IconData plusIcon,
              required VoidCallback onMinus,
              required VoidCallback onPlus,
            }) {
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.055),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(value, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        unawaited(AppAudioService.playClick());
                        onMinus();
                      },
                      icon: Icon(minusIcon, size: 19),
                      style: IconButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: () {
                        unawaited(AppAudioService.playClick());
                        onPlus();
                      },
                      icon: Icon(plusIcon, size: 19),
                      style: IconButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: math.min(MediaQuery.sizeOf(dialogContext).width * .48, 470.0).toDouble(),
                  constraints: const BoxConstraints(maxHeight: 620),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xF20A0E15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 36)],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('إعدادات قاتل ومقتول', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                            ),
                            IconButton(
                              onPressed: () {
                                unawaited(AppAudioService.playClick());
                                Navigator.pop(dialogContext);
                              },
                              icon: const Icon(Icons.close_rounded, color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('الصوت', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        _settingsSlider(
                          title: 'موسيقى الخلفية',
                          value: _musicVolume,
                          percent: '${(_musicVolume * 100).round()}%',
                          onChanged: (value) {
                            refresh(() => _musicVolume = value);
                            unawaited(AppAudioService.setMusicVolume(value));
                          },
                        ),
                        _settingsSlider(
                          title: 'المؤثرات',
                          subtitle: 'الإطلاق • الإصابة • القتل • الخطوات',
                          value: _effectsVolume,
                          percent: '${(_effectsVolume * 100).round()}%',
                          onChanged: (value) {
                            refresh(() => _effectsVolume = value);
                            unawaited(AppAudioService.setEffectsVolume(value));
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('ضبط منظور الشخص الثالث', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                unawaited(AppAudioService.playClick());
                                refresh(() {
                                  _cameraDistance = 2.17;
                                  _cameraOffsetX = .32;
                                  _cameraOffsetY = .70;
                                  _cameraYawOffset = 11 * math.pi / 180;
                                  _cameraZoom = .69;
                                  _cameraPitch = 0;
                                  _cameraOrbit = 0;
                                });
                              },
                              icon: const Icon(Icons.restart_alt_rounded, size: 17),
                              label: const Text('إعادة ضبط'),
                            ),
                          ],
                        ),
                        const Text(
                          'اللعبة متوقفة لكن المعاينة خلف النافذة تتغير فوراً مع كل تعديل.',
                          style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                        ),
                        const SizedBox(height: 9),
                        stepper(
                          title: 'قرب / بعد الكاميرا',
                          value: _cameraDistance.toStringAsFixed(2),
                          minusIcon: Icons.zoom_in_rounded,
                          plusIcon: Icons.zoom_out_rounded,
                          onMinus: () => refresh(() => _cameraDistance = math.max(.22, _cameraDistance - .12)),
                          onPlus: () => refresh(() => _cameraDistance += .12),
                        ),
                        stepper(
                          title: 'موضع الكاميرا يمين / يسار',
                          value: _cameraOffsetX.toStringAsFixed(2),
                          minusIcon: Icons.arrow_left_rounded,
                          plusIcon: Icons.arrow_right_rounded,
                          onMinus: () => refresh(() => _cameraOffsetX -= .10),
                          onPlus: () => refresh(() => _cameraOffsetX += .10),
                        ),
                        stepper(
                          title: 'موضع الكاميرا أعلى / أسفل',
                          value: _cameraOffsetY.toStringAsFixed(2),
                          minusIcon: Icons.keyboard_arrow_down_rounded,
                          plusIcon: Icons.keyboard_arrow_up_rounded,
                          onMinus: () => refresh(() => _cameraOffsetY -= .10),
                          onPlus: () => refresh(() => _cameraOffsetY += .10),
                        ),
                        stepper(
                          title: 'دوران الكاميرا حول اللاعب',
                          value: '${(_cameraYawOffset * 180 / math.pi).round()}°',
                          minusIcon: Icons.rotate_left_rounded,
                          plusIcon: Icons.rotate_right_rounded,
                          onMinus: () => refresh(() => _cameraYawOffset = _normalizeAngle(_cameraYawOffset - .10)),
                          onPlus: () => refresh(() => _cameraYawOffset = _normalizeAngle(_cameraYawOffset + .10)),
                        ),
                        stepper(
                          title: 'التكبير اللحظي',
                          value: '${_cameraZoom.toStringAsFixed(2)}×',
                          minusIcon: Icons.remove_rounded,
                          plusIcon: Icons.add_rounded,
                          onMinus: () => refresh(() => _cameraZoom = math.max(.05, _cameraZoom / 1.12)),
                          onPlus: () => refresh(() => _cameraZoom *= 1.12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  unawaited(AppAudioService.playClick());
                                  Navigator.pop(dialogContext);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white12),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  saved = true;
                                  unawaited(AppAudioService.playClick());
                                  await _saveGameSettings();
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                },
                                icon: const Icon(Icons.save_rounded, size: 18),
                                label: const Text('حفظ'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: widget.playerColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!saved && mounted) {
      setState(() {
        _musicVolume = oldMusic;
        _effectsVolume = oldEffects;
        _cameraDistance = oldDistance;
        _cameraOffsetX = oldOffsetX;
        _cameraOffsetY = oldOffsetY;
        _cameraYawOffset = oldYaw;
        _cameraZoom = oldZoom;
      });
      unawaited(AppAudioService.setMusicVolume(oldMusic));
      unawaited(AppAudioService.setEffectsVolume(oldEffects));
    }
  }

  Widget _settingsSlider({
    required String title,
    String? subtitle,
    required double value,
    required String percent,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    if (subtitle != null)
                      Text(subtitle, style: const TextStyle(color: Colors.white30, fontSize: 9)),
                  ],
                ),
              ),
              Text(percent, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
            ],
          ),
          Slider(
            value: value.clamp(0.0, 1.0).toDouble(),
            min: 0,
            max: 1,
            onChanged: onChanged,
          ),
        ],
      ),
    );
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
          avatar: widget.playerAvatar,
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
          color: const Color(0xFF219587),
          avatar: KillerKilledAvatar.random(_random),
          x: .5 + math.cos(theta) * .30,
          y: .5 + math.sin(theta) * .25,
          angle: theta + math.pi,
        ),
      );
    }

    if (_world.ready) {
      for (final fighter in _fighters) {
        _world.setFighterAvatar(fighter.id, fighter.avatar);
      }
    }
    _cameraFollowInitialized = false;
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastFrame).inMicroseconds / 1000000).clamp(0.0, .05);
    _lastFrame = now;

    if (!_gameStarted || _paused) {
      return;
    }

    _time += dt;
    _world.updateEffects(dt);

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
        fighter.moveForward = 0;
        fighter.moveStrafe = 0;
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

    _updateCameraFollow(dt);
    _sync3D();
    setState(() {});
  }

  void _handleRightLookDrag(Offset delta) {
    if (!_gameStarted || _paused || _fighters.isEmpty || _phase == _RoundPhase.finished) return;

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
      if (_movementInputActive && _movementHeadingAnchor != null) {
        _movementHeadingAnchor = _normalizeAngle(_movementHeadingAnchor! + yawDelta);
      }
    } else {
      // During reveal/shooting/death, the fighter's aim stays frozen. Horizontal
      // dragging only inspects the scene with the camera.
      _cameraOrbit = _normalizeAngle(_cameraOrbit + yawDelta);
    }

    // Vertical dragging always controls camera elevation. No spring-back and no
    // automatic movement: the angle stays exactly where the player leaves it.
    _cameraPitch = (_cameraPitch + pitchDelta).clamp(-1.0, 1.10).toDouble();
  }


  void _handleRightScaleStart(ScaleStartDetails details) {
    _rightGestureStartZoom = _cameraZoom;
    _rightGestureLastFocal = details.localFocalPoint;
  }

  void _handleRightScaleUpdate(ScaleUpdateDetails details) {
    if (!_gameStarted || _paused || _fighters.isEmpty || _phase == _RoundPhase.finished) return;

    // One finger behaves exactly like the previous free-look surface.
    // With two fingers, the same gesture also supports a deliberately limited
    // pinch zoom so the camera never gets excessively close/far from gameplay.
    final delta = details.localFocalPoint - _rightGestureLastFocal;
    _rightGestureLastFocal = details.localFocalPoint;
    if (delta.distanceSquared > 0) {
      _handleRightLookDrag(delta);
    }

    if (details.pointerCount >= 2) {
      // No artificial maximum zoom. Repeated pinch gestures can keep moving
      // closer or farther; only a tiny positive floor prevents division by 0.
      _cameraZoom = math.max(.05, _rightGestureStartZoom * details.scale);
    }
  }


  void _handleMoveStickChanged(Offset value) {
    if (!_gameStarted || _paused || _fighters.isEmpty) return;
    _stick = value;
    final me = _fighters.first;
    final shouldWalk = _phase == _RoundPhase.movement && !me.eliminated && value.distance >= .04;

    // Lock the facing heading when the player first touches the movement stick.
    // Left/right then stay true side-steps and never rotate the character.
    if (shouldWalk && !_movementInputActive) {
      _movementInputActive = true;
      _movementHeadingAnchor = me.angle;
    }

    if (shouldWalk) {
      unawaited(AppAudioService.startWalking());
    } else {
      unawaited(AppAudioService.stopWalking());
    }
  }

  void _releaseMoveStick() {
    _stick = Offset.zero;
    _movementInputActive = false;
    // Keep the last movement anchor during the short deceleration tail; it is
    // replaced on the next touch and cleared once motion has fully settled.
    unawaited(AppAudioService.stopWalking());
  }

  void _moveHuman(double dt) {
    final me = _fighters.first;
    if (me.eliminated) return;

    // Smooth the control vector itself, not only the final velocity. This makes
    // the joystick and character feel fluid while keeping the response quick.
    final inputBlend = 1 - math.exp(-20.0 * dt);
    _smoothedStick = Offset(
      _smoothedStick.dx + (_stick.dx - _smoothedStick.dx) * inputBlend,
      _smoothedStick.dy + (_stick.dy - _smoothedStick.dy) * inputBlend,
    );

    final forwardInput = (-_smoothedStick.dy).clamp(-1.0, 1.0).toDouble();
    final strafeInput = (-_smoothedStick.dx).clamp(-1.0, 1.0).toDouble();
    me.moveForward = forwardInput;
    me.moveStrafe = strafeInput;

    final inputMagnitude = math.sqrt(forwardInput * forwardInput + strafeInput * strafeInput);
    final anchor = _movementHeadingAnchor ?? me.angle;
    final baseForwardX = math.cos(anchor);
    final baseForwardY = math.sin(anchor);
    final baseRightX = -math.sin(anchor);
    final baseRightY = math.cos(anchor);

    var desiredDirX = baseForwardX * forwardInput + baseRightX * strafeInput;
    var desiredDirY = baseForwardY * forwardInput + baseRightY * strafeInput;
    final desiredLength = math.sqrt(desiredDirX * desiredDirX + desiredDirY * desiredDirY);
    if (desiredLength > .0001) {
      desiredDirX /= desiredLength;
      desiredDirY /= desiredLength;
    }

    // Movement never rotates the fighter automatically. Forward/backward keep
    // the current facing direction, while left/right are true strafes. Turning
    // remains under the player's right-side look control only.
    final backingUp = forwardInput < -.10 && forwardInput.abs() >= strafeInput.abs() * .72;

    final maxSpeed = backingUp ? .225 : (strafeInput.abs() > forwardInput.abs() ? .285 : .315);
    var targetVX = desiredLength > .03 ? desiredDirX * maxSpeed * inputMagnitude.clamp(0.0, 1.0).toDouble() : 0.0;
    var targetVY = desiredLength > .03 ? desiredDirY * maxSpeed * inputMagnitude.clamp(0.0, 1.0).toDouble() : 0.0;

    // Fast but soft acceleration/deceleration: no snap on release, no heavy lag.
    final velocityBlend = 1 - math.exp(-18.0 * dt);
    me.velocityX += (targetVX - me.velocityX) * velocityBlend;
    me.velocityY += (targetVY - me.velocityY) * velocityBlend;
    if (_stick.distance < .01 && math.sqrt(me.velocityX * me.velocityX + me.velocityY * me.velocityY) < .006) {
      me.velocityX = 0;
      me.velocityY = 0;
      _smoothedStick = Offset.zero;
      if (!_movementInputActive) _movementHeadingAnchor = null;
      me.moveForward = 0;
      me.moveStrafe = 0;
    }

    me.x = (me.x + me.velocityX * dt).clamp(.055, .945);
    me.y = (me.y + me.velocityY * dt).clamp(.055, .945);
  }


  void _updateCameraFollow(double dt) {
    if (_fighters.isEmpty) return;
    final me = _fighters.first;
    if (!_cameraFollowInitialized) {
      _cameraFollowX = me.x;
      _cameraFollowY = me.y;
      _cameraFollowAngle = me.angle;
      _cameraFollowInitialized = true;
      return;
    }

    final positionBlend = 1 - math.exp(-26.0 * dt);
    final angleBlend = 1 - math.exp(-24.0 * dt);
    _cameraFollowX += (me.x - _cameraFollowX) * positionBlend;
    _cameraFollowY += (me.y - _cameraFollowY) * positionBlend;
    _cameraFollowAngle = _lerpAngle(_cameraFollowAngle, me.angle, angleBlend);
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
      bot.moveForward = 1;
      bot.moveStrafe = 0;
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

    // Any free-look used while everyone was revealed is temporary. Return to
    // the exact view the player had before reveal so the camera lands back on
    // the character instead of staying on the inspected side angle.
    if (!first && _hasPreRevealCameraView) {
      _cameraOrbit = _preRevealCameraOrbit;
      _cameraPitch = _preRevealCameraPitch;
      _hasPreRevealCameraView = false;
    }

    _phase = _RoundPhase.movement;
    _remaining = KillerKilledConfig.movementSeconds.toDouble();
    _activeShooterId = null;
    _stick = Offset.zero;
    _smoothedStick = Offset.zero;
    _movementInputActive = false;
    _movementHeadingAnchor = null;
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

    _preRevealCameraOrbit = _cameraOrbit;
    _preRevealCameraPitch = _cameraPitch;
    _hasPreRevealCameraView = true;

    _phase = _RoundPhase.reveal;
    _remaining = 0;
    _stick = Offset.zero;
    _centerMessage = 'انكشف الجميع • الآن الالتفاف بالكاميرا فقط';
    _messageOpacity = 1;
    _currentObstacle = _randomizeObstacle();
    for (final fighter in _fighters) {
      fighter.velocityX = 0;
      fighter.velocityY = 0;
      fighter.moveForward = 0;
      fighter.moveStrafe = 0;
    }
    if (_world.ready && _currentObstacle != null) {
      _world.setObstacle(visible: true, x: _currentObstacle!.x, y: _currentObstacle!.y);
    }
    _sync3D();
    _phaseTimer?.cancel();
    unawaited(_beginShootingAfterReveal());
  }

  Future<void> _beginShootingAfterReveal() async {
    await _waitGameplay(const Duration(milliseconds: 1050));
    if (!mounted || _phase != _RoundPhase.reveal) return;
    await _beginShooting();
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
      await _waitGameplay(const Duration(milliseconds: 620));
      if (!mounted) return;

      final victim = _rayHit(shooter);
      unawaited(AppAudioService.playPistolShot());
      shooter.shotFlash = .22;
      if (victim != null) {
        victim.hearts = math.max(0, victim.hearts - 1);
        victim.hitFlash = 1;
        unawaited(AppAudioService.playDamageHit());
        final lethalHit = victim.hearts == 0;
        if (_sceneReady) {
          _world.addBlood(
            victim.x,
            victim.y,
            shotAngle: shooter.angle,
            lethal: lethalHit,
          );
        }
        if (lethalHit) {
          victim.eliminated = true;
          // Let the flesh impact land first, then layer the kill cue a moment
          // later so a fatal hit sounds heavier instead of replacing the hit.
          unawaited(_playDeathCueAfterImpact());
        }
      }

      _sync3D();
      setState(() {});
      await _waitGameplay(const Duration(milliseconds: 720));

      if (_fighters.where((f) => !f.eliminated).length <= 1) {
        _finishGame();
        return;
      }
    }

    _activeShooterId = null;
    _round++;
    await _waitGameplay(const Duration(milliseconds: 520));
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
      final showLaser = !fighter.eliminated &&
          (fighter.isHuman || _phase != _RoundPhase.movement || spectating);
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
        forwardMotion: fighter.moveForward,
        strafeMotion: fighter.moveStrafe,
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
                    top: 88,
                    left: 24,
                    right: 24,
                    child: _buildCenterAnnouncement(),
                  ),
                if (_gameStarted && movement && !me.eliminated)
                  Positioned(
                    left: 32,
                    bottom: 32,
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
                if (_paused) Positioned.fill(child: _buildPauseOverlay()),
                if (_loadingVisible)
                  Positioned.fill(child: _buildLoadingOverlay()),
              ],
            );
          },
        ),
    );
  }

  Widget _buildCenterAnnouncement() {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _messageOpacity,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(begin: const Offset(0, -.28), end: Offset.zero).animate(animation);
              final scale = Tween<double>(begin: .72, end: 1).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: slide,
                  child: ScaleTransition(scale: scale, child: child),
                ),
              );
            },
            child: Text(
              _centerMessage,
              key: ValueKey(_centerMessage),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: .2,
                shadows: [
                  const Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
                  Shadow(color: widget.playerColor.withOpacity(.70), blurRadius: 20),
                  const Shadow(color: Colors.black87, blurRadius: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Material(
      color: Colors.black.withOpacity(.32),
      child: Center(
        child: Container(
          width: 330,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: const Color(0xF20B1018),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white12),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 38)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: widget.playerColor.withOpacity(.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.playerColor.withOpacity(.40)),
                ),
                child: Icon(Icons.pause_rounded, color: widget.playerColor, size: 30),
              ),
              const SizedBox(height: 12),
              const Text('اللعبة متوقفة مؤقتاً', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _pauseMenuButton(
                icon: Icons.play_arrow_rounded,
                label: 'استئناف',
                filled: true,
                onTap: _resumeGame,
              ),
              const SizedBox(height: 9),
              _pauseMenuButton(
                icon: Icons.tune_rounded,
                label: 'الإعدادات',
                onTap: _showSettings,
              ),
              const SizedBox(height: 9),
              _pauseMenuButton(
                icon: Icons.logout_rounded,
                label: 'الخروج من اللعبة',
                danger: true,
                onTap: _exitPausedGame,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
    bool danger = false,
  }) {
    final foreground = danger ? const Color(0xFFFF6574) : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: filled ? widget.playerColor : Colors.white.withOpacity(.07),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: filled ? widget.playerColor : Colors.white10),
          ),
        ),
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
          playerX: _cameraFollowInitialized ? _cameraFollowX : me.x,
          playerY: _cameraFollowInitialized ? _cameraFollowY : me.y,
          playerAngle: _cameraFollowInitialized ? _cameraFollowAngle : me.angle,
          cameraOrbit: _cameraOrbit,
          cameraPitch: _cameraPitch,
          cameraZoom: _cameraZoom,
          cameraDistance: _cameraDistance,
          cameraOffsetX: _cameraOffsetX,
          cameraOffsetY: _cameraOffsetY,
          cameraYawOffset: _cameraYawOffset,
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
        playerX: _cameraFollowInitialized ? _cameraFollowX : me.x,
        playerY: _cameraFollowInitialized ? _cameraFollowY : me.y,
        playerAngle: _cameraFollowInitialized ? _cameraFollowAngle : me.angle,
        cameraOrbit: _cameraOrbit,
        cameraPitch: _cameraPitch,
        cameraZoom: _cameraZoom,
        cameraDistance: _cameraDistance,
        cameraOffsetX: _cameraOffsetX,
        cameraOffsetY: _cameraOffsetY,
        cameraYawOffset: _cameraYawOffset,
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
          onTap: _pauseGame,
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
            child: const Icon(Icons.pause_rounded, color: Colors.white),
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
      d = Offset(0, raw.dy.clamp(-maxTravel, maxTravel).toDouble());
    } else if (widget.axis == Axis.horizontal) {
      d = Offset(raw.dx.clamp(-maxTravel, maxTravel).toDouble(), 0);
    } else {
      final length = raw.distance;
      d = length > maxTravel && length > 0 ? raw * (maxTravel / length) : raw;
    }

    final normalized = Offset(d.dx / maxTravel, d.dy / maxTravel);
    final magnitude = normalized.distance.clamp(0.0, 1.0);
    const deadZone = .055;
    Offset output = Offset.zero;
    if (magnitude > deadZone) {
      final direction = normalized / magnitude;
      final t = ((magnitude - deadZone) / (1 - deadZone)).clamp(0.0, 1.0);
      // Smoothstep gives fine low-speed control while still reaching full speed.
      final response = t * t * (3 - 2 * t);
      output = direction * response;
    }

    setState(() => _knob = d);
    widget.onChanged(output);
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
          child: TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(begin: Offset.zero, end: _knob),
            duration: const Duration(milliseconds: 42),
            curve: Curves.easeOutCubic,
            builder: (context, offset, child) => Transform.translate(
              offset: offset,
              child: child,
            ),
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
