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
import '../heads_up/heads_up_setup_screen.dart';
import '../killer_killed/killer_killed_home_screen.dart';
import '../guess_time/guess_time_home_screen.dart';

class ArcadeLobbyScreen extends StatefulWidget {
  const ArcadeLobbyScreen({super.key});

  @override
  State<ArcadeLobbyScreen> createState() => _ArcadeLobbyScreenState();
}

class _ArcadeLobbyScreenState extends State<ArcadeLobbyScreen> {
  static const String _prefsKey = 'arcade_lobby_developer_settings_v14';

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
    ),
    _ArcadeGameEntry(
      title: 'خمن اللي براسي',
      subtitle: 'ضع الهاتف على رأسك ودع المجموعة تساعدك على التخمين.',
      icon: '🧠',
    ),
    _ArcadeGameEntry(
      title: 'قاتل ومقتول',
      subtitle: 'تحرّك بسرعة واكشف موقع خصومك قبل انتهاء الوقت.',
      icon: '🎯',
    ),
    _ArcadeGameEntry(
      title: 'خمن الوقت',
      subtitle: 'احفظ الوقت المطلوب واضغط في اللحظة الأقرب للفوز.',
      icon: '⏱',
    ),
  ];

  SharedPreferences? _prefs;
  Timer? _saveTimer;
  Timer? _engineTimer;
  DateTime? _lastTickAt;

  Node? _roomNode;
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
  MeshGeometry? _arcadeDisplaySurfaceGeometry;
  Node? _arcadeJoystickPressHitboxNode;
  UnlitMaterial? _arcadeJoystickPressHitboxMaterial;
  bool _arcadeDisplayDirty = true;
  bool _arcadeDisplayRefreshInFlight = false;
  bool _arcadeDisplayEnabled = true;
  String _arcadeDisplaySideTitle = 'سوكي';
  String _arcadeDisplayCenterTitle = 'اختر لعبتك';
  int _arcadeSelectedGameIndex = 0;
  double _arcadeDisplayBgR = 0.0;
  double _arcadeDisplayBgG = 54.0;
  double _arcadeDisplayBgB = 49.0;
  double _arcadeDisplayHeaderR = 62.0;
  double _arcadeDisplayHeaderG = 152.0;
  double _arcadeDisplayHeaderB = 160.0;
  double _arcadeDisplayAccentR = 0.0;
  double _arcadeDisplayAccentG = 255.0;
  double _arcadeDisplayAccentB = 65.0;
  double _arcadeDisplayCardR = 255.0;
  double _arcadeDisplayCardG = 152.0;
  double _arcadeDisplayCardB = 0.0;
  double _arcadeDisplaySelectedCardR = 0.0;
  double _arcadeDisplaySelectedCardG = 141.0;
  double _arcadeDisplaySelectedCardB = 0.0;
  double _arcadeDisplayTextR = 255.0;
  double _arcadeDisplayTextG = 255.0;
  double _arcadeDisplayTextB = 255.0;
  double _arcadeDisplaySubtextR = 197.0;
  double _arcadeDisplaySubtextG = 205.0;
  double _arcadeDisplaySubtextB = 229.0;
  double _arcadeDisplayArrowR = 255.0;
  double _arcadeDisplayArrowG = 213.0;
  double _arcadeDisplayArrowB = 96.0;
  double _arcadeDisplayFrameR = 124.0;
  double _arcadeDisplayFrameG = 255.0;
  double _arcadeDisplayFrameB = 223.0;
  bool _arcadeDisplayShowSubtitle = true;
  double _arcadeDisplayHeaderOffsetX = 0.0;
  double _arcadeDisplayHeaderOffsetY = 0.0;
  double _arcadeDisplayHeaderScale = 1.50;
  double _arcadeDisplaySideTitleOffsetX = 0.0;
  double _arcadeDisplaySideTitleOffsetY = 0.0;
  double _arcadeDisplaySideTitleScale = 1.95;
  double _arcadeDisplayCenterTitleOffsetX = 0.0;
  double _arcadeDisplayCenterTitleOffsetY = 20.50;
  double _arcadeDisplayCenterTitleScale = 1.85;
  double _arcadeDisplayCurrentGameOffsetX = -76.0;
  double _arcadeDisplayCurrentGameOffsetY = 0.0;
  double _arcadeDisplayCurrentGameScale = 2.0;
  double _arcadeDisplayCardsOffsetX = 0.0;
  double _arcadeDisplayCardsOffsetY = 103.50;
  double _arcadeDisplayCardsScale = 2.35;
  double _arcadeDisplayCardsGapScale = 1.0;
  double _arcadeDisplayArrowsOffsetX = -48.50;
  double _arcadeDisplayArrowsOffsetY = -157.0;
  double _arcadeDisplayArrowsScale = 1.0;
  double _arcadeDisplayDotsOffsetX = 0.0;
  double _arcadeDisplayDotsOffsetY = 145.0;
  double _arcadeDisplayDotsScale = .10;
  double _arcadeDisplayHintOffsetX = -20.5;
  double _arcadeDisplayHintOffsetY = 400.0;
  double _arcadeDisplayHintScale = .10;

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
  bool _arcadeJoystickAnimating = false;
  double _arcadeJoystickAnimElapsed = 0.0;
  double _arcadeJoystickAnimDirection = 0.0;

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

    _cameraX = 1.3675;
    _cameraY = 4.0117;
    _cameraZ = -0.6627;
    _targetX = 0.1677;
    _targetY = 3.2981;
    _targetZ = -1.1725;
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

    _mainLookLeftDeg = 8.0;
    _mainLookRightDeg = 12.0;
    _mainLookUpDeg = 4.0;
    _mainLookDownDeg = 20.0;
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
    _arcadeScreenX = 0.0;
    _arcadeScreenY = -0.0;
    _arcadeScreenZ = 0.0700;
    _arcadeScreenRotX = 0.0;
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
    _arcadeSelectedGameIndex = 0;
    _arcadeDisplayBgR = 0;
    _arcadeDisplayBgG = 54;
    _arcadeDisplayBgB = 49;
    _arcadeDisplayHeaderR = 62;
    _arcadeDisplayHeaderG = 152;
    _arcadeDisplayHeaderB = 160;
    _arcadeDisplayAccentR = 0;
    _arcadeDisplayAccentG = 255;
    _arcadeDisplayAccentB = 65;
    _arcadeDisplayCardR = 255;
    _arcadeDisplayCardG = 152;
    _arcadeDisplayCardB = 0;
    _arcadeDisplaySelectedCardR = 0;
    _arcadeDisplaySelectedCardG = 141;
    _arcadeDisplaySelectedCardB = 0;
    _arcadeDisplayTextR = 255;
    _arcadeDisplayTextG = 255;
    _arcadeDisplayTextB = 255;
    _arcadeDisplaySubtextR = 197;
    _arcadeDisplaySubtextG = 205;
    _arcadeDisplaySubtextB = 229;
    _arcadeDisplayArrowR = 255;
    _arcadeDisplayArrowG = 213;
    _arcadeDisplayArrowB = 96;
    _arcadeDisplayShowSubtitle = true;
    _arcadeDisplayHeaderOffsetX = 0;
    _arcadeDisplayHeaderOffsetY = 0;
    _arcadeDisplayHeaderScale = 1.50;
    _arcadeDisplaySideTitleOffsetX = 0;
    _arcadeDisplaySideTitleOffsetY = 0;
    _arcadeDisplaySideTitleScale = 1.95;
    _arcadeDisplayCenterTitleOffsetX = 0;
    _arcadeDisplayCenterTitleOffsetY = 20.50;
    _arcadeDisplayCenterTitleScale = 1.85;
    _arcadeDisplayCurrentGameOffsetX = -76;
    _arcadeDisplayCurrentGameOffsetY = 0;
    _arcadeDisplayCurrentGameScale = 2.00;
    _arcadeDisplayCardsOffsetX = 0;
    _arcadeDisplayCardsOffsetY = 103.50;
    _arcadeDisplayCardsScale = 2.35;
    _arcadeDisplayCardsGapScale = 1.00;
    _arcadeDisplayArrowsOffsetX = -48.50;
    _arcadeDisplayArrowsOffsetY = -157.00;
    _arcadeDisplayArrowsScale = 1.00;
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
      ..rotX = 9
      ..rotY = 8
      ..rotZ = -1
      ..offsetX = -.0100;
    _pose('Head')
      ..rotX = -7
      ..rotY = -46
      ..rotZ = -3
      ..offsetY = -.0200
      ..offsetZ = .0100;
    _pose('LeftShoulder')..rotX = 15.28;
    _pose('LeftArm')
      ..rotX = -59
      ..rotY = 14;
    _pose('LeftForeArm')..rotX = 49;
    _pose('RightShoulder')..rotX = 5.19;
    _pose('RightArm')
      ..rotX = -46
      ..rotY = 3
      ..rotZ = 30
      ..offsetY = .0200;
    _pose('RightForeArm')
      ..rotX = 25.28
      ..rotY = 11.29
      ..rotZ = 66.36
      ..offsetX = -.0120
      ..offsetZ = -.0157;
    _pose('RightHand')
      ..rotX = 8
      ..rotY = -38
      ..rotZ = -38
      ..offsetX = -.0700;
    _pose('LeftUpLeg')..rotZ = -70;
    _pose('LeftLeg')..rotZ = 75.65;
    _pose('RightUpLeg')..rotZ = 70;
    _pose('RightLeg')..rotZ = -70.64;

    _arcadeHighlightVisible = false;
    _arcadeX = -2.1700;
    _arcadeY = 1.6800;
    _arcadeZ = -2.1300;
    _arcadeRotX = 0.0;
    _arcadeRotY = -25.0;
    _arcadeRotZ = 5.0;
    _arcadeSizeX = 1.5800;
    _arcadeSizeY = 3.3600;
    _arcadeSizeZ = 1.4500;
    _arcadeGlowThickness = .0050;
    _arcadeGlowIntensity = .7500;
    _arcadeGlowOpacity = .5000;
    _arcadeGlowR = 29;
    _arcadeGlowG = 255;
    _arcadeGlowB = 0;

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
      _updateArcadeGlowMaterial();
      if (_arcadeDisplayDirty && !_arcadeDisplayRefreshInFlight) {
        unawaited(_refreshArcadeDisplayTexture());
      }

      var changed = _tickArcadeJoystickAnimation(dt);
      if (_arcadeCameraAnimating) {
        changed = _tickArcadeCameraTransition(dt) || changed;
      } else {
        changed = _tickKeyboardMovement(dt) || changed;
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
      await _loadCharacter();
      await _buildSpaceBackdrop();
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

  Future<Texture2D> _makeArcadeDisplayTexture() async {
    const width = 1024;
    const height = 768;
    const textureScale = 1.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(textureScale);
    final logicalSize = ui.Size(width / textureScale, height / textureScale);

    final bg = _rgb(_arcadeDisplayBgR, _arcadeDisplayBgG, _arcadeDisplayBgB);
    final header =
        _rgb(_arcadeDisplayHeaderR, _arcadeDisplayHeaderG, _arcadeDisplayHeaderB);
    final accent =
        _rgb(_arcadeDisplayAccentR, _arcadeDisplayAccentG, _arcadeDisplayAccentB);
    final card = _rgb(_arcadeDisplayCardR, _arcadeDisplayCardG, _arcadeDisplayCardB);
    final selectedCard = _rgb(
      _arcadeDisplaySelectedCardR,
      _arcadeDisplaySelectedCardG,
      _arcadeDisplaySelectedCardB,
    );
    final textColor =
        _rgb(_arcadeDisplayTextR, _arcadeDisplayTextG, _arcadeDisplayTextB);
    final subColor = _rgb(
      _arcadeDisplaySubtextR,
      _arcadeDisplaySubtextG,
      _arcadeDisplaySubtextB,
    );
    final arrowColor =
        _rgb(_arcadeDisplayArrowR, _arcadeDisplayArrowG, _arcadeDisplayArrowB);

    double clampScale(double value, [double min = .1, double max = 5]) =>
        value.clamp(min, max).toDouble();

    Rect rectFromCenter({
      required double cx,
      required double cy,
      required double width,
      required double height,
    }) => Rect.fromCenter(center: Offset(cx, cy), width: width, height: height);

    void paintText(
      String value, {
      required Rect rect,
      required double fontSize,
      required Color color,
      FontWeight fontWeight = FontWeight.w700,
      TextAlign align = TextAlign.center,
      int? maxLines,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: align,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: rect.width);
      painter.paint(
        canvas,
        Offset(rect.left + (rect.width - painter.width) * .5, rect.top),
      );
    }

    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(18, 18, logicalSize.width - 36, logicalSize.height - 36),
      const Radius.circular(28),
    );
    canvas.drawRRect(outer, Paint()..color = bg);

    final gridPaint = Paint()..color = accent.withOpacity(.05);
    for (double x = 36; x < logicalSize.width - 36; x += 36) {
      canvas.drawRect(
        Rect.fromLTWH(x, 36, 2, logicalSize.height - 72),
        gridPaint,
      );
    }
    for (double y = 36; y < logicalSize.height - 36; y += 30) {
      canvas.drawRect(
        Rect.fromLTWH(36, y, logicalSize.width - 72, 2),
        gridPaint,
      );
    }

    final headerScale = clampScale(_arcadeDisplayHeaderScale, .4, 3);
    final headerRect = RRect.fromRectAndRadius(
      rectFromCenter(
        cx: logicalSize.width * .5 + _arcadeDisplayHeaderOffsetX,
        cy: 103 + _arcadeDisplayHeaderOffsetY,
        width: (logicalSize.width - 108) * headerScale,
        height: 110 * headerScale,
      ),
      Radius.circular(24 * headerScale),
    );
    canvas.drawRRect(headerRect, Paint()..color = header);

    final accentBarRect = rectFromCenter(
      cx: headerRect.left + 21 * headerScale,
      cy: headerRect.center.dy,
      width: 18 * headerScale,
      height: 42 * headerScale,
    );
    canvas.drawRect(accentBarRect, Paint()..color = accent);

    final sideScale = clampScale(_arcadeDisplaySideTitleScale, .25, 4);
    paintText(
      _arcadeDisplaySideTitle,
      rect: Rect.fromLTWH(
        headerRect.left + 50 * headerScale + _arcadeDisplaySideTitleOffsetX,
        headerRect.top + 16 * headerScale + _arcadeDisplaySideTitleOffsetY,
        headerRect.width - 100 * headerScale,
        46 * sideScale,
      ),
      fontSize: 34 * sideScale,
      color: textColor,
      fontWeight: FontWeight.w900,
    );

    final centerScale = clampScale(_arcadeDisplayCenterTitleScale, .25, 4);
    paintText(
      _arcadeDisplayCenterTitle,
      rect: Rect.fromLTWH(
        headerRect.left + 50 * headerScale + _arcadeDisplayCenterTitleOffsetX,
        headerRect.top + 60 * headerScale + _arcadeDisplayCenterTitleOffsetY,
        headerRect.width - 100 * headerScale,
        36 * centerScale,
      ),
      fontSize: 23 * centerScale,
      color: subColor,
      fontWeight: FontWeight.w700,
    );

    final current =
        _arcadeGames[_arcadeSelectedGameIndex.clamp(0, _arcadeGames.length - 1).toInt()];
    final currentScale = clampScale(_arcadeDisplayCurrentGameScale, .25, 4);
    paintText(
      'اسم اللعبة',
      rect: Rect.fromLTWH(
        logicalSize.width - 230 + _arcadeDisplayCurrentGameOffsetX,
        58 + _arcadeDisplayCurrentGameOffsetY,
        150 * currentScale,
        26 * currentScale,
      ),
      fontSize: 16 * currentScale,
      color: accent,
      fontWeight: FontWeight.w800,
      align: TextAlign.right,
    );
    paintText(
      current.title,
      rect: Rect.fromLTWH(
        logicalSize.width - 320 + _arcadeDisplayCurrentGameOffsetX,
        86 + _arcadeDisplayCurrentGameOffsetY,
        240 * currentScale,
        34 * currentScale,
      ),
      fontSize: 21 * currentScale,
      color: textColor,
      fontWeight: FontWeight.w800,
      align: TextAlign.right,
    );

    final cardsScale = clampScale(_arcadeDisplayCardsScale, .35, 4);
    final cardsGapScale = clampScale(_arcadeDisplayCardsGapScale, .2, 4);
    final baseY = 420.0 + _arcadeDisplayCardsOffsetY;
    final cardW = 170.0 * cardsScale;
    final cardH = 210.0 * cardsScale;
    final gap = 24.0 * cardsGapScale;
    final startX = (logicalSize.width - (cardW * 3 + gap * 2)) * .5 +
        _arcadeDisplayCardsOffsetX;

    _ArcadeGameEntry gameAt(int offset) {
      final len = _arcadeGames.length;
      final raw = (_arcadeSelectedGameIndex + offset) % len;
      final index = raw < 0 ? raw + len : raw;
      return _arcadeGames[index];
    }

    for (var i = 0; i < 3; i++) {
      final offset = i - 1;
      final game = gameAt(offset);
      final selected = offset == 0;
      final left = startX + i * (cardW + gap);
      final currentCardW = cardW * (selected ? 1.02 : .92);
      final currentCardH = cardH * (selected ? 1.08 : .9);
      final top = baseY - currentCardH / 2 - (selected ? 20 * cardsScale : 0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, currentCardW, currentCardH),
        Radius.circular(22 * cardsScale),
      );
      canvas.drawRRect(rect, Paint()..color = selected ? selectedCard : card);
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 6 * cardsScale.clamp(.6, 1.5) : 3.2
          ..color = selected ? accent : Colors.white.withOpacity(.12),
      );

      paintText(
        game.icon,
        rect: Rect.fromLTWH(
          left + 12 * cardsScale,
          top + 10 * cardsScale,
          currentCardW - 24 * cardsScale,
          56 * cardsScale,
        ),
        fontSize: (selected ? 34 : 28) * cardsScale,
        color: textColor,
        fontWeight: FontWeight.w700,
      );
      paintText(
        game.title,
        rect: Rect.fromLTWH(
          left + 12 * cardsScale,
          top + 66 * cardsScale,
          currentCardW - 24 * cardsScale,
          72 * cardsScale,
        ),
        fontSize: (selected ? 22 : 18) * cardsScale,
        color: textColor,
        fontWeight: FontWeight.w900,
        maxLines: 2,
      );
      if (_arcadeDisplayShowSubtitle) {
        paintText(
          game.subtitle,
          rect: Rect.fromLTWH(
            left + 16 * cardsScale,
            top + 125 * cardsScale,
            currentCardW - 32 * cardsScale,
            72 * cardsScale,
          ),
          fontSize: (selected ? 13.5 : 12) * cardsScale,
          color: subColor,
          fontWeight: FontWeight.w700,
          maxLines: 3,
        );
      }
      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left + 18 * cardsScale,
          top + currentCardH - 34 * cardsScale,
          currentCardW - 36 * cardsScale,
          24 * cardsScale,
        ),
        Radius.circular(12 * cardsScale),
      );
      canvas.drawRRect(tagRect, Paint()..color = Colors.black.withOpacity(.20));
      paintText(
        selected ? 'جاهز للاختيار' : 'مرّر بالمقبض',
        rect: Rect.fromLTWH(
          left + 18 * cardsScale,
          top + currentCardH - 30 * cardsScale,
          currentCardW - 36 * cardsScale,
          16 * cardsScale,
        ),
        fontSize: 11 * cardsScale,
        color: selected ? accent : subColor,
        fontWeight: FontWeight.w800,
      );
    }

    void drawArrow(bool left) {
      final arrowScale = clampScale(_arcadeDisplayArrowsScale, .25, 4);
      final cx = (left ? 76.0 : logicalSize.width - 76.0) +
          (left ? -_arcadeDisplayArrowsOffsetX : _arcadeDisplayArrowsOffsetX);
      final cy = 402.0 + _arcadeDisplayArrowsOffsetY;
      canvas.drawCircle(
        Offset(cx, cy),
        34 * arrowScale,
        Paint()..color = arrowColor.withOpacity(.20),
      );
      final path = ui.Path();
      if (left) {
        path.moveTo(cx + 10 * arrowScale, cy - 16 * arrowScale);
        path.lineTo(cx - 12 * arrowScale, cy);
        path.lineTo(cx + 10 * arrowScale, cy + 16 * arrowScale);
      } else {
        path.moveTo(cx - 10 * arrowScale, cy - 16 * arrowScale);
        path.lineTo(cx + 12 * arrowScale, cy);
        path.lineTo(cx - 10 * arrowScale, cy + 16 * arrowScale);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * arrowScale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = arrowColor,
      );
    }

    drawArrow(true);
    drawArrow(false);

    final dotsScale = clampScale(_arcadeDisplayDotsScale, .25, 4);
    final dotsStartX = logicalSize.width * .5 -
        ((_arcadeGames.length - 1) * (22 * dotsScale)) * .5 +
        _arcadeDisplayDotsOffsetX;
    for (var i = 0; i < _arcadeGames.length; i++) {
      final selected = i == _arcadeSelectedGameIndex;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            dotsStartX + i * 22 * dotsScale,
            logicalSize.height - 70 + _arcadeDisplayDotsOffsetY,
            (selected ? 20 : 12) * dotsScale,
            10 * dotsScale,
          ),
          Radius.circular(8 * dotsScale),
        ),
        Paint()..color = selected ? accent : Colors.white.withOpacity(.18),
      );
    }

    final hintScale = clampScale(_arcadeDisplayHintScale, .25, 4);
    paintText(
      'حرّك المقبض يمينًا أو يسارًا للتبديل',
      rect: Rect.fromLTWH(
        90 + _arcadeDisplayHintOffsetX,
        logicalSize.height - 116 + _arcadeDisplayHintOffsetY,
        logicalSize.width - 180,
        26 * hintScale,
      ),
      fontSize: 18 * hintScale,
      color: subColor,
      fontWeight: FontWeight.w700,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  bool _tickArcadeJoystickAnimation(double dt) {
    if (!_arcadeJoystickAnimating) return false;
    _arcadeJoystickAnimElapsed += dt;
    final total = _arcadeJoystickPressDuration + _arcadeJoystickReturnDuration;
    if (_arcadeJoystickAnimElapsed >= total) {
      _arcadeJoystickAnimElapsed = 0;
      _arcadeJoystickAnimDirection = 0;
      _arcadeJoystickAnimating = false;
    }
    _applyAllTransforms(save: false, repaint: false);
    return true;
  }

  double get _arcadeJoystickPressAmount {
    if (!_arcadeJoystickAnimating) return 0;
    if (_arcadeJoystickPressDuration <= 0) return 0;
    if (_arcadeJoystickAnimElapsed <= _arcadeJoystickPressDuration) {
      final t = (_arcadeJoystickAnimElapsed / _arcadeJoystickPressDuration)
          .clamp(0.0, 1.0)
          .toDouble();
      return t * t * (3 - 2 * t);
    }
    final returnTime = _arcadeJoystickAnimElapsed - _arcadeJoystickPressDuration;
    if (_arcadeJoystickReturnDuration <= 0) return 0;
    final t = (returnTime / _arcadeJoystickReturnDuration)
        .clamp(0.0, 1.0)
        .toDouble();
    final eased = t * t * (3 - 2 * t);
    return 1 - eased;
  }

  void _startArcadeJoystickAnimation(double direction) {
    _arcadeJoystickAnimating = true;
    _arcadeJoystickAnimElapsed = 0;
    _arcadeJoystickAnimDirection = direction.sign == 0 ? 1 : direction.sign;
  }

  void _browseArcadeGames(int direction) {
    if (_arcadeGames.isEmpty || direction == 0) return;
    final length = _arcadeGames.length;
    var next = _arcadeSelectedGameIndex + direction;
    while (next < 0) {
      next += length;
    }
    next %= length;
    _arcadeSelectedGameIndex = next;
    _startArcadeJoystickAnimation(direction.toDouble());
    _requestArcadeDisplayRefresh();
    _scheduleSave();
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
    final glowMaterial = _unlit(_arcadeGlowColor(alpha: .70));
    final haloMaterial = _unlit(_arcadeGlowColor(alpha: .06));
    final hitboxMaterial = _unlit(const Color(0x01000000));
    _arcadeGlowMaterial = glowMaterial;
    _arcadeHaloMaterial = haloMaterial;
    _arcadeHitboxMaterial = hitboxMaterial;

    final root = Node(name: 'arcade_interaction_glow');
    _arcadeGlowRoot = root;
    _arcadeGlowEdges.clear();

    Node edge(String name) {
      final node = Node(
        name: name,
        mesh: Mesh(CuboidGeometry(vm.Vector3.all(1)), glowMaterial),
      )
        ..castsShadows = false
        ..raycastable = false
        ..highlightColor = null;
      root.add(node);
      _arcadeGlowEdges.add(node);
      return node;
    }

    for (var i = 0; i < 12; i++) {
      edge('arcade_glow_edge_$i');
    }

    final halo = Node(
      name: 'arcade_glow_halo',
      mesh: Mesh(CuboidGeometry(vm.Vector3.all(1)), haloMaterial),
    )
      ..castsShadows = false
      ..raycastable = false
      ..highlightColor = null;
    root.add(halo);
    _arcadeHaloNode = halo;
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

  void _updateArcadeInteractionVisual() {
    final root = _arcadeGlowRoot;
    final hitbox = _arcadeHitboxNode;
    if (root == null || hitbox == null || _arcadeGlowEdges.length != 12) return;

    final rotation = _rotationFromDegrees(_arcadeRotX, _arcadeRotY, _arcadeRotZ);
    final hideForUserArcade =
        _userModeActive && (_arcadeCameraAnimating || _arcadeFocusLocked);
    final showRoot = _arcadeHighlightVisible && !hideForUserArcade;
    final hasEdgeFrame = _arcadeGlowThickness > .0001;

    root
      ..visible = showRoot
      ..position = vm.Vector3(_arcadeX, _arcadeY, _arcadeZ)
      ..rotation = vm.Quaternion.copy(rotation);
    hitbox
      ..position = vm.Vector3(_arcadeX, _arcadeY, _arcadeZ)
      ..rotation = vm.Quaternion.copy(rotation)
      ..scale = vm.Vector3(_arcadeSizeX, _arcadeSizeY, _arcadeSizeZ);

    final hx = _arcadeSizeX * .5;
    final hy = _arcadeSizeY * .5;
    final hz = _arcadeSizeZ * .5;
    final t = hasEdgeFrame ? _arcadeGlowThickness : .0;

    void setEdge(int index, vm.Vector3 position, vm.Vector3 scale) {
      _arcadeGlowEdges[index]
        ..visible = showRoot && hasEdgeFrame
        ..position = position
        ..scale = scale;
    }

    var i = 0;
    for (final sy in <double>[-1, 1]) {
      for (final sz in <double>[-1, 1]) {
        setEdge(
          i++,
          vm.Vector3(0, sy * hy, sz * hz),
          vm.Vector3(_arcadeSizeX + t, t, t),
        );
      }
    }
    for (final sx in <double>[-1, 1]) {
      for (final sz in <double>[-1, 1]) {
        setEdge(
          i++,
          vm.Vector3(sx * hx, 0, sz * hz),
          vm.Vector3(t, _arcadeSizeY + t, t),
        );
      }
    }
    for (final sx in <double>[-1, 1]) {
      for (final sy in <double>[-1, 1]) {
        setEdge(
          i++,
          vm.Vector3(sx * hx, sy * hy, 0),
          vm.Vector3(t, t, _arcadeSizeZ + t),
        );
      }
    }

    final halo = _arcadeHaloNode;
    if (halo != null) {
      halo
        ..visible = showRoot
        ..position = vm.Vector3.zero()
        ..scale = vm.Vector3(
          _arcadeSizeX + math.max(.06, _arcadeSizeX * .10),
          _arcadeSizeY + math.max(.06, _arcadeSizeY * .10),
          _arcadeSizeZ + math.max(.06, _arcadeSizeZ * .10),
        );
    }
    _updateArcadeGlowMaterial();
  }



  void _updateArcadeGlowMaterial() {
    final pulse = .70 + .30 * ((math.sin(_arcadePulseClock * 2.6) + 1) * .5);
    final intensity = _arcadeGlowIntensity.clamp(0.0, 2.0).toDouble();
    final opacity = _arcadeGlowOpacity.clamp(0.0, 1.0).toDouble();
    final hasEdgeFrame = _arcadeGlowThickness > .0001;

    _arcadeGlowMaterial?.baseColorFactor = _vectorColor(
      _arcadeGlowColor(
        alpha: hasEdgeFrame
            ? (.35 * intensity * pulse * opacity).clamp(0.0, .95).toDouble()
            : 0,
      ),
    );
    _arcadeHaloMaterial?.baseColorFactor = _vectorColor(
      _arcadeGlowColor(
        alpha: (.11 * intensity * pulse * opacity).clamp(0.0, .35).toDouble(),
      ),
    );
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

  void _handleSceneTap(TapUpDetails details) {
    if (_userModeActive && _arcadeFocusLocked) {
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
    if (!mounted) return;
    final index = _arcadeSelectedGameIndex.clamp(0, _arcadeGames.length - 1).toInt();
    Widget page;
    switch (index) {
      case 0:
        page = const DrawingGameHomeScreen();
        break;
      case 1:
        page = const HeadsUpSetupScreen();
        break;
      case 2:
        page = const KillerKilledHomeScreen();
        break;
      case 3:
      default:
        page = const GuessTimeHomeScreen();
        break;
    }
    Navigator.push(context, mundasRoute(page));
  }

  void _startArcadeCameraTransition() {
    _motionPlaying = false;
    _userCameraOverrideActive = false;
    _cameraMotionResumeBlendActive = false;
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


  bool _tickArcadeCameraTransition(double dt) {
    if (!_arcadeCameraAnimating) return false;
    _arcadeCameraTransitionElapsed += dt;
    final duration = math.max(.05, _arcadeTransitionSeconds);
    final raw = (_arcadeCameraTransitionElapsed / duration).clamp(0.0, 1.0).toDouble();
    final t = raw * raw * (3 - 2 * raw);

    double lerp(double a, double b) => a + (b - a) * t;
    _cameraX = lerp(_arcadeStartCameraX, _arcadeFocusCameraX);
    _cameraY = lerp(_arcadeStartCameraY, _arcadeFocusCameraY);
    _cameraZ = lerp(_arcadeStartCameraZ, _arcadeFocusCameraZ);
    _targetX = lerp(_arcadeStartTargetX, _arcadeFocusTargetX);
    _targetY = lerp(_arcadeStartTargetY, _arcadeFocusTargetY);
    _targetZ = lerp(_arcadeStartTargetZ, _arcadeFocusTargetZ);
    _cameraFov = lerp(_arcadeStartFov, _arcadeFocusFov);

    if (raw >= 1) {
      _arcadeCameraAnimating = false;
      _arcadeFocusLocked = true;
      _motionPlaying = false;
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
      arcadeJoystick.position = vm.Vector3.copy(_arcadeJoystickBasePosition)
        ..add(vm.Vector3(
          _arcadeJoystickX +
              _arcadeJoystickPressOffsetX * pressDirection * pressAmount,
          _arcadeJoystickY + _arcadeJoystickPressOffsetY * pressAmount,
          _arcadeJoystickZ + _arcadeJoystickPressOffsetZ * pressAmount,
        ));
      arcadeJoystick.rotation =
          vm.Quaternion.copy(_arcadeJoystickBaseRotation) *
          _rotationFromDegrees(
            _arcadeJoystickRotX + _arcadeJoystickTiltPitch * pressAmount,
            _arcadeJoystickRotY +
                _arcadeJoystickTiltYaw * pressDirection * pressAmount,
            _arcadeJoystickRotZ +
                _arcadeJoystickTiltRoll * pressDirection * pressAmount,
          );
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



  void _handleLookDrag(DragUpdateDetails details) {
    _registerUserCameraInteraction();

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
      'ARCADE_VIEW_LIMITS left=${_fmt2(_arcadeLookLeftDeg)} right=${_fmt2(_arcadeLookRightDeg)} up=${_fmt2(_arcadeLookUpDeg)} down=${_fmt2(_arcadeLookDownDeg)}',
    );
    buffer.writeln(
      'ROOM visible=$_showRoom pos=${_fmt4(_roomX)},${_fmt4(_roomY)},${_fmt4(_roomZ)} rot=${_fmt2(_roomRotX)},${_fmt2(_roomRotY)},${_fmt2(_roomRotZ)} scale=${_fmt4(_roomScaleX)},${_fmt4(_roomScaleY)},${_fmt4(_roomScaleZ)}',
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
    buffer.writeln(
      'ARCADE_JOYSTICK_ACTION press=${_fmt3(_arcadeJoystickPressDuration)} return=${_fmt3(_arcadeJoystickReturnDuration)} offset=${_fmt4(_arcadeJoystickPressOffsetX)},${_fmt4(_arcadeJoystickPressOffsetY)},${_fmt4(_arcadeJoystickPressOffsetZ)} tilt=${_fmt2(_arcadeJoystickTiltPitch)},${_fmt2(_arcadeJoystickTiltYaw)},${_fmt2(_arcadeJoystickTiltRoll)}',
    );
    buffer.writeln(
      'ARCADE_JOYSTICK_HITBOX visible=$_showArcadeJoystickPressHitbox pos=${_fmt4(_arcadeJoystickPressHitboxX)},${_fmt4(_arcadeJoystickPressHitboxY)},${_fmt4(_arcadeJoystickPressHitboxZ)} size=${_fmt4(_arcadeJoystickPressHitboxSizeX)},${_fmt4(_arcadeJoystickPressHitboxSizeY)},${_fmt4(_arcadeJoystickPressHitboxSizeZ)} preview=$_arcadeJoystickPressPreview previewDirection=${_fmt2(_arcadeJoystickPreviewDirection)}',
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
              min: -10,
              max: 10,
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
              _arcadeDisplayBgR = 0;
              _arcadeDisplayBgG = 54;
              _arcadeDisplayBgB = 49;
              _arcadeDisplayHeaderR = 62;
              _arcadeDisplayHeaderG = 152;
              _arcadeDisplayHeaderB = 160;
              _arcadeDisplayAccentR = 0;
              _arcadeDisplayAccentG = 255;
              _arcadeDisplayAccentB = 65;
              _arcadeDisplayCardR = 255;
              _arcadeDisplayCardG = 152;
              _arcadeDisplayCardB = 0;
              _arcadeDisplaySelectedCardR = 0;
              _arcadeDisplaySelectedCardG = 141;
              _arcadeDisplaySelectedCardB = 0;
              _arcadeDisplayTextR = 255;
              _arcadeDisplayTextG = 255;
              _arcadeDisplayTextB = 255;
              _arcadeDisplaySubtextR = 197;
              _arcadeDisplaySubtextG = 205;
              _arcadeDisplaySubtextB = 229;
              _arcadeDisplayArrowR = 255;
              _arcadeDisplayArrowG = 213;
              _arcadeDisplayArrowB = 70;
              _arcadeDisplayFrameR = 124;
              _arcadeDisplayFrameG = 255;
              _arcadeDisplayFrameB = 223;
              _arcadeDisplayShowSubtitle = true;
              _arcadeDisplayHeaderOffsetX = 0;
              _arcadeDisplayHeaderOffsetY = 0;
              _arcadeDisplayHeaderScale = 1.50;
              _arcadeDisplaySideTitleOffsetX = 0;
              _arcadeDisplaySideTitleOffsetY = 0;
              _arcadeDisplaySideTitleScale = 1.95;
              _arcadeDisplayCenterTitleOffsetX = 0;
              _arcadeDisplayCenterTitleOffsetY = 20.50;
              _arcadeDisplayCenterTitleScale = 1.85;
              _arcadeDisplayCurrentGameOffsetX = -76;
              _arcadeDisplayCurrentGameOffsetY = 0;
              _arcadeDisplayCurrentGameScale = 2.0;
              _arcadeDisplayCardsOffsetX = 0;
              _arcadeDisplayCardsOffsetY = 103.50;
              _arcadeDisplayCardsScale = 2.35;
              _arcadeDisplayCardsGapScale = 1.0;
              _arcadeDisplayArrowsOffsetX = -48.50;
              _arcadeDisplayArrowsOffsetY = -157;
              _arcadeDisplayArrowsScale = 1.0;
              _arcadeDisplayDotsOffsetX = 0;
              _arcadeDisplayDotsOffsetY = 145;
              _arcadeDisplayDotsScale = .25;
              _arcadeDisplayHintOffsetX = -20.50;
              _arcadeDisplayHintOffsetY = 400;
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
              'تحريك المقبض عند التبديل بين الألعاب',
              style: TextStyle(
                color: Colors.white.withOpacity(.90),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _numberControl(
              label: 'مدة الضغط',
              value: _arcadeJoystickPressDuration,
              min: .01,
              max: 1.5,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickPressDuration = v;
                _previewArcadeJoystickPress(_arcadeJoystickPreviewDirection);
              }),
            ),
            _numberControl(
              label: 'مدة الرجوع',
              value: _arcadeJoystickReturnDuration,
              min: .01,
              max: 2.0,
              step: .01,
              onChanged: (v) => setState(() {
                _arcadeJoystickReturnDuration = v;
                _previewArcadeJoystickPress(_arcadeJoystickPreviewDirection);
              }),
            ),
            _tripleControl(
              prefix: 'إزاحة الضغط',
              xLabel: 'X',
              yLabel: 'Y',
              zLabel: 'Z',
              min: -1,
              max: 1,
              step: .005,
              x: _arcadeJoystickPressOffsetX,
              y: _arcadeJoystickPressOffsetY,
              z: _arcadeJoystickPressOffsetZ,
              onX: (v) => _arcadeJoystickPressOffsetX = v,
              onY: (v) => _arcadeJoystickPressOffsetY = v,
              onZ: (v) => _arcadeJoystickPressOffsetZ = v,
              afterChange: () => _previewArcadeJoystickPress(_arcadeJoystickPreviewDirection),
            ),
            _tripleControl(
              prefix: 'ميلان المقبض عند التصفح',
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
              afterChange: () => _previewArcadeJoystickPress(_arcadeJoystickPreviewDirection),
            ),
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
              _arcadeJoystickReturnDuration = .18;
              _arcadeJoystickPressOffsetX = .018;
              _arcadeJoystickPressOffsetY = -.055;
              _arcadeJoystickPressOffsetZ = 0;
              _arcadeJoystickTiltPitch = 11;
              _arcadeJoystickTiltYaw = 6;
              _arcadeJoystickTiltRoll = 14;
              _showArcadeJoystickPressHitbox = false;
              _arcadeJoystickPressHitboxX = 0;
              _arcadeJoystickPressHitboxY = 0;
              _arcadeJoystickPressHitboxZ = 0;
              _arcadeJoystickPressHitboxSizeX = 2.20;
              _arcadeJoystickPressHitboxSizeY = 2.20;
              _arcadeJoystickPressHitboxSizeZ = 3.40;
              _arcadeJoystickPressPreview = true;
              _arcadeJoystickPreviewDirection = 1;
              _applyAllTransforms(repaint: false);
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
          'حدد صندوق ماكينة الآركيد والتوهج الذي يحيط بها، مع دوران كامل للصندوق، ثم حرر كاميرا الانتقال مباشرة بالماوس والأسهم.',
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
          prefix: 'موضع الآركيد / صندوق الضغط',
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
          prefix: 'دوران صندوق الآركيد',
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
          prefix: 'حجم صندوق الآركيد',
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

class _ArcadeGameEntry {
  final String title;
  final String subtitle;
  final String icon;

  const _ArcadeGameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
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
