import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/killer_killed_config.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/app_audio_service.dart';
import '../../widgets/live_performance_monitor.dart';
import '../guess_time/dev_image_picker_stub.dart'
    if (dart.library.io) '../guess_time/dev_image_picker_io.dart' as dev_image_picker;
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

  Color get playerColor => const Color(0xFF2F6DFF);

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

class _ArenaRay {
  const _ArenaRay(this.x, this.y, this.dx, this.dy);

  final double x;
  final double y;
  final double dx;
  final double dy;
}

class _KillerKilledArenaScreenState extends State<KillerKilledArenaScreen> {
  // Real 8-side movement boundary for the irregular center stage. Every side
  // has an independent center, length and angle so it can be fitted precisely
  // from developer mode. Gameplay collision and the visible debug lines use
  // the same side definitions.
  double _arenaCenterX = .50;
  double _arenaCenterY = .50;
  final List<Offset> _arenaSideCenters = <Offset>[
    const Offset(.500, .145),
    const Offset(1.030, .180),
    const Offset(1.260, .500),
    const Offset(1.040, .820),
    const Offset(.500, .855),
    const Offset(-.040, .820),
    const Offset(-.265, .500),
    const Offset(.030, .180),
  ];
  final List<double> _arenaSideLengths = <double>[
    .612, .462, .573, .447, .642, .454, .573, .469,
  ];
  final List<double> _arenaSideAnglesDeg = <double>[
    0.0, 9.0, 90.0, 170.8, 180.0, -171.0, -90.0, -9.0,
  ];
  double _arenaShotRadius = .58;
  // Visual-only laser reach. The playable floor stays radius .50, while the
  // beam may continue through empty air to the surrounding stage structure.
  static const double _arenaVisualLaserRadius = 1.00;

  final _random = math.Random();
  final List<_Fighter> _fighters = [];
  final KillerKilled3DWorld _world = KillerKilled3DWorld();

  Timer? _phaseTimer;
  _RoundPhase _phase = _RoundPhase.movement;
  double _remaining = KillerKilledConfig.movementSeconds.toDouble();
  Offset _stick = Offset.zero;
  Offset _smoothedStick = Offset.zero;
  double? _movementHeadingAnchor;
  bool _movementInputActive = false;

  // Windows desktop controls mirror the two mobile control zones:
  // WASD/arrow keys drive the left movement stick, while the mouse controls
  // the right-side look surface. Keeping this state here means keyboard input
  // feeds the exact same movement/animation path as the touch joystick.
  final FocusNode _desktopFocusNode = FocusNode(debugLabel: 'killer_killed_desktop');
  final Set<LogicalKeyboardKey> _desktopPressedKeys = <LogicalKeyboardKey>{};

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _isThermalOptimized =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  double _cameraOrbit = 0;
  double _cameraPitch = 0;
  double _cameraZoom = .69;
  double _rightGestureStartZoom = .69;
  Offset _rightGestureLastFocal = Offset.zero;
  double _cameraDistance = 2.17;
  double _cameraOffsetX = .32;
  double _cameraOffsetY = .70;
  double _cameraYawOffset = 11 * math.pi / 180;

  // Developer-only free-fly camera. These values are intentionally isolated
  // from every gameplay camera value and are never persisted to settings.
  bool _devFreeCameraEnabled = false;
  double _devFreeCameraX = 0.0;
  double _devFreeCameraY = 2.8;
  double _devFreeCameraZ = 7.0;
  double _devFreeCameraYaw = -math.pi / 2;
  double _devFreeCameraPitch = -.22;
  double _devFreeCameraSpeed = 8.0;
  final Set<LogicalKeyboardKey> _devFreeCameraPressedKeys = <LogicalKeyboardKey>{};

  // Developer-only frozen gameplay simulation. It uses the real gameplay
  // camera and movement presentation, but never advances timers, bots, shots
  // or eliminations. Entering it snapshots the current game and returning to
  // the developer lab restores that snapshot exactly.
  bool _devSimulationMode = false;
  bool _developerPanelVisible = true;
  _RoundPhase? _devSimulationSavedPhase;
  double? _devSimulationSavedRemaining;
  int? _devSimulationSavedActiveShooterId;
  _ArenaObstacle? _devSimulationSavedObstacle;
  String? _devSimulationSavedCenterMessage;
  double? _devSimulationSavedMessageOpacity;
  List<({
    double x,
    double y,
    double angle,
    double velocityX,
    double velocityY,
    double walkTime,
    double moveForward,
    double moveStrafe,
    int hearts,
    bool eliminated,
    double fall,
    double hitFlash,
    double shotFlash,
  })>? _devSimulationFighterSnapshots;

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
  final ValueNotifier<int> _uiFrame = ValueNotifier<int>(0);
  double _uiRefreshElapsed = 0;
  double _botUpdateElapsed = 0;
  double _effectsUpdateElapsed = 0;
  double _visualUpdateElapsed = 0;
  double _time = 0;
  bool _sceneReady = false;
  bool _gameStarted = false;
  bool _loadingVisible = true;
  double _loadingProgress = 0;
  String _loadingStage = 'تجهيز اللعبة…';
  DateTime? _loadingStartedAt;
  Object? _sceneError;
  _ArenaObstacle? _currentObstacle;

  bool _gunDevMode = false;
  double _gunDevX = 0;
  double _gunDevY = .018;
  double _gunDevZ = .087;
  double _gunDevRotX = 0;
  double _gunDevRotY = 0;
  double _gunDevRotZ = 0;

  // Full mobile-friendly developer laboratory.
  bool _developerPanelOpen = false;
  OverlayEntry? _developerOverlay;
  int _devSelectedFighter = 0;
  double _devLaserReachRadius = 3.000;
  double _devLaserHitRadius = 1.015;
  double _devLaserThickness = .55;
  double _devLaserGlow = 3.0;
  Color _devLaserColor = const Color(0xFFFF0000);
  bool _devHitboxesVisible = false;
  double _devHitboxForward = 1.0;
  double _devHitboxSide = 1.0;
  double _devHitboxVertical = 1.0;
  double _devHitboxRadius = 1.0;
  double _devTorsoForward = .683;
  double _devTorsoSide = 1.318;
  double _devTorsoVertical = 1.347;
  double _devHeadForward = .767;
  double _devHeadSide = .868;
  double _devHeadVertical = 1.0;
  double _devRightArmForward = 1.089;
  double _devRightArmSide = .713;
  double _devRightArmVertical = .838;
  double _devLeftArmForward = .643;
  double _devLeftArmSide = .838;
  double _devLeftArmVertical = 1.604;
  double _devTorsoOffsetX = 0.0;
  double _devTorsoOffsetY = .010;
  double _devTorsoOffsetZ = .020;
  double _devHeadOffsetX = -.310;
  double _devHeadOffsetY = .010;
  double _devHeadOffsetZ = .060;
  double _devRightArmOffsetX = -.114;
  double _devRightArmOffsetY = .500;
  double _devRightArmOffsetZ = .157;
  double _devLeftArmOffsetX = .029;
  double _devLeftArmOffsetY = -.493;
  double _devLeftArmOffsetZ = 0.0;
  double _devRightArmPitchDeg = 3.86;
  double _devRightArmYawDeg = 0.0;
  double _devLeftArmPitchDeg = 0.0;
  double _devLeftArmYawDeg = 0.0;
  bool _devKillPathVisible = true;
  double _devKillPathOffsetX = 0.000;
  double _devKillPathOffsetY = 0.003;
  double _devKillPathHeight = 1.375;
  double _devKillPathAngleDeg = 0.0;
  double _devKillPathLengthScale = 1.014;
  double _devKillPathThickness = 1.17;
  double _devWalkCycleSpeed = 0.368;
  double _devSupportArmWalkBlend = 1.250;
  double _devSupportArmX = 0.0;
  double _devSupportArmY = 0.0;
  double _devSupportArmZ = 0.0;
  double _devSupportForeArmBend = 0.0;
  double _devMovementSpeed = 1.0;

  // Full player-physics / locomotion developer tuning.
  double _devPlayerScale = 1.0;
  bool _devPhysicsWalkPreview = true;
  double _devWalkPhase1 = 1.0;
  double _devWalkPhase2 = .16;
  double _devWalkPhase3 = .06;
  double _devThighSwingDeg = 29.0;
  double _devKneeBendDeg = 20.0;
  double _devFootSwingDeg = 6.0;
  double _devShoulderSwingDeg = 7.0;
  double _devArmSwingDeg = 12.0;
  double _devHeadYawDeg = 2.8;
  double _devHeadPitchDeg = 1.4;
  double _devBodyLeanDeg = 2.0;
  double _devBodyBob = .016;
  double _devDeathOffsetX = 0.0;
  double _devDeathOffsetY = .080;
  double _devDeathOffsetZ = 0.0;
  double _devDeathScale = 1.0;
  double _devCameraZoomMin = .28;
  double _devCameraZoomMax = 2.20;
  double _devLookPitchMinDeg = -57.3;
  double _devLookPitchMaxDeg = 63.0;

  double _devBackgroundRotationSpeed = 0.0;
  double _devBackgroundScale = 1.0;

  // Developer controls for the new boss-room map. The map is intentionally
  // loaded at a small root scale while preserving all original geometry and
  // texture quality.
  double _devMapX = 0.0;
  double _devMapY = -.400;
  double _devMapZ = 0.0;
  double _devMapRotX = 0.0;
  double _devMapRotY = 0.0;
  double _devMapRotZ = 0.0;
  double _devMapScale = .255;
  double _devLightIntensity = 3.250;
  double _devLightDirectionX = -.520;
  double _devLightDirectionY = -1.060;
  double _devLightDirectionZ = -.360;
  double _devSceneExposure = 1.881;
  double _devLightR = 132.0;
  double _devLightG = 0.0;
  double _devLightB = 0.0;
  bool _devLightCastsShadow = true;
  double _devLobbyBackdropR = 7.0;
  double _devLobbyBackdropG = 0.0;
  double _devLobbyBackdropB = 0.0;
  double _devLobbyBackdropScale = 1.0;
  double _devLobbyBackdropX = 0.0;
  double _devLobbyBackdropY = 0.0;
  double _devLobbyBackdropZ = 0.0;
  int _devPanelSection = 0;
  bool _devArenaBoundaryVisible = true;
  KillerKilledBackgroundFit _devBackgroundFit = KillerKilledBackgroundFit.cover;
  Uint8List? _devBackgroundBytes;
  Uint8List? _defaultBackgroundBytes;

  Color _developerRgbColor(double r, double g, double b) => Color.fromARGB(
        255,
        r.round().clamp(0, 255).toInt(),
        g.round().clamp(0, 255).toInt(),
        b.round().clamp(0, 255).toInt(),
      );

