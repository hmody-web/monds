import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:flutter_scene/scene.dart' as fs show Material;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/killer_killed_avatar.dart';
import '../home_screen.dart';
import '../drawing_game_home_screen.dart';
import '../local/local_players_screen.dart';
import '../multiplayer/multiplayer_entry_screen.dart';
import '../heads_up/heads_up_setup_screen.dart';
import '../killer_killed/killer_killed_home_screen.dart';
import '../guess_time/guess_time_home_screen.dart';

class ArcadeLobbyScreen extends StatefulWidget {
  const ArcadeLobbyScreen({super.key});

  @override
  State<ArcadeLobbyScreen> createState() => _ArcadeLobbyScreenState();
}

class _ArcadeLobbyScreenState extends State<ArcadeLobbyScreen> {
  static const String _prefsKey = 'arcade_lobby_developer_settings_v34';

  final Scene _scene = Scene();
  final List<_PoseTuning> _poseTunings = _buildDefaultPoseTunings();
  final Map<String, Node> _jointNodes = <String, Node>{};
  final Map<String, _NodeSnapshot> _jointBase = <String, _NodeSnapshot>{};
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'arcade_lobby');
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  final Map<String, _MotionTrack> _motionTracks = <String, _MotionTrack>{};

  static const List<_ArcadeGameEntry> _arcadeGames = <_ArcadeGameEntry>[
    _ArcadeGameEntry(
      title: 'خمن من الرسم',
      subtitle: 'ارسموا الكلمة واكشفوا سوكي قبل أن يخدع المجموعة.',
      icon: '✏',
      coverAsset: 'assets/models/arcade_games/guess_drawing.webp',
      hasOffline: true,
      hasOnline: true,
      detailsTitle: 'خمن من الرسم',
      detailsText:
          'يظهر للاعب المطلوب رسمه، ويرسمه من دون كتابة الاسم. باقي اللاعبين يحاولون معرفة الإجابة قبل انتهاء الجولة.',
    ),
    _ArcadeGameEntry(
      title: 'خمن اللي براسي',
      subtitle: 'ضع الهاتف على رأسك ودع المجموعة تساعدك على التخمين.',
      icon: '🧠',
      coverAsset: 'assets/models/arcade_games/heads_up.webp',
      hasOffline: true,
      hasOnline: false,
      detailsTitle: 'خمن اللي براسي',
      detailsText:
          'يختار اللاعب الفئة ثم يحاول معرفة الكلمة من تلميحات بقية اللاعبين قبل انتهاء الوقت.',
    ),
    _ArcadeGameEntry(
      title: 'قاتل ومقتول',
      subtitle: 'تحرّك بسرعة واكشف موقع خصومك قبل انتهاء الوقت.',
      icon: '🎯',
      coverAsset: 'assets/models/arcade_games/killer_killed.webp',
      hasOffline: true,
      hasOnline: false,
      detailsTitle: 'قاتل ومقتول',
      detailsText:
          'ابدأ الجولة ونفذ هدفك قبل خصمك. تعتمد اللعبة على السرعة والتركيز والتوقيت الصحيح أثناء الجولة.',
    ),
    _ArcadeGameEntry(
      title: 'خمن الوقت',
      subtitle: 'احفظ الوقت المطلوب واضغط في اللحظة الأقرب للفوز.',
      icon: '⏱',
      coverAsset: 'assets/models/arcade_games/guess_time.webp',
      hasOffline: true,
      hasOnline: true,
      detailsTitle: 'خمن الوقت',
      detailsText:
          'احفظ الوقت المطلوب، ثم أوقف العداد في اللحظة التي تعتقد أنها الأقرب له. الأكثر دقة يفوز.',
    ),
    _ArcadeGameEntry(
      title: 'رجوع',
      subtitle: 'العودة إلى الشخصية',
      icon: '↩',
      coverAsset: '',
      isBack: true,
      hasOffline: false,
      hasOnline: false,
    ),
  ];

  SharedPreferences? _prefs;
  Timer? _saveTimer;
  Timer? _engineTimer;
  DateTime? _lastTickAt;

  Node? _roomNode;

  Node? _tvNode;
  Node? _tvScreenNode;
  fs.Material? _tvScreenOriginalMaterial;
  Mesh? _tvScreenOriginalMesh;
  MeshGeometry? _tvGameScreenGeometry;
  UnlitMaterial? _tvScreenHighlightMaterial;
  UnlitMaterial? _tvGameScreenMaterial;
  Texture2D? _tvGameScreenTexture;
  bool _tvGameScreenRefreshInFlight = false;

  Node? _arcadeScreenNode;
  Node? _arcadeJoystickNode;
  Node? _legacyArcadeScreenNode;
  Node? _legacyArcadeJoystickNode;
  Node? _arcadeScreenRevealNode;
  Node? _arcadeJoystickRevealNode;
  vm.Vector3 _arcadeScreenBasePosition = vm.Vector3.zero();
  vm.Quaternion _arcadeScreenBaseRotation = vm.Quaternion.identity();
  vm.Vector3 _arcadeScreenBaseScale = vm.Vector3.all(1);
  vm.Vector3 _arcadeJoystickBasePosition = vm.Vector3.zero();
  vm.Quaternion _arcadeJoystickBaseRotation = vm.Quaternion.identity();
  vm.Vector3 _arcadeJoystickBaseScale = vm.Vector3.all(1);
  fs.Material? _arcadeScreenOriginalMaterial;
  Mesh? _arcadeScreenOriginalMesh;
  fs.Material? _arcadeJoystickOriginalMaterial;
  UnlitMaterial? _arcadeScreenColorMaterial;
  UnlitMaterial? _arcadeJoystickColorMaterial;
  Node? _characterNode;
  Node? _spaceBackdrop;
  Texture2D? _spaceBackdropTexture;
  Node? _arcadeGlowRoot;
  Node? _arcadeHitboxNode;
  Node? _arcadeHaloNode;
  final List<Node> _arcadeGlowEdges = <Node>[];
  final List<_ArcadeGlowBandNode> _arcadeGlowBands = <_ArcadeGlowBandNode>[];
  UnlitMaterial? _arcadeGlowMaterial;
  UnlitMaterial? _arcadeHaloMaterial;
  UnlitMaterial? _arcadeHitboxMaterial;

  MeshData? _arcadeCutSourceData;
  fs.Material? _arcadeCutSourceMaterial;
  Node? _arcadeCutRemainderNode;
  Node? _arcadeCutterNode;
  UnlitMaterial? _arcadeCutterMaterial;
  final Set<int> _arcadeRemovedTriangles = <int>{};
  final List<_ArcadeCutPart> _arcadeCutParts = <_ArcadeCutPart>[];
  int _nextArcadeCutPartId = 1;
  int? _selectedArcadeCutPartId;

  bool _showArcadeCutter = true;
  double _cutterX = 0.0;
  double _cutterY = 0.0;
  double _cutterZ = 0.0;
  double _cutterLeft = 1.0;
  double _cutterRight = 1.0;
  double _cutterUp = 1.0;
  double _cutterDown = 1.0;
  double _cutterFront = 1.0;
  double _cutterBack = 1.0;
  double _cutterPitch = 0.0;
  double _cutterYaw = 0.0;
  double _cutterRoll = 0.0;

  bool _loading = true;
  bool _developerPanelOpen = false;
  String _developerSection = 'map';
  bool _motionPanelOpen = false;
  bool _uiPreviewOnly = false;
  bool _arcadeCameraEditMode = false;
  bool _arcadeFocusLocked = false;
  bool _userModeActive = false;
  bool _userCameraOverrideActive = false;
  bool _cameraMotionResumeBlendActive = false;
  double _userCameraIdleSeconds = 0;
  double _cameraMotionResumeBlendElapsed = 0;
  static const double _userCameraIdleDelaySeconds = 5.0;
  static const double _cameraMotionResumeBlendSeconds = 1.25;

  // Touch look physics: inertia + soft overscroll + spring bounce.
  double _userLookVelocityYaw = 0.0;
  double _userLookVelocityPitch = 0.0;
  double _userLookInertia = .90;
  double _userLookInputBoost = 18.0;
  double _userLookMaxVelocityDeg = 95.0;
  double _userLookOverscrollDeg = 1.0;
  double _userLookSpringStrength = 38.0;
  double _userLookSpringDamping = 8.5;

  double _cameraResumeStartX = 0;
  double _cameraResumeStartY = 0;
  double _cameraResumeStartZ = 0;
  double _cameraResumeStartTargetX = 0;
  double _cameraResumeStartTargetY = 0;
  double _cameraResumeStartTargetZ = 0;
  double _cameraResumeStartFov = 48;
  bool _initialCameraEditMode = false;
  String _lookLimitPreviewMode = '';
  bool _lookLimitPreviewRestoreMotionPlaying = false;
  double _lookPreviewRestoreCameraX = 0;
  double _lookPreviewRestoreCameraY = 0;
  double _lookPreviewRestoreCameraZ = 0;
  double _lookPreviewRestoreTargetX = 0;
  double _lookPreviewRestoreTargetY = 0;
  double _lookPreviewRestoreTargetZ = 0;
  double _lookPreviewRestoreFov = 0;
  bool _initialCameraEditRestoreMotionPlaying = false;
  double _initialEditRestoreCameraX = 0;
  double _initialEditRestoreCameraY = 0;
  double _initialEditRestoreCameraZ = 0;
  double _initialEditRestoreTargetX = 0;
  double _initialEditRestoreTargetY = 0;
  double _initialEditRestoreTargetZ = 0;
  double _initialEditRestoreFov = 0;
  double _initialEditOriginalStartCameraX = 0;
  double _initialEditOriginalStartCameraY = 0;
  double _initialEditOriginalStartCameraZ = 0;
  double _initialEditOriginalStartTargetX = 0;
  double _initialEditOriginalStartTargetY = 0;
  double _initialEditOriginalStartTargetZ = 0;
  double _initialEditOriginalStartFov = 0;
  Object? _error;

  bool _showRoom = true;
  bool _showCharacter = true;
  bool _showGuide = true;

  double _renderScale = .8;
  double _sceneExposure = 1.44;
  double _lightIntensity = .65;
  double _lightYawDeg = -48.0;
  double _lightPitchDeg = -58.0;

  double _cameraX = 5.4903;
  double _cameraY = 2.6880;
  double _cameraZ = 0.6767;
  double _targetX = 4.5293;
  double _targetY = 2.5474;
  double _targetZ = 0.4388;
  double _cameraFov = 67.0;
  double _cameraMoveSpeed = 2.0;
  double _mouseSensitivity = 0.0052;

  double _cameraYaw = 0;
  double _cameraPitch = 0;
  double _cameraDistance = 1.0;

  double _mainLookLeftDeg = 55.0;
  double _mainLookRightDeg = 55.0;
  double _mainLookUpDeg = 30.0;
  double _mainLookDownDeg = 30.0;
  double _arcadeLookLeftDeg = 3.0;
  double _arcadeLookRightDeg = 3.0;
  double _arcadeLookUpDeg = 3.0;
  double _arcadeLookDownDeg = 3.0;

  double _userStartCameraX = .6100;
  double _userStartCameraY = 4.0400;
  double _userStartCameraZ = -.3300;
  double _userStartTargetX = -.3132;
  double _userStartTargetY = 3.0436;
  double _userStartTargetZ = -.9329;
  double _userStartFov = 48.0;

  double _roomX = 0.3150;
  double _roomY = 0.0000;
  double _roomZ = 0.4250;
  double _roomRotX = 0.0;
  double _roomRotY = 0.0;
  double _roomRotZ = 0.0;
  double _roomScaleX = 0.0900;
  double _roomScaleY = 0.0900;
  double _roomScaleZ = 0.0900;

  bool _showTv = true;

  // Final / settled TV transform (official values).
  double _tvX = -1.4100;
  double _tvY = 3.3400;
  double _tvZ = -0.5800;
  double _tvRotX = -115.0;
  double _tvRotY = 94.0;
  double _tvRotZ = -3.0;
  double _tvScaleX = .5000;
  double _tvScaleY = .7800;
  double _tvScaleZ = 1.4000;

  // TV entrance animation.
  double _tvEntryStartX = -6.0000;
  double _tvEntryStartY = 5.1000;
  double _tvEntryStartZ = 3.5000;
  double _tvEntryStartRotX = -115.0;
  double _tvEntryStartRotY = 94.0;
  double _tvEntryStartRotZ = -3.0;
  double _tvEntryStartScaleX = .1250;
  double _tvEntryStartScaleY = .1950;
  double _tvEntryStartScaleZ = .3500;
  double _tvEntrySpinXTurns = 0.0;
  double _tvEntrySpinYTurns = 2.0;
  double _tvEntrySpinZTurns = 0.0;
  double _tvEntryDuration = 1.25;

  // Camera destination while entering the TV/game view.
  double _tvCameraX = 1.3675;
  double _tvCameraY = 4.0117;
  double _tvCameraZ = -0.6627;
  double _tvCameraTargetX = -1.4100;
  double _tvCameraTargetY = 3.3400;
  double _tvCameraTargetZ = -0.5800;
  double _tvCameraFov = 48.0;
  double _tvCameraDuration = 1.25;

  // Independent look limits while focused on the TV.
  double _tvLookLeftDeg = 0.0;
  double _tvLookRightDeg = 0.0;
  double _tvLookUpDeg = 0.0;
  double _tvLookDownDeg = 0.0;

  bool _tvCameraLivePreview = true;

  // Dynamic settled motion.
  bool _tvIdleMotionEnabled = true;
  double _tvIdleMoveX = .0350;
  double _tvIdleMoveY = .0500;
  double _tvIdleMoveZ = .0200;
  double _tvIdleRotX = 1.2;
  double _tvIdleRotY = 2.0;
  double _tvIdleRotZ = .8;
  double _tvIdleCycleSeconds = 4.0;
  double _tvIdleClock = 0.0;

  bool _tvTransitionAnimating = false;
  bool _tvModeActive = false;
  double _tvTransitionElapsed = 0.0;
  int _tvSelectedGameIndex = 0;

  double _tvTransitionCameraStartX = 0;
  double _tvTransitionCameraStartY = 0;
  double _tvTransitionCameraStartZ = 0;
  double _tvTransitionTargetStartX = 0;
  double _tvTransitionTargetStartY = 0;
  double _tvTransitionTargetStartZ = 0;
  double _tvTransitionFovStart = 48;

  bool _showTvScreen = true;
  double _tvScreenX = 0.0;
  double _tvScreenY = 0.0;
  double _tvScreenZ = 0.0;
  double _tvScreenRotX = 0.0;
  double _tvScreenRotY = 0.0;
  double _tvScreenRotZ = 0.0;
  double _tvScreenScaleX = 1.0;
  double _tvScreenScaleY = 1.0;
  double _tvScreenScaleZ = 1.0;
  bool _tvScreenHighlight = false;

  // TV game menu screen design.
  bool _tvDetailsVisible = false;
  double _tvUiTitleOffsetX = 0.0;
  double _tvUiTitleOffsetY = 0.0;
  double _tvUiTitleScale = 1.0;
  double _tvUiButtonsOffsetX = 0.0;
  double _tvUiButtonsOffsetY = 0.0;
  double _tvUiButtonsScale = 1.0;
  double _tvUiButtonsGap = 1.0;
  double _tvUiInfoOffsetX = 0.0;
  double _tvUiInfoOffsetY = 0.0;
  double _tvUiInfoScale = 1.0;
  double _tvUiPanelOffsetX = 0.0;
  double _tvUiPanelOffsetY = 0.0;
  double _tvUiPanelScale = 1.0;
  double _tvUiButtonRadius = 1.0;
  double _tvUiButtonStroke = 1.0;

  double _tvUiBgR = 6.0;
  double _tvUiBgG = 18.0;
  double _tvUiBgB = 29.0;
  double _tvUiAccentR = 255.0;
  double _tvUiAccentG = 184.0;
  double _tvUiAccentB = 52.0;
  double _tvUiTitleR = 255.0;
  double _tvUiTitleG = 241.0;
  double _tvUiTitleB = 197.0;
  double _tvUiOfflineR = 22.0;
  double _tvUiOfflineG = 136.0;
  double _tvUiOfflineB = 96.0;
  double _tvUiOnlineR = 38.0;
  double _tvUiOnlineG = 94.0;
  double _tvUiOnlineB = 184.0;
  double _tvUiDisabledR = 68.0;
  double _tvUiDisabledG = 66.0;
  double _tvUiDisabledB = 76.0;
  double _tvUiInfoR = 210.0;
  double _tvUiInfoG = 104.0;
  double _tvUiInfoB = 30.0;
  double _tvUiTextR = 255.0;
  double _tvUiTextG = 255.0;
  double _tvUiTextB = 255.0;
  double _tvUiPanelR = 12.0;
  double _tvUiPanelG = 23.0;
  double _tvUiPanelB = 36.0;

  bool _showArcadeScreen = true;
  double _arcadeScreenX = 0.0;
  double _arcadeScreenY = 0.0;
  double _arcadeScreenZ = 0.0;
  double _arcadeScreenRotX = 0.0;
  double _arcadeScreenRotY = 0.0;
  double _arcadeScreenRotZ = 0.0;
  double _arcadeScreenScaleX = 1.0;
  double _arcadeScreenScaleY = 1.0;
  double _arcadeScreenScaleZ = 1.0;
  bool _arcadeScreenColorEnabled = false;
  double _arcadeScreenColorR = 255.0;
  double _arcadeScreenColorG = 255.0;
  double _arcadeScreenColorB = 255.0;
  double _arcadeScreenColorOpacity = 1.0;

  bool _showArcadeJoystick = true;
  double _arcadeJoystickX = 0.0;
  double _arcadeJoystickY = 0.0;
  double _arcadeJoystickZ = 0.0;
  double _arcadeJoystickRotX = 0.0;
  double _arcadeJoystickRotY = 0.0;
  double _arcadeJoystickRotZ = 0.0;
  double _arcadeJoystickScaleX = 1.0;
  double _arcadeJoystickScaleY = 1.0;
  double _arcadeJoystickScaleZ = 1.0;
  bool _arcadeJoystickColorEnabled = false;
  double _arcadeJoystickColorR = 255.0;
  double _arcadeJoystickColorG = 255.0;
  double _arcadeJoystickColorB = 255.0;
  double _arcadeJoystickColorOpacity = 1.0;
  bool _revealArcadeScreen = false;
  bool _revealArcadeJoystick = false;

  Texture2D? _arcadeDisplayTexture;
  UnlitMaterial? _arcadeDisplayMaterial;
  final Map<String, ui.Image> _arcadeCoverImages = <String, ui.Image>{};
  bool _arcadeCarouselAnimating = false;
  double _arcadeCarouselElapsed = 0.0;
  double _arcadeCarouselDuration = .20;
  double _arcadeDisplayRefreshAccumulator = 0.0;
  static const double _arcadeDisplayAnimationRefreshStep = 1.0 / 40.0;
  int _arcadeCarouselFromIndex = 0;
  int _arcadeCarouselToIndex = 0;
  int _arcadeCarouselDirection = 0;
  MeshGeometry? _arcadeDisplaySurfaceGeometry;
  Node? _arcadeJoystickPressHitboxNode;
  UnlitMaterial? _arcadeJoystickPressHitboxMaterial;
  bool _arcadeDisplayDirty = true;
  bool _arcadeDisplayRefreshInFlight = false;
  bool _arcadeDisplayEnabled = true;
  String _arcadeDisplaySideTitle = 'سوكي';
  String _arcadeDisplayCenterTitle = 'اختر لعبتك';
  int _arcadeSelectedGameIndex = 0;
  double _arcadeDisplayBgR = 5.0;
  double _arcadeDisplayBgG = 17.0;
  double _arcadeDisplayBgB = 28.0;
  double _arcadeDisplayHeaderR = 8.0;
  double _arcadeDisplayHeaderG = 29.0;
  double _arcadeDisplayHeaderB = 43.0;
  double _arcadeDisplayAccentR = 76.0;
  double _arcadeDisplayAccentG = 244.0;
  double _arcadeDisplayAccentB = 255.0;
  double _arcadeDisplayCardR = 17.0;
  double _arcadeDisplayCardG = 27.0;
  double _arcadeDisplayCardB = 39.0;
  double _arcadeDisplaySelectedCardR = 6.0;
  double _arcadeDisplaySelectedCardG = 42.0;
  double _arcadeDisplaySelectedCardB = 53.0;
  double _arcadeDisplayTextR = 255.0;
  double _arcadeDisplayTextG = 255.0;
  double _arcadeDisplayTextB = 255.0;
  double _arcadeDisplaySubtextR = 143.0;
  double _arcadeDisplaySubtextG = 160.0;
  double _arcadeDisplaySubtextB = 177.0;
  double _arcadeDisplayArrowR = 255.0;
  double _arcadeDisplayArrowG = 199.0;
  double _arcadeDisplayArrowB = 63.0;
  double _arcadeDisplayFrameR = 124.0;
  double _arcadeDisplayFrameG = 255.0;
  double _arcadeDisplayFrameB = 223.0;
  bool _arcadeDisplayShowSubtitle = true;
  double _arcadeDisplayHeaderOffsetX = 0.0;
  double _arcadeDisplayHeaderOffsetY = 0.0;
  double _arcadeDisplayHeaderScale = 1.0;
  double _arcadeDisplaySideTitleOffsetX = 0.0;
  double _arcadeDisplaySideTitleOffsetY = 0.0;
  double _arcadeDisplaySideTitleScale = 1.0;
  double _arcadeDisplayCenterTitleOffsetX = 0.0;
  double _arcadeDisplayCenterTitleOffsetY = 0.0;
  double _arcadeDisplayCenterTitleScale = 1.0;
  double _arcadeDisplayCurrentGameOffsetX = 0.0;
  double _arcadeDisplayCurrentGameOffsetY = 0.0;
  double _arcadeDisplayCurrentGameScale = 1.0;
  double _arcadeDisplayCardsOffsetX = 0.0;
  double _arcadeDisplayCardsOffsetY = 0.0;
  double _arcadeDisplayCardsScale = 1.0;
  double _arcadeDisplayCardsGapScale = 1.0;
  double _arcadeDisplayArrowsOffsetX = 0.0;
  double _arcadeDisplayArrowsOffsetY = 0.0;
  double _arcadeDisplayArrowsScale = 1.0;
  double _arcadeDisplayDotsOffsetX = 0.0;
  double _arcadeDisplayDotsOffsetY = 0.0;
  double _arcadeDisplayDotsScale = 1.0;
  double _arcadeDisplayHintOffsetX = 0.0;
  double _arcadeDisplayHintOffsetY = 0.0;
  double _arcadeDisplayHintScale = 1.0;

  bool _showArcadeJoystickPressHitbox = false;
  double _arcadeJoystickPressHitboxX = 41.0;
  double _arcadeJoystickPressHitboxY = -.86;
  double _arcadeJoystickPressHitboxZ = 38.0;
  double _arcadeJoystickPressHitboxSizeX = 2.20;
  double _arcadeJoystickPressHitboxSizeY = 2.20;
  double _arcadeJoystickPressHitboxSizeZ = 4.89;
  bool _arcadeJoystickPressPreview = false;
  double _arcadeJoystickPreviewDirection = 1.0;
  bool _arcadeScreenGestureActive = false;
  double _arcadeScreenGestureDx = 0.0;

  double _arcadeJoystickPressDuration = .010;
  double _arcadeJoystickReturnDuration = .18;
  double _arcadeJoystickPressOffsetX = -9.0;
  double _arcadeJoystickPressOffsetY = -.035;
  double _arcadeJoystickPressOffsetZ = 12.0;
  double _arcadeJoystickTiltPitch = 0.0;
  double _arcadeJoystickTiltYaw = 16.0;
  double _arcadeJoystickTiltRoll = 0.0;

  // Previous browsing has its own complete animation settings.
  double _arcadeJoystickPreviousPressDuration = .010;
  double _arcadeJoystickPreviousReturnDuration = .180;
  double _arcadeJoystickPreviousOffsetX = 9.0;
  double _arcadeJoystickPreviousOffsetY = -.035;
  double _arcadeJoystickPreviousOffsetZ = 12.0;
  double _arcadeJoystickPreviousTiltPitch = 0.0;
  double _arcadeJoystickPreviousTiltYaw = -16.0;
  double _arcadeJoystickPreviousTiltRoll = 0.0;

  bool _arcadeJoystickAnimating = false;
  double _arcadeJoystickAnimElapsed = 0.0;
  double _arcadeJoystickAnimDirection = 0.0;
  bool _arcadeJoystickPeakFrameShown = false;
  double _arcadeJoystickPeakHoldElapsed = 0.0;
  double _arcadeJoystickPreviousPeakHold = .080;

  // Extra path compensation applied ONLY while PREVIOUS is returning.
  // Useful to cancel/control the visual arc caused by the joystick pivot.
  double _arcadeJoystickPreviousReturnCompX = -5.0;
  double _arcadeJoystickPreviousReturnCompY = -10.0;
  double _arcadeJoystickPreviousReturnCompZ = 0.0;
  double _arcadeJoystickPreviousReturnCompStrength = 1.0;

  Node? _arcadeEnterButtonNode;
  Node? _arcadeEnterButtonRedMotionNode;
  Node? _arcadeEnterButtonRedHitNode;
  vm.Vector3 _arcadeEnterButtonRedBasePosition = vm.Vector3.zero();
  vm.Quaternion _arcadeEnterButtonRedBaseRotation = vm.Quaternion.identity();
  vm.Vector3 _arcadeEnterButtonRedBaseScale = vm.Vector3.all(1);
  bool _showArcadeEnterButton = true;
  double _arcadeEnterButtonX = -17.50;
  double _arcadeEnterButtonY = 20.00;
  double _arcadeEnterButtonZ = -21.20;
  double _arcadeEnterButtonRotX = 0.0;
  double _arcadeEnterButtonRotY = 0.0;
  double _arcadeEnterButtonRotZ = 0.0;
  double _arcadeEnterButtonScaleX = .75;
  double _arcadeEnterButtonScaleY = .75;
  double _arcadeEnterButtonScaleZ = .75;
  double _arcadeEnterButtonPressDuration = .10;
  double _arcadeEnterButtonReturnDuration = .16;
  double _arcadeEnterButtonPressDepth = 4.0;
  bool _arcadeEnterButtonRedColorEnabled = true;
  double _arcadeEnterButtonRedR = 47.0;
  double _arcadeEnterButtonRedG = 0.0;
  double _arcadeEnterButtonRedB = 14.0;
  UnlitMaterial? _arcadeEnterButtonRedMaterial;
  bool _arcadeEnterButtonPreviewPressed = false;
  bool _arcadeEnterButtonAnimating = false;
  double _arcadeEnterButtonAnimElapsed = 0.0;
  bool _arcadeEnterButtonOpenGameOnPress = false;
  bool _arcadeEnterButtonNavigationTriggered = false;

  double _characterX = 3.4600;
  double _characterY = 0.3600;
  double _characterZ = 0.4600;
  double _characterRotX = 0.0;
  double _characterRotY = 111.0;
  double _characterRotZ = 0.0;
  double _characterScaleX = 1.3800;
  double _characterScaleY = 1.3800;
  double _characterScaleZ = 1.3800;


  bool _arcadeHighlightVisible = true;
  double _arcadeX = -1.4800;
  double _arcadeY = 1.6500;
  double _arcadeZ = -1.6900;
  double _arcadeRotX = 0.0;
  double _arcadeRotY = -25.0;
  double _arcadeRotZ = 0.0;
  double _arcadeSizeX = 1.4400;
  double _arcadeSizeY = 4.0000;
  double _arcadeSizeZ = 1.6000;
  double _arcadeGlowThickness = .0000;
  double _arcadeGlowIntensity = .6500;
  double _arcadeGlowOpacity = 1.0000;
  double _arcadeGlowR = 97;
  double _arcadeGlowG = 54;
  double _arcadeGlowB = 224;
  double _arcadeGlowTopR = 29.0;
  double _arcadeGlowTopG = 255.0;
  double _arcadeGlowTopB = 0.0;
  double _arcadeGlowTopOpacity = .18;
  double _arcadeGlowBottomR = 29.0;
  double _arcadeGlowBottomG = 255.0;
  double _arcadeGlowBottomB = 0.0;
  double _arcadeGlowBottomOpacity = .55;
  double _arcadeGlowBlendMidpoint = .50;
  bool _arcadeGlowAutoRotate = true;
  double _arcadeGlowRotationSpeed = 18.0;
  bool _arcadeGlowRotateRight = true;
  double _arcadeGlowSpinAngle = 0.0;
  bool _arcadeGlowAutoBob = true;
  double _arcadeGlowBobAmount = .0600;
  double _arcadeGlowBobSpeed = .45;
  double _arcadeGlowBobPhase = 0.0;
  double _arcadeFocusCameraX = .6100;
  double _arcadeFocusCameraY = 4.0400;
  double _arcadeFocusCameraZ = -.3300;
  double _arcadeFocusTargetX = -.5800;
  double _arcadeFocusTargetY = 3.3400;
  double _arcadeFocusTargetZ = -.8800;
  double _arcadeFocusFov = 48.0;
  double _arcadeTransitionSeconds = 1.0;
  bool _arcadeCameraAnimating = false;
  double _arcadeCameraTransitionElapsed = 0;
  double _arcadePulseClock = 0;
  double _arcadeStartCameraX = 0;
  double _arcadeStartCameraY = 0;
  double _arcadeStartCameraZ = 0;
  double _arcadeStartTargetX = 0;
  double _arcadeStartTargetY = 0;
  double _arcadeStartTargetZ = 0;
  double _arcadeStartFov = 0;

  // Camera position before entering the arcade, used by the Back card.
  double _arcadeOriginCameraX = 0;
  double _arcadeOriginCameraY = 0;
  double _arcadeOriginCameraZ = 0;
  double _arcadeOriginTargetX = 0;
  double _arcadeOriginTargetY = 0;
  double _arcadeOriginTargetZ = 0;
  double _arcadeOriginFov = 48;
  bool _arcadeCameraReturning = false;

  double _arcadeEditRestoreCameraX = 0;
  double _arcadeEditRestoreCameraY = 0;
  double _arcadeEditRestoreCameraZ = 0;
  double _arcadeEditRestoreTargetX = 0;
  double _arcadeEditRestoreTargetY = 0;
  double _arcadeEditRestoreTargetZ = 0;
  double _arcadeEditRestoreFov = 0;
  double _arcadeEditOriginalFocusCameraX = 0;
  double _arcadeEditOriginalFocusCameraY = 0;
  double _arcadeEditOriginalFocusCameraZ = 0;
  double _arcadeEditOriginalFocusTargetX = 0;
  double _arcadeEditOriginalFocusTargetY = 0;
  double _arcadeEditOriginalFocusTargetZ = 0;
  double _arcadeEditOriginalFocusFov = 0;

  String _selectedTrackId = 'camera';
  bool _motionPlaying = false;
  bool _motionLoop = true;
  double _motionClock = 0.0;
  double _newKeyframeDuration = 1.20;

  @override
  void initState() {
    super.initState();
    _applyFactoryDefaults();
    _syncCameraAnglesFromCurrentView();
    _initializeMotionTracks();
    _applyFactoryMotionDefaults();
    _startEngine();
    unawaited(_bootstrap());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _engineTimer?.cancel();
    _keyboardFocusNode.dispose();
    for (final image in _arcadeCoverImages.values) {
      image.dispose();
    }
    _arcadeCoverImages.clear();
    super.dispose();
  }

  void _applyFactoryDefaults() {
    _showRoom = true;
    _showCharacter = true;
    _showGuide = false;
    _renderScale = .8000;
    _sceneExposure = 1.4400;
    _lightIntensity = .6500;
    _lightYawDeg = -48.0;
    _lightPitchDeg = -58.0;

    _cameraX = 4.0209;
    _cameraY = 3.3069;
    _cameraZ = 2.6723;
    _targetX = 2.8533;
    _targetY = 2.9428;
    _targetZ = 1.8280;
    _cameraFov = 48.0;
    _cameraMoveSpeed = 2.0000;
    _mouseSensitivity = 0.0052;

    _userStartCameraX = 4.0209;
    _userStartCameraY = 3.3069;
    _userStartCameraZ = 2.6723;
    _userStartTargetX = 2.8205;
    _userStartTargetY = 2.9750;
    _userStartTargetZ = 1.8614;
    _userStartFov = 48.0;

    _mainLookLeftDeg = 2.0;
    _mainLookRightDeg = 6.0;
    _mainLookUpDeg = 2.0;
    _mainLookDownDeg = 4.0;
    _arcadeLookLeftDeg = 0.0;
    _arcadeLookRightDeg = 0.0;
    _arcadeLookUpDeg = 0.0;
    _arcadeLookDownDeg = 0.0;

    _roomX = 0.3150;
    _roomY = 0.0000;
    _roomZ = 0.4250;
    _roomRotX = 0.0;
    _roomRotY = 0.0;
    _roomRotZ = 0.0;
    _roomScaleX = 0.0900;
    _roomScaleY = 0.0900;
    _roomScaleZ = 0.0900;

    _showArcadeScreen = true;
    _arcadeScreenX = 0.0600;
    _arcadeScreenY = 0.8100;
    _arcadeScreenZ = 0.0700;
    _arcadeScreenRotX = 1.0;
    _arcadeScreenRotY = 0.0;
    _arcadeScreenRotZ = 0.0;
    _arcadeScreenScaleX = 1.0;
    _arcadeScreenScaleY = 1.0;
    _arcadeScreenScaleZ = 1.0;
    _arcadeScreenColorEnabled = false;
    _arcadeScreenColorR = 255.0;
    _arcadeScreenColorG = 255.0;
    _arcadeScreenColorB = 255.0;
    _arcadeScreenColorOpacity = 1.0;

    _showArcadeCutter = false;
    _cutterX = -28.3500;
    _cutterY = 22.3000;
    _cutterZ = -24.1500;
    _cutterLeft = 12.1100;
    _cutterRight = 2.6100;
    _cutterUp = 4.8100;
    _cutterDown = 5.6100;
    _cutterFront = 0.6600;
    _cutterBack = 0.0100;
    _cutterPitch = 65.0;
    _cutterYaw = -113.0;
    _cutterRoll = 0.0;
    _arcadeRemovedTriangles.clear();
    _arcadeCutParts.clear();
    _nextArcadeCutPartId = 1;
    _selectedArcadeCutPartId = null;

    _showArcadeJoystick = true;
    _arcadeJoystickX = 0.0;
    _arcadeJoystickY = 0.0;
    _arcadeJoystickZ = 0.0;
    _arcadeJoystickRotX = 0.0;
    _arcadeJoystickRotY = 0.0;
    _arcadeJoystickRotZ = 0.0;
    _arcadeJoystickScaleX = 1.0;
    _arcadeJoystickScaleY = 1.0;
    _arcadeJoystickScaleZ = 1.0;
    _arcadeJoystickColorEnabled = false;
    _arcadeJoystickColorR = 255.0;
    _arcadeJoystickColorG = 255.0;
    _arcadeJoystickColorB = 255.0;
    _arcadeJoystickColorOpacity = 1.0;
    _revealArcadeScreen = false;
    _revealArcadeJoystick = false;

    _arcadeDisplayEnabled = true;
    _arcadeDisplaySideTitle = 'سوكي';
    _arcadeDisplayCenterTitle = 'اختر لعبتك';
    _arcadeSelectedGameIndex = 2;
    _arcadeDisplayBgR = 5;
    _arcadeDisplayBgG = 17;
    _arcadeDisplayBgB = 28;
    _arcadeDisplayHeaderR = 8;
    _arcadeDisplayHeaderG = 29;
    _arcadeDisplayHeaderB = 43;
    _arcadeDisplayAccentR = 76;
    _arcadeDisplayAccentG = 244;
    _arcadeDisplayAccentB = 255;
    _arcadeDisplayCardR = 17;
    _arcadeDisplayCardG = 27;
    _arcadeDisplayCardB = 39;
    _arcadeDisplaySelectedCardR = 6;
    _arcadeDisplaySelectedCardG = 42;
    _arcadeDisplaySelectedCardB = 53;
    _arcadeDisplayTextR = 255;
    _arcadeDisplayTextG = 255;
    _arcadeDisplayTextB = 255;
    _arcadeDisplaySubtextR = 143;
    _arcadeDisplaySubtextG = 160;
    _arcadeDisplaySubtextB = 177;
    _arcadeDisplayArrowR = 255;
    _arcadeDisplayArrowG = 199;
    _arcadeDisplayArrowB = 63;
    _arcadeDisplayShowSubtitle = true;
    _arcadeDisplayHeaderOffsetX = 0;
    _arcadeDisplayHeaderOffsetY = 0;
    _arcadeDisplayHeaderScale = 1.0;
    _arcadeDisplaySideTitleOffsetX = 0;
    _arcadeDisplaySideTitleOffsetY = 0;
    _arcadeDisplaySideTitleScale = 1.0;
    _arcadeDisplayCenterTitleOffsetX = 0;
    _arcadeDisplayCenterTitleOffsetY = 0;
    _arcadeDisplayCenterTitleScale = 1.0;
    _arcadeDisplayCurrentGameOffsetX = 0;
    _arcadeDisplayCurrentGameOffsetY = 0;
    _arcadeDisplayCurrentGameScale = 2.0;
    _arcadeDisplayCardsOffsetX = 0;
    _arcadeDisplayCardsOffsetY = 0;
    _arcadeDisplayCardsScale = 1.0;
    _arcadeDisplayCardsGapScale = 1.00;
    _arcadeDisplayArrowsOffsetX = -10.50;
    _arcadeDisplayArrowsOffsetY = 491.50;
    _arcadeDisplayArrowsScale = 0.85;
    _arcadeDisplayDotsOffsetX = 0;
    _arcadeDisplayDotsOffsetY = 145.00;
    _arcadeDisplayDotsScale = 0.10;
    _arcadeDisplayHintOffsetX = -20.50;
    _arcadeDisplayHintOffsetY = 400.00;
    _arcadeDisplayHintScale = 0.10;
    _arcadeDisplayDirty = true;

    _arcadeJoystickPressDuration = 0.010;
    _arcadeJoystickReturnDuration = 0.180;
    _arcadeJoystickPressOffsetX = -9.0000;
    _arcadeJoystickPressOffsetY = -0.0350;
    _arcadeJoystickPressOffsetZ = 12.0000;
    _arcadeJoystickTiltPitch = 0.0;
    _arcadeJoystickTiltYaw = 16.0;
    _arcadeJoystickTiltRoll = 0.0;

    _arcadeJoystickPreviousPressDuration = 0.010;
    _arcadeJoystickPreviousReturnDuration = 0.170;
    _arcadeJoystickPreviousOffsetX = 53.0000;
    _arcadeJoystickPreviousOffsetY = -12.0700;
    _arcadeJoystickPreviousOffsetZ = -16.5400;
    _arcadeJoystickPreviousTiltPitch = -19.0;
    _arcadeJoystickPreviousTiltYaw = -62.0;
    _arcadeJoystickPreviousTiltRoll = 0.0;
    _arcadeJoystickPreviousPeakHold = .080;
    _arcadeJoystickPreviousReturnCompX = -5.0;
    _arcadeJoystickPreviousReturnCompY = -10.0;
    _arcadeJoystickPreviousReturnCompZ = 0.0;
    _arcadeJoystickPreviousReturnCompStrength = 1.0;

    _showArcadeJoystickPressHitbox = false;
    _arcadeJoystickPressHitboxX = 41.0000;
    _arcadeJoystickPressHitboxY = -0.8600;
    _arcadeJoystickPressHitboxZ = 38.0000;
    _arcadeJoystickPressHitboxSizeX = 2.2000;
    _arcadeJoystickPressHitboxSizeY = 2.2000;
    _arcadeJoystickPressHitboxSizeZ = 4.8900;
    _arcadeJoystickPressPreview = false;
    _arcadeJoystickPreviewDirection = 1.0;
    _arcadeJoystickAnimating = false;
    _arcadeJoystickAnimElapsed = 0;
    _arcadeJoystickAnimDirection = 0;

    _showArcadeEnterButton = true;
    _arcadeEnterButtonX = 25.8000;
    _arcadeEnterButtonY = 27.6600;
    _arcadeEnterButtonZ = 16.5500;
    _arcadeEnterButtonRotX = 94.0;
    _arcadeEnterButtonRotY = 9.0;
    _arcadeEnterButtonRotZ = 2.0;
    _arcadeEnterButtonScaleX = 1.2000;
    _arcadeEnterButtonScaleY = 1.2000;
    _arcadeEnterButtonScaleZ = 1.2000;
    _arcadeEnterButtonPressDuration = .050;
    _arcadeEnterButtonReturnDuration = .100;
    _arcadeEnterButtonPressDepth = 12.0000;
    _arcadeEnterButtonRedColorEnabled = true;
    _arcadeEnterButtonRedR = 47.0;
    _arcadeEnterButtonRedG = 0.0;
    _arcadeEnterButtonRedB = 14.0;
    _arcadeEnterButtonPreviewPressed = false;
    _arcadeEnterButtonAnimating = false;
    _arcadeEnterButtonAnimElapsed = 0;
    _arcadeEnterButtonOpenGameOnPress = false;
    _arcadeEnterButtonNavigationTriggered = false;

    _characterX = 1.2800;
    _characterY = 0.8000;
    _characterZ = 1.2600;
    _characterRotX = 2.0;
    _characterRotY = 104.0;
    _characterRotZ = 0.0;
    _characterScaleX = 1.3800;
    _characterScaleY = 1.3800;
    _characterScaleZ = 1.3800;

    for (final tuning in _poseTunings) {
      tuning
        ..rotX = 0
        ..rotY = 0
        ..rotZ = 0
        ..offsetX = 0
        ..offsetY = 0
        ..offsetZ = 0;
    }

    _pose('Neck')
      ..rotX = 8.16
      ..rotY = 8.88
      ..rotZ = -1.54
      ..offsetX = -.0100;
    _pose('Head')
      ..rotX = -7
      ..rotY = -46
      ..rotZ = -3
      ..offsetY = -.0200
      ..offsetZ = .0100;
    _pose('LeftShoulder')..rotX = 17.50;
    _pose('LeftArm')
      ..rotX = -59
      ..rotY = 14;
    _pose('LeftForeArm')..rotX = 49;
    _pose('RightShoulder')..rotX = 8.30;
    _pose('RightArm')
      ..rotX = -46
      ..rotY = 3
      ..rotZ = 30
      ..offsetY = .0200;
    _pose('RightForeArm')
      ..rotX = 26.12
      ..rotY = 10.18
      ..rotZ = 65.94
      ..offsetX = -.0329
      ..offsetZ = -.0129;
    _pose('RightHand')
      ..rotX = 8
      ..rotY = -38
      ..rotZ = -38
      ..offsetX = -.0700;
    _pose('LeftUpLeg')..rotZ = -70;
    _pose('LeftLeg')..rotZ = 75.89;
    _pose('RightUpLeg')..rotZ = 70;
    _pose('RightLeg')..rotZ = -68.65;

    _arcadeHighlightVisible = false;
    _arcadeX = -2.1600;
    _arcadeY = 1.7700;
    _arcadeZ = -2.1100;
    _arcadeRotX = 0.0;
    _arcadeRotY = -25.0;
    _arcadeRotZ = 2.0;
    _arcadeSizeX = 2.0000;
    _arcadeSizeY = 3.2200;
    _arcadeSizeZ = 2.3100;
    _arcadeGlowThickness = .0050;
    _arcadeGlowIntensity = 1.0500;
    _arcadeGlowOpacity = .8500;
    _arcadeGlowR = 134;
    _arcadeGlowG = 0;
    _arcadeGlowB = 0;
    _arcadeGlowTopR = 191.0;
    _arcadeGlowTopG = 0.0;
    _arcadeGlowTopB = 0.0;
    _arcadeGlowTopOpacity = .1000;
    _arcadeGlowBottomR = 255.0;
    _arcadeGlowBottomG = 0.0;
    _arcadeGlowBottomB = 17.0;
    _arcadeGlowBottomOpacity = .9500;
    _arcadeGlowBlendMidpoint = .4500;
    _arcadeGlowAutoRotate = true;
    _arcadeGlowRotationSpeed = 13.0;
    _arcadeGlowRotateRight = true;
    _arcadeGlowSpinAngle = 0.0;
    _arcadeGlowAutoBob = true;
    _arcadeGlowBobAmount = .0300;
    _arcadeGlowBobSpeed = .50;
    _arcadeGlowBobPhase = 0.0;

    _arcadeFocusCameraX = 1.3675;
    _arcadeFocusCameraY = 4.0117;
    _arcadeFocusCameraZ = -.6627;
    _arcadeFocusTargetX = .1677;
    _arcadeFocusTargetY = 3.2981;
    _arcadeFocusTargetZ = -1.1725;
    _arcadeFocusFov = 48.0;
    _arcadeTransitionSeconds = 1.0;
    _arcadeCameraAnimating = false;
    _arcadeCameraTransitionElapsed = 0;
    _arcadePulseClock = 0;
    _arcadeCameraEditMode = false;
    _arcadeFocusLocked = false;

    _userModeActive = true;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userLookVelocityYaw = 0;
    _userLookVelocityPitch = 0;
    _userCameraIdleSeconds = 0;
    _cameraMotionResumeBlendElapsed = 0;
    _lookLimitPreviewMode = '';

    _developerPanelOpen = false;
    _motionPanelOpen = false;
    _developerSection = 'values';
    _uiPreviewOnly = false;
    _motionPlaying = false;
    _motionLoop = true;
    _motionClock = 0;
    _newKeyframeDuration = 5.10;
    _selectedTrackId = 'camera';
  }


  _PoseTuning _pose(String nodeName) {
    for (final tuning in _poseTunings) {
      if (tuning.nodeName == nodeName) return tuning;
    }
    throw StateError('Unknown pose node $nodeName');
  }

  void _initializeMotionTracks() {
    _motionTracks.clear();
    _motionTracks['camera'] = _MotionTrack(id: 'camera', label: 'الكاميرا');
    _motionTracks['room'] = _MotionTrack(id: 'room', label: 'الماب');
    _motionTracks['character'] = _MotionTrack(id: 'character', label: 'الشخصية');
    _motionTracks['scene'] = _MotionTrack(id: 'scene', label: 'المشهد والإضاءة');
    for (final tuning in _poseTunings) {
      _motionTracks['bone:${tuning.nodeName}'] = _MotionTrack(
        id: 'bone:${tuning.nodeName}',
        label: 'عظم ${tuning.label}',
      );
    }
    _selectedTrackId = _motionTracks.keys.first;
  }

  void _applyFactoryMotionDefaults() {
    _MotionKeyframe cameraPoint(
      double duration,
      double cameraX,
      double cameraY,
      double cameraZ,
      double targetX,
      double targetY,
      double targetZ,
      double fov,
    ) {
      return _MotionKeyframe(
        durationSeconds: duration,
        snapshot: _TrackSnapshot(
          values: <String, double>{
            'cameraX': cameraX,
            'cameraY': cameraY,
            'cameraZ': cameraZ,
            'targetX': targetX,
            'targetY': targetY,
            'targetZ': targetZ,
            'cameraFov': fov,
          },
        ),
      );
    }

    void setBoneTrack(
      String nodeName,
      List<_MotionKeyframe> points,
    ) {
      final track = _motionTracks['bone:$nodeName'];
      if (track == null) return;
      track
        ..enabled = true
        ..keyframes = points;
    }

    final cameraTrack = _motionTracks['camera'];
    if (cameraTrack != null) {
      cameraTrack
        ..enabled = true
        ..keyframes = <_MotionKeyframe>[
          cameraPoint(5.10, 4.0209, 3.3069, 2.6723, 2.8205, 2.9750, 1.8614, 48),
          cameraPoint(5.10, 4.0509, 3.2869, 2.6723, 2.8205, 2.9750, 1.8614, 48),
          cameraPoint(5.10, 4.0109, 3.1669, 2.6723, 2.8205, 2.9750, 1.8614, 48),
          cameraPoint(5.10, 4.0409, 3.2869, 2.6723, 2.8205, 2.9750, 1.8614, 48),
          cameraPoint(5.10, 3.8836, 3.2873, 2.6723, 2.8205, 2.9750, 1.8614, 42),
          cameraPoint(5.10, 3.8836, 3.1873, 2.6723, 2.8205, 2.9750, 1.8614, 49),
        ];
    }

    _selectedTrackId = 'camera';
    _motionPlaying = false;
    _motionLoop = true;
    _newKeyframeDuration = 5.10;

    setBoneTrack('Neck', <_MotionKeyframe>[
      _boneKeyframe(3.00, 9, 8, -1, -.0100, 0, 0),
      _boneKeyframe(.65, 9, 8, -1, -.0100, 0, 0),
      _boneKeyframe(3.70, 12, 21, 2, -.0100, 0, 0),
      _boneKeyframe(5.25, 12, 22, 2, -.0100, 0, 0),
      _boneKeyframe(4.40, -1.9162, 19.3631, -7.9162, -.0100, 0, 0),
    ]);
    setBoneTrack('LeftShoulder', <_MotionKeyframe>[
      _boneKeyframe(2.00, 18, 0, 0, 0, 0, 0),
      _boneKeyframe(2.00, 13, 0, 0, 0, 0, 0),
    ]);
    setBoneTrack('RightShoulder', <_MotionKeyframe>[
      _boneKeyframe(2.00, 9, 0, 0, 0, 0, 0),
      _boneKeyframe(2.00, 2, 0, 0, 0, 0, 0),
    ]);
    setBoneTrack('RightForeArm', <_MotionKeyframe>[
      _boneKeyframe(5.10, 24, 13, 67, .0200, 0, -.0200),
      _boneKeyframe(5.10, 30, 5, 64, -.1300, 0, 0),
    ]);
    setBoneTrack('LeftLeg', <_MotionKeyframe>[
      _boneKeyframe(5.65, 0, 0, 77, 0, 0, 0),
      _boneKeyframe(1.70, 0, 0, 70, 0, 0, 0),
    ]);
    setBoneTrack('RightLeg', <_MotionKeyframe>[
      _boneKeyframe(2.30, 0, 0, -73, 0, 0, 0),
      _boneKeyframe(2.30, 0, 0, -68, 0, 0, 0),
    ]);
  }


  _MotionKeyframe _boneKeyframe(
    double duration,
    double rotX,
    double rotY,
    double rotZ,
    double offsetX,
    double offsetY,
    double offsetZ,
  ) {
    return _MotionKeyframe(
      durationSeconds: duration,
      snapshot: _TrackSnapshot(
        values: <String, double>{
          'rotX': rotX,
          'rotY': rotY,
          'rotZ': rotZ,
          'offsetX': offsetX,
          'offsetY': offsetY,
          'offsetZ': offsetZ,
        },
      ),
    );
  }

  void _startEngine() {
    _lastTickAt = DateTime.now();
    _engineTimer?.cancel();
    _engineTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now();
      final last = _lastTickAt ?? now;
      var dt = now.difference(last).inMicroseconds / 1000000.0;
      _lastTickAt = now;
      if (dt <= 0) return;
      if (dt > .05) dt = .05;

      _arcadePulseClock += dt;
      var changed = _tickArcadeGlowMotion(dt);
      _updateArcadeGlowMaterial();

      changed = _tickArcadeJoystickAnimation(dt) || changed;
      changed = _tickArcadeCarousel(dt) || changed;
      changed = _tickArcadeEnterButtonAnimation(dt) || changed;
      changed = _tickTvTransition(dt) || changed;
      changed = _tickTvIdleMotion(dt) || changed;

      _arcadeDisplayRefreshAccumulator += dt;
      final refreshReady = !_arcadeCarouselAnimating ||
          _arcadeDisplayRefreshAccumulator >=
              _arcadeDisplayAnimationRefreshStep;
      if (_arcadeDisplayDirty &&
          !_arcadeDisplayRefreshInFlight &&
          refreshReady) {
        _arcadeDisplayRefreshAccumulator = 0;
        unawaited(_refreshArcadeDisplayTexture());
      }
      if (_arcadeCameraAnimating) {
        changed = _tickArcadeCameraTransition(dt) || changed;
      } else {
        changed = _tickKeyboardMovement(dt) || changed;
        changed = _tickUserLookPhysics(dt) || changed;
        _tickUserCameraIdle(dt);
        if (_motionPlaying && !_arcadeFocusLocked && !_arcadeCameraEditMode) {
          changed = _tickMotion(dt) || changed;
        }
      }

      if (changed && mounted) setState(() {});
    });
  }

  Future<void> _bootstrap() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _restoreSavedSettings();
      await Scene.initializeStaticResources();
      _configureScene();
      await _loadRoom();
      await _loadTvModel();
      await _loadCharacter();
      await _buildSpaceBackdrop();
      await _loadArcadeCoverImages();
      _buildArcadeInteraction();
      await _refreshArcadeDisplayTexture(force: true);
      _syncCameraAnglesFromCurrentView();
      _applyAllTransforms(save: false, repaint: false);
      if (!mounted) return;

      _startUserMode();

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _loadRoom() async {
    final room = await Node.fromGlbAsset('assets/models/arcade_room.glb');
    room.name = 'arcade_room';
    _roomNode = room;

    _legacyArcadeScreenNode = room.getChildByName('ArcadeScreen');
    _legacyArcadeJoystickNode = room.getChildByName('ArcadeJoystick');

    _arcadeScreenNode = room.getChildByName('ArcadeCut_2') ?? _legacyArcadeScreenNode;
    _arcadeJoystickNode = room.getChildByName('ArcadeCut_1') ?? _legacyArcadeJoystickNode;

    if (_legacyArcadeScreenNode != null &&
        !identical(_legacyArcadeScreenNode, _arcadeScreenNode)) {
      _legacyArcadeScreenNode!.visible = false;
    }
    if (_legacyArcadeJoystickNode != null &&
        !identical(_legacyArcadeJoystickNode, _arcadeJoystickNode)) {
      _legacyArcadeJoystickNode!.visible = false;
    }

    final arcadeScreen = _arcadeScreenNode;
    if (arcadeScreen != null) {
      _arcadeScreenBasePosition = vm.Vector3.copy(arcadeScreen.position);
      _arcadeScreenBaseRotation = vm.Quaternion.copy(arcadeScreen.rotation);
      _arcadeScreenBaseScale = vm.Vector3.copy(arcadeScreen.scale);
      final mesh = arcadeScreen.mesh;
      if (mesh != null && mesh.primitives.isNotEmpty) {
        _arcadeScreenOriginalMesh = mesh;
        _arcadeScreenOriginalMaterial = mesh.primitives.first.material;
      }
    }

    final arcadeJoystick = _arcadeJoystickNode;
    if (arcadeJoystick != null) {
      _arcadeJoystickBasePosition = vm.Vector3.copy(arcadeJoystick.position);
      _arcadeJoystickBaseRotation = vm.Quaternion.copy(arcadeJoystick.rotation);
      _arcadeJoystickBaseScale = vm.Vector3.copy(arcadeJoystick.scale);
      final mesh = arcadeJoystick.mesh;
      if (mesh != null && mesh.primitives.isNotEmpty) {
        _arcadeJoystickOriginalMaterial = mesh.primitives.first.material;
      }
    }

    await _loadArcadeEnterButton(room);
    _buildArcadeDisplaySurface();
    _ensureArcadeJoystickPressHitbox();
    _requestArcadeDisplayRefresh();
    _scene.add(room);

    try {
      _arcadeCutSourceData = room.extractMeshData();
      final bodyNode = room.getChildByName('ArcadeBody') ?? room.getChildByName('Box002_Material #749_0');
      final bodyMesh = bodyNode?.mesh;
      if (bodyMesh != null && bodyMesh.primitives.isNotEmpty) {
        _arcadeCutSourceMaterial = bodyMesh.primitives.first.material;
      }
    } catch (_) {
      _arcadeCutSourceData = null;
      _arcadeCutSourceMaterial = null;
    }

    _ensureArcadePartRevealNodes();
    _ensureArcadeCutterNode();
  }



  Future<void> _loadTvModel() async {
    final tv = await Node.fromGlbAsset('assets/models/arcade_tv_split.glb');
    tv.name = 'arcade_tv_test';
    _tvNode = tv;
    _tvScreenNode = tv.getChildByName('TVScreen');

    final mesh = _tvScreenNode?.mesh;
    if (mesh != null && mesh.primitives.isNotEmpty) {
      _tvScreenOriginalMesh = mesh;
      _tvScreenOriginalMaterial = mesh.primitives.first.material;
    }

    _buildTvGameScreenGeometry();

    _scene.add(tv);
    _applyTvTransform();
    unawaited(_refreshTvGameScreen());
  }


  void _buildTvGameScreenGeometry() {
    final screen = _tvScreenNode;
    if (screen == null || _tvGameScreenGeometry != null) return;

    try {
      final data = screen.extractMeshData();
      final positions = Float32List.fromList(data.positions);

      // Do NOT reuse the model's original atlas UVs here.
      // TVScreen lies almost completely in the local X/Z plane:
      //   +X = visible right
      //   +Z = visible up
      // Generate clean planar UVs directly from the actual screen geometry.
      var minX = double.infinity;
      var maxX = -double.infinity;
      var minZ = double.infinity;
      var maxZ = -double.infinity;

      for (var i = 0; i + 2 < positions.length; i += 3) {
        final x = positions[i];
        final z = positions[i + 2];
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minZ = math.min(minZ, z);
        maxZ = math.max(maxZ, z);
      }

      final rangeX = math.max(.000001, maxX - minX);
      final rangeZ = math.max(.000001, maxZ - minZ);
      final texCoords = Float32List((positions.length ~/ 3) * 2);

      for (var vertex = 0; vertex < positions.length ~/ 3; vertex++) {
        final p = vertex * 3;
        final t = vertex * 2;
        final x = positions[p];
        final z = positions[p + 2];

        // Flip horizontally only so the content reads correctly on the TV.
        texCoords[t] =
            (1.0 - ((x - minX) / rangeX)).clamp(0.0, 1.0);

        // Texture V grows downward while local +Z is visible upward.
        texCoords[t + 1] =
            (1.0 - ((z - minZ) / rangeZ)).clamp(0.0, 1.0);
      }

      _tvGameScreenGeometry = MeshGeometry.fromArrays(
        positions: positions,
        normals: data.normals == null
            ? null
            : Float32List.fromList(data.normals!),
        texCoords: texCoords,
        texCoords1: data.texCoords1 == null
            ? null
            : Float32List.fromList(data.texCoords1!),
        colors: data.colors == null
            ? null
            : Float32List.fromList(data.colors!),
        tangents: data.tangents == null
            ? null
            : Float32List.fromList(data.tangents!),
        indices: data.indices,
        retainCpuData: true,
      );
    } catch (_) {
      _tvGameScreenGeometry = null;
    }
  }

  Future<void> _refreshTvGameScreen() async {
    if (_tvGameScreenRefreshInFlight || _tvScreenNode == null) return;
    _tvGameScreenRefreshInFlight = true;
    try {
      final index = _tvSelectedGameIndex
          .clamp(0, _arcadeGames.length - 1)
          .toInt();
      final texture = await _makeTvGameScreenTexture(index);
      _tvGameScreenTexture = texture;

      final material =
          _tvGameScreenMaterial ?? _unlit(const Color(0xFFFFFFFF));
      material
        ..name = 'tv_dynamic_game_screen'
        ..baseColorTexture = texture
        ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
        ..vertexColorWeight = 0
        ..doubleSided = true
        ..alphaMode = AlphaMode.opaque;
      _tvGameScreenMaterial = material;

      final screen = _tvScreenNode;
      final geometry = _tvGameScreenGeometry;
      if (screen != null && geometry != null && !_tvScreenHighlight) {
        screen.mesh = Mesh(geometry, material);
      }
      if (mounted) setState(() {});
    } finally {
      _tvGameScreenRefreshInFlight = false;
    }
  }

  Future<Texture2D> _makeTvGameScreenTexture(int gameIndex) async {
    // IMPORTANT: keep the TV renderer on the same proven drawing path that
    // the original screen used successfully. Do not switch to a primitive
    // emergency picture; that was the reason the user saw coloured blocks.
    return _makeTvGameScreenClassicTexture(gameIndex);
  }

  Future<Texture2D> _makeTvGameScreenClassicTexture(int gameIndex) async {
    const width = 768;
    const height = 1024;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size(width.toDouble(), height.toDouble());

    final game = _arcadeGames[
        gameIndex.clamp(0, _arcadeGames.length - 1).toInt()];

    void textAt(
      String value,
      Rect rect,
      double fontSize,
      Color color, {
      FontWeight weight = FontWeight.w900,
      int? maxLines,
      String? fontFamily,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            fontFamily: fontFamily,
            height: 1.08,
            shadows: const <Shadow>[
              Shadow(
                color: Color(0xAA000000),
                offset: Offset(3, 4),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: rect.width);

      painter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - painter.width) * .5,
          rect.top + (rect.height - painter.height) * .5,
        ),
      );
    }

    // -----------------------------------------------------------------
    // BACKGROUND — same visual language as the real arcade display.
    // This deliberately uses only the same drawing operations that the
    // original working TV renderer used (rects, rrects, paths, text,
    // and linear gradients).
    // -----------------------------------------------------------------
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(0, 1024),
          const <Color>[
            Color(0xFF071427),
            Color(0xFF0B2B47),
            Color(0xFF123758),
            Color(0xFF111827),
          ],
          const <double>[0, .35, .70, 1],
        ),
    );

    // Pixel wall / cabinet silhouettes.
    final wallPaint = Paint()..color = const Color(0xFF17436A);
    final wallDarkPaint = Paint()..color = const Color(0xFF0B243D);
    for (final r in const <Rect>[
      Rect.fromLTWH(62, 226, 92, 118),
      Rect.fromLTWH(156, 265, 70, 134),
      Rect.fromLTWH(236, 214, 104, 158),
      Rect.fromLTWH(428, 214, 104, 158),
      Rect.fromLTWH(542, 265, 70, 134),
      Rect.fromLTWH(614, 226, 92, 118),
    ]) {
      canvas.drawRect(r, wallPaint);
      canvas.drawRect(
        Rect.fromLTWH(r.left + 12, r.top + 16, r.width * .42, 12),
        wallDarkPaint,
      );
    }

    // Top truss.
    canvas.drawRect(
      const Rect.fromLTWH(0, 36, 768, 18),
      Paint()..color = const Color(0xFF182337),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 96, 768, 12),
      Paint()..color = const Color(0xFF25324C),
    );
    for (double x = 0; x < 768; x += 96) {
      canvas.drawRect(
        Rect.fromLTWH(x, 36, 9, 70),
        Paint()..color = const Color(0xFF33425D),
      );
      canvas.drawLine(
        Offset(x, 44),
        Offset(x + 78, 96),
        Paint()
          ..color = const Color(0xFF33425D)
          ..strokeWidth = 5,
      );
      canvas.drawLine(
        Offset(x + 78, 44),
        Offset(x, 96),
        Paint()
          ..color = const Color(0xFF33425D)
          ..strokeWidth = 5,
      );
    }

    // Arcade lamps and warm cones.
    for (final cx in const <double>[185, 583]) {
      final cone = ui.Path()
        ..moveTo(cx - 42, 105)
        ..lineTo(cx + 42, 105)
        ..lineTo(cx + 88, 286)
        ..lineTo(cx - 88, 286)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, 105),
            Offset(cx, 286),
            const <Color>[
              Color(0x55FF9D1A),
              Color(0x00FF9D1A),
            ],
          ),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 92), width: 76, height: 20),
        Paint()..color = const Color(0xFF8E2B18),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 108), width: 48, height: 12),
        Paint()..color = const Color(0xFFFFB526),
      );
    }

    // Side machine rails.
    for (final left in const <double>[30, 712]) {
      canvas.drawRect(
        Rect.fromLTWH(left, 155, 26, 650),
        Paint()..color = const Color(0xFF24324D),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 5, 205, 16, 420),
        Paint()..color = const Color(0xFFD67B0C),
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 8, 212, 10, 405),
        Paint()..color = const Color(0xFFFFB72A),
      );
    }

    // Pixel floor.
    canvas.drawRect(
      const Rect.fromLTWH(0, 822, 768, 202),
      Paint()..color = const Color(0xFF32171B),
    );
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 11; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * 76.0 - 20, 822 + row * 38.0, 72, 34),
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFF7D261C)
                : const Color(0xFF451B1C),
        );
      }
    }

    // Outer cabinet frame.
    final outerFrame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 28, 712, 968),
      const Radius.circular(34),
    );
    canvas.drawRRect(
      outerFrame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..color = const Color(0xFFD6790D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 44, 680, 936),
        const Radius.circular(27),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFB41F),
    );

    // -----------------------------------------------------------------
    // TITLE MARQUEE — red metal + gold frame, same arcade family.
    // -----------------------------------------------------------------
    final titleScale = _tvUiTitleScale.clamp(.55, 1.45).toDouble();
    final titleRect = Rect.fromLTWH(
      170 + _tvUiTitleOffsetX,
      52 + _tvUiTitleOffsetY,
      428,
      132,
    );
    final titleOuter = RRect.fromRectAndRadius(
      titleRect,
      const Radius.circular(17),
    );
    canvas.drawRRect(titleOuter, Paint()..color = const Color(0xFFD6790D));
    canvas.drawRRect(
      titleOuter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFFFB41F),
    );
    final titleInner = RRect.fromRectAndRadius(
      titleRect.deflate(13),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      titleInner,
      Paint()
        ..shader = ui.Gradient.linear(
          titleRect.topCenter,
          titleRect.bottomCenter,
          const <Color>[
            Color(0xFFE63A22),
            Color(0xFFB72324),
            Color(0xFF86181C),
          ],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
    for (final p in <Offset>[
      Offset(titleRect.left + 22, titleRect.top + 22),
      Offset(titleRect.right - 22, titleRect.top + 22),
      Offset(titleRect.left + 22, titleRect.bottom - 22),
      Offset(titleRect.right - 22, titleRect.bottom - 22),
    ]) {
      canvas.drawCircle(p, 7, Paint()..color = const Color(0xFF6F360A));
      canvas.drawCircle(
        p.translate(-2, -2),
        3,
        Paint()..color = const Color(0xFFFFC23A),
      );
    }
    textAt(
      game.title,
      titleRect.deflate(22),
      42 * titleScale,
      const Color(0xFFFFD45A),
      maxLines: 2,
      fontFamily: 'PCB',
    );

    // Back button — exact hitbox is preserved.
    const backRect = Rect.fromLTWH(58, 62, 94, 94);
    final backRRect = RRect.fromRectAndRadius(
      backRect,
      const Radius.circular(14),
    );
    canvas.drawRRect(
      backRRect.shift(const Offset(6, 8)),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(backRRect, Paint()..color = const Color(0xFFD67A0B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(backRect.deflate(8), const Radius.circular(9)),
      Paint()..color = const Color(0xFF071523),
    );
    canvas.drawRRect(
      backRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFC636),
    );
    final backPath = ui.Path()
      ..moveTo(119, 84)
      ..lineTo(87, 109)
      ..lineTo(119, 134);
    canvas.drawPath(
      backPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFD45A),
    );

    // -----------------------------------------------------------------
    // SELECTED GAME CARD — same green selected frame + gold arcade trim.
    // No runtime image decoding is done here. This intentionally keeps
    // the renderer on the proven stable path and removes the crash source.
    // -----------------------------------------------------------------
    const cardRect = Rect.fromLTWH(205, 238, 358, 404);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cardRect.translate(9, 12),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xAA090609),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.inflate(12), const Radius.circular(24)),
      Paint()..color = const Color(0xFF4D220F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.inflate(12), const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0xFFD87612),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.inflate(5), const Radius.circular(20)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFB52B),
    );

    final selectedFrame = RRect.fromRectAndRadius(
      cardRect,
      const Radius.circular(16),
    );
    canvas.drawRRect(selectedFrame, Paint()..color = const Color(0xFF007C5D));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect.deflate(12), const Radius.circular(11)),
      Paint()
        ..shader = ui.Gradient.linear(
          cardRect.topCenter,
          cardRect.bottomCenter,
          const <Color>[
            Color(0xFF103854),
            Color(0xFF0A2137),
            Color(0xFF071523),
          ],
          const <double>[0.0, 0.55, 1.0],
        ),
    );

    // Pixel accents inside the selected card.
    final inner = cardRect.deflate(30);
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.top + 12, inner.width, 8),
      Paint()..color = const Color(0xFF00A77E),
    );
    canvas.drawRect(
      Rect.fromLTWH(inner.left + 20, inner.top + 44, inner.width - 40, 4),
      Paint()..color = const Color(0x335CE7D0),
    );
    for (final x in <double>[inner.left + 12, inner.right - 20]) {
      canvas.drawRect(
        Rect.fromLTWH(x, inner.top + 78, 8, 178),
        Paint()..color = const Color(0xFF18506B),
      );
    }

    textAt(
      'اللعبة المختارة',
      Rect.fromLTWH(cardRect.left + 34, cardRect.top + 54, cardRect.width - 68, 46),
      22,
      const Color(0xFF76F1D1),
      maxLines: 1,
      fontFamily: 'PCB',
    );
    textAt(
      game.title,
      Rect.fromLTWH(cardRect.left + 38, cardRect.top + 112, cardRect.width - 76, 112),
      43,
      const Color(0xFFFFD45A),
      maxLines: 2,
      fontFamily: 'PCB',
    );
    textAt(
      game.subtitle,
      Rect.fromLTWH(cardRect.left + 48, cardRect.top + 236, cardRect.width - 96, 112),
      21,
      const Color(0xFFE8F5FF),
      weight: FontWeight.w700,
      maxLines: 4,
    );

    for (final p in <Offset>[
      Offset(cardRect.left, cardRect.top),
      Offset(cardRect.right, cardRect.top),
      Offset(cardRect.left, cardRect.bottom),
      Offset(cardRect.right, cardRect.bottom),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 22, height: 22),
        Paint()..color = const Color(0xFFFFA916),
      );
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 9, height: 9),
        Paint()..color = const Color(0xFFFFE063),
      );
    }

    // -----------------------------------------------------------------
    // MODE BUTTONS — exact current hitboxes (Y=720) are preserved.
    // -----------------------------------------------------------------
    final buttonScale = _tvUiButtonsScale.clamp(.35, 4.0).toDouble();
    final gap = 26 * _tvUiButtonsGap.clamp(.3, 4.0).toDouble();
    final bw = 250 * buttonScale;
    final bh = 116 * buttonScale;
    final groupWidth = bw * 2 + gap;
    final startX = (768 - groupWidth) * .5 + _tvUiButtonsOffsetX;
    final by = 720 + _tvUiButtonsOffsetY;

    final modeLabelRect = Rect.fromLTWH(226, by - 66, 316, 46);
    canvas.drawRRect(
      RRect.fromRectAndRadius(modeLabelRect, const Radius.circular(11)),
      Paint()..color = const Color(0xFFE28A12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(modeLabelRect.deflate(7), const Radius.circular(7)),
      Paint()..color = const Color(0xFF071826),
    );
    textAt(
      'اختر طريقة اللعب',
      modeLabelRect.deflate(6),
      22,
      const Color(0xFFFFD15A),
      fontFamily: 'PCB',
    );

    void gameButton(Rect rect, String label, Color color, bool enabled) {
      final outer = RRect.fromRectAndRadius(rect, const Radius.circular(15));
      canvas.drawRRect(
        outer.shift(const Offset(7, 9)),
        Paint()..color = const Color(0x99000000),
      );
      canvas.drawRRect(outer, Paint()..color = const Color(0xFF4D220F));
      canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const Color(0xFFD87612),
      );

      final innerRect = rect.deflate(9);
      final activeColor = enabled ? color : const Color(0xFF414851);
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerRect, const Radius.circular(9)),
        Paint()
          ..shader = ui.Gradient.linear(
            innerRect.topCenter,
            innerRect.bottomCenter,
            <Color>[
              Color.lerp(activeColor, Colors.white, enabled ? .13 : .03)!,
              activeColor,
              Color.lerp(activeColor, Colors.black, .28)!,
            ],
            const <double>[0.0, 0.52, 1.0],
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerRect, const Radius.circular(9)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = enabled
              ? const Color(0xFFFFC02B)
              : const Color(0xFF7B713C),
      );
      textAt(
        label,
        rect,
        31 * buttonScale,
        Colors.white.withOpacity(enabled ? 1 : .45),
        maxLines: 1,
      );
    }

    gameButton(
      Rect.fromLTWH(startX, by, bw, bh),
      'ابدأ اللعب',
      const Color(0xFF078968),
      game.hasOffline,
    );
    gameButton(
      Rect.fromLTWH(startX + bw + gap, by, bw, bh),
      'العب مع صديق',
      const Color(0xFF2369C8),
      game.hasOnline,
    );

    // Info button — exact hitbox preserved.
    final infoScale = _tvUiInfoScale.clamp(.4, 3.0).toDouble();
    final infoSize = 92 * infoScale;
    final infoRect = Rect.fromLTWH(
      768 - 72 - infoSize + _tvUiInfoOffsetX,
      1024 - 72 - infoSize + _tvUiInfoOffsetY,
      infoSize,
      infoSize,
    );
    final infoOuter = RRect.fromRectAndRadius(
      infoRect,
      const Radius.circular(14),
    );
    canvas.drawRRect(
      infoOuter.shift(const Offset(6, 8)),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(infoOuter, Paint()..color = const Color(0xFFD67A0B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(infoRect.deflate(8), const Radius.circular(9)),
      Paint()..color = const Color(0xFF9C2020),
    );
    canvas.drawRRect(
      infoOuter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFC83B),
    );
    textAt(
      '!',
      infoRect,
      40 * infoScale,
      const Color(0xFFFFF1B2),
    );

    // Details panel — same stable drawing path and arcade palette.
    if (_tvDetailsVisible && !game.isBack) {
      final ps = _tvUiPanelScale.clamp(.55, 1.25).toDouble();
      final panelRect = Rect.fromLTWH(
        78 + _tvUiPanelOffsetX,
        214 + _tvUiPanelOffsetY,
        612 * ps,
        594 * ps,
      );
      final panel = RRect.fromRectAndRadius(
        panelRect,
        Radius.circular(22 * ps),
      );
      canvas.drawRRect(
        panel.shift(Offset(10 * ps, 12 * ps)),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRRect(panel, Paint()..color = const Color(0xFFD6790D));

      final panelInnerRect = panelRect.deflate(13 * ps);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          panelInnerRect,
          Radius.circular(15 * ps),
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            panelInnerRect.topCenter,
            panelInnerRect.bottomCenter,
            const <Color>[
              Color(0xFF123758),
              Color(0xFF0B2B47),
              Color(0xFF071427),
            ],
            const <double>[0.0, 0.55, 1.0],
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          panelInnerRect,
          Radius.circular(15 * ps),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * ps
          ..color = const Color(0xFF007C5D),
      );

      final panelTitleRect = Rect.fromLTWH(
        panelRect.left + 42 * ps,
        panelRect.top + 35 * ps,
        panelRect.width - 84 * ps,
        86 * ps,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(panelTitleRect, Radius.circular(10 * ps)),
        Paint()..color = const Color(0xFF9C2020),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(panelTitleRect, Radius.circular(10 * ps)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * ps
          ..color = const Color(0xFFD6790D),
      );
      textAt(
        game.detailsTitle,
        panelTitleRect.deflate(10 * ps),
        35 * ps,
        const Color(0xFFFFD45A),
        maxLines: 1,
      );
      textAt(
        game.detailsText,
        Rect.fromLTWH(
          panelRect.left + 54 * ps,
          panelRect.top + 150 * ps,
          panelRect.width - 108 * ps,
          330 * ps,
        ),
        26 * ps,
        Colors.white,
        weight: FontWeight.w700,
        maxLines: 7,
      );
    }

    // Light CRT scanlines only; no white/grey radial overlay.
    final scan = Paint()..color = Colors.black.withOpacity(.06);
    for (double y = 0; y < height; y += 8) {
      canvas.drawRect(Rect.fromLTWH(0, y, width.toDouble(), 2), scan);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  void _applyTvTransform() {
    final tv = _tvNode;
    if (tv == null) return;

    // In user mode the TV is hidden until a game is selected.
    // Developer mode always keeps it visible for placement/tuning.
    final userShouldSeeTv =
        !_userModeActive || _tvTransitionAnimating || _tvModeActive;

    var x = _tvX;
    var y = _tvY;
    var z = _tvZ;
    var rotX = _tvRotX;
    var rotY = _tvRotY;
    var rotZ = _tvRotZ;
    var scaleX = _tvScaleX;
    var scaleY = _tvScaleY;
    var scaleZ = _tvScaleZ;

    if (_tvTransitionAnimating) {
      final duration = math.max(.05, _tvEntryDuration);
      final raw =
          (_tvTransitionElapsed / duration).clamp(0.0, 1.0).toDouble();

      // Smootherstep: very soft start + soft landing.
      final t = raw * raw * raw * (raw * (raw * 6 - 15) + 10);

      double lerp(double a, double b) => a + (b - a) * t;

      x = lerp(_tvEntryStartX, _tvX);
      y = lerp(_tvEntryStartY, _tvY);
      z = lerp(_tvEntryStartZ, _tvZ);

      // Full-turn controls keep the final orientation exactly equal
      // to the final TV rotation while allowing dramatic spinning.
      rotX = lerp(_tvEntryStartRotX, _tvRotX) +
          360.0 * _tvEntrySpinXTurns * t;
      rotY = lerp(_tvEntryStartRotY, _tvRotY) +
          360.0 * _tvEntrySpinYTurns * t;
      rotZ = lerp(_tvEntryStartRotZ, _tvRotZ) +
          360.0 * _tvEntrySpinZTurns * t;

      scaleX = lerp(_tvEntryStartScaleX, _tvScaleX);
      scaleY = lerp(_tvEntryStartScaleY, _tvScaleY);
      scaleZ = lerp(_tvEntryStartScaleZ, _tvScaleZ);
    } else if (_tvModeActive && _tvIdleMotionEnabled) {
      final cycle = math.max(.20, _tvIdleCycleSeconds);
      final phase = (_tvIdleClock / cycle) * math.pi * 2;

      x += math.sin(phase) * _tvIdleMoveX;
      y += math.sin(phase * .83 + 1.10) * _tvIdleMoveY;
      z += math.sin(phase * 1.13 + 2.20) * _tvIdleMoveZ;

      rotX += math.sin(phase * .74 + .60) * _tvIdleRotX;
      rotY += math.sin(phase * .91 + 1.80) * _tvIdleRotY;
      rotZ += math.sin(phase * 1.07 + 2.70) * _tvIdleRotZ;
    }

    tv
      ..visible = _showTv && userShouldSeeTv
      ..position = vm.Vector3(x, y, z)
      ..rotation = _rotationFromDegrees(rotX, rotY, rotZ)
      ..scale = vm.Vector3(scaleX, scaleY, scaleZ);

    final screen = _tvScreenNode;
    if (screen == null) return;

    // TVScreen is part of the television itself and must never drift,
    // rotate, or scale independently. Keep its local transform natural.
    screen
      ..visible = _showTvScreen
      ..position = vm.Vector3.zero()
      ..rotation = vm.Quaternion.identity()
      ..scale = vm.Vector3.all(1.0);

    final geometry = _tvGameScreenGeometry;
    if (geometry != null) {
      if (_tvScreenHighlight) {
        final material =
            _tvScreenHighlightMaterial ?? _unlit(const Color(0xFFFF1744));
        material
          ..name = 'tv_screen_cut_highlight'
          ..baseColorFactor = _vectorColor(const Color(0xFFFF1744))
          ..vertexColorWeight = 0
          ..doubleSided = true
          ..alphaMode = AlphaMode.opaque;
        _tvScreenHighlightMaterial = material;

        final currentMesh = screen.mesh;
        final alreadyHighlight = currentMesh != null &&
            currentMesh.primitives.isNotEmpty &&
            identical(currentMesh.primitives.first.material, material);
        if (!alreadyHighlight) {
          screen.mesh = Mesh(geometry, material);
        }
      } else if (_tvGameScreenMaterial != null) {
        final material = _tvGameScreenMaterial!;
        material
          ..baseColorTexture = _tvGameScreenTexture
          ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
          ..vertexColorWeight = 0
          ..doubleSided = true
          ..alphaMode = AlphaMode.opaque;

        final currentMesh = screen.mesh;
        final alreadyDynamic = currentMesh != null &&
            currentMesh.primitives.isNotEmpty &&
            identical(currentMesh.primitives.first.material, material);
        if (!alreadyDynamic) {
          screen.mesh = Mesh(geometry, material);
        }
      } else if (_tvScreenOriginalMesh != null &&
          !identical(screen.mesh, _tvScreenOriginalMesh)) {
        screen.mesh = _tvScreenOriginalMesh;
      }
    }
  }

  Future<void> _loadArcadeEnterButton(Node room) async {
    final model = await Node.fromGlbAsset('assets/models/low_poly_button.glb');
    model.name = 'arcade_enter_button_model';

    final anchor = Node(name: 'arcade_enter_button_anchor');
    anchor.add(model);

    _arcadeEnterButtonNode = anchor;
    _arcadeEnterButtonRedMotionNode =
        model.getChildByName('Cube.001') ??
        model.getChildByName('Cube.001_Material.001_0');
    _arcadeEnterButtonRedHitNode =
        model.getChildByName('Cube.001_Material.001_0') ??
        _arcadeEnterButtonRedMotionNode;

    final red = _arcadeEnterButtonRedMotionNode;
    if (red != null) {
      _arcadeEnterButtonRedBasePosition = vm.Vector3.copy(red.position);
      _arcadeEnterButtonRedBaseRotation = vm.Quaternion.copy(red.rotation);
      _arcadeEnterButtonRedBaseScale = vm.Vector3.copy(red.scale);
    }
    _applyArcadeEnterButtonRedColor();

    final parent = room.getChildByName('Box002') ?? room;
    parent.add(anchor);
    _applyArcadeEnterButtonTransform();
  }

  void _applyArcadeEnterButtonRedColor() {
    final target = _arcadeEnterButtonRedHitNode ?? _arcadeEnterButtonRedMotionNode;
    if (target == null) return;

    final color = Color.fromARGB(
      255,
      _arcadeEnterButtonRedR.round().clamp(0, 255).toInt(),
      _arcadeEnterButtonRedG.round().clamp(0, 255).toInt(),
      _arcadeEnterButtonRedB.round().clamp(0, 255).toInt(),
    );
    final material = _arcadeEnterButtonRedMaterial ?? _unlit(color);
    material
      ..name = 'arcade_enter_button_red_custom_material'
      ..baseColorFactor = _vectorColor(color)
      ..vertexColorWeight = 0
      ..doubleSided = true
      ..alphaMode = AlphaMode.opaque;
    _arcadeEnterButtonRedMaterial = material;

    void applyTo(Node? node) {
      if (node == null) return;
      final mesh = node.mesh;
      if (mesh != null && mesh.primitives.isNotEmpty) {
        mesh.primitives.first.material = material;
      }
      for (final child in node.children) {
        applyTo(child);
      }
    }

    if (_arcadeEnterButtonRedColorEnabled) {
      applyTo(_arcadeEnterButtonRedMotionNode);
      if (!identical(_arcadeEnterButtonRedHitNode, _arcadeEnterButtonRedMotionNode)) {
        applyTo(_arcadeEnterButtonRedHitNode);
      }
    }
  }

  double get _arcadeEnterButtonPressAmount {
    if (_arcadeEnterButtonPreviewPressed) return 1.0;
    if (!_arcadeEnterButtonAnimating) return 0.0;

    if (_arcadeEnterButtonAnimElapsed <= _arcadeEnterButtonPressDuration) {
      if (_arcadeEnterButtonPressDuration <= 0) return 1.0;
      final t = (_arcadeEnterButtonAnimElapsed / _arcadeEnterButtonPressDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      return t * t * (3 - 2 * t);
    }

    if (_arcadeEnterButtonReturnDuration <= 0) return 0.0;
    final returnTime =
        _arcadeEnterButtonAnimElapsed - _arcadeEnterButtonPressDuration;
    final t = (returnTime / _arcadeEnterButtonReturnDuration)
        .clamp(0.0, 1.0)
        .toDouble();
    final eased = t * t * (3 - 2 * t);
    return 1.0 - eased;
  }

  void _applyArcadeEnterButtonTransform() {
    final button = _arcadeEnterButtonNode;
    if (button != null) {
      button
        ..visible = _showArcadeEnterButton
        ..position = vm.Vector3(
          _arcadeEnterButtonX,
          _arcadeEnterButtonY,
          _arcadeEnterButtonZ,
        )
        ..rotation = _rotationFromDegrees(
          _arcadeEnterButtonRotX,
          _arcadeEnterButtonRotY,
          _arcadeEnterButtonRotZ,
        )
        ..scale = vm.Vector3(
          _arcadeEnterButtonScaleX,
          _arcadeEnterButtonScaleY,
          _arcadeEnterButtonScaleZ,
        );
    }

    _applyArcadeEnterButtonRedColor();

    final red = _arcadeEnterButtonRedMotionNode;
    if (red != null) {
      final amount = _arcadeEnterButtonPressAmount;
      final pressedPosition =
          vm.Vector3.copy(_arcadeEnterButtonRedBasePosition)
            ..add(
              vm.Vector3(
                0,
                -_arcadeEnterButtonPressDepth * amount,
                0,
              ),
            );

      red
        ..position = pressedPosition
        ..rotation = vm.Quaternion.copy(_arcadeEnterButtonRedBaseRotation)
        ..scale = vm.Vector3.copy(_arcadeEnterButtonRedBaseScale);
    }
  }

  void _pressArcadeEnterButton({bool openGame = true}) {
    if (_arcadeEnterButtonAnimating) return;
    _arcadeEnterButtonPreviewPressed = false;
    _arcadeEnterButtonAnimating = true;
    _arcadeEnterButtonAnimElapsed = 0;
    _arcadeEnterButtonOpenGameOnPress = openGame;
    _arcadeEnterButtonNavigationTriggered = false;
    _applyArcadeEnterButtonTransform();
    if (mounted) setState(() {});
  }

  bool _tickArcadeEnterButtonAnimation(double dt) {
    if (!_arcadeEnterButtonAnimating) return false;

    _arcadeEnterButtonAnimElapsed += dt;
    if (_arcadeEnterButtonOpenGameOnPress &&
        !_arcadeEnterButtonNavigationTriggered &&
        _arcadeEnterButtonAnimElapsed >= _arcadeEnterButtonPressDuration) {
      _arcadeEnterButtonNavigationTriggered = true;
      scheduleMicrotask(_openSelectedArcadeGame);
    }

    final total =
        _arcadeEnterButtonPressDuration + _arcadeEnterButtonReturnDuration;
    if (_arcadeEnterButtonAnimElapsed >= total) {
      _arcadeEnterButtonAnimating = false;
      _arcadeEnterButtonAnimElapsed = 0;
      _arcadeEnterButtonOpenGameOnPress = false;
    }

    _applyArcadeEnterButtonTransform();
    return true;
  }

  void _ensureArcadePartRevealNodes() {
    final room = _roomNode;
    if (room == null) return;

    if (_arcadeScreenRevealNode == null) {
      final material = _unlit(const Color(0x8843F56B))
        ..name = 'arcade_screen_reveal_material';
      final node = Node(
        name: 'arcade_screen_reveal',
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(3.55, 5.85, .22)),
          material,
        ),
      )
        ..castsShadows = false
        ..raycastable = false
        ..highlightColor = null;
      _arcadeScreenRevealNode = node;
      room.add(node);
    }

    if (_arcadeJoystickRevealNode == null) {
      final material = _unlit(const Color(0x88FF2DD1))
        ..name = 'arcade_joystick_reveal_material';
      final node = Node(
        name: 'arcade_joystick_reveal',
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(1.90, 1.90, 3.10)),
          material,
        ),
      )
        ..castsShadows = false
        ..raycastable = false
        ..highlightColor = null;
      _arcadeJoystickRevealNode = node;
      room.add(node);
    }

    _updateArcadePartRevealVisuals();
  }

  void _updateArcadePartRevealVisuals() {
    final screenReveal = _arcadeScreenRevealNode;
    final screen = _arcadeScreenNode;
    if (screenReveal != null && screen != null) {
      screenReveal.visible = _revealArcadeScreen;
      screenReveal.position = vm.Vector3.copy(screen.position);
      screenReveal.rotation = vm.Quaternion.copy(screen.rotation);
      screenReveal.scale = vm.Vector3.copy(screen.scale);
    }

    final joystickReveal = _arcadeJoystickRevealNode;
    final joystick = _arcadeJoystickNode;
    if (joystickReveal != null && joystick != null) {
      joystickReveal.visible = _revealArcadeJoystick;
      joystickReveal.position = vm.Vector3.copy(joystick.position);
      joystickReveal.rotation = vm.Quaternion.copy(joystick.rotation);
      joystickReveal.scale = vm.Vector3.copy(joystick.scale);
    }
  }


  void _ensureArcadeCutterNode() {
    final room = _roomNode;
    if (room == null || _arcadeCutterNode != null) return;

    final material = _unlit(const Color(0x5547D7FF))
      ..name = 'arcade_runtime_cutter_material'
      ..depthBias = .02;
    _arcadeCutterMaterial = material;

    final node = Node(
      name: 'arcade_runtime_cutter',
      mesh: Mesh(
        CuboidGeometry(vm.Vector3.all(1)),
        material,
      ),
    )
      ..castsShadows = false
      ..raycastable = false
      ..frustumCulled = false
      ..highlightColor = _vectorColor(const Color(0xFF6BE7FF));

    _arcadeCutterNode = node;
    room.add(node);
    _updateArcadeCutterVisual();
  }

  vm.Quaternion get _cutterRotation =>
      _rotationFromDegrees(_cutterPitch, _cutterYaw, _cutterRoll);

  vm.Vector3 _rotateVectorByQuaternion(vm.Vector3 value, vm.Quaternion rotation) {
    final matrix = vm.Matrix4.compose(
      vm.Vector3.zero(),
      rotation,
      vm.Vector3.all(1),
    );
    final result = vm.Vector3.copy(value);
    matrix.transform3(result);
    return result;
  }

  void _updateArcadeCutterVisual() {
    final node = _arcadeCutterNode;
    if (node == null) return;

    final width = math.max(.001, _cutterLeft + _cutterRight);
    final height = math.max(.001, _cutterDown + _cutterUp);
    final depth = math.max(.001, _cutterBack + _cutterFront);
    final localOffset = vm.Vector3(
      (_cutterRight - _cutterLeft) * .5,
      (_cutterUp - _cutterDown) * .5,
      (_cutterFront - _cutterBack) * .5,
    );
    final rotation = _cutterRotation;
    final rotatedOffset = _rotateVectorByQuaternion(localOffset, rotation);

    node
      ..visible = _showArcadeCutter && !_userModeActive
      ..position = vm.Vector3(
        _cutterX + rotatedOffset.x,
        _cutterY + rotatedOffset.y,
        _cutterZ + rotatedOffset.z,
      )
      ..rotation = rotation
      ..scale = vm.Vector3(width, height, depth);
  }

  bool _pointInsideArcadeCutter(vm.Vector3 point) {
    final transform = vm.Matrix4.compose(
      vm.Vector3(_cutterX, _cutterY, _cutterZ),
      _cutterRotation,
      vm.Vector3.all(1),
    );
    final inverse = vm.Matrix4.copy(transform);
    inverse.invert();

    final local = vm.Vector3.copy(point);
    inverse.transform3(local);

    return local.x >= -_cutterLeft &&
        local.x <= _cutterRight &&
        local.y >= -_cutterDown &&
        local.y <= _cutterUp &&
        local.z >= -_cutterBack &&
        local.z <= _cutterFront;
  }

  List<int> _sourceTriangleIndices() {
    final data = _arcadeCutSourceData;
    if (data == null) return const <int>[];
    final indices = data.indices;
    if (indices != null && indices.isNotEmpty) {
      return indices;
    }
    return List<int>.generate(data.vertexCount, (index) => index);
  }

  List<int> _trianglesInsideCutter() {
    final data = _arcadeCutSourceData;
    if (data == null) return const <int>[];

    final indices = _sourceTriangleIndices();
    final positions = data.positions;
    final result = <int>[];

    for (var triangleIndex = 0;
        triangleIndex * 3 + 2 < indices.length;
        triangleIndex++) {
      if (_arcadeRemovedTriangles.contains(triangleIndex)) continue;

      final ia = indices[triangleIndex * 3];
      final ib = indices[triangleIndex * 3 + 1];
      final ic = indices[triangleIndex * 3 + 2];

      final ax = positions[ia * 3];
      final ay = positions[ia * 3 + 1];
      final az = positions[ia * 3 + 2];
      final bx = positions[ib * 3];
      final by = positions[ib * 3 + 1];
      final bz = positions[ib * 3 + 2];
      final cx = positions[ic * 3];
      final cy = positions[ic * 3 + 1];
      final cz = positions[ic * 3 + 2];

      final centroid = vm.Vector3(
        (ax + bx + cx) / 3,
        (ay + by + cy) / 3,
        (az + bz + cz) / 3,
      );
      if (_pointInsideArcadeCutter(centroid)) {
        result.add(triangleIndex);
      }
    }

    return result;
  }

  _ArcadeCutPart? _createArcadeCutPart(List<int> triangleIds) {
    final data = _arcadeCutSourceData;
    final material = _arcadeCutSourceMaterial;
    final room = _roomNode;
    if (data == null || material == null || room == null || triangleIds.isEmpty) {
      return null;
    }

    final sourceIndices = _sourceTriangleIndices();
    final vertexIndices = <int>[];
    for (final triangleId in triangleIds) {
      final base = triangleId * 3;
      if (base + 2 >= sourceIndices.length) continue;
      vertexIndices
        ..add(sourceIndices[base])
        ..add(sourceIndices[base + 1])
        ..add(sourceIndices[base + 2]);
    }
    if (vertexIndices.isEmpty) return null;

    final sourcePositions = data.positions;
    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    var maxZ = -double.infinity;

    for (final vertexIndex in vertexIndices) {
      final x = sourcePositions[vertexIndex * 3];
      final y = sourcePositions[vertexIndex * 3 + 1];
      final z = sourcePositions[vertexIndex * 3 + 2];
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      minZ = math.min(minZ, z);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
      maxZ = math.max(maxZ, z);
    }

    final pivot = vm.Vector3(
      (minX + maxX) * .5,
      (minY + maxY) * .5,
      (minZ + maxZ) * .5,
    );

    final positions = Float32List(vertexIndices.length * 3);
    for (var i = 0; i < vertexIndices.length; i++) {
      final sourceVertex = vertexIndices[i];
      positions[i * 3] = sourcePositions[sourceVertex * 3] - pivot.x;
      positions[i * 3 + 1] = sourcePositions[sourceVertex * 3 + 1] - pivot.y;
      positions[i * 3 + 2] = sourcePositions[sourceVertex * 3 + 2] - pivot.z;
    }

    Float32List? copyAttribute(Float32List? source, int components) {
      if (source == null) return null;
      final out = Float32List(vertexIndices.length * components);
      for (var i = 0; i < vertexIndices.length; i++) {
        final sourceVertex = vertexIndices[i];
        for (var c = 0; c < components; c++) {
          out[i * components + c] =
              source[sourceVertex * components + c];
        }
      }
      return out;
    }

    final geometry = MeshGeometry.fromArrays(
      positions: positions,
      normals: copyAttribute(data.normals, 3),
      texCoords: copyAttribute(data.texCoords, 2),
      texCoords1: copyAttribute(data.texCoords1, 2),
      colors: copyAttribute(data.colors, 4),
      tangents: copyAttribute(data.tangents, 4),
      retainCpuData: true,
    );

    final id = _nextArcadeCutPartId++;
    final node = Node(
      name: 'arcade_cut_part_$id',
      mesh: Mesh(geometry, material),
    )
      ..position = pivot
      ..castsShadows = true
      ..raycastable = false;

    final part = _ArcadeCutPart(
      id: id,
      node: node,
      originalMaterial: material,
      triangleIds: List<int>.from(triangleIds),
      baseX: pivot.x,
      baseY: pivot.y,
      baseZ: pivot.z,
    );
    _arcadeCutParts.add(part);
    room.add(node);
    _selectedArcadeCutPartId = id;
    return part;
  }

  void _rebuildArcadeCutRemainder() {
    final data = _arcadeCutSourceData;
    final material = _arcadeCutSourceMaterial;
    final room = _roomNode;
    if (data == null || material == null || room == null) return;

    final sourceIndices = _sourceTriangleIndices();
    final remainingIndices = <int>[];
    for (var triangleIndex = 0;
        triangleIndex * 3 + 2 < sourceIndices.length;
        triangleIndex++) {
      if (_arcadeRemovedTriangles.contains(triangleIndex)) continue;
      final base = triangleIndex * 3;
      remainingIndices
        ..add(sourceIndices[base])
        ..add(sourceIndices[base + 1])
        ..add(sourceIndices[base + 2]);
    }

    final geometry = MeshGeometry.fromArrays(
      positions: Float32List.fromList(data.positions),
      normals: data.normals == null ? null : Float32List.fromList(data.normals!),
      texCoords:
          data.texCoords == null ? null : Float32List.fromList(data.texCoords!),
      texCoords1:
          data.texCoords1 == null ? null : Float32List.fromList(data.texCoords1!),
      colors: data.colors == null ? null : Float32List.fromList(data.colors!),
      tangents:
          data.tangents == null ? null : Float32List.fromList(data.tangents!),
      indices: remainingIndices,
      retainCpuData: true,
    );

    final old = _arcadeCutRemainderNode;
    old?.detach();

    final remainder = Node(
      name: 'arcade_cut_remainder',
      mesh: Mesh(geometry, material),
    )
      ..castsShadows = true
      ..raycastable = false;
    _arcadeCutRemainderNode = remainder;
    room.add(remainder);

    for (final node in room.meshNodes.toList()) {
      if (identical(node, remainder) ||
          node.name.startsWith('arcade_cut_part_') ||
          node.name == 'arcade_runtime_cutter' ||
          node.name.startsWith('arcade_screen_reveal') ||
          node.name.startsWith('arcade_joystick_reveal')) {
        continue;
      }
      node.visible = false;
    }
  }

  Future<void> _copyArcadePreCutSelectionData() async {
    final data = _arcadeCutSourceData;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هندسة مجسم الآركيد غير متاحة حالياً.'),
        ),
      );
      return;
    }

    final triangleIds = _trianglesInsideCutter();
    if (triangleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مكعب القص حالياً ما محدد أي مثلث من المجسم.'),
        ),
      );
      return;
    }

    final indices = _sourceTriangleIndices();
    final positions = data.positions;

    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    var maxZ = -double.infinity;

    final triangles = <Map<String, dynamic>>[];

    for (final triangleId in triangleIds) {
      final base = triangleId * 3;
      if (base + 2 >= indices.length) continue;

      final ia = indices[base];
      final ib = indices[base + 1];
      final ic = indices[base + 2];

      List<double> vertex(int index) {
        final x = positions[index * 3].toDouble();
        final y = positions[index * 3 + 1].toDouble();
        final z = positions[index * 3 + 2].toDouble();

        minX = math.min(minX, x);
        minY = math.min(minY, y);
        minZ = math.min(minZ, z);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        maxZ = math.max(maxZ, z);

        return <double>[x, y, z];
      }

      final a = vertex(ia);
      final b = vertex(ib);
      final c = vertex(ic);

      triangles.add(<String, dynamic>{
        'triangleIndex': triangleId,
        'vertexIndices': <int>[ia, ib, ic],
        'vertices': <List<double>>[a, b, c],
        'centroid': <double>[
          (a[0] + b[0] + c[0]) / 3.0,
          (a[1] + b[1] + c[1]) / 3.0,
          (a[2] + b[2] + c[2]) / 3.0,
        ],
      });
    }

    final payload = <String, dynamic>{
      'format': 'SOOKY_ARCADE_PRECUT_SELECTION_V2',
      'source': 'assets/models/arcade_room.glb',
      'selection': <String, dynamic>{
        'triangleCount': triangles.length,
        'triangleIndices': triangleIds,
        'sourceVertexCount': data.vertexCount,
        'sourceTriangleCount': indices.length ~/ 3,
        'boundingBox': <String, dynamic>{
          'min': <double>[minX, minY, minZ],
          'max': <double>[maxX, maxY, maxZ],
          'center': <double>[
            (minX + maxX) * .5,
            (minY + maxY) * .5,
            (minZ + maxZ) * .5,
          ],
          'size': <double>[
            maxX - minX,
            maxY - minY,
            maxZ - minZ,
          ],
        },
        'cutter': <String, dynamic>{
          'center': <double>[_cutterX, _cutterY, _cutterZ],
          'extents': <String, double>{
            'left': _cutterLeft,
            'right': _cutterRight,
            'up': _cutterUp,
            'down': _cutterDown,
            'front': _cutterFront,
            'back': _cutterBack,
          },
          'rotationDegrees': <String, double>{
            'pitch': _cutterPitch,
            'yaw': _cutterYaw,
            'roll': _cutterRoll,
          },
        },
        'triangles': triangles,
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    final output = encoder.convert(payload);
    await Clipboard.setData(ClipboardData(text: output));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ بيانات ${triangles.length} مثلث قبل القص بالكامل. الصقها وأرسلها إلي.',
        ),
      ),
    );
  }

  void _performArcadeCut() {
    final triangles = _trianglesInsideCutter();
    if (triangles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المكعب لا يحتوي أي جزء من المجسم حالياً.'),
        ),
      );
      return;
    }

    final part = _createArcadeCutPart(triangles);
    if (part == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إنشاء القطعة المقصوصة من المجسم.'),
        ),
      );
      return;
    }

    _arcadeRemovedTriangles.addAll(triangles);
    _rebuildArcadeCutRemainder();
    setState(() {});
  }

  _ArcadeCutPart? get _selectedArcadeCutPart {
    final id = _selectedArcadeCutPartId;
    if (id == null) return null;
    for (final part in _arcadeCutParts) {
      if (part.id == id) return part;
    }
    return null;
  }

  void _applyArcadeCutPartTransform(_ArcadeCutPart part) {
    part.node
      ..visible = part.visible
      ..position = vm.Vector3(
        part.baseX + part.x,
        part.baseY + part.y,
        part.baseZ + part.z,
      )
      ..rotation = _rotationFromDegrees(
        part.rotX,
        part.rotY,
        part.rotZ,
      )
      ..scale = vm.Vector3(
        part.scaleX,
        part.scaleY,
        part.scaleZ,
      );

    if (part.colorEnabled) {
      part.customMaterial ??= _unlit(
        Color.fromARGB(
          254,
          part.colorR.round().clamp(0, 255).toInt(),
          part.colorG.round().clamp(0, 255).toInt(),
          part.colorB.round().clamp(0, 255).toInt(),
        ),
      );
      part.customMaterial!.baseColorFactor = _vectorColor(
        Color.fromARGB(
          (part.colorOpacity.clamp(0.0, 1.0) * 255).round(),
          part.colorR.round().clamp(0, 255).toInt(),
          part.colorG.round().clamp(0, 255).toInt(),
          part.colorB.round().clamp(0, 255).toInt(),
        ),
      );
      final mesh = part.node.mesh;
      if (mesh != null && mesh.primitives.isNotEmpty) {
        mesh.primitives.first.material = part.customMaterial!;
      }
    } else {
      final mesh = part.node.mesh;
      if (mesh != null && mesh.primitives.isNotEmpty) {
        mesh.primitives.first.material = part.originalMaterial;
      }
    }

    part.node.highlightColor = part.glowEnabled
        ? vm.Vector4(
            part.glowR.clamp(0, 255).toDouble() / 255.0,
            part.glowG.clamp(0, 255).toDouble() / 255.0,
            part.glowB.clamp(0, 255).toDouble() / 255.0,
            part.glowIntensity.clamp(0.0, 1.0).toDouble(),
          )
        : null;
  }

  Future<void> _exportArcadeCutParts() async {
    if (_arcadeCutParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ماكو أجزاء مقصوصة حتى يتم تصديرها.'),
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'format': 'SOOKY_ARCADE_CUTS_V1',
      'source': 'assets/models/arcade_room.glb',
      'cuts': [
        for (final part in _arcadeCutParts)
          <String, dynamic>{
            'id': part.id,
            'label': part.label,
            'triangles': part.triangleIds,
            'visible': part.visible,
            'position': <String, double>{
              'x': part.x,
              'y': part.y,
              'z': part.z,
            },
            'basePosition': <String, double>{
              'x': part.baseX,
              'y': part.baseY,
              'z': part.baseZ,
            },
            'rotation': <String, double>{
              'x': part.rotX,
              'y': part.rotY,
              'z': part.rotZ,
            },
            'scale': <String, double>{
              'x': part.scaleX,
              'y': part.scaleY,
              'z': part.scaleZ,
            },
            'color': <String, dynamic>{
              'enabled': part.colorEnabled,
              'r': part.colorR,
              'g': part.colorG,
              'b': part.colorB,
              'opacity': part.colorOpacity,
            },
            'glow': <String, dynamic>{
              'enabled': part.glowEnabled,
              'r': part.glowR,
              'g': part.glowG,
              'b': part.glowB,
              'intensity': part.glowIntensity,
            },
          },
      ],
    };

    const encoder = JsonEncoder.withIndent('  ');
    final output = encoder.convert(payload);
    await Clipboard.setData(ClipboardData(text: output));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ ${_arcadeCutParts.length} جزء مقصوص بالكامل. الصقه وأرسله إلي.',
        ),
      ),
    );
  }

  void _deleteSelectedArcadeCutPart() {
    final part = _selectedArcadeCutPart;
    if (part == null) return;
    part.node.detach();
    _arcadeCutParts.remove(part);
    _selectedArcadeCutPartId =
        _arcadeCutParts.isEmpty ? null : _arcadeCutParts.last.id;
    setState(() {});
  }

  Future<void> _loadCharacter() async {
    final character = await Node.fromGlbAsset(
      'assets/models/creative_character_free.glb',
    );
    character.name = 'arcade_character';
    _applyDefaultAvatar(character);
    _captureJointNodes(character);
    _characterNode = character;
    _scene.add(character);
  }

  vm.Vector4 _vectorColor(Color color, {double? alpha}) {
    final argb = color.toARGB32();
    final resolvedAlpha = alpha ?? (((argb >> 24) & 0xFF) / 255.0);
    return vm.Vector4(
      ((argb >> 16) & 0xFF) / 255.0,
      ((argb >> 8) & 0xFF) / 255.0,
      (argb & 0xFF) / 255.0,
      resolvedAlpha,
    );
  }

  UnlitMaterial _unlit(Color color) {
    final material = UnlitMaterial();
    material.baseColorFactor = _vectorColor(color);
    material.vertexColorWeight = 0;
    final alpha = ((color.toARGB32() >> 24) & 0xFF) / 255.0;
    if (alpha < .999) material.alphaMode = AlphaMode.blend;
    material.doubleSided = true;
    return material;
  }

  void _applyArcadePartMaterial({
    required Node? node,
    required fs.Material? originalMaterial,
    required bool colorEnabled,
    required double colorR,
    required double colorG,
    required double colorB,
    required double colorOpacity,
    required UnlitMaterial? cachedMaterial,
    required ValueChanged<UnlitMaterial?> onMaterialCached,
  }) {
    if (node == null) return;
    final mesh = node.mesh;
    if (mesh == null || mesh.primitives.isEmpty) return;

    if (!colorEnabled) {
      if (originalMaterial != null) {
        mesh.primitives.first.material = originalMaterial;
      }
      return;
    }

    final color = Color.fromARGB(
      (colorOpacity.clamp(0.0, 1.0) * 255).round(),
      colorR.round().clamp(0, 255).toInt(),
      colorG.round().clamp(0, 255).toInt(),
      colorB.round().clamp(0, 255).toInt(),
    );
    final material = cachedMaterial ?? _unlit(color);
    material
      ..baseColorFactor = _vectorColor(color)
      ..vertexColorWeight = 0
      ..doubleSided = true
      ..alphaMode = color.alpha < 255 ? AlphaMode.blend : AlphaMode.opaque;
    mesh.primitives.first.material = material;
    if (!identical(material, cachedMaterial)) {
      onMaterialCached(material);
    }
  }


  void _buildArcadeDisplaySurface() {
    final screen = _arcadeScreenNode;
    if (screen == null || _arcadeDisplaySurfaceGeometry != null) return;

    try {
      final data = screen.extractMeshData();
      final texCoords = data.texCoords == null
          ? Float32List.fromList(<double>[
              0, 1,
              1, 1,
              1, 0,
              0, 1,
              1, 0,
              0, 0,
            ])
          : Float32List.fromList(data.texCoords!);

      if (texCoords.length >= 2) {
        var minU = double.infinity;
        var maxU = -double.infinity;
        var minV = double.infinity;
        var maxV = -double.infinity;

        for (var i = 0; i + 1 < texCoords.length; i += 2) {
          minU = math.min(minU, texCoords[i]);
          maxU = math.max(maxU, texCoords[i]);
          minV = math.min(minV, texCoords[i + 1]);
          maxV = math.max(maxV, texCoords[i + 1]);
        }

        final rangeU = math.max(.000001, maxU - minU);
        final rangeV = math.max(.000001, maxV - minV);

        for (var i = 0; i + 1 < texCoords.length; i += 2) {
          texCoords[i] = ((texCoords[i] - minU) / rangeU).clamp(0.0, 1.0);
          texCoords[i + 1] =
              (1.0 - ((texCoords[i + 1] - minV) / rangeV))
                  .clamp(0.0, 1.0);
        }
      }

      _arcadeDisplaySurfaceGeometry = MeshGeometry.fromArrays(
        positions: Float32List.fromList(data.positions),
        normals: data.normals == null
            ? null
            : Float32List.fromList(data.normals!),
        texCoords: texCoords,
        texCoords1: data.texCoords1 == null
            ? null
            : Float32List.fromList(data.texCoords1!),
        colors: data.colors == null
            ? null
            : Float32List.fromList(data.colors!),
        tangents: data.tangents == null
            ? null
            : Float32List.fromList(data.tangents!),
        indices: data.indices,
        retainCpuData: true,
      );
    } catch (_) {
      _arcadeDisplaySurfaceGeometry = null;
    }
  }

  void _ensureArcadeJoystickPressHitbox() {
    final joystick = _arcadeJoystickNode;
    if (joystick == null || _arcadeJoystickPressHitboxNode != null) return;

    final material = _unlit(const Color(0x6649E8FF))
      ..name = 'arcade_joystick_press_hitbox_material'
      ..depthBias = .06;
    _arcadeJoystickPressHitboxMaterial = material;

    final hitbox = Node(
      name: 'arcade_joystick_press_hitbox',
      mesh: Mesh(CuboidGeometry(vm.Vector3.all(1)), material),
    )
      ..castsShadows = false
      ..raycastable = true
      ..frustumCulled = false
      ..highlightColor = _vectorColor(const Color(0xFF49E8FF));

    _arcadeJoystickPressHitboxNode = hitbox;
    joystick.add(hitbox);
    _updateArcadeJoystickPressHitbox();
  }

  void _updateArcadeJoystickPressHitbox() {
    final hitbox = _arcadeJoystickPressHitboxNode;
    if (hitbox == null) return;
    hitbox
      ..visible = _showArcadeJoystickPressHitbox && !_userModeActive
      ..position = vm.Vector3(
        _arcadeJoystickPressHitboxX,
        _arcadeJoystickPressHitboxY,
        _arcadeJoystickPressHitboxZ,
      )
      ..scale = vm.Vector3(
        math.max(.01, _arcadeJoystickPressHitboxSizeX),
        math.max(.01, _arcadeJoystickPressHitboxSizeY),
        math.max(.01, _arcadeJoystickPressHitboxSizeZ),
      );
  }

  bool get _arcadeJoystickDeveloperPreviewActive =>
      _arcadeJoystickPressPreview &&
      !_userModeActive &&
      _developerPanelOpen &&
      _developerSection == 'arcade_parts';

  void _previewArcadeJoystickPress([double direction = 1]) {
    _arcadeJoystickPressPreview = true;
    _arcadeJoystickPreviewDirection = direction < 0 ? -1 : 1;
    _applyAllTransforms(save: false, repaint: false);
  }

  void _requestArcadeDisplayRefresh() {
    _arcadeDisplayDirty = true;
  }

  Color _rgb(double r, double g, double b, {double opacity = 1}) {
    return Color.fromARGB(
      (opacity.clamp(0.0, 1.0) * 255).round(),
      r.round().clamp(0, 255).toInt(),
      g.round().clamp(0, 255).toInt(),
      b.round().clamp(0, 255).toInt(),
    );
  }

  Future<void> _refreshArcadeDisplayTexture({bool force = false}) async {
    if (_arcadeScreenNode == null ||
        (!_arcadeDisplayDirty && !force) ||
        _arcadeDisplayRefreshInFlight) {
      return;
    }
    _arcadeDisplayRefreshInFlight = true;
    try {
      final texture = await _makeArcadeDisplayTexture();
      _arcadeDisplayTexture = texture;
      final material =
          _arcadeDisplayMaterial ?? _unlit(const Color(0xFFFFFFFF));
      material
        ..name = 'sooky_arcade_display_material'
        ..baseColorTexture = texture
        ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
        ..vertexColorWeight = 0
        ..doubleSided = true
        ..alphaMode = AlphaMode.opaque;
      _arcadeDisplayMaterial = material;

      final screen = _arcadeScreenNode;
      final geometry = _arcadeDisplaySurfaceGeometry;
      if (screen != null && geometry != null && _arcadeDisplayEnabled) {
        screen.mesh = Mesh(geometry, material);
      }

      _arcadeDisplayDirty = false;
      _applyAllTransforms(save: false, repaint: false);
      if (mounted) setState(() {});
    } finally {
      _arcadeDisplayRefreshInFlight = false;
    }
  }

  Future<void> _loadArcadeCoverImages() async {
    for (final game in _arcadeGames) {
      if (game.isBack || game.coverAsset.isEmpty) continue;
      if (_arcadeCoverImages.containsKey(game.coverAsset)) continue;
      final data = await rootBundle.load(game.coverAsset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      _arcadeCoverImages[game.coverAsset] = frame.image;
      codec.dispose();
    }
  }

  double get _arcadeCarouselT {
    if (!_arcadeCarouselAnimating || _arcadeCarouselDuration <= 0) return 1.0;
    final raw = (_arcadeCarouselElapsed / _arcadeCarouselDuration)
        .clamp(0.0, 1.0)
        .toDouble();
    return 1 - math.pow(1 - raw, 5).toDouble();
  }

  bool _tickArcadeCarousel(double dt) {
    if (!_arcadeCarouselAnimating) return false;
    _arcadeCarouselElapsed += dt;
    _requestArcadeDisplayRefresh();
    if (_arcadeCarouselElapsed >= _arcadeCarouselDuration) {
      _arcadeSelectedGameIndex = _arcadeCarouselToIndex;
      _arcadeCarouselAnimating = false;
      _arcadeCarouselElapsed = 0;
      _arcadeCarouselFromIndex = _arcadeSelectedGameIndex;
      _arcadeCarouselToIndex = _arcadeSelectedGameIndex;
      _arcadeCarouselDirection = 0;
      _arcadeDisplayRefreshAccumulator = _arcadeDisplayAnimationRefreshStep;
      _requestArcadeDisplayRefresh();
      _scheduleSave();
    }
    return true;
  }

  Future<Texture2D> _makeArcadeDisplayTexture() async {
    // Render at 75% physical resolution for much faster animated refreshes,
    // while keeping the exact same 1024x768 logical layout.
    const width = 768;
    const height = 576;
    const logicalWidth = 1024.0;
    const logicalHeight = 768.0;
    const logicalSize = ui.Size(logicalWidth, logicalHeight);
    const renderScale = width / logicalWidth;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(renderScale);

    void paintText(
      String value, {
      required Rect rect,
      required double fontSize,
      required Color color,
      FontWeight fontWeight = FontWeight.w800,
      List<Shadow>? shadows,
      int? maxLines,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1.0,
            shadows: shadows,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: rect.width);
      painter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - painter.width) * .5,
          rect.top + (rect.height - painter.height) * .5,
        ),
      );
    }

    Color lerpColor(Color a, Color b, double t) =>
        Color.lerp(a, b, t.clamp(0.0, 1.0)) ?? a;

    void pixelRect(Rect rect, Color color) {
      canvas.drawRect(rect, Paint()..color = color);
    }

    // ------------------------------------------------------------------
    // BACKGROUND — stage-like pixel arcade look matching the reference.
    // ------------------------------------------------------------------
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, logicalHeight),
        const <Color>[
          Color(0xFF071427),
          Color(0xFF0B2B47),
          Color(0xFF123758),
          Color(0xFF111827),
        ],
        const <double>[0, .35, .70, 1],
      );
    canvas.drawRect(Offset.zero & logicalSize, bgPaint);

    // Pixel block skyline / wall shapes.
    final wall = Paint()..color = const Color(0xFF17436A).withOpacity(.70);
    final wallDark = Paint()..color = const Color(0xFF0B243D).withOpacity(.95);
    final blocks = <Rect>[
      const Rect.fromLTWH(60, 180, 110, 75),
      const Rect.fromLTWH(170, 220, 85, 90),
      const Rect.fromLTWH(270, 170, 120, 120),
      const Rect.fromLTWH(650, 165, 120, 130),
      const Rect.fromLTWH(780, 215, 90, 95),
      const Rect.fromLTWH(875, 175, 85, 85),
    ];
    for (final r in blocks) {
      canvas.drawRect(r, wall);
      canvas.drawRect(
        Rect.fromLTWH(r.left + 16, r.top + 18, r.width * .42, 14),
        wallDark,
      );
    }

    // Stage truss.
    pixelRect(Rect.fromLTWH(0, 42, logicalWidth, 18), const Color(0xFF182337));
    for (double x = 0; x < width; x += 92) {
      pixelRect(Rect.fromLTWH(x, 42, 10, 72), const Color(0xFF25324C));
      canvas.drawLine(
        Offset(x, 50),
        Offset(x + 76, 100),
        Paint()..color = const Color(0xFF33425D)..strokeWidth = 6,
      );
      canvas.drawLine(
        Offset(x + 76, 50),
        Offset(x, 100),
        Paint()..color = const Color(0xFF33425D)..strokeWidth = 6,
      );
    }

    // Hanging lamps and warm cones.
    void drawLamp(double cx) {
      final cone = ui.Path()
        ..moveTo(cx - 52, 86)
        ..lineTo(cx + 52, 86)
        ..lineTo(cx + 92, 250)
        ..lineTo(cx - 92, 250)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, 88),
            Offset(cx, 250),
            <Color>[
              const Color(0x55FF9D1A),
              const Color(0x05FF9D1A),
            ],
          ),
      );
      pixelRect(Rect.fromCenter(center: Offset(cx, 70), width: 56, height: 44), const Color(0xFF601D13));
      pixelRect(Rect.fromCenter(center: Offset(cx, 88), width: 82, height: 20), const Color(0xFF992D17));
      pixelRect(Rect.fromCenter(center: Offset(cx, 92), width: 52, height: 12), const Color(0xFFFFC53D));
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 92), width: 42, height: 8),
        Paint()
          ..color = const Color(0xFFFFEA81)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    drawLamp(185);
    drawLamp(839);

    // Pixel side columns.
    for (final left in <double>[22, 970]) {
      pixelRect(Rect.fromLTWH(left, 130, 28, 500), const Color(0xFF24324D));
      pixelRect(Rect.fromLTWH(left + 5, 180, 18, 265), const Color(0xFFE88B19));
      pixelRect(Rect.fromLTWH(left + 8, 190, 12, 245), const Color(0xFFFFB12A));
    }

    // Pixel floor at bottom.
    pixelRect(Rect.fromLTWH(0, 618, logicalWidth, 150), const Color(0xFF32171B));
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 12; col++) {
        final bright = (row + col).isEven;
        pixelRect(
          Rect.fromLTWH(col * 86.0 - 14, 618 + row * 38.0, 82, 34),
          bright ? const Color(0xFF7D261C) : const Color(0xFF451B1C),
        );
      }
    }

    // ------------------------------------------------------------------
    // TITLE SIGN — red metal plate + thick gold pixel frame.
    // ------------------------------------------------------------------
    final signOuter = RRect.fromRectAndRadius(
      const Rect.fromLTWH(285, 42, 454, 132),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      signOuter,
      Paint()
        ..color = const Color(0xFFFFA51A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(signOuter, Paint()..color = const Color(0xFFD6790D));

    final signInner = RRect.fromRectAndRadius(
      const Rect.fromLTWH(300, 55, 424, 104),
      const Radius.circular(11),
    );
    canvas.drawRRect(signInner, Paint()..color = const Color(0xFF8C1F20));
    canvas.drawRRect(
      signInner,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(300, 55),
          const Offset(724, 159),
          const <Color>[
            Color(0xFFB72324),
            Color(0xFFE63A22),
            Color(0xFF95191D),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );

    // Plate rivets.
    for (final p in <Offset>[
      const Offset(316, 70),
      const Offset(708, 70),
      const Offset(316, 144),
      const Offset(708, 144),
    ]) {
      canvas.drawCircle(p, 9, Paint()..color = const Color(0xFF6F360A));
      canvas.drawCircle(p.translate(-2, -2), 4, Paint()..color = const Color(0xFFFFC23A));
    }

    paintText(
      'سوكي',
      rect: const Rect.fromLTWH(350, 58, 324, 90),
      fontSize: 72,
      color: const Color(0xFFFFC83E),
      fontWeight: FontWeight.w900,
      shadows: const <Shadow>[
        Shadow(color: Color(0xFF2A1000), offset: Offset(5, 7), blurRadius: 0),
        Shadow(color: Color(0xFFFF8611), offset: Offset(0, 0), blurRadius: 8),
      ],
    );

    final subtitlePlate = RRect.fromRectAndRadius(
      const Rect.fromLTWH(350, 158, 324, 58),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      subtitlePlate,
      Paint()..color = const Color(0xFFE28A12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(358, 165, 308, 44),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFF071826),
    );
    paintText(
      'اختر لعبتك',
      rect: const Rect.fromLTWH(362, 165, 300, 44),
      fontSize: 31,
      color: const Color(0xFFFFD15A),
      fontWeight: FontWeight.w900,
    );

    // ------------------------------------------------------------------
    // CAROUSEL — cards move; selected frame NEVER moves.
    // ------------------------------------------------------------------
    final centerX = logicalWidth * .5;
    const cardCenterY = 458.0;
    const sideW = 244.0;
    const sideH = 338.0;
    const centerW = 304.0;
    const centerH = 392.0;
    const sideX = 276.0;

    int indexWrap(int index) {
      final len = _arcadeGames.length;
      var value = index % len;
      if (value < 0) value += len;
      return value;
    }

    double slotX(double p) {
      if (p <= -1) return centerX - sideX + (p + 1) * 238;
      if (p >= 1) return centerX + sideX + (p - 1) * 238;
      return centerX + p * sideX;
    }

    double slotWidth(double p) {
      final d = p.abs().clamp(0.0, 1.0).toDouble();
      return centerW + (sideW - centerW) * d;
    }

    double slotHeight(double p) {
      final d = p.abs().clamp(0.0, 1.0).toDouble();
      return centerH + (sideH - centerH) * d;
    }

    double slotOpacity(double p) {
      final d = p.abs();
      if (d <= 1) return 1.0 - .12 * d;
      return (1.0 - .42 * (d - 1)).clamp(.30, .88).toDouble();
    }

    void drawCover(
      ui.Image image,
      Rect rect, {
      required double opacity,
    }) {
      final srcAspect = image.width / image.height;
      final dstAspect = rect.width / rect.height;
      Rect src;
      if (srcAspect > dstAspect) {
        final wantedW = image.height * dstAspect;
        src = Rect.fromLTWH(
          (image.width - wantedW) / 2,
          0,
          wantedW,
          image.height.toDouble(),
        );
      } else {
        final wantedH = image.width / dstAspect;
        src = Rect.fromLTWH(
          0,
          (image.height - wantedH) / 2,
          image.width.toDouble(),
          wantedH,
        );
      }
      canvas.drawImageRect(
        image,
        src,
        rect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withOpacity(opacity),
      );
    }

    void drawMovingCard(int gameIndex, double p) {
      if (p.abs() > 1.85) return;
      final game = _arcadeGames[indexWrap(gameIndex)];
      final image = game.isBack ? null : _arcadeCoverImages[game.coverAsset];

      final nearCenter = p.abs() < .55;
      final w = slotWidth(p);
      final h = slotHeight(p);
      final y = cardCenterY + p.abs().clamp(0.0, 1.0) * 10;
      final rect = Rect.fromCenter(
        center: Offset(slotX(p), y),
        width: w,
        height: h,
      );

      // Shadow plate behind cover.
      final shadowRect = rect.translate(8, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(shadowRect, const Radius.circular(14)),
        Paint()..color = const Color(0xAA100A0A),
      );

      // Brown/gold side frame integrated with reference look.
      final outer = RRect.fromRectAndRadius(rect.inflate(11), const Radius.circular(15));
      canvas.drawRRect(outer, Paint()..color = const Color(0xFF4D220F));
      canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFFD87612),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFB52B),
      );

      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      );

      if (game.isBack) {
        final backBg = Paint()
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.bottomRight,
            const <Color>[
              Color(0xFF2C1014),
              Color(0xFF6C1E19),
              Color(0xFF241014),
            ],
            const <double>[0.0, 0.52, 1.0],
          );
        canvas.drawRect(rect, backBg);

        // Pixel-style inner panels.
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + rect.width * .10,
            rect.top + rect.height * .10,
            rect.width * .80,
            rect.height * .80,
          ),
          Paint()..color = const Color(0x33000000),
        );

        final arrowCenter = Offset(
          rect.center.dx,
          rect.top + rect.height * .36,
        );
        final arrowR = rect.width * .18;
        canvas.drawCircle(
          arrowCenter,
          arrowR,
          Paint()..color = const Color(0xFF101C28),
        );
        canvas.drawCircle(
          arrowCenter,
          arrowR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(4.0, rect.width * .025)
            ..color = const Color(0xFFFFB52B),
        );

        final arrow = ui.Path()
          ..moveTo(arrowCenter.dx + arrowR * .40, arrowCenter.dy - arrowR * .48)
          ..lineTo(arrowCenter.dx - arrowR * .30, arrowCenter.dy)
          ..lineTo(arrowCenter.dx + arrowR * .40, arrowCenter.dy + arrowR * .48);
        canvas.drawPath(
          arrow,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(6.0, rect.width * .045)
            ..strokeCap = StrokeCap.square
            ..strokeJoin = StrokeJoin.miter
            ..color = const Color(0xFFFFD45A),
        );

        paintText(
          'رجوع',
          rect: Rect.fromLTWH(
            rect.left + rect.width * .08,
            rect.top + rect.height * .54,
            rect.width * .84,
            rect.height * .18,
          ),
          fontSize: nearCenter ? 47 : 34,
          color: const Color(0xFFFFE59A),
          fontWeight: FontWeight.w900,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xFF260800),
              offset: Offset(4, 5),
              blurRadius: 0,
            ),
          ],
        );

        paintText(
          'العودة إلى الشخصية',
          rect: Rect.fromLTWH(
            rect.left + rect.width * .08,
            rect.top + rect.height * .72,
            rect.width * .84,
            rect.height * .10,
          ),
          fontSize: nearCenter ? 19 : 14,
          color: const Color(0xFFFFC96A),
          fontWeight: FontWeight.w700,
        );
      } else if (image != null) {
        drawCover(image, rect, opacity: slotOpacity(p));
      }

      if (!nearCenter) {
        canvas.drawRect(
          rect,
          Paint()..color = const Color(0xFF170C08).withOpacity(.18),
        );
      }
      canvas.restore();

      // Pixel corner bolts.
      for (final c in <Offset>[
        Offset(rect.left + 5, rect.top + 5),
        Offset(rect.right - 5, rect.top + 5),
        Offset(rect.left + 5, rect.bottom - 5),
        Offset(rect.right - 5, rect.bottom - 5),
      ]) {
        canvas.drawRect(
          Rect.fromCenter(center: c, width: 10, height: 10),
          Paint()..color = const Color(0xFFFFA11F),
        );
      }
    }

    final carouselProgress = _arcadeCarouselAnimating ? _arcadeCarouselT : 0.0;
    final direction = _arcadeCarouselAnimating ? _arcadeCarouselDirection : 0;
    final baseIndex = _arcadeCarouselAnimating
        ? _arcadeCarouselFromIndex
        : _arcadeSelectedGameIndex;

    // Draw far-to-near so center card visually sits above side cards.
    final cardSpecs = <({int offset, double p})>[];
    for (var offset = -2; offset <= 2; offset++) {
      final p = offset - direction * carouselProgress;
      cardSpecs.add((offset: offset, p: p));
    }
    cardSpecs.sort((a, b) => b.p.abs().compareTo(a.p.abs()));
    for (final spec in cardSpecs) {
      drawMovingCard(baseIndex + spec.offset, spec.p);
    }

    // Fixed selected frame: NEVER moves with the cards.
    final frameRect = Rect.fromCenter(
      center: Offset(centerX, cardCenterY),
      width: centerW + 28,
      height: centerH + 28,
    );

    // Green selected backing visible as a fixed frame.
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(17)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = const Color(0xFF007C5D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect.inflate(5), const Radius.circular(20)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = const Color(0xFFFFB41F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect.inflate(11), const Radius.circular(23)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFE05E),
    );

    // Gold square accents in all four corners of the fixed frame.
    for (final p in <Offset>[
      Offset(frameRect.left - 4, frameRect.top - 4),
      Offset(frameRect.right + 4, frameRect.top - 4),
      Offset(frameRect.left - 4, frameRect.bottom + 4),
      Offset(frameRect.right + 4, frameRect.bottom + 4),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 26, height: 26),
        Paint()..color = const Color(0xFFFFA916),
      );
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 12, height: 12),
        Paint()..color = const Color(0xFFFFE063),
      );
    }

    // Gentle center highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect.deflate(12), const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF35F0B0).withOpacity(.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ------------------------------------------------------------------
    // FIXED ARCADE ARROWS.
    // ------------------------------------------------------------------
    void drawPixelArrow(double cx, bool left) {
      final outer = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 455), width: 72, height: 92),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.outerRect.shift(const Offset(6, 7)), const Radius.circular(8)),
        Paint()..color = const Color(0xAA0C0710),
      );
      canvas.drawRRect(outer, Paint()..color = const Color(0xFF18203A));
      canvas.drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFFE78B16),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer.outerRect.deflate(7), const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFC02B),
      );

      final path = ui.Path();
      if (left) {
        path
          ..moveTo(cx + 13, 430)
          ..lineTo(cx - 15, 455)
          ..lineTo(cx + 13, 480);
      } else {
        path
          ..moveTo(cx - 13, 430)
          ..lineTo(cx + 15, 455)
          ..lineTo(cx - 13, 480);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..color = const Color(0xFFFFC12A),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..color = const Color(0xFFFFF078),
      );
    }

    drawPixelArrow(92, true);
    drawPixelArrow(932, false);

    // Dark vignette makes the screen feel like the actual reference cabinet.
    canvas.drawRect(
      Offset.zero & logicalSize,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(512, 390),
          610,
          const <Color>[
            Color(0x00000000),
            Color(0x00000000),
            Color(0x60000000),
          ],
          const <double>[0, .60, 1],
        ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  double get _activeArcadeJoystickPressDuration =>
      _arcadeJoystickAnimDirection < 0
          ? _arcadeJoystickPreviousPressDuration
          : _arcadeJoystickPressDuration;

  double get _activeArcadeJoystickReturnDuration =>
      _arcadeJoystickAnimDirection < 0
          ? _arcadeJoystickPreviousReturnDuration
          : _arcadeJoystickReturnDuration;

  bool _tickArcadeJoystickAnimation(double dt) {
    if (!_arcadeJoystickAnimating) return false;

    final pressDuration = math.max(.0001, _activeArcadeJoystickPressDuration);
    final returnDuration = math.max(.0001, _activeArcadeJoystickReturnDuration);
    final isPrevious = _arcadeJoystickAnimDirection < 0;
    final peakHold = isPrevious
        ? math.max(0.0, _arcadeJoystickPreviousPeakHold)
        : 0.0;

    // Phase 1: reach the exact developer-preview pose.
    if (!_arcadeJoystickPeakFrameShown) {
      if (_arcadeJoystickAnimElapsed + dt >= pressDuration) {
        _arcadeJoystickAnimElapsed = pressDuration;
        _arcadeJoystickPeakFrameShown = true;
        _arcadeJoystickPeakHoldElapsed = 0;
      } else {
        _arcadeJoystickAnimElapsed += dt;
      }
      _applyAllTransforms(save: false, repaint: false);
      return true;
    }

    // Phase 2: PREVIOUS stays exactly at pressAmount=1 for a short moment.
    // This makes user mode visually match the developer preview exactly.
    if (isPrevious && _arcadeJoystickPeakHoldElapsed < peakHold) {
      _arcadeJoystickAnimElapsed = pressDuration;
      _arcadeJoystickPeakHoldElapsed += dt;
      _applyAllTransforms(save: false, repaint: false);
      return true;
    }

    // Phase 3: smooth return from the same exact pose.
    _arcadeJoystickAnimElapsed += dt;
    final total = pressDuration + returnDuration;

    if (_arcadeJoystickAnimElapsed >= total) {
      _arcadeJoystickAnimElapsed = 0;
      _arcadeJoystickAnimDirection = 0;
      _arcadeJoystickAnimating = false;
      _arcadeJoystickPeakFrameShown = false;
      _arcadeJoystickPeakHoldElapsed = 0;
    }

    _applyAllTransforms(save: false, repaint: false);
    return true;
  }

  double get _arcadeJoystickPreviousReturnProgress {
    if (!_arcadeJoystickAnimating || _arcadeJoystickAnimDirection >= 0) {
      return 0;
    }

    final pressDuration = math.max(.0001, _activeArcadeJoystickPressDuration);
    final returnDuration = math.max(.0001, _activeArcadeJoystickReturnDuration);

    if (!_arcadeJoystickPeakFrameShown) return 0;
    if (_arcadeJoystickPeakHoldElapsed < _arcadeJoystickPreviousPeakHold) {
      return 0;
    }

    final returnElapsed =
        (_arcadeJoystickAnimElapsed - pressDuration).clamp(0.0, returnDuration);
    return (returnElapsed / returnDuration).clamp(0.0, 1.0).toDouble();
  }

  double get _arcadeJoystickPressAmount {
    if (!_arcadeJoystickAnimating) return 0;
    final pressDuration = _activeArcadeJoystickPressDuration;
    final returnDuration = _activeArcadeJoystickReturnDuration;
    if (pressDuration <= 0) return 0;
    if (_arcadeJoystickAnimElapsed <= pressDuration) {
      final t = (_arcadeJoystickAnimElapsed / pressDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      return t * t * (3 - 2 * t);
    }
    final returnTime = _arcadeJoystickAnimElapsed - pressDuration;
    if (returnDuration <= 0) return 0;
    final t = (returnTime / returnDuration)
        .clamp(0.0, 1.0)
        .toDouble();
    final eased = t * t * (3 - 2 * t);
    return 1 - eased;
  }

  void _startArcadeJoystickAnimation(double direction) {
    _arcadeJoystickAnimating = true;
    _arcadeJoystickAnimElapsed = 0;
    _arcadeJoystickAnimDirection = direction.sign == 0 ? 1 : direction.sign;
    _arcadeJoystickPeakFrameShown = false;
    _arcadeJoystickPeakHoldElapsed = 0;

    // Apply the correct NEXT/PREVIOUS branch immediately.
    _applyAllTransforms(save: false, repaint: false);
  }

  void _browseArcadeGames(int direction) {
    if (_arcadeGames.isEmpty || direction == 0 || _arcadeCarouselAnimating) {
      return;
    }

    final length = _arcadeGames.length;
    var next = _arcadeSelectedGameIndex + direction;
    while (next < 0) {
      next += length;
    }
    next %= length;

    _arcadeCarouselFromIndex = _arcadeSelectedGameIndex;
    _arcadeCarouselToIndex = next;
    _arcadeCarouselDirection = direction.sign;
    _arcadeCarouselElapsed = 0;
    _arcadeCarouselAnimating = true;

    _startArcadeJoystickAnimation(direction.toDouble());
    _requestArcadeDisplayRefresh();
    if (mounted) setState(() {});
  }

  Future<Texture2D> _makeSpaceBackdropTexture() async {
    const width = 1024;
    const height = 512;
    const textureScale = .40;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(textureScale);

    final base = ui.Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(width.toDouble(), height.toDouble()),
        const <Color>[
          Color(0xFF030405),
          Color(0xFF0A0A05),
          Color(0xFF171507),
          Color(0xFF070806),
          Color(0xFF020304),
        ],
        const <double>[0, .25, .48, .72, 1],
      );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      base,
    );

    final clouds = <({Offset center, double radius, Color color})>[
      (center: const Offset(235, 245), radius: 330, color: const Color(0x556B5A08)),
      (center: const Offset(565, 145), radius: 285, color: const Color(0x3D8B7410)),
      (center: const Offset(830, 340), radius: 360, color: const Color(0x426A590B)),
      (center: const Offset(490, 420), radius: 260, color: const Color(0x244D430D)),
    ];
    for (final cloud in clouds) {
      final paint = ui.Paint()
        ..shader = ui.Gradient.radial(
          cloud.center,
          cloud.radius,
          <Color>[cloud.color, const Color(0x00000000)],
          const <double>[0, 1],
        );
      canvas.drawCircle(cloud.center, cloud.radius, paint);
    }

    final rng = math.Random(48173);
    for (var i = 0; i < 48; i++) {
      final x = rng.nextDouble() * width;
      final y = rng.nextDouble() * height;
      final bright = rng.nextDouble();
      final radius = .45 + rng.nextDouble() * (bright > .92 ? 2.2 : 1.0);
      final alpha = 35 + (bright * 95).round();
      final warm = rng.nextDouble() < .22;
      final color = warm
          ? Color.fromARGB(alpha, 255, 235, 150)
          : Color.fromARGB(alpha, 225, 230, 218);
      canvas.drawCircle(Offset(x, y), radius, ui.Paint()..color = color);
    }

    final image = await recorder
        .endRecording()
        .toImage((width * textureScale).round(), (height * textureScale).round());
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  Future<void> _buildSpaceBackdrop() async {
    final texture = await _makeSpaceBackdropTexture();
    _spaceBackdropTexture = texture;
    final material = _unlit(const Color(0xFFFFFFFF))
      ..name = 'sooky_arcade_space_backdrop_material'
      ..baseColorTexture = texture
      ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
      ..vertexColorWeight = 0
      ..doubleSided = true;

    final backdrop = Node(
      name: 'sooky_arcade_space_backdrop',
      mesh: Mesh(IcosphereGeometry(radius: .5, subdivisions: 3), material),
    )
      ..position = vm.Vector3(_roomX, 2.2, _roomZ)
      ..scale = vm.Vector3.all(150)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -.35)
      ..castsShadows = false
      ..raycastable = false
      ..highlightColor = null;
    _spaceBackdrop = backdrop;
    _scene.add(backdrop);
  }

  Color _arcadeGlowColor({double alpha = 1}) {
    return Color.fromARGB(
      (alpha.clamp(0.0, 1.0) * 255).round(),
      _arcadeGlowR.round().clamp(0, 255).toInt(),
      _arcadeGlowG.round().clamp(0, 255).toInt(),
      _arcadeGlowB.round().clamp(0, 255).toInt(),
    );
  }

  void _buildArcadeInteraction() {
    final hitboxMaterial = _unlit(const Color(0x01000000));
    _arcadeHitboxMaterial = hitboxMaterial;

    final root = Node(name: 'arcade_interaction_glow');
    _arcadeGlowRoot = root;
    _arcadeGlowEdges.clear();
    _arcadeGlowBands.clear();

    const segmentCount = 18;
    const bandCount = 6;
    for (var band = 0; band < bandCount; band++) {
      for (var segment = 0; segment < segmentCount; segment++) {
        final material = _unlit(const Color(0x00000000));
        final node = Node(
          name: 'arcade_glow_band_${band}_$segment',
          mesh: Mesh(CuboidGeometry(vm.Vector3.all(1)), material),
        )
          ..castsShadows = false
          ..raycastable = false
          ..highlightColor = null;
        root.add(node);
        _arcadeGlowBands.add(
          _ArcadeGlowBandNode(
            node: node,
            material: material,
            bandIndex: band,
            segmentIndex: segment,
          ),
        );
      }
    }

    _scene.add(root);

    final hitbox = Node(
      name: 'arcade_click_hitbox',
      mesh: Mesh(CuboidGeometry(vm.Vector3.all(1)), hitboxMaterial),
    )
      ..castsShadows = false
      ..raycastable = true
      ..highlightColor = null;
    _arcadeHitboxNode = hitbox;
    _scene.add(hitbox);
    _updateArcadeInteractionVisual();
  }

  bool _tickArcadeGlowMotion(double dt) {
    var changed = false;

    if (_arcadeGlowAutoRotate && _arcadeGlowRotationSpeed.abs() > .0001) {
      final direction = _arcadeGlowRotateRight ? 1.0 : -1.0;
      _arcadeGlowSpinAngle =
          (_arcadeGlowSpinAngle + direction * _arcadeGlowRotationSpeed * dt) %
              360.0;
      changed = true;
    }

    if (_arcadeGlowAutoBob && _arcadeGlowBobAmount.abs() > .0001) {
      _arcadeGlowBobPhase =
          (_arcadeGlowBobPhase + dt * _arcadeGlowBobSpeed * math.pi * 2) %
              (math.pi * 2);
      changed = true;
    }

    if (changed) {
      _updateArcadeInteractionVisual();
    }
    return changed;
  }

  void _updateArcadeInteractionVisual() {
    final root = _arcadeGlowRoot;
    final hitbox = _arcadeHitboxNode;
    if (root == null || hitbox == null || _arcadeGlowBands.isEmpty) return;

    final rotation = _rotationFromDegrees(_arcadeRotX, _arcadeRotY, _arcadeRotZ);
    final showRoot = (_userModeActive && !_arcadeFocusLocked) ||
        (!_userModeActive && _arcadeHighlightVisible);

    final bobOffset = _arcadeGlowAutoBob
        ? math.sin(_arcadeGlowBobPhase) * _arcadeGlowBobAmount
        : 0.0;
    final visualRotation =
        vm.Quaternion.copy(rotation) *
        _rotationFromDegrees(0, _arcadeGlowSpinAngle, 0);

    root
      ..visible = showRoot
      ..position = vm.Vector3(_arcadeX, _arcadeY + bobOffset, _arcadeZ)
      ..rotation = visualRotation;
    hitbox
      ..position = vm.Vector3(_arcadeX, _arcadeY, _arcadeZ)
      ..rotation = vm.Quaternion.copy(rotation)
      ..scale = vm.Vector3(_arcadeSizeX, _arcadeSizeY, _arcadeSizeZ);

    const segmentCount = 18;
    const bandCount = 6;
    final radiusX = math.max(.08, _arcadeSizeX * .5);
    final radiusZ = math.max(.08, _arcadeSizeZ * .5);
    final height = math.max(.12, _arcadeSizeY);
    final bandHeight = math.max(.05, height / bandCount * 1.06);
    final avgRadius = (radiusX + radiusZ) * .5;
    final segmentWidth = math.max(.05, (2 * math.pi * avgRadius / segmentCount) * .95);
    final segmentDepth = math.max(.03, math.min(radiusX, radiusZ) * .20);

    for (final band in _arcadeGlowBands) {
      final bandT = bandCount == 1 ? .5 : band.bandIndex / (bandCount - 1);
      final y = -height * .5 + height * bandT;
      final angle = (band.segmentIndex / segmentCount) * math.pi * 2;
      final x = math.cos(angle) * radiusX;
      final z = math.sin(angle) * radiusZ;
      band.node
        ..visible = showRoot
        ..position = vm.Vector3(x, y, z)
        ..rotation = _rotationFromDegrees(0, -_radToDeg(angle), 0)
        ..scale = vm.Vector3(segmentWidth, bandHeight, segmentDepth);
    }
    _updateArcadeGlowMaterial();
  }

  Color _arcadeGlowGradientColor(double bandT, {double pulse = 1.0}) {
    final midpoint = _arcadeGlowBlendMidpoint.clamp(.05, .95).toDouble();
    final easedT = bandT <= midpoint
        ? .5 * (bandT / midpoint)
        : .5 + .5 * ((bandT - midpoint) / (1 - midpoint));
    final r = (_arcadeGlowBottomR + (_arcadeGlowTopR - _arcadeGlowBottomR) * easedT)
        .clamp(0.0, 255.0)
        .round();
    final g = (_arcadeGlowBottomG + (_arcadeGlowTopG - _arcadeGlowBottomG) * easedT)
        .clamp(0.0, 255.0)
        .round();
    final b = (_arcadeGlowBottomB + (_arcadeGlowTopB - _arcadeGlowBottomB) * easedT)
        .clamp(0.0, 255.0)
        .round();
    final intensity = _arcadeGlowIntensity.clamp(0.0, 2.0).toDouble();
    final globalOpacity = _arcadeGlowOpacity.clamp(0.0, 1.0).toDouble();
    final localOpacity = (_arcadeGlowBottomOpacity +
            (_arcadeGlowTopOpacity - _arcadeGlowBottomOpacity) * easedT)
        .clamp(0.0, 1.0)
        .toDouble();
    final alpha = (localOpacity * globalOpacity * intensity * pulse)
        .clamp(0.0, .95)
        .toDouble();
    return Color.fromRGBO(r, g, b, alpha);
  }

  void _updateArcadeGlowMaterial() {
    final pulse = .70 + .30 * ((math.sin(_arcadePulseClock * 2.6) + 1) * .5);
    if (_arcadeGlowBands.isEmpty) return;
    const bandCount = 6;
    for (final band in _arcadeGlowBands) {
      final bandT = bandCount == 1 ? .5 : band.bandIndex / (bandCount - 1);
      final segmentAngle =
          (band.segmentIndex / 18.0) * math.pi * 2 +
          _arcadeGlowSpinAngle * math.pi / 180.0;
      final travelWave =
          .72 + .28 * ((math.sin(segmentAngle) + 1.0) * .5);
      band.material.baseColorFactor = _vectorColor(
        _arcadeGlowGradientColor(
          bandT,
          pulse: pulse * travelWave,
        ),
      );
    }
  }

  PerspectiveCamera _currentCamera() {
    return PerspectiveCamera(
      position: vm.Vector3(_cameraX, _cameraY, _cameraZ),
      target: vm.Vector3(_targetX, _targetY, _targetZ),
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: _degToRad(_cameraFov),
      fovNear: .05,
      fovFar: 100,
    );
  }

  bool _rayHitsNode(Offset localPosition, Node? node) {
    if (node == null) return false;
    final size = MediaQuery.sizeOf(context);
    final ray = _currentCamera().screenPointToRay(localPosition, size);
    return raycastNode(node, ray, includeInvisible: true) != null;
  }

  bool _isArcadeScreenHit(Offset localPosition) =>
      _rayHitsNode(localPosition, _arcadeScreenNode);

  bool _isArcadeJoystickPressHit(Offset localPosition) =>
      _rayHitsNode(localPosition, _arcadeJoystickPressHitboxNode);

  bool _isArcadeEnterButtonHit(Offset localPosition) =>
      _rayHitsNode(localPosition, _arcadeEnterButtonRedHitNode);

  bool _isTvScreenHit(Offset localPosition) =>
      _rayHitsNode(localPosition, _tvScreenNode);

  _TvScreenAction _tvScreenActionAt(Offset localPosition) {
    final screen = _tvScreenNode;
    if (screen == null) return _TvScreenAction.none;

    final size = MediaQuery.sizeOf(context);
    final ray = _currentCamera().screenPointToRay(localPosition, size);
    final hit = raycastNode(screen, ray, includeInvisible: true);
    final uv = hit?.uv;
    if (uv == null) return _TvScreenAction.none;

    // The generated TV interface is a 768x1024 portrait texture.
    final x = uv.x * 768.0;
    final y = uv.y * 1024.0;

    final backRect = const Rect.fromLTWH(58, 62, 94, 94);
    if (backRect.contains(Offset(x, y))) {
      return _TvScreenAction.back;
    }

    final game = _arcadeGames[
        _tvSelectedGameIndex.clamp(0, _arcadeGames.length - 1).toInt()];
    final buttonScale = _tvUiButtonsScale.clamp(.35, 4.0);
    final gap = 26 * _tvUiButtonsGap.clamp(.3, 4.0);
    final bw = 250 * buttonScale;
    final bh = 116 * buttonScale;
    final by = 430 + _tvUiButtonsOffsetY;
    final twoModes = game.hasOffline && game.hasOnline;
    final groupWidth = twoModes ? bw * 2 + gap : bw;
    final startX = (768 - groupWidth) * .5 + _tvUiButtonsOffsetX;

    if (game.hasOffline) {
      final offlineRect = Rect.fromLTWH(startX, by, bw, bh);
      if (offlineRect.contains(Offset(x, y))) {
        return _TvScreenAction.offline;
      }
    }
    if (game.hasOnline) {
      final onlineX = twoModes ? startX + bw + gap : startX;
      final onlineRect = Rect.fromLTWH(onlineX, by, bw, bh);
      if (onlineRect.contains(Offset(x, y))) {
        return _TvScreenAction.online;
      }
    }

    final infoScale = _tvUiInfoScale.clamp(.4, 3.0);
    final infoSize = 92 * infoScale;
    final infoRect = Rect.fromLTWH(
      768 - 72 - infoSize + _tvUiInfoOffsetX,
      1024 - 72 - infoSize + _tvUiInfoOffsetY,
      infoSize,
      infoSize,
    );
    if (infoRect.contains(Offset(x, y))) {
      return _TvScreenAction.info;
    }

    return _TvScreenAction.none;
  }

  Widget _tvModeRootForGame(int gameIndex, {required bool online}) {
    switch (gameIndex) {
      case 0:
        return online
            ? const MultiplayerEntryScreen()
            : const LocalPlayersScreen();
      case 1:
        return const HeadsUpSetupScreen();
      case 2:
        return const KillerKilledHomeScreen();
      case 3:
        return GuessTimeHomeScreen(initialOnline: online);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openTvGameModePage({required bool online}) async {
    if (!_tvModeActive || _tvTransitionAnimating) return;

    final index = _tvSelectedGameIndex
        .clamp(0, _arcadeGames.length - 1)
        .toInt();
    final game = _arcadeGames[index];

    final available = online ? game.hasOnline : game.hasOffline;
    if (!available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              online
                  ? 'الأون لاين غير متوفر لهذه اللعبة حاليًا.'
                  : 'الأوف لاين غير متوفر لهذه اللعبة.',
              textAlign: TextAlign.center,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final root = _tvModeRootForGame(index, online: online);

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withOpacity(.88),
        transitionDuration: const Duration(milliseconds: 620),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _TvExpandedGamePage(
            title: game.title,
            modeLabel: online ? 'اللعب مع صديق' : 'اللعب محلياً',
            root: root,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          );
          final scale = Tween<double>(
            begin: .16,
            end: 1.0,
          ).animate(curved);
          final fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0, .62, curve: Curves.easeOut),
          );

          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _returnFromTvToArcade() {
    if (!_tvModeActive || _tvTransitionAnimating) return;

    _tvDetailsVisible = false;
    _tvModeActive = false;
    _tvTransitionAnimating = false;
    _tvTransitionElapsed = 0;
    _tvIdleClock = 0;

    _motionPlaying = false;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userLookVelocityYaw = 0;
    _userLookVelocityPitch = 0;
    _userCameraIdleSeconds = 0;

    // Reuse the existing smooth arcade camera transition, starting from
    // the exact current TV camera and ending at the arcade focus camera.
    _arcadeStartCameraX = _cameraX;
    _arcadeStartCameraY = _cameraY;
    _arcadeStartCameraZ = _cameraZ;
    _arcadeStartTargetX = _targetX;
    _arcadeStartTargetY = _targetY;
    _arcadeStartTargetZ = _targetZ;
    _arcadeStartFov = _cameraFov;

    _arcadeCameraReturning = false;
    _arcadeFocusLocked = false;
    _arcadeCameraAnimating = true;
    _arcadeCameraTransitionElapsed = 0;

    _applyTvTransform();
    _updateArcadeInteractionVisual();
    if (mounted) setState(() {});
  }

  void _handleSceneTap(TapUpDetails details) {
    if (_tvTransitionAnimating) return;

    if (_tvModeActive) {
      final action = _tvScreenActionAt(details.localPosition);
      switch (action) {
        case _TvScreenAction.back:
          _returnFromTvToArcade();
          break;
        case _TvScreenAction.offline:
          unawaited(_openTvGameModePage(online: false));
          break;
        case _TvScreenAction.online:
          unawaited(_openTvGameModePage(online: true));
          break;
        case _TvScreenAction.info:
          _tvDetailsVisible = !_tvDetailsVisible;
          unawaited(_refreshTvGameScreen());
          break;
        case _TvScreenAction.none:
          if (!_isTvScreenHit(details.localPosition)) {
            _returnFromTvToArcade();
          }
          break;
      }
      return;
    }

    if (_userModeActive && _arcadeFocusLocked) {
      if (_isArcadeEnterButtonHit(details.localPosition)) {
        _pressArcadeEnterButton(openGame: true);
        return;
      }

      if (_isArcadeJoystickPressHit(details.localPosition)) {
        final direction = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
        _browseArcadeGames(direction);
        return;
      }

      if (_isArcadeScreenHit(details.localPosition)) {
        _openSelectedArcadeGame();
        return;
      }

      // المستخدم داخل الآركيد بالفعل؛ جسم الآركيد لا يعيد تشغيل الانتقال.
      return;
    }

    if (_arcadeCameraAnimating) return;

    final hitbox = _arcadeHitboxNode;
    if (hitbox == null) return;
    final size = MediaQuery.sizeOf(context);
    final ray = _currentCamera().screenPointToRay(details.localPosition, size);
    final hit = raycastNode(hitbox, ray, includeInvisible: true);
    if (hit == null) return;
    _startArcadeCameraTransition();
  }

  void _handleSceneSecondaryTap(TapUpDetails details) {
    if (!_userModeActive || !_arcadeFocusLocked) return;
    if (!_isArcadeJoystickPressHit(details.localPosition)) return;
    _browseArcadeGames(-1);
  }

  void _handleScenePanStart(DragStartDetails details) {
    _arcadeScreenGestureActive =
        _userModeActive &&
        _arcadeFocusLocked &&
        _isArcadeScreenHit(details.localPosition);
    _arcadeScreenGestureDx = 0;
  }

  void _handleScenePanUpdate(DragUpdateDetails details) {
    if (_arcadeScreenGestureActive) {
      _arcadeScreenGestureDx += details.delta.dx;
      return;
    }
    _handleLookDrag(details);
  }

  void _handleScenePanEnd(DragEndDetails details) {
    if (!_arcadeScreenGestureActive) return;
    final dx = _arcadeScreenGestureDx;
    _arcadeScreenGestureActive = false;
    _arcadeScreenGestureDx = 0;
    if (dx.abs() < 24) return;
    // سحب لليسار = التالي، سحب لليمين = السابق.
    _browseArcadeGames(dx < 0 ? 1 : -1);
  }

  void _openSelectedArcadeGame() {
    if (!mounted || _tvTransitionAnimating || _tvModeActive) return;

    final index =
        _arcadeSelectedGameIndex.clamp(0, _arcadeGames.length - 1).toInt();

    if (_arcadeGames[index].isBack) {
      _startArcadeReturnTransition();
      return;
    }

    _startTvGameTransition(index);
  }

  void _startTvGameTransition(int gameIndex) {
    if (_tvTransitionAnimating) return;

    _tvSelectedGameIndex = gameIndex;
    _tvDetailsVisible = false;
    unawaited(_refreshTvGameScreen());
    _tvTransitionAnimating = true;
    _tvModeActive = false;
    _tvTransitionElapsed = 0;
    _tvIdleClock = 0;

    _motionPlaying = false;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userLookVelocityYaw = 0;
    _userLookVelocityPitch = 0;
    _userCameraIdleSeconds = 0;

    _tvTransitionCameraStartX = _cameraX;
    _tvTransitionCameraStartY = _cameraY;
    _tvTransitionCameraStartZ = _cameraZ;
    _tvTransitionTargetStartX = _targetX;
    _tvTransitionTargetStartY = _targetY;
    _tvTransitionTargetStartZ = _targetZ;
    _tvTransitionFovStart = _cameraFov;

    // Arcade interactions stop as soon as the TV cinematic begins.
    _arcadeFocusLocked = false;
    _arcadeCameraAnimating = false;

    _applyTvTransform();
    _updateArcadeInteractionVisual();
    if (mounted) setState(() {});
  }

  void _startArcadeReturnTransition() {
    if (!_arcadeFocusLocked || _arcadeCameraAnimating) return;

    _motionPlaying = false;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userLookVelocityYaw = 0;
    _userLookVelocityPitch = 0;
    _userCameraIdleSeconds = 0;

    _arcadeFocusLocked = false;
    _arcadeCameraAnimating = true;
    _arcadeCameraReturning = true;
    _arcadeCameraTransitionElapsed = 0;

    // Start from the exact current arcade view.
    _arcadeStartCameraX = _cameraX;
    _arcadeStartCameraY = _cameraY;
    _arcadeStartCameraZ = _cameraZ;
    _arcadeStartTargetX = _targetX;
    _arcadeStartTargetY = _targetY;
    _arcadeStartTargetZ = _targetZ;
    _arcadeStartFov = _cameraFov;

    _updateArcadeInteractionVisual();
    if (mounted) setState(() {});
  }

  void _startArcadeCameraTransition() {
    _motionPlaying = false;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userLookVelocityYaw = 0;
    _userLookVelocityPitch = 0;
    _userCameraIdleSeconds = 0;
    _arcadeCameraEditMode = false;
    _arcadeFocusLocked = false;
    _arcadeCameraAnimating = true;
    _arcadeCameraTransitionElapsed = 0;
    _arcadeStartCameraX = _cameraX;
    _arcadeStartCameraY = _cameraY;
    _arcadeStartCameraZ = _cameraZ;
    _arcadeStartTargetX = _targetX;
    _arcadeStartTargetY = _targetY;
    _arcadeStartTargetZ = _targetZ;
    _arcadeStartFov = _cameraFov;

    _arcadeOriginCameraX = _cameraX;
    _arcadeOriginCameraY = _cameraY;
    _arcadeOriginCameraZ = _cameraZ;
    _arcadeOriginTargetX = _targetX;
    _arcadeOriginTargetY = _targetY;
    _arcadeOriginTargetZ = _targetZ;
    _arcadeOriginFov = _cameraFov;
    _arcadeCameraReturning = false;

    _updateArcadeInteractionVisual();
  }

  void _previewArcadeFocusCamera() {
    _cameraX = _arcadeFocusCameraX;
    _cameraY = _arcadeFocusCameraY;
    _cameraZ = _arcadeFocusCameraZ;
    _targetX = _arcadeFocusTargetX;
    _targetY = _arcadeFocusTargetY;
    _targetZ = _arcadeFocusTargetZ;
    _cameraFov = _arcadeFocusFov;
    _syncCameraAnglesFromCurrentView();
    _applyAllTransforms(save: false, repaint: false);
  }

  void _syncArcadeFocusFromCurrentCamera({bool save = true}) {
    _arcadeFocusCameraX = _cameraX;
    _arcadeFocusCameraY = _cameraY;
    _arcadeFocusCameraZ = _cameraZ;
    _arcadeFocusTargetX = _targetX;
    _arcadeFocusTargetY = _targetY;
    _arcadeFocusTargetZ = _targetZ;
    _arcadeFocusFov = _cameraFov;
    if (save) _scheduleSave();
  }

  void _beginArcadeCameraEditing() {
    if (_lookLimitPreviewMode.isNotEmpty) _finishLookLimitPreview();
    _motionPlaying = false;
    _arcadeCameraAnimating = false;
    _arcadeFocusLocked = false;
    _arcadeCameraEditMode = true;

    _arcadeEditRestoreCameraX = _cameraX;
    _arcadeEditRestoreCameraY = _cameraY;
    _arcadeEditRestoreCameraZ = _cameraZ;
    _arcadeEditRestoreTargetX = _targetX;
    _arcadeEditRestoreTargetY = _targetY;
    _arcadeEditRestoreTargetZ = _targetZ;
    _arcadeEditRestoreFov = _cameraFov;

    _arcadeEditOriginalFocusCameraX = _arcadeFocusCameraX;
    _arcadeEditOriginalFocusCameraY = _arcadeFocusCameraY;
    _arcadeEditOriginalFocusCameraZ = _arcadeFocusCameraZ;
    _arcadeEditOriginalFocusTargetX = _arcadeFocusTargetX;
    _arcadeEditOriginalFocusTargetY = _arcadeFocusTargetY;
    _arcadeEditOriginalFocusTargetZ = _arcadeFocusTargetZ;
    _arcadeEditOriginalFocusFov = _arcadeFocusFov;

    _previewArcadeFocusCamera();
    if (mounted) setState(() {});
  }

  void _finishArcadeCameraEditing() {
    _syncArcadeFocusFromCurrentCamera(save: true);
    _arcadeCameraEditMode = false;
    _arcadeFocusLocked = true;
    _motionPlaying = false;
    if (mounted) setState(() {});
  }

  void _cancelArcadeCameraEditing() {
    _arcadeFocusCameraX = _arcadeEditOriginalFocusCameraX;
    _arcadeFocusCameraY = _arcadeEditOriginalFocusCameraY;
    _arcadeFocusCameraZ = _arcadeEditOriginalFocusCameraZ;
    _arcadeFocusTargetX = _arcadeEditOriginalFocusTargetX;
    _arcadeFocusTargetY = _arcadeEditOriginalFocusTargetY;
    _arcadeFocusTargetZ = _arcadeEditOriginalFocusTargetZ;
    _arcadeFocusFov = _arcadeEditOriginalFocusFov;

    _cameraX = _arcadeEditRestoreCameraX;
    _cameraY = _arcadeEditRestoreCameraY;
    _cameraZ = _arcadeEditRestoreCameraZ;
    _targetX = _arcadeEditRestoreTargetX;
    _targetY = _arcadeEditRestoreTargetY;
    _targetZ = _arcadeEditRestoreTargetZ;
    _cameraFov = _arcadeEditRestoreFov;
    _arcadeCameraEditMode = false;
    _arcadeFocusLocked = true;
    _motionPlaying = false;
    _syncCameraAnglesFromCurrentView();
    _applyAllTransforms(save: false, repaint: false);
    if (mounted) setState(() {});
  }




  void _applyTvCameraPreviewNow() {
    if (!_tvCameraLivePreview || _userModeActive) return;

    _cameraX = _tvCameraX;
    _cameraY = _tvCameraY;
    _cameraZ = _tvCameraZ;
    _targetX = _tvCameraTargetX;
    _targetY = _tvCameraTargetY;
    _targetZ = _tvCameraTargetZ;
    _cameraFov = _tvCameraFov;

    _syncCameraAnglesFromCurrentView();
    _applyAllTransforms(save: false, repaint: false);
    if (mounted) setState(() {});
  }

  void _applyTvLookLimits() {
    if (!_tvModeActive || _tvTransitionAnimating) return;

    final center = _anglesBetween(
      _tvCameraX,
      _tvCameraY,
      _tvCameraZ,
      _tvCameraTargetX,
      _tvCameraTargetY,
      _tvCameraTargetZ,
    );

    final yawOffset = _normalizeAngle(_cameraYaw - center.yaw).clamp(
          -_degToRad(_tvLookLeftDeg),
          _degToRad(_tvLookRightDeg),
        ).toDouble();

    final pitchOffset = (_cameraPitch - center.pitch).clamp(
          -_degToRad(_tvLookDownDeg),
          _degToRad(_tvLookUpDeg),
        ).toDouble();

    _cameraYaw = center.yaw + yawOffset;
    _cameraPitch = (center.pitch + pitchOffset).clamp(-1.55, 1.55).toDouble();
    _updateTargetFromCameraAngles();
  }

  bool _tickTvTransition(double dt) {
    if (!_tvTransitionAnimating) return false;

    _tvTransitionElapsed += dt;

    final tvDuration = math.max(.05, _tvEntryDuration);
    final cameraDuration = math.max(.05, _tvCameraDuration);

    final cameraRaw =
        (_tvTransitionElapsed / cameraDuration).clamp(0.0, 1.0).toDouble();
    final cameraT = cameraRaw *
        cameraRaw *
        cameraRaw *
        (cameraRaw * (cameraRaw * 6 - 15) + 10);

    double lerp(double a, double b) => a + (b - a) * cameraT;

    _cameraX = lerp(_tvTransitionCameraStartX, _tvCameraX);
    _cameraY = lerp(_tvTransitionCameraStartY, _tvCameraY);
    _cameraZ = lerp(_tvTransitionCameraStartZ, _tvCameraZ);
    _targetX = lerp(_tvTransitionTargetStartX, _tvCameraTargetX);
    _targetY = lerp(_tvTransitionTargetStartY, _tvCameraTargetY);
    _targetZ = lerp(_tvTransitionTargetStartZ, _tvCameraTargetZ);
    _cameraFov = lerp(_tvTransitionFovStart, _tvCameraFov);

    _applyTvTransform();

    if (_tvTransitionElapsed >= math.max(tvDuration, cameraDuration)) {
      _tvTransitionAnimating = false;
      _tvModeActive = true;
      _tvTransitionElapsed = 0;
      _tvIdleClock = 0;

      // Force exact configured final camera values.
      _cameraX = _tvCameraX;
      _cameraY = _tvCameraY;
      _cameraZ = _tvCameraZ;
      _targetX = _tvCameraTargetX;
      _targetY = _tvCameraTargetY;
      _targetZ = _tvCameraTargetZ;
      _cameraFov = _tvCameraFov;

      _syncCameraAnglesFromCurrentView();
      _applyTvTransform();
    }

    return true;
  }

  bool _tickTvIdleMotion(double dt) {
    if (!_tvModeActive || _tvTransitionAnimating || !_tvIdleMotionEnabled) {
      return false;
    }

    _tvIdleClock += dt;
    _applyTvTransform();
    return true;
  }

  bool _tickArcadeCameraTransition(double dt) {
    if (!_arcadeCameraAnimating) return false;
    _arcadeCameraTransitionElapsed += dt;
    final duration = math.max(.05, _arcadeTransitionSeconds);
    final raw = (_arcadeCameraTransitionElapsed / duration).clamp(0.0, 1.0).toDouble();
    final t = raw * raw * (3 - 2 * raw);

    double lerp(double a, double b) => a + (b - a) * t;

    final targetCameraX =
        _arcadeCameraReturning ? _arcadeOriginCameraX : _arcadeFocusCameraX;
    final targetCameraY =
        _arcadeCameraReturning ? _arcadeOriginCameraY : _arcadeFocusCameraY;
    final targetCameraZ =
        _arcadeCameraReturning ? _arcadeOriginCameraZ : _arcadeFocusCameraZ;
    final targetTargetX =
        _arcadeCameraReturning ? _arcadeOriginTargetX : _arcadeFocusTargetX;
    final targetTargetY =
        _arcadeCameraReturning ? _arcadeOriginTargetY : _arcadeFocusTargetY;
    final targetTargetZ =
        _arcadeCameraReturning ? _arcadeOriginTargetZ : _arcadeFocusTargetZ;
    final targetFov =
        _arcadeCameraReturning ? _arcadeOriginFov : _arcadeFocusFov;

    _cameraX = lerp(_arcadeStartCameraX, targetCameraX);
    _cameraY = lerp(_arcadeStartCameraY, targetCameraY);
    _cameraZ = lerp(_arcadeStartCameraZ, targetCameraZ);
    _targetX = lerp(_arcadeStartTargetX, targetTargetX);
    _targetY = lerp(_arcadeStartTargetY, targetTargetY);
    _targetZ = lerp(_arcadeStartTargetZ, targetTargetZ);
    _cameraFov = lerp(_arcadeStartFov, targetFov);

    if (raw >= 1) {
      _arcadeCameraAnimating = false;
      final returned = _arcadeCameraReturning;
      _arcadeCameraReturning = false;
      _arcadeFocusLocked = !returned;
      _motionPlaying = returned;
      _syncCameraAnglesFromCurrentView();
      _applyActiveUserLookLimits();
      _updateTargetFromCameraAngles();
      _updateArcadeInteractionVisual();
    }
    return true;
  }

  void _applyDefaultAvatar(Node character) {
    final visibleNodes = KillerKilledAvatar.defaultAvatar.visibleNodeNames;
    for (final name in KillerKilledAvatar.customizableNodeNames) {
      final node = character.getChildByName(name);
      if (node != null) {
        node.visible = visibleNodes.contains(name);
      }
    }
    final bodyNode = character.getChildByName('Body_010');
    if (bodyNode != null) {
      bodyNode.visible = true;
    }
  }

  void _captureJointNodes(Node character) {
    for (final tuning in _poseTunings) {
      final node = character.getChildByName(tuning.nodeName);
      if (node == null) continue;
      _jointNodes[tuning.nodeName] = node;
      _jointBase[tuning.nodeName] = _NodeSnapshot.fromNode(node);
    }
  }

  void _configureScene() {
    _scene.renderScale = _renderScale;
    _scene.exposure = _sceneExposure;
    _scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = true
      ..sampleCount = 4
      ..radius = .32
      ..intensity = .68;

    final yaw = _degToRad(_lightYawDeg);
    final pitch = _degToRad(_lightPitchDeg);
    final direction = vm.Vector3(
      math.cos(pitch) * math.cos(yaw),
      math.sin(pitch),
      math.cos(pitch) * math.sin(yaw),
    )..normalize();

    _scene.directionalLight = DirectionalLight(
      direction: direction,
      color: vm.Vector3(.93, .96, 1.0),
      intensity: _lightIntensity,
      castsShadow: true,
      shadowCascadeCount: 1,
      shadowMaxDistance: 20,
      shadowMapResolution: 1024,
      shadowSoftness: .15,
      shadowAmbientStrength: .18,
    );
  }

  void _applyAllTransforms({bool save = true, bool repaint = true}) {
    _configureScene();

    final room = _roomNode;
    if (room != null) {
      room.visible = _showRoom;
      room.position = vm.Vector3(_roomX, _roomY, _roomZ);
      room.rotation = _rotationFromDegrees(_roomRotX, _roomRotY, _roomRotZ);
      room.scale = vm.Vector3(_roomScaleX, _roomScaleY, _roomScaleZ);
    }

    _applyTvTransform();

    if (_legacyArcadeScreenNode != null &&
        !identical(_legacyArcadeScreenNode, _arcadeScreenNode)) {
      _legacyArcadeScreenNode!.visible = false;
    }
    if (_legacyArcadeJoystickNode != null &&
        !identical(_legacyArcadeJoystickNode, _arcadeJoystickNode)) {
      _legacyArcadeJoystickNode!.visible = false;
    }

    final arcadeScreen = _arcadeScreenNode;
    if (arcadeScreen != null) {
      arcadeScreen.visible =
          _showArcadeScreen && _arcadeCutRemainderNode == null;
      arcadeScreen.position = vm.Vector3.copy(_arcadeScreenBasePosition)
        ..add(vm.Vector3(_arcadeScreenX, _arcadeScreenY, _arcadeScreenZ));
      arcadeScreen.rotation =
          vm.Quaternion.copy(_arcadeScreenBaseRotation) *
          _rotationFromDegrees(
            _arcadeScreenRotX,
            _arcadeScreenRotY,
            _arcadeScreenRotZ,
          );
      arcadeScreen.scale = vm.Vector3(
        _arcadeScreenBaseScale.x * _arcadeScreenScaleX,
        _arcadeScreenBaseScale.y * _arcadeScreenScaleY,
        _arcadeScreenBaseScale.z * _arcadeScreenScaleZ,
      );

      final geometry = _arcadeDisplaySurfaceGeometry;
      final displayMaterial = _arcadeDisplayMaterial;
      if (_arcadeDisplayEnabled &&
          geometry != null &&
          displayMaterial != null) {
        displayMaterial
          ..baseColorTexture = _arcadeDisplayTexture
          ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
          ..vertexColorWeight = 0
          ..doubleSided = true
          ..alphaMode = AlphaMode.opaque;
        final currentMesh = arcadeScreen.mesh;
        final alreadyUsingDisplay = currentMesh != null &&
            currentMesh.primitives.isNotEmpty &&
            identical(currentMesh.primitives.first.material, displayMaterial);
        if (!alreadyUsingDisplay) {
          arcadeScreen.mesh = Mesh(geometry, displayMaterial);
        }
      } else if (_arcadeScreenOriginalMesh != null &&
          !identical(arcadeScreen.mesh, _arcadeScreenOriginalMesh)) {
        arcadeScreen.mesh = _arcadeScreenOriginalMesh;
      }
    }

    final arcadeJoystick = _arcadeJoystickNode;
    if (arcadeJoystick != null) {
      arcadeJoystick.visible =
          _showArcadeJoystick && _arcadeCutRemainderNode == null;
      final pressAmount = _arcadeJoystickDeveloperPreviewActive
          ? 1.0
          : _arcadeJoystickPressAmount;
      final pressDirection = _arcadeJoystickDeveloperPreviewActive
          ? _arcadeJoystickPreviewDirection
          : _arcadeJoystickAnimDirection;
      final previousAction = pressDirection < 0;
      final actionOffsetX = previousAction
          ? _arcadeJoystickPreviousOffsetX
          : _arcadeJoystickPressOffsetX;
      final actionOffsetY = previousAction
          ? _arcadeJoystickPreviousOffsetY
          : _arcadeJoystickPressOffsetY;
      final actionOffsetZ = previousAction
          ? _arcadeJoystickPreviousOffsetZ
          : _arcadeJoystickPressOffsetZ;
      final actionTiltPitch = previousAction
          ? _arcadeJoystickPreviousTiltPitch
          : _arcadeJoystickTiltPitch;
      final actionTiltYaw = previousAction
          ? _arcadeJoystickPreviousTiltYaw
          : _arcadeJoystickTiltYaw;
      final actionTiltRoll = previousAction
          ? _arcadeJoystickPreviousTiltRoll
          : _arcadeJoystickTiltRoll;

      final basePosition = vm.Vector3.copy(_arcadeJoystickBasePosition)
        ..add(vm.Vector3(
          _arcadeJoystickX,
          _arcadeJoystickY,
          _arcadeJoystickZ,
        ));

      final peakPosition = vm.Vector3.copy(_arcadeJoystickBasePosition)
        ..add(vm.Vector3(
          _arcadeJoystickX + actionOffsetX,
          _arcadeJoystickY + actionOffsetY,
          _arcadeJoystickZ + actionOffsetZ,
        ));

      final baseRotation =
          vm.Quaternion.copy(_arcadeJoystickBaseRotation) *
          _rotationFromDegrees(
            _arcadeJoystickRotX,
            _arcadeJoystickRotY,
            _arcadeJoystickRotZ,
          );

      final peakRotation =
          vm.Quaternion.copy(_arcadeJoystickBaseRotation) *
          _rotationFromDegrees(
            _arcadeJoystickRotX + actionTiltPitch,
            _arcadeJoystickRotY + actionTiltYaw,
            _arcadeJoystickRotZ + actionTiltRoll,
          );

      // Use one single interpolation path for both forward and return.
      // Since pressAmount rises 0→1 then falls 1→0, the return retraces
      // the exact same transform path in reverse with no extra arc.
      var resolvedPosition = vm.Vector3(
        basePosition.x + (peakPosition.x - basePosition.x) * pressAmount,
        basePosition.y + (peakPosition.y - basePosition.y) * pressAmount,
        basePosition.z + (peakPosition.z - basePosition.z) * pressAmount,
      );

      // During PREVIOUS return only, add a smooth bell-shaped compensation.
      // 0 at the start/end of return, strongest around the middle.
      if (previousAction && !_arcadeJoystickDeveloperPreviewActive) {
        final returnT = _arcadeJoystickPreviousReturnProgress;
        if (returnT > 0) {
          final arc = math.sin(returnT * math.pi) *
              _arcadeJoystickPreviousReturnCompStrength;
          resolvedPosition += vm.Vector3(
            _arcadeJoystickPreviousReturnCompX * arc,
            _arcadeJoystickPreviousReturnCompY * arc,
            _arcadeJoystickPreviousReturnCompZ * arc,
          );
        }
      }

      arcadeJoystick.position = resolvedPosition;
      arcadeJoystick.rotation =
          _slerpQuaternion(baseRotation, peakRotation, pressAmount);
      arcadeJoystick.scale = vm.Vector3(
        _arcadeJoystickBaseScale.x * _arcadeJoystickScaleX,
        _arcadeJoystickBaseScale.y * _arcadeJoystickScaleY,
        _arcadeJoystickBaseScale.z * _arcadeJoystickScaleZ,
      );
      _applyArcadePartMaterial(
        node: arcadeJoystick,
        originalMaterial: _arcadeJoystickOriginalMaterial,
        colorEnabled: _arcadeJoystickColorEnabled,
        colorR: _arcadeJoystickColorR,
        colorG: _arcadeJoystickColorG,
        colorB: _arcadeJoystickColorB,
        colorOpacity: _arcadeJoystickColorOpacity,
        cachedMaterial: _arcadeJoystickColorMaterial,
        onMaterialCached: (material) => _arcadeJoystickColorMaterial = material,
      );
      _updateArcadeJoystickPressHitbox();
    }

    _applyArcadeEnterButtonTransform();
    _updateArcadePartRevealVisuals();
    _updateArcadeCutterVisual();
    for (final part in _arcadeCutParts) {
      _applyArcadeCutPartTransform(part);
    }

    final character = _characterNode;
    if (character != null) {
      character.visible = _showCharacter;
      character.position = vm.Vector3(_characterX, _characterY, _characterZ);
      character.rotation = _rotationFromDegrees(
        _characterRotX,
        _characterRotY,
        _characterRotZ,
      );
      character.scale = vm.Vector3(
        _characterScaleX,
        _characterScaleY,
        _characterScaleZ,
      );
    }

    for (final tuning in _poseTunings) {
      final node = _jointNodes[tuning.nodeName];
      final base = _jointBase[tuning.nodeName];
      if (node == null || base == null) continue;
      node.position = vm.Vector3(
        base.position.x + tuning.offsetX,
        base.position.y + tuning.offsetY,
        base.position.z + tuning.offsetZ,
      );
      node.rotation = _withDelta(
        base.rotation,
        x: _degToRad(tuning.rotX),
        y: _degToRad(tuning.rotY),
        z: _degToRad(tuning.rotZ),
      );
    }

    final backdrop = _spaceBackdrop;
    if (backdrop != null) {
      backdrop.position = vm.Vector3(_roomX, 2.2, _roomZ);
    }
    _updateArcadeInteractionVisual();

    if (save) _scheduleSave();
    if (repaint && mounted) setState(() {});
  }

  vm.Quaternion _withDelta(
    vm.Quaternion base, {
    double x = 0,
    double y = 0,
    double z = 0,
  }) {
    var result = vm.Quaternion.copy(base);
    if (x != 0) {
      result = result * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), x);
    }
    if (y != 0) {
      result = result * vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), y);
    }
    if (z != 0) {
      result = result * vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), z);
    }
    return result;
  }

  vm.Quaternion _slerpQuaternion(
    vm.Quaternion a,
    vm.Quaternion b,
    double t,
  ) {
    final qa = vm.Quaternion.copy(a)..normalize();
    var qb = vm.Quaternion.copy(b)..normalize();

    var dot =
        qa.x * qb.x + qa.y * qb.y + qa.z * qb.z + qa.w * qb.w;

    if (dot < 0.0) {
      qb = vm.Quaternion(-qb.x, -qb.y, -qb.z, -qb.w);
      dot = -dot;
    }

    final clampedT = t.clamp(0.0, 1.0).toDouble();

    if (dot > 0.9995) {
      final out = vm.Quaternion(
        qa.x + (qb.x - qa.x) * clampedT,
        qa.y + (qb.y - qa.y) * clampedT,
        qa.z + (qb.z - qa.z) * clampedT,
        qa.w + (qb.w - qa.w) * clampedT,
      );
      out.normalize();
      return out;
    }

    final theta0 = math.acos(dot.clamp(-1.0, 1.0));
    final sinTheta0 = math.sin(theta0);
    if (sinTheta0.abs() < 1e-6) return qa;

    final theta = theta0 * clampedT;
    final s0 = math.sin(theta0 - theta) / sinTheta0;
    final s1 = math.sin(theta) / sinTheta0;

    final out = vm.Quaternion(
      qa.x * s0 + qb.x * s1,
      qa.y * s0 + qb.y * s1,
      qa.z * s0 + qb.z * s1,
      qa.w * s0 + qb.w * s1,
    );
    out.normalize();
    return out;
  }

  vm.Quaternion _rotationFromDegrees(double xDeg, double yDeg, double zDeg) {
    return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _degToRad(yDeg)) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), _degToRad(xDeg)) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), _degToRad(zDeg));
  }

  double _degToRad(double value) => value * math.pi / 180.0;
  double _radToDeg(double value) => value * 180.0 / math.pi;

  void _syncCameraAnglesFromCurrentView() {
    final dx = _targetX - _cameraX;
    final dy = _targetY - _cameraY;
    final dz = _targetZ - _cameraZ;
    final distance = math.sqrt(dx * dx + dy * dy + dz * dz);
    _cameraDistance = distance <= .001 ? 1.0 : distance;
    _cameraYaw = math.atan2(dz, dx);
    _cameraPitch = math.asin((dy / _cameraDistance).clamp(-1.0, 1.0));
  }

  void _updateTargetFromCameraAngles() {
    final cosPitch = math.cos(_cameraPitch);
    _targetX = _cameraX + _cameraDistance * cosPitch * math.cos(_cameraYaw);
    _targetY = _cameraY + _cameraDistance * math.sin(_cameraPitch);
    _targetZ = _cameraZ + _cameraDistance * cosPitch * math.sin(_cameraYaw);
  }

  double _normalizeAngle(double value) {
    while (value > math.pi) value -= math.pi * 2;
    while (value < -math.pi) value += math.pi * 2;
    return value;
  }

  ({double yaw, double pitch}) _anglesBetween(
    double cameraX, double cameraY, double cameraZ,
    double targetX, double targetY, double targetZ,
  ) {
    final dx = targetX - cameraX;
    final dy = targetY - cameraY;
    final dz = targetZ - cameraZ;
    final distance = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (distance <= .0001) return (yaw: 0.0, pitch: 0.0);
    return (
      yaw: math.atan2(dz, dx),
      pitch: math.asin((dy / distance).clamp(-1.0, 1.0)),
    );
  }

  void _applyActiveUserLookLimits() {
    final previewMain = _lookLimitPreviewMode == 'main';
    final previewArcade = _lookLimitPreviewMode == 'arcade';
    if (!_userModeActive && !previewMain && !previewArcade) return;

    final useArcade = previewArcade ||
        (!previewMain && _userModeActive && _arcadeFocusLocked);

    final center = useArcade
        ? _anglesBetween(
            _arcadeFocusCameraX,
            _arcadeFocusCameraY,
            _arcadeFocusCameraZ,
            _arcadeFocusTargetX,
            _arcadeFocusTargetY,
            _arcadeFocusTargetZ,
          )
        : _anglesBetween(
            _userStartCameraX,
            _userStartCameraY,
            _userStartCameraZ,
            _userStartTargetX,
            _userStartTargetY,
            _userStartTargetZ,
          );

    final left = _degToRad(useArcade ? _arcadeLookLeftDeg : _mainLookLeftDeg);
    final right = _degToRad(useArcade ? _arcadeLookRightDeg : _mainLookRightDeg);
    final up = _degToRad(useArcade ? _arcadeLookUpDeg : _mainLookUpDeg);
    final down = _degToRad(useArcade ? _arcadeLookDownDeg : _mainLookDownDeg);

    var yawDelta = _normalizeAngle(_cameraYaw - center.yaw);
    yawDelta = yawDelta.clamp(-left, right).toDouble();
    _cameraYaw = center.yaw + yawDelta;
    _cameraPitch =
        _cameraPitch.clamp(center.pitch - down, center.pitch + up).toDouble();
  }


  void _previewLookLimits({required bool arcade}) {
    final nextMode = arcade ? 'arcade' : 'main';

    if (_lookLimitPreviewMode.isEmpty) {
      _lookLimitPreviewRestoreMotionPlaying = _motionPlaying;
      _lookPreviewRestoreCameraX = _cameraX;
      _lookPreviewRestoreCameraY = _cameraY;
      _lookPreviewRestoreCameraZ = _cameraZ;
      _lookPreviewRestoreTargetX = _targetX;
      _lookPreviewRestoreTargetY = _targetY;
      _lookPreviewRestoreTargetZ = _targetZ;
      _lookPreviewRestoreFov = _cameraFov;
    }

    final changedMode = _lookLimitPreviewMode != nextMode;
    _lookLimitPreviewMode = nextMode;
    _userModeActive = false;
    _motionPlaying = false;
    _arcadeCameraAnimating = false;
    _arcadeCameraEditMode = false;
    _initialCameraEditMode = false;

    if (changedMode) {
      if (arcade) {
        _cameraX = _arcadeFocusCameraX;
        _cameraY = _arcadeFocusCameraY;
        _cameraZ = _arcadeFocusCameraZ;
        _targetX = _arcadeFocusTargetX;
        _targetY = _arcadeFocusTargetY;
        _targetZ = _arcadeFocusTargetZ;
        _cameraFov = _arcadeFocusFov;
      } else {
        _cameraX = _userStartCameraX;
        _cameraY = _userStartCameraY;
        _cameraZ = _userStartCameraZ;
        _targetX = _userStartTargetX;
        _targetY = _userStartTargetY;
        _targetZ = _userStartTargetZ;
        _cameraFov = _userStartFov;
      }
      _syncCameraAnglesFromCurrentView();
    }

    _applyActiveUserLookLimits();
    _updateTargetFromCameraAngles();
    _applyAllTransforms(save: false, repaint: false);
    _keyboardFocusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _refreshLookLimitPreview({required bool arcade}) {
    _previewLookLimits(arcade: arcade);
    _scheduleSave();
  }

  void _finishLookLimitPreview() {
    if (_lookLimitPreviewMode.isEmpty) return;

    _cameraX = _lookPreviewRestoreCameraX;
    _cameraY = _lookPreviewRestoreCameraY;
    _cameraZ = _lookPreviewRestoreCameraZ;
    _targetX = _lookPreviewRestoreTargetX;
    _targetY = _lookPreviewRestoreTargetY;
    _targetZ = _lookPreviewRestoreTargetZ;
    _cameraFov = _lookPreviewRestoreFov;
    _motionPlaying = _lookLimitPreviewRestoreMotionPlaying;
    _lookLimitPreviewMode = '';

    _syncCameraAnglesFromCurrentView();
    _applyAllTransforms(save: false, repaint: false);
    _keyboardFocusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _beginInitialCameraEditing() {
    if (_lookLimitPreviewMode.isNotEmpty) _finishLookLimitPreview();
    _userModeActive = false;
    _arcadeCameraAnimating = false;
    _arcadeCameraEditMode = false;
    _initialCameraEditMode = true;

    _initialCameraEditRestoreMotionPlaying = _motionPlaying;
    _motionPlaying = false;

    _initialEditRestoreCameraX = _cameraX;
    _initialEditRestoreCameraY = _cameraY;
    _initialEditRestoreCameraZ = _cameraZ;
    _initialEditRestoreTargetX = _targetX;
    _initialEditRestoreTargetY = _targetY;
    _initialEditRestoreTargetZ = _targetZ;
    _initialEditRestoreFov = _cameraFov;

    _initialEditOriginalStartCameraX = _userStartCameraX;
    _initialEditOriginalStartCameraY = _userStartCameraY;
    _initialEditOriginalStartCameraZ = _userStartCameraZ;
    _initialEditOriginalStartTargetX = _userStartTargetX;
    _initialEditOriginalStartTargetY = _userStartTargetY;
    _initialEditOriginalStartTargetZ = _userStartTargetZ;
    _initialEditOriginalStartFov = _userStartFov;

    _cameraX = _userStartCameraX;
    _cameraY = _userStartCameraY;
    _cameraZ = _userStartCameraZ;
    _targetX = _userStartTargetX;
    _targetY = _userStartTargetY;
    _targetZ = _userStartTargetZ;
    _cameraFov = _userStartFov;
    _syncCameraAnglesFromCurrentView();
    _applyAllTransforms(save: false, repaint: false);
    _keyboardFocusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _finishInitialCameraEditing() {
    _userStartCameraX = _cameraX;
    _userStartCameraY = _cameraY;
    _userStartCameraZ = _cameraZ;
    _userStartTargetX = _targetX;
    _userStartTargetY = _targetY;
    _userStartTargetZ = _targetZ;
    _userStartFov = _cameraFov;

    _initialCameraEditMode = false;
    _motionPlaying = _initialCameraEditRestoreMotionPlaying;
    _scheduleSave();
    _keyboardFocusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _cancelInitialCameraEditing() {
    _userStartCameraX = _initialEditOriginalStartCameraX;
    _userStartCameraY = _initialEditOriginalStartCameraY;
    _userStartCameraZ = _initialEditOriginalStartCameraZ;
    _userStartTargetX = _initialEditOriginalStartTargetX;
    _userStartTargetY = _initialEditOriginalStartTargetY;
    _userStartTargetZ = _initialEditOriginalStartTargetZ;
    _userStartFov = _initialEditOriginalStartFov;

    _cameraX = _initialEditRestoreCameraX;
    _cameraY = _initialEditRestoreCameraY;
    _cameraZ = _initialEditRestoreCameraZ;
    _targetX = _initialEditRestoreTargetX;
    _targetY = _initialEditRestoreTargetY;
    _targetZ = _initialEditRestoreTargetZ;
    _cameraFov = _initialEditRestoreFov;

    _initialCameraEditMode = false;
    _motionPlaying = _initialCameraEditRestoreMotionPlaying;
    _syncCameraAnglesFromCurrentView();
    _applyAllTransforms(save: false, repaint: false);
    _keyboardFocusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _registerUserCameraInteraction() {
    if (!_userModeActive ||
        _arcadeCameraAnimating ||
        _arcadeFocusLocked ||
        _arcadeCameraEditMode) {
      return;
    }
    _userCameraIdleSeconds = 0;
    _userCameraOverrideActive = true;
    _cameraMotionResumeBlendActive = false;
    _cameraMotionResumeBlendElapsed = 0;
  }

  void _tickUserCameraIdle(double dt) {
    if (!_userModeActive ||
        _arcadeCameraAnimating ||
        _arcadeFocusLocked ||
        _arcadeCameraEditMode ||
        !_motionPlaying) {
      return;
    }
    if (!_userCameraOverrideActive) return;

    _userCameraIdleSeconds += dt;
    if (_userCameraIdleSeconds < _userCameraIdleDelaySeconds) return;

    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = true;
    _cameraMotionResumeBlendElapsed = 0;
    _cameraResumeStartX = _cameraX;
    _cameraResumeStartY = _cameraY;
    _cameraResumeStartZ = _cameraZ;
    _cameraResumeStartTargetX = _targetX;
    _cameraResumeStartTargetY = _targetY;
    _cameraResumeStartTargetZ = _targetZ;
    _cameraResumeStartFov = _cameraFov;
  }

  _TrackSnapshot _blendCameraBackToMotion(
    _TrackSnapshot motionSnapshot,
    double dt,
  ) {
    _cameraMotionResumeBlendElapsed += dt;
    final raw = (_cameraMotionResumeBlendElapsed /
            _cameraMotionResumeBlendSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final t = raw * raw * (3 - 2 * raw);

    double lerp(double a, double b) => a + (b - a) * t;

    final values = motionSnapshot.values;
    final result = _TrackSnapshot(
      values: <String, double>{
        'cameraX': lerp(
          _cameraResumeStartX,
          values['cameraX'] ?? _cameraResumeStartX,
        ),
        'cameraY': lerp(
          _cameraResumeStartY,
          values['cameraY'] ?? _cameraResumeStartY,
        ),
        'cameraZ': lerp(
          _cameraResumeStartZ,
          values['cameraZ'] ?? _cameraResumeStartZ,
        ),
        'targetX': lerp(
          _cameraResumeStartTargetX,
          values['targetX'] ?? _cameraResumeStartTargetX,
        ),
        'targetY': lerp(
          _cameraResumeStartTargetY,
          values['targetY'] ?? _cameraResumeStartTargetY,
        ),
        'targetZ': lerp(
          _cameraResumeStartTargetZ,
          values['targetZ'] ?? _cameraResumeStartTargetZ,
        ),
        'cameraFov': lerp(
          _cameraResumeStartFov,
          values['cameraFov'] ?? _cameraResumeStartFov,
        ),
      },
    );

    if (raw >= 1) {
      _cameraMotionResumeBlendActive = false;
      _cameraMotionResumeBlendElapsed = 0;
    }
    return result;
  }

  void _startUserMode() {
    if (_lookLimitPreviewMode.isNotEmpty) _finishLookLimitPreview();
    _initialCameraEditMode = false;
    _userModeActive = true;
    _developerPanelOpen = false;
    _motionPanelOpen = false;
    _uiPreviewOnly = false;
    _arcadeFocusLocked = false;
    _arcadeCameraAnimating = false;
    _arcadeCameraEditMode = false;

    _cameraX = _userStartCameraX;
    _cameraY = _userStartCameraY;
    _cameraZ = _userStartCameraZ;
    _targetX = _userStartTargetX;
    _targetY = _userStartTargetY;
    _targetZ = _userStartTargetZ;
    _cameraFov = _userStartFov;
    _syncCameraAnglesFromCurrentView();
    _applyActiveUserLookLimits();
    _updateTargetFromCameraAngles();

    _motionClock = 0;
    _motionPlaying = true;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userCameraIdleSeconds = 0;
    _cameraMotionResumeBlendElapsed = 0;
    _tvTransitionAnimating = false;
    _tvModeActive = false;
    _tvTransitionElapsed = 0;
    _tvIdleClock = 0;

    _applyAllTransforms(save: false, repaint: false);
    _updateArcadeInteractionVisual();
    _keyboardFocusNode.requestFocus();
    if (mounted) setState(() {});
  }

  void _exitUserMode() {
    _userModeActive = false;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
    _userCameraIdleSeconds = 0;
    _developerPanelOpen = true;
    _motionPanelOpen = false;
    _updateArcadeInteractionVisual();
    if (mounted) setState(() {});
  }

  bool _tickKeyboardMovement(double dt) {
    if (_pressedKeys.isEmpty) return false;
    final ctrl = _isCtrlPressed;
    final up = _isPressed(const [LogicalKeyboardKey.arrowUp]);
    final down = _isPressed(const [LogicalKeyboardKey.arrowDown]);
    final left = _isPressed(const [LogicalKeyboardKey.arrowLeft]);
    final right = _isPressed(const [LogicalKeyboardKey.arrowRight]);
    if (!up && !down && !left && !right) return false;

    _registerUserCameraInteraction();

    final moveAmount = _cameraMoveSpeed * dt;
    final forward = vm.Vector3(math.cos(_cameraYaw), 0, math.sin(_cameraYaw));
    final rightAxis = vm.Vector3(-forward.z, 0, forward.x);
    final delta = vm.Vector3.zero();

    if (ctrl) {
      if (up) delta.y += moveAmount;
      if (down) delta.y -= moveAmount;
      if (right) delta.add(rightAxis * moveAmount);
      if (left) delta.add(rightAxis * -moveAmount);
    } else {
      if (up) delta.add(forward * moveAmount);
      if (down) delta.add(forward * -moveAmount);
      if (right) delta.add(rightAxis * moveAmount);
      if (left) delta.add(rightAxis * -moveAmount);
    }

    _cameraX += delta.x;
    _cameraY += delta.y;
    _cameraZ += delta.z;
    _targetX += delta.x;
    _targetY += delta.y;
    _targetZ += delta.z;

    if (_arcadeCameraEditMode) {
      _syncArcadeFocusFromCurrentCamera(save: false);
    }
    _applyAllTransforms(repaint: false, save: false);
    return true;
  }


  bool _tickMotion(double dt) {
    if (_motionTracks.values.every(
      (track) => !track.enabled || track.keyframes.isEmpty,
    )) {
      return false;
    }

    _motionClock += dt;
    var applied = false;
    var anyRunning = false;

    for (final track in _motionTracks.values) {
      if (!track.enabled || track.keyframes.isEmpty) continue;

      final result = _sampleMotionTrack(
        track,
        _motionClock,
        loop: _motionLoop,
      );
      if (!result.finished) anyRunning = true;

      if (track.id == 'camera' &&
          _userModeActive &&
          !_arcadeFocusLocked &&
          !_arcadeCameraEditMode) {
        if (_userCameraOverrideActive) {
          continue;
        }

        final snapshot = _cameraMotionResumeBlendActive
            ? _blendCameraBackToMotion(result.snapshot, dt)
            : result.snapshot;
        _applySnapshot(track.id, snapshot);
        applied = true;
        continue;
      }

      _applySnapshot(track.id, result.snapshot);
      applied = true;
    }

    if (applied) {
      if (_userModeActive) {
        _syncCameraAnglesFromCurrentView();
        _applyActiveUserLookLimits();
        _updateTargetFromCameraAngles();
      }
      _applyAllTransforms(save: false, repaint: false);
    }

    if (!_motionLoop && !anyRunning) {
      _motionPlaying = false;
    }

    return applied;
  }

  _MotionSampleResult _sampleMotionTrack(
    _MotionTrack track,
    double clock, {
    required bool loop,
  }) {
    if (track.keyframes.isEmpty) {
      return _MotionSampleResult(snapshot: _TrackSnapshot.empty(), finished: true);
    }
    if (track.keyframes.length == 1) {
      return _MotionSampleResult(snapshot: track.keyframes.first.snapshot, finished: true);
    }

    final keyframes = track.keyframes;
    var total = 0.0;
    final segmentCount = loop ? keyframes.length : keyframes.length - 1;
    for (var i = 0; i < segmentCount; i++) {
      total += math.max(.001, keyframes[i].durationSeconds);
    }
    if (total <= .001) {
      return _MotionSampleResult(snapshot: keyframes.last.snapshot, finished: true);
    }

    var localClock = clock;
    var finished = false;
    if (loop) {
      localClock = localClock % total;
    } else if (localClock >= total) {
      localClock = total;
      finished = true;
    }

    for (var i = 0; i < segmentCount; i++) {
      final start = keyframes[i];
      final end = keyframes[(i + 1) % keyframes.length];
      final duration = math.max(.001, start.durationSeconds);
      if (localClock <= duration || i == segmentCount - 1) {
        final t = duration <= .001 ? 1.0 : (localClock / duration).clamp(0.0, 1.0).toDouble();
        final snapshot = _interpolateSnapshot(start.snapshot, end.snapshot, t);
        return _MotionSampleResult(snapshot: snapshot, finished: finished);
      }
      localClock -= duration;
    }

    return _MotionSampleResult(snapshot: keyframes.last.snapshot, finished: true);
  }

  _TrackSnapshot _interpolateSnapshot(_TrackSnapshot a, _TrackSnapshot b, double t) {
    final values = <String, double>{};
    final keys = <String>{...a.values.keys, ...b.values.keys};
    for (final key in keys) {
      final av = a.values[key] ?? b.values[key] ?? 0;
      final bv = b.values[key] ?? a.values[key] ?? 0;
      values[key] = av + (bv - av) * t;
    }
    final flags = <String, bool>{...a.flags};
    for (final entry in b.flags.entries) {
      flags[entry.key] = t < .5 ? (a.flags[entry.key] ?? entry.value) : entry.value;
    }
    return _TrackSnapshot(values: values, flags: flags);
  }

  _TrackSnapshot _captureSnapshot(String trackId) {
    switch (trackId) {
      case 'camera':
        return _TrackSnapshot(
          values: <String, double>{
            'cameraX': _cameraX,
            'cameraY': _cameraY,
            'cameraZ': _cameraZ,
            'targetX': _targetX,
            'targetY': _targetY,
            'targetZ': _targetZ,
            'cameraFov': _cameraFov,
          },
        );
      case 'room':
        return _TrackSnapshot(
          values: <String, double>{
            'roomX': _roomX,
            'roomY': _roomY,
            'roomZ': _roomZ,
            'roomRotX': _roomRotX,
            'roomRotY': _roomRotY,
            'roomRotZ': _roomRotZ,
            'roomScaleX': _roomScaleX,
            'roomScaleY': _roomScaleY,
            'roomScaleZ': _roomScaleZ,
          },
          flags: <String, bool>{'visible': _showRoom},
        );
      case 'character':
        return _TrackSnapshot(
          values: <String, double>{
            'characterX': _characterX,
            'characterY': _characterY,
            'characterZ': _characterZ,
            'characterRotX': _characterRotX,
            'characterRotY': _characterRotY,
            'characterRotZ': _characterRotZ,
            'characterScaleX': _characterScaleX,
            'characterScaleY': _characterScaleY,
            'characterScaleZ': _characterScaleZ,
          },
          flags: <String, bool>{'visible': _showCharacter},
        );
      case 'scene':
        return _TrackSnapshot(
          values: <String, double>{
            'renderScale': _renderScale,
            'sceneExposure': _sceneExposure,
            'lightIntensity': _lightIntensity,
            'lightYawDeg': _lightYawDeg,
            'lightPitchDeg': _lightPitchDeg,
          },
        );
      default:
        if (trackId.startsWith('bone:')) {
          final nodeName = trackId.substring(5);
          _PoseTuning? tuning;
          for (final item in _poseTunings) {
            if (item.nodeName == nodeName) {
              tuning = item;
              break;
            }
          }
          if (tuning == null) return _TrackSnapshot.empty();
          return _TrackSnapshot(
            values: <String, double>{
              'rotX': tuning.rotX,
              'rotY': tuning.rotY,
              'rotZ': tuning.rotZ,
              'offsetX': tuning.offsetX,
              'offsetY': tuning.offsetY,
              'offsetZ': tuning.offsetZ,
            },
          );
        }
        return _TrackSnapshot.empty();
    }
  }

  void _applySnapshot(String trackId, _TrackSnapshot snapshot) {
    switch (trackId) {
      case 'camera':
        _cameraX = snapshot.values['cameraX'] ?? _cameraX;
        _cameraY = snapshot.values['cameraY'] ?? _cameraY;
        _cameraZ = snapshot.values['cameraZ'] ?? _cameraZ;
        _targetX = snapshot.values['targetX'] ?? _targetX;
        _targetY = snapshot.values['targetY'] ?? _targetY;
        _targetZ = snapshot.values['targetZ'] ?? _targetZ;
        _cameraFov = snapshot.values['cameraFov'] ?? _cameraFov;
        _syncCameraAnglesFromCurrentView();
        break;
      case 'room':
        _roomX = snapshot.values['roomX'] ?? _roomX;
        _roomY = snapshot.values['roomY'] ?? _roomY;
        _roomZ = snapshot.values['roomZ'] ?? _roomZ;
        _roomRotX = snapshot.values['roomRotX'] ?? _roomRotX;
        _roomRotY = snapshot.values['roomRotY'] ?? _roomRotY;
        _roomRotZ = snapshot.values['roomRotZ'] ?? _roomRotZ;
        _roomScaleX = snapshot.values['roomScaleX'] ?? _roomScaleX;
        _roomScaleY = snapshot.values['roomScaleY'] ?? _roomScaleY;
        _roomScaleZ = snapshot.values['roomScaleZ'] ?? _roomScaleZ;
        _showRoom = snapshot.flags['visible'] ?? _showRoom;
        break;
      case 'character':
        _characterX = snapshot.values['characterX'] ?? _characterX;
        _characterY = snapshot.values['characterY'] ?? _characterY;
        _characterZ = snapshot.values['characterZ'] ?? _characterZ;
        _characterRotX = snapshot.values['characterRotX'] ?? _characterRotX;
        _characterRotY = snapshot.values['characterRotY'] ?? _characterRotY;
        _characterRotZ = snapshot.values['characterRotZ'] ?? _characterRotZ;
        _characterScaleX = snapshot.values['characterScaleX'] ?? _characterScaleX;
        _characterScaleY = snapshot.values['characterScaleY'] ?? _characterScaleY;
        _characterScaleZ = snapshot.values['characterScaleZ'] ?? _characterScaleZ;
        _showCharacter = snapshot.flags['visible'] ?? _showCharacter;
        break;
      case 'scene':
        _renderScale = snapshot.values['renderScale'] ?? _renderScale;
        _sceneExposure = snapshot.values['sceneExposure'] ?? _sceneExposure;
        _lightIntensity = snapshot.values['lightIntensity'] ?? _lightIntensity;
        _lightYawDeg = snapshot.values['lightYawDeg'] ?? _lightYawDeg;
        _lightPitchDeg = snapshot.values['lightPitchDeg'] ?? _lightPitchDeg;
        break;
      default:
        if (trackId.startsWith('bone:')) {
          final nodeName = trackId.substring(5);
          for (final tuning in _poseTunings) {
            if (tuning.nodeName != nodeName) continue;
            tuning.rotX = snapshot.values['rotX'] ?? tuning.rotX;
            tuning.rotY = snapshot.values['rotY'] ?? tuning.rotY;
            tuning.rotZ = snapshot.values['rotZ'] ?? tuning.rotZ;
            tuning.offsetX = snapshot.values['offsetX'] ?? tuning.offsetX;
            tuning.offsetY = snapshot.values['offsetY'] ?? tuning.offsetY;
            tuning.offsetZ = snapshot.values['offsetZ'] ?? tuning.offsetZ;
            break;
          }
        }
        break;
    }
  }

  bool _isPressed(List<LogicalKeyboardKey> keys) {
    for (final key in keys) {
      if (_pressedKeys.contains(key)) return true;
    }
    return false;
  }

  bool get _isCtrlPressed => _isPressed(const [
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
      ]);

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final firstPress = _pressedKeys.add(event.logicalKey);

      if (event.logicalKey == LogicalKeyboardKey.f1 &&
          firstPress &&
          _userModeActive) {
        _exitUserMode();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.capsLock &&
          firstPress &&
          !_userModeActive) {
        setState(() {
          _uiPreviewOnly = !_uiPreviewOnly;
        });
        return KeyEventResult.handled;
      }

      if (_userModeActive &&
          _arcadeFocusLocked &&
          firstPress &&
          (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.keyA)) {
        _browseArcadeGames(-1);
        return KeyEventResult.handled;
      }

      if (_userModeActive &&
          _arcadeFocusLocked &&
          firstPress &&
          (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.keyD)) {
        _browseArcadeGames(1);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.escape &&
          firstPress &&
          _lookLimitPreviewMode.isNotEmpty) {
        _finishLookLimitPreview();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.escape && firstPress) {
        if (_initialCameraEditMode) {
          _cancelInitialCameraEditing();
          return KeyEventResult.handled;
        }
        if (_arcadeCameraEditMode) {
          _cancelArcadeCameraEditing();
          return KeyEventResult.handled;
        }
        if (_userModeActive) {
          _exitUserMode();
          return KeyEventResult.handled;
        }
      }

      if ((event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
          firstPress) {
        if (_initialCameraEditMode) {
          _finishInitialCameraEditing();
        } else if (_arcadeCameraEditMode) {
          _finishArcadeCameraEditing();
        } else {
          _toggleMotionPlayback();
        }
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    return KeyEventResult.ignored;
  }



  bool _tickUserLookPhysics(double dt) {
    if (!_userModeActive ||
        (_arcadeFocusLocked && !_tvModeActive) ||
        _lookLimitPreviewMode.isNotEmpty ||
        _arcadeCameraEditMode ||
        _initialCameraEditMode ||
        _tvTransitionAnimating) {
      _userLookVelocityYaw = 0;
      _userLookVelocityPitch = 0;
      return false;
    }

    if (_tvModeActive) {
      _userLookVelocityYaw = 0;
      _userLookVelocityPitch = 0;

      _cameraX = _tvCameraX;
      _cameraY = _tvCameraY;
      _cameraZ = _tvCameraZ;
      _targetX = _tvCameraTargetX;
      _targetY = _tvCameraTargetY;
      _targetZ = _tvCameraTargetZ;
      _cameraFov = _tvCameraFov;
      _syncCameraAnglesFromCurrentView();
      return false;
    }

    final center = _tvModeActive
        ? _anglesBetween(
            _tvCameraX,
            _tvCameraY,
            _tvCameraZ,
            _tvCameraTargetX,
            _tvCameraTargetY,
            _tvCameraTargetZ,
          )
        : _anglesBetween(
            _userStartCameraX,
            _userStartCameraY,
            _userStartCameraZ,
            _userStartTargetX,
            _userStartTargetY,
            _userStartTargetZ,
          );

    final left =
        _degToRad(_tvModeActive ? _tvLookLeftDeg : _mainLookLeftDeg);
    final right =
        _degToRad(_tvModeActive ? _tvLookRightDeg : _mainLookRightDeg);
    final up =
        _degToRad(_tvModeActive ? _tvLookUpDeg : _mainLookUpDeg);
    final down =
        _degToRad(_tvModeActive ? _tvLookDownDeg : _mainLookDownDeg);
    final overscroll = _degToRad(_userLookOverscrollDeg);

    var yawOffset = _normalizeAngle(_cameraYaw - center.yaw);
    var pitchOffset = _cameraPitch - center.pitch;

    // Spring starts at the real boundary; the camera may pass it by
    // _userLookOverscrollDeg before being smoothly pushed back.
    double spring(double value, double minValue, double maxValue) {
      if (value < minValue) return (minValue - value) * _userLookSpringStrength;
      if (value > maxValue) return (maxValue - value) * _userLookSpringStrength;
      return 0.0;
    }

    _userLookVelocityYaw += spring(yawOffset, -left, right) * dt;
    _userLookVelocityPitch += spring(pitchOffset, -down, up) * dt;

    // Extra damping while outside a real boundary gives a soft elastic rebound.
    final outsideYaw = yawOffset < -left || yawOffset > right;
    final outsidePitch = pitchOffset < -down || pitchOffset > up;
    if (outsideYaw) {
      _userLookVelocityYaw *=
          math.exp(-_userLookSpringDamping * dt).toDouble();
    }
    if (outsidePitch) {
      _userLookVelocityPitch *=
          math.exp(-_userLookSpringDamping * dt).toDouble();
    }

    final inertiaFactor =
        math.pow(_userLookInertia.clamp(.50, .995), dt * 60.0).toDouble();
    _userLookVelocityYaw *= inertiaFactor;
    _userLookVelocityPitch *= inertiaFactor;

    if (_userLookVelocityYaw.abs() < .00008) _userLookVelocityYaw = 0;
    if (_userLookVelocityPitch.abs() < .00008) _userLookVelocityPitch = 0;

    if (_userLookVelocityYaw == 0 && _userLookVelocityPitch == 0) {
      return false;
    }

    _cameraYaw += _userLookVelocityYaw * dt;
    _cameraPitch += _userLookVelocityPitch * dt;

    yawOffset = _normalizeAngle(_cameraYaw - center.yaw);
    pitchOffset = _cameraPitch - center.pitch;

    // Hard safety bound is only one configurable overscroll beyond the limit.
    final safeYaw = yawOffset.clamp(-left - overscroll, right + overscroll).toDouble();
    final safePitch = pitchOffset.clamp(-down - overscroll, up + overscroll).toDouble();

    if (safeYaw != yawOffset) {
      _cameraYaw = center.yaw + safeYaw;
      _userLookVelocityYaw *= -.32;
    }
    if (safePitch != pitchOffset) {
      _cameraPitch = center.pitch + safePitch;
      _userLookVelocityPitch *= -.32;
    }

    _cameraPitch = _cameraPitch.clamp(-1.55, 1.55).toDouble();
    _updateTargetFromCameraAngles();
    _applyAllTransforms(repaint: false, save: false);
    return true;
  }

  void _handleLookDrag(DragUpdateDetails details) {
    _registerUserCameraInteraction();

    // Developer camera editing keeps the old exact/direct response.
    if (!_userModeActive ||
        _lookLimitPreviewMode.isNotEmpty ||
        _arcadeCameraEditMode ||
        _initialCameraEditMode) {
      final dx = details.delta.dx * _mouseSensitivity;
      final dy = details.delta.dy * _mouseSensitivity;
      _cameraYaw -= dx;
      _cameraPitch = (_cameraPitch - dy).clamp(-1.55, 1.55).toDouble();
      _applyActiveUserLookLimits();
      _updateTargetFromCameraAngles();

      if (_arcadeCameraEditMode) {
        _syncArcadeFocusFromCurrentCamera(save: false);
      }
      _applyAllTransforms(repaint: false, save: false);
      setState(() {});
      return;
    }

    // TV camera is fully locked: no overscroll, no bounce, no drag movement.
    if (_tvModeActive) {
      _userLookVelocityYaw = 0;
      _userLookVelocityPitch = 0;
      return;
    }

    // Arcade view is locked.
    if (_arcadeFocusLocked) return;

    final yawInput = -details.delta.dx * _mouseSensitivity;
    final pitchInput = -details.delta.dy * _mouseSensitivity;

    // Small immediate response + velocity accumulation = responsive but smooth.
    _cameraYaw += yawInput * .22;
    _cameraPitch += pitchInput * .22;

    final maxVelocity = _degToRad(_userLookMaxVelocityDeg);
    _userLookVelocityYaw =
        (_userLookVelocityYaw + yawInput * _userLookInputBoost)
            .clamp(-maxVelocity, maxVelocity)
            .toDouble();
    _userLookVelocityPitch =
        (_userLookVelocityPitch + pitchInput * _userLookInputBoost)
            .clamp(-maxVelocity, maxVelocity)
            .toDouble();

    final center = _tvModeActive
        ? _anglesBetween(
            _tvCameraX,
            _tvCameraY,
            _tvCameraZ,
            _tvCameraTargetX,
            _tvCameraTargetY,
            _tvCameraTargetZ,
          )
        : _anglesBetween(
            _userStartCameraX,
            _userStartCameraY,
            _userStartCameraZ,
            _userStartTargetX,
            _userStartTargetY,
            _userStartTargetZ,
          );

    final leftLimit =
        _tvModeActive ? _tvLookLeftDeg : _mainLookLeftDeg;
    final rightLimit =
        _tvModeActive ? _tvLookRightDeg : _mainLookRightDeg;
    final upLimit =
        _tvModeActive ? _tvLookUpDeg : _mainLookUpDeg;
    final downLimit =
        _tvModeActive ? _tvLookDownDeg : _mainLookDownDeg;

    final overscroll = _tvModeActive ? 0.0 : _degToRad(_userLookOverscrollDeg);
    final yawOffset = _normalizeAngle(_cameraYaw - center.yaw).clamp(
          -_degToRad(leftLimit) - overscroll,
          _degToRad(rightLimit) + overscroll,
        ).toDouble();
    final pitchOffset = (_cameraPitch - center.pitch).clamp(
          -_degToRad(downLimit) - overscroll,
          _degToRad(upLimit) + overscroll,
        ).toDouble();

    _cameraYaw = center.yaw + yawOffset;
    _cameraPitch = (center.pitch + pitchOffset).clamp(-1.55, 1.55).toDouble();
    _updateTargetFromCameraAngles();
    _applyAllTransforms(repaint: false, save: false);
    setState(() {});
  }


  void _restoreSavedSettings() {
    final prefs = _prefs;
    final raw = prefs?.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      double readDouble(String key, double fallback) {
        final value = decoded[key];
        if (value is num) return value.toDouble();
        return fallback;
      }

      bool readBool(String key, bool fallback) {
        final value = decoded[key];
        return value is bool ? value : fallback;
      }

      _developerPanelOpen = readBool('developerPanelOpen', _developerPanelOpen);
      _motionPanelOpen = readBool('motionPanelOpen', _motionPanelOpen);
      _showRoom = readBool('showRoom', _showRoom);
      _showCharacter = readBool('showCharacter', _showCharacter);
      _showGuide = readBool('showGuide', _showGuide);
      final developerSection = decoded['developerSection'];
      if (developerSection is String && developerSection.isNotEmpty) {
        _developerSection = developerSection;
      }
      _renderScale = readDouble('renderScale', _renderScale);
      _sceneExposure = readDouble('sceneExposure', _sceneExposure);
      _lightIntensity = readDouble('lightIntensity', _lightIntensity);
      _lightYawDeg = readDouble('lightYawDeg', _lightYawDeg);
      _lightPitchDeg = readDouble('lightPitchDeg', _lightPitchDeg);

      _cameraX = readDouble('cameraX', _cameraX);
      _cameraY = readDouble('cameraY', _cameraY);
      _cameraZ = readDouble('cameraZ', _cameraZ);
      _targetX = readDouble('targetX', _targetX);
      _targetY = readDouble('targetY', _targetY);
      _targetZ = readDouble('targetZ', _targetZ);
      _cameraFov = readDouble('cameraFov', _cameraFov);
      _cameraMoveSpeed = readDouble('cameraMoveSpeed', _cameraMoveSpeed);
      _mouseSensitivity = readDouble('mouseSensitivity', _mouseSensitivity);
      _mainLookLeftDeg = readDouble('mainLookLeftDeg', _mainLookLeftDeg);
      _mainLookRightDeg = readDouble('mainLookRightDeg', _mainLookRightDeg);
      _mainLookUpDeg = readDouble('mainLookUpDeg', _mainLookUpDeg);
      _mainLookDownDeg = readDouble('mainLookDownDeg', _mainLookDownDeg);
      _userLookInertia = readDouble('userLookInertia', _userLookInertia);
      _userLookInputBoost = readDouble('userLookInputBoost', _userLookInputBoost);
      _userLookMaxVelocityDeg = readDouble('userLookMaxVelocityDeg', _userLookMaxVelocityDeg);
      _userLookOverscrollDeg = readDouble('userLookOverscrollDeg', _userLookOverscrollDeg);
      _userLookSpringStrength = readDouble('userLookSpringStrength', _userLookSpringStrength);
      _userLookSpringDamping = readDouble('userLookSpringDamping', _userLookSpringDamping);
      _arcadeLookLeftDeg = readDouble('arcadeLookLeftDeg', _arcadeLookLeftDeg);
      _arcadeLookRightDeg = readDouble('arcadeLookRightDeg', _arcadeLookRightDeg);
      _arcadeLookUpDeg = readDouble('arcadeLookUpDeg', _arcadeLookUpDeg);
      _arcadeLookDownDeg = readDouble('arcadeLookDownDeg', _arcadeLookDownDeg);
      _userStartCameraX = readDouble('userStartCameraX', _userStartCameraX);
      _userStartCameraY = readDouble('userStartCameraY', _userStartCameraY);
      _userStartCameraZ = readDouble('userStartCameraZ', _userStartCameraZ);
      _userStartTargetX = readDouble('userStartTargetX', _userStartTargetX);
      _userStartTargetY = readDouble('userStartTargetY', _userStartTargetY);
      _userStartTargetZ = readDouble('userStartTargetZ', _userStartTargetZ);
      _userStartFov = readDouble('userStartFov', _userStartFov);

      _roomX = readDouble('roomX', _roomX);
      _roomY = readDouble('roomY', _roomY);
      _roomZ = readDouble('roomZ', _roomZ);
      _roomRotX = readDouble('roomRotX', _roomRotX);
      _roomRotY = readDouble('roomRotY', _roomRotY);
      _roomRotZ = readDouble('roomRotZ', _roomRotZ);
      _roomScaleX = readDouble('roomScaleX', _roomScaleX);
      _roomScaleY = readDouble('roomScaleY', _roomScaleY);
      _roomScaleZ = readDouble('roomScaleZ', _roomScaleZ);
      _showTv = readBool('showTv', _showTv);
      _tvX = readDouble('tvX', _tvX);
      _tvY = readDouble('tvY', _tvY);
      _tvZ = readDouble('tvZ', _tvZ);
      _tvRotX = readDouble('tvRotX', _tvRotX);
      _tvRotY = readDouble('tvRotY', _tvRotY);
      _tvRotZ = readDouble('tvRotZ', _tvRotZ);
      _tvScaleX = readDouble('tvScaleX', _tvScaleX);
      _tvScaleY = readDouble('tvScaleY', _tvScaleY);
      _tvScaleZ = readDouble('tvScaleZ', _tvScaleZ);
      _tvEntryStartX = readDouble('tvEntryStartX', _tvEntryStartX);
      _tvEntryStartY = readDouble('tvEntryStartY', _tvEntryStartY);
      _tvEntryStartZ = readDouble('tvEntryStartZ', _tvEntryStartZ);
      _tvEntryStartRotX = readDouble('tvEntryStartRotX', _tvEntryStartRotX);
      _tvEntryStartRotY = readDouble('tvEntryStartRotY', _tvEntryStartRotY);
      _tvEntryStartRotZ = readDouble('tvEntryStartRotZ', _tvEntryStartRotZ);
      _tvEntryStartScaleX =
          readDouble('tvEntryStartScaleX', _tvEntryStartScaleX);
      _tvEntryStartScaleY =
          readDouble('tvEntryStartScaleY', _tvEntryStartScaleY);
      _tvEntryStartScaleZ =
          readDouble('tvEntryStartScaleZ', _tvEntryStartScaleZ);
      _tvEntrySpinXTurns =
          readDouble('tvEntrySpinXTurns', _tvEntrySpinXTurns);
      _tvEntrySpinYTurns =
          readDouble('tvEntrySpinYTurns', _tvEntrySpinYTurns);
      _tvEntrySpinZTurns =
          readDouble('tvEntrySpinZTurns', _tvEntrySpinZTurns);
      _tvEntryDuration = readDouble('tvEntryDuration', _tvEntryDuration);

      _tvCameraX = readDouble('tvCameraX', _tvCameraX);
      _tvCameraY = readDouble('tvCameraY', _tvCameraY);
      _tvCameraZ = readDouble('tvCameraZ', _tvCameraZ);
      _tvCameraTargetX = readDouble('tvCameraTargetX', _tvCameraTargetX);
      _tvCameraTargetY = readDouble('tvCameraTargetY', _tvCameraTargetY);
      _tvCameraTargetZ = readDouble('tvCameraTargetZ', _tvCameraTargetZ);
      _tvCameraFov = readDouble('tvCameraFov', _tvCameraFov);
      _tvCameraDuration = readDouble('tvCameraDuration', _tvCameraDuration);
      _tvLookLeftDeg = readDouble('tvLookLeftDeg', _tvLookLeftDeg);
      _tvLookRightDeg = readDouble('tvLookRightDeg', _tvLookRightDeg);
      _tvLookUpDeg = readDouble('tvLookUpDeg', _tvLookUpDeg);
      _tvLookDownDeg = readDouble('tvLookDownDeg', _tvLookDownDeg);
      _tvCameraLivePreview =
          readBool('tvCameraLivePreview', _tvCameraLivePreview);

      _tvIdleMotionEnabled =
          readBool('tvIdleMotionEnabled', _tvIdleMotionEnabled);
      _tvIdleMoveX = readDouble('tvIdleMoveX', _tvIdleMoveX);
      _tvIdleMoveY = readDouble('tvIdleMoveY', _tvIdleMoveY);
      _tvIdleMoveZ = readDouble('tvIdleMoveZ', _tvIdleMoveZ);
      _tvIdleRotX = readDouble('tvIdleRotX', _tvIdleRotX);
      _tvIdleRotY = readDouble('tvIdleRotY', _tvIdleRotY);
      _tvIdleRotZ = readDouble('tvIdleRotZ', _tvIdleRotZ);
      _tvIdleCycleSeconds =
          readDouble('tvIdleCycleSeconds', _tvIdleCycleSeconds);
      _showTvScreen = readBool('showTvScreen', _showTvScreen);
      _tvScreenX = readDouble('tvScreenX', _tvScreenX);
      _tvScreenY = readDouble('tvScreenY', _tvScreenY);
      _tvScreenZ = readDouble('tvScreenZ', _tvScreenZ);
      _tvScreenRotX = readDouble('tvScreenRotX', _tvScreenRotX);
      _tvScreenRotY = readDouble('tvScreenRotY', _tvScreenRotY);
      _tvScreenRotZ = readDouble('tvScreenRotZ', _tvScreenRotZ);
      _tvScreenScaleX = readDouble('tvScreenScaleX', _tvScreenScaleX);
      _tvScreenScaleY = readDouble('tvScreenScaleY', _tvScreenScaleY);
      _tvScreenScaleZ = readDouble('tvScreenScaleZ', _tvScreenScaleZ);
      _tvScreenHighlight =
          readBool('tvScreenHighlight', _tvScreenHighlight);
      _tvDetailsVisible = readBool('tvDetailsVisible', _tvDetailsVisible);
      _tvUiTitleOffsetX = readDouble('tvUiTitleOffsetX', _tvUiTitleOffsetX);
      _tvUiTitleOffsetY = readDouble('tvUiTitleOffsetY', _tvUiTitleOffsetY);
      _tvUiTitleScale = readDouble('tvUiTitleScale', _tvUiTitleScale);
      _tvUiButtonsOffsetX = readDouble('tvUiButtonsOffsetX', _tvUiButtonsOffsetX);
      _tvUiButtonsOffsetY = readDouble('tvUiButtonsOffsetY', _tvUiButtonsOffsetY);
      _tvUiButtonsScale = readDouble('tvUiButtonsScale', _tvUiButtonsScale);
      _tvUiButtonsGap = readDouble('tvUiButtonsGap', _tvUiButtonsGap);
      _tvUiInfoOffsetX = readDouble('tvUiInfoOffsetX', _tvUiInfoOffsetX);
      _tvUiInfoOffsetY = readDouble('tvUiInfoOffsetY', _tvUiInfoOffsetY);
      _tvUiInfoScale = readDouble('tvUiInfoScale', _tvUiInfoScale);
      _tvUiPanelOffsetX = readDouble('tvUiPanelOffsetX', _tvUiPanelOffsetX);
      _tvUiPanelOffsetY = readDouble('tvUiPanelOffsetY', _tvUiPanelOffsetY);
      _tvUiPanelScale = readDouble('tvUiPanelScale', _tvUiPanelScale);
      _tvUiButtonRadius = readDouble('tvUiButtonRadius', _tvUiButtonRadius);
      _tvUiButtonStroke = readDouble('tvUiButtonStroke', _tvUiButtonStroke);
      _tvUiBgR = readDouble('tvUiBgR', _tvUiBgR);
      _tvUiBgG = readDouble('tvUiBgG', _tvUiBgG);
      _tvUiBgB = readDouble('tvUiBgB', _tvUiBgB);
      _tvUiAccentR = readDouble('tvUiAccentR', _tvUiAccentR);
      _tvUiAccentG = readDouble('tvUiAccentG', _tvUiAccentG);
      _tvUiAccentB = readDouble('tvUiAccentB', _tvUiAccentB);
      _tvUiTitleR = readDouble('tvUiTitleR', _tvUiTitleR);
      _tvUiTitleG = readDouble('tvUiTitleG', _tvUiTitleG);
      _tvUiTitleB = readDouble('tvUiTitleB', _tvUiTitleB);
      _tvUiOfflineR = readDouble('tvUiOfflineR', _tvUiOfflineR);
      _tvUiOfflineG = readDouble('tvUiOfflineG', _tvUiOfflineG);
      _tvUiOfflineB = readDouble('tvUiOfflineB', _tvUiOfflineB);
      _tvUiOnlineR = readDouble('tvUiOnlineR', _tvUiOnlineR);
      _tvUiOnlineG = readDouble('tvUiOnlineG', _tvUiOnlineG);
      _tvUiOnlineB = readDouble('tvUiOnlineB', _tvUiOnlineB);
      _tvUiDisabledR = readDouble('tvUiDisabledR', _tvUiDisabledR);
      _tvUiDisabledG = readDouble('tvUiDisabledG', _tvUiDisabledG);
      _tvUiDisabledB = readDouble('tvUiDisabledB', _tvUiDisabledB);
      _tvUiInfoR = readDouble('tvUiInfoR', _tvUiInfoR);
      _tvUiInfoG = readDouble('tvUiInfoG', _tvUiInfoG);
      _tvUiInfoB = readDouble('tvUiInfoB', _tvUiInfoB);
      _tvUiTextR = readDouble('tvUiTextR', _tvUiTextR);
      _tvUiTextG = readDouble('tvUiTextG', _tvUiTextG);
      _tvUiTextB = readDouble('tvUiTextB', _tvUiTextB);
      _tvUiPanelR = readDouble('tvUiPanelR', _tvUiPanelR);
      _tvUiPanelG = readDouble('tvUiPanelG', _tvUiPanelG);
      _tvUiPanelB = readDouble('tvUiPanelB', _tvUiPanelB);

      _showArcadeScreen = readBool('showArcadeScreen', _showArcadeScreen);
      _arcadeScreenX = readDouble('arcadeScreenX', _arcadeScreenX);
      _arcadeScreenY = readDouble('arcadeScreenY', _arcadeScreenY);
      _arcadeScreenZ = readDouble('arcadeScreenZ', _arcadeScreenZ);
      _arcadeScreenRotX = readDouble('arcadeScreenRotX', _arcadeScreenRotX);
      _arcadeScreenRotY = readDouble('arcadeScreenRotY', _arcadeScreenRotY);
      _arcadeScreenRotZ = readDouble('arcadeScreenRotZ', _arcadeScreenRotZ);
      _arcadeScreenScaleX = readDouble('arcadeScreenScaleX', _arcadeScreenScaleX);
      _arcadeScreenScaleY = readDouble('arcadeScreenScaleY', _arcadeScreenScaleY);
      _arcadeScreenScaleZ = readDouble('arcadeScreenScaleZ', _arcadeScreenScaleZ);
      _arcadeScreenColorEnabled = readBool('arcadeScreenColorEnabled', _arcadeScreenColorEnabled);
      _arcadeScreenColorR = readDouble('arcadeScreenColorR', _arcadeScreenColorR);
      _arcadeScreenColorG = readDouble('arcadeScreenColorG', _arcadeScreenColorG);
      _arcadeScreenColorB = readDouble('arcadeScreenColorB', _arcadeScreenColorB);
      _arcadeScreenColorOpacity = readDouble('arcadeScreenColorOpacity', _arcadeScreenColorOpacity);

      _showArcadeJoystick = readBool('showArcadeJoystick', _showArcadeJoystick);
      _arcadeJoystickX = readDouble('arcadeJoystickX', _arcadeJoystickX);
      _arcadeJoystickY = readDouble('arcadeJoystickY', _arcadeJoystickY);
      _arcadeJoystickZ = readDouble('arcadeJoystickZ', _arcadeJoystickZ);
      _arcadeJoystickRotX = readDouble('arcadeJoystickRotX', _arcadeJoystickRotX);
      _arcadeJoystickRotY = readDouble('arcadeJoystickRotY', _arcadeJoystickRotY);
      _arcadeJoystickRotZ = readDouble('arcadeJoystickRotZ', _arcadeJoystickRotZ);
      _arcadeJoystickScaleX = readDouble('arcadeJoystickScaleX', _arcadeJoystickScaleX);
      _arcadeJoystickScaleY = readDouble('arcadeJoystickScaleY', _arcadeJoystickScaleY);
      _arcadeJoystickScaleZ = readDouble('arcadeJoystickScaleZ', _arcadeJoystickScaleZ);
      _arcadeJoystickColorEnabled = readBool('arcadeJoystickColorEnabled', _arcadeJoystickColorEnabled);
      _arcadeJoystickColorR = readDouble('arcadeJoystickColorR', _arcadeJoystickColorR);
      _arcadeJoystickColorG = readDouble('arcadeJoystickColorG', _arcadeJoystickColorG);
      _arcadeJoystickColorB = readDouble('arcadeJoystickColorB', _arcadeJoystickColorB);
      _arcadeJoystickColorOpacity = readDouble('arcadeJoystickColorOpacity', _arcadeJoystickColorOpacity);
      _revealArcadeScreen = readBool('revealArcadeScreen', _revealArcadeScreen);
      _revealArcadeJoystick = readBool('revealArcadeJoystick', _revealArcadeJoystick);
      _arcadeDisplayEnabled = readBool('arcadeDisplayEnabled', _arcadeDisplayEnabled);
      final arcadeDisplaySideTitle = decoded['arcadeDisplaySideTitle'];
      if (arcadeDisplaySideTitle is String && arcadeDisplaySideTitle.isNotEmpty) {
        _arcadeDisplaySideTitle = arcadeDisplaySideTitle;
      }
      final arcadeDisplayCenterTitle = decoded['arcadeDisplayCenterTitle'];
      if (arcadeDisplayCenterTitle is String && arcadeDisplayCenterTitle.isNotEmpty) {
        _arcadeDisplayCenterTitle = arcadeDisplayCenterTitle;
      }
      _arcadeSelectedGameIndex = readDouble(
        'arcadeSelectedGameIndex',
        _arcadeSelectedGameIndex.toDouble(),
      ).round().clamp(0, _arcadeGames.length - 1).toInt();
      _arcadeDisplayBgR = readDouble('arcadeDisplayBgR', _arcadeDisplayBgR);
      _arcadeDisplayBgG = readDouble('arcadeDisplayBgG', _arcadeDisplayBgG);
      _arcadeDisplayBgB = readDouble('arcadeDisplayBgB', _arcadeDisplayBgB);
      _arcadeDisplayHeaderR = readDouble('arcadeDisplayHeaderR', _arcadeDisplayHeaderR);
      _arcadeDisplayHeaderG = readDouble('arcadeDisplayHeaderG', _arcadeDisplayHeaderG);
      _arcadeDisplayHeaderB = readDouble('arcadeDisplayHeaderB', _arcadeDisplayHeaderB);
      _arcadeDisplayAccentR = readDouble('arcadeDisplayAccentR', _arcadeDisplayAccentR);
      _arcadeDisplayAccentG = readDouble('arcadeDisplayAccentG', _arcadeDisplayAccentG);
      _arcadeDisplayAccentB = readDouble('arcadeDisplayAccentB', _arcadeDisplayAccentB);
      _arcadeDisplayCardR = readDouble('arcadeDisplayCardR', _arcadeDisplayCardR);
      _arcadeDisplayCardG = readDouble('arcadeDisplayCardG', _arcadeDisplayCardG);
      _arcadeDisplayCardB = readDouble('arcadeDisplayCardB', _arcadeDisplayCardB);
      _arcadeDisplaySelectedCardR = readDouble('arcadeDisplaySelectedCardR', _arcadeDisplaySelectedCardR);
      _arcadeDisplaySelectedCardG = readDouble('arcadeDisplaySelectedCardG', _arcadeDisplaySelectedCardG);
      _arcadeDisplaySelectedCardB = readDouble('arcadeDisplaySelectedCardB', _arcadeDisplaySelectedCardB);
      _arcadeDisplayTextR = readDouble('arcadeDisplayTextR', _arcadeDisplayTextR);
      _arcadeDisplayTextG = readDouble('arcadeDisplayTextG', _arcadeDisplayTextG);
      _arcadeDisplayTextB = readDouble('arcadeDisplayTextB', _arcadeDisplayTextB);
      _arcadeDisplaySubtextR = readDouble('arcadeDisplaySubtextR', _arcadeDisplaySubtextR);
      _arcadeDisplaySubtextG = readDouble('arcadeDisplaySubtextG', _arcadeDisplaySubtextG);
      _arcadeDisplaySubtextB = readDouble('arcadeDisplaySubtextB', _arcadeDisplaySubtextB);
      _arcadeDisplayArrowR = readDouble('arcadeDisplayArrowR', _arcadeDisplayArrowR);
      _arcadeDisplayArrowG = readDouble('arcadeDisplayArrowG', _arcadeDisplayArrowG);
      _arcadeDisplayArrowB = readDouble('arcadeDisplayArrowB', _arcadeDisplayArrowB);
      _arcadeDisplayFrameR = readDouble('arcadeDisplayFrameR', _arcadeDisplayFrameR);
      _arcadeDisplayFrameG = readDouble('arcadeDisplayFrameG', _arcadeDisplayFrameG);
      _arcadeDisplayFrameB = readDouble('arcadeDisplayFrameB', _arcadeDisplayFrameB);
      _arcadeDisplayShowSubtitle = readBool('arcadeDisplayShowSubtitle', _arcadeDisplayShowSubtitle);
      _arcadeDisplayHeaderOffsetX = readDouble('arcadeDisplayHeaderOffsetX', _arcadeDisplayHeaderOffsetX);
      _arcadeDisplayHeaderOffsetY = readDouble('arcadeDisplayHeaderOffsetY', _arcadeDisplayHeaderOffsetY);
      _arcadeDisplayHeaderScale = readDouble('arcadeDisplayHeaderScale', _arcadeDisplayHeaderScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplaySideTitleOffsetX = readDouble('arcadeDisplaySideTitleOffsetX', _arcadeDisplaySideTitleOffsetX);
      _arcadeDisplaySideTitleOffsetY = readDouble('arcadeDisplaySideTitleOffsetY', _arcadeDisplaySideTitleOffsetY);
      _arcadeDisplaySideTitleScale = readDouble('arcadeDisplaySideTitleScale', _arcadeDisplaySideTitleScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayCenterTitleOffsetX = readDouble('arcadeDisplayCenterTitleOffsetX', _arcadeDisplayCenterTitleOffsetX);
      _arcadeDisplayCenterTitleOffsetY = readDouble('arcadeDisplayCenterTitleOffsetY', _arcadeDisplayCenterTitleOffsetY);
      _arcadeDisplayCenterTitleScale = readDouble('arcadeDisplayCenterTitleScale', _arcadeDisplayCenterTitleScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayCurrentGameOffsetX = readDouble('arcadeDisplayCurrentGameOffsetX', _arcadeDisplayCurrentGameOffsetX);
      _arcadeDisplayCurrentGameOffsetY = readDouble('arcadeDisplayCurrentGameOffsetY', _arcadeDisplayCurrentGameOffsetY);
      _arcadeDisplayCurrentGameScale = readDouble('arcadeDisplayCurrentGameScale', _arcadeDisplayCurrentGameScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayCardsOffsetX = readDouble('arcadeDisplayCardsOffsetX', _arcadeDisplayCardsOffsetX);
      _arcadeDisplayCardsOffsetY = readDouble('arcadeDisplayCardsOffsetY', _arcadeDisplayCardsOffsetY);
      _arcadeDisplayCardsScale = readDouble('arcadeDisplayCardsScale', _arcadeDisplayCardsScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayCardsGapScale = readDouble('arcadeDisplayCardsGapScale', _arcadeDisplayCardsGapScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayArrowsOffsetX = readDouble('arcadeDisplayArrowsOffsetX', _arcadeDisplayArrowsOffsetX);
      _arcadeDisplayArrowsOffsetY = readDouble('arcadeDisplayArrowsOffsetY', _arcadeDisplayArrowsOffsetY);
      _arcadeDisplayArrowsScale = readDouble('arcadeDisplayArrowsScale', _arcadeDisplayArrowsScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayDotsOffsetX = readDouble('arcadeDisplayDotsOffsetX', _arcadeDisplayDotsOffsetX);
      _arcadeDisplayDotsOffsetY = readDouble('arcadeDisplayDotsOffsetY', _arcadeDisplayDotsOffsetY);
      _arcadeDisplayDotsScale = readDouble('arcadeDisplayDotsScale', _arcadeDisplayDotsScale).clamp(.1, 5.0).toDouble();
      _arcadeDisplayHintOffsetX = readDouble('arcadeDisplayHintOffsetX', _arcadeDisplayHintOffsetX);
      _arcadeDisplayHintOffsetY = readDouble('arcadeDisplayHintOffsetY', _arcadeDisplayHintOffsetY);
      _arcadeDisplayHintScale = readDouble('arcadeDisplayHintScale', _arcadeDisplayHintScale).clamp(.1, 5.0).toDouble();
      _showArcadeJoystickPressHitbox = readBool('showArcadeJoystickPressHitbox', _showArcadeJoystickPressHitbox);
      _arcadeJoystickPressHitboxX = readDouble('arcadeJoystickPressHitboxX', _arcadeJoystickPressHitboxX);
      _arcadeJoystickPressHitboxY = readDouble('arcadeJoystickPressHitboxY', _arcadeJoystickPressHitboxY);
      _arcadeJoystickPressHitboxZ = readDouble('arcadeJoystickPressHitboxZ', _arcadeJoystickPressHitboxZ);
      _arcadeJoystickPressHitboxSizeX = readDouble('arcadeJoystickPressHitboxSizeX', _arcadeJoystickPressHitboxSizeX).clamp(.01, 20.0).toDouble();
      _arcadeJoystickPressHitboxSizeY = readDouble('arcadeJoystickPressHitboxSizeY', _arcadeJoystickPressHitboxSizeY).clamp(.01, 20.0).toDouble();
      _arcadeJoystickPressHitboxSizeZ = readDouble('arcadeJoystickPressHitboxSizeZ', _arcadeJoystickPressHitboxSizeZ).clamp(.01, 20.0).toDouble();
      _arcadeJoystickPressPreview = readBool('arcadeJoystickPressPreview', _arcadeJoystickPressPreview);
      _arcadeJoystickPreviewDirection = readDouble('arcadeJoystickPreviewDirection', _arcadeJoystickPreviewDirection) < 0 ? -1 : 1;
      _arcadeJoystickPressDuration = readDouble('arcadeJoystickPressDuration', _arcadeJoystickPressDuration);
      _arcadeJoystickReturnDuration = readDouble('arcadeJoystickReturnDuration', _arcadeJoystickReturnDuration);
      _arcadeJoystickPressOffsetX = readDouble('arcadeJoystickPressOffsetX', _arcadeJoystickPressOffsetX);
      _arcadeJoystickPressOffsetY = readDouble('arcadeJoystickPressOffsetY', _arcadeJoystickPressOffsetY);
      _arcadeJoystickPressOffsetZ = readDouble('arcadeJoystickPressOffsetZ', _arcadeJoystickPressOffsetZ);
      _arcadeJoystickTiltPitch = readDouble('arcadeJoystickTiltPitch', _arcadeJoystickTiltPitch);
      _arcadeJoystickTiltYaw = readDouble('arcadeJoystickTiltYaw', _arcadeJoystickTiltYaw);
      _arcadeJoystickTiltRoll = readDouble('arcadeJoystickTiltRoll', _arcadeJoystickTiltRoll);
      _arcadeJoystickPreviousPressDuration = readDouble(
        'arcadeJoystickPreviousPressDuration',
        _arcadeJoystickPreviousPressDuration,
      );
      _arcadeJoystickPreviousReturnDuration = readDouble(
        'arcadeJoystickPreviousReturnDuration',
        _arcadeJoystickPreviousReturnDuration,
      );
      _arcadeJoystickPreviousOffsetX = readDouble(
        'arcadeJoystickPreviousOffsetX',
        _arcadeJoystickPreviousOffsetX,
      );
      _arcadeJoystickPreviousOffsetY = readDouble(
        'arcadeJoystickPreviousOffsetY',
        _arcadeJoystickPreviousOffsetY,
      );
      _arcadeJoystickPreviousOffsetZ = readDouble(
        'arcadeJoystickPreviousOffsetZ',
        _arcadeJoystickPreviousOffsetZ,
      );
      _arcadeJoystickPreviousTiltPitch = readDouble(
        'arcadeJoystickPreviousTiltPitch',
        _arcadeJoystickPreviousTiltPitch,
      );
      _arcadeJoystickPreviousTiltYaw = readDouble(
        'arcadeJoystickPreviousTiltYaw',
        _arcadeJoystickPreviousTiltYaw,
      );
      _arcadeJoystickPreviousTiltRoll = readDouble(
        'arcadeJoystickPreviousTiltRoll',
        _arcadeJoystickPreviousTiltRoll,
      );
      _arcadeJoystickPreviousPeakHold = readDouble(
        'arcadeJoystickPreviousPeakHold',
        _arcadeJoystickPreviousPeakHold,
      );
      _arcadeJoystickPreviousReturnCompX = readDouble(
        'arcadeJoystickPreviousReturnCompX',
        _arcadeJoystickPreviousReturnCompX,
      );
      _arcadeJoystickPreviousReturnCompY = readDouble(
        'arcadeJoystickPreviousReturnCompY',
        _arcadeJoystickPreviousReturnCompY,
      );
      _arcadeJoystickPreviousReturnCompZ = readDouble(
        'arcadeJoystickPreviousReturnCompZ',
        _arcadeJoystickPreviousReturnCompZ,
      );
      _arcadeJoystickPreviousReturnCompStrength = readDouble(
        'arcadeJoystickPreviousReturnCompStrength',
        _arcadeJoystickPreviousReturnCompStrength,
      );
      _showArcadeEnterButton = readBool('showArcadeEnterButton', _showArcadeEnterButton);
      _arcadeEnterButtonX = readDouble('arcadeEnterButtonX', _arcadeEnterButtonX);
      _arcadeEnterButtonY = readDouble('arcadeEnterButtonY', _arcadeEnterButtonY);
      _arcadeEnterButtonZ = readDouble('arcadeEnterButtonZ', _arcadeEnterButtonZ);
      _arcadeEnterButtonRotX = readDouble('arcadeEnterButtonRotX', _arcadeEnterButtonRotX);
      _arcadeEnterButtonRotY = readDouble('arcadeEnterButtonRotY', _arcadeEnterButtonRotY);
      _arcadeEnterButtonRotZ = readDouble('arcadeEnterButtonRotZ', _arcadeEnterButtonRotZ);
      _arcadeEnterButtonScaleX = readDouble('arcadeEnterButtonScaleX', _arcadeEnterButtonScaleX);
      _arcadeEnterButtonScaleY = readDouble('arcadeEnterButtonScaleY', _arcadeEnterButtonScaleY);
      _arcadeEnterButtonScaleZ = readDouble('arcadeEnterButtonScaleZ', _arcadeEnterButtonScaleZ);
      _arcadeEnterButtonPressDuration = readDouble('arcadeEnterButtonPressDuration', _arcadeEnterButtonPressDuration);
      _arcadeEnterButtonReturnDuration = readDouble('arcadeEnterButtonReturnDuration', _arcadeEnterButtonReturnDuration);
      _arcadeEnterButtonPressDepth = readDouble('arcadeEnterButtonPressDepth', _arcadeEnterButtonPressDepth);
      _arcadeEnterButtonRedColorEnabled = readBool('arcadeEnterButtonRedColorEnabled', _arcadeEnterButtonRedColorEnabled);
      _arcadeEnterButtonRedR = readDouble('arcadeEnterButtonRedR', _arcadeEnterButtonRedR);
      _arcadeEnterButtonRedG = readDouble('arcadeEnterButtonRedG', _arcadeEnterButtonRedG);
      _arcadeEnterButtonRedB = readDouble('arcadeEnterButtonRedB', _arcadeEnterButtonRedB);
      _arcadeEnterButtonPreviewPressed = readBool('arcadeEnterButtonPreviewPressed', _arcadeEnterButtonPreviewPressed);
      _showArcadeCutter = readBool('showArcadeCutter', _showArcadeCutter);
      _cutterX = readDouble('cutterX', _cutterX);
      _cutterY = readDouble('cutterY', _cutterY);
      _cutterZ = readDouble('cutterZ', _cutterZ);
      _cutterLeft = readDouble('cutterLeft', _cutterLeft);
      _cutterRight = readDouble('cutterRight', _cutterRight);
      _cutterUp = readDouble('cutterUp', _cutterUp);
      _cutterDown = readDouble('cutterDown', _cutterDown);
      _cutterFront = readDouble('cutterFront', _cutterFront);
      _cutterBack = readDouble('cutterBack', _cutterBack);
      _cutterPitch = readDouble('cutterPitch', _cutterPitch);
      _cutterYaw = readDouble('cutterYaw', _cutterYaw);
      _cutterRoll = readDouble('cutterRoll', _cutterRoll);

      _characterX = readDouble('characterX', _characterX);
      _characterY = readDouble('characterY', _characterY);
      _characterZ = readDouble('characterZ', _characterZ);
      _characterRotX = readDouble('characterRotX', _characterRotX);
      _characterRotY = readDouble('characterRotY', _characterRotY);
      _characterRotZ = readDouble('characterRotZ', _characterRotZ);
      _characterScaleX = readDouble('characterScaleX', _characterScaleX);
      _characterScaleY = readDouble('characterScaleY', _characterScaleY);
      _characterScaleZ = readDouble('characterScaleZ', _characterScaleZ);

      _arcadeHighlightVisible = readBool('arcadeHighlightVisible', _arcadeHighlightVisible);
      _arcadeX = readDouble('arcadeX', _arcadeX);
      _arcadeY = readDouble('arcadeY', _arcadeY);
      _arcadeZ = readDouble('arcadeZ', _arcadeZ);
      _arcadeRotX = readDouble('arcadeRotX', _arcadeRotX);
      _arcadeRotY = readDouble('arcadeRotY', _arcadeRotY);
      _arcadeRotZ = readDouble('arcadeRotZ', _arcadeRotZ);
      _arcadeSizeX = readDouble('arcadeSizeX', _arcadeSizeX);
      _arcadeSizeY = readDouble('arcadeSizeY', _arcadeSizeY);
      _arcadeSizeZ = readDouble('arcadeSizeZ', _arcadeSizeZ);
      _arcadeGlowThickness = readDouble('arcadeGlowThickness', _arcadeGlowThickness);
      _arcadeGlowIntensity = readDouble('arcadeGlowIntensity', _arcadeGlowIntensity);
      _arcadeGlowOpacity = readDouble('arcadeGlowOpacity', _arcadeGlowOpacity);
      _arcadeGlowR = readDouble('arcadeGlowR', _arcadeGlowR);
      _arcadeGlowG = readDouble('arcadeGlowG', _arcadeGlowG);
      _arcadeGlowB = readDouble('arcadeGlowB', _arcadeGlowB);
      _arcadeGlowTopR = readDouble('arcadeGlowTopR', _arcadeGlowTopR);
      _arcadeGlowTopG = readDouble('arcadeGlowTopG', _arcadeGlowTopG);
      _arcadeGlowTopB = readDouble('arcadeGlowTopB', _arcadeGlowTopB);
      _arcadeGlowTopOpacity = readDouble('arcadeGlowTopOpacity', _arcadeGlowTopOpacity);
      _arcadeGlowBottomR = readDouble('arcadeGlowBottomR', _arcadeGlowBottomR);
      _arcadeGlowBottomG = readDouble('arcadeGlowBottomG', _arcadeGlowBottomG);
      _arcadeGlowBottomB = readDouble('arcadeGlowBottomB', _arcadeGlowBottomB);
      _arcadeGlowBottomOpacity = readDouble('arcadeGlowBottomOpacity', _arcadeGlowBottomOpacity);
      _arcadeGlowBlendMidpoint = readDouble('arcadeGlowBlendMidpoint', _arcadeGlowBlendMidpoint);
      _arcadeGlowAutoRotate = readBool('arcadeGlowAutoRotate', _arcadeGlowAutoRotate);
      _arcadeGlowRotationSpeed = readDouble('arcadeGlowRotationSpeed', _arcadeGlowRotationSpeed);
      _arcadeGlowRotateRight = readBool('arcadeGlowRotateRight', _arcadeGlowRotateRight);
      _arcadeGlowAutoBob = readBool('arcadeGlowAutoBob', _arcadeGlowAutoBob);
      _arcadeGlowBobAmount = readDouble('arcadeGlowBobAmount', _arcadeGlowBobAmount);
      _arcadeGlowBobSpeed = readDouble('arcadeGlowBobSpeed', _arcadeGlowBobSpeed);
      _arcadeFocusCameraX = readDouble('arcadeFocusCameraX', _arcadeFocusCameraX);
      _arcadeFocusCameraY = readDouble('arcadeFocusCameraY', _arcadeFocusCameraY);
      _arcadeFocusCameraZ = readDouble('arcadeFocusCameraZ', _arcadeFocusCameraZ);
      _arcadeFocusTargetX = readDouble('arcadeFocusTargetX', _arcadeFocusTargetX);
      _arcadeFocusTargetY = readDouble('arcadeFocusTargetY', _arcadeFocusTargetY);
      _arcadeFocusTargetZ = readDouble('arcadeFocusTargetZ', _arcadeFocusTargetZ);
      _arcadeFocusFov = readDouble('arcadeFocusFov', _arcadeFocusFov);
      _arcadeTransitionSeconds = readDouble('arcadeTransitionSeconds', _arcadeTransitionSeconds);

      _motionPlaying = readBool('motionPlaying', _motionPlaying);
      _motionLoop = readBool('motionLoop', _motionLoop);
      _newKeyframeDuration = readDouble('newKeyframeDuration', _newKeyframeDuration);
      final selectedTrackId = decoded['selectedTrackId'];
      if (selectedTrackId is String && _motionTracks.containsKey(selectedTrackId)) {
        _selectedTrackId = selectedTrackId;
      }

      final poseData = decoded['poseTunings'];
      if (poseData is List) {
        for (final entry in poseData) {
          if (entry is! Map) continue;
          final nodeName = entry['nodeName']?.toString();
          if (nodeName == null) continue;
          _PoseTuning? tuning;
          for (final item in _poseTunings) {
            if (item.nodeName == nodeName) {
              tuning = item;
              break;
            }
          }
          if (tuning == null) continue;
          tuning.rotX = (entry['rotX'] as num?)?.toDouble() ?? tuning.rotX;
          tuning.rotY = (entry['rotY'] as num?)?.toDouble() ?? tuning.rotY;
          tuning.rotZ = (entry['rotZ'] as num?)?.toDouble() ?? tuning.rotZ;
          tuning.offsetX = (entry['offsetX'] as num?)?.toDouble() ?? tuning.offsetX;
          tuning.offsetY = (entry['offsetY'] as num?)?.toDouble() ?? tuning.offsetY;
          tuning.offsetZ = (entry['offsetZ'] as num?)?.toDouble() ?? tuning.offsetZ;
        }
      }

      final motionData = decoded['motionTracks'];
      if (motionData is List) {
        for (final entry in motionData) {
          if (entry is! Map<String, dynamic>) continue;
          final track = _MotionTrack.fromJson(entry);
          final existing = _motionTracks[track.id];
          if (existing == null) continue;
          existing
            ..enabled = track.enabled
            ..keyframes = track.keyframes;
        }
      }
    } catch (_) {}
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _saveSettings);
  }

  Future<void> _saveSettings() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final data = <String, dynamic>{
      'developerPanelOpen': _developerPanelOpen,
      'motionPanelOpen': _motionPanelOpen,
      'developerSection': _developerSection,
      'showRoom': _showRoom,
      'showCharacter': _showCharacter,
      'showGuide': _showGuide,
      'renderScale': _renderScale,
      'sceneExposure': _sceneExposure,
      'lightIntensity': _lightIntensity,
      'lightYawDeg': _lightYawDeg,
      'lightPitchDeg': _lightPitchDeg,
      'cameraX': _cameraX,
      'cameraY': _cameraY,
      'cameraZ': _cameraZ,
      'targetX': _targetX,
      'targetY': _targetY,
      'targetZ': _targetZ,
      'cameraFov': _cameraFov,
      'cameraMoveSpeed': _cameraMoveSpeed,
      'mouseSensitivity': _mouseSensitivity,
      'mainLookLeftDeg': _mainLookLeftDeg,
      'mainLookRightDeg': _mainLookRightDeg,
      'mainLookUpDeg': _mainLookUpDeg,
      'mainLookDownDeg': _mainLookDownDeg,
      'userLookInertia': _userLookInertia,
      'userLookInputBoost': _userLookInputBoost,
      'userLookMaxVelocityDeg': _userLookMaxVelocityDeg,
      'userLookOverscrollDeg': _userLookOverscrollDeg,
      'userLookSpringStrength': _userLookSpringStrength,
      'userLookSpringDamping': _userLookSpringDamping,
      'arcadeLookLeftDeg': _arcadeLookLeftDeg,
      'arcadeLookRightDeg': _arcadeLookRightDeg,
      'arcadeLookUpDeg': _arcadeLookUpDeg,
      'arcadeLookDownDeg': _arcadeLookDownDeg,
      'userStartCameraX': _userStartCameraX,
      'userStartCameraY': _userStartCameraY,
      'userStartCameraZ': _userStartCameraZ,
      'userStartTargetX': _userStartTargetX,
      'userStartTargetY': _userStartTargetY,
      'userStartTargetZ': _userStartTargetZ,
      'userStartFov': _userStartFov,
      'roomX': _roomX,
      'roomY': _roomY,
      'roomZ': _roomZ,
      'roomRotX': _roomRotX,
      'roomRotY': _roomRotY,
      'roomRotZ': _roomRotZ,
      'roomScaleX': _roomScaleX,
      'roomScaleY': _roomScaleY,
      'roomScaleZ': _roomScaleZ,
      'showTv': _showTv,
      'tvX': _tvX,
      'tvY': _tvY,
      'tvZ': _tvZ,
      'tvRotX': _tvRotX,
      'tvRotY': _tvRotY,
      'tvRotZ': _tvRotZ,
      'tvScaleX': _tvScaleX,
      'tvScaleY': _tvScaleY,
      'tvScaleZ': _tvScaleZ,
      'tvEntryStartX': _tvEntryStartX,
      'tvEntryStartY': _tvEntryStartY,
      'tvEntryStartZ': _tvEntryStartZ,
      'tvEntryStartRotX': _tvEntryStartRotX,
      'tvEntryStartRotY': _tvEntryStartRotY,
      'tvEntryStartRotZ': _tvEntryStartRotZ,
      'tvEntryStartScaleX': _tvEntryStartScaleX,
      'tvEntryStartScaleY': _tvEntryStartScaleY,
      'tvEntryStartScaleZ': _tvEntryStartScaleZ,
      'tvEntrySpinXTurns': _tvEntrySpinXTurns,
      'tvEntrySpinYTurns': _tvEntrySpinYTurns,
      'tvEntrySpinZTurns': _tvEntrySpinZTurns,
      'tvEntryDuration': _tvEntryDuration,
      'tvCameraX': _tvCameraX,
      'tvCameraY': _tvCameraY,
      'tvCameraZ': _tvCameraZ,
      'tvCameraTargetX': _tvCameraTargetX,
      'tvCameraTargetY': _tvCameraTargetY,
      'tvCameraTargetZ': _tvCameraTargetZ,
      'tvCameraFov': _tvCameraFov,
      'tvCameraDuration': _tvCameraDuration,
      'tvLookLeftDeg': _tvLookLeftDeg,
      'tvLookRightDeg': _tvLookRightDeg,
      'tvLookUpDeg': _tvLookUpDeg,
      'tvLookDownDeg': _tvLookDownDeg,
      'tvCameraLivePreview': _tvCameraLivePreview,
      'tvIdleMotionEnabled': _tvIdleMotionEnabled,
      'tvIdleMoveX': _tvIdleMoveX,
      'tvIdleMoveY': _tvIdleMoveY,
      'tvIdleMoveZ': _tvIdleMoveZ,
      'tvIdleRotX': _tvIdleRotX,
      'tvIdleRotY': _tvIdleRotY,
      'tvIdleRotZ': _tvIdleRotZ,
      'tvIdleCycleSeconds': _tvIdleCycleSeconds,
      'showTvScreen': _showTvScreen,
      'tvScreenX': _tvScreenX,
      'tvScreenY': _tvScreenY,
      'tvScreenZ': _tvScreenZ,
      'tvScreenRotX': _tvScreenRotX,
      'tvScreenRotY': _tvScreenRotY,
      'tvScreenRotZ': _tvScreenRotZ,
      'tvScreenScaleX': _tvScreenScaleX,
      'tvScreenScaleY': _tvScreenScaleY,
      'tvScreenScaleZ': _tvScreenScaleZ,
      'tvScreenHighlight': _tvScreenHighlight,
      'tvDetailsVisible': _tvDetailsVisible,
      'tvUiTitleOffsetX': _tvUiTitleOffsetX,
      'tvUiTitleOffsetY': _tvUiTitleOffsetY,
      'tvUiTitleScale': _tvUiTitleScale,
      'tvUiButtonsOffsetX': _tvUiButtonsOffsetX,
      'tvUiButtonsOffsetY': _tvUiButtonsOffsetY,
      'tvUiButtonsScale': _tvUiButtonsScale,
      'tvUiButtonsGap': _tvUiButtonsGap,
      'tvUiInfoOffsetX': _tvUiInfoOffsetX,
      'tvUiInfoOffsetY': _tvUiInfoOffsetY,
      'tvUiInfoScale': _tvUiInfoScale,
      'tvUiPanelOffsetX': _tvUiPanelOffsetX,
      'tvUiPanelOffsetY': _tvUiPanelOffsetY,
      'tvUiPanelScale': _tvUiPanelScale,
      'tvUiButtonRadius': _tvUiButtonRadius,
      'tvUiButtonStroke': _tvUiButtonStroke,
      'tvUiBgR': _tvUiBgR,
      'tvUiBgG': _tvUiBgG,
      'tvUiBgB': _tvUiBgB,
      'tvUiAccentR': _tvUiAccentR,
      'tvUiAccentG': _tvUiAccentG,
      'tvUiAccentB': _tvUiAccentB,
      'tvUiTitleR': _tvUiTitleR,
      'tvUiTitleG': _tvUiTitleG,
      'tvUiTitleB': _tvUiTitleB,
      'tvUiOfflineR': _tvUiOfflineR,
      'tvUiOfflineG': _tvUiOfflineG,
      'tvUiOfflineB': _tvUiOfflineB,
      'tvUiOnlineR': _tvUiOnlineR,
      'tvUiOnlineG': _tvUiOnlineG,
      'tvUiOnlineB': _tvUiOnlineB,
      'tvUiDisabledR': _tvUiDisabledR,
      'tvUiDisabledG': _tvUiDisabledG,
      'tvUiDisabledB': _tvUiDisabledB,
      'tvUiInfoR': _tvUiInfoR,
      'tvUiInfoG': _tvUiInfoG,
      'tvUiInfoB': _tvUiInfoB,
      'tvUiTextR': _tvUiTextR,
      'tvUiTextG': _tvUiTextG,
      'tvUiTextB': _tvUiTextB,
      'tvUiPanelR': _tvUiPanelR,
      'tvUiPanelG': _tvUiPanelG,
      'tvUiPanelB': _tvUiPanelB,
      'showArcadeScreen': _showArcadeScreen,
      'arcadeScreenX': _arcadeScreenX,
      'arcadeScreenY': _arcadeScreenY,
      'arcadeScreenZ': _arcadeScreenZ,
      'arcadeScreenRotX': _arcadeScreenRotX,
      'arcadeScreenRotY': _arcadeScreenRotY,
      'arcadeScreenRotZ': _arcadeScreenRotZ,
      'arcadeScreenScaleX': _arcadeScreenScaleX,
      'arcadeScreenScaleY': _arcadeScreenScaleY,
      'arcadeScreenScaleZ': _arcadeScreenScaleZ,
      'arcadeScreenColorEnabled': _arcadeScreenColorEnabled,
      'arcadeScreenColorR': _arcadeScreenColorR,
      'arcadeScreenColorG': _arcadeScreenColorG,
      'arcadeScreenColorB': _arcadeScreenColorB,
      'arcadeScreenColorOpacity': _arcadeScreenColorOpacity,
      'showArcadeJoystick': _showArcadeJoystick,
      'arcadeJoystickX': _arcadeJoystickX,
      'arcadeJoystickY': _arcadeJoystickY,
      'arcadeJoystickZ': _arcadeJoystickZ,
      'arcadeJoystickRotX': _arcadeJoystickRotX,
      'arcadeJoystickRotY': _arcadeJoystickRotY,
      'arcadeJoystickRotZ': _arcadeJoystickRotZ,
      'arcadeJoystickScaleX': _arcadeJoystickScaleX,
      'arcadeJoystickScaleY': _arcadeJoystickScaleY,
      'arcadeJoystickScaleZ': _arcadeJoystickScaleZ,
      'arcadeJoystickColorEnabled': _arcadeJoystickColorEnabled,
      'arcadeJoystickColorR': _arcadeJoystickColorR,
      'arcadeJoystickColorG': _arcadeJoystickColorG,
      'arcadeJoystickColorB': _arcadeJoystickColorB,
      'arcadeJoystickColorOpacity': _arcadeJoystickColorOpacity,
      'revealArcadeScreen': _revealArcadeScreen,
      'revealArcadeJoystick': _revealArcadeJoystick,
      'arcadeDisplayEnabled': _arcadeDisplayEnabled,
      'arcadeDisplaySideTitle': _arcadeDisplaySideTitle,
      'arcadeDisplayCenterTitle': _arcadeDisplayCenterTitle,
      'arcadeSelectedGameIndex': _arcadeSelectedGameIndex,
      'arcadeDisplayBgR': _arcadeDisplayBgR,
      'arcadeDisplayBgG': _arcadeDisplayBgG,
      'arcadeDisplayBgB': _arcadeDisplayBgB,
      'arcadeDisplayHeaderR': _arcadeDisplayHeaderR,
      'arcadeDisplayHeaderG': _arcadeDisplayHeaderG,
      'arcadeDisplayHeaderB': _arcadeDisplayHeaderB,
      'arcadeDisplayAccentR': _arcadeDisplayAccentR,
      'arcadeDisplayAccentG': _arcadeDisplayAccentG,
      'arcadeDisplayAccentB': _arcadeDisplayAccentB,
      'arcadeDisplayCardR': _arcadeDisplayCardR,
      'arcadeDisplayCardG': _arcadeDisplayCardG,
      'arcadeDisplayCardB': _arcadeDisplayCardB,
      'arcadeDisplaySelectedCardR': _arcadeDisplaySelectedCardR,
      'arcadeDisplaySelectedCardG': _arcadeDisplaySelectedCardG,
      'arcadeDisplaySelectedCardB': _arcadeDisplaySelectedCardB,
      'arcadeDisplayTextR': _arcadeDisplayTextR,
      'arcadeDisplayTextG': _arcadeDisplayTextG,
      'arcadeDisplayTextB': _arcadeDisplayTextB,
      'arcadeDisplaySubtextR': _arcadeDisplaySubtextR,
      'arcadeDisplaySubtextG': _arcadeDisplaySubtextG,
      'arcadeDisplaySubtextB': _arcadeDisplaySubtextB,
      'arcadeDisplayArrowR': _arcadeDisplayArrowR,
      'arcadeDisplayArrowG': _arcadeDisplayArrowG,
      'arcadeDisplayArrowB': _arcadeDisplayArrowB,
      'arcadeDisplayFrameR': _arcadeDisplayFrameR,
      'arcadeDisplayFrameG': _arcadeDisplayFrameG,
      'arcadeDisplayFrameB': _arcadeDisplayFrameB,
      'arcadeDisplayShowSubtitle': _arcadeDisplayShowSubtitle,
      'arcadeDisplayHeaderOffsetX': _arcadeDisplayHeaderOffsetX,
      'arcadeDisplayHeaderOffsetY': _arcadeDisplayHeaderOffsetY,
      'arcadeDisplayHeaderScale': _arcadeDisplayHeaderScale,
      'arcadeDisplaySideTitleOffsetX': _arcadeDisplaySideTitleOffsetX,
      'arcadeDisplaySideTitleOffsetY': _arcadeDisplaySideTitleOffsetY,
      'arcadeDisplaySideTitleScale': _arcadeDisplaySideTitleScale,
      'arcadeDisplayCenterTitleOffsetX': _arcadeDisplayCenterTitleOffsetX,
      'arcadeDisplayCenterTitleOffsetY': _arcadeDisplayCenterTitleOffsetY,
      'arcadeDisplayCenterTitleScale': _arcadeDisplayCenterTitleScale,
      'arcadeDisplayCurrentGameOffsetX': _arcadeDisplayCurrentGameOffsetX,
      'arcadeDisplayCurrentGameOffsetY': _arcadeDisplayCurrentGameOffsetY,
      'arcadeDisplayCurrentGameScale': _arcadeDisplayCurrentGameScale,
      'arcadeDisplayCardsOffsetX': _arcadeDisplayCardsOffsetX,
      'arcadeDisplayCardsOffsetY': _arcadeDisplayCardsOffsetY,
      'arcadeDisplayCardsScale': _arcadeDisplayCardsScale,
      'arcadeDisplayCardsGapScale': _arcadeDisplayCardsGapScale,
      'arcadeDisplayArrowsOffsetX': _arcadeDisplayArrowsOffsetX,
      'arcadeDisplayArrowsOffsetY': _arcadeDisplayArrowsOffsetY,
      'arcadeDisplayArrowsScale': _arcadeDisplayArrowsScale,
      'arcadeDisplayDotsOffsetX': _arcadeDisplayDotsOffsetX,
      'arcadeDisplayDotsOffsetY': _arcadeDisplayDotsOffsetY,
      'arcadeDisplayDotsScale': _arcadeDisplayDotsScale,
      'arcadeDisplayHintOffsetX': _arcadeDisplayHintOffsetX,
      'arcadeDisplayHintOffsetY': _arcadeDisplayHintOffsetY,
      'arcadeDisplayHintScale': _arcadeDisplayHintScale,
      'showArcadeJoystickPressHitbox': _showArcadeJoystickPressHitbox,
      'arcadeJoystickPressHitboxX': _arcadeJoystickPressHitboxX,
      'arcadeJoystickPressHitboxY': _arcadeJoystickPressHitboxY,
      'arcadeJoystickPressHitboxZ': _arcadeJoystickPressHitboxZ,
      'arcadeJoystickPressHitboxSizeX': _arcadeJoystickPressHitboxSizeX,
      'arcadeJoystickPressHitboxSizeY': _arcadeJoystickPressHitboxSizeY,
      'arcadeJoystickPressHitboxSizeZ': _arcadeJoystickPressHitboxSizeZ,
      'arcadeJoystickPressPreview': _arcadeJoystickPressPreview,
      'arcadeJoystickPreviewDirection': _arcadeJoystickPreviewDirection,
      'arcadeJoystickPressDuration': _arcadeJoystickPressDuration,
      'arcadeJoystickReturnDuration': _arcadeJoystickReturnDuration,
      'arcadeJoystickPressOffsetX': _arcadeJoystickPressOffsetX,
      'arcadeJoystickPressOffsetY': _arcadeJoystickPressOffsetY,
      'arcadeJoystickPressOffsetZ': _arcadeJoystickPressOffsetZ,
      'arcadeJoystickTiltPitch': _arcadeJoystickTiltPitch,
      'arcadeJoystickTiltYaw': _arcadeJoystickTiltYaw,
      'arcadeJoystickTiltRoll': _arcadeJoystickTiltRoll,
      'arcadeJoystickPreviousPressDuration':
          _arcadeJoystickPreviousPressDuration,
      'arcadeJoystickPreviousReturnDuration':
          _arcadeJoystickPreviousReturnDuration,
      'arcadeJoystickPreviousOffsetX': _arcadeJoystickPreviousOffsetX,
      'arcadeJoystickPreviousOffsetY': _arcadeJoystickPreviousOffsetY,
      'arcadeJoystickPreviousOffsetZ': _arcadeJoystickPreviousOffsetZ,
      'arcadeJoystickPreviousTiltPitch': _arcadeJoystickPreviousTiltPitch,
      'arcadeJoystickPreviousTiltYaw': _arcadeJoystickPreviousTiltYaw,
      'arcadeJoystickPreviousTiltRoll': _arcadeJoystickPreviousTiltRoll,
      'arcadeJoystickPreviousPeakHold': _arcadeJoystickPreviousPeakHold,
      'arcadeJoystickPreviousReturnCompX':
          _arcadeJoystickPreviousReturnCompX,
      'arcadeJoystickPreviousReturnCompY':
          _arcadeJoystickPreviousReturnCompY,
      'arcadeJoystickPreviousReturnCompZ':
          _arcadeJoystickPreviousReturnCompZ,
      'arcadeJoystickPreviousReturnCompStrength':
          _arcadeJoystickPreviousReturnCompStrength,
      'showArcadeEnterButton': _showArcadeEnterButton,
      'arcadeEnterButtonX': _arcadeEnterButtonX,
      'arcadeEnterButtonY': _arcadeEnterButtonY,
      'arcadeEnterButtonZ': _arcadeEnterButtonZ,
      'arcadeEnterButtonRotX': _arcadeEnterButtonRotX,
      'arcadeEnterButtonRotY': _arcadeEnterButtonRotY,
      'arcadeEnterButtonRotZ': _arcadeEnterButtonRotZ,
      'arcadeEnterButtonScaleX': _arcadeEnterButtonScaleX,
      'arcadeEnterButtonScaleY': _arcadeEnterButtonScaleY,
      'arcadeEnterButtonScaleZ': _arcadeEnterButtonScaleZ,
      'arcadeEnterButtonPressDuration': _arcadeEnterButtonPressDuration,
      'arcadeEnterButtonReturnDuration': _arcadeEnterButtonReturnDuration,
      'arcadeEnterButtonPressDepth': _arcadeEnterButtonPressDepth,
      'arcadeEnterButtonRedColorEnabled': _arcadeEnterButtonRedColorEnabled,
      'arcadeEnterButtonRedR': _arcadeEnterButtonRedR,
      'arcadeEnterButtonRedG': _arcadeEnterButtonRedG,
      'arcadeEnterButtonRedB': _arcadeEnterButtonRedB,
      'arcadeEnterButtonPreviewPressed': _arcadeEnterButtonPreviewPressed,
      'showArcadeCutter': _showArcadeCutter,
      'cutterX': _cutterX,
      'cutterY': _cutterY,
      'cutterZ': _cutterZ,
      'cutterLeft': _cutterLeft,
      'cutterRight': _cutterRight,
      'cutterUp': _cutterUp,
      'cutterDown': _cutterDown,
      'cutterFront': _cutterFront,
      'cutterBack': _cutterBack,
      'cutterPitch': _cutterPitch,
      'cutterYaw': _cutterYaw,
      'cutterRoll': _cutterRoll,
      'characterX': _characterX,
      'characterY': _characterY,
      'characterZ': _characterZ,
      'characterRotX': _characterRotX,
      'characterRotY': _characterRotY,
      'characterRotZ': _characterRotZ,
      'characterScaleX': _characterScaleX,
      'characterScaleY': _characterScaleY,
      'characterScaleZ': _characterScaleZ,
      'arcadeHighlightVisible': _arcadeHighlightVisible,
      'arcadeX': _arcadeX,
      'arcadeY': _arcadeY,
      'arcadeZ': _arcadeZ,
      'arcadeRotX': _arcadeRotX,
      'arcadeRotY': _arcadeRotY,
      'arcadeRotZ': _arcadeRotZ,
      'arcadeSizeX': _arcadeSizeX,
      'arcadeSizeY': _arcadeSizeY,
      'arcadeSizeZ': _arcadeSizeZ,
      'arcadeGlowThickness': _arcadeGlowThickness,
      'arcadeGlowIntensity': _arcadeGlowIntensity,
      'arcadeGlowOpacity': _arcadeGlowOpacity,
      'arcadeGlowR': _arcadeGlowR,
      'arcadeGlowG': _arcadeGlowG,
      'arcadeGlowB': _arcadeGlowB,
      'arcadeGlowTopR': _arcadeGlowTopR,
      'arcadeGlowTopG': _arcadeGlowTopG,
      'arcadeGlowTopB': _arcadeGlowTopB,
      'arcadeGlowTopOpacity': _arcadeGlowTopOpacity,
      'arcadeGlowBottomR': _arcadeGlowBottomR,
      'arcadeGlowBottomG': _arcadeGlowBottomG,
      'arcadeGlowBottomB': _arcadeGlowBottomB,
      'arcadeGlowBottomOpacity': _arcadeGlowBottomOpacity,
      'arcadeGlowBlendMidpoint': _arcadeGlowBlendMidpoint,
      'arcadeGlowAutoRotate': _arcadeGlowAutoRotate,
      'arcadeGlowRotationSpeed': _arcadeGlowRotationSpeed,
      'arcadeGlowRotateRight': _arcadeGlowRotateRight,
      'arcadeGlowAutoBob': _arcadeGlowAutoBob,
      'arcadeGlowBobAmount': _arcadeGlowBobAmount,
      'arcadeGlowBobSpeed': _arcadeGlowBobSpeed,
      'arcadeFocusCameraX': _arcadeFocusCameraX,
      'arcadeFocusCameraY': _arcadeFocusCameraY,
      'arcadeFocusCameraZ': _arcadeFocusCameraZ,
      'arcadeFocusTargetX': _arcadeFocusTargetX,
      'arcadeFocusTargetY': _arcadeFocusTargetY,
      'arcadeFocusTargetZ': _arcadeFocusTargetZ,
      'arcadeFocusFov': _arcadeFocusFov,
      'arcadeTransitionSeconds': _arcadeTransitionSeconds,
      'poseTunings': _poseTunings.map((t) => t.toJson()).toList(),
      'motionPlaying': _motionPlaying,
      'motionLoop': _motionLoop,
      'selectedTrackId': _selectedTrackId,
      'newKeyframeDuration': _newKeyframeDuration,
      'motionTracks': _motionTracks.values.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  Future<void> _resetDeveloperSettings() async {
    _saveTimer?.cancel();
    await _prefs?.remove(_prefsKey);
    setState(() {
      _applyFactoryDefaults();
      _initializeMotionTracks();
      _applyFactoryMotionDefaults();
      _syncCameraAnglesFromCurrentView();
      _applyAllTransforms(save: false, repaint: false);
    });
  }

  Future<void> _copyCurrentValues() async {
    final buffer = StringBuffer();
    buffer.writeln('SOOKY_ARCADE_LOBBY_VALUES');
    buffer.writeln('UI showGuide=$_showGuide developerPanel=$_developerPanelOpen motionPanel=$_motionPanelOpen developerSection=$_developerSection userMode=$_userModeActive');
    buffer.writeln('BACKGROUND spaceStars=true');
    buffer.writeln(
      'CAMERA position=${_fmt4(_cameraX)},${_fmt4(_cameraY)},${_fmt4(_cameraZ)}',
    );
    buffer.writeln(
      'CAMERA_TARGET position=${_fmt4(_targetX)},${_fmt4(_targetY)},${_fmt4(_targetZ)}',
    );
    buffer.writeln(
      'CAMERA fov=${_fmt2(_cameraFov)} moveSpeed=${_fmt4(_cameraMoveSpeed)} mouseSensitivity=${_fmt4(_mouseSensitivity)}',
    );
    buffer.writeln(
      'USER_START_CAMERA position=${_fmt4(_userStartCameraX)},${_fmt4(_userStartCameraY)},${_fmt4(_userStartCameraZ)} target=${_fmt4(_userStartTargetX)},${_fmt4(_userStartTargetY)},${_fmt4(_userStartTargetZ)} fov=${_fmt2(_userStartFov)}',
    );
    buffer.writeln(
      'USER_VIEW_LIMITS left=${_fmt2(_mainLookLeftDeg)} right=${_fmt2(_mainLookRightDeg)} up=${_fmt2(_mainLookUpDeg)} down=${_fmt2(_mainLookDownDeg)}',
    );
    buffer.writeln(
      'USER_CAMERA_MOTION idleDelay=${_fmt2(_userCameraIdleDelaySeconds)} resumeBlend=${_fmt2(_cameraMotionResumeBlendSeconds)} override=$_userCameraOverrideActive',
    );
    buffer.writeln(
      'USER_LOOK_PHYSICS inertia=${_fmt2(_userLookInertia)} inputBoost=${_fmt2(_userLookInputBoost)} maxVelocityDeg=${_fmt2(_userLookMaxVelocityDeg)} overscrollDeg=${_fmt2(_userLookOverscrollDeg)} spring=${_fmt2(_userLookSpringStrength)} damping=${_fmt2(_userLookSpringDamping)}',
    );
    buffer.writeln(
      'ARCADE_VIEW_LIMITS left=${_fmt2(_arcadeLookLeftDeg)} right=${_fmt2(_arcadeLookRightDeg)} up=${_fmt2(_arcadeLookUpDeg)} down=${_fmt2(_arcadeLookDownDeg)}',
    );
    buffer.writeln(
      'ROOM visible=$_showRoom pos=${_fmt4(_roomX)},${_fmt4(_roomY)},${_fmt4(_roomZ)} rot=${_fmt2(_roomRotX)},${_fmt2(_roomRotY)},${_fmt2(_roomRotZ)} scale=${_fmt4(_roomScaleX)},${_fmt4(_roomScaleY)},${_fmt4(_roomScaleZ)}',
    );
    buffer.writeln(
      'TV visible=$_showTv pos=${_fmt4(_tvX)},${_fmt4(_tvY)},${_fmt4(_tvZ)} rot=${_fmt2(_tvRotX)},${_fmt2(_tvRotY)},${_fmt2(_tvRotZ)} scale=${_fmt4(_tvScaleX)},${_fmt4(_tvScaleY)},${_fmt4(_tvScaleZ)}',
    );
    buffer.writeln(
      'TV_SCREEN visible=$_showTvScreen highlight=$_tvScreenHighlight pos=0.0000,0.0000,0.0000 rot=0.00,0.00,0.00 scale=1.0000,1.0000,1.0000 lockedToTv=true',
    );
    buffer.writeln(
      'TV_GAME_UI details=$_tvDetailsVisible title=(${_fmt2(_tvUiTitleOffsetX)},${_fmt2(_tvUiTitleOffsetY)},${_fmt2(_tvUiTitleScale)}) buttons=(${_fmt2(_tvUiButtonsOffsetX)},${_fmt2(_tvUiButtonsOffsetY)},${_fmt2(_tvUiButtonsScale)}) gap=${_fmt2(_tvUiButtonsGap)} info=(${_fmt2(_tvUiInfoOffsetX)},${_fmt2(_tvUiInfoOffsetY)},${_fmt2(_tvUiInfoScale)}) panel=(${_fmt2(_tvUiPanelOffsetX)},${_fmt2(_tvUiPanelOffsetY)},${_fmt2(_tvUiPanelScale)}) radius=${_fmt2(_tvUiButtonRadius)} stroke=${_fmt2(_tvUiButtonStroke)} bgRGB=${_tvUiBgR.round()},${_tvUiBgG.round()},${_tvUiBgB.round()} accentRGB=${_tvUiAccentR.round()},${_tvUiAccentG.round()},${_tvUiAccentB.round()} titleRGB=${_tvUiTitleR.round()},${_tvUiTitleG.round()},${_tvUiTitleB.round()} offlineRGB=${_tvUiOfflineR.round()},${_tvUiOfflineG.round()},${_tvUiOfflineB.round()} onlineRGB=${_tvUiOnlineR.round()},${_tvUiOnlineG.round()},${_tvUiOnlineB.round()} disabledRGB=${_tvUiDisabledR.round()},${_tvUiDisabledG.round()},${_tvUiDisabledB.round()} infoRGB=${_tvUiInfoR.round()},${_tvUiInfoG.round()},${_tvUiInfoB.round()} textRGB=${_tvUiTextR.round()},${_tvUiTextG.round()},${_tvUiTextB.round()} panelRGB=${_tvUiPanelR.round()},${_tvUiPanelG.round()},${_tvUiPanelB.round()}',
    );
    buffer.writeln(
      'TV_ENTRY startPos=${_fmt4(_tvEntryStartX)},${_fmt4(_tvEntryStartY)},${_fmt4(_tvEntryStartZ)} startRot=${_fmt2(_tvEntryStartRotX)},${_fmt2(_tvEntryStartRotY)},${_fmt2(_tvEntryStartRotZ)} startScale=${_fmt4(_tvEntryStartScaleX)},${_fmt4(_tvEntryStartScaleY)},${_fmt4(_tvEntryStartScaleZ)} spinTurns=${_fmt2(_tvEntrySpinXTurns)},${_fmt2(_tvEntrySpinYTurns)},${_fmt2(_tvEntrySpinZTurns)} duration=${_fmt2(_tvEntryDuration)}',
    );
    buffer.writeln(
      'TV_CAMERA position=${_fmt4(_tvCameraX)},${_fmt4(_tvCameraY)},${_fmt4(_tvCameraZ)} target=${_fmt4(_tvCameraTargetX)},${_fmt4(_tvCameraTargetY)},${_fmt4(_tvCameraTargetZ)} fov=${_fmt2(_tvCameraFov)} duration=${_fmt2(_tvCameraDuration)}',
    );
    buffer.writeln(
      'TV_VIEW_LIMITS left=${_fmt2(_tvLookLeftDeg)} right=${_fmt2(_tvLookRightDeg)} up=${_fmt2(_tvLookUpDeg)} down=${_fmt2(_tvLookDownDeg)} livePreview=$_tvCameraLivePreview',
    );
    buffer.writeln(
      'TV_IDLE enabled=$_tvIdleMotionEnabled move=${_fmt4(_tvIdleMoveX)},${_fmt4(_tvIdleMoveY)},${_fmt4(_tvIdleMoveZ)} rot=${_fmt2(_tvIdleRotX)},${_fmt2(_tvIdleRotY)},${_fmt2(_tvIdleRotZ)} cycle=${_fmt2(_tvIdleCycleSeconds)} active=$_tvModeActive transitioning=$_tvTransitionAnimating selectedGame=$_tvSelectedGameIndex',
    );
    buffer.writeln(
      'ARCADE_SCREEN visible=$_showArcadeScreen pos=${_fmt4(_arcadeScreenX)},${_fmt4(_arcadeScreenY)},${_fmt4(_arcadeScreenZ)} rot=${_fmt2(_arcadeScreenRotX)},${_fmt2(_arcadeScreenRotY)},${_fmt2(_arcadeScreenRotZ)} scale=${_fmt4(_arcadeScreenScaleX)},${_fmt4(_arcadeScreenScaleY)},${_fmt4(_arcadeScreenScaleZ)}',
    );
    buffer.writeln(
      'ARCADE_JOYSTICK visible=$_showArcadeJoystick pos=${_fmt4(_arcadeJoystickX)},${_fmt4(_arcadeJoystickY)},${_fmt4(_arcadeJoystickZ)} rot=${_fmt2(_arcadeJoystickRotX)},${_fmt2(_arcadeJoystickRotY)},${_fmt2(_arcadeJoystickRotZ)} scale=${_fmt4(_arcadeJoystickScaleX)},${_fmt4(_arcadeJoystickScaleY)},${_fmt4(_arcadeJoystickScaleZ)}',
    );
    buffer.writeln(
      'ARCADE_SCREEN_UI enabled=$_arcadeDisplayEnabled sideTitle=${jsonEncode(_arcadeDisplaySideTitle)} centerTitle=${jsonEncode(_arcadeDisplayCenterTitle)} selected=${_arcadeSelectedGameIndex} bgRGB=${_arcadeDisplayBgR.round()},${_arcadeDisplayBgG.round()},${_arcadeDisplayBgB.round()} headerRGB=${_arcadeDisplayHeaderR.round()},${_arcadeDisplayHeaderG.round()},${_arcadeDisplayHeaderB.round()} accentRGB=${_arcadeDisplayAccentR.round()},${_arcadeDisplayAccentG.round()},${_arcadeDisplayAccentB.round()} cardRGB=${_arcadeDisplayCardR.round()},${_arcadeDisplayCardG.round()},${_arcadeDisplayCardB.round()} selectedCardRGB=${_arcadeDisplaySelectedCardR.round()},${_arcadeDisplaySelectedCardG.round()},${_arcadeDisplaySelectedCardB.round()} textRGB=${_arcadeDisplayTextR.round()},${_arcadeDisplayTextG.round()},${_arcadeDisplayTextB.round()} subtitleRGB=${_arcadeDisplaySubtextR.round()},${_arcadeDisplaySubtextG.round()},${_arcadeDisplaySubtextB.round()} arrowRGB=${_arcadeDisplayArrowR.round()},${_arcadeDisplayArrowG.round()},${_arcadeDisplayArrowB.round()} showSubtitle=$_arcadeDisplayShowSubtitle header=(${_arcadeDisplayHeaderOffsetX.toStringAsFixed(2)},${_arcadeDisplayHeaderOffsetY.toStringAsFixed(2)},${_arcadeDisplayHeaderScale.toStringAsFixed(2)}) sideTitle=(${_arcadeDisplaySideTitleOffsetX.toStringAsFixed(2)},${_arcadeDisplaySideTitleOffsetY.toStringAsFixed(2)},${_arcadeDisplaySideTitleScale.toStringAsFixed(2)}) centerTitle=(${_arcadeDisplayCenterTitleOffsetX.toStringAsFixed(2)},${_arcadeDisplayCenterTitleOffsetY.toStringAsFixed(2)},${_arcadeDisplayCenterTitleScale.toStringAsFixed(2)}) current=(${_arcadeDisplayCurrentGameOffsetX.toStringAsFixed(2)},${_arcadeDisplayCurrentGameOffsetY.toStringAsFixed(2)},${_arcadeDisplayCurrentGameScale.toStringAsFixed(2)}) cards=(${_arcadeDisplayCardsOffsetX.toStringAsFixed(2)},${_arcadeDisplayCardsOffsetY.toStringAsFixed(2)},${_arcadeDisplayCardsScale.toStringAsFixed(2)}) gap=${_arcadeDisplayCardsGapScale.toStringAsFixed(2)} arrows=(${_arcadeDisplayArrowsOffsetX.toStringAsFixed(2)},${_arcadeDisplayArrowsOffsetY.toStringAsFixed(2)},${_arcadeDisplayArrowsScale.toStringAsFixed(2)}) dots=(${_arcadeDisplayDotsOffsetX.toStringAsFixed(2)},${_arcadeDisplayDotsOffsetY.toStringAsFixed(2)},${_arcadeDisplayDotsScale.toStringAsFixed(2)}) hint=(${_arcadeDisplayHintOffsetX.toStringAsFixed(2)},${_arcadeDisplayHintOffsetY.toStringAsFixed(2)},${_arcadeDisplayHintScale.toStringAsFixed(2)})',
    );
    buffer.writeln('ARCADE_CAROUSEL duration=${_fmt3(_arcadeCarouselDuration)} refreshHz=40.00');
    buffer.writeln(
      'ARCADE_JOYSTICK_ACTION_NEXT press=${_fmt3(_arcadeJoystickPressDuration)} return=${_fmt3(_arcadeJoystickReturnDuration)} offset=${_fmt4(_arcadeJoystickPressOffsetX)},${_fmt4(_arcadeJoystickPressOffsetY)},${_fmt4(_arcadeJoystickPressOffsetZ)} tilt=${_fmt2(_arcadeJoystickTiltPitch)},${_fmt2(_arcadeJoystickTiltYaw)},${_fmt2(_arcadeJoystickTiltRoll)}',
    );
    buffer.writeln(
      'ARCADE_JOYSTICK_ACTION_PREVIOUS press=${_fmt3(_arcadeJoystickPreviousPressDuration)} return=${_fmt3(_arcadeJoystickPreviousReturnDuration)} hold=${_fmt3(_arcadeJoystickPreviousPeakHold)} offset=${_fmt4(_arcadeJoystickPreviousOffsetX)},${_fmt4(_arcadeJoystickPreviousOffsetY)},${_fmt4(_arcadeJoystickPreviousOffsetZ)} tilt=${_fmt2(_arcadeJoystickPreviousTiltPitch)},${_fmt2(_arcadeJoystickPreviousTiltYaw)},${_fmt2(_arcadeJoystickPreviousTiltRoll)} returnComp=${_fmt4(_arcadeJoystickPreviousReturnCompX)},${_fmt4(_arcadeJoystickPreviousReturnCompY)},${_fmt4(_arcadeJoystickPreviousReturnCompZ)} returnCompStrength=${_fmt2(_arcadeJoystickPreviousReturnCompStrength)}',
    );
    buffer.writeln(
      'ARCADE_JOYSTICK_HITBOX visible=$_showArcadeJoystickPressHitbox pos=${_fmt4(_arcadeJoystickPressHitboxX)},${_fmt4(_arcadeJoystickPressHitboxY)},${_fmt4(_arcadeJoystickPressHitboxZ)} size=${_fmt4(_arcadeJoystickPressHitboxSizeX)},${_fmt4(_arcadeJoystickPressHitboxSizeY)},${_fmt4(_arcadeJoystickPressHitboxSizeZ)} preview=$_arcadeJoystickPressPreview previewDirection=${_fmt2(_arcadeJoystickPreviewDirection)}',
    );
    buffer.writeln(
      'ARCADE_ENTER_BUTTON visible=$_showArcadeEnterButton pos=${_fmt4(_arcadeEnterButtonX)},${_fmt4(_arcadeEnterButtonY)},${_fmt4(_arcadeEnterButtonZ)} rot=${_fmt2(_arcadeEnterButtonRotX)},${_fmt2(_arcadeEnterButtonRotY)},${_fmt2(_arcadeEnterButtonRotZ)} scale=${_fmt4(_arcadeEnterButtonScaleX)},${_fmt4(_arcadeEnterButtonScaleY)},${_fmt4(_arcadeEnterButtonScaleZ)} press=${_fmt3(_arcadeEnterButtonPressDuration)} return=${_fmt3(_arcadeEnterButtonReturnDuration)} depth=${_fmt4(_arcadeEnterButtonPressDepth)} redColorEnabled=$_arcadeEnterButtonRedColorEnabled redRGB=${_arcadeEnterButtonRedR.round()},${_arcadeEnterButtonRedG.round()},${_arcadeEnterButtonRedB.round()} preview=$_arcadeEnterButtonPreviewPressed',
    );
    buffer.writeln(
      'ARCADE_REVEAL screen=$_revealArcadeScreen joystick=$_revealArcadeJoystick',
    );
    buffer.writeln(
      'CUTTER visible=$_showArcadeCutter pos=${_fmt4(_cutterX)},${_fmt4(_cutterY)},${_fmt4(_cutterZ)} extents=L${_fmt4(_cutterLeft)},R${_fmt4(_cutterRight)},U${_fmt4(_cutterUp)},D${_fmt4(_cutterDown)},F${_fmt4(_cutterFront)},B${_fmt4(_cutterBack)} rot=${_fmt2(_cutterPitch)},${_fmt2(_cutterYaw)},${_fmt2(_cutterRoll)}',
    );
    for (final part in _arcadeCutParts) {
      buffer.writeln(
        'CUT_PART id=${part.id} label=${part.label} visible=${part.visible} pos=${_fmt4(part.x)},${_fmt4(part.y)},${_fmt4(part.z)} rot=${_fmt2(part.rotX)},${_fmt2(part.rotY)},${_fmt2(part.rotZ)} scale=${_fmt4(part.scaleX)},${_fmt4(part.scaleY)},${_fmt4(part.scaleZ)} colorEnabled=${part.colorEnabled} colorRGB=${part.colorR.round()},${part.colorG.round()},${part.colorB.round()} glowEnabled=${part.glowEnabled} glowRGB=${part.glowR.round()},${part.glowG.round()},${part.glowB.round()} glowIntensity=${_fmt2(part.glowIntensity)} triangles=${part.triangleIds.length}',
      );
    }
    buffer.writeln(
      'CHARACTER visible=$_showCharacter pos=${_fmt4(_characterX)},${_fmt4(_characterY)},${_fmt4(_characterZ)} rot=${_fmt2(_characterRotX)},${_fmt2(_characterRotY)},${_fmt2(_characterRotZ)} scale=${_fmt4(_characterScaleX)},${_fmt4(_characterScaleY)},${_fmt4(_characterScaleZ)}',
    );
    buffer.writeln(
      'SCENE renderScale=${_fmt4(_renderScale)} exposure=${_fmt4(_sceneExposure)} lightIntensity=${_fmt4(_lightIntensity)} lightYaw=${_fmt2(_lightYawDeg)} lightPitch=${_fmt2(_lightPitchDeg)}',
    );
    buffer.writeln(
      'ARCADE highlight=$_arcadeHighlightVisible pos=${_fmt4(_arcadeX)},${_fmt4(_arcadeY)},${_fmt4(_arcadeZ)} rot=${_fmt2(_arcadeRotX)},${_fmt2(_arcadeRotY)},${_fmt2(_arcadeRotZ)} size=${_fmt4(_arcadeSizeX)},${_fmt4(_arcadeSizeY)},${_fmt4(_arcadeSizeZ)} glowThickness=${_fmt4(_arcadeGlowThickness)} glowIntensity=${_fmt4(_arcadeGlowIntensity)} glowOpacity=${_fmt4(_arcadeGlowOpacity)} glowRGB=${_arcadeGlowR.round()},${_arcadeGlowG.round()},${_arcadeGlowB.round()} transition=${_fmt4(_arcadeTransitionSeconds)}',
    );
    buffer.writeln(
      'ARCADE_GLOW topRGB=${_arcadeGlowTopR.round()},${_arcadeGlowTopG.round()},${_arcadeGlowTopB.round()} topOpacity=${_fmt4(_arcadeGlowTopOpacity)} bottomRGB=${_arcadeGlowBottomR.round()},${_arcadeGlowBottomG.round()},${_arcadeGlowBottomB.round()} bottomOpacity=${_fmt4(_arcadeGlowBottomOpacity)} midpoint=${_fmt4(_arcadeGlowBlendMidpoint)}',
    );
    buffer.writeln(
      'ARCADE_GLOW_MOTION rotate=$_arcadeGlowAutoRotate speed=${_fmt2(_arcadeGlowRotationSpeed)} direction=${_arcadeGlowRotateRight ? 'right' : 'left'} bob=$_arcadeGlowAutoBob bobAmount=${_fmt4(_arcadeGlowBobAmount)} bobSpeed=${_fmt2(_arcadeGlowBobSpeed)}',
    );
    buffer.writeln(
      'ARCADE_CAMERA position=${_fmt4(_arcadeFocusCameraX)},${_fmt4(_arcadeFocusCameraY)},${_fmt4(_arcadeFocusCameraZ)} target=${_fmt4(_arcadeFocusTargetX)},${_fmt4(_arcadeFocusTargetY)},${_fmt4(_arcadeFocusTargetZ)} fov=${_fmt2(_arcadeFocusFov)}',
    );
    for (final tuning in _poseTunings) {
      buffer.writeln(
        'BONE ${tuning.nodeName} rot=${_fmt2(tuning.rotX)},${_fmt2(tuning.rotY)},${_fmt2(tuning.rotZ)} offset=${_fmt4(tuning.offsetX)},${_fmt4(tuning.offsetY)},${_fmt4(tuning.offsetZ)}',
      );
    }

    buffer.writeln(
      'MOTION playing=$_motionPlaying loop=$_motionLoop selectedTrack=$_selectedTrackId defaultDuration=${_fmt4(_newKeyframeDuration)}',
    );
    for (final track in _motionTracks.values) {
      buffer.writeln(
        'MOTION_TRACK id=${track.id} enabled=${track.enabled} points=${track.keyframes.length}',
      );
      for (var i = 0; i < track.keyframes.length; i++) {
        final keyframe = track.keyframes[i];
        final values = keyframe.snapshot.values.entries
            .map((entry) => '${entry.key}=${_fmt4(entry.value)}')
            .join(',');
        final flags = keyframe.snapshot.flags.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join(',');
        buffer.writeln(
          'MOTION_POINT track=${track.id} index=${i + 1} duration=${_fmt4(keyframe.durationSeconds)} values=[$values] flags=[$flags]',
        );
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كل القيم الحالية')),
    );
  }

  String _fmt4(double value) => value.toStringAsFixed(4);
  String _fmt3(double value) => value.toStringAsFixed(3);
  String _fmt2(double value) => value.toStringAsFixed(2);

  void _addCurrentKeyframe() {
    final track = _motionTracks[_selectedTrackId];
    if (track == null) return;
    track.keyframes.add(
      _MotionKeyframe(
        durationSeconds: _newKeyframeDuration,
        snapshot: _captureSnapshot(track.id),
      ),
    );
    _scheduleSave();
    setState(() {});
  }

  void _clearSelectedTrack() {
    final track = _motionTracks[_selectedTrackId];
    if (track == null) return;
    track.keyframes.clear();
    _motionPlaying = false;
    _motionClock = 0;
    _scheduleSave();
    setState(() {});
  }

  void _toggleMotionPlayback() {
    final hasAny = _motionTracks.values.any(
      (track) => track.enabled && track.keyframes.isNotEmpty,
    );
    if (!hasAny) return;
    setState(() {
      if (_motionPlaying) {
        _motionPlaying = false;
      } else {
        _motionClock = 0;
        _motionPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 18),
              Text(
                'جاري تجهيز واجهة الماب الجديدة…',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذر تحميل واجهة الماب الجديدة.',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error.toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        mundasRoute(const HomeScreen()),
                      ),
                      icon: const Icon(Icons.apps_rounded),
                      label: const Text('فتح الواجهة القديمة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            Positioned.fill(child: _buildScene()),
            if (!_userModeActive && !_uiPreviewOnly && _showGuide) _buildGuideCard(),
            if (!_userModeActive && !_uiPreviewOnly && _developerPanelOpen) _buildDeveloperPanel(),
            if (!_userModeActive && !_uiPreviewOnly && _motionPanelOpen) _buildMotionPanel(),
            if (_uiPreviewOnly)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'وضع المعاينة فقط • Caps Lock للرجوع',
                    style: TextStyle(color: Colors.white, fontSize: 12.3),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _uiPreviewOnly
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'games_button',
                  backgroundColor: Colors.white,
                  foregroundColor: MundasColors.ink,
                  onPressed: () => Navigator.push(
                    context,
                    mundasRoute(const HomeScreen()),
                  ),
                  child: const Icon(Icons.apps_rounded),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'motion_panel_button',
                  tooltip: _motionPanelOpen ? 'إخفاء نافذة الحركة' : 'نافذة الحركة',
                  backgroundColor: _motionPanelOpen
                      ? const Color(0xFF7A4BC2)
                      : const Color(0xFF1E2332),
                  foregroundColor: Colors.white,
                  onPressed: () {
                    if (_userModeActive) {
                      _exitUserMode();
                      setState(() {
                        _developerPanelOpen = false;
                        _motionPanelOpen = true;
                      });
                      return;
                    }
                    setState(() {
                      _motionPanelOpen = !_motionPanelOpen;
                    });
                  },
                  child: const Icon(Icons.animation_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'developer_button',
                  tooltip: _developerPanelOpen ? 'إخفاء المطور' : 'مختبر المطور',
                  backgroundColor: _developerPanelOpen
                      ? const Color(0xFFE5A93A)
                      : const Color(0xFF1E2332),
                  foregroundColor: _developerPanelOpen
                      ? const Color(0xFF151925)
                      : Colors.white,
                  onPressed: () {
                    if (_userModeActive) {
                      _exitUserMode();
                      setState(() {
                        _developerPanelOpen = true;
                        _motionPanelOpen = false;
                      });
                      return;
                    }
                    setState(() {
                      _developerPanelOpen = !_developerPanelOpen;
                    });
                  },
                  child: const Icon(Icons.tune_rounded, size: 20),
                ),
              ],
            ),
    );
  }

  Widget _buildScene() {
    return Listener(
      onPointerDown: (_) {
        _keyboardFocusNode.requestFocus();
        if (!(_userModeActive && _arcadeFocusLocked)) {
          _registerUserCameraInteraction();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _handleScenePanStart,
        onPanUpdate: _handleScenePanUpdate,
        onPanEnd: _handleScenePanEnd,
        onTapUp: _handleSceneTap,
        onSecondaryTapUp: _handleSceneSecondaryTap,
        child: SceneView(
          _scene,
          autoTick: true,
          warmUp: true,
          cameraBuilder: (_) => _currentCamera(),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Positioned(
      left: 16,
      right: 16,
      top: 16,
      child: IgnorePointer(
        ignoring: _developerPanelOpen,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xCC111726),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.14)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الواجهة الجديدة شغّالة ✅',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'اسحب داخل المشهد لتغيير اتجاه النظر. الأسهم لتحريك الكاميرا، Ctrl + الأسهم لرفع/خفض وتحريك أدق، و Caps Lock يخفي كل الواجهات. الآن تقدر أيضًا تصنع نقاط حركة ديناميكية للكاميرا والماب والشخصية وحتى كل عظم.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.8, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeveloperPanel() {
    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width * .92, 500.0).toDouble(),
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xF4111726),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.35),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مختبر المطور',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'اختر القسم المطلوب فقط؛ ماكو بعد قائمة طويلة ومتشابكة.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.3,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إخفاء',
                      onPressed: () => setState(() => _developerPanelOpen = false),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x2FFFFFFF)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _buildDeveloperSectionButtons(),
              ),
              const Divider(height: 1, color: Color(0x2FFFFFFF)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  children: [
                    _buildSelectedDeveloperSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeveloperSectionButtons() {
    const sections = <({
      String id,
      String label,
      IconData icon,
      Color color,
    })>[
      (
        id: 'map',
        label: 'الماب',
        icon: Icons.map_rounded,
        color: Color(0xFFB7791F),
      ),
      (
        id: 'tv',
        label: 'تلفزيون الاختبار',
        icon: Icons.tv_rounded,
        color: Color(0xFFCC6B22),
      ),
      (
        id: 'camera',
        label: 'الكاميرا',
        icon: Icons.videocam_rounded,
        color: Color(0xFF2563A8),
      ),
      (
        id: 'character',
        label: 'الجسم',
        icon: Icons.accessibility_new_rounded,
        color: Color(0xFF14836A),
      ),
      (
        id: 'head',
        label: 'الرأس',
        icon: Icons.face_rounded,
        color: Color(0xFF7A4BC2),
      ),
      (
        id: 'torso',
        label: 'الجذع',
        icon: Icons.man_rounded,
        color: Color(0xFFB14C68),
      ),
      (
        id: 'arms',
        label: 'الأيادي',
        icon: Icons.back_hand_rounded,
        color: Color(0xFFB85C2B),
      ),
      (
        id: 'legs',
        label: 'الأرجل',
        icon: Icons.directions_walk_rounded,
        color: Color(0xFF3F6F8F),
      ),
      (
        id: 'arcade',
        label: 'الآركيد',
        icon: Icons.sports_esports_rounded,
        color: Color(0xFF168CB8),
      ),
      (
        id: 'arcade_parts',
        label: 'الشاشة والمقبض',
        icon: Icons.gamepad_rounded,
        color: Color(0xFF8B5CF6),
      ),
      (
        id: 'cutter',
        label: 'القص',
        icon: Icons.content_cut_rounded,
        color: Color(0xFFB94A72),
      ),
      (
        id: 'scene',
        label: 'المشهد',
        icon: Icons.light_mode_rounded,
        color: Color(0xFF677A32),
      ),
      (
        id: 'values',
        label: 'القيم',
        icon: Icons.data_object_rounded,
        color: Color(0xFF4B556D),
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final section in sections)
          Builder(
            builder: (context) {
              final selected = _developerSection == section.id;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _developerSection = section.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(
                      minWidth: 96,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? section.color
                          : section.color.withOpacity(.62),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFFD46A)
                            : Colors.white.withOpacity(.20),
                        width: selected ? 2.2 : 1.0,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: section.color.withOpacity(.38),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : const [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          section.icon,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          section.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSelectedDeveloperSection() {
    switch (_developerSection) {
      case 'tv':
        return _buildTvDeveloperSection();
      case 'camera':
        return _buildCameraSection();
      case 'character':
        return _buildCharacterDeveloperSection();
      case 'head':
        return _buildPoseGroupSection(
          title: 'الرأس والرقبة',
          subtitle: 'تحكم منفصل بالرقبة والرأس: دوران وإزاحة لكل جزء.',
          nodeNames: const ['Neck', 'Head'],
        );
      case 'torso':
        return _buildPoseGroupSection(
          title: 'الجذع',
          subtitle: 'الحوض والعمود الفقري السفلي والعلوي.',
          nodeNames: const ['Hips', 'Spine', 'Spine1'],
        );
      case 'arms':
        return _buildPoseGroupSection(
          title: 'الأكتاف والأذرع والأيادي',
          subtitle: 'كل كتف وذراع وساعد ويد بشكل مستقل لليمين واليسار.',
          nodeNames: const [
            'LeftShoulder',
            'LeftArm',
            'LeftForeArm',
            'LeftHand',
            'RightShoulder',
            'RightArm',
            'RightForeArm',
            'RightHand',
          ],
        );
      case 'legs':
        return _buildPoseGroupSection(
          title: 'الأرجل',
          subtitle: 'الفخذ والساق والقدم لكل جهة بشكل مستقل.',
          nodeNames: const [
            'LeftUpLeg',
            'LeftLeg',
            'LeftFoot',
            'RightUpLeg',
            'RightLeg',
            'RightFoot',
          ],
        );
      case 'arcade':
        return _buildArcadeDeveloperSection();
      case 'arcade_parts':
        return _buildArcadePartsDeveloperSection();
      case 'cutter':
        return _buildArcadeCutterDeveloperSection();
      case 'scene':
        return _buildSceneDeveloperSection();
      case 'values':
        return _buildValuesDeveloperSection();
      case 'map':
      default:
        return _buildMapDeveloperSection();
    }
  }

  Widget _buildMapDeveloperSection() {
    return _buildTransformSection(
      title: 'قسم الماب',
      subtitle: 'كل ما يخص الماب فقط: إظهار، موضع، دوران، وحجم.',
      controls: [
        _buildSwitchRow(
          label: 'إظهار الماب',
          value: _showRoom,
          onChanged: (value) {
            setState(() => _showRoom = value);
            _applyAllTransforms();
          },
        ),
        _tripleControl(
          prefix: 'موضع الماب',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -10,
          max: 10,
          step: .02,
          x: _roomX,
          y: _roomY,
          z: _roomZ,
          onX: (v) => _roomX = v,
          onY: (v) => _roomY = v,
          onZ: (v) => _roomZ = v,
        ),
        _tripleControl(
          prefix: 'دوران الماب',
          xLabel: 'Pitch',
          yLabel: 'Yaw',
          zLabel: 'Roll',
          min: -180,
          max: 180,
          step: 1,
          x: _roomRotX,
          y: _roomRotY,
          z: _roomRotZ,
          onX: (v) => _roomRotX = v,
          onY: (v) => _roomRotY = v,
          onZ: (v) => _roomRotZ = v,
        ),
        _tripleControl(
          prefix: 'حجم الماب',
          xLabel: 'Scale X',
          yLabel: 'Scale Y',
          zLabel: 'Scale Z',
          min: .01,
          max: 2.5,
          step: .01,
          x: _roomScaleX,
          y: _roomScaleY,
          z: _roomScaleZ,
          onX: (v) => _roomScaleX = v,
          onY: (v) => _roomScaleY = v,
          onZ: (v) => _roomScaleZ = v,
        ),
      ],
    );
  }



  Widget _buildTvDeveloperSection() {
    return _buildTransformSection(
      title: 'تلفزيون اللعبة',
      subtitle:
          'اضبط المكان النهائي، كاميرا الانتقال، بداية دخول التلفزيون، الدوران أثناء الطيران والحركة الديناميكية بعد الاستقرار.',
      controls: [
        _buildSwitchRow(
          label: 'إظهار التلفزيون',
          value: _showTv,
          onChanged: (value) {
            setState(() => _showTv = value);
            _applyTvTransform();
            _scheduleSave();
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'المكان النهائي للتلفزيون',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        _tripleControl(
          prefix: 'موضع نهائي',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -20,
          max: 20,
          step: .01,
          x: _tvX,
          y: _tvY,
          z: _tvZ,
          onX: (v) => _tvX = v,
          onY: (v) => _tvY = v,
          onZ: (v) => _tvZ = v,
        ),
        _tripleControl(
          prefix: 'دوران نهائي',
          xLabel: 'Pitch',
          yLabel: 'Yaw',
          zLabel: 'Roll',
          min: -180,
          max: 180,
          step: 1,
          x: _tvRotX,
          y: _tvRotY,
          z: _tvRotZ,
          onX: (v) => _tvRotX = v,
          onY: (v) => _tvRotY = v,
          onZ: (v) => _tvRotZ = v,
        ),
        _tripleControl(
          prefix: 'حجم نهائي',
          xLabel: 'Scale X',
          yLabel: 'Scale Y',
          zLabel: 'Scale Z',
          min: .01,
          max: 10,
          step: .01,
          x: _tvScaleX,
          y: _tvScaleY,
          z: _tvScaleZ,
          onX: (v) => _tvScaleX = v,
          onY: (v) => _tvScaleY = v,
          onZ: (v) => _tvScaleZ = v,
        ),

        const Divider(height: 30, color: Color(0x2FFFFFFF)),
        const Text(
          'كاميرا شاشة التلفزيون',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        _tripleControl(
          prefix: 'موضع الكاميرا',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -20,
          max: 20,
          step: .01,
          x: _tvCameraX,
          y: _tvCameraY,
          z: _tvCameraZ,
          onX: (v) {
            _tvCameraX = v;
            _applyTvCameraPreviewNow();
          },
          onY: (v) {
            _tvCameraY = v;
            _applyTvCameraPreviewNow();
          },
          onZ: (v) {
            _tvCameraZ = v;
            _applyTvCameraPreviewNow();
          },
        ),
        _tripleControl(
          prefix: 'هدف الكاميرا',
          xLabel: 'Target X',
          yLabel: 'Target Y',
          zLabel: 'Target Z',
          min: -20,
          max: 20,
          step: .01,
          x: _tvCameraTargetX,
          y: _tvCameraTargetY,
          z: _tvCameraTargetZ,
          onX: (v) {
            _tvCameraTargetX = v;
            _applyTvCameraPreviewNow();
          },
          onY: (v) {
            _tvCameraTargetY = v;
            _applyTvCameraPreviewNow();
          },
          onZ: (v) {
            _tvCameraTargetZ = v;
            _applyTvCameraPreviewNow();
          },
        ),
        _numberControl(
          label: 'FOV كاميرا التلفزيون',
          value: _tvCameraFov,
          min: 15,
          max: 100,
          step: 1,
          onChanged: (v) => setState(() {
            _tvCameraFov = v;
            _applyTvCameraPreviewNow();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'مدة انتقال الكاميرا',
          value: _tvCameraDuration,
          min: .10,
          max: 8,
          step: .05,
          onChanged: (v) => setState(() {
            _tvCameraDuration = v;
            _scheduleSave();
          }),
        ),
        _buildSwitchRow(
          label: 'معاينة فورية لتعديلات الكاميرا',
          value: _tvCameraLivePreview,
          onChanged: (value) {
            setState(() => _tvCameraLivePreview = value);
            if (value) _applyTvCameraPreviewNow();
            _scheduleSave();
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'حدود النظر في وضع التلفزيون',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        _numberControl(
          label: 'حد النظر يسار',
          value: _tvLookLeftDeg,
          min: 0,
          max: 89,
          step: .5,
          onChanged: (v) => setState(() {
            _tvLookLeftDeg = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'حد النظر يمين',
          value: _tvLookRightDeg,
          min: 0,
          max: 89,
          step: .5,
          onChanged: (v) => setState(() {
            _tvLookRightDeg = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'حد النظر أعلى',
          value: _tvLookUpDeg,
          min: 0,
          max: 89,
          step: .5,
          onChanged: (v) => setState(() {
            _tvLookUpDeg = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'حد النظر أسفل',
          value: _tvLookDownDeg,
          min: 0,
          max: 89,
          step: .5,
          onChanged: (v) => setState(() {
            _tvLookDownDeg = v;
            _scheduleSave();
          }),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _cameraX = _tvCameraX;
                _cameraY = _tvCameraY;
                _cameraZ = _tvCameraZ;
                _targetX = _tvCameraTargetX;
                _targetY = _tvCameraTargetY;
                _targetZ = _tvCameraTargetZ;
                _cameraFov = _tvCameraFov;
              });
              _syncCameraAnglesFromCurrentView();
              _applyAllTransforms(save: false, repaint: false);
            },
            icon: const Icon(Icons.videocam_rounded),
            label: const Text('معاينة كاميرا التلفزيون فورًا'),
          ),
        ),

        const Divider(height: 30, color: Color(0x2FFFFFFF)),
        const Text(
          'بداية دخول التلفزيون',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        _tripleControl(
          prefix: 'موضع البداية',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -30,
          max: 30,
          step: .05,
          x: _tvEntryStartX,
          y: _tvEntryStartY,
          z: _tvEntryStartZ,
          onX: (v) => _tvEntryStartX = v,
          onY: (v) => _tvEntryStartY = v,
          onZ: (v) => _tvEntryStartZ = v,
        ),
        _tripleControl(
          prefix: 'دوران البداية',
          xLabel: 'Pitch',
          yLabel: 'Yaw',
          zLabel: 'Roll',
          min: -360,
          max: 360,
          step: 1,
          x: _tvEntryStartRotX,
          y: _tvEntryStartRotY,
          z: _tvEntryStartRotZ,
          onX: (v) => _tvEntryStartRotX = v,
          onY: (v) => _tvEntryStartRotY = v,
          onZ: (v) => _tvEntryStartRotZ = v,
        ),
        _tripleControl(
          prefix: 'حجم البداية',
          xLabel: 'Scale X',
          yLabel: 'Scale Y',
          zLabel: 'Scale Z',
          min: .01,
          max: 10,
          step: .01,
          x: _tvEntryStartScaleX,
          y: _tvEntryStartScaleY,
          z: _tvEntryStartScaleZ,
          onX: (v) => _tvEntryStartScaleX = v,
          onY: (v) => _tvEntryStartScaleY = v,
          onZ: (v) => _tvEntryStartScaleZ = v,
        ),
        _tripleControl(
          prefix: 'لفات أثناء الدخول',
          xLabel: 'X turns',
          yLabel: 'Y turns',
          zLabel: 'Z turns',
          min: -5,
          max: 5,
          step: 1,
          x: _tvEntrySpinXTurns,
          y: _tvEntrySpinYTurns,
          z: _tvEntrySpinZTurns,
          onX: (v) => _tvEntrySpinXTurns = v,
          onY: (v) => _tvEntrySpinYTurns = v,
          onZ: (v) => _tvEntrySpinZTurns = v,
        ),
        _numberControl(
          label: 'مدة وصول التلفزيون',
          value: _tvEntryDuration,
          min: .10,
          max: 8,
          step: .05,
          onChanged: (v) => setState(() {
            _tvEntryDuration = v;
            _scheduleSave();
          }),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (_tvTransitionAnimating) return;
              _startTvGameTransition(_arcadeSelectedGameIndex);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('تجربة الانتقال من المكان الحالي'),
          ),
        ),

        const Divider(height: 30, color: Color(0x2FFFFFFF)),
        const Text(
          'الحركة الديناميكية بعد الاستقرار',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        _buildSwitchRow(
          label: 'تشغيل الحركة الديناميكية',
          value: _tvIdleMotionEnabled,
          onChanged: (value) {
            setState(() {
              _tvIdleMotionEnabled = value;
              _tvIdleClock = 0;
            });
            _applyTvTransform();
            _scheduleSave();
          },
        ),
        _tripleControl(
          prefix: 'حركة مستمرة',
          xLabel: 'يمين/يسار X',
          yLabel: 'أعلى/أسفل Y',
          zLabel: 'أمام/خلف Z',
          min: 0,
          max: 2,
          step: .005,
          x: _tvIdleMoveX,
          y: _tvIdleMoveY,
          z: _tvIdleMoveZ,
          onX: (v) => _tvIdleMoveX = v,
          onY: (v) => _tvIdleMoveY = v,
          onZ: (v) => _tvIdleMoveZ = v,
        ),
        _tripleControl(
          prefix: 'تمايل الدوران',
          xLabel: 'Pitch',
          yLabel: 'Yaw',
          zLabel: 'Roll',
          min: 0,
          max: 25,
          step: .1,
          x: _tvIdleRotX,
          y: _tvIdleRotY,
          z: _tvIdleRotZ,
          onX: (v) => _tvIdleRotX = v,
          onY: (v) => _tvIdleRotY = v,
          onZ: (v) => _tvIdleRotZ = v,
        ),
        _numberControl(
          label: 'زمن الدورة الكاملة للحركة',
          value: _tvIdleCycleSeconds,
          min: .20,
          max: 20,
          step: .10,
          onChanged: (v) => setState(() {
            _tvIdleCycleSeconds = v;
            _scheduleSave();
          }),
        ),

        const Divider(height: 30, color: Color(0x2FFFFFFF)),
        const Text(
          'تصميم شاشة اللعبة داخل التلفزيون',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchRow(
          label: 'معاينة نافذة التفاصيل',
          value: _tvDetailsVisible,
          onChanged: (value) {
            setState(() => _tvDetailsVisible = value);
            unawaited(_refreshTvGameScreen());
            _scheduleSave();
          },
        ),
        _screenElementLayoutControl(
          title: 'اسم اللعبة',
          x: _tvUiTitleOffsetX,
          y: _tvUiTitleOffsetY,
          scale: _tvUiTitleScale,
          onX: (v) {
            _tvUiTitleOffsetX = v;
            unawaited(_refreshTvGameScreen());
          },
          onY: (v) {
            _tvUiTitleOffsetY = v;
            unawaited(_refreshTvGameScreen());
          },
          onScale: (v) {
            _tvUiTitleScale = v;
            unawaited(_refreshTvGameScreen());
          },
        ),
        _screenElementLayoutControl(
          title: 'أزرار أوف لاين / أون لاين',
          x: _tvUiButtonsOffsetX,
          y: _tvUiButtonsOffsetY,
          scale: _tvUiButtonsScale,
          onX: (v) {
            _tvUiButtonsOffsetX = v;
            unawaited(_refreshTvGameScreen());
          },
          onY: (v) {
            _tvUiButtonsOffsetY = v;
            unawaited(_refreshTvGameScreen());
          },
          onScale: (v) {
            _tvUiButtonsScale = v;
            unawaited(_refreshTvGameScreen());
          },
        ),
        _numberControl(
          label: 'تباعد زري اللعب',
          value: _tvUiButtonsGap,
          min: .3,
          max: 4,
          step: .05,
          onChanged: (v) {
            setState(() => _tvUiButtonsGap = v);
            unawaited(_refreshTvGameScreen());
            _scheduleSave();
          },
        ),
        _screenElementLayoutControl(
          title: 'زر !',
          x: _tvUiInfoOffsetX,
          y: _tvUiInfoOffsetY,
          scale: _tvUiInfoScale,
          onX: (v) {
            _tvUiInfoOffsetX = v;
            unawaited(_refreshTvGameScreen());
          },
          onY: (v) {
            _tvUiInfoOffsetY = v;
            unawaited(_refreshTvGameScreen());
          },
          onScale: (v) {
            _tvUiInfoScale = v;
            unawaited(_refreshTvGameScreen());
          },
        ),
        _screenElementLayoutControl(
          title: 'نافذة التفاصيل',
          x: _tvUiPanelOffsetX,
          y: _tvUiPanelOffsetY,
          scale: _tvUiPanelScale,
          onX: (v) {
            _tvUiPanelOffsetX = v;
            unawaited(_refreshTvGameScreen());
          },
          onY: (v) {
            _tvUiPanelOffsetY = v;
            unawaited(_refreshTvGameScreen());
          },
          onScale: (v) {
            _tvUiPanelScale = v;
            unawaited(_refreshTvGameScreen());
          },
        ),
        _numberControl(
          label: 'استدارة الأزرار',
          value: _tvUiButtonRadius,
          min: .4,
          max: 2.5,
          step: .05,
          onChanged: (v) {
            setState(() => _tvUiButtonRadius = v);
            unawaited(_refreshTvGameScreen());
            _scheduleSave();
          },
        ),
        _numberControl(
          label: 'سماكة إطار الأزرار',
          value: _tvUiButtonStroke,
          min: .4,
          max: 3,
          step: .05,
          onChanged: (v) {
            setState(() => _tvUiButtonStroke = v);
            unawaited(_refreshTvGameScreen());
            _scheduleSave();
          },
        ),
        _colorGroup(
          title: 'خلفية شاشة اللعبة',
          r: _tvUiBgR,
          g: _tvUiBgG,
          b: _tvUiBgB,
          onR: (v) {
            setState(() => _tvUiBgR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiBgG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiBgB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون التحديد الرئيسي',
          r: _tvUiAccentR,
          g: _tvUiAccentG,
          b: _tvUiAccentB,
          onR: (v) {
            setState(() => _tvUiAccentR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiAccentG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiAccentB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون اسم اللعبة',
          r: _tvUiTitleR,
          g: _tvUiTitleG,
          b: _tvUiTitleB,
          onR: (v) {
            setState(() => _tvUiTitleR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiTitleG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiTitleB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون أوف لاين',
          r: _tvUiOfflineR,
          g: _tvUiOfflineG,
          b: _tvUiOfflineB,
          onR: (v) {
            setState(() => _tvUiOfflineR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiOfflineG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiOfflineB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون أون لاين',
          r: _tvUiOnlineR,
          g: _tvUiOnlineG,
          b: _tvUiOnlineB,
          onR: (v) {
            setState(() => _tvUiOnlineR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiOnlineG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiOnlineB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون زر !',
          r: _tvUiInfoR,
          g: _tvUiInfoG,
          b: _tvUiInfoB,
          onR: (v) {
            setState(() => _tvUiInfoR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiInfoG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiInfoB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون الزر غير المتوفر',
          r: _tvUiDisabledR,
          g: _tvUiDisabledG,
          b: _tvUiDisabledB,
          onR: (v) {
            setState(() => _tvUiDisabledR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiDisabledG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiDisabledB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون النص',
          r: _tvUiTextR,
          g: _tvUiTextG,
          b: _tvUiTextB,
          onR: (v) {
            setState(() => _tvUiTextR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiTextG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiTextB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),
        _colorGroup(
          title: 'لون نافذة التفاصيل',
          r: _tvUiPanelR,
          g: _tvUiPanelG,
          b: _tvUiPanelB,
          onR: (v) {
            setState(() => _tvUiPanelR = v);
            unawaited(_refreshTvGameScreen());
          },
          onG: (v) {
            setState(() => _tvUiPanelG = v);
            unawaited(_refreshTvGameScreen());
          },
          onB: (v) {
            setState(() => _tvUiPanelB = v);
            unawaited(_refreshTvGameScreen());
          },
        ),

        const Divider(height: 30, color: Color(0x2FFFFFFF)),
        const Text(
          'الشاشة المقصوصة TVScreen',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'مثبتة داخل مجسم التلفزيون: الموضع 0,0,0 — الدوران 0 — الحجم 1,1,1. تحريك عناصر الواجهة يتم من إعدادات التصميم أعلاه فقط.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        _buildSwitchRow(
          label: 'إظهار الشاشة المقصوصة',
          value: _showTvScreen,
          onChanged: (value) {
            setState(() => _showTvScreen = value);
            _applyTvTransform();
            _scheduleSave();
          },
        ),
        _buildSwitchRow(
          label: 'تحديد الشاشة المقصوصة بالأحمر',
          value: _tvScreenHighlight,
          onChanged: (value) {
            setState(() => _tvScreenHighlight = value);
            _applyTvTransform();
            _scheduleSave();
          },
        ),
      ],
    );
  }


  Widget _buildArcadeCutterDeveloperSection() {
    final selectedPart = _selectedArcadeCutPart;

    Widget partEditor(_ArcadeCutPart part) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwitchRow(
            label: 'إظهار ${part.label}',
            value: part.visible,
            onChanged: (value) {
              setState(() => part.visible = value);
              _applyArcadeCutPartTransform(part);
            },
          ),
          _tripleControl(
            prefix: 'موضع ${part.label}',
            xLabel: 'X',
            yLabel: 'Y',
            zLabel: 'Z',
            min: -20,
            max: 20,
            step: .01,
            x: part.x,
            y: part.y,
            z: part.z,
            onX: (v) => part.x = v,
            onY: (v) => part.y = v,
            onZ: (v) => part.z = v,
          ),
          _tripleControl(
            prefix: 'دوران ${part.label}',
            xLabel: 'رأسي',
            yLabel: 'أفقي',
            zLabel: 'Roll',
            min: -180,
            max: 180,
            step: 1,
            x: part.rotX,
            y: part.rotY,
            z: part.rotZ,
            onX: (v) => part.rotX = v,
            onY: (v) => part.rotY = v,
            onZ: (v) => part.rotZ = v,
          ),
          _tripleControl(
            prefix: 'حجم ${part.label}',
            xLabel: 'X',
            yLabel: 'Y',
            zLabel: 'Z',
            min: .01,
            max: 8,
            step: .01,
            x: part.scaleX,
            y: part.scaleY,
            z: part.scaleZ,
            onX: (v) => part.scaleX = v,
            onY: (v) => part.scaleY = v,
            onZ: (v) => part.scaleZ = v,
          ),
          const Divider(height: 26, color: Color(0x2FFFFFFF)),
          _buildSwitchRow(
            label: 'إضافة لون مخصص',
            value: part.colorEnabled,
            onChanged: (value) {
              setState(() => part.colorEnabled = value);
              _applyArcadeCutPartTransform(part);
            },
          ),
          if (part.colorEnabled) ...[
            _numberControl(
              label: 'اللون R',
              value: part.colorR,
              min: 0,
              max: 255,
              step: 1,
              onChanged: (v) {
                setState(() => part.colorR = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
            _numberControl(
              label: 'اللون G',
              value: part.colorG,
              min: 0,
              max: 255,
              step: 1,
              onChanged: (v) {
                setState(() => part.colorG = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
            _numberControl(
              label: 'اللون B',
              value: part.colorB,
              min: 0,
              max: 255,
              step: 1,
              onChanged: (v) {
                setState(() => part.colorB = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
            _numberControl(
              label: 'شفافية اللون',
              value: part.colorOpacity,
              min: 0,
              max: 1,
              step: .05,
              onChanged: (v) {
                setState(() => part.colorOpacity = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
          ],
          const Divider(height: 26, color: Color(0x2FFFFFFF)),
          _buildSwitchRow(
            label: 'توهج / تحديد',
            value: part.glowEnabled,
            onChanged: (value) {
              setState(() => part.glowEnabled = value);
              _applyArcadeCutPartTransform(part);
            },
          ),
          if (part.glowEnabled) ...[
            _numberControl(
              label: 'شدة التوهج',
              value: part.glowIntensity,
              min: 0,
              max: 1,
              step: .05,
              onChanged: (v) {
                setState(() => part.glowIntensity = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
            _numberControl(
              label: 'Glow R',
              value: part.glowR,
              min: 0,
              max: 255,
              step: 1,
              onChanged: (v) {
                setState(() => part.glowR = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
            _numberControl(
              label: 'Glow G',
              value: part.glowG,
              min: 0,
              max: 255,
              step: 1,
              onChanged: (v) {
                setState(() => part.glowG = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
            _numberControl(
              label: 'Glow B',
              value: part.glowB,
              min: 0,
              max: 255,
              step: 1,
              onChanged: (v) {
                setState(() => part.glowB = v);
                _applyArcadeCutPartTransform(part);
              },
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleteSelectedArcadeCutPart,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('حذف ${part.label}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF8E8E),
              ),
            ),
          ),
        ],
      );
    }

    return _buildTransformSection(
      title: 'أداة القص الحر',
      subtitle:
          'حرك مكعب القص وحدد حجمه من كل جهة بشكل مستقل، ثم اضغط قص. المثلثات الموجودة داخل المكعب تنتقل إلى عنصر مستقل باسم مقصوص 1، مقصوص 2...',
      controls: [
        if (_arcadeCutSourceData == null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x33C2410C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66FB923C)),
            ),
            child: const Text(
              'تعذر قراءة هندسة مجسم الآركيد. تأكد أن arcade_room.glb يعمل مع flutter_scene الحالي.',
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        _buildSwitchRow(
          label: 'إظهار مكعب القص',
          value: _showArcadeCutter,
          onChanged: (value) {
            setState(() => _showArcadeCutter = value);
            _updateArcadeCutterVisual();
            _scheduleSave();
          },
        ),
        _tripleControl(
          prefix: 'موضع مركز القص',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -60,
          max: 60,
          step: .05,
          x: _cutterX,
          y: _cutterY,
          z: _cutterZ,
          onX: (v) => _cutterX = v,
          onY: (v) => _cutterY = v,
          onZ: (v) => _cutterZ = v,
        ),
        _numberControl(
          label: 'الحجم من اليسار',
          value: _cutterLeft,
          min: .01,
          max: 60,
          step: .05,
          onChanged: (v) => setState(() {
            _cutterLeft = math.max(.01, v);
            _updateArcadeCutterVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'الحجم من اليمين',
          value: _cutterRight,
          min: .01,
          max: 60,
          step: .05,
          onChanged: (v) => setState(() {
            _cutterRight = math.max(.01, v);
            _updateArcadeCutterVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'الحجم من الأعلى',
          value: _cutterUp,
          min: .01,
          max: 60,
          step: .05,
          onChanged: (v) => setState(() {
            _cutterUp = math.max(.01, v);
            _updateArcadeCutterVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'الحجم من الأسفل',
          value: _cutterDown,
          min: .01,
          max: 60,
          step: .05,
          onChanged: (v) => setState(() {
            _cutterDown = math.max(.01, v);
            _updateArcadeCutterVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'الحجم للأمام',
          value: _cutterFront,
          min: .01,
          max: 60,
          step: .05,
          onChanged: (v) => setState(() {
            _cutterFront = math.max(.01, v);
            _updateArcadeCutterVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'الحجم للخلف',
          value: _cutterBack,
          min: .01,
          max: 60,
          step: .05,
          onChanged: (v) => setState(() {
            _cutterBack = math.max(.01, v);
            _updateArcadeCutterVisual();
            _scheduleSave();
          }),
        ),
        _tripleControl(
          prefix: 'دوران مكعب القص',
          xLabel: 'رأسي',
          yLabel: 'أفقي',
          zLabel: 'Roll',
          min: -180,
          max: 180,
          step: 1,
          x: _cutterPitch,
          y: _cutterYaw,
          z: _cutterRoll,
          onX: (v) => _cutterPitch = v,
          onY: (v) => _cutterYaw = v,
          onZ: (v) => _cutterRoll = v,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _arcadeCutSourceData == null
                ? null
                : _copyArcadePreCutSelectionData,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('نسخ بيانات التحديد الحالي قبل القص'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7CE7FF),
              side: const BorderSide(color: Color(0x807CE7FF)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _arcadeCutSourceData == null ? null : _performArcadeCut,
            icon: const Icon(Icons.content_cut_rounded),
            label: const Text('قص الجزء داخل المكعب'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB94A72),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_arcadeCutParts.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportArcadeCutParts,
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('تصدير المقصوصات الحالية ونسخها'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8FE8FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const Divider(height: 30, color: Color(0x2FFFFFFF)),
          const Text(
            'الأجزاء المقصوصة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final part in _arcadeCutParts)
                ChoiceChip(
                  label: Text(part.label),
                  selected: _selectedArcadeCutPartId == part.id,
                  onSelected: (_) {
                    setState(() => _selectedArcadeCutPartId = part.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedPart != null) partEditor(selectedPart),
        ],
      ],
    );
  }

  Widget _buildArcadePartsDeveloperSection() {
    Widget partControls({
      required String title,
      required bool visible,
      required ValueChanged<bool> onVisible,
      required double x,
      required double y,
      required double z,
      required double rotX,
      required double rotY,
      required double rotZ,
      required double scaleX,
      required double scaleY,
      required double scaleZ,
      required ValueChanged<double> onX,
      required ValueChanged<double> onY,
      required ValueChanged<double> onZ,
      required ValueChanged<double> onRotX,
      required ValueChanged<double> onRotY,
      required ValueChanged<double> onRotZ,
      required ValueChanged<double> onScaleX,
      required ValueChanged<double> onScaleY,
      required ValueChanged<double> onScaleZ,
      required VoidCallback onReset,
      List<Widget> extraControls = const <Widget>[],
      double positionMin = -10,
      double positionMax = 10,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _buildSwitchRow(
              label: 'إظهار $title',
              value: visible,
              onChanged: (value) {
                onVisible(value);
                _applyAllTransforms();
              },
            ),
            _tripleControl(
              prefix: 'موضع $title',
              xLabel: 'X',
              yLabel: 'Y',
              zLabel: 'Z',
              min: positionMin,
              max: positionMax,
              step: .01,
              x: x,
              y: y,
              z: z,
              onX: onX,
              onY: onY,
              onZ: onZ,
            ),
            _tripleControl(
              prefix: 'دوران $title',
              xLabel: 'Pitch',
              yLabel: 'Yaw',
              zLabel: 'Roll',
              min: -180,
              max: 180,
              step: 1,
              x: rotX,
              y: rotY,
              z: rotZ,
              onX: onRotX,
              onY: onRotY,
              onZ: onRotZ,
            ),
            _tripleControl(
              prefix: 'حجم $title',
              xLabel: 'Scale X',
              yLabel: 'Scale Y',
              zLabel: 'Scale Z',
              min: .01,
              max: 5,
              step: .01,
              x: scaleX,
              y: scaleY,
              z: scaleZ,
              onX: onScaleX,
              onY: onScaleY,
              onZ: onScaleZ,
            ),
            if (extraControls.isNotEmpty) ...[
              const Divider(height: 24, color: Color(0x2FFFFFFF)),
              ...extraControls,
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text('إرجاع $title للوضع الأصلي'),
              ),
            ),
          ],
        ),
      );
    }

    return _buildTransformSection(
      title: 'الشاشة والمقبض الأصليان',
      subtitle:
          'تحكم مباشر بنفس ArcadeScreen و ArcadeJoystick المفصولين من المجسم الأصلي. القيم هنا محلية داخل ماكينة الآركيد، لذلك تحريك الماب أو تدويره يبقيهما مرتبطين به.',
      controls: [
        if (_arcadeScreenNode == null || _arcadeJoystickNode == null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x33C2410C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66FB923C)),
            ),
            child: const Text(
              'تنبيه: لازم تستخدم arcade_room.glb المفصول الذي يحتوي ArcadeScreen و ArcadeJoystick.',
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'كشف المكان',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _buildSwitchRow(
                label: 'إظهار كشف مكان الشاشة الحالية',
                value: _revealArcadeScreen,
                onChanged: (value) {
                  setState(() => _revealArcadeScreen = value);
                  _applyAllTransforms();
                },
              ),
              _buildSwitchRow(
                label: 'إظهار كشف مكان المقبض الحالي',
                value: _revealArcadeJoystick,
                onChanged: (value) {
                  setState(() => _revealArcadeJoystick = value);
                  _applyAllTransforms();
                },
              ),
              const SizedBox(height: 4),
              Text(
                'يعرض مكعبًا مضيئًا فوق مكان القطعة حتى تعرفها بسرعة أثناء التعديل.',
                style: TextStyle(
                  color: Colors.white.withOpacity(.72),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        partControls(
          title: 'الشاشة',
          visible: _showArcadeScreen,
          onVisible: (v) => setState(() => _showArcadeScreen = v),
          x: _arcadeScreenX,
          y: _arcadeScreenY,
          z: _arcadeScreenZ,
          rotX: _arcadeScreenRotX,
          rotY: _arcadeScreenRotY,
          rotZ: _arcadeScreenRotZ,
          scaleX: _arcadeScreenScaleX,
          scaleY: _arcadeScreenScaleY,
          scaleZ: _arcadeScreenScaleZ,
          onX: (v) => _arcadeScreenX = v,
          onY: (v) => _arcadeScreenY = v,
          onZ: (v) => _arcadeScreenZ = v,
          onRotX: (v) => _arcadeScreenRotX = v,
          onRotY: (v) => _arcadeScreenRotY = v,
          onRotZ: (v) => _arcadeScreenRotZ = v,
          onScaleX: (v) => _arcadeScreenScaleX = v,
          onScaleY: (v) => _arcadeScreenScaleY = v,
          onScaleZ: (v) => _arcadeScreenScaleZ = v,
          extraControls: [
            _buildSwitchRow(
              label: 'تفعيل شاشة الآركيد التفاعلية',
              value: _arcadeDisplayEnabled,
              onChanged: (v) {
                setState(() {
                  _arcadeDisplayEnabled = v;
                  _requestArcadeDisplayRefresh();
                  _applyAllTransforms(repaint: false);
                });
              },
            ),
            _stringControl(
              label: 'اسم اللعبة أعلى الشاشة',
              value: _arcadeDisplaySideTitle,
              onChanged: (v) {
                setState(() {
                  _arcadeDisplaySideTitle = v;
                  _requestArcadeDisplayRefresh();
                });
              },
            ),
            _stringControl(
              label: 'النص الوسطي',
              value: _arcadeDisplayCenterTitle,
              onChanged: (v) {
                setState(() {
                  _arcadeDisplayCenterTitle = v;
                  _requestArcadeDisplayRefresh();
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _browseArcadeGames(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('السابق'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _browseArcadeGames(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('التالي'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اللعبة الحالية: ${_arcadeGames[_arcadeSelectedGameIndex].title}',
              style: TextStyle(
                color: Colors.white.withOpacity(.82),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildSwitchRow(
              label: 'إظهار وصف اللعبة على البطاقات',
              value: _arcadeDisplayShowSubtitle,
              onChanged: (v) {
                setState(() {
                  _arcadeDisplayShowSubtitle = v;
                  _requestArcadeDisplayRefresh();
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'التحكم بتخطيط عناصر الشاشة',
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 10),
            _screenElementLayoutControl(
              title: 'الهيدر',
              x: _arcadeDisplayHeaderOffsetX,
              y: _arcadeDisplayHeaderOffsetY,
              scale: _arcadeDisplayHeaderScale,
              onX: (v) => _arcadeDisplayHeaderOffsetX = v,
              onY: (v) => _arcadeDisplayHeaderOffsetY = v,
              onScale: (v) => _arcadeDisplayHeaderScale = v,
            ),
            _screenElementLayoutControl(
              title: 'اسم اللعبة أعلى الشاشة',
              x: _arcadeDisplaySideTitleOffsetX,
              y: _arcadeDisplaySideTitleOffsetY,
              scale: _arcadeDisplaySideTitleScale,
              onX: (v) => _arcadeDisplaySideTitleOffsetX = v,
              onY: (v) => _arcadeDisplaySideTitleOffsetY = v,
              onScale: (v) => _arcadeDisplaySideTitleScale = v,
            ),
            _screenElementLayoutControl(
              title: 'النص الوسطي',
              x: _arcadeDisplayCenterTitleOffsetX,
              y: _arcadeDisplayCenterTitleOffsetY,
              scale: _arcadeDisplayCenterTitleScale,
              onX: (v) => _arcadeDisplayCenterTitleOffsetX = v,
              onY: (v) => _arcadeDisplayCenterTitleOffsetY = v,
              onScale: (v) => _arcadeDisplayCenterTitleScale = v,
            ),
            _screenElementLayoutControl(
              title: 'عنوان اللعبة الحالية',
              x: _arcadeDisplayCurrentGameOffsetX,
              y: _arcadeDisplayCurrentGameOffsetY,
              scale: _arcadeDisplayCurrentGameScale,
              onX: (v) => _arcadeDisplayCurrentGameOffsetX = v,
              onY: (v) => _arcadeDisplayCurrentGameOffsetY = v,
              onScale: (v) => _arcadeDisplayCurrentGameScale = v,
            ),
            _screenElementLayoutControl(
              title: 'الكروت',
              x: _arcadeDisplayCardsOffsetX,
              y: _arcadeDisplayCardsOffsetY,
              scale: _arcadeDisplayCardsScale,
              onX: (v) => _arcadeDisplayCardsOffsetX = v,
              onY: (v) => _arcadeDisplayCardsOffsetY = v,
              onScale: (v) => _arcadeDisplayCardsScale = v,
            ),
            _numberControl(
              label: 'تباعد الكروت',
              value: _arcadeDisplayCardsGapScale,
              min: .2,
              max: 3,
              step: .05,
              onChanged: (v) {
                setState(() {
                  _arcadeDisplayCardsGapScale = v;
                  _requestArcadeDisplayRefresh();
                });
              },
            ),
            _screenElementLayoutControl(
              title: 'الأسهم',
              x: _arcadeDisplayArrowsOffsetX,
              y: _arcadeDisplayArrowsOffsetY,
              scale: _arcadeDisplayArrowsScale,
              onX: (v) => _arcadeDisplayArrowsOffsetX = v,
              onY: (v) => _arcadeDisplayArrowsOffsetY = v,
              onScale: (v) => _arcadeDisplayArrowsScale = v,
            ),
            _screenElementLayoutControl(
              title: 'نقاط الصفحات',
              x: _arcadeDisplayDotsOffsetX,
              y: _arcadeDisplayDotsOffsetY,
              scale: _arcadeDisplayDotsScale,
              onX: (v) => _arcadeDisplayDotsOffsetX = v,
              onY: (v) => _arcadeDisplayDotsOffsetY = v,
              onScale: (v) => _arcadeDisplayDotsScale = v,
            ),
            _screenElementLayoutControl(
              title: 'نص الإرشاد السفلي',
              x: _arcadeDisplayHintOffsetX,
              y: _arcadeDisplayHintOffsetY,
              scale: _arcadeDisplayHintScale,
              onX: (v) => _arcadeDisplayHintOffsetX = v,
              onY: (v) => _arcadeDisplayHintOffsetY = v,
              onScale: (v) => _arcadeDisplayHintScale = v,
            ),
            _colorGroup(
              title: 'خلفية الشاشة',
              r: _arcadeDisplayBgR,
              g: _arcadeDisplayBgG,
              b: _arcadeDisplayBgB,
              onR: (v) => setState(() {
                _arcadeDisplayBgR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplayBgG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplayBgB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون الهيدر',
              r: _arcadeDisplayHeaderR,
              g: _arcadeDisplayHeaderG,
              b: _arcadeDisplayHeaderB,
              onR: (v) => setState(() {
                _arcadeDisplayHeaderR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplayHeaderG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplayHeaderB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون التركيز',
              r: _arcadeDisplayAccentR,
              g: _arcadeDisplayAccentG,
              b: _arcadeDisplayAccentB,
              onR: (v) => setState(() {
                _arcadeDisplayAccentR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplayAccentG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplayAccentB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون البطاقات',
              r: _arcadeDisplayCardR,
              g: _arcadeDisplayCardG,
              b: _arcadeDisplayCardB,
              onR: (v) => setState(() {
                _arcadeDisplayCardR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplayCardG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplayCardB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون البطاقة المحددة',
              r: _arcadeDisplaySelectedCardR,
              g: _arcadeDisplaySelectedCardG,
              b: _arcadeDisplaySelectedCardB,
              onR: (v) => setState(() {
                _arcadeDisplaySelectedCardR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplaySelectedCardG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplaySelectedCardB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون النصوص',
              r: _arcadeDisplayTextR,
              g: _arcadeDisplayTextG,
              b: _arcadeDisplayTextB,
              onR: (v) => setState(() {
                _arcadeDisplayTextR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplayTextG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplayTextB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون النص الثانوي',
              r: _arcadeDisplaySubtextR,
              g: _arcadeDisplaySubtextG,
              b: _arcadeDisplaySubtextB,
              onR: (v) => setState(() {
                _arcadeDisplaySubtextR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplaySubtextG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplaySubtextB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            _colorGroup(
              title: 'لون الأسهم والإطار',
              r: _arcadeDisplayArrowR,
              g: _arcadeDisplayArrowG,
              b: _arcadeDisplayArrowB,
              onR: (v) => setState(() {
                _arcadeDisplayArrowR = v;
                _requestArcadeDisplayRefresh();
              }),
              onG: (v) => setState(() {
                _arcadeDisplayArrowG = v;
                _requestArcadeDisplayRefresh();
              }),
              onB: (v) => setState(() {
                _arcadeDisplayArrowB = v;
                _requestArcadeDisplayRefresh();
              }),
            ),
            const Divider(height: 24, color: Color(0x2FFFFFFF)),
          ],
          onReset: () {
            setState(() {
              _showArcadeScreen = true;
              _arcadeScreenX = 0;
              _arcadeScreenY = 0;
              _arcadeScreenZ = 0;
              _arcadeScreenRotX = 0;
              _arcadeScreenRotY = 0;
              _arcadeScreenRotZ = 0;
              _arcadeScreenScaleX = 1;
              _arcadeScreenScaleY = 1;
              _arcadeScreenScaleZ = 1;
              _arcadeScreenColorEnabled = false;
              _arcadeScreenColorR = 255;
              _arcadeScreenColorG = 255;
              _arcadeScreenColorB = 255;
              _arcadeScreenColorOpacity = 1;
              _arcadeDisplayEnabled = true;
              _arcadeDisplaySideTitle = 'سوكي';
              _arcadeDisplayCenterTitle = 'اختر لعبتك';
              _arcadeSelectedGameIndex = 2;
              _arcadeDisplayBgR = 5;
              _arcadeDisplayBgG = 17;
              _arcadeDisplayBgB = 28;
              _arcadeDisplayHeaderR = 8;
              _arcadeDisplayHeaderG = 29;
              _arcadeDisplayHeaderB = 43;
              _arcadeDisplayAccentR = 76;
              _arcadeDisplayAccentG = 244;
              _arcadeDisplayAccentB = 255;
              _arcadeDisplayCardR = 17;
              _arcadeDisplayCardG = 27;
              _arcadeDisplayCardB = 39;
              _arcadeDisplaySelectedCardR = 6;
              _arcadeDisplaySelectedCardG = 42;
              _arcadeDisplaySelectedCardB = 53;
              _arcadeDisplayTextR = 255;
              _arcadeDisplayTextG = 255;
              _arcadeDisplayTextB = 255;
              _arcadeDisplaySubtextR = 143;
              _arcadeDisplaySubtextG = 160;
              _arcadeDisplaySubtextB = 177;
              _arcadeDisplayArrowR = 255;
              _arcadeDisplayArrowG = 199;
              _arcadeDisplayArrowB = 70;
              _arcadeDisplayFrameR = 124;
              _arcadeDisplayFrameG = 255;
              _arcadeDisplayFrameB = 223;
              _arcadeDisplayShowSubtitle = true;
              _arcadeDisplayHeaderOffsetX = 0;
              _arcadeDisplayHeaderOffsetY = 0;
              _arcadeDisplayHeaderScale = 1.0;
              _arcadeDisplaySideTitleOffsetX = 0;
              _arcadeDisplaySideTitleOffsetY = 0;
              _arcadeDisplaySideTitleScale = 1.0;
              _arcadeDisplayCenterTitleOffsetX = 0;
              _arcadeDisplayCenterTitleOffsetY = 0;
              _arcadeDisplayCenterTitleScale = 1.0;
              _arcadeDisplayCurrentGameOffsetX = 0;
              _arcadeDisplayCurrentGameOffsetY = 0;
              _arcadeDisplayCurrentGameScale = 2.0;
              _arcadeDisplayCardsOffsetX = 0;
              _arcadeDisplayCardsOffsetY = 0;
              _arcadeDisplayCardsScale = 1.0;
              _arcadeDisplayCardsGapScale = 1.0;
              _arcadeDisplayArrowsOffsetX = 0;
              _arcadeDisplayArrowsOffsetY = 0;
              _arcadeDisplayArrowsScale = 1.0;
              _arcadeDisplayDotsOffsetX = 0;
              _arcadeDisplayDotsOffsetY = 0;
              _arcadeDisplayDotsScale = .25;
              _arcadeDisplayHintOffsetX = -20.50;
              _arcadeDisplayHintOffsetY = 0;
              _arcadeDisplayHintScale = .25;
              _requestArcadeDisplayRefresh();
              _applyAllTransforms(repaint: false);
            });
          },
        ),
        partControls(
          title: 'المقبض',
          visible: _showArcadeJoystick,
          onVisible: (v) => setState(() => _showArcadeJoystick = v),
          x: _arcadeJoystickX,
          y: _arcadeJoystickY,
          z: _arcadeJoystickZ,
          rotX: _arcadeJoystickRotX,
          rotY: _arcadeJoystickRotY,
          rotZ: _arcadeJoystickRotZ,
          scaleX: _arcadeJoystickScaleX,
          scaleY: _arcadeJoystickScaleY,
          scaleZ: _arcadeJoystickScaleZ,
          onX: (v) => _arcadeJoystickX = v,
          onY: (v) => _arcadeJoystickY = v,
          onZ: (v) => _arcadeJoystickZ = v,
          onRotX: (v) => _arcadeJoystickRotX = v,
          onRotY: (v) => _arcadeJoystickRotY = v,
          onRotZ: (v) => _arcadeJoystickRotZ = v,
          onScaleX: (v) => _arcadeJoystickScaleX = v,
          onScaleY: (v) => _arcadeJoystickScaleY = v,
          onScaleZ: (v) => _arcadeJoystickScaleZ = v,
          extraControls: [
            _buildSwitchRow(
              label: 'إظهار هيت بوكس ضغط المقبض',
              value: _showArcadeJoystickPressHitbox,
              onChanged: (v) {
                setState(() {
                  _showArcadeJoystickPressHitbox = v;
                  _updateArcadeJoystickPressHitbox();
                });
              },
            ),
            _tripleControl(
              prefix: 'موضع هيت بوكس الضغط',
              xLabel: 'X',
              yLabel: 'Y',
              zLabel: 'Z',
              min: -5,
              max: 5,
              step: .01,
              x: _arcadeJoystickPressHitboxX,
              y: _arcadeJoystickPressHitboxY,
              z: _arcadeJoystickPressHitboxZ,
              onX: (v) => _arcadeJoystickPressHitboxX = v,
              onY: (v) => _arcadeJoystickPressHitboxY = v,
              onZ: (v) => _arcadeJoystickPressHitboxZ = v,
              afterChange: _updateArcadeJoystickPressHitbox,
            ),
            _tripleControl(
              prefix: 'حجم هيت بوكس الضغط',
              xLabel: 'Size X',
              yLabel: 'Size Y',
              zLabel: 'Size Z',
              min: .05,
              max: 10,
              step: .01,
              x: _arcadeJoystickPressHitboxSizeX,
              y: _arcadeJoystickPressHitboxSizeY,
              z: _arcadeJoystickPressHitboxSizeZ,
              onX: (v) => _arcadeJoystickPressHitboxSizeX = v,
              onY: (v) => _arcadeJoystickPressHitboxSizeY = v,
              onZ: (v) => _arcadeJoystickPressHitboxSizeZ = v,
              afterChange: _updateArcadeJoystickPressHitbox,
            ),
            _buildSwitchRow(
              label: 'معاينة ضغط المقبض مباشرة',
              value: _arcadeJoystickPressPreview,
              onChanged: (v) {
                setState(() {
                  _arcadeJoystickPressPreview = v;
                  _applyAllTransforms(save: false, repaint: false);
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _arcadeJoystickPreviewDirection = -1;
                      _previewArcadeJoystickPress(-1);
                    }),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('معاينة يسار'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _arcadeJoystickPreviewDirection = 1;
                      _previewArcadeJoystickPress(1);
                    }),
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('معاينة يمين'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'حركة المقبض عند التصفح',
              style: TextStyle(
                color: Colors.white.withOpacity(.90),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'التالي',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _numberControl(
              label: 'مدة ضغط التالي',
              value: _arcadeJoystickPressDuration,
              min: .01,
              max: 1.5,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickPressDuration = v;
                _arcadeJoystickPreviewDirection = 1;
                _previewArcadeJoystickPress(1);
              }),
            ),
            _numberControl(
              label: 'مدة رجوع التالي',
              value: _arcadeJoystickReturnDuration,
              min: .01,
              max: 2.0,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickReturnDuration = v;
                _arcadeJoystickPreviewDirection = 1;
                _previewArcadeJoystickPress(1);
              }),
            ),
            _tripleControl(
              prefix: 'إزاحة التالي',
              xLabel: 'X',
              yLabel: 'Y',
              zLabel: 'Z',
              min: -20,
              max: 20,
              step: .005,
              x: _arcadeJoystickPressOffsetX,
              y: _arcadeJoystickPressOffsetY,
              z: _arcadeJoystickPressOffsetZ,
              onX: (v) => _arcadeJoystickPressOffsetX = v,
              onY: (v) => _arcadeJoystickPressOffsetY = v,
              onZ: (v) => _arcadeJoystickPressOffsetZ = v,
              afterChange: () {
                _arcadeJoystickPreviewDirection = 1;
                _previewArcadeJoystickPress(1);
              },
            ),
            _tripleControl(
              prefix: 'ميلان التالي',
              xLabel: 'Pitch',
              yLabel: 'Yaw',
              zLabel: 'Roll',
              min: -90,
              max: 90,
              step: 1,
              x: _arcadeJoystickTiltPitch,
              y: _arcadeJoystickTiltYaw,
              z: _arcadeJoystickTiltRoll,
              onX: (v) => _arcadeJoystickTiltPitch = v,
              onY: (v) => _arcadeJoystickTiltYaw = v,
              onZ: (v) => _arcadeJoystickTiltRoll = v,
              afterChange: () {
                _arcadeJoystickPreviewDirection = 1;
                _previewArcadeJoystickPress(1);
              },
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _arcadeJoystickPreviewDirection = 1);
                  _previewArcadeJoystickPress(1);
                },
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('معاينة حركة التالي'),
              ),
            ),
            const Divider(height: 26, color: Color(0x2FFFFFFF)),
            const Text(
              'السابق',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _numberControl(
              label: 'مدة ضغط السابق',
              value: _arcadeJoystickPreviousPressDuration,
              min: .01,
              max: 1.5,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickPreviousPressDuration = v;
                _arcadeJoystickPreviewDirection = -1;
                _previewArcadeJoystickPress(-1);
              }),
            ),
            _numberControl(
              label: 'مدة رجوع السابق',
              value: _arcadeJoystickPreviousReturnDuration,
              min: .01,
              max: 2.0,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickPreviousReturnDuration = v;
                _arcadeJoystickPreviewDirection = -1;
                _previewArcadeJoystickPress(-1);
              }),
            ),
            _numberControl(
              label: 'تثبيت السابق على الوضعية النهائية',
              value: _arcadeJoystickPreviousPeakHold,
              min: 0,
              max: .50,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickPreviousPeakHold = v;
                _scheduleSave();
              }),
            ),
            const SizedBox(height: 8),
            const Text(
              'تعويض مسار رجوع السابق',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _tripleControl(
              prefix: 'تعويض الرجوع',
              xLabel: 'يمين/يسار X',
              yLabel: 'أعلى/أسفل Y',
              zLabel: 'أمام/خلف Z',
              min: -100,
              max: 100,
              step: .10,
              x: _arcadeJoystickPreviousReturnCompX,
              y: _arcadeJoystickPreviousReturnCompY,
              z: _arcadeJoystickPreviousReturnCompZ,
              onX: (v) => _arcadeJoystickPreviousReturnCompX = v,
              onY: (v) => _arcadeJoystickPreviousReturnCompY = v,
              onZ: (v) => _arcadeJoystickPreviousReturnCompZ = v,
              afterChange: () {
                _scheduleSave();
              },
            ),
            _numberControl(
              label: 'قوة تعويض الرجوع',
              value: _arcadeJoystickPreviousReturnCompStrength,
              min: 0,
              max: 3,
              step: .05,
              onChanged: (v) => setState(() {
                _arcadeJoystickPreviousReturnCompStrength = v;
                _scheduleSave();
              }),
            ),
            _tripleControl(
              prefix: 'إزاحة السابق',
              xLabel: 'X',
              yLabel: 'Y',
              zLabel: 'Z',
              min: -20,
              max: 20,
              step: .005,
              x: _arcadeJoystickPreviousOffsetX,
              y: _arcadeJoystickPreviousOffsetY,
              z: _arcadeJoystickPreviousOffsetZ,
              onX: (v) => _arcadeJoystickPreviousOffsetX = v,
              onY: (v) => _arcadeJoystickPreviousOffsetY = v,
              onZ: (v) => _arcadeJoystickPreviousOffsetZ = v,
              afterChange: () {
                _arcadeJoystickPreviewDirection = -1;
                _previewArcadeJoystickPress(-1);
              },
            ),
            _tripleControl(
              prefix: 'ميلان السابق',
              xLabel: 'Pitch',
              yLabel: 'Yaw',
              zLabel: 'Roll',
              min: -90,
              max: 90,
              step: 1,
              x: _arcadeJoystickPreviousTiltPitch,
              y: _arcadeJoystickPreviousTiltYaw,
              z: _arcadeJoystickPreviousTiltRoll,
              onX: (v) => _arcadeJoystickPreviousTiltPitch = v,
              onY: (v) => _arcadeJoystickPreviousTiltYaw = v,
              onZ: (v) => _arcadeJoystickPreviousTiltRoll = v,
              afterChange: () {
                _arcadeJoystickPreviewDirection = -1;
                _previewArcadeJoystickPress(-1);
              },
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _arcadeJoystickPreviewDirection = -1);
                  _previewArcadeJoystickPress(-1);
                },
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('معاينة حركة السابق'),
              ),
            ),
            const Divider(height: 24, color: Color(0x2FFFFFFF)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _browseArcadeGames(-1),
                    icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
                    label: const Text('تجربة يسار'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _browseArcadeGames(1),
                    icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
                    label: const Text('تجربة يمين'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0x2FFFFFFF)),
            _buildSwitchRow(
              label: 'لون مخصص للمقبض',
              value: _arcadeJoystickColorEnabled,
              onChanged: (v) {
                setState(() {
                  _arcadeJoystickColorEnabled = v;
                  _applyAllTransforms(repaint: false);
                });
              },
            ),
            if (_arcadeJoystickColorEnabled) ...[
              _numberControl(
                label: 'R',
                value: _arcadeJoystickColorR,
                min: 0,
                max: 255,
                step: 1,
                onChanged: (v) {
                  setState(() {
                    _arcadeJoystickColorR = v;
                    _applyAllTransforms(repaint: false);
                  });
                },
              ),
              _numberControl(
                label: 'G',
                value: _arcadeJoystickColorG,
                min: 0,
                max: 255,
                step: 1,
                onChanged: (v) {
                  setState(() {
                    _arcadeJoystickColorG = v;
                    _applyAllTransforms(repaint: false);
                  });
                },
              ),
              _numberControl(
                label: 'B',
                value: _arcadeJoystickColorB,
                min: 0,
                max: 255,
                step: 1,
                onChanged: (v) {
                  setState(() {
                    _arcadeJoystickColorB = v;
                    _applyAllTransforms(repaint: false);
                  });
                },
              ),
              _numberControl(
                label: 'شفافية اللون',
                value: _arcadeJoystickColorOpacity,
                min: 0,
                max: 1,
                step: .05,
                onChanged: (v) {
                  setState(() {
                    _arcadeJoystickColorOpacity = v;
                    _applyAllTransforms(repaint: false);
                  });
                },
              ),
            ],
          ],
          onReset: () {
            setState(() {
              _showArcadeJoystick = true;
              _arcadeJoystickX = 0;
              _arcadeJoystickY = 0;
              _arcadeJoystickZ = 0;
              _arcadeJoystickRotX = 0;
              _arcadeJoystickRotY = 0;
              _arcadeJoystickRotZ = 0;
              _arcadeJoystickScaleX = 1;
              _arcadeJoystickScaleY = 1;
              _arcadeJoystickScaleZ = 1;
              _arcadeJoystickColorEnabled = false;
              _arcadeJoystickColorR = 255;
              _arcadeJoystickColorG = 255;
              _arcadeJoystickColorB = 255;
              _arcadeJoystickColorOpacity = 1;
              _arcadeJoystickPressDuration = .010;
              _arcadeJoystickReturnDuration = .180;
              _arcadeJoystickPressOffsetX = -9.0000;
              _arcadeJoystickPressOffsetY = -.0350;
              _arcadeJoystickPressOffsetZ = 12.0000;
              _arcadeJoystickTiltPitch = 0;
              _arcadeJoystickTiltYaw = 16;
              _arcadeJoystickTiltRoll = 0;

              _arcadeJoystickPreviousPressDuration = .010;
              _arcadeJoystickPreviousReturnDuration = .170;
              _arcadeJoystickPreviousOffsetX = 53.0000;
              _arcadeJoystickPreviousOffsetY = -12.0700;
              _arcadeJoystickPreviousOffsetZ = -16.5400;
              _arcadeJoystickPreviousTiltPitch = -19;
              _arcadeJoystickPreviousTiltYaw = -62;
              _arcadeJoystickPreviousTiltRoll = 0;
              _arcadeJoystickPreviousPeakHold = .080;
              _arcadeJoystickPreviousReturnCompX = -5.0;
              _arcadeJoystickPreviousReturnCompY = -10.0;
              _arcadeJoystickPreviousReturnCompZ = 0.0;
              _arcadeJoystickPreviousReturnCompStrength = 1.0;

              _showArcadeJoystickPressHitbox = false;
              _arcadeJoystickPressHitboxX = 41.0000;
              _arcadeJoystickPressHitboxY = -.8600;
              _arcadeJoystickPressHitboxZ = 38.0000;
              _arcadeJoystickPressHitboxSizeX = 2.20;
              _arcadeJoystickPressHitboxSizeY = 2.20;
              _arcadeJoystickPressHitboxSizeZ = 4.89;
              _arcadeJoystickPressPreview = false;
              _arcadeJoystickPreviewDirection = 1;
              _applyAllTransforms(repaint: false);
            });
          },
        ),
        partControls(
          title: 'زر الدخول',
          visible: _showArcadeEnterButton,
          onVisible: (v) => setState(() => _showArcadeEnterButton = v),
          x: _arcadeEnterButtonX,
          y: _arcadeEnterButtonY,
          z: _arcadeEnterButtonZ,
          rotX: _arcadeEnterButtonRotX,
          rotY: _arcadeEnterButtonRotY,
          rotZ: _arcadeEnterButtonRotZ,
          scaleX: _arcadeEnterButtonScaleX,
          scaleY: _arcadeEnterButtonScaleY,
          scaleZ: _arcadeEnterButtonScaleZ,
          onX: (v) => _arcadeEnterButtonX = v,
          onY: (v) => _arcadeEnterButtonY = v,
          onZ: (v) => _arcadeEnterButtonZ = v,
          onRotX: (v) => _arcadeEnterButtonRotX = v,
          onRotY: (v) => _arcadeEnterButtonRotY = v,
          onRotZ: (v) => _arcadeEnterButtonRotZ = v,
          onScaleX: (v) => _arcadeEnterButtonScaleX = v,
          onScaleY: (v) => _arcadeEnterButtonScaleY = v,
          onScaleZ: (v) => _arcadeEnterButtonScaleZ = v,
          positionMin: -60,
          positionMax: 60,
          extraControls: [
            Text(
              'حركة الزر الأحمر عند الضغط',
              style: TextStyle(
                color: Colors.white.withOpacity(.90),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _numberControl(
              label: 'مدة النزول',
              value: _arcadeEnterButtonPressDuration,
              min: .01,
              max: 2,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeEnterButtonPressDuration = v;
                _scheduleSave();
              }),
            ),
            _numberControl(
              label: 'مدة الرجوع',
              value: _arcadeEnterButtonReturnDuration,
              min: .01,
              max: 2,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeEnterButtonReturnDuration = v;
                _scheduleSave();
              }),
            ),
            _numberControl(
              label: 'مقدار نزول الزر الأحمر',
              value: _arcadeEnterButtonPressDepth,
              min: 0,
              max: 30,
              step: .1,
              onChanged: (v) => setState(() {
                _arcadeEnterButtonPressDepth = v;
                _applyArcadeEnterButtonTransform();
                _scheduleSave();
              }),
            ),
            const Divider(height: 24, color: Color(0x2FFFFFFF)),
            _buildSwitchRow(
              label: 'تفعيل لون مخصص للزر الأحمر',
              value: _arcadeEnterButtonRedColorEnabled,
              onChanged: (v) {
                setState(() {
                  _arcadeEnterButtonRedColorEnabled = v;
                  _applyArcadeEnterButtonRedColor();
                  _scheduleSave();
                });
              },
            ),
            if (_arcadeEnterButtonRedColorEnabled)
              _colorGroup(
                title: 'لون الزر الأحمر الحقيقي',
                r: _arcadeEnterButtonRedR,
                g: _arcadeEnterButtonRedG,
                b: _arcadeEnterButtonRedB,
                onR: (v) => setState(() {
                  _arcadeEnterButtonRedR = v;
                  _applyArcadeEnterButtonRedColor();
                  _scheduleSave();
                }),
                onG: (v) => setState(() {
                  _arcadeEnterButtonRedG = v;
                  _applyArcadeEnterButtonRedColor();
                  _scheduleSave();
                }),
                onB: (v) => setState(() {
                  _arcadeEnterButtonRedB = v;
                  _applyArcadeEnterButtonRedColor();
                  _scheduleSave();
                }),
              ),
            _buildSwitchRow(
              label: 'معاينة الزر مضغوطًا',
              value: _arcadeEnterButtonPreviewPressed,
              onChanged: (v) {
                setState(() {
                  _arcadeEnterButtonPreviewPressed = v;
                  _applyArcadeEnterButtonTransform();
                  _scheduleSave();
                });
              },
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pressArcadeEnterButton(openGame: false),
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('تجربة ضغطة كاملة'),
              ),
            ),
          ],
          onReset: () {
            setState(() {
              _showArcadeEnterButton = true;
              _arcadeEnterButtonX = 25.8000;
              _arcadeEnterButtonY = 27.6600;
              _arcadeEnterButtonZ = 16.5500;
              _arcadeEnterButtonRotX = 94;
              _arcadeEnterButtonRotY = 9;
              _arcadeEnterButtonRotZ = 2;
              _arcadeEnterButtonScaleX = 1.20;
              _arcadeEnterButtonScaleY = 1.20;
              _arcadeEnterButtonScaleZ = 1.20;
              _arcadeEnterButtonPressDuration = .050;
              _arcadeEnterButtonReturnDuration = .100;
              _arcadeEnterButtonPressDepth = 12.0;
              _arcadeEnterButtonRedColorEnabled = true;
              _arcadeEnterButtonRedR = 47.0;
              _arcadeEnterButtonRedG = 0.0;
              _arcadeEnterButtonRedB = 14.0;
              _arcadeEnterButtonPreviewPressed = false;
              _applyArcadeEnterButtonTransform();
            });
          },
        ),
      ],
    );
  }

  Widget _buildArcadeDeveloperSection() {
    return _buildTransformSection(
      title: 'ماكينة الآركيد التفاعلية',
      subtitle:
          'حدد أسطوانة التوهج الخاصة بالآركيد (عرض/ارتفاع/عمق) مع تدرج لوني من الأسفل إلى الأعلى، ثم حرر كاميرا الانتقال مباشرة بالماوس والأسهم.',
      controls: [
        _buildSwitchRow(
          label: 'إظهار توهج الآركيد',
          value: _arcadeHighlightVisible,
          onChanged: (value) {
            setState(() => _arcadeHighlightVisible = value);
            _updateArcadeInteractionVisual();
            _scheduleSave();
          },
        ),
        _tripleControl(
          prefix: 'موضع أسطوانة التوهج / الضغط',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -10,
          max: 10,
          step: .01,
          x: _arcadeX,
          y: _arcadeY,
          z: _arcadeZ,
          onX: (v) => _arcadeX = v,
          onY: (v) => _arcadeY = v,
          onZ: (v) => _arcadeZ = v,
        ),
        _tripleControl(
          prefix: 'دوران أسطوانة التوهج',
          xLabel: 'Pitch',
          yLabel: 'Yaw',
          zLabel: 'Roll',
          min: -180,
          max: 180,
          step: 1,
          x: _arcadeRotX,
          y: _arcadeRotY,
          z: _arcadeRotZ,
          onX: (v) => _arcadeRotX = v,
          onY: (v) => _arcadeRotY = v,
          onZ: (v) => _arcadeRotZ = v,
        ),
        _tripleControl(
          prefix: 'حجم أسطوانة التوهج',
          xLabel: 'Size X',
          yLabel: 'Size Y',
          zLabel: 'Size Z',
          min: .05,
          max: 6,
          step: .01,
          x: _arcadeSizeX,
          y: _arcadeSizeY,
          z: _arcadeSizeZ,
          onX: (v) => _arcadeSizeX = v,
          onY: (v) => _arcadeSizeY = v,
          onZ: (v) => _arcadeSizeZ = v,
        ),
        _numberControl(
          label: 'سمك إطار التوهج',
          value: _arcadeGlowThickness,
          min: .005,
          max: .35,
          step: .005,
          onChanged: (v) => setState(() {
            _arcadeGlowThickness = v;
            _updateArcadeInteractionVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'شدة التوهج',
          value: _arcadeGlowIntensity,
          min: 0,
          max: 2,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeGlowIntensity = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'شفافية التوهج',
          value: _arcadeGlowOpacity,
          min: 0,
          max: 1,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeGlowOpacity = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        const SizedBox(height: 4),
        const Text(
          'لون التوهج RGB',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _numberControl(
          label: 'أحمر R',
          value: _arcadeGlowR,
          min: 0,
          max: 255,
          step: 1,
          onChanged: (v) => setState(() {
            _arcadeGlowR = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'أخضر G',
          value: _arcadeGlowG,
          min: 0,
          max: 255,
          step: 1,
          onChanged: (v) => setState(() {
            _arcadeGlowG = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'أزرق B',
          value: _arcadeGlowB,
          min: 0,
          max: 255,
          step: 1,
          onChanged: (v) => setState(() {
            _arcadeGlowB = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        const Divider(height: 26, color: Color(0x2FFFFFFF)),
        const Text(
          'تدرج الأسطوانة المتوهجة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _colorGroup(
          title: 'لون أعلى الأسطوانة',
          r: _arcadeGlowTopR,
          g: _arcadeGlowTopG,
          b: _arcadeGlowTopB,
          onR: (v) => setState(() {
            _arcadeGlowTopR = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
          onG: (v) => setState(() {
            _arcadeGlowTopG = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
          onB: (v) => setState(() {
            _arcadeGlowTopB = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'شفافية أعلى الأسطوانة',
          value: _arcadeGlowTopOpacity,
          min: 0,
          max: 1,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeGlowTopOpacity = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        const SizedBox(height: 8),
        _colorGroup(
          title: 'لون أسفل الأسطوانة',
          r: _arcadeGlowBottomR,
          g: _arcadeGlowBottomG,
          b: _arcadeGlowBottomB,
          onR: (v) => setState(() {
            _arcadeGlowBottomR = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
          onG: (v) => setState(() {
            _arcadeGlowBottomG = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
          onB: (v) => setState(() {
            _arcadeGlowBottomB = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'شفافية أسفل الأسطوانة',
          value: _arcadeGlowBottomOpacity,
          min: 0,
          max: 1,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeGlowBottomOpacity = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'منتصف التدرج (0 = يغلب الأسفل / 1 = يغلب الأعلى)',
          value: _arcadeGlowBlendMidpoint,
          min: .05,
          max: .95,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeGlowBlendMidpoint = v;
            _updateArcadeGlowMaterial();
            _scheduleSave();
          }),
        ),
        const Divider(height: 26, color: Color(0x2FFFFFFF)),
        const Text(
          'حركة أسطوانة التوهج',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildSwitchRow(
          label: 'دوران تلقائي مستمر',
          value: _arcadeGlowAutoRotate,
          onChanged: (v) {
            setState(() {
              _arcadeGlowAutoRotate = v;
              _scheduleSave();
            });
          },
        ),
        _numberControl(
          label: 'سرعة الدوران (درجة/ثانية)',
          value: _arcadeGlowRotationSpeed,
          min: 0,
          max: 180,
          step: 1,
          onChanged: (v) => setState(() {
            _arcadeGlowRotationSpeed = v;
            _scheduleSave();
          }),
        ),
        _buildSwitchRow(
          label: _arcadeGlowRotateRight
              ? 'اتجاه الدوران: يمين'
              : 'اتجاه الدوران: يسار',
          value: _arcadeGlowRotateRight,
          onChanged: (v) {
            setState(() {
              _arcadeGlowRotateRight = v;
              _scheduleSave();
            });
          },
        ),
        const SizedBox(height: 8),
        _buildSwitchRow(
          label: 'صعود ونزول مستمر',
          value: _arcadeGlowAutoBob,
          onChanged: (v) {
            setState(() {
              _arcadeGlowAutoBob = v;
              _arcadeGlowBobPhase = 0;
              _updateArcadeInteractionVisual();
              _scheduleSave();
            });
          },
        ),
        _numberControl(
          label: 'مقدار الصعود والنزول',
          value: _arcadeGlowBobAmount,
          min: 0,
          max: 1.0,
          step: .01,
          onChanged: (v) => setState(() {
            _arcadeGlowBobAmount = v;
            _updateArcadeInteractionVisual();
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'سرعة الصعود والنزول',
          value: _arcadeGlowBobSpeed,
          min: .05,
          max: 3.0,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeGlowBobSpeed = v;
            _scheduleSave();
          }),
        ),
        const Divider(height: 26, color: Color(0x2FFFFFFF)),
        _numberControl(
          label: 'مدة انتقال الكاميرا (ثانية)',
          value: _arcadeTransitionSeconds,
          min: .10,
          max: 5,
          step: .05,
          onChanged: (v) => setState(() {
            _arcadeTransitionSeconds = v;
            _scheduleSave();
          }),
        ),
        _tripleControl(
          prefix: 'موضع الكاميرا بعد الضغط',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -20,
          max: 20,
          step: .02,
          x: _arcadeFocusCameraX,
          y: _arcadeFocusCameraY,
          z: _arcadeFocusCameraZ,
          onX: (v) => _arcadeFocusCameraX = v,
          onY: (v) => _arcadeFocusCameraY = v,
          onZ: (v) => _arcadeFocusCameraZ = v,
          afterChange: () {
            if (_arcadeCameraEditMode) _previewArcadeFocusCamera();
          },
        ),
        _tripleControl(
          prefix: 'نقطة نظر الكاميرا بعد الضغط',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -20,
          max: 20,
          step: .02,
          x: _arcadeFocusTargetX,
          y: _arcadeFocusTargetY,
          z: _arcadeFocusTargetZ,
          onX: (v) => _arcadeFocusTargetX = v,
          onY: (v) => _arcadeFocusTargetY = v,
          onZ: (v) => _arcadeFocusTargetZ = v,
          afterChange: () {
            if (_arcadeCameraEditMode) _previewArcadeFocusCamera();
          },
        ),
        _numberControl(
          label: 'FOV بعد الضغط',
          value: _arcadeFocusFov,
          min: 18,
          max: 110,
          step: 1,
          onChanged: (v) => setState(() {
            _arcadeFocusFov = v;
            if (_arcadeCameraEditMode) _previewArcadeFocusCamera();
            _scheduleSave();
          }),
        ),
        const Divider(height: 26, color: Color(0x2FFFFFFF)),
        const Text('حدود النظر في وضع المستخدم — عند الآركيد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('تطبق بعد الوصول للآركيد في وضع المستخدم. أثناء تعديلها هنا تنتقل المعاينة فورًا إلى كاميرا الآركيد الحالية وتسمح للمطور بتجربة الحدود بالماوس.', style: TextStyle(color: Colors.white70, fontSize: 12.2, height: 1.45)),
        const SizedBox(height: 10),
        _numberControl(label: 'حد الآركيد جهة اليسار', value: _arcadeLookLeftDeg, min: 0, max: 180, step: 1, onChanged: (v) { setState(() => _arcadeLookLeftDeg = v); _refreshLookLimitPreview(arcade: true); }),
        _numberControl(label: 'حد الآركيد جهة اليمين', value: _arcadeLookRightDeg, min: 0, max: 180, step: 1, onChanged: (v) { setState(() => _arcadeLookRightDeg = v); _refreshLookLimitPreview(arcade: true); }),
        _numberControl(label: 'حد الآركيد للأعلى', value: _arcadeLookUpDeg, min: 0, max: 89, step: 1, onChanged: (v) { setState(() => _arcadeLookUpDeg = v); _refreshLookLimitPreview(arcade: true); }),
        _numberControl(label: 'حد الآركيد للأسفل', value: _arcadeLookDownDeg, min: 0, max: 89, step: 1, onChanged: (v) { setState(() => _arcadeLookDownDeg = v); _refreshLookLimitPreview(arcade: true); }),
        if (_lookLimitPreviewMode == 'arcade') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _finishLookLimitPreview,
              icon: const Icon(Icons.stop_circle_rounded),
              label: const Text('إنهاء معاينة حدود الآركيد'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8A4E24),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!_arcadeCameraEditMode)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _beginArcadeCameraEditing,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('تحديد القيم بشكل حر (ماوس + أسهم + Ctrl)'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        if (_arcadeCameraEditMode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x2B6B46C1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x886B46C1)),
            ),
            child: const Text(
              'وضع تحرير كاميرا الآركيد مفعل: حرّك الكاميرا بالسحب بالماوس، الأسهم، وCtrl + الأسهم. Enter = تم، وEsc = إلغاء.',
              style: TextStyle(color: Colors.white, fontSize: 12.3, height: 1.45),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _finishArcadeCameraEditing,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('تم اعتماد القيم الحالية'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF198A61),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _cancelArcadeCameraEditing,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('إلغاء'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              setState(() {
                _syncArcadeFocusFromCurrentCamera(save: true);
              });
            },
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('اعتماد الكاميرا الحالية ككاميرا الآركيد'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF285F78),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startArcadeCameraTransition,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('تجربة انتقال الكاميرا الآن'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF168CB8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCharacterDeveloperSection() {
    return _buildTransformSection(
      title: 'قسم الجسم العام',
      subtitle: 'تحكم بالمجسم ككل قبل الدخول لتفاصيل الرأس أو الجذع أو الأطراف.',
      controls: [
        _buildSwitchRow(
          label: 'إظهار الشخصية',
          value: _showCharacter,
          onChanged: (value) {
            setState(() => _showCharacter = value);
            _applyAllTransforms();
          },
        ),
        _tripleControl(
          prefix: 'موضع الشخصية',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -10,
          max: 10,
          step: .02,
          x: _characterX,
          y: _characterY,
          z: _characterZ,
          onX: (v) => _characterX = v,
          onY: (v) => _characterY = v,
          onZ: (v) => _characterZ = v,
        ),
        _tripleControl(
          prefix: 'دوران الشخصية',
          xLabel: 'Pitch',
          yLabel: 'Yaw',
          zLabel: 'Roll',
          min: -180,
          max: 180,
          step: 1,
          x: _characterRotX,
          y: _characterRotY,
          z: _characterRotZ,
          onX: (v) => _characterRotX = v,
          onY: (v) => _characterRotY = v,
          onZ: (v) => _characterRotZ = v,
        ),
        _tripleControl(
          prefix: 'حجم الشخصية',
          xLabel: 'Scale X',
          yLabel: 'Scale Y',
          zLabel: 'Scale Z',
          min: .25,
          max: 4.0,
          step: .01,
          x: _characterScaleX,
          y: _characterScaleY,
          z: _characterScaleZ,
          onX: (v) => _characterScaleX = v,
          onY: (v) => _characterScaleY = v,
          onZ: (v) => _characterScaleZ = v,
        ),
      ],
    );
  }

  Widget _buildPoseGroupSection({
    required String title,
    required String subtitle,
    required List<String> nodeNames,
  }) {
    final nodes = _poseTunings
        .where((tuning) => nodeNames.contains(tuning.nodeName))
        .toList();

    return _buildTransformSection(
      title: title,
      subtitle: subtitle,
      controls: [
        for (final tuning in nodes) _buildPoseTile(tuning),
      ],
    );
  }

  Widget _buildSceneDeveloperSection() {
    return Column(
      children: [
        _buildSwitchRow(
          label: 'إظهار بطاقة الشرح',
          value: _showGuide,
          onChanged: (value) {
            setState(() => _showGuide = value);
            _scheduleSave();
          },
        ),
        _buildSceneSection(),
      ],
    );
  }

  Widget _buildValuesDeveloperSection() {
    return _buildTransformSection(
      title: 'القيم والحفظ',
      subtitle:
          'نسخ القيم هنا شامل: الكاميرا، الماب، الجسم، جميع العظام، المشهد، الآركيد التفاعلي، وإعدادات ونقاط الحركة الديناميكية.',
      controls: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startUserMode,
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: const Text('تشغيل وضع المستخدم'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF167A55), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => unawaited(_copyCurrentValues()),
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('نسخ كل القيم الحالية — شامل'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2A5EA8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              unawaited(_saveSettings());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ إعدادات المطور والحركة')),
              );
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('حفظ الإعدادات الحالية'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF278E66),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => unawaited(_resetDeveloperSettings()),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('إعادة كل شيء إلى الافتراضي'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B2935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.08)),
          ),
          child: const Text(
            'زر النسخ يطلع بلوك SOOKY_ARCADE_LOBBY_VALUES كامل، بما فيه إعدادات الآركيد والتوهج وكاميرته، وكل Motion Track وكل نقطة حركة ومدتها وقيمها.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.3,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMotionPanel() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SafeArea(
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width * .92, 470.0).toDouble(),
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          decoration: BoxDecoration(
            color: const Color(0xF4111726),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x667A4BC2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.35),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 18, 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'إخفاء نافذة الحركة',
                      onPressed: () => setState(() => _motionPanelOpen = false),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'محرر الحركة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'نقاط حركة مستقلة مع زمن وتكرار وقيم قابلة للتعديل مباشرة.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.3,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x2FFFFFFF)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _toggleMotionPlayback,
                    icon: Icon(
                      _motionPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                    ),
                    label: Text(
                      _motionPlaying
                          ? 'إيقاف الحركة الديناميكية  •  Enter'
                          : 'تشغيل الحركة الديناميكية  •  Enter',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _motionPlaying
                          ? const Color(0xFFB2455B)
                          : const Color(0xFF7A4BC2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  children: [
                    _buildMotionSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    Widget action(
      String text,
      IconData icon,
      VoidCallback onTap, {
      Color? background,
      Color? foreground,
    }) {
      return Expanded(
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(text, textAlign: TextAlign.center),
          style: FilledButton.styleFrom(
            backgroundColor: background ?? const Color(0xFF1B2335),
            foregroundColor: foreground ?? Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            action('نسخ القيم', Icons.copy_all_rounded, () => unawaited(_copyCurrentValues()), background: const Color(0xFF2A5EA8)),
            const SizedBox(width: 10),
            action('حفظ', Icons.save_rounded, () {
              unawaited(_saveSettings());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ إعدادات المطور')),
              );
            }, background: const Color(0xFF278E66)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            action('إعادة الافتراضي', Icons.restart_alt_rounded, () => unawaited(_resetDeveloperSettings()), background: const Color(0xFF7B2935)),
          ],
        ),
      ],
    );
  }

  Widget _buildSceneSection() {
    return _buildTransformSection(
      title: 'المشهد والإضاءة',
      subtitle: 'إعدادات عامة سريعة لتوازن الجودة وشكل الإضاءة.',
      controls: [
        _numberControl(
          label: 'جودة الرندر',
          value: _renderScale,
          min: .35,
          max: 1.20,
          step: .01,
          onChanged: (v) => setState(() {
            _renderScale = v;
            _applyAllTransforms(repaint: false);
          }),
        ),
        _numberControl(
          label: 'سطوع المشهد',
          value: _sceneExposure,
          min: .30,
          max: 2.50,
          step: .01,
          onChanged: (v) => setState(() {
            _sceneExposure = v;
            _applyAllTransforms(repaint: false);
          }),
        ),
        _numberControl(
          label: 'شدة الإضاءة',
          value: _lightIntensity,
          min: .10,
          max: 5.00,
          step: .01,
          onChanged: (v) => setState(() {
            _lightIntensity = v;
            _applyAllTransforms(repaint: false);
          }),
        ),
        _tripleControl(
          prefix: 'اتجاه الإضاءة',
          xLabel: 'Yaw',
          yLabel: 'Pitch',
          zLabel: 'غير مستخدم',
          min: -180,
          max: 180,
          step: 1,
          x: _lightYawDeg,
          y: _lightPitchDeg,
          z: 0,
          onX: (v) => _lightYawDeg = v,
          onY: (v) => _lightPitchDeg = v,
          onZ: (_) {},
          disableZ: true,
        ),
      ],
    );
  }

  Widget _buildCameraSection() {
    return _buildTransformSection(
      title: 'الكاميرا عند دخول التطبيق',
      subtitle: 'اسحب داخل المشهد لتغيير النظر. الأسهم للحركة، Ctrl + الأسهم للرفع/الخفض والتحريك الأدق.',
      controls: [
        _numberControl(
          label: 'سرعة حركة الكاميرا',
          value: _cameraMoveSpeed,
          min: .1,
          max: 10,
          step: .1,
          onChanged: (v) => setState(() {
            _cameraMoveSpeed = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'حساسية الماوس/السحب',
          value: _mouseSensitivity,
          min: .0005,
          max: .0300,
          step: .0001,
          onChanged: (v) => setState(() {
            _mouseSensitivity = v;
            _scheduleSave();
          }),
        ),
        _tripleControl(
          prefix: 'موضع الكاميرا',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -20,
          max: 20,
          step: .02,
          x: _cameraX,
          y: _cameraY,
          z: _cameraZ,
          onX: (v) => _cameraX = v,
          onY: (v) => _cameraY = v,
          onZ: (v) => _cameraZ = v,
          afterChange: () => _syncCameraAnglesFromCurrentView(),
        ),
        _tripleControl(
          prefix: 'نقطة النظر',
          xLabel: 'X',
          yLabel: 'Y',
          zLabel: 'Z',
          min: -20,
          max: 20,
          step: .02,
          x: _targetX,
          y: _targetY,
          z: _targetZ,
          onX: (v) => _targetX = v,
          onY: (v) => _targetY = v,
          onZ: (v) => _targetZ = v,
          afterChange: () => _syncCameraAnglesFromCurrentView(),
        ),
        _numberControl(
          label: 'مجال الرؤية FOV',
          value: _cameraFov,
          min: 18,
          max: 110,
          step: 1,
          onChanged: (v) => setState(() {
            _cameraFov = v;
            _applyAllTransforms(repaint: false);
          }),
        ),
        const Divider(height: 26, color: Color(0x2FFFFFFF)),
        const Text('حدود النظر في وضع المستخدم — قبل الآركيد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('الحدود تعمل في وضع المستخدم فقط. أثناء تعديلها هنا يتم تشغيل معاينة مؤقتة فورًا من الكاميرا الأولية حتى يفحصها المطور، ثم ترجع الحرية الكاملة عند إنهاء المعاينة.', style: TextStyle(color: Colors.white70, fontSize: 12.2, height: 1.45)),
        const SizedBox(height: 10),
        _numberControl(label: 'الحد جهة اليسار', value: _mainLookLeftDeg, min: 0, max: 180, step: 1, onChanged: (v) { setState(() => _mainLookLeftDeg = v); _refreshLookLimitPreview(arcade: false); }),
        _numberControl(label: 'الحد جهة اليمين', value: _mainLookRightDeg, min: 0, max: 180, step: 1, onChanged: (v) { setState(() => _mainLookRightDeg = v); _refreshLookLimitPreview(arcade: false); }),
        _numberControl(label: 'الحد للأعلى', value: _mainLookUpDeg, min: 0, max: 89, step: 1, onChanged: (v) { setState(() => _mainLookUpDeg = v); _refreshLookLimitPreview(arcade: false); }),
        _numberControl(label: 'الحد للأسفل', value: _mainLookDownDeg, min: 0, max: 89, step: 1, onChanged: (v) { setState(() => _mainLookDownDeg = v); _refreshLookLimitPreview(arcade: false); }),
        const SizedBox(height: 8),
        const Text(
          'مرونة لمس الكاميرا',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _numberControl(
          label: 'الانزلاق بعد ترك الإصبع',
          value: _userLookInertia,
          min: .60,
          max: .98,
          step: .01,
          onChanged: (v) => setState(() {
            _userLookInertia = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'قوة استجابة السحب',
          value: _userLookInputBoost,
          min: 3,
          max: 40,
          step: 1,
          onChanged: (v) => setState(() {
            _userLookInputBoost = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'أقصى سرعة للانزلاق',
          value: _userLookMaxVelocityDeg,
          min: 20,
          max: 180,
          step: 5,
          onChanged: (v) => setState(() {
            _userLookMaxVelocityDeg = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'تجاوز الحد قبل الارتداد (درجة)',
          value: _userLookOverscrollDeg,
          min: 0,
          max: 5,
          step: .1,
          onChanged: (v) => setState(() {
            _userLookOverscrollDeg = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'قوة ارتداد الحد',
          value: _userLookSpringStrength,
          min: 5,
          max: 90,
          step: 1,
          onChanged: (v) => setState(() {
            _userLookSpringStrength = v;
            _scheduleSave();
          }),
        ),
        _numberControl(
          label: 'نعومة/تخميد الارتداد',
          value: _userLookSpringDamping,
          min: 1,
          max: 20,
          step: .5,
          onChanged: (v) => setState(() {
            _userLookSpringDamping = v;
            _scheduleSave();
          }),
        ),
        if (_lookLimitPreviewMode == 'main') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _finishLookLimitPreview,
              icon: const Icon(Icons.stop_circle_rounded),
              label: const Text('إنهاء معاينة حدود الكاميرا'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8A4E24),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!_initialCameraEditMode)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _beginInitialCameraEditing,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('تعيين الكاميرا الأولية بحرية'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF315A7D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        if (_initialCameraEditMode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x29315A7D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x88315A7D)),
            ),
            child: const Text(
              'تحرير الكاميرا الأولية شغّال الآن: حرّك بالأسهم، Ctrl + الأسهم للارتفاع/التحريك، واسحب بالماوس لتغيير النظر. Enter = تم، Esc = إلغاء. بعد الضغط على تم تبقى قيم البداية ثابتة ولا تتغير بأي حركة لاحقة.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.3,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _finishInitialCameraEditing,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('تم — تثبيت الكاميرا الأولية'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF198A61),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _cancelInitialCameraEditing,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('إلغاء'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMotionSection() {
    final selectedTrack = _motionTracks[_selectedTrackId];
    return _buildTransformSection(
      title: 'نقاط الحركة الديناميكية',
      subtitle: 'هنا تكدر تضيف نقاط حركة مع مدة زمنية وتتكرر تلقائيًا. تشتغل على الكاميرا، الماب، الشخصية، المشهد، أو أي عظم منفصل.',
      controls: [
        DropdownButtonFormField<String>(
          value: _selectedTrackId,
          dropdownColor: const Color(0xFF1B2335),
          decoration: _fieldDecoration('المسار المراد تحريكه'),
          items: _motionTracks.values
              .map(
                (track) => DropdownMenuItem<String>(
                  value: track.id,
                  child: Text(track.label, style: const TextStyle(color: Colors.white)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedTrackId = value;
              _scheduleSave();
            });
          },
        ),
        const SizedBox(height: 12),
        if (selectedTrack != null)
          _buildSwitchRow(
            label: 'تفعيل هذا المسار',
            value: selectedTrack.enabled,
            onChanged: (value) {
              setState(() => selectedTrack.enabled = value);
              _scheduleSave();
            },
          ),
        _buildSwitchRow(
          label: 'تكرار الحركة Loop',
          value: _motionLoop,
          onChanged: (value) {
            setState(() => _motionLoop = value);
            _scheduleSave();
          },
        ),
        _numberControl(
          label: 'المدة الافتراضية للنقطة الجديدة (ثانية)',
          value: _newKeyframeDuration,
          min: .10,
          max: 20.0,
          step: .10,
          onChanged: (v) => setState(() {
            _newKeyframeDuration = v;
            _scheduleSave();
          }),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _addCurrentKeyframe,
                icon: const Icon(Icons.add_circle_rounded),
                label: const Text('إضافة نقطة من القيم الحالية'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _clearSelectedTrack,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('مسح نقاط هذا المسار'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _motionPlaying
                ? 'الحركة شغّالة الآن. اضغط زر تشغيل/إيقاف الحركة لإيقافها.'
                : 'أضف نقطتين أو أكثر للمسار، ثم اضغط تشغيل الحركة. كل نقطة تستخدم مدة الانتقال الخاصة بها للوصول للنقطة التالية.',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
        ),
        const SizedBox(height: 12),
        if (selectedTrack == null || selectedTrack.keyframes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'لا توجد نقاط حركة لهذا المسار بعد.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ...List<Widget>.generate(selectedTrack.keyframes.length, (index) {
            final keyframe = selectedTrack.keyframes[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'النقطة ${index + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'رفع',
                        onPressed: index == 0
                            ? null
                            : () {
                                final temp = selectedTrack.keyframes[index - 1];
                                selectedTrack.keyframes[index - 1] = keyframe;
                                selectedTrack.keyframes[index] = temp;
                                _scheduleSave();
                                setState(() {});
                              },
                        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: 'خفض',
                        onPressed: index == selectedTrack.keyframes.length - 1
                            ? null
                            : () {
                                final temp = selectedTrack.keyframes[index + 1];
                                selectedTrack.keyframes[index + 1] = keyframe;
                                selectedTrack.keyframes[index] = temp;
                                _scheduleSave();
                                setState(() {});
                              },
                        icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: () {
                          selectedTrack.keyframes.removeAt(index);
                          _scheduleSave();
                          setState(() {});
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  _numberControl(
                    label: 'المدة للوصول إلى النقطة التالية (ثانية)',
                    value: keyframe.durationSeconds,
                    min: .05,
                    max: 20.0,
                    step: .05,
                    onChanged: (v) => setState(() {
                      keyframe.durationSeconds = v;
                      _scheduleSave();
                    }),
                  ),
                  _buildSnapshotEditor(selectedTrack.id, keyframe),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        keyframe.snapshot = _captureSnapshot(selectedTrack.id);
                        _scheduleSave();
                        setState(() {});
                      },
                      icon: const Icon(Icons.photo_camera_back_rounded, size: 18),
                      label: const Text('التقاط القيم الحالية داخل هذه النقطة'),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSnapshotEditor(String trackId, _MotionKeyframe keyframe) {
    final entries = keyframe.snapshot.values.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x241F8FFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x334A90E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'قيم هذه النقطة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            _numberControl(
              label: _motionValueLabel(entry.key),
              value: entry.value,
              min: _motionValueMin(entry.key),
              max: _motionValueMax(entry.key),
              step: _motionValueStep(entry.key),
              onChanged: (value) {
                final values = Map<String, double>.from(keyframe.snapshot.values);
                values[entry.key] = value;
                keyframe.snapshot = _TrackSnapshot(
                  values: values,
                  flags: Map<String, bool>.from(keyframe.snapshot.flags),
                );
                _scheduleSave();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  String _motionValueLabel(String key) {
    const labels = <String, String>{
      'cameraX': 'Camera X',
      'cameraY': 'Camera Y',
      'cameraZ': 'Camera Z',
      'targetX': 'Target X',
      'targetY': 'Target Y',
      'targetZ': 'Target Z',
      'cameraFov': 'FOV',
      'roomX': 'Map X',
      'roomY': 'Map Y',
      'roomZ': 'Map Z',
      'roomRotX': 'Map Rotation X',
      'roomRotY': 'Map Rotation Y',
      'roomRotZ': 'Map Rotation Z',
      'roomScaleX': 'Map Scale X',
      'roomScaleY': 'Map Scale Y',
      'roomScaleZ': 'Map Scale Z',
      'characterX': 'Character X',
      'characterY': 'Character Y',
      'characterZ': 'Character Z',
      'characterRotX': 'Character Rotation X',
      'characterRotY': 'Character Rotation Y',
      'characterRotZ': 'Character Rotation Z',
      'characterScaleX': 'Character Scale X',
      'characterScaleY': 'Character Scale Y',
      'characterScaleZ': 'Character Scale Z',
      'renderScale': 'Render Scale',
      'sceneExposure': 'Exposure',
      'lightIntensity': 'Light Intensity',
      'lightYawDeg': 'Light Yaw',
      'lightPitchDeg': 'Light Pitch',
      'rotX': 'Rotation X',
      'rotY': 'Rotation Y',
      'rotZ': 'Rotation Z',
      'offsetX': 'Offset X',
      'offsetY': 'Offset Y',
      'offsetZ': 'Offset Z',
    };
    return labels[key] ?? key;
  }

  double _motionValueMin(String key) {
    if (key.contains('Rot') || key.startsWith('rot') || key.contains('Yaw') || key.contains('Pitch')) return -180;
    if (key.contains('Scale') || key == 'renderScale') return .01;
    if (key == 'cameraFov') return 18;
    if (key == 'sceneExposure' || key == 'lightIntensity') return 0;
    if (key.startsWith('offset')) return -2.0;
    return -20.0;
  }

  double _motionValueMax(String key) {
    if (key.contains('Rot') || key.startsWith('rot') || key.contains('Yaw') || key.contains('Pitch')) return 180;
    if (key.contains('Scale')) return 4.0;
    if (key == 'renderScale') return 1.5;
    if (key == 'cameraFov') return 110;
    if (key == 'sceneExposure') return 3.0;
    if (key == 'lightIntensity') return 6.0;
    if (key.startsWith('offset')) return 2.0;
    return 20.0;
  }

  double _motionValueStep(String key) {
    if (key.contains('Rot') || key.startsWith('rot') || key.contains('Yaw') || key.contains('Pitch')) return 1.0;
    if (key.contains('Scale') || key == 'renderScale' || key == 'sceneExposure' || key == 'lightIntensity') return .01;
    if (key == 'cameraFov') return 1.0;
    return .01;
  }

  Widget _buildPoseSection() {
    return _buildTransformSection(
      title: 'وضعية الجسم بالتفصيل',
      subtitle: 'التحكم يشمل الرأس، الجذع، الكتفين، الذراعين، الساعدين، اليدين، الفخذين، الساقين والقدمين. كل جزء لديه دوران وإزاحة مستقلة ويمكن كذلك عمل نقاط حركة له من قسم الحركة.',
      controls: [
        for (final tuning in _poseTunings) _buildPoseTile(tuning),
      ],
    );
  }

  Widget _buildPoseTile(_PoseTuning tuning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: ExpansionTile(
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(
          tuning.label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          tuning.nodeName,
          style: const TextStyle(color: Colors.white54, fontSize: 11.5),
        ),
        children: [
          _tripleControl(
            prefix: 'دوران ${tuning.label}',
            xLabel: 'X',
            yLabel: 'Y',
            zLabel: 'Z',
            min: -180,
            max: 180,
            step: 1,
            x: tuning.rotX,
            y: tuning.rotY,
            z: tuning.rotZ,
            onX: (v) => tuning.rotX = v,
            onY: (v) => tuning.rotY = v,
            onZ: (v) => tuning.rotZ = v,
          ),
          _tripleControl(
            prefix: 'إزاحة ${tuning.label}',
            xLabel: 'X',
            yLabel: 'Y',
            zLabel: 'Z',
            min: -1.5,
            max: 1.5,
            step: .01,
            x: tuning.offsetX,
            y: tuning.offsetY,
            z: tuning.offsetZ,
            onX: (v) => tuning.offsetX = v,
            onY: (v) => tuning.offsetY = v,
            onZ: (v) => tuning.offsetZ = v,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  tuning
                    ..rotX = 0
                    ..rotY = 0
                    ..rotZ = 0
                    ..offsetX = 0
                    ..offsetY = 0
                    ..offsetZ = 0;
                  _applyAllTransforms(repaint: false);
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إرجاع هذا الجزء للوضع الافتراضي'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFFE5A93A)),
      ),
    );
  }

  Widget _buildTransformSection({
    required String title,
    required String subtitle,
    required List<Widget> controls,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161D2C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12.2, height: 1.45),
          ),
          const SizedBox(height: 12),
          ...controls,
        ],
      ),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFE5A93A),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _switchTile(label, value, onChanged),
    );
  }

  String _formatEditableNumber(double value, int decimals) {
    if (decimals <= 0) return value.round().toString();
    return value.toStringAsFixed(decimals);
  }

  double? _parseEditableNumber(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty || normalized == '-' || normalized == '.' || normalized == '-.') {
      return null;
    }
    return double.tryParse(normalized);
  }

  InputDecoration _compactNumberDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white.withOpacity(.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5A93A), width: 1.4),
      ),
    );
  }


  Widget _stringControl({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('text:$label:$value'),
            initialValue: value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white),
            decoration: _compactNumberDecoration().copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onFieldSubmitted: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _colorGroup({
    required String title,
    required double r,
    required double g,
    required double b,
    required ValueChanged<double> onR,
    required ValueChanged<double> onG,
    required ValueChanged<double> onB,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _tripleControl(
            prefix: 'RGB',
            xLabel: 'R',
            yLabel: 'G',
            zLabel: 'B',
            min: 0,
            max: 255,
            step: 1,
            x: r,
            y: g,
            z: b,
            onX: onR,
            onY: onG,
            onZ: onB,
          ),
        ],
      ),
    );
  }

  Widget _screenElementLayoutControl({
    required String title,
    required double x,
    required double y,
    required double scale,
    required ValueChanged<double> onX,
    required ValueChanged<double> onY,
    required ValueChanged<double> onScale,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _axisControl(
            label: 'X',
            value: x,
            min: -500,
            max: 500,
            step: .5,
            onChanged: (v) {
              setState(() {
                onX(v);
                _requestArcadeDisplayRefresh();
              });
            },
          ),
          _axisControl(
            label: 'Y',
            value: y,
            min: -500,
            max: 500,
            step: .5,
            onChanged: (v) {
              setState(() {
                onY(v);
                _requestArcadeDisplayRefresh();
              });
            },
          ),
          _axisControl(
            label: 'الحجم',
            value: scale.clamp(.1, 5).toDouble(),
            min: .1,
            max: 5,
            step: .05,
            onChanged: (v) {
              setState(() {
                onScale(v);
                _requestArcadeDisplayRefresh();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _numberControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
  }) {
    final decimals = step >= 1 ? 0 : (step >= .1 ? 1 : (step >= .01 ? 2 : 4));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 96,
                child: TextFormField(
                  key: ValueKey('number:$label:${value.toStringAsFixed(6)}'),
                  initialValue: _formatEditableNumber(value, decimals),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
                  decoration: _compactNumberDecoration(),
                  onFieldSubmitted: (raw) {
                    final parsed = _parseEditableNumber(raw);
                    if (parsed != null) onChanged(parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max).toDouble()),
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFE5A93A),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: const Color(0x29E5A93A),
                  ),
                  child: Slider(
                    value: value.clamp(min, max).toDouble(),
                    min: min,
                    max: max,
                    onChanged: (newValue) {
                      final snapped = ((newValue - min) / step).round() * step + min;
                      onChanged(snapped.clamp(min, max).toDouble());
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max).toDouble()),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripleControl({
    required String prefix,
    required String xLabel,
    required String yLabel,
    required String zLabel,
    required double min,
    required double max,
    required double step,
    required double x,
    required double y,
    required double z,
    required ValueChanged<double> onX,
    required ValueChanged<double> onY,
    required ValueChanged<double> onZ,
    bool disableZ = false,
    VoidCallback? afterChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _axisControl(
          label: xLabel,
          value: x,
          min: min,
          max: max,
          step: step,
          onChanged: (v) {
            setState(() {
              onX(v);
              afterChange?.call();
              _applyAllTransforms(repaint: false);
            });
          },
        ),
        _axisControl(
          label: yLabel,
          value: y,
          min: min,
          max: max,
          step: step,
          onChanged: (v) {
            setState(() {
              onY(v);
              afterChange?.call();
              _applyAllTransforms(repaint: false);
            });
          },
        ),
        _axisControl(
          label: zLabel,
          value: z,
          min: min,
          max: max,
          step: step,
          enabled: !disableZ,
          onChanged: (v) {
            if (disableZ) return;
            setState(() {
              onZ(v);
              afterChange?.call();
              _applyAllTransforms(repaint: false);
            });
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _axisControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    final decimals = step >= 1 ? 0 : (step >= .1 ? 1 : (step >= .01 ? 2 : 4));
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12.6),
            ),
          ),
          IconButton(
            onPressed: !enabled || value <= min ? null : () => onChanged((value - step).clamp(min, max).toDouble()),
            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFE5A93A),
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: const Color(0x33E5A93A),
                trackHeight: 3.5,
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: !enabled
                    ? null
                    : (newValue) {
                        final snapped = ((newValue - min) / step).round() * step + min;
                        onChanged(snapped.clamp(min, max).toDouble());
                      },
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: TextFormField(
              key: ValueKey('axis:$label:${value.toStringAsFixed(6)}'),
              initialValue: _formatEditableNumber(value, decimals),
              enabled: enabled,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12.2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
              decoration: _compactNumberDecoration(),
              onFieldSubmitted: (raw) {
                final parsed = _parseEditableNumber(raw);
                if (parsed != null && enabled) onChanged(parsed);
              },
            ),
          ),
          IconButton(
            onPressed: !enabled || value >= max ? null : () => onChanged((value + step).clamp(min, max).toDouble()),
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

}

class _PoseTuning {
  _PoseTuning({required this.label, required this.nodeName});

  final String label;
  final String nodeName;

  double rotX = 0;
  double rotY = 0;
  double rotZ = 0;
  double offsetX = 0;
  double offsetY = 0;
  double offsetZ = 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'nodeName': nodeName,
        'rotX': rotX,
        'rotY': rotY,
        'rotZ': rotZ,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'offsetZ': offsetZ,
      };
}


enum _TvScreenAction { none, back, offline, online, info }

class _TvExpandedGamePage extends StatelessWidget {
  const _TvExpandedGamePage({
    required this.title,
    required this.modeLabel,
    required this.root,
  });

  final String title;
  final String modeLabel;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060A10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFC547),
          secondary: Color(0xFF27C38A),
          surface: Color(0xFF101820),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1118),
          hintStyle: const TextStyle(color: Color(0xFF818894)),
          labelStyle: const TextStyle(color: Color(0xFFB8BEC7)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF5F6670)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFFFC547), width: 1.8),
          ),
        ),
      ),
      child: root,
    );
  }
}

class _TvTornClipper extends CustomClipper<ui.Path> {
  const _TvTornClipper({required this.edge});
  final double edge;

  @override
  ui.Path getClip(ui.Size size) {
    final path = ui.Path();
    final step = math.max(14.0, edge * 1.25);

    double wobble(int i, double amount) =>
        math.sin(i * 2.17) * amount +
        math.sin(i * .79 + 1.4) * amount * .42;

    path.moveTo(edge + 2, edge);

    var i = 0;
    for (double x = edge; x <= size.width - edge; x += step) {
      path.lineTo(
        x,
        edge + wobble(i++, edge * .36),
      );
    }

    i = 0;
    for (double y = edge; y <= size.height - edge; y += step) {
      path.lineTo(
        size.width - edge + wobble(i++, edge * .36),
        y,
      );
    }

    i = 0;
    for (double x = size.width - edge; x >= edge; x -= step) {
      path.lineTo(
        x,
        size.height - edge + wobble(i++, edge * .36),
      );
    }

    i = 0;
    for (double y = size.height - edge; y >= edge; y -= step) {
      path.lineTo(
        edge + wobble(i++, edge * .36),
        y,
      );
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TvTornClipper oldClipper) =>
      oldClipper.edge != edge;
}

class _TvScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(.08);
    for (double y = 0; y < size.height; y += 7) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcadeGameEntry {
  final String title;
  final String subtitle;
  final String icon;
  final String coverAsset;
  final bool isBack;
  final bool hasOffline;
  final bool hasOnline;
  final String detailsTitle;
  final String detailsText;

  const _ArcadeGameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.coverAsset,
    this.isBack = false,
    this.hasOffline = true,
    this.hasOnline = false,
    this.detailsTitle = '',
    this.detailsText = '',
  });
}

class _NodeSnapshot {
  _NodeSnapshot({required this.position, required this.rotation});

  final vm.Vector3 position;
  final vm.Quaternion rotation;

  factory _NodeSnapshot.fromNode(Node node) {
    return _NodeSnapshot(
      position: vm.Vector3(node.position.x, node.position.y, node.position.z),
      rotation: vm.Quaternion.copy(node.rotation),
    );
  }
}

class _TrackSnapshot {
  const _TrackSnapshot({this.values = const <String, double>{}, this.flags = const <String, bool>{}});

  final Map<String, double> values;
  final Map<String, bool> flags;

  factory _TrackSnapshot.empty() => const _TrackSnapshot();

  Map<String, dynamic> toJson() => <String, dynamic>{'values': values, 'flags': flags};

  factory _TrackSnapshot.fromJson(Map<String, dynamic> json) {
    final values = <String, double>{};
    final rawValues = json['values'];
    if (rawValues is Map) {
      for (final entry in rawValues.entries) {
        final value = entry.value;
        if (value is num) values[entry.key.toString()] = value.toDouble();
      }
    }
    final flags = <String, bool>{};
    final rawFlags = json['flags'];
    if (rawFlags is Map) {
      for (final entry in rawFlags.entries) {
        final value = entry.value;
        if (value is bool) flags[entry.key.toString()] = value;
      }
    }
    return _TrackSnapshot(values: values, flags: flags);
  }
}

class _MotionKeyframe {
  _MotionKeyframe({required this.durationSeconds, required this.snapshot});

  double durationSeconds;
  _TrackSnapshot snapshot;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'durationSeconds': durationSeconds,
        'snapshot': snapshot.toJson(),
      };

  factory _MotionKeyframe.fromJson(Map<String, dynamic> json) {
    return _MotionKeyframe(
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 1.0,
      snapshot: json['snapshot'] is Map<String, dynamic>
          ? _TrackSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>)
          : _TrackSnapshot.empty(),
    );
  }
}

class _MotionTrack {
  _MotionTrack({required this.id, required this.label, this.enabled = true, List<_MotionKeyframe>? keyframes})
      : keyframes = keyframes ?? <_MotionKeyframe>[];

  final String id;
  final String label;
  bool enabled;
  List<_MotionKeyframe> keyframes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'enabled': enabled,
        'keyframes': keyframes.map((e) => e.toJson()).toList(),
      };

  factory _MotionTrack.fromJson(Map<String, dynamic> json) {
    final rawKeyframes = json['keyframes'];
    return _MotionTrack(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      enabled: json['enabled'] == true,
      keyframes: rawKeyframes is List
          ? rawKeyframes
              .whereType<Map<String, dynamic>>()
              .map(_MotionKeyframe.fromJson)
              .toList()
          : <_MotionKeyframe>[],
    );
  }
}

class _MotionSampleResult {
  _MotionSampleResult({required this.snapshot, required this.finished});

  final _TrackSnapshot snapshot;
  final bool finished;
}

List<_PoseTuning> _buildDefaultPoseTunings() {
  return <_PoseTuning>[
    _PoseTuning(label: 'الحوض', nodeName: 'Hips'),
    _PoseTuning(label: 'العمود الفقري السفلي', nodeName: 'Spine'),
    _PoseTuning(label: 'العمود الفقري العلوي', nodeName: 'Spine1'),
    _PoseTuning(label: 'الرقبة', nodeName: 'Neck'),
    _PoseTuning(label: 'الرأس', nodeName: 'Head'),
    _PoseTuning(label: 'الكتف الأيسر', nodeName: 'LeftShoulder'),
    _PoseTuning(label: 'الذراع الأيسر', nodeName: 'LeftArm'),
    _PoseTuning(label: 'الساعد الأيسر', nodeName: 'LeftForeArm'),
    _PoseTuning(label: 'اليد اليسرى', nodeName: 'LeftHand'),
    _PoseTuning(label: 'الكتف الأيمن', nodeName: 'RightShoulder'),
    _PoseTuning(label: 'الذراع الأيمن', nodeName: 'RightArm'),
    _PoseTuning(label: 'الساعد الأيمن', nodeName: 'RightForeArm'),
    _PoseTuning(label: 'اليد اليمنى', nodeName: 'RightHand'),
    _PoseTuning(label: 'الفخذ الأيسر', nodeName: 'LeftUpLeg'),
    _PoseTuning(label: 'الساق اليسرى', nodeName: 'LeftLeg'),
    _PoseTuning(label: 'القدم اليسرى', nodeName: 'LeftFoot'),
    _PoseTuning(label: 'الفخذ الأيمن', nodeName: 'RightUpLeg'),
    _PoseTuning(label: 'الساق اليمنى', nodeName: 'RightLeg'),
    _PoseTuning(label: 'القدم اليمنى', nodeName: 'RightFoot'),
  ];
}


class _ArcadeGlowBandNode {
  _ArcadeGlowBandNode({
    required this.node,
    required this.material,
    required this.bandIndex,
    required this.segmentIndex,
  });

  final Node node;
  final UnlitMaterial material;
  final int bandIndex;
  final int segmentIndex;
}

class _ArcadeCutPart {
  _ArcadeCutPart({
    required this.id,
    required this.node,
    required this.originalMaterial,
    required this.triangleIds,
    required this.baseX,
    required this.baseY,
    required this.baseZ,
  });

  final int id;
  final Node node;
  final fs.Material originalMaterial;
  final List<int> triangleIds;
  final double baseX;
  final double baseY;
  final double baseZ;

  UnlitMaterial? customMaterial;

  String get label => 'مقصوص $id';

  bool visible = true;
  double x = 0;
  double y = 0;
  double z = 0;
  double rotX = 0;
  double rotY = 0;
  double rotZ = 0;
  double scaleX = 1;
  double scaleY = 1;
  double scaleZ = 1;

  bool colorEnabled = false;
  double colorR = 255;
  double colorG = 255;
  double colorB = 255;
  double colorOpacity = 1;

  bool glowEnabled = false;
  double glowR = 0;
  double glowG = 220;
  double glowB = 255;
  double glowIntensity = .85;
}