  @override
  void initState() {
    super.initState();
    AppAudioService.suppressGlobalClick = true;
    _buildFighters();
    if (_isWindowsDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _desktopFocusNode.requestFocus();
      });
    }
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
      _applyGunDeveloperTransform();
      _applyDeveloperWorldTuning();
      // The boss-room map is decorative geometry only. The existing Milky Way
      // background remains independent and keeps all of its developer controls.
      _defaultBackgroundBytes = null;
      _devBackgroundBytes = null;
      _devBackgroundFit = KillerKilledBackgroundFit.cover;
      _world.restoreOriginalBackground();
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
    _phaseTimer?.cancel();
    _uiFrame.dispose();
    _desktopPressedKeys.clear();
    _desktopFocusNode.dispose();
    AppAudioService.suppressGlobalClick = false;
    unawaited(AppAudioService.stopArenaAudio());
    unawaited(_leaveLandscapeMode());
    _developerOverlay?.remove();
    _developerOverlay = null;
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
      _devMapX = prefs.getDouble('kk_dev_map_x') ?? 0.0;
      _devMapY = prefs.getDouble('kk_dev_map_y') ?? -.400;
      _devMapZ = prefs.getDouble('kk_dev_map_z') ?? 0.0;
      _devMapRotX = prefs.getDouble('kk_dev_map_rx') ?? 0.0;
      _devMapRotY = prefs.getDouble('kk_dev_map_ry') ?? 0.0;
      _devMapRotZ = prefs.getDouble('kk_dev_map_rz') ?? 0.0;
      _devMapScale = prefs.getDouble('kk_dev_map_scale_boss_room') ?? .255;
      _devLightIntensity = prefs.getDouble('kk_dev_light_intensity') ?? 3.250;
      _devLightDirectionX = prefs.getDouble('kk_dev_light_dx') ?? -.520;
      _devLightDirectionY = prefs.getDouble('kk_dev_light_dy') ?? -1.060;
      _devLightDirectionZ = prefs.getDouble('kk_dev_light_dz') ?? -.360;
      _devSceneExposure = prefs.getDouble('kk_dev_scene_exposure') ?? 1.881;
      _devLightR = prefs.getDouble('kk_dev_light_r') ?? 132.0;
      _devLightG = prefs.getDouble('kk_dev_light_g') ?? 0.0;
      _devLightB = prefs.getDouble('kk_dev_light_b') ?? 0.0;
      _devLightCastsShadow = prefs.getBool('kk_dev_light_shadow') ?? true;
      _devLobbyBackdropR = prefs.getDouble('kk_dev_lobby_backdrop_r') ?? 7.0;
      _devLobbyBackdropG = prefs.getDouble('kk_dev_lobby_backdrop_g') ?? 0.0;
      _devLobbyBackdropB = prefs.getDouble('kk_dev_lobby_backdrop_b') ?? 0.0;
      _devLobbyBackdropScale = prefs.getDouble('kk_dev_lobby_backdrop_scale') ?? 1.0;
      _devLobbyBackdropX = prefs.getDouble('kk_dev_lobby_backdrop_x') ?? 0.0;
      _devLobbyBackdropY = prefs.getDouble('kk_dev_lobby_backdrop_y') ?? 0.0;
      _devLobbyBackdropZ = prefs.getDouble('kk_dev_lobby_backdrop_z') ?? 0.0;
      for (var i = 0; i < 8; i++) {
        _arenaSideCenters[i] = Offset(
          prefs.getDouble('kk_arena_side_${i}_x') ?? _arenaSideCenters[i].dx,
          prefs.getDouble('kk_arena_side_${i}_y') ?? _arenaSideCenters[i].dy,
        );
        _arenaSideLengths[i] = prefs.getDouble('kk_arena_side_${i}_length') ?? _arenaSideLengths[i];
        _arenaSideAnglesDeg[i] = prefs.getDouble('kk_arena_side_${i}_angle') ?? _arenaSideAnglesDeg[i];
      }

      _arenaCenterX = prefs.getDouble('kk_arena_center_x') ?? .50;
      _arenaCenterY = prefs.getDouble('kk_arena_center_y') ?? .50;
      _arenaShotRadius = prefs.getDouble('kk_arena_shot_radius') ?? .58;
      _devArenaBoundaryVisible = prefs.getBool('kk_arena_boundary_visible') ?? true;

      _devPlayerScale = prefs.getDouble('kk_dev_player_scale') ?? 1.0;
      _devWalkPhase1 = prefs.getDouble('kk_dev_walk_phase1') ?? 1.0;
      _devWalkPhase2 = prefs.getDouble('kk_dev_walk_phase2') ?? .16;
      _devWalkPhase3 = prefs.getDouble('kk_dev_walk_phase3') ?? .06;
      _devThighSwingDeg = prefs.getDouble('kk_dev_thigh_swing_deg') ?? 29.0;
      _devKneeBendDeg = prefs.getDouble('kk_dev_knee_bend_deg') ?? 20.0;
      _devFootSwingDeg = prefs.getDouble('kk_dev_foot_swing_deg') ?? 6.0;
      _devShoulderSwingDeg = prefs.getDouble('kk_dev_shoulder_swing_deg') ?? 7.0;
      _devArmSwingDeg = prefs.getDouble('kk_dev_arm_swing_deg') ?? 12.0;
      _devHeadYawDeg = prefs.getDouble('kk_dev_head_yaw_deg') ?? 2.8;
      _devHeadPitchDeg = prefs.getDouble('kk_dev_head_pitch_deg') ?? 1.4;
      _devBodyLeanDeg = prefs.getDouble('kk_dev_body_lean_deg') ?? 2.0;
      _devBodyBob = prefs.getDouble('kk_dev_body_bob') ?? .016;
      _devDeathOffsetX = prefs.getDouble('kk_dev_death_offset_x') ?? 0.0;
      _devDeathOffsetY = prefs.getDouble('kk_dev_death_offset_y') ?? .080;
      _devDeathOffsetZ = prefs.getDouble('kk_dev_death_offset_z') ?? 0.0;
      _devDeathScale = prefs.getDouble('kk_dev_death_scale') ?? 1.0;
      _devCameraZoomMin = prefs.getDouble('kk_dev_camera_zoom_min') ?? .28;
      _devCameraZoomMax = prefs.getDouble('kk_dev_camera_zoom_max') ?? 2.20;
      _devLookPitchMinDeg = prefs.getDouble('kk_dev_look_pitch_min_deg') ?? -57.3;
      _devLookPitchMaxDeg = prefs.getDouble('kk_dev_look_pitch_max_deg') ?? 63.0;

      // One-time adoption of the approved boss-room geometry values from the
      // developer fit. After this migration they remain fully editable and
      // future launches load the user's saved values normally.
      final approvedBossRoomFitV2 =
          prefs.getBool('kk_boss_room_approved_fit_v2') ?? false;
      if (!approvedBossRoomFitV2) {
        _devMapScale = .255;
        _arenaCenterX = .500;
        _arenaCenterY = .500;
        const approvedCenters = <Offset>[
          Offset(.500, .145),
          Offset(1.030, .180),
          Offset(1.260, .500),
          Offset(1.040, .820),
          Offset(.500, .855),
          Offset(-.040, .820),
          Offset(-.265, .500),
          Offset(.030, .180),
        ];
        const approvedLengths = <double>[
          .612, .462, .573, .447, .642, .454, .573, .469,
        ];
        const approvedAngles = <double>[
          0.0, 9.0, 90.0, 170.8, 180.0, -171.0, -90.0, -9.0,
        ];
        for (var i = 0; i < 8; i++) {
          _arenaSideCenters[i] = approvedCenters[i];
          _arenaSideLengths[i] = approvedLengths[i];
          _arenaSideAnglesDeg[i] = approvedAngles[i];
        }
        await Future.wait([
          prefs.setDouble('kk_dev_map_scale_boss_room', _devMapScale),
          prefs.setDouble('kk_arena_center_x', _arenaCenterX),
          prefs.setDouble('kk_arena_center_y', _arenaCenterY),
          for (var i = 0; i < 8; i++) ...[
            prefs.setDouble('kk_arena_side_${i}_x', _arenaSideCenters[i].dx),
            prefs.setDouble('kk_arena_side_${i}_y', _arenaSideCenters[i].dy),
            prefs.setDouble('kk_arena_side_${i}_length', _arenaSideLengths[i]),
            prefs.setDouble('kk_arena_side_${i}_angle', _arenaSideAnglesDeg[i]),
          ],
          prefs.setBool('kk_boss_room_approved_fit_v2', true),
        ]);
      }
      // Apply the latest user-approved Boss Room placement/lighting once,
      // even on installs that already have older developer values persisted.
      final approvedBossRoomLookV3 =
          prefs.getBool('kk_boss_room_approved_look_v3') ?? false;
      if (!approvedBossRoomLookV3) {
        _devMapX = 0.0;
        _devMapY = -.400;
        _devMapZ = 0.0;
        _devMapRotX = 0.0;
        _devMapRotY = 0.0;
        _devMapRotZ = 0.0;
        _devMapScale = .255;
        _devLightIntensity = 3.250;
        _devSceneExposure = 1.881;
        _devLightDirectionX = -.520;
        _devLightDirectionY = -1.060;
        _devLightDirectionZ = -.360;
        _devLightR = 132.0;
        _devLightG = 0.0;
        _devLightB = 0.0;
        _devLightCastsShadow = true;
        _devLobbyBackdropR = 7.0;
        _devLobbyBackdropG = 0.0;
        _devLobbyBackdropB = 0.0;
        await Future.wait([
          prefs.setDouble('kk_dev_map_x', _devMapX),
          prefs.setDouble('kk_dev_map_y', _devMapY),
          prefs.setDouble('kk_dev_map_z', _devMapZ),
          prefs.setDouble('kk_dev_map_rx', _devMapRotX),
          prefs.setDouble('kk_dev_map_ry', _devMapRotY),
          prefs.setDouble('kk_dev_map_rz', _devMapRotZ),
          prefs.setDouble('kk_dev_map_scale_boss_room', _devMapScale),
          prefs.setDouble('kk_dev_light_intensity', _devLightIntensity),
          prefs.setDouble('kk_dev_scene_exposure', _devSceneExposure),
          prefs.setDouble('kk_dev_light_dx', _devLightDirectionX),
          prefs.setDouble('kk_dev_light_dy', _devLightDirectionY),
          prefs.setDouble('kk_dev_light_dz', _devLightDirectionZ),
          prefs.setDouble('kk_dev_light_r', _devLightR),
          prefs.setDouble('kk_dev_light_g', _devLightG),
          prefs.setDouble('kk_dev_light_b', _devLightB),
          prefs.setBool('kk_dev_light_shadow', _devLightCastsShadow),
          prefs.setDouble('kk_dev_lobby_backdrop_r', _devLobbyBackdropR),
          prefs.setDouble('kk_dev_lobby_backdrop_g', _devLobbyBackdropG),
          prefs.setDouble('kk_dev_lobby_backdrop_b', _devLobbyBackdropB),
          prefs.setBool('kk_boss_room_approved_look_v3', true),
        ]);
      }

      final restorePreVideoCamera =
          prefs.getBool('kk_camera_restore_pre_video_v1') ?? false;
      if (!restorePreVideoCamera) {
        // Restore ONLY the approved camera values that were used before the
        // temporary developer/video experiments. All other developer settings
        // remain untouched.
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
          prefs.setBool('kk_camera_restore_pre_video_v1', true),
        ]);
      } else {
        _cameraDistance = prefs.getDouble('kk_camera_distance') ?? 2.17;
        _cameraOffsetX = prefs.getDouble('kk_camera_offset_x') ?? .32;
        _cameraOffsetY = prefs.getDouble('kk_camera_offset_y') ?? .70;
        _cameraYawOffset = prefs.getDouble('kk_camera_yaw_offset') ?? 11 * math.pi / 180;
        _cameraZoom = math.max(.28, prefs.getDouble('kk_camera_zoom') ?? .69);
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
        prefs.setDouble('kk_dev_map_x', _devMapX),
        prefs.setDouble('kk_dev_map_y', _devMapY),
        prefs.setDouble('kk_dev_map_z', _devMapZ),
        prefs.setDouble('kk_dev_map_rx', _devMapRotX),
        prefs.setDouble('kk_dev_map_ry', _devMapRotY),
        prefs.setDouble('kk_dev_map_rz', _devMapRotZ),
        prefs.setDouble('kk_dev_map_scale_boss_room', _devMapScale),
        prefs.setDouble('kk_dev_light_intensity', _devLightIntensity),
        prefs.setDouble('kk_dev_light_dx', _devLightDirectionX),
        prefs.setDouble('kk_dev_light_dy', _devLightDirectionY),
        prefs.setDouble('kk_dev_light_dz', _devLightDirectionZ),
        prefs.setDouble('kk_dev_scene_exposure', _devSceneExposure),
        prefs.setDouble('kk_dev_light_r', _devLightR),
        prefs.setDouble('kk_dev_light_g', _devLightG),
        prefs.setDouble('kk_dev_light_b', _devLightB),
        prefs.setBool('kk_dev_light_shadow', _devLightCastsShadow),
        prefs.setDouble('kk_dev_lobby_backdrop_r', _devLobbyBackdropR),
        prefs.setDouble('kk_dev_lobby_backdrop_g', _devLobbyBackdropG),
        prefs.setDouble('kk_dev_lobby_backdrop_b', _devLobbyBackdropB),
        prefs.setDouble('kk_dev_lobby_backdrop_scale', _devLobbyBackdropScale),
        prefs.setDouble('kk_dev_lobby_backdrop_x', _devLobbyBackdropX),
        prefs.setDouble('kk_dev_lobby_backdrop_y', _devLobbyBackdropY),
        prefs.setDouble('kk_dev_lobby_backdrop_z', _devLobbyBackdropZ),
        prefs.setDouble('kk_arena_center_x', _arenaCenterX),
        prefs.setDouble('kk_arena_center_y', _arenaCenterY),
        prefs.setDouble('kk_arena_shot_radius', _arenaShotRadius),
        prefs.setBool('kk_arena_boundary_visible', _devArenaBoundaryVisible),
        prefs.setDouble('kk_dev_player_scale', _devPlayerScale),
        prefs.setDouble('kk_dev_walk_phase1', _devWalkPhase1),
        prefs.setDouble('kk_dev_walk_phase2', _devWalkPhase2),
        prefs.setDouble('kk_dev_walk_phase3', _devWalkPhase3),
        prefs.setDouble('kk_dev_thigh_swing_deg', _devThighSwingDeg),
        prefs.setDouble('kk_dev_knee_bend_deg', _devKneeBendDeg),
        prefs.setDouble('kk_dev_foot_swing_deg', _devFootSwingDeg),
        prefs.setDouble('kk_dev_shoulder_swing_deg', _devShoulderSwingDeg),
        prefs.setDouble('kk_dev_arm_swing_deg', _devArmSwingDeg),
        prefs.setDouble('kk_dev_head_yaw_deg', _devHeadYawDeg),
        prefs.setDouble('kk_dev_head_pitch_deg', _devHeadPitchDeg),
        prefs.setDouble('kk_dev_body_lean_deg', _devBodyLeanDeg),
        prefs.setDouble('kk_dev_body_bob', _devBodyBob),
        prefs.setDouble('kk_dev_death_offset_x', _devDeathOffsetX),
        prefs.setDouble('kk_dev_death_offset_y', _devDeathOffsetY),
        prefs.setDouble('kk_dev_death_offset_z', _devDeathOffsetZ),
        prefs.setDouble('kk_dev_death_scale', _devDeathScale),
        prefs.setDouble('kk_dev_camera_zoom_min', _devCameraZoomMin),
        prefs.setDouble('kk_dev_camera_zoom_max', _devCameraZoomMax),
        prefs.setDouble('kk_dev_look_pitch_min_deg', _devLookPitchMinDeg),
        prefs.setDouble('kk_dev_look_pitch_max_deg', _devLookPitchMaxDeg),
        for (var i = 0; i < 8; i++) ...[
          prefs.setDouble('kk_arena_side_${i}_x', _arenaSideCenters[i].dx),
          prefs.setDouble('kk_arena_side_${i}_y', _arenaSideCenters[i].dy),
          prefs.setDouble('kk_arena_side_${i}_length', _arenaSideLengths[i]),
          prefs.setDouble('kk_arena_side_${i}_angle', _arenaSideAnglesDeg[i]),
        ],
      ]);
    } catch (_) {}
  }

  Future<void> _waitGameplay(Duration duration) async {
    var remainingMs = duration.inMilliseconds;
    while (mounted && remainingMs > 0 && _phase != _RoundPhase.finished) {
      const slice = 40;
      await Future<void>.delayed(const Duration(milliseconds: slice));
      if (!_paused && !_devSimulationMode) remainingMs -= slice;
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
                          onMinus: () => refresh(() => _cameraZoom = math.max(.28, _cameraZoom / 1.12)),
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
          color: const Color(0xFF2F6DFF),
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

  void _onSceneTick(Duration elapsed, double deltaSeconds) {
    _tick(deltaSeconds);
  }

  void _tick(double deltaSeconds) {
    if (!mounted) return;
    final dt = deltaSeconds.clamp(0.0, .05).toDouble();

    if (_devFreeCameraEnabled && _gameStarted) {
      _updateDeveloperFreeCamera(dt);
    }

    if (!_gameStarted || _paused) {
      return;
    }

    _time += dt;
    if (_isThermalOptimized) {
      _effectsUpdateElapsed += dt;
      if (_effectsUpdateElapsed >= (1 / 30)) {
        final effectsDt = _effectsUpdateElapsed.clamp(0.0, .05).toDouble();
        _effectsUpdateElapsed = 0;
        _world.updateEffects(effectsDt);
      }
    } else {
      _world.updateEffects(dt);
    }

    if (_phase == _RoundPhase.movement) {
      if (_devSimulationMode) {
        // Frozen gameplay simulation: the human may walk/look with the real
        // controls, but the round timer, bots and combat never advance.
        _moveHuman(dt);
        _resolveFighterCollisions();
      } else {
        _remaining -= dt;
        _moveHuman(dt);
      }
      if (!_devSimulationMode && _isThermalOptimized) {
        // Bots are hidden during movement, so 30 Hz AI/collision stepping is
        // enough while the human and camera still update at display refresh.
        _botUpdateElapsed += dt;
        if (_botUpdateElapsed >= (1 / 30)) {
          final botDt = _botUpdateElapsed.clamp(0.0, .05).toDouble();
          _botUpdateElapsed = 0;
          _moveBots(botDt);
          _resolveFighterCollisions();
        }
      } else if (!_devSimulationMode) {
        _moveBots(dt);
        _resolveFighterCollisions();
      }
      if (!_devSimulationMode && _remaining <= 0) _finishMovement();
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

    // Keep the human player's movement transforms at full refresh. When all
    // fighters are revealed (or the player is spectating), 30 Hz skeleton
    // updates are enough because those poses are mostly idle/recoil/fall while
    // SceneView itself continues rendering/camera motion at display refresh.
    final spectating = _fighters.isNotEmpty && _fighters.first.eliminated;
    final fullRateVisuals = _phase == _RoundPhase.movement && !spectating;
    if (_isThermalOptimized && !fullRateVisuals) {
      _visualUpdateElapsed += dt;
      if (_visualUpdateElapsed >= (1 / 30)) {
        _visualUpdateElapsed %= (1 / 30);
        _sync3D();
      }
    } else {
      _visualUpdateElapsed = 0;
      _sync3D();
    }

    // The 3D scene still updates on every rendered frame, but the Flutter HUD
    // and screen-space labels do not need a full widget rebuild at 60 Hz.
    // HUD/labels need far fewer updates than the 3D renderer. iOS uses 20 Hz
    // here to cut widget/layout work further without affecting gameplay input.
    final uiStep = _isThermalOptimized ? (1 / 20) : (1 / 30);
    _uiRefreshElapsed += dt;
    if (_uiRefreshElapsed >= uiStep) {
      _uiRefreshElapsed %= uiStep;
      _uiFrame.value++;
    }
  }

  static final Set<LogicalKeyboardKey> _desktopMovementKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
  };

  KeyEventResult _handleDesktopKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isWindowsDesktop) return KeyEventResult.ignored;

    // Caps Lock is reserved for showing/hiding the developer panel while the
    // developer lab is active. It never changes gameplay or camera values.
    if (_developerPanelOpen && !_devSimulationMode &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.capsLock) {
      _developerPanelVisible = !_developerPanelVisible;
      _developerOverlay?.markNeedsBuild();
      if (!_developerPanelVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _desktopFocusNode.requestFocus();
        });
      }
      return KeyEventResult.handled;
    }

    if (_devFreeCameraEnabled) {
      final freeCameraKeys = <LogicalKeyboardKey>{
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.keyQ,
        LogicalKeyboardKey.keyE,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
      };
      if (!freeCameraKeys.contains(event.logicalKey)) {
        return KeyEventResult.ignored;
      }
      final released = event is KeyUpEvent;
      if (released) {
        _devFreeCameraPressedKeys.remove(event.logicalKey);
      } else {
        _devFreeCameraPressedKeys.add(event.logicalKey);
      }
      return KeyEventResult.handled;
    }

    if (_developerPanelOpen && event is KeyDownEvent) {
      const yawStep = 0.075;
      const pitchStep = 0.055;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() => _cameraOrbit = _normalizeAngle(_cameraOrbit - yawStep));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() => _cameraOrbit = _normalizeAngle(_cameraOrbit + yawStep));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() => _cameraPitch = (_cameraPitch - pitchStep).clamp(_devLookPitchMinDeg * math.pi / 180, _devLookPitchMaxDeg * math.pi / 180).toDouble());
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() => _cameraPitch = (_cameraPitch + pitchStep).clamp(_devLookPitchMinDeg * math.pi / 180, _devLookPitchMaxDeg * math.pi / 180).toDouble());
        return KeyEventResult.handled;
      }
    }

    if (!_desktopMovementKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isReleased = event is KeyUpEvent;
    final changed = isReleased
        ? _desktopPressedKeys.remove(key)
        : _desktopPressedKeys.add(key);
    if (changed) _applyDesktopMovementInput();
    return KeyEventResult.handled;
  }

  void _applyDesktopMovementInput() {
    if (!_isWindowsDesktop) return;

    final up = _desktopPressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _desktopPressedKeys.contains(LogicalKeyboardKey.arrowUp);
    final down = _desktopPressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _desktopPressedKeys.contains(LogicalKeyboardKey.arrowDown);
    final left = _desktopPressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _desktopPressedKeys.contains(LogicalKeyboardKey.arrowLeft);
    final right = _desktopPressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _desktopPressedKeys.contains(LogicalKeyboardKey.arrowRight);

    var dx = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    var dy = (down ? 1.0 : 0.0) - (up ? 1.0 : 0.0);
    final length = math.sqrt(dx * dx + dy * dy);
    if (length > 1) {
      dx /= length;
      dy /= length;
    }

    final value = Offset(dx, dy);
    if (value == Offset.zero) {
      _releaseMoveStick();
    } else {
      _handleMoveStickChanged(value);
    }
  }

  void _updateDeveloperFreeCamera(double dt) {
    if (!_isWindowsDesktop || _devFreeCameraPressedKeys.isEmpty) return;

    final forwardPressed =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.arrowUp);
    final backPressed =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.arrowDown);
    final leftPressed =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.arrowLeft);
    final rightPressed =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.arrowRight);
    final upPressed =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.keyE) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.space);
    final downPressed =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.keyQ) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.controlRight);
    final fast =
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        _devFreeCameraPressedKeys.contains(LogicalKeyboardKey.shiftRight);

    var forwardAmount = (forwardPressed ? 1.0 : 0.0) - (backPressed ? 1.0 : 0.0);
    var sideAmount = (rightPressed ? 1.0 : 0.0) - (leftPressed ? 1.0 : 0.0);
    var verticalAmount = (upPressed ? 1.0 : 0.0) - (downPressed ? 1.0 : 0.0);

    final horizontalLength = math.sqrt(forwardAmount * forwardAmount + sideAmount * sideAmount);
    if (horizontalLength > 1) {
      forwardAmount /= horizontalLength;
      sideAmount /= horizontalLength;
    }

    final cosPitch = math.cos(_devFreeCameraPitch);
    final forwardX = math.cos(_devFreeCameraYaw) * cosPitch;
    final forwardY = math.sin(_devFreeCameraPitch);
    final forwardZ = math.sin(_devFreeCameraYaw) * cosPitch;
    final rightX = -math.sin(_devFreeCameraYaw);
    final rightZ = math.cos(_devFreeCameraYaw);
    final speed = _devFreeCameraSpeed * (fast ? 3.0 : 1.0) * dt;

    _devFreeCameraX += (forwardX * forwardAmount + rightX * sideAmount) * speed;
    _devFreeCameraY += (forwardY * forwardAmount + verticalAmount) * speed;
    _devFreeCameraZ += (forwardZ * forwardAmount + rightZ * sideAmount) * speed;
  }

  void _clearDeveloperFreeCameraInput() {
    _devFreeCameraPressedKeys.clear();
  }

  void _clearDesktopMovement() {
    if (_desktopPressedKeys.isEmpty) return;
    _desktopPressedKeys.clear();
    _releaseMoveStick();
  }

  void _handleDesktopMouseWheel(PointerSignalEvent event) {
    if (!_isWindowsDesktop || event is! PointerScrollEvent) return;
    if (_devFreeCameraEnabled) {
      // In the developer free camera the wheel is a real dolly: scroll up
      // walks forward and scroll down walks backward along the view direction.
      final cosPitch = math.cos(_devFreeCameraPitch);
      final forwardX = math.cos(_devFreeCameraYaw) * cosPitch;
      final forwardY = math.sin(_devFreeCameraPitch);
      final forwardZ = math.sin(_devFreeCameraYaw) * cosPitch;
      final notches = (-event.scrollDelta.dy / 120.0).clamp(-8.0, 8.0).toDouble();
      final distance = notches * (_devFreeCameraSpeed * .18);
      _devFreeCameraX += forwardX * distance;
      _devFreeCameraY += forwardY * distance;
      _devFreeCameraZ += forwardZ * distance;
      return;
    }
    if (!_gameStarted || _paused || _fighters.isEmpty ||
        _phase == _RoundPhase.finished) {
      return;
    }

    // Wheel up = zoom in, wheel down = zoom out. The 3D camera itself still
    // applies its stage-interior safety clamp, so desktop zoom cannot escape
    // through the sci-fi shell.
    final factor = math.exp(-event.scrollDelta.dy * .0018);
    _cameraZoom = (_cameraZoom * factor).clamp(_devCameraZoomMin, _devCameraZoomMax).toDouble();
  }

  void _handleDesktopMouseHover(PointerHoverEvent event) {
    if (!_isWindowsDesktop || !_desktopFocusNode.hasFocus) return;

    // Free developer camera never reacts to plain mouse movement. Looking is
    // handled exclusively by _handleDeveloperFreeCameraPointerMove while the
    // primary mouse button is held and dragged.
    if (_devFreeCameraEnabled) return;

    // In developer mode the camera must move only while the mouse button is
    // held and dragged. Plain mouse movement never changes the inspection view.
    if (_developerPanelOpen) return;
    if (event.delta.distanceSquared <= 0) return;
    _handleRightLookDrag(event.delta);
  }

  void _handleDeveloperFreeCameraPointerMove(PointerMoveEvent event) {
    if (!_isWindowsDesktop || !_desktopFocusNode.hasFocus || !_devFreeCameraEnabled) {
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) return;
    if (event.delta.distanceSquared <= 0) return;

    const sensitivity = 0.0031;
    _devFreeCameraYaw =
        _normalizeAngle(_devFreeCameraYaw - event.delta.dx * sensitivity);
    _devFreeCameraPitch = (_devFreeCameraPitch - event.delta.dy * sensitivity)
        .clamp(-1.53, 1.53)
        .toDouble();
  }

  void _handleRightLookDrag(Offset delta) {
    if (!_gameStarted || (_paused && !_developerPanelOpen) || _fighters.isEmpty || _phase == _RoundPhase.finished) return;

    // Developer inspection is intentionally softer than gameplay look. It
    // orbits the camera only; it never rotates or moves the fighter.
    if (_developerPanelOpen) {
      const devYawSensitivity = 0.0032;
      const devPitchSensitivity = 0.0026;
      _cameraOrbit = _normalizeAngle(_cameraOrbit - delta.dx * devYawSensitivity);
      _cameraPitch = (_cameraPitch + delta.dy * devPitchSensitivity).clamp(_devLookPitchMinDeg * math.pi / 180, _devLookPitchMaxDeg * math.pi / 180).toDouble();
      return;
    }

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
    _cameraPitch = (_cameraPitch + pitchDelta).clamp(_devLookPitchMinDeg * math.pi / 180, _devLookPitchMaxDeg * math.pi / 180).toDouble();
  }


  void _handleRightScaleStart(ScaleStartDetails details) {
    if (_devFreeCameraEnabled) return;
    _rightGestureStartZoom = _cameraZoom;
    _rightGestureLastFocal = details.localFocalPoint;
  }

  void _handleRightScaleUpdate(ScaleUpdateDetails details) {
    if (_devFreeCameraEnabled) return;
    if (!_gameStarted || (_paused && !_developerPanelOpen) || _fighters.isEmpty || _phase == _RoundPhase.finished) return;

    // One finger behaves exactly like the previous free-look surface.
    // With two fingers, the same gesture also supports a deliberately limited
    // pinch zoom so the camera never gets excessively close/far from gameplay.
    final delta = details.localFocalPoint - _rightGestureLastFocal;
    _rightGestureLastFocal = details.localFocalPoint;
    if (delta.distanceSquared > 0) {
      _handleRightLookDrag(delta);
    }

    if (details.pointerCount >= 2) {
      // Zoom-out stops at the stage-safe limit. This still gives a wide view,
      // but can never pull the camera through the enlarged outer structure.
      _cameraZoom = (_rightGestureStartZoom * details.scale).clamp(_devCameraZoomMin, _devCameraZoomMax).toDouble();
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

    final maxSpeed = backingUp ? .450 : (strafeInput.abs() > forwardInput.abs() ? .570 : .630);
    var targetVX = desiredLength > .03 ? desiredDirX * maxSpeed * _devMovementSpeed * inputMagnitude.clamp(0.0, 1.0).toDouble() : 0.0;
    var targetVY = desiredLength > .03 ? desiredDirY * maxSpeed * _devMovementSpeed * inputMagnitude.clamp(0.0, 1.0).toDouble() : 0.0;

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

    me.x += me.velocityX * dt;
    me.y += me.velocityY * dt;
    _keepFighterInsideArena(me);
  }

  List<Offset> _arenaBoundaryVertices() {
    final endpoints = <(Offset, Offset)>[];
    for (var i = 0; i < 8; i++) {
      final center = _arenaSideCenters[i];
      final half = _arenaSideLengths[i].abs() * .5;
      final angle = _arenaSideAnglesDeg[i] * math.pi / 180.0;
      final delta = Offset(math.cos(angle) * half, math.sin(angle) * half);
      endpoints.add((center - delta, center + delta));
    }

    // Each corner is the midpoint of the closest endpoint pair of neighboring
    // sides. Therefore X/Y, length and angle of every side all affect the REAL
    // collision polygon, not only the developer preview.
    final vertices = <Offset>[];
    for (var i = 0; i < 8; i++) {
      final a = endpoints[i];
      final b = endpoints[(i + 1) % 8];
      final pairs = <(Offset, Offset)>[
        (a.$1, b.$1),
        (a.$1, b.$2),
        (a.$2, b.$1),
        (a.$2, b.$2),
      ];
      var best = pairs.first;
      var bestDistance = (best.$1 - best.$2).distanceSquared;
      for (final pair in pairs.skip(1)) {
        final distance = (pair.$1 - pair.$2).distanceSquared;
        if (distance < bestDistance) {
          best = pair;
          bestDistance = distance;
        }
      }
      vertices.add((best.$1 + best.$2) / 2.0);
    }
    return vertices;
  }

  bool _pointInsideArena(double x, double y, {double inset = 0.0}) {
    final point = Offset(x, y);
    final vertices = _arenaBoundaryVertices();
    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final a = vertices[i];
      final b = vertices[j];
      final crosses = ((a.dy > point.dy) != (b.dy > point.dy)) &&
          (point.dx <
              (b.dx - a.dx) * (point.dy - a.dy) /
                      ((b.dy - a.dy).abs() < .0000001 ? .0000001 : b.dy - a.dy) +
                  a.dx);
      if (crosses) inside = !inside;
    }
    if (!inside) return false;
    if (inset <= 0) return true;

    // Optional safety inset: reject points too close to any edge.
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      if (_distancePointToSegment(point, a, b) < inset) return false;
    }
    return true;
  }

  double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 < .00000001) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / length2).clamp(0.0, 1.0).toDouble();
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - closest).distance;
  }

  Offset _projectInsideArena(double x, double y, {double inset = .002}) {
    final point = Offset(x, y);
    if (_pointInsideArena(x, y, inset: inset)) return point;
    final vertices = _arenaBoundaryVertices();
    var bestPoint = vertices.first;
    var bestDistance2 = double.infinity;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final ab = b - a;
      final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final ap = point - a;
      final t = length2 < .00000001
          ? 0.0
          : ((ap.dx * ab.dx + ap.dy * ab.dy) / length2).clamp(0.0, 1.0).toDouble();
      final candidate = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      final d2 = (candidate - point).distanceSquared;
      if (d2 < bestDistance2) {
        bestDistance2 = d2;
        bestPoint = candidate;
      }
    }
    final towardCenter = Offset(_arenaCenterX, _arenaCenterY) - bestPoint;
    final len = towardCenter.distance;
    if (len > .000001) {
      bestPoint += towardCenter / len * inset;
    }
    return bestPoint;
  }

  void _keepFighterInsideArena(_Fighter fighter) {
    if (_pointInsideArena(fighter.x, fighter.y, inset: .002)) return;
    final before = Offset(fighter.x, fighter.y);
    final projected = _projectInsideArena(before.dx, before.dy);
    fighter.x = projected.dx;
    fighter.y = projected.dy;

    final correction = projected - before;
    final correctionLength = correction.distance;
    if (correctionLength > .000001) {
      final nx = correction.dx / correctionLength;
      final ny = correction.dy / correctionLength;
      final inwardVelocity = fighter.velocityX * nx + fighter.velocityY * ny;
      if (inwardVelocity < 0) {
        fighter.velocityX -= inwardVelocity * nx;
        fighter.velocityY -= inwardVelocity * ny;
      }
    }
  }

  bool _obstacleFitsArena(_ArenaObstacle obstacle) {
    const inset = .012;
    for (final sx in const [-1.0, 1.0]) {
      for (final sy in const [-1.0, 1.0]) {
        if (!_pointInsideArena(
          obstacle.x + sx * obstacle.halfW,
          obstacle.y + sy * obstacle.halfH,
          inset: inset,
        )) {
          return false;
        }
      }
    }
    return true;
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

      final speed = (.108 + _random.nextDouble() * .044) * _devMovementSpeed;
      bot.moveForward = 1;
      bot.moveStrafe = 0;
      bot.velocityX = math.cos(bot.angle) * speed;
      bot.velocityY = math.sin(bot.angle) * speed;

      var nx = bot.x + bot.velocityX * dt;
      var ny = bot.y + bot.velocityY * dt;
      if (!_pointInsideArena(nx, ny, inset: .002)) {
        final projected = _projectInsideArena(nx, ny);
        nx = projected.dx;
        ny = projected.dy;
        bot.angle += math.pi * (.72 + _random.nextDouble() * .18);
      }
      bot.x = nx;
      bot.y = ny;
      _keepFighterInsideArena(bot);
    }
  }

  void _resolveFighterCollisions() {
    final minDistance = .082 * _devPlayerScale;
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
          b.x += nx * overlap;
          b.y += ny * overlap;
          _keepFighterInsideArena(b);
          continue;
        }
        if (b.isHuman && !humanIsMoving) {
          a.x -= nx * overlap;
          a.y -= ny * overlap;
          _keepFighterInsideArena(a);
          continue;
        }

        final push = overlap / 2;
        a.x -= nx * push;
        a.y -= ny * push;
        b.x += nx * push;
        b.y += ny * push;
        _keepFighterInsideArena(a);
        _keepFighterInsideArena(b);
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
    _centerMessage = first
        ? (_isWindowsDesktop
            ? 'WASD أو الأسهم للحركة • حرّك الماوس في يمين الشاشة للنظر'
            : 'اليسار للحركة • اسحب يمين الشاشة للنظر والالتفاف')
        : 'الجولة $_round';
    _messageOpacity = 1;
    if (_isWindowsDesktop && _desktopPressedKeys.isNotEmpty) {
      _applyDesktopMovementInput();
    }
  }

  _ArenaObstacle _randomizeObstacle() {
    for (var attempt = 0; attempt < 90; attempt++) {
      final candidate = _ArenaObstacle(
        .08 + _random.nextDouble() * .84,
        .18 + _random.nextDouble() * .64,
        .024,
        .024,
      );
      if (!_obstacleFitsArena(candidate)) continue;
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
    return const _ArenaObstacle(.5, .5, .024, .024);
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

  _ArenaRay _aimRayFor(_Fighter shooter) {
    final exact = _world.fighterAimRay2D(shooter.id);
    final base = exact != null
        ? _ArenaRay(exact.x, exact.y, exact.dx, exact.dy)
        : _ArenaRay(
            shooter.x,
            shooter.y,
            math.cos(shooter.angle),
            math.sin(shooter.angle),
          );

    final angle = math.atan2(base.dy, base.dx) + _devKillPathAngleDeg * math.pi / 180;
    return _ArenaRay(
      base.x + _devKillPathOffsetX,
      base.y + _devKillPathOffsetY,
      math.cos(angle),
      math.sin(angle),
    );
  }

  void _syncDeveloperKillPath() {
    if (!_world.ready || !_developerPanelOpen || _fighters.isEmpty) {
      if (_world.ready) {
        _world.setDeveloperKillPath(
          visible: false,
          originX: 0,
          originY: 0,
          dirX: 1,
          dirY: 0,
          length: 0,
        );
      }
      return;
    }
    final shooter = _fighters[_devSelectedFighter.clamp(0, _fighters.length - 1).toInt()];
    final ray = _aimRayFor(shooter);
    final baseLimit = _rayLimitForRay(ray);
    final length = baseLimit * _devKillPathLengthScale;
    _world.setDeveloperKillPath(
      visible: _devKillPathVisible,
      originX: ray.x,
      originY: ray.y,
      dirX: ray.dx,
      dirY: ray.dy,
      length: length,
      thickness: _devKillPathThickness,
      height: _devKillPathHeight,
    );
  }

  _Fighter? _rayHit(_Fighter shooter) {
    final ray = _aimRayFor(shooter);
    final limit = _rayLimitForRay(ray);
    _Fighter? best;
    var bestT = double.infinity;

    // Hit testing uses the exact rendered muzzle ray, then keeps ONLY the
    // nearest body crossed by that ray. A second player behind the first can
    // never receive the same shot.
    for (final target in _fighters) {
      if (target.id == shooter.id || target.eliminated) continue;
      final t = _fighterRayIntersectionT(
        ray.x,
        ray.y,
        ray.dx,
        ray.dy,
        target,
      );
      if (t != null && t > .003 && t < limit && t < bestT) {
        bestT = t;
        best = target;
      }
    }
    return best;
  }

  double? _fighterRayIntersectionT(
    double ox,
    double oy,
    double dx,
    double dy,
    _Fighter target,
  ) {
    // If the muzzle starts inside an overlapping fighter, there is no visible
    // entry of the laser through that body. Ignore that target instead of
    // producing the old overlap/point-blank ghost kill.
    if (_pointInsideFighterHitbox(ox, oy, target)) return null;

    final fx = math.cos(target.angle);
    final fy = math.sin(target.angle);
    final sx = -fy;
    final sy = fx;

    double px(double forward, double side, [double ox = 0, double oy = 0]) =>
        target.x + _devPlayerScale * (fx * ((forward + ox) * _devHitboxForward) + sx * ((side + oy) * _devHitboxSide));
    double py(double forward, double side, [double ox = 0, double oy = 0]) =>
        target.y + _devPlayerScale * (fy * ((forward + ox) * _devHitboxForward) + sy * ((side + oy) * _devHitboxSide));

    var best = double.infinity;
    bool verticalHit(double center, double halfHeight, double verticalScale) {
      if (!_developerPanelOpen) return true;
      final scaledCenter = center * _devPlayerScale;
      final half = halfHeight * _devHitboxVertical.abs() * _devHitboxRadius.abs() * verticalScale.abs() * _devPlayerScale;
      return _devKillPathHeight >= scaledCenter - half && _devKillPathHeight <= scaledCenter + half;
    }

    void capsule(
      double f0,
      double s0,
      double f1,
      double s1,
      double radius, {
      double forwardScale = 1,
      double sideScale = 1,
      double radiusScale = 1,
      double verticalCenter = 1.0,
      double verticalHalfHeight = .5,
      double verticalScale = 1,
      double offsetX = 0,
      double offsetY = 0,
      double offsetZ = 0,
    }) {
      if (!verticalHit(verticalCenter + offsetZ, verticalHalfHeight, verticalScale)) return;
      final t = _rayCapsuleIntersection(
        ox,
        oy,
        dx,
        dy,
        px(f0 * forwardScale, s0 * sideScale, offsetX, offsetY),
        py(f0 * forwardScale, s0 * sideScale, offsetX, offsetY),
        px(f1 * forwardScale, s1 * sideScale, offsetX, offsetY),
        py(f1 * forwardScale, s1 * sideScale, offsetX, offsetY),
        radius * _devHitboxRadius * radiusScale.abs() * _devPlayerScale,
      );
      if (t != null && t >= 0 && t < best) best = t;
    }

    void circle(
      double forward,
      double side,
      double radius, {
      double forwardScale = 1,
      double sideScale = 1,
      double radiusScale = 1,
      double verticalCenter = 1.0,
      double verticalHalfHeight = .5,
      double verticalScale = 1,
      double offsetX = 0,
      double offsetY = 0,
      double offsetZ = 0,
    }) {
      if (!verticalHit(verticalCenter + offsetZ, verticalHalfHeight, verticalScale)) return;
      final t = _rayCircleIntersection(
        ox,
        oy,
        dx,
        dy,
        px(forward * forwardScale, side * sideScale, offsetX, offsetY),
        py(forward * forwardScale, side * sideScale, offsetX, offsetY),
        radius * _devHitboxRadius * radiusScale.abs() * _devPlayerScale,
      );
      if (t != null && t >= 0 && t < best) best = t;
    }

    // Torso/chest.
    capsule(
      -.018, 0, .024, 0, .024,
      forwardScale: _devTorsoForward,
      sideScale: _devTorsoSide,
      radiusScale: (_devTorsoForward.abs() + _devTorsoSide.abs()) * .5,
      verticalCenter: 1.02,
      verticalHalfHeight: .66,
      verticalScale: _devTorsoVertical,
      offsetX: _devTorsoOffsetX, offsetY: _devTorsoOffsetY, offsetZ: _devTorsoOffsetZ,
    );
    // Head/face footprint.
    circle(
      .038, 0, .0205,
      forwardScale: _devHeadForward,
      sideScale: _devHeadSide,
      radiusScale: (_devHeadForward.abs() + _devHeadSide.abs()) * .5,
      verticalCenter: 1.63,
      verticalHalfHeight: .33,
      verticalScale: _devHeadVertical,
      offsetX: _devHeadOffsetX, offsetY: _devHeadOffsetY, offsetZ: _devHeadOffsetZ,
    );

    // Weapon-side arm.
    capsule(
      .010, -.030, .083, -.024, .0088,
      forwardScale: _devRightArmForward,
      sideScale: _devRightArmSide,
      radiusScale: (_devRightArmForward.abs() + _devRightArmSide.abs()) * .5,
      verticalCenter: 1.16,
      verticalHalfHeight: .25,
      verticalScale: _devRightArmVertical,
      offsetX: _devRightArmOffsetX, offsetY: _devRightArmOffsetY, offsetZ: _devRightArmOffsetZ,
    );
    // Relaxed support arm.
    capsule(
      .008, .030, -.040, .038, .0090,
      forwardScale: _devLeftArmForward,
      sideScale: _devLeftArmSide,
      radiusScale: (_devLeftArmForward.abs() + _devLeftArmSide.abs()) * .5,
      verticalCenter: 1.05,
      verticalHalfHeight: .50,
      verticalScale: _devLeftArmVertical,
      offsetX: _devLeftArmOffsetX, offsetY: _devLeftArmOffsetY, offsetZ: _devLeftArmOffsetZ,
    );

    // Explicit hands. A shot that only clips the hand still deals the exact
    // same damage as a torso hit; this also prevents tiny visual gaps between
    // the arm capsule and the hand from producing a miss.
    circle(
      .083, -.024, .0125,
      forwardScale: _devRightArmForward,
      sideScale: _devRightArmSide,
      radiusScale: (_devRightArmForward.abs() + _devRightArmSide.abs()) * .5,
      verticalCenter: 1.16,
      verticalHalfHeight: .20,
      verticalScale: _devRightArmVertical,
      offsetX: _devRightArmOffsetX, offsetY: _devRightArmOffsetY, offsetZ: _devRightArmOffsetZ,
    );
    circle(
      -.040, .038, .0125,
      forwardScale: _devLeftArmForward,
      sideScale: _devLeftArmSide,
      radiusScale: (_devLeftArmForward.abs() + _devLeftArmSide.abs()) * .5,
      verticalCenter: 1.05,
      verticalHalfHeight: .24,
      verticalScale: _devLeftArmVertical,
      offsetX: _devLeftArmOffsetX, offsetY: _devLeftArmOffsetY, offsetZ: _devLeftArmOffsetZ,
    );

    // Two separate legs/feet. The small gap between them is intentionally not
    // hittable, so shots passing through empty space no longer cause damage.
    capsule(-.018, -.017, -.079, -.020, .0105, verticalCenter: .48, verticalHalfHeight: .78);
    capsule(-.018, .017, -.079, .020, .0105, verticalCenter: .48, verticalHalfHeight: .78);

    return best.isFinite ? best : null;
  }

  bool _pointInsideFighterHitbox(double x, double y, _Fighter target) {
    final fx = math.cos(target.angle);
    final fy = math.sin(target.angle);
    final sx = -fy;
    final sy = fx;
    final relX = x - target.x;
    final relY = y - target.y;
    final safeForwardScale = _devHitboxForward.abs() < .000001
        ? (_devHitboxForward.isNegative ? -.000001 : .000001)
        : _devHitboxForward;
    final safeSideScale = _devHitboxSide.abs() < .000001
        ? (_devHitboxSide.isNegative ? -.000001 : .000001)
        : _devHitboxSide;
    final safePlayerScale = _devPlayerScale.abs().clamp(.05, 5.0).toDouble();
    final forward = (relX * fx + relY * fy) / (safeForwardScale * safePlayerScale);
    final side = (relX * sx + relY * sy) / (safeSideScale * safePlayerScale);

    bool circle(
      double cf,
      double cs,
      double radius, {
      double forwardScale = 1,
      double sideScale = 1,
      double radiusScale = 1,
      double offsetX = 0,
      double offsetY = 0,
    }) {
      final dx = forward - (cf * forwardScale + offsetX);
      final dy = side - (cs * sideScale + offsetY);
      final r = radius * _devHitboxRadius * radiusScale.abs();
      return dx * dx + dy * dy <= r * r;
    }

    bool capsule(
      double f0,
      double s0,
      double f1,
      double s1,
      double radius, {
      double forwardScale = 1,
      double sideScale = 1,
      double radiusScale = 1,
      double offsetX = 0,
      double offsetY = 0,
    }) {
      final r = radius * _devHitboxRadius * radiusScale.abs();
      return _pointSegmentDistanceSquared(
            forward,
            side,
            f0 * forwardScale + offsetX,
            s0 * sideScale + offsetY,
            f1 * forwardScale + offsetX,
            s1 * sideScale + offsetY,
          ) <=
          r * r;
    }

    return capsule(
          -.018, 0, .024, 0, .024,
          forwardScale: _devTorsoForward,
          sideScale: _devTorsoSide,
          radiusScale: (_devTorsoForward.abs() + _devTorsoSide.abs()) * .5,
          offsetX: _devTorsoOffsetX, offsetY: _devTorsoOffsetY,
        ) ||
        circle(
          .038, 0, .0205,
          forwardScale: _devHeadForward,
          sideScale: _devHeadSide,
          radiusScale: (_devHeadForward.abs() + _devHeadSide.abs()) * .5,
          offsetX: _devHeadOffsetX, offsetY: _devHeadOffsetY,
        ) ||
        capsule(
          .010, -.030, .083, -.024, .0088,
          forwardScale: _devRightArmForward,
          sideScale: _devRightArmSide,
          radiusScale: (_devRightArmForward.abs() + _devRightArmSide.abs()) * .5,
          offsetX: _devRightArmOffsetX, offsetY: _devRightArmOffsetY,
        ) ||
        capsule(
          .008, .030, -.040, .038, .0090,
          forwardScale: _devLeftArmForward,
          sideScale: _devLeftArmSide,
          radiusScale: (_devLeftArmForward.abs() + _devLeftArmSide.abs()) * .5,
          offsetX: _devLeftArmOffsetX, offsetY: _devLeftArmOffsetY,
        ) ||
        circle(
          .083, -.024, .0125,
          forwardScale: _devRightArmForward,
          sideScale: _devRightArmSide,
          radiusScale: (_devRightArmForward.abs() + _devRightArmSide.abs()) * .5,
          offsetX: _devRightArmOffsetX, offsetY: _devRightArmOffsetY,
        ) ||
        circle(
          -.040, .038, .0125,
          forwardScale: _devLeftArmForward,
          sideScale: _devLeftArmSide,
          radiusScale: (_devLeftArmForward.abs() + _devLeftArmSide.abs()) * .5,
          offsetX: _devLeftArmOffsetX, offsetY: _devLeftArmOffsetY,
        ) ||
        capsule(-.018, -.017, -.079, -.020, .0105) ||
        capsule(-.018, .017, -.079, .020, .0105);
  }

  double _pointSegmentDistanceSquared(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final vx = bx - ax;
    final vy = by - ay;
    final lengthSq = vx * vx + vy * vy;
    if (lengthSq < .000000001) {
      final dx = px - ax;
      final dy = py - ay;
      return dx * dx + dy * dy;
    }
    final t = (((px - ax) * vx + (py - ay) * vy) / lengthSq)
        .clamp(0.0, 1.0)
        .toDouble();
    final qx = ax + vx * t;
    final qy = ay + vy * t;
    final dx = px - qx;
    final dy = py - qy;
    return dx * dx + dy * dy;
  }

  double? _rayCircleIntersection(
    double ox,
    double oy,
    double dx,
    double dy,
    double cx,
    double cy,
    double radius,
  ) {
    final mx = ox - cx;
    final my = oy - cy;
    final b = mx * dx + my * dy;
    final c = mx * mx + my * my - radius * radius;
    final disc = b * b - c;
    if (disc < 0) return null;
    final root = math.sqrt(disc);
    final t0 = -b - root;
    if (t0 >= 0) return t0;
    final t1 = -b + root;
    return t1 >= 0 ? t1 : null;
  }

  double? _rayCapsuleIntersection(
    double ox,
    double oy,
    double dx,
    double dy,
    double ax,
    double ay,
    double bx,
    double by,
    double radius,
  ) {
    final segX = bx - ax;
    final segY = by - ay;
    final length = math.sqrt(segX * segX + segY * segY);
    if (length < .000001) {
      return _rayCircleIntersection(ox, oy, dx, dy, ax, ay, radius);
    }

    final ux = segX / length;
    final uy = segY / length;
    final vx = -uy;
    final vy = ux;
    final relX = ox - ax;
    final relY = oy - ay;
    final localOx = relX * ux + relY * uy;
    final localOy = relX * vx + relY * vy;
    final localDx = dx * ux + dy * uy;
    final localDy = dx * vx + dy * vy;

    var best = double.infinity;
    final stripT = _rayRectIntersection(
      localOx,
      localOy,
      localDx,
      localDy,
      0,
      length,
      -radius,
      radius,
    );
    if (stripT != null && stripT >= 0) best = math.min(best, stripT);

    final startT = _rayCircleIntersection(
      localOx,
      localOy,
      localDx,
      localDy,
      0,
      0,
      radius,
    );
    if (startT != null && startT >= 0) best = math.min(best, startT);

    final endT = _rayCircleIntersection(
      localOx,
      localOy,
      localDx,
      localDy,
      length,
      0,
      radius,
    );
    if (endT != null && endT >= 0) best = math.min(best, endT);

    return best.isFinite ? best : null;
  }

  double _rayLimitT(_Fighter shooter) => _rayLimitForRay(_aimRayFor(shooter));

  double _visualRayLimitT(_Fighter shooter) =>
      _visualRayLimitForRay(_aimRayFor(shooter));

  double _visualRayLimitForRay(_ArenaRay ray) {
    // The red sight line is allowed to continue beyond the playable circle to
    // the outer sci-fi structure. Hard cover still blocks it so the beam never
    // visually passes through the grave/obstacle. This is visual only and does
    // NOT enlarge the gameplay hit range.
    final ox = ray.x - _arenaCenterX;
    final oy = ray.y - _arenaCenterY;
    final b = ox * ray.dx + oy * ray.dy;
    final c = ox * ox + oy * oy -
        _devLaserReachRadius * _devLaserReachRadius;
    final discriminant = math.max(0.0, b * b - c);
    var limit = -b + math.sqrt(discriminant);

    final obstacle = _currentObstacle;
    if (obstacle != null && _phase != _RoundPhase.movement) {
      final hit = _rayRectIntersection(
        ray.x,
        ray.y,
        ray.dx,
        ray.dy,
        obstacle.x - obstacle.halfW,
        obstacle.x + obstacle.halfW,
        obstacle.y - obstacle.halfH,
        obstacle.y + obstacle.halfH,
      );
      if (hit != null && hit > .006) limit = math.min(limit, hit);
    }
    return math.max(.001, limit);
  }

  double _rayLimitForRay(_ArenaRay ray) {
    // Stop the visible beam and the hit test using the SAME muzzle ray.
    final ox = ray.x - _arenaCenterX;
    final oy = ray.y - _arenaCenterY;
    final b = ox * ray.dx + oy * ray.dy;
    final c = ox * ox + oy * oy - _devLaserHitRadius * _devLaserHitRadius;
    final discriminant = math.max(0.0, b * b - c);
    var limit = -b + math.sqrt(discriminant);

    final obstacle = _currentObstacle;
    if (obstacle != null && _phase != _RoundPhase.movement) {
      final hit = _rayRectIntersection(
        ray.x,
        ray.y,
        ray.dx,
        ray.dy,
        obstacle.x - obstacle.halfW,
        obstacle.x + obstacle.halfW,
        obstacle.y - obstacle.halfH,
        obstacle.y + obstacle.halfH,
      );
      if (hit != null && hit > .006) limit = math.min(limit, hit);
    }
    return math.max(.001, limit);
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
      final active = fighter.id == _activeShooterId;
      final visible = _devSimulationMode || fighter.eliminated || spectating || !movement || fighter.isHuman;

      // During the hidden-movement phase bots still run gameplay logic, but
      // there is no reason to animate their skeletons or ray-test their lasers.
      // Toggling only visibility here avoids most per-frame 3D work for them.
      if (!visible) {
        _world.setFighterVisible(fighter.id, false);
        continue;
      }

      final realSpeed = math.sqrt(
        fighter.velocityX * fighter.velocityX +
            fighter.velocityY * fighter.velocityY,
      );
      final previewWalk = _developerPanelOpen &&
          _devPhysicsWalkPreview &&
          fighter.id == _devSelectedFighter &&
          fighter.fall <= 0;
      final speed = previewWalk ? .25 : realSpeed;
      final previewForward = previewWalk ? 1.0 : fighter.moveForward;
      final previewStrafe = previewWalk ? 0.0 : fighter.moveStrafe;
      final showLaser = !_devSimulationMode &&
          !fighter.eliminated &&
          (fighter.isHuman || _phase != _RoundPhase.movement || spectating);

      // Only perform the blocker/ray calculation when something is actually
      // drawn along that ray. Hidden lasers no longer pay this cost.
      var laserLength = .05;
      if (showLaser || fighter.shotFlash > 0) {
        final visualRayLength = _visualRayLimitT(fighter);
        laserLength = math.max(
          .05,
          visualRayLength * KillerKilled3DWorld.arenaWorldSize - .02,
        );
      }

      _world.updateFighter(
        id: fighter.id,
        x: fighter.x,
        y: fighter.y,
        angle: fighter.angle,
        walkTime: fighter.walkTime,
        speed: speed,
        forwardMotion: previewForward,
        strafeMotion: previewStrafe,
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

  double _nativeTopSafetyInset(BuildContext context) {
    final view = View.of(context);
    final logical = view.viewPadding.top / view.devicePixelRatio;
    return math.max(6.0, logical);
  }

  @override
  Widget build(BuildContext context) {
    final me = _fighters.first;

    return Focus(
      focusNode: _desktopFocusNode,
      autofocus: _isWindowsDesktop,
      onKeyEvent: _handleDesktopKeyEvent,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _clearDesktopMovement();
          _clearDeveloperFreeCameraInput();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Positioned.fill(child: _buildScene(me)),
                ValueListenableBuilder<int>(
                  valueListenable: _uiFrame,
                  builder: (context, _, __) {
                    final liveMe = _fighters.first;
                    final liveMovement = _phase == _RoundPhase.movement;
                    return Stack(
                      children: [
                if (_gameStarted && (_devFreeCameraEnabled || _phase != _RoundPhase.finished))
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    // Windows uses the mouse as the look control across the
                    // ENTIRE game window, not only the old right half. Touch
                    // devices keep the right-half gesture surface.
                    width: _isWindowsDesktop
                        ? constraints.maxWidth
                        : constraints.maxWidth * .50,
                    child: MouseRegion(
                      cursor: _isWindowsDesktop
                          ? SystemMouseCursors.basic
                          : MouseCursor.defer,
                      onHover: _handleDesktopMouseHover,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerSignal: _handleDesktopMouseWheel,
                        onPointerDown: (_) {
                          if (_isWindowsDesktop) _desktopFocusNode.requestFocus();
                        },
                        onPointerMove: _handleDeveloperFreeCameraPointerMove,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onScaleStart: _handleRightScaleStart,
                          onScaleUpdate: _handleRightScaleUpdate,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                if (_gameStarted && _sceneReady && !_devFreeCameraEnabled)
                  ..._buildLabels(viewSize, liveMe),
                if (_gameStarted)
                  Positioned(
                    top: _nativeTopSafetyInset(context) + 12,
                    left: 14,
                    right: 14,
                    child: _hud(),
                  ),
                if (_gameStarted && _sceneReady && !_devSimulationMode)
                  Positioned(right: 14, bottom: 18, child: _buildDeveloperLabButton()),
                if (_gameStarted && !_devSimulationMode)
                  const LivePerformanceMonitor(
                    label: 'استهلاك قاتل ومقتول',
                    topOffset: 62,
                    rightOffset: 10,
                  ),
                if (_gameStarted && _devSimulationMode)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: SafeArea(
                      top: false,
                      left: false,
                      child: FilledButton.icon(
                        onPressed: _exitDeveloperSimulation,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xE61A2332),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.developer_mode_rounded, size: 19),
                        label: const Text('العودة إلى وضع المطور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                if (_gameStarted && _messageOpacity > 0)
                  Positioned(
                    top: _nativeTopSafetyInset(context) + 88,
                    left: 24,
                    right: 24,
                    child: _buildCenterAnnouncement(),
                  ),
                if (_gameStarted && liveMovement && !liveMe.eliminated)
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
                if (_developerPanelOpen && _fighters.isNotEmpty)
                  Positioned(
                    right: 18,
                    top: 92,
                    child: IgnorePointer(
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xE6101722),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x66FFD43B)),
                          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))],
                        ),
                        child: Builder(builder: (_) {
                          final selected = _fighters[_devSelectedFighter.clamp(0, _fighters.length - 1).toInt()];
                          final victim = _rayHit(selected);
                          return Row(
                            children: [
                              Icon(victim == null ? Icons.close_rounded : Icons.gps_fixed_rounded, color: victim == null ? const Color(0xFFFF6B6B) : const Color(0xFFFFD43B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  victim == null ? '${selected.name}: لا يصيب أي لاعب' : '${selected.name} → ${victim.name}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                if (_paused && !_developerPanelOpen) Positioned.fill(child: _buildPauseOverlay()),
                      ],
                    );
                  },
                ),
                if (_loadingVisible)
                  Positioned.fill(child: _buildLoadingOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }

  void _applyDeveloperWorldTuning() {
    if (!_world.ready) return;
    _world
      ..setLaserStyle(
        color: _devLaserColor,
        thickness: _devLaserThickness,
        glow: _devLaserGlow,
      )
      ..setWalkAnimationTuning(
        cycleSpeed: _devWalkCycleSpeed,
        supportArmWalkBlend: _devSupportArmWalkBlend,
        supportArmOffsetX: _devSupportArmX * math.pi / 180,
        supportArmOffsetY: _devSupportArmY * math.pi / 180,
        supportArmOffsetZ: _devSupportArmZ * math.pi / 180,
        supportForeArmBend: _devSupportForeArmBend * math.pi / 180,
        rightArmPitch: _devRightArmPitchDeg * math.pi / 180,
        rightArmYaw: _devRightArmYawDeg * math.pi / 180,
        leftArmPitch: _devLeftArmPitchDeg * math.pi / 180,
        leftArmYaw: _devLeftArmYawDeg * math.pi / 180,
      )
      ..setPlayerPhysicsTuning(
        playerScale: _devPlayerScale,
        phase1: _devWalkPhase1,
        phase2: _devWalkPhase2,
        phase3: _devWalkPhase3,
        thighSwing: _devThighSwingDeg * math.pi / 180,
        kneeBend: _devKneeBendDeg * math.pi / 180,
        footSwing: _devFootSwingDeg * math.pi / 180,
        shoulderSwing: _devShoulderSwingDeg * math.pi / 180,
        armSwing: _devArmSwingDeg * math.pi / 180,
        headYaw: _devHeadYawDeg * math.pi / 180,
        headPitch: _devHeadPitchDeg * math.pi / 180,
        bodyLean: _devBodyLeanDeg * math.pi / 180,
        bodyBob: _devBodyBob,
        deathOffsetX: _devDeathOffsetX,
        deathOffsetY: _devDeathOffsetY,
        deathOffsetZ: _devDeathOffsetZ,
        deathScale: _devDeathScale,
      )
      ..setDebugHitboxes(
        enabled: _devHitboxesVisible,
        forwardScale: _devHitboxForward,
        sideScale: _devHitboxSide,
        verticalScale: _devHitboxVertical,
        radiusScale: _devHitboxRadius,
        torsoForward: _devTorsoForward,
        torsoSide: _devTorsoSide,
        torsoVertical: _devTorsoVertical,
        headForward: _devHeadForward,
        headSide: _devHeadSide,
        headVertical: _devHeadVertical,
        rightArmForward: _devRightArmForward,
        rightArmSide: _devRightArmSide,
        rightArmVertical: _devRightArmVertical,
        leftArmForward: _devLeftArmForward,
        leftArmSide: _devLeftArmSide,
        leftArmVertical: _devLeftArmVertical,
        torsoOffsetX: _devTorsoOffsetX,
        torsoOffsetY: _devTorsoOffsetY,
        torsoOffsetZ: _devTorsoOffsetZ,
        headOffsetX: _devHeadOffsetX,
        headOffsetY: _devHeadOffsetY,
        headOffsetZ: _devHeadOffsetZ,
        rightArmOffsetX: _devRightArmOffsetX,
        rightArmOffsetY: _devRightArmOffsetY,
        rightArmOffsetZ: _devRightArmOffsetZ,
        leftArmOffsetX: _devLeftArmOffsetX,
        leftArmOffsetY: _devLeftArmOffsetY,
        leftArmOffsetZ: _devLeftArmOffsetZ,
      )
      ..setBackgroundTuning(
        rotationSpeed: _devBackgroundRotationSpeed,
        scale: _devBackgroundScale,
      )
      ..setMapDeveloperTransform(
        x: _devMapX,
        y: _devMapY,
        z: _devMapZ,
        rotationX: _devMapRotX * math.pi / 180,
        rotationY: _devMapRotY * math.pi / 180,
        rotationZ: _devMapRotZ * math.pi / 180,
        scale: _devMapScale,
      )
      ..setLightingTuning(
        color: _developerRgbColor(_devLightR, _devLightG, _devLightB),
        intensity: _devLightIntensity,
        directionX: _devLightDirectionX,
        directionY: _devLightDirectionY,
        directionZ: _devLightDirectionZ,
        exposure: _devSceneExposure,
        castsShadow: _devLightCastsShadow,
      )
      ..setLobbyBackdropColor(
        _developerRgbColor(
          _devLobbyBackdropR,
          _devLobbyBackdropG,
          _devLobbyBackdropB,
        ),
      )
      ..setLobbyBackdropTransform(
        x: _devLobbyBackdropX,
        y: _devLobbyBackdropY,
        z: _devLobbyBackdropZ,
        scale: _devLobbyBackdropScale,
      )
      ..setArenaBoundaryPreview(
        visible: _devArenaBoundaryVisible,
        sideCenters: _arenaSideCenters,
        sideLengths: _arenaSideLengths,
        sideAnglesDegrees: _arenaSideAnglesDeg,
      );
    _syncDeveloperKillPath();
  }

  Widget _buildDeveloperLabButton() {
    return SafeArea(
      top: false,
      child: FilledButton.icon(
        onPressed: _openDeveloperLab,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xE61A2332),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: const BorderSide(color: Colors.white12),
        ),
        icon: const Icon(Icons.developer_mode_rounded, size: 18),
        label: const Text('المطور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Future<void> _openDeveloperLab() async {
    if (_developerPanelOpen || !_world.ready) return;
    final wasPaused = _paused;
    setState(() {
      _developerPanelOpen = true;
      _developerPanelVisible = true;
      _paused = true;
      _stick = Offset.zero;
      _smoothedStick = Offset.zero;
      _movementInputActive = false;
    });
    unawaited(AppAudioService.stopWalking());
    if (!wasPaused) unawaited(AppAudioService.pauseKillerKilledMusic());
    _applyDeveloperWorldTuning();

    late OverlayEntry overlayEntry;

    void closeDeveloperLab() {
      if (_developerOverlay == overlayEntry) {
        _developerOverlay = null;
      }
      if (overlayEntry.mounted) overlayEntry.remove();
      if (!mounted) return;
      setState(() {
        _developerPanelOpen = false;
        _developerPanelVisible = false;
        _paused = wasPaused;
      });
      _syncDeveloperKillPath();
      unawaited(_saveGameSettings());
      if (!wasPaused) unawaited(AppAudioService.resumeKillerKilledMusic());
    }

    overlayEntry = OverlayEntry(
      builder: (sheetContext) {
        if (!_developerPanelVisible) return const SizedBox.shrink();
        final size = MediaQuery.sizeOf(sheetContext);
        final sideWidth = math.min(size.width * .82, 430.0);
        return Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: sideWidth,
          child: Focus(
            autofocus: true,
            onKeyEvent: _handleDesktopKeyEvent,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
              right: false,
              child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void refresh(VoidCallback change, {bool sync = true}) {
              if (!mounted) return;
              setState(change);
              setSheetState(() {});
              _applyDeveloperWorldTuning();
              if (sync) _sync3D();
            }

            Widget sectionTitle(IconData icon, String title) => Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    children: [
                      Icon(icon, color: const Color(0xFF63B3FF), size: 19),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                );

            Widget slider({
              required String label,
              required double value,
              required double min,
              required double max,
              required ValueChanged<double> onChanged,
              String suffix = '',
              int divisions = 200,
            }) {
              final calculatedStep = ((max - min).abs() / math.max(1, divisions)).toDouble();
              final step = calculatedStep == 0 ? .1 : calculatedStep;

              void commit(double next) {
                // Developer values are deliberately unbounded. The old min/max
                // arguments now define only the +/- step size, not a hard limit.
                onChanged(next);
                setSheetState(() {});
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.045),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ناقص',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => commit(value - step),
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70, size: 21),
                    ),
                    SizedBox(
                      width: 105,
                      child: TextFormField(
                        key: ValueKey('dev_${label}_${value.toStringAsFixed(8)}'),
                        initialValue: value.toStringAsFixed(3),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          isDense: true,
                          suffixText: suffix,
                          suffixStyle: const TextStyle(color: Colors.white54, fontSize: 10),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onFieldSubmitted: (raw) {
                          final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
                          if (parsed != null && parsed.isFinite) commit(parsed);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'زائد',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => commit(value + step),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF63B3FF), size: 21),
                    ),
                  ],
                ),
              );
            }

            Widget colorSlider({
              required String label,
              required double value,
              required Color activeColor,
              required ValueChanged<double> onChanged,
            }) {
              final safe = value.clamp(0.0, 255.0).toDouble();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.045),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 68,
                      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(sheetContext).copyWith(
                          trackHeight: 6,
                          activeTrackColor: activeColor,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: activeColor,
                          overlayColor: activeColor.withOpacity(.16),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
                        ),
                        child: Slider(
                          value: safe,
                          min: 0,
                          max: 255,
                          divisions: 255,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        safe.round().toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget actionButton(String text, IconData icon, VoidCallback onTap, {Color? color}) =>
                FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: color ?? const Color(0xFF245FAE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(icon, size: 18),
                  label: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                );

            final safeIndex = _fighters.isEmpty
                ? 0
                : _devSelectedFighter.clamp(0, _fighters.length - 1).toInt();
            final selected = _fighters.isEmpty ? null : _fighters[safeIndex];
            final predictedVictim = selected == null ? null : _rayHit(selected);
            final laserArgb = _devLaserColor.toARGB32();
            final red = ((laserArgb >> 16) & 0xFF).toDouble();
            final green = ((laserArgb >> 8) & 0xFF).toDouble();
            final blue = (laserArgb & 0xFF).toDouble();

            return DraggableScrollableSheet(
              initialChildSize: 1,
              minChildSize: 1,
              maxChildSize: 1,
              expand: true,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xF20A0F17),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                            ),
                            const Spacer(),
                            const Text('مختبر قاتل ومقتول', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                            const Spacer(),
                            IconButton(
                              onPressed: closeDeveloperLab,
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          children: [
                            for (final entry in const <(int, IconData, String)>[
                              (0, Icons.gps_fixed_rounded, 'التصويب'),
                              (1, Icons.person_rounded, 'اللاعب'),
                              (2, Icons.map_rounded, 'الماب'),
                              (3, Icons.videocam_rounded, 'الكاميرا'),
                            ])
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 7),
                                child: ChoiceChip(
                                  selected: _devPanelSection == entry.$1,
                                  avatar: Icon(entry.$2, size: 16, color: _devPanelSection == entry.$1 ? Colors.white : Colors.white54),
                                  label: Text(entry.$3),
                                  onSelected: (_) {
                                    setSheetState(() => _devPanelSection = entry.$1);
                                    if (scrollController.hasClients) {
                                      scrollController.jumpTo(0);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _devFreeCameraEnabled
                                      ? const Color(0x22FFD43B)
                                      : const Color(0x14000000),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _devFreeCameraEnabled
                                        ? const Color(0x66FFD43B)
                                        : Colors.white12,
                                  ),
                                ),
                                child: SwitchListTile.adaptive(
                                  value: _devFreeCameraEnabled,
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: const Color(0xFFFFD43B),
                                  title: const Text(
                                    'الكاميرا الحرة للمطور',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                  subtitle: const Text(
                                    'خيار مستقل ولا يغيّر أي قيمة من كاميرا اللعب. WASD/الأسهم للحركة، اضغط زر الماوس الأيسر واسحب للنظر، E/Space صعود، Q/Ctrl نزول، Shift سرعة، وعجلة الماوس تمشي للأمام/الخلف.',
                                    style: TextStyle(color: Colors.white54, fontSize: 10.5, height: 1.45),
                                  ),
                                  onChanged: (enabled) {
                                    refresh(() {
                                      _devFreeCameraEnabled = enabled;
                                      _clearDeveloperFreeCameraInput();
                                    }, sync: false);
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              slider(
                                label: 'حساسية حركة الكاميرا الحرة',
                                value: _devFreeCameraSpeed,
                                min: 1.0,
                                max: 20.0,
                                divisions: 190,
                                onChanged: (v) => refresh(
                                  () => _devFreeCameraSpeed = v.clamp(.25, 40.0).toDouble(),
                                  sync: false,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FilledButton.icon(
                                onPressed: () => _enterDeveloperSimulation(overlayEntry),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C7A4B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.sports_esports_rounded, size: 19),
                                label: const Text(
                                  'تجربة محاكاة اللعب بدون لعب',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 6, bottom: 12),
                                child: Text(
                                  'يعرض جميع اللاعبين بكاميرا وتحكم اللعب الحقيقيين، لكن بدون عداد جولة أو حركة بوتات أو إطلاق أو إصابة أو إقصاء. زر الرجوع يظهر أسفل اليمين.',
                                  style: TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.45),
                                ),
                              ),
                              if (_devPanelSection == 0) ...[
                              sectionTitle(Icons.gps_fixed_rounded, 'التصويب — الليزر والإطلاق'),
                              slider(
                                label: 'طول الليزر المرئي',
                                value: _devLaserReachRadius,
                                min: .55,
                                max: 2.2,
                                onChanged: (v) => refresh(() => _devLaserReachRadius = v),
                              ),
                              slider(
                                label: 'مدى القتل',
                                value: _devLaserHitRadius,
                                min: .30,
                                max: 1.40,
                                onChanged: (v) => refresh(() => _devLaserHitRadius = v),
                              ),
                              slider(
                                label: 'سمك الليزر',
                                value: _devLaserThickness,
                                min: .25,
                                max: 4,
                                onChanged: (v) => refresh(() => _devLaserThickness = v),
                              ),
                              slider(
                                label: 'توهج الليزر',
                                value: _devLaserGlow,
                                min: 0,
                                max: 3,
                                onChanged: (v) => refresh(() => _devLaserGlow = v),
                              ),
                              const Divider(color: Colors.white12, height: 24),
                              sectionTitle(Icons.route_rounded, 'مسار القتل الحقيقي'),
                              SwitchListTile.adaptive(
                                value: _devKillPathVisible,
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: const Color(0xFFFFD43B),
                                title: const Text('إظهار مسار القتل الحقيقي', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                                subtitle: const Text('الأصفر = مسار القتل الحقيقي، الأحمر = الليزر المرئي.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                                onChanged: (v) => refresh(() => _devKillPathVisible = v),
                              ),
                              slider(label: 'إزاحة مسار القتل X', value: _devKillPathOffsetX, min: -.30, max: .30, onChanged: (v) => refresh(() => _devKillPathOffsetX = v)),
                              slider(label: 'إزاحة مسار القتل Y', value: _devKillPathOffsetY, min: -.30, max: .30, onChanged: (v) => refresh(() => _devKillPathOffsetY = v)),
                              slider(label: 'ارتفاع مسار القتل عن الأرض', value: _devKillPathHeight, min: -.50, max: 2.50, suffix: ' م', onChanged: (v) => refresh(() => _devKillPathHeight = v)),
                              slider(label: 'زاوية مسار القتل', value: _devKillPathAngleDeg, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devKillPathAngleDeg = v)),
                              slider(label: 'طول مسار القتل', value: _devKillPathLengthScale, min: .10, max: 3.0, onChanged: (v) => refresh(() => _devKillPathLengthScale = v)),
                              slider(label: 'سمك مسار القتل', value: _devKillPathThickness, min: .10, max: 8.0, onChanged: (v) => refresh(() => _devKillPathThickness = v)),
                              Container(
                                margin: const EdgeInsets.only(top: 4, bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0x22FFD43B),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: const Color(0x55FFD43B)),
                                ),
                                child: Text(
                                  selected == null
                                      ? 'لا يوجد لاعب محدد.'
                                      : predictedVictim == null
                                          ? 'مسار قتل ${selected.name}: لا يصيب أي لاعب حاليًا.'
                                          : 'مسار قتل ${selected.name} → ${predictedVictim.name}',
                                  style: const TextStyle(color: Color(0xFFFFE584), fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text('لون الليزر', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              slider(
                                label: 'R',
                                value: red,
                                min: 0,
                                max: 255,
                                divisions: 255,
                                onChanged: (v) => refresh(() {
                                  _devLaserColor = Color.fromARGB(255, v.clamp(0, 255).round(), green.clamp(0, 255).round(), blue.clamp(0, 255).round());
                                }),
                              ),
                              slider(
                                label: 'G',
                                value: green,
                                min: 0,
                                max: 255,
                                divisions: 255,
                                onChanged: (v) => refresh(() {
                                  _devLaserColor = Color.fromARGB(255, red.clamp(0, 255).round(), v.clamp(0, 255).round(), blue.clamp(0, 255).round());
                                }),
                              ),
                              slider(
                                label: 'B',
                                value: blue,
                                min: 0,
                                max: 255,
                                divisions: 255,
                                onChanged: (v) => refresh(() {
                                  _devLaserColor = Color.fromARGB(255, red.clamp(0, 255).round(), green.clamp(0, 255).round(), v.clamp(0, 255).round());
                                }),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final color in const [
                                    Color(0xFFFF3044),
                                    Color(0xFF3FA9FF),
                                    Color(0xFF37FF87),
                                    Color(0xFFFFD33D),
                                    Color(0xFFD45CFF),
                                  ])
                                    InkWell(
                                      onTap: () => refresh(() => _devLaserColor = color),
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: color,
                                          border: Border.all(color: Colors.white54, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  actionButton('تجربة إطلاق', Icons.gps_fixed_rounded, () => unawaited(_developerTestShot()), color: const Color(0xFFB53A3A)),
                                  actionButton('إرجاع الليزر', Icons.restart_alt_rounded, () {
                                    refresh(() {
                                      _devLaserReachRadius = 3.000;
                                      _devLaserHitRadius = 1.015;
                                      _devLaserThickness = .55;
                                      _devLaserGlow = 3.0;
                                      _devLaserColor = const Color(0xFFFF0000);
                                    });
                                  }),
                                ],
                              ),

                              const Divider(color: Colors.white12, height: 28),
                              ],
                              if (_devPanelSection == 1) ...[
                              sectionTitle(Icons.person_rounded, 'اللاعب — Hitbox عام'),
                              SwitchListTile.adaptive(
                                value: _devHitboxesVisible,
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: const Color(0xFF62FF8B),
                                title: const Text('إظهار Hitbox اللاعبين والليزر', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                                onChanged: (v) => refresh(() => _devHitboxesVisible = v),
                              ),
                              slider(
                                label: 'الحجم أمام / خلف',
                                value: _devHitboxForward,
                                min: .45,
                                max: 2.2,
                                onChanged: (v) => refresh(() => _devHitboxForward = v),
                              ),
                              slider(
                                label: 'الحجم يمين / يسار',
                                value: _devHitboxSide,
                                min: .45,
                                max: 2.2,
                                onChanged: (v) => refresh(() => _devHitboxSide = v),
                              ),
                              slider(
                                label: 'الارتفاع فوق / تحت',
                                value: _devHitboxVertical,
                                min: .45,
                                max: 2.2,
                                onChanged: (v) => refresh(() => _devHitboxVertical = v),
                              ),
                              slider(
                                label: 'سماكة مناطق الإصابة',
                                value: _devHitboxRadius,
                                min: .45,
                                max: 2.2,
                                onChanged: (v) => refresh(() => _devHitboxRadius = v),
                              ),
                              const SizedBox(height: 8),
                              sectionTitle(Icons.person_rounded, 'اللاعب — Hitbox مفصل'),
                              const Text('الجسم', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'الجسم أمام/خلف', value: _devTorsoForward, min: .10, max: 3, onChanged: (v) => refresh(() => _devTorsoForward = v)),
                              slider(label: 'الجسم يمين/يسار', value: _devTorsoSide, min: .10, max: 3, onChanged: (v) => refresh(() => _devTorsoSide = v)),
                              slider(label: 'الجسم فوق/تحت', value: _devTorsoVertical, min: .10, max: 3, onChanged: (v) => refresh(() => _devTorsoVertical = v)),
                              slider(label: 'إزاحة الجسم X', value: _devTorsoOffsetX, min: -1, max: 1, onChanged: (v) => refresh(() => _devTorsoOffsetX = v)),
                              slider(label: 'إزاحة الجسم Y', value: _devTorsoOffsetY, min: -1, max: 1, onChanged: (v) => refresh(() => _devTorsoOffsetY = v)),
                              slider(label: 'إزاحة الجسم Z', value: _devTorsoOffsetZ, min: -2, max: 2, onChanged: (v) => refresh(() => _devTorsoOffsetZ = v)),
                              const Text('الرأس', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'الرأس أمام/خلف', value: _devHeadForward, min: .10, max: 3, onChanged: (v) => refresh(() => _devHeadForward = v)),
                              slider(label: 'الرأس يمين/يسار', value: _devHeadSide, min: .10, max: 3, onChanged: (v) => refresh(() => _devHeadSide = v)),
                              slider(label: 'الرأس فوق/تحت', value: _devHeadVertical, min: .10, max: 3, onChanged: (v) => refresh(() => _devHeadVertical = v)),
                              slider(label: 'إزاحة الرأس X', value: _devHeadOffsetX, min: -1, max: 1, onChanged: (v) => refresh(() => _devHeadOffsetX = v)),
                              slider(label: 'إزاحة الرأس Y', value: _devHeadOffsetY, min: -1, max: 1, onChanged: (v) => refresh(() => _devHeadOffsetY = v)),
                              slider(label: 'إزاحة الرأس Z', value: _devHeadOffsetZ, min: -2, max: 2, onChanged: (v) => refresh(() => _devHeadOffsetZ = v)),
                              const Text('اليد اليمنى', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'اليمنى طول', value: _devRightArmForward, min: .10, max: 4, onChanged: (v) => refresh(() => _devRightArmForward = v)),
                              slider(label: 'اليمنى عرض', value: _devRightArmSide, min: .10, max: 4, onChanged: (v) => refresh(() => _devRightArmSide = v)),
                              slider(label: 'اليمنى ارتفاع', value: _devRightArmVertical, min: .10, max: 4, onChanged: (v) => refresh(() => _devRightArmVertical = v)),
                              slider(label: 'إزاحة اليد اليمنى X', value: _devRightArmOffsetX, min: -1, max: 1, onChanged: (v) => refresh(() => _devRightArmOffsetX = v)),
                              slider(label: 'إزاحة اليد اليمنى Y', value: _devRightArmOffsetY, min: -1, max: 1, onChanged: (v) => refresh(() => _devRightArmOffsetY = v)),
                              slider(label: 'إزاحة اليد اليمنى Z', value: _devRightArmOffsetZ, min: -2, max: 2, onChanged: (v) => refresh(() => _devRightArmOffsetZ = v)),
                              slider(label: 'زاوية اليد اليمنى فوق/تحت', value: _devRightArmPitchDeg, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devRightArmPitchDeg = v)),
                              slider(label: 'زاوية اليد اليمنى يمين/يسار', value: _devRightArmYawDeg, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devRightArmYawDeg = v)),
                              const Text('اليد اليسرى', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'اليسرى طول', value: _devLeftArmForward, min: .10, max: 4, onChanged: (v) => refresh(() => _devLeftArmForward = v)),
                              slider(label: 'اليسرى عرض', value: _devLeftArmSide, min: .10, max: 4, onChanged: (v) => refresh(() => _devLeftArmSide = v)),
                              slider(label: 'اليسرى ارتفاع', value: _devLeftArmVertical, min: .10, max: 4, onChanged: (v) => refresh(() => _devLeftArmVertical = v)),
                              slider(label: 'إزاحة اليد اليسرى X', value: _devLeftArmOffsetX, min: -1, max: 1, onChanged: (v) => refresh(() => _devLeftArmOffsetX = v)),
                              slider(label: 'إزاحة اليد اليسرى Y', value: _devLeftArmOffsetY, min: -1, max: 1, onChanged: (v) => refresh(() => _devLeftArmOffsetY = v)),
                              slider(label: 'إزاحة اليد اليسرى Z', value: _devLeftArmOffsetZ, min: -2, max: 2, onChanged: (v) => refresh(() => _devLeftArmOffsetZ = v)),
                              slider(label: 'زاوية اليد اليسرى فوق/تحت', value: _devLeftArmPitchDeg, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devLeftArmPitchDeg = v)),
                              slider(label: 'زاوية اليد اليسرى يمين/يسار', value: _devLeftArmYawDeg, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devLeftArmYawDeg = v)),

                              const Divider(color: Colors.white12, height: 28),
                              sectionTitle(Icons.person_rounded, 'اللاعب — الشخصية والحركة'),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (var i = 0; i < _fighters.length; i++)
                                      Padding(
                                        padding: const EdgeInsetsDirectional.only(end: 7),
                                        child: ChoiceChip(
                                          selected: safeIndex == i,
                                          label: Text(_fighters[i].name),
                                          onSelected: (_) => refresh(() => _devSelectedFighter = i),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (selected != null) ...[
                                const SizedBox(height: 8),
                                slider(
                                  label: 'مكان X',
                                  value: selected.x,
                                  min: .03,
                                  max: .97,
                                  onChanged: (v) {
                                    selected.x = v;
                                    refresh(() {}, sync: true);
                                  },
                                ),
                                slider(
                                  label: 'مكان Y',
                                  value: selected.y,
                                  min: .03,
                                  max: .97,
                                  onChanged: (v) {
                                    selected.y = v;
                                    refresh(() {}, sync: true);
                                  },
                                ),
                                slider(
                                  label: 'دوران الشخصية',
                                  value: selected.angle * 180 / math.pi,
                                  min: -180,
                                  max: 180,
                                  suffix: '°',
                                  onChanged: (v) {
                                    selected.angle = v * math.pi / 180;
                                    refresh(() {}, sync: true);
                                  },
                                ),
                              ],
                              const Divider(color: Colors.white12, height: 24),
                              sectionTitle(Icons.accessibility_new_rounded, 'فيزيائية اللاعب — الجسم والحركة'),
                              const Text(
                                'المعاينة فورية على اللاعب داخل الماب. حجم اللاعب يغيّر الجسم والمسدس والـAim والليزر والـHitboxes كوحدة واحدة.',
                                style: TextStyle(color: Colors.white38, fontSize: 10.5),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                value: _devPhysicsWalkPreview,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('معاينة المشي الحية', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                subtitle: const Text('يشغّل دورة المشي على اللاعب المحدد في مكانه حتى تشاهد أي تعديل فوراً.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                onChanged: (v) => refresh(() => _devPhysicsWalkPreview = v),
                              ),
                              slider(
                                label: 'حجم اللاعب الكامل',
                                value: _devPlayerScale,
                                min: .35,
                                max: 1.60,
                                onChanged: (v) => refresh(() => _devPlayerScale = v),
                              ),
                              slider(
                                label: 'سرعة دورة المشي',
                                value: _devWalkCycleSpeed,
                                min: .15,
                                max: 3.50,
                                onChanged: (v) => refresh(() => _devWalkCycleSpeed = v),
                              ),
                              const Text('مراحل الحركة الثلاث', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'حركة 1 — الخطوة الرئيسية', value: _devWalkPhase1, min: 0, max: 2.0, onChanged: (v) => refresh(() => _devWalkPhase1 = v)),
                              slider(label: 'حركة 2 — ثقل الجسم', value: _devWalkPhase2, min: -.8, max: .8, onChanged: (v) => refresh(() => _devWalkPhase2 = v)),
                              slider(label: 'حركة 3 — نعومة الخطوة', value: _devWalkPhase3, min: -.5, max: .5, onChanged: (v) => refresh(() => _devWalkPhase3 = v)),
                              const Text('الأرجل والقدم', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'حركة الفخذ', value: _devThighSwingDeg, min: 0, max: 65, suffix: '°', onChanged: (v) => refresh(() => _devThighSwingDeg = v)),
                              slider(label: 'ثني الركبة', value: _devKneeBendDeg, min: 0, max: 65, suffix: '°', onChanged: (v) => refresh(() => _devKneeBendDeg = v)),
                              slider(label: 'حركة القدم', value: _devFootSwingDeg, min: 0, max: 30, suffix: '°', onChanged: (v) => refresh(() => _devFootSwingDeg = v)),
                              const Text('اليد والكتف والرأس', style: TextStyle(color: Color(0xFF8DD7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'حركة الكتف أثناء المشي', value: _devShoulderSwingDeg, min: 0, max: 30, suffix: '°', onChanged: (v) => refresh(() => _devShoulderSwingDeg = v)),
                              slider(label: 'حركة اليد أثناء المشي', value: _devArmSwingDeg, min: 0, max: 45, suffix: '°', onChanged: (v) => refresh(() => _devArmSwingDeg = v)),
                              slider(label: 'حركة الرأس يمين/يسار', value: _devHeadYawDeg, min: 0, max: 15, suffix: '°', onChanged: (v) => refresh(() => _devHeadYawDeg = v)),
                              slider(label: 'حركة الرأس فوق/تحت', value: _devHeadPitchDeg, min: 0, max: 12, suffix: '°', onChanged: (v) => refresh(() => _devHeadPitchDeg = v)),
                              slider(label: 'ميلان الجسم أثناء المشي', value: _devBodyLeanDeg, min: -12, max: 12, suffix: '°', onChanged: (v) => refresh(() => _devBodyLeanDeg = v)),
                              slider(label: 'صعود/نزول الجسم بالخطوة', value: _devBodyBob, min: 0, max: .080, onChanged: (v) => refresh(() => _devBodyBob = v)),
                              const Divider(color: Colors.white12, height: 22),
                              const Text('الموت والحجم', style: TextStyle(color: Color(0xFFFFB86B), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'مكان الجثة X', value: _devDeathOffsetX, min: -.50, max: .50, onChanged: (v) => refresh(() => _devDeathOffsetX = v)),
                              slider(label: 'ارتفاع/انخفاض الجثة', value: _devDeathOffsetY, min: -.50, max: .50, onChanged: (v) => refresh(() => _devDeathOffsetY = v)),
                              slider(label: 'مكان الجثة Z', value: _devDeathOffsetZ, min: -.50, max: .50, onChanged: (v) => refresh(() => _devDeathOffsetZ = v)),
                              slider(label: 'حجم اللاعب بعد الموت', value: _devDeathScale, min: .35, max: 1.50, onChanged: (v) => refresh(() => _devDeathScale = v)),
                              if (selected != null)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    actionButton('معاينة الموت', Icons.personal_injury_rounded, () {
                                      selected.fall = 1;
                                      refresh(() {}, sync: true);
                                    }),
                                    actionButton('إرجاع اللاعب واقف', Icons.accessibility_new_rounded, () {
                                      selected.fall = 0;
                                      selected.eliminated = false;
                                      refresh(() {}, sync: true);
                                    }),
                                  ],
                                ),
                              const Divider(color: Colors.white12, height: 22),
                              const Text('حدود كاميرا اللاعب', style: TextStyle(color: Color(0xFFAED7FF), fontSize: 11.5, fontWeight: FontWeight.w900)),
                              slider(label: 'أقل تكبير', value: _devCameraZoomMin, min: .15, max: 1.20, onChanged: (v) => refresh(() {
                                _devCameraZoomMin = math.min(v, _devCameraZoomMax - .01);
                                _cameraZoom = _cameraZoom.clamp(_devCameraZoomMin, _devCameraZoomMax).toDouble();
                              }, sync: false)),
                              slider(label: 'أعلى تكبير', value: _devCameraZoomMax, min: .40, max: 4.0, onChanged: (v) => refresh(() {
                                _devCameraZoomMax = math.max(v, _devCameraZoomMin + .01);
                                _cameraZoom = _cameraZoom.clamp(_devCameraZoomMin, _devCameraZoomMax).toDouble();
                              }, sync: false)),
                              slider(label: 'حد النظر للأسفل', value: _devLookPitchMinDeg, min: -89, max: 0, suffix: '°', onChanged: (v) => refresh(() {
                                _devLookPitchMinDeg = math.min(v, _devLookPitchMaxDeg - 1);
                                _cameraPitch = _cameraPitch.clamp(_devLookPitchMinDeg * math.pi / 180, _devLookPitchMaxDeg * math.pi / 180).toDouble();
                              }, sync: false)),
                              slider(label: 'حد النظر للأعلى', value: _devLookPitchMaxDeg, min: 0, max: 89, suffix: '°', onChanged: (v) => refresh(() {
                                _devLookPitchMaxDeg = math.max(v, _devLookPitchMinDeg + 1);
                                _cameraPitch = _cameraPitch.clamp(_devLookPitchMinDeg * math.pi / 180, _devLookPitchMaxDeg * math.pi / 180).toDouble();
                              }, sync: false)),
                              const Divider(color: Colors.white12, height: 22),
                              slider(
                                label: 'سرعة حركة الأرجل',
                                value: _devWalkCycleSpeed,
                                min: .20,
                                max: 3,
                                onChanged: (v) => refresh(() => _devWalkCycleSpeed = v),
                              ),
                              slider(
                                label: 'حركة اليد الأخرى أثناء المشي',
                                value: _devSupportArmWalkBlend,
                                min: 0,
                                max: 1.8,
                                onChanged: (v) => refresh(() => _devSupportArmWalkBlend = v),
                              ),
                              slider(
                                label: 'وضع اليد الأخرى X',
                                value: _devSupportArmX,
                                min: -90,
                                max: 90,
                                suffix: '°',
                                onChanged: (v) => refresh(() => _devSupportArmX = v),
                              ),
                              slider(
                                label: 'وضع اليد الأخرى Y',
                                value: _devSupportArmY,
                                min: -90,
                                max: 90,
                                suffix: '°',
                                onChanged: (v) => refresh(() => _devSupportArmY = v),
                              ),
                              slider(
                                label: 'وضع اليد الأخرى Z',
                                value: _devSupportArmZ,
                                min: -90,
                                max: 90,
                                suffix: '°',
                                onChanged: (v) => refresh(() => _devSupportArmZ = v),
                              ),
                              slider(
                                label: 'انحناء مرفق اليد الأخرى',
                                value: _devSupportForeArmBend,
                                min: -90,
                                max: 90,
                                suffix: '°',
                                onChanged: (v) => refresh(() => _devSupportForeArmBend = v),
                              ),
                              slider(
                                label: 'سرعة حركة اللاعبين',
                                value: _devMovementSpeed,
                                min: .35,
                                max: 1.8,
                                onChanged: (v) => refresh(() => _devMovementSpeed = v),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  actionButton('تشغيل حركة المشي', Icons.directions_walk_rounded, () => unawaited(_developerPreviewWalk())),
                                  actionButton('إعادة توزيع اللاعبين', Icons.shuffle_rounded, () {
                                    _buildFighters();
                                    _devSelectedFighter = 0;
                                    _sync3D();
                                    setSheetState(() {});
                                  }),
                                ],
                              ),

                              const Divider(color: Colors.white12, height: 28),
                              ],
                              if (_devPanelSection == 0) ...[
                              sectionTitle(Icons.gps_fixed_rounded, 'التصويب — المسدس'),
                              slider(label: 'X يمين/يسار', value: _gunDevX, min: -.30, max: .30, onChanged: (v) {
                                refresh(() => _gunDevX = v, sync: false);
                                _applyGunDeveloperTransform();
                              }),
                              slider(label: 'Y فوق/تحت', value: _gunDevY, min: -.30, max: .30, onChanged: (v) {
                                refresh(() => _gunDevY = v, sync: false);
                                _applyGunDeveloperTransform();
                              }),
                              slider(label: 'Z قدام/لوراء', value: _gunDevZ, min: -.10, max: .60, onChanged: (v) {
                                refresh(() => _gunDevZ = v, sync: false);
                                _applyGunDeveloperTransform();
                              }),
                              slider(label: 'دوران X', value: _gunDevRotX, min: -180, max: 180, suffix: '°', onChanged: (v) {
                                refresh(() => _gunDevRotX = v, sync: false);
                                _applyGunDeveloperTransform();
                              }),
                              slider(label: 'دوران Y', value: _gunDevRotY, min: -180, max: 180, suffix: '°', onChanged: (v) {
                                refresh(() => _gunDevRotY = v, sync: false);
                                _applyGunDeveloperTransform();
                              }),
                              slider(label: 'دوران Z', value: _gunDevRotZ, min: -180, max: 180, suffix: '°', onChanged: (v) {
                                refresh(() => _gunDevRotZ = v, sync: false);
                                _applyGunDeveloperTransform();
                              }),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: actionButton('إرجاع المسدس', Icons.restart_alt_rounded, () {
                                  _resetGunDeveloperTransform();
                                  setSheetState(() {});
                                }),
                              ),

                              const Divider(color: Colors.white12, height: 28),
                              ],
                              if (_devPanelSection == 2) ...[
                              sectionTitle(Icons.map_rounded, 'الماب الجديد — Boss Room'),
                              const Text('المجسم يعمل بجودته الأصلية بالكامل. التحكم هنا يغيّر Root Transform فقط بدون ضغط Mesh أو Texture.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                              const SizedBox(height: 8),
                              slider(label: 'Map X', value: _devMapX, min: -20, max: 20, onChanged: (v) => refresh(() => _devMapX = v, sync: false)),
                              slider(label: 'Map Y', value: _devMapY, min: -20, max: 20, onChanged: (v) => refresh(() => _devMapY = v, sync: false)),
                              slider(label: 'Map Z', value: _devMapZ, min: -20, max: 20, onChanged: (v) => refresh(() => _devMapZ = v, sync: false)),
                              slider(label: 'حجم الماب الكامل', value: _devMapScale, min: .01, max: 1.20, onChanged: (v) => refresh(() => _devMapScale = v, sync: false)),
                              slider(label: 'دوران الماب X', value: _devMapRotX, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devMapRotX = v, sync: false)),
                              slider(label: 'دوران الماب Y', value: _devMapRotY, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devMapRotY = v, sync: false)),
                              slider(label: 'دوران الماب Z', value: _devMapRotZ, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _devMapRotZ = v, sync: false)),
                              const Divider(color: Colors.white12, height: 28),
                              sectionTitle(Icons.light_mode_rounded, 'إضاءة الماب'),
                              slider(label: 'شدة الإضاءة', value: _devLightIntensity, min: 0, max: 10, onChanged: (v) => refresh(() => _devLightIntensity = v, sync: false)),
                              slider(label: 'Exposure', value: _devSceneExposure, min: .10, max: 4.0, onChanged: (v) => refresh(() => _devSceneExposure = v, sync: false)),
                              slider(label: 'اتجاه الضوء X', value: _devLightDirectionX, min: -2, max: 2, onChanged: (v) => refresh(() => _devLightDirectionX = v, sync: false)),
                              slider(label: 'اتجاه الضوء Y', value: _devLightDirectionY, min: -2, max: 2, onChanged: (v) => refresh(() => _devLightDirectionY = v, sync: false)),
                              slider(label: 'اتجاه الضوء Z', value: _devLightDirectionZ, min: -2, max: 2, onChanged: (v) => refresh(() => _devLightDirectionZ = v, sync: false)),
                              colorSlider(label: 'Light R', value: _devLightR, activeColor: Colors.redAccent, onChanged: (v) => refresh(() => _devLightR = v, sync: false)),
                              colorSlider(label: 'Light G', value: _devLightG, activeColor: Colors.greenAccent, onChanged: (v) => refresh(() => _devLightG = v, sync: false)),
                              colorSlider(label: 'Light B', value: _devLightB, activeColor: Colors.blueAccent, onChanged: (v) => refresh(() => _devLightB = v, sync: false)),
                              SwitchListTile.adaptive(
                                value: _devLightCastsShadow,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('تفعيل ظلال الإضاءة', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                                onChanged: (v) => refresh(() => _devLightCastsShadow = v, sync: false),
                              ),

                              const Divider(color: Colors.white12, height: 28),
                              ],
                              if (_devPanelSection == 1) ...[
                              sectionTitle(Icons.crop_free_rounded, 'حد حركة اللاعبين — 8 أضلاع'),
                              SwitchListTile.adaptive(
                                value: _devArenaBoundaryVisible,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('إظهار حدود الأضلاع الحقيقية', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                                subtitle: const Text('هذه الخطوط نفسها مستخدمة في منع اللاعب من الخروج، وليست رسماً فقط.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                                onChanged: (v) => refresh(() => _devArenaBoundaryVisible = v, sync: false),
                              ),
                              slider(label: 'مركز الحدود X', value: _arenaCenterX, min: -.50, max: 1.50, onChanged: (v) => refresh(() => _arenaCenterX = v)),
                              slider(label: 'مركز الحدود Y', value: _arenaCenterY, min: -.50, max: 1.50, onChanged: (v) => refresh(() => _arenaCenterY = v)),
                              const Text('لكل ضلع: X و Y لمركز الضلع، الطول، والميلان بالدرجات. عدّلها حتى تطابق حافة الستيج 100%.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                              const SizedBox(height: 10),
                              for (var i = 0; i < 8; i++) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.035),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('الضلع ${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      slider(label: 'X', value: _arenaSideCenters[i].dx, min: -.50, max: 1.50, onChanged: (v) => refresh(() => _arenaSideCenters[i] = Offset(v, _arenaSideCenters[i].dy))),
                                      slider(label: 'Y', value: _arenaSideCenters[i].dy, min: -.50, max: 1.50, onChanged: (v) => refresh(() => _arenaSideCenters[i] = Offset(_arenaSideCenters[i].dx, v))),
                                      slider(label: 'طول الضلع', value: _arenaSideLengths[i], min: .01, max: 1.50, onChanged: (v) => refresh(() => _arenaSideLengths[i] = v)),
                                      slider(label: 'ميلان الضلع', value: _arenaSideAnglesDeg[i], min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _arenaSideAnglesDeg[i] = v)),
                                    ],
                                  ),
                                ),
                              ],
                              const Divider(color: Colors.white12, height: 28),
                              ],
                              if (_devPanelSection == 2) ...[
                              sectionTitle(Icons.wallpaper_rounded, 'الخلفية'),
                              const Text('خلفية Milky Way مستقلة بالكامل عن الماب الجديد. اللون والحجم والإحداثيات تطبق على الخلفية نفسها.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                              const SizedBox(height: 8),
                              colorSlider(label: 'خلفية R', value: _devLobbyBackdropR, activeColor: Colors.redAccent, onChanged: (v) => refresh(() => _devLobbyBackdropR = v, sync: false)),
                              colorSlider(label: 'خلفية G', value: _devLobbyBackdropG, activeColor: Colors.greenAccent, onChanged: (v) => refresh(() => _devLobbyBackdropG = v, sync: false)),
                              colorSlider(label: 'خلفية B', value: _devLobbyBackdropB, activeColor: Colors.blueAccent, onChanged: (v) => refresh(() => _devLobbyBackdropB = v, sync: false)),
                              const SizedBox(height: 8),
                              slider(label: 'Background X', value: _devLobbyBackdropX, min: -1000, max: 1000, divisions: 2000, onChanged: (v) => refresh(() => _devLobbyBackdropX = v, sync: false)),
                              slider(label: 'Background Y', value: _devLobbyBackdropY, min: -1000, max: 1000, divisions: 2000, onChanged: (v) => refresh(() => _devLobbyBackdropY = v, sync: false)),
                              slider(label: 'Background Z', value: _devLobbyBackdropZ, min: -1000, max: 1000, divisions: 2000, onChanged: (v) => refresh(() => _devLobbyBackdropZ = v, sync: false)),
                              slider(label: 'حجم خلفية Milky Way', value: _devLobbyBackdropScale, min: 0, max: 100, divisions: 1000, onChanged: (v) => refresh(() => _devLobbyBackdropScale = v, sync: false)),
                              const Text('X/Y/Z والحجم تتحكم مباشرة بالخلفية بدون التأثير على الماب أو اللاعبين.', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                              const Divider(color: Colors.white12, height: 20),
                              slider(
                                label: 'سرعة دوران الخلفية',
                                value: _devBackgroundRotationSpeed,
                                min: -.10,
                                max: .10,
                                onChanged: (v) => refresh(() => _devBackgroundRotationSpeed = v, sync: false),
                              ),
                              Wrap(
                                spacing: 7,
                                children: [
                                  for (final fit in KillerKilledBackgroundFit.values)
                                    ChoiceChip(
                                      selected: _devBackgroundFit == fit,
                                      label: Text(switch (fit) {
                                        KillerKilledBackgroundFit.cover => 'ملء',
                                        KillerKilledBackgroundFit.contain => 'ملائمة',
                                        KillerKilledBackgroundFit.repeat => 'تكرار',
                                      }),
                                      onSelected: (_) async {
                                        refresh(() => _devBackgroundFit = fit, sync: false);
                                        final bytes = _devBackgroundBytes;
                                        if (bytes != null) {
                                          await _world.setBackgroundImage(bytes, fit: fit);
                                          if (mounted) setState(() {});
                                        }
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  actionButton('اختيار صورة', Icons.photo_library_rounded, () async {
                                    final picked = await dev_image_picker.pickDeveloperImage();
                                    final bytes = picked?['bytes'];
                                    if (bytes is Uint8List) {
                                      _devBackgroundBytes = bytes;
                                      await _world.setBackgroundImage(bytes, fit: _devBackgroundFit);
                                      if (mounted) {
                                        setState(() {});
                                        setSheetState(() {});
                                      }
                                    }
                                  }, color: const Color(0xFF6C4AC9)),
                                  actionButton('الخلفية الافتراضية', Icons.restore_rounded, () async {
                                    final bytes = _defaultBackgroundBytes;
                                    if (bytes != null) {
                                      _devBackgroundBytes = bytes;
                                      _devBackgroundFit = KillerKilledBackgroundFit.cover;
                                      await _world.setBackgroundImage(bytes, fit: _devBackgroundFit);
                                    } else {
                                      _devBackgroundBytes = null;
                                      _world.restoreOriginalBackground();
                                    }
                                    if (mounted) setState(() {});
                                    setSheetState(() {});
                                  }),
                                ],
                              ),

                              const Divider(color: Colors.white12, height: 28),
                              ],
                              if (_devPanelSection == 3) ...[
                              sectionTitle(Icons.videocam_rounded, 'الكاميرا'),
                              slider(label: 'المسافة', value: _cameraDistance, min: .8, max: 4.5, onChanged: (v) => refresh(() => _cameraDistance = v, sync: false)),
                              slider(label: 'الارتفاع', value: _cameraOffsetY, min: -.2, max: 2.2, onChanged: (v) => refresh(() => _cameraOffsetY = v, sync: false)),
                              slider(label: 'يمين / يسار', value: _cameraOffsetX, min: -1.5, max: 1.5, onChanged: (v) => refresh(() => _cameraOffsetX = v, sync: false)),
                              slider(label: 'التكبير', value: _cameraZoom, min: .28, max: 2.2, onChanged: (v) => refresh(() => _cameraZoom = v, sync: false)),
                              slider(label: 'Yaw إضافي', value: _cameraYawOffset * 180 / math.pi, min: -180, max: 180, suffix: '°', onChanged: (v) => refresh(() => _cameraYawOffset = v * math.pi / 180, sync: false)),
                              const SizedBox(height: 16),
                              const Text(
                                'كل القيم تُطبّق مباشرة. اللعبة متوقفة أثناء فتح هذه اللوحة، لكن المعاينة ثلاثية الأبعاد تبقى شغالة حتى تشوف التغيير فورًا.',
                                style: TextStyle(color: Colors.white38, fontSize: 10.5, height: 1.45),
                              ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
              ),
            ),
          ),
          ),
        );
      },
    );
    _developerOverlay = overlayEntry;
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
  }

  void _enterDeveloperSimulation(OverlayEntry overlayEntry) {
    if (_devSimulationMode || _fighters.isEmpty) return;

    _devSimulationSavedPhase = _phase;
    _devSimulationSavedRemaining = _remaining;
    _devSimulationSavedActiveShooterId = _activeShooterId;
    _devSimulationSavedObstacle = _currentObstacle;
    _devSimulationSavedCenterMessage = _centerMessage;
    _devSimulationSavedMessageOpacity = _messageOpacity;
    _devSimulationFighterSnapshots = [
      for (final fighter in _fighters)
        (
          x: fighter.x,
          y: fighter.y,
          angle: fighter.angle,
          velocityX: fighter.velocityX,
          velocityY: fighter.velocityY,
          walkTime: fighter.walkTime,
          moveForward: fighter.moveForward,
          moveStrafe: fighter.moveStrafe,
          hearts: fighter.hearts,
          eliminated: fighter.eliminated,
          fall: fighter.fall,
          hitFlash: fighter.hitFlash,
          shotFlash: fighter.shotFlash,
        ),
    ];

    _clearDeveloperFreeCameraInput();
    _devFreeCameraEnabled = false;
    _developerPanelVisible = false;
    _developerPanelOpen = false;
    _devSimulationMode = true;
    _paused = false;
    _phase = _RoundPhase.movement;
    _activeShooterId = null;
    _currentObstacle = null;
    _stick = Offset.zero;
    _smoothedStick = Offset.zero;
    _movementInputActive = false;
    _movementHeadingAnchor = null;
    _centerMessage = '';
    _messageOpacity = 0;
    for (final fighter in _fighters) {
      fighter
        ..velocityX = 0
        ..velocityY = 0
        ..moveForward = 0
        ..moveStrafe = 0
        ..eliminated = false
        ..fall = 0
        ..hitFlash = 0
        ..shotFlash = 0;
    }
    if (_developerOverlay == overlayEntry) _developerOverlay = null;
    if (overlayEntry.mounted) overlayEntry.remove();
    _world.setObstacle(visible: false);
    _sync3D();
    if (mounted) setState(() {});
  }

  Future<void> _exitDeveloperSimulation() async {
    if (!_devSimulationMode) return;
    final snapshots = _devSimulationFighterSnapshots;
    if (snapshots != null) {
      for (var i = 0; i < _fighters.length && i < snapshots.length; i++) {
        final fighter = _fighters[i];
        final snap = snapshots[i];
        fighter
          ..x = snap.x
          ..y = snap.y
          ..angle = snap.angle
          ..velocityX = snap.velocityX
          ..velocityY = snap.velocityY
          ..walkTime = snap.walkTime
          ..moveForward = snap.moveForward
          ..moveStrafe = snap.moveStrafe
          ..hearts = snap.hearts
          ..eliminated = snap.eliminated
          ..fall = snap.fall
          ..hitFlash = snap.hitFlash
          ..shotFlash = snap.shotFlash;
      }
    }
    _phase = _devSimulationSavedPhase ?? _RoundPhase.movement;
    _remaining = _devSimulationSavedRemaining ?? _remaining;
    _activeShooterId = _devSimulationSavedActiveShooterId;
    _currentObstacle = _devSimulationSavedObstacle;
    _centerMessage = _devSimulationSavedCenterMessage ?? '';
    _messageOpacity = _devSimulationSavedMessageOpacity ?? 0;
    _devSimulationMode = false;
    _devSimulationFighterSnapshots = null;
    _clearDesktopMovement();
    _world.setObstacle(
      visible: _currentObstacle != null && _phase != _RoundPhase.movement,
      x: _currentObstacle?.x ?? .5,
      y: _currentObstacle?.y ?? .5,
    );
    _sync3D();
    if (mounted) setState(() {});
    await _openDeveloperLab();
  }

  Future<void> _developerTestShot() async {
    if (_fighters.isEmpty) return;
    final shooter = _fighters[_devSelectedFighter.clamp(0, _fighters.length - 1).toInt()];
    final previousPhase = _phase;
    final previousShooter = _activeShooterId;
    final snapshots = [
      for (final fighter in _fighters)
        (
          hearts: fighter.hearts,
          eliminated: fighter.eliminated,
          fall: fighter.fall,
          hitFlash: fighter.hitFlash,
          shotFlash: fighter.shotFlash,
        ),
    ];

    _phase = _RoundPhase.shooting;
    _activeShooterId = shooter.id;
    shooter.shotFlash = .22;
    final victim = _rayHit(shooter);
    if (victim != null) {
      victim.hitFlash = 1;
      victim.fall = 1;
      unawaited(AppAudioService.playDamageHit());
    }
    unawaited(AppAudioService.playPistolShot());
    _sync3D();
    if (mounted) setState(() {});

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    for (var i = 0; i < _fighters.length && i < snapshots.length; i++) {
      final fighter = _fighters[i];
      final snap = snapshots[i];
      fighter
        ..hearts = snap.hearts
        ..eliminated = snap.eliminated
        ..fall = snap.fall
        ..hitFlash = snap.hitFlash
        ..shotFlash = snap.shotFlash;
    }
    _phase = previousPhase;
    _activeShooterId = previousShooter;
    _sync3D();
    setState(() {});
  }

  Future<void> _developerPreviewWalk() async {
    if (_fighters.isEmpty) return;
    final fighter = _fighters[_devSelectedFighter.clamp(0, _fighters.length - 1).toInt()];
    final originalWalk = fighter.walkTime;
    final originalForward = fighter.moveForward;
    final originalStrafe = fighter.moveStrafe;
    final originalVX = fighter.velocityX;
    final originalVY = fighter.velocityY;
    for (var i = 0; i < 28 && mounted && _developerPanelOpen; i++) {
      fighter.walkTime += .055 * _devWalkCycleSpeed;
      fighter.moveForward = 1;
      fighter.moveStrafe = 0;
      fighter.velocityX = math.cos(fighter.angle) * .30;
      fighter.velocityY = math.sin(fighter.angle) * .30;
      _sync3D();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 55));
    }
    fighter
      ..walkTime = originalWalk
      ..moveForward = originalForward
      ..moveStrafe = originalStrafe
      ..velocityX = originalVX
      ..velocityY = originalVY;
    _sync3D();
    if (mounted) setState(() {});
  }

  void _applyGunDeveloperTransform() {
    _world.setGunDeveloperTransform(
      x: _gunDevX,
      y: _gunDevY,
      z: _gunDevZ,
      rotX: _gunDevRotX * math.pi / 180,
      rotY: _gunDevRotY * math.pi / 180,
      rotZ: _gunDevRotZ * math.pi / 180,
    );
  }

  void _resetGunDeveloperTransform() {
    setState(() {
      _gunDevX = 0;
      _gunDevY = .018;
      _gunDevZ = .087;
      _gunDevRotX = 0;
      _gunDevRotY = 0;
      _gunDevRotZ = 0;
    });
    _applyGunDeveloperTransform();
  }

  Widget _buildGunDeveloperPanel() {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xE61A2332),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    if (!_gunDevMode) {
      return SafeArea(
        child: ElevatedButton.icon(
          style: buttonStyle,
          onPressed: () => setState(() => _gunDevMode = true),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('وضع المطور للمجسم'),
        ),
      );
    }

    return SafeArea(
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 430),
        decoration: BoxDecoration(
          color: const Color(0xEE0E1624),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'وضع مطور المجسم فقط',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetGunDeveloperTransform,
                    child: const Text('إرجاع'),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => setState(() => _gunDevMode = false),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'هذه الأدوات تغيّر شكل ومكان ودوران مجسم المسدس، والليزر/القتل يتبعان فوهته تلقائيًا.',
                style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.35),
              ),
              const SizedBox(height: 10),
              _devStatLine('X يمين/يسار', _gunDevX),
              _buildDevSlider(
                label: 'X يمين/يسار',
                value: _gunDevX,
                min: -.30,
                max: .30,
                onChanged: (v) {
                  setState(() => _gunDevX = v);
                  _applyGunDeveloperTransform();
                },
              ),
              _devStatLine('Y فوق/تحت', _gunDevY),
              _buildDevSlider(
                label: 'Y فوق/تحت',
                value: _gunDevY,
                min: -.30,
                max: .30,
                onChanged: (v) {
                  setState(() => _gunDevY = v);
                  _applyGunDeveloperTransform();
                },
              ),
              _devStatLine('Z قدام/لوراء', _gunDevZ),
              _buildDevSlider(
                label: 'Z قدام/لوراء',
                value: _gunDevZ,
                min: -.10,
                max: .60,
                onChanged: (v) {
                  setState(() => _gunDevZ = v);
                  _applyGunDeveloperTransform();
                },
              ),
              const Divider(color: Colors.white12, height: 18),
              _devStatLine('دوران X', _gunDevRotX, suffix: '°'),
              _buildDevSlider(
                label: 'دوران X',
                value: _gunDevRotX,
                min: -180,
                max: 180,
                onChanged: (v) {
                  setState(() => _gunDevRotX = v);
                  _applyGunDeveloperTransform();
                },
              ),
              _devStatLine('دوران Y', _gunDevRotY, suffix: '°'),
              _buildDevSlider(
                label: 'دوران Y',
                value: _gunDevRotY,
                min: -180,
                max: 180,
                onChanged: (v) {
                  setState(() => _gunDevRotY = v);
                  _applyGunDeveloperTransform();
                },
              ),
              _devStatLine('دوران Z', _gunDevRotZ, suffix: '°'),
              _buildDevSlider(
                label: 'دوران Z',
                value: _gunDevRotZ,
                min: -180,
                max: 180,
                onChanged: (v) {
                  setState(() => _gunDevRotZ = v);
                  _applyGunDeveloperTransform();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _devStatLine(String label, double value, {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${value.toStringAsFixed(3)}$suffix',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDevSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(trackHeight: 3.2),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: 300,
        label: '$label ${value.toStringAsFixed(3)}',
        onChanged: onChanged,
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
        autoTick: _devFreeCameraEnabled ||
            ((!_paused || _developerPanelOpen) && _phase != _RoundPhase.finished),
        onTick: _onSceneTick,
        cameraBuilder: (elapsed) => _devFreeCameraEnabled
            ? _world.developerFreeCameraFor(
                seconds: elapsed.inMicroseconds / 1000000,
                x: _devFreeCameraX,
                y: _devFreeCameraY,
                z: _devFreeCameraZ,
                yaw: _devFreeCameraYaw,
                pitch: _devFreeCameraPitch,
              )
            : _world.cameraFor(
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
    final labelCamera = _world.cameraFor(
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
      updateBackground: false,
    );

    for (final fighter in _fighters) {
      if (fighter.eliminated) continue;
      if (!_devSimulationMode && movement && !fighter.isHuman && !me.eliminated) continue;
      final point = _world.labelScreenPoint(
        camera: labelCamera,
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
        if (!_developerPanelOpen) ...[
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
        ],
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
