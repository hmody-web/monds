import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Radius, Size;
import 'dart:ui' as dui;

import 'package:flutter/material.dart' as ui;
import 'package:flutter/services.dart' as services;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';
import 'dev_image_picker_stub.dart' if (dart.library.io) 'dev_image_picker_io.dart' as dev_picker;

const String _kDefaultBlackWallTexturePath = r'C:\Users\blcon\Downloads\black-wall-texture-15.jpg';
const String _kDefaultBlackWallTextureBase64 = r'''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''';

Uint8List _decodeDefaultBlackWallTextureBytes() =>
    convert.base64Decode(_kDefaultBlackWallTextureBase64);

class GuessTime3DWorld {
  final Scene scene = Scene();
  final List<_PlayerVisual> _players = [];
  final List<MeshPrimitive> _screenPrimitives = [];
  final List<UnlitMaterial> _screenMaterials = [];
  final List<Texture2D?> _playerScreenTextures = List<Texture2D?>.filled(4, null);
  final List<UnlitMaterial> _stationTimerMaterials = [];
  final List<Texture2D?> _stationTimerTextures = List<Texture2D?>.filled(4, null);
  final List<List<List<Node>>> _stationDigitSegments = [];
  final List<Node> _stationDecimalDots = [];
  final List<int> _screenOwners = List<int>.filled(28, 0);
  final List<String> _playerScreenValues = List<String>.filled(4, '00.00');
  final List<String> _stationTimerValues = List<String>.filled(4, '00.00');
  int _screenTextureRevision = 0;
  int _stationTimerTextureRevision = 0;
  int _bigScreenTextureRevision = 0;
  String _lastBigScreenSignature = '';
  GuessTimePhase? _cachedBigScreenPhase;
  int _cachedBigScreenRound = 1;
  int _cachedBigScreenCountdown = 3;
  int _cachedBigScreenLockedCount = 0;
  int _cachedBigScreenTotalPlayers = 4;
  List<GuessTimeStanding> _cachedRoundStandings = const [];
  List<GuessTimeStanding> _cachedFinalStandings = const [];
  String? _cachedLoserName;
  final List<Node> _stations = [];
  final List<Node> _buttons = [];
  final List<vm.Vector3> _buttonPositions = [];
  final List<vm.Vector3> _stationDisplayPositions = [];
  final List<Node> _chairs = [];
  final List<_Debris> _debris = [];
  final math.Random _random = math.Random(8831);
  Node? _spaceBackdrop;
  Texture2D? _spaceBackdropTexture;
  late final Node _environmentRoot;
  late final Node _outerGround;
  late final PhysicallyBasedMaterial _outerGroundMaterial;
  final List<Node> _mountainRoots = [];
  final List<Node> _mountainModels = [];
  final List<PhysicallyBasedMaterial> _mountainMaterials = [];

  late final Node _characterTemplate;
  late final Node _roomRig;
  late final Node _room;
  late final UnlitMaterial _bigScreenMaterial;
  late final Node _bigScreen;
  Texture2D? _bigScreenTexture;
  late final Node _tank;
  late final Node _tankTurret;
  late final Node _tankTurretMesh;
  late final Node _tankBarrel;
  late final Node _tankBarrelMesh;
  late final Node _tankMuzzle;
  late final Node _tankTurretPivotMarker;
  late final Node _tankBarrelPivotMarker;
  late final Node _tankMuzzleMarker;

  // Authored T-34 part pivots (source coordinates are Z-up, +Y forward).
  // The optimized asset keeps vertices in their original authored positions,
  // so we re-center the logical pivots at runtime and compensate the child
  // meshes. This preserves the exact appearance while making rotations happen
  // around the turret ring / gun breech instead of the model origin.
  static final vm.Vector3 _t34TurretPivotBase =
      vm.Vector3(.9447, -19.0424, 60.3980);
  static final vm.Vector3 _t34BarrelPivotBase =
      vm.Vector3(.3000, 31.0000, 76.5000);
  final List<Node> _tankPathMarkers = [];
  bool _tankDeveloperPathRunning = false;
  DateTime? _tankDeveloperPathStartedAt;
  int _tankDeveloperTarget = 0;
  late final Node _projectile;
  late final Node _projectileModel;
  late final Node _projectileGlowInner;
  late final Node _projectileGlowOuter;
  final List<Node> _projectileTrail = [];
  late final UnlitMaterial _projectileMaterial;
  late final UnlitMaterial _projectileGlowMaterial;
  late final UnlitMaterial _projectileTrailMaterial;
  bool _projectileBuilt = false;

  final List<PhysicallyBasedMaterial> _deskPrimaryMaterials = [];
  final List<PhysicallyBasedMaterial> _deskSecondaryMaterials = [];
  final List<PhysicallyBasedMaterial> _chairPrimaryMaterials = [];
  final List<PhysicallyBasedMaterial> _chairFrameMaterials = [];
  final List<PhysicallyBasedMaterial> _chairAccentMaterials = [];
  final List<PhysicallyBasedMaterial> _timerShellMaterials = [];
  final List<UnlitMaterial> _deskImageMaterials = [];
  final List<UnlitMaterial> _chairImageMaterials = [];
  final List<UnlitMaterial> _timerImageMaterials = [];
  final List<UnlitMaterial> _timerFaceMaterials = [];
  final List<UnlitMaterial> _timerDigitMaterials = [];
  final List<Node> _deskImageDecals = [];
  final List<Node> _chairImageDecals = [];
  final List<Node> _timerImageDecals = [];
  final List<_TimerVisualAssembly> _timerAssemblies = [];
  final List<Node> _chairSeatCrossNodes = [];
  final List<Node> _chairBackCrossNodes = [];
  final List<List<Node>> _chairSeatRoundNodes = [];
  final List<List<Node>> _chairBackRoundNodes = [];
  final List<Node> _timerBodyCrossNodes = [];
  final List<List<Node>> _timerBodyRoundNodes = [];
  late final Node _bigScreenMount;
  late final Node _bigScreenFrame;
  late final Node _bigScreenBezel;
  late final Node _bigScreenFrameCross;
  final List<Node> _bigScreenFrameRoundNodes = [];
  late final PhysicallyBasedMaterial _bigScreenFrameMaterial;
  late final PhysicallyBasedMaterial _bigScreenBezelMaterial;
  late vm.Vector3 _bigScreenBasePosition;
  late vm.Quaternion _bigScreenBaseRotation;
  late final UnlitMaterial _explosionMaterial;

  bool ready = false;
  bool _eliminationActive = false;
  DateTime? _eliminationStartedAt;
  int _loserIndex = -1;
  bool _shotTriggered = false;
  bool _impactTriggered = false;
  vm.Vector3 _shotStart = vm.Vector3.zero();
  vm.Vector3 _shotTarget = vm.Vector3.zero();

  final _geo = _GuessGeometryBank();

  static const bool developerMode = false;
  static const bool stationDeveloperMode = false;
  static const bool tankDeveloperMode = true;
  static bool _runtimeDeveloperMode = stationDeveloperMode || tankDeveloperMode;
  static bool get layoutDeveloperMode => _runtimeDeveloperMode;
  static const bool debugLayout = false;

  final _dev = _GuessTimeDeveloperTuning();
  ui.OverlayEntry? _developerOverlayEntry;
  DateTime _lastCameraFrame = DateTime.now();
  int _developerOverlayAttachAttempts = 0;
  // Measured from the original GLB floor mesh (Object_4) after recursively
  // applying parent × child × mesh transforms. The room itself is NOT moved.
  static const double _roomFloorY = -2.88845171;

  late final _RoomLayout _layout;

  int _viewerIndex = 0;
  double _lookYaw = 0;
  double _lookPitch = 0;
  double _lookYawTarget = 0;
  double _lookPitchTarget = 0;
  bool _developerFreeCameraEnabled = false;
  int _developerSelectedStation = 0;
  GuessTimePhase _behaviorPhase = GuessTimePhase.waiting;
  int _behaviorElapsedMs = 0;
  final List<bool> _behaviorLocked = List<bool>.filled(4, false);


  // These are the 28 real luminous monitor faces measured directly from the
  // ORIGINAL surveillance_room.glb after recursively applying its complete
  // node hierarchy. They are in the GLB's untouched authored world space.
  static final List<_ScreenSpec> _screenSpecs = <_ScreenSpec>[
    _ScreenSpec(
      vm.Vector3(0.438433, -0.233829, 0.618345),
      vm.Vector3(0.225018, 0.000000, -0.974355),
      vm.Vector3(0.726571, 0.666288, 0.167795),
      vm.Vector3(0.649201, -0.745695, 0.149927),
      0.422995, 0.308297,
    ),
    _ScreenSpec(
      vm.Vector3(1.089907, -0.275922, 0.212554),
      vm.Vector3(0.556425, 0.000000, -0.830898),
      vm.Vector3(0.731624, 0.474004, 0.489945),
      vm.Vector3(0.393849, -0.880523, 0.263748),
      0.423005, 0.308311,
    ),
    _ScreenSpec(
      vm.Vector3(1.703159, -0.279224, 0.094151),
      vm.Vector3(0.895080, 0.000000, -0.445906),
      vm.Vector3(0.397351, 0.453788, 0.797614),
      vm.Vector3(0.202347, -0.891110, 0.406176),
      0.423006, 0.308313,
    ),
    _ScreenSpec(
      vm.Vector3(2.308545, -0.265069, -0.032251),
      vm.Vector3(0.999686, -0.000000, -0.025066),
      vm.Vector3(0.021200, 0.533598, 0.845473),
      vm.Vector3(0.013375, -0.845738, 0.533430),
      0.423001, 0.308306,
    ),
    _ScreenSpec(
      vm.Vector3(2.953575, -0.211787, 0.210213),
      vm.Vector3(0.972090, -0.000000, 0.234609),
      vm.Vector3(-0.158395, 0.737685, 0.656302),
      vm.Vector3(-0.173067, -0.675145, 0.717096),
      0.422992, 0.308294,
    ),
    _ScreenSpec(
      vm.Vector3(3.629809, -0.275818, 0.330043),
      vm.Vector3(0.857362, -0.000000, 0.514715),
      vm.Vector3(-0.453046, 0.474623, 0.754640),
      vm.Vector3(-0.244295, -0.880189, 0.406923),
      0.423004, 0.308311,
    ),
    _ScreenSpec(
      vm.Vector3(4.373132, -0.293477, 0.787535),
      vm.Vector3(0.770831, 0.000000, 0.637040),
      vm.Vector3(-0.596803, 0.349765, 0.722143),
      vm.Vector3(-0.222814, -0.936838, 0.269609),
      0.423015, 0.308326,
    ),
    _ScreenSpec(
      vm.Vector3(0.442214, -0.940260, 0.754610),
      vm.Vector3(0.473174, 0.000000, -0.880969),
      vm.Vector3(0.488758, 0.831986, 0.262516),
      vm.Vector3(0.732954, -0.554797, 0.393675),
      0.422989, 0.308289,
    ),
    _ScreenSpec(
      vm.Vector3(0.974387, -0.988659, 0.408092),
      vm.Vector3(0.892609, -0.000000, -0.450832),
      vm.Vector3(0.319931, 0.704558, 0.633437),
      vm.Vector3(0.317637, -0.709646, 0.628895),
      0.422994, 0.308295,
    ),
    _ScreenSpec(
      vm.Vector3(1.691345, -0.939150, 0.227859),
      vm.Vector3(0.948569, 0.000000, -0.316571),
      vm.Vector3(0.174508, 0.834343, 0.522894),
      vm.Vector3(0.264129, -0.551245, 0.791432),
      0.422989, 0.308289,
    ),
    _ScreenSpec(
      vm.Vector3(2.301417, -0.960451, 0.046729),
      vm.Vector3(0.999980, 0.000000, -0.006394),
      vm.Vector3(0.003960, 0.785088, 0.619371),
      vm.Vector3(0.005020, -0.619384, 0.785072),
      0.422991, 0.308291,
    ),
    _ScreenSpec(
      vm.Vector3(2.955009, -0.893521, 0.267343),
      vm.Vector3(0.978287, 0.000000, 0.207255),
      vm.Vector3(-0.084008, 0.914168, 0.396534),
      vm.Vector3(-0.189466, -0.405335, 0.894319),
      0.422986, 0.308285,
    ),
    _ScreenSpec(
      vm.Vector3(3.602180, -0.919350, 0.457161),
      vm.Vector3(0.896284, 0.000000, 0.443481),
      vm.Vector3(-0.216386, 0.872886, 0.437319),
      vm.Vector3(-0.387109, -0.487925, 0.782353),
      0.422988, 0.308287,
    ),
    _ScreenSpec(
      vm.Vector3(4.291323, -0.988198, 0.864516),
      vm.Vector3(0.751186, 0.000000, 0.660091),
      vm.Vector3(-0.467457, 0.706042, 0.531967),
      vm.Vector3(-0.466052, -0.708170, 0.530368),
      0.422993, 0.308295,
    ),
    _ScreenSpec(
      vm.Vector3(0.487583, -1.580441, 0.774047),
      vm.Vector3(0.466212, 0.000000, -0.884673),
      vm.Vector3(0.134723, 0.988336, 0.070998),
      vm.Vector3(0.874354, -0.152286, 0.460775),
      0.422983, 0.308280,
    ),
    _ScreenSpec(
      vm.Vector3(1.037514, -1.651385, 0.452477),
      vm.Vector3(0.859680, -0.000000, -0.510833),
      vm.Vector3(0.193622, 0.925384, 0.325845),
      vm.Vector3(0.472717, -0.379031, 0.795534),
      0.422986, 0.308284,
    ),
    _ScreenSpec(
      vm.Vector3(1.754721, -1.592592, 0.252896),
      vm.Vector3(0.914176, 0.000000, -0.405318),
      vm.Vector3(0.077462, 0.981568, 0.174713),
      vm.Vector3(0.397847, -0.191115, 0.897325),
      0.422983, 0.308281,
    ),
    _ScreenSpec(
      vm.Vector3(2.320462, -1.529036, 0.113925),
      vm.Vector3(0.999202, 0.000000, -0.039943),
      vm.Vector3(-0.000477, 0.999929, -0.011937),
      vm.Vector3(0.039940, 0.011947, 0.999131),
      0.422981, 0.308277,
    ),
    _ScreenSpec(
      vm.Vector3(2.958433, -1.624098, 0.281638),
      vm.Vector3(0.980638, 0.000000, 0.195828),
      vm.Vector3(-0.057144, 0.956477, 0.286157),
      vm.Vector3(-0.187305, -0.291807, 0.937958),
      0.422984, 0.308283,
    ),
    _ScreenSpec(
      vm.Vector3(3.608297, -1.595575, 0.497123),
      vm.Vector3(0.914247, 0.000000, 0.405157),
      vm.Vector3(-0.081294, 0.979664, 0.183441),
      vm.Vector3(-0.396917, -0.200647, 0.895655),
      0.422983, 0.308281,
    ),
    _ScreenSpec(
      vm.Vector3(4.271392, -1.567232, 0.964314),
      vm.Vector3(0.808772, -0.000000, 0.588123),
      vm.Vector3(-0.064740, 0.993923, 0.089029),
      vm.Vector3(-0.584548, -0.110079, 0.803857),
      0.422982, 0.308279,
    ),
    _ScreenSpec(
      vm.Vector3(0.470697, -2.233637, 0.797995),
      vm.Vector3(0.512458, -0.000000, -0.858712),
      vm.Vector3(-0.178899, 0.978058, -0.106763),
      vm.Vector3(0.839870, 0.208334, 0.501214),
      0.422983, 0.308281,
    ),
    _ScreenSpec(
      vm.Vector3(1.044448, -2.224376, 0.465498),
      vm.Vector3(0.860325, -0.000000, -0.509746),
      vm.Vector3(-0.121272, 0.971288, -0.204677),
      vm.Vector3(0.495110, 0.237906, 0.835623),
      0.422984, 0.308281,
    ),
    _ScreenSpec(
      vm.Vector3(1.675558, -2.215722, 0.275585),
      vm.Vector3(0.964629, 0.000000, -0.263612),
      vm.Vector3(-0.069999, 0.964100, -0.256145),
      vm.Vector3(0.254148, 0.265538, 0.929999),
      0.422984, 0.308282,
    ),
    _ScreenSpec(
      vm.Vector3(2.308179, -2.148187, 0.075964),
      vm.Vector3(0.999817, -0.000000, -0.019124),
      vm.Vector3(-0.009201, 0.876661, -0.481021),
      vm.Vector3(0.016765, 0.481109, 0.876500),
      0.422988, 0.308287,
    ),
    _ScreenSpec(
      vm.Vector3(2.903855, -2.166905, 0.251919),
      vm.Vector3(0.952284, 0.000000, 0.305214),
      vm.Vector3(0.128609, 0.906888, -0.401266),
      vm.Vector3(-0.276795, 0.421372, 0.863615),
      0.422986, 0.308285,
    ),
    _ScreenSpec(
      vm.Vector3(3.613690, -2.231781, 0.498762),
      vm.Vector3(0.918338, 0.000000, 0.395796),
      vm.Vector3(0.084803, 0.976777, -0.196763),
      vm.Vector3(-0.386605, 0.214260, 0.897011),
      0.422983, 0.308281,
    ),
    _ScreenSpec(
      vm.Vector3(4.244828, -2.200009, 0.925620),
      vm.Vector3(0.757774, 0.000000, 0.652517),
      vm.Vector3(0.206001, 0.948858, -0.239231),
      vm.Vector3(-0.619146, 0.315703, 0.719020),
      0.422985, 0.308283,
    ),
  ];

  Future<void> initialize({
    required List<GuessTimePlayer> players,
    void Function(double progress, String stage)? onProgress,
  }) async {
    if (ready) return;
    onProgress?.call(.05, 'تهيئة محرك الغرفة');
    await Scene.initializeStaticResources();

    scene.renderScale = .88;
    scene.exposure = 1.15;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.25, -1, -.30),
      color: vm.Vector3(.90, .95, 1.0),
      intensity: 2.35,
      castsShadow: true,
      shadowCascadeCount: 1,
      shadowMaxDistance: 28,
      shadowMapResolution: 512,
      shadowSoftness: .18,
      shadowAmbientStrength: .28,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = true
      ..sampleCount = 4
      ..radius = .27
      ..intensity = .82;

    onProgress?.call(.15, 'تحميل غرفة المراقبة');
    final importedRoom = await Node.fromGlbAsset('assets/models/surveillance_room.glb');
    importedRoom.name = 'surveillance_room_original';
    for (final mesh in importedRoom.meshNodes) {
      mesh
        ..castsShadows = true
        ..highlightColor = null;
    }

    // Keep the imported GLB untouched under an identity developer rig.
    // The rig exists only so the temporary in-game developer panel can move
    // and rotate the authored room live without altering its internal nodes.
    _roomRig = Node(name: 'guess_time_room_developer_rig');
    _room = importedRoom;
    _roomRig.add(_room);

    // Bind/split the REAL monitor face geometry before mounting the room in the
    // Scene. surveillance_room.glb stores all 28 Lumires faces inside ONE
    // primitive, so assigning 28 materials requires splitting that primitive's
    // own triangles -- not drawing 28 replacement panels in front of it.
    onProgress?.call(.24, 'ربط أسطح الشاشات الأصلية');
    _bindOriginalScreens();
    scene.add(_roomRig);
    // The room transform is part of the final authored gameplay layout, not
    // merely a developer preview. Apply it before positioning/facing players.
    _applyDeveloperMapTransform();

    _layout = _deriveRoomLayout();
    _initializeDeveloperStations();
    _resetDeveloperCameraToDefaultView();

    onProgress?.call(.30, 'تجهيز خلفية الفضاء');
    await _buildSpaceBackdrop();

    onProgress?.call(.33, 'تهيئة الأرضية والجبال الخارجية');
    await _buildEnvironment();

    onProgress?.call(.35, 'تحميل الشخصيات');
    _characterTemplate = await Node.fromGlbAsset('assets/models/creative_character_free.glb');

    onProgress?.call(.50, 'تجهيز شاشة النتائج');
    _buildBigScreen();

    onProgress?.call(.63, 'بناء محطات اللاعبين');
    _buildStations();
    await _applyInitialSurfaceDeveloperSettings();
    // Keep the authored surveillance_room.glb open. The extra safety shell
    // used during camera debugging is intentionally not mounted anymore.

    onProgress?.call(.76, 'تجهيز الشخصيات والكراسي');
    for (var i = 0; i < players.length && i < 4; i++) {
      _buildPlayer(i, players[i].avatar);
    }

    onProgress?.call(.88, 'تحميل وتجهيز دبابة T-34');
    await _buildTank();
    if (debugLayout) _buildLayoutDebug();

    onProgress?.call(.94, 'تهيئة شاشات الأوقات');
    await _primeScreenTextures();

    ready = true;
    if (developerMode || layoutDeveloperMode) {
      _lastCameraFrame = DateTime.now();
      _scheduleDeveloperOverlayAttach();
    }
    onProgress?.call(1, 'الغرفة جاهزة');
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

  PhysicallyBasedMaterial _pbr(Color color, {double roughness = .52, double metallic = .35}) {
    final material = PhysicallyBasedMaterial();
    material.baseColorFactor = _vectorColor(color);
    material.roughnessFactor = roughness;
    material.metallicFactor = metallic;
    return material;
  }

  UnlitMaterial _unlit(Color color) {
    final material = UnlitMaterial();
    material.baseColorFactor = _vectorColor(color);
    final a = ((color.toARGB32() >> 24) & 0xFF) / 255.0;
    if (a < .999) material.alphaMode = AlphaMode.blend;
    return material;
  }

  Future<Texture2D> _makeSpaceBackdropTexture() async {
    const width = 1024;
    const height = 512;
    final recorder = dui.PictureRecorder();
    final canvas = dui.Canvas(recorder);

    // Deep-space base: almost black with a muted olive/yellow falloff.
    final base = dui.Paint()
      ..shader = dui.Gradient.linear(
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
      dui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      base,
    );

    // Large soft nebula clouds. Radial gradients give the blurred look without
    // expensive runtime blur passes.
    final clouds = <({Offset center, double radius, Color color})>[
      (center: const Offset(235, 245), radius: 330, color: const Color(0x556B5A08)),
      (center: const Offset(565, 145), radius: 285, color: const Color(0x3D8B7410)),
      (center: const Offset(830, 340), radius: 360, color: const Color(0x426A590B)),
      (center: const Offset(490, 420), radius: 260, color: const Color(0x244D430D)),
    ];
    for (final cloud in clouds) {
      final paint = dui.Paint()
        ..shader = dui.Gradient.radial(
          cloud.center,
          cloud.radius,
          <Color>[cloud.color, const Color(0x00000000)],
          const <double>[0, 1],
        );
      canvas.drawCircle(cloud.center, cloud.radius, paint);
    }

    // Sparse, deliberately soft stars. Bigger stars are low opacity so the
    // backdrop feels distant rather than like sharp wallpaper.
    final rng = math.Random(48173);
    for (var i = 0; i < 155; i++) {
      final x = rng.nextDouble() * width;
      final y = rng.nextDouble() * height;
      final bright = rng.nextDouble();
      final radius = .45 + rng.nextDouble() * (bright > .92 ? 2.2 : 1.0);
      final alpha = 35 + (bright * 95).round();
      final warm = rng.nextDouble() < .22;
      final color = warm
          ? Color.fromARGB(alpha, 255, 235, 150)
          : Color.fromARGB(alpha, 225, 230, 218);
      canvas.drawCircle(Offset(x, y), radius, dui.Paint()..color = color);
    }

    final image = await recorder.endRecording().toImage(width, height);
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
      ..name = 'guess_time_space_backdrop_material'
      ..baseColorTexture = texture
      ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
      ..vertexColorWeight = 0
      ..doubleSided = true;

    // This is a distant sky sphere, not a gameplay wall. Its radius is large
    // enough that the room remains visually open from every direction.
    final center = (_layout.rowCenter + _authoredRoomPointToWorld(_layout.screensCenter)) * .5;
    _spaceBackdrop = _mesh(
      _geo.skySphere,
      material,
      name: 'guess_time_distant_space_backdrop',
      position: center + vm.Vector3(0, 1.6, 0),
      scale: vm.Vector3.all(150),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -.35),
    )
      ..castsShadows = false
      ..highlightColor = null;
    scene.add(_spaceBackdrop!);
  }

  Node _mesh(
    Geometry geometry,
    Material material, {
    String name = '',
    vm.Vector3? position,
    vm.Vector3? scale,
    vm.Quaternion? rotation,
  }) {
    final node = Node(name: name, mesh: Mesh(geometry, material));
    if (position != null) node.position = position;
    if (scale != null) node.scale = scale;
    if (rotation != null) node.rotation = rotation;
    node.highlightColor = null;
    return node;
  }

  vm.Quaternion _rotationFromBasis(vm.Vector3 right, vm.Vector3 up, vm.Vector3 forward) {
    // Exact orthonormal basis measured from the monitor mesh.  Using all three
    // axes preserves each monitor's roll as well as its yaw/pitch.
    final m00 = right.x, m01 = up.x, m02 = forward.x;
    final m10 = right.y, m11 = up.y, m12 = forward.y;
    final m20 = right.z, m21 = up.z, m22 = forward.z;
    final trace = m00 + m11 + m22;
    late double x, y, z, w;
    if (trace > 0) {
      final s = math.sqrt(trace + 1.0) * 2.0;
      w = .25 * s;
      x = (m21 - m12) / s;
      y = (m02 - m20) / s;
      z = (m10 - m01) / s;
    } else if (m00 > m11 && m00 > m22) {
      final s = math.sqrt(1.0 + m00 - m11 - m22) * 2.0;
      w = (m21 - m12) / s;
      x = .25 * s;
      y = (m01 + m10) / s;
      z = (m02 + m20) / s;
    } else if (m11 > m22) {
      final s = math.sqrt(1.0 + m11 - m00 - m22) * 2.0;
      w = (m02 - m20) / s;
      x = (m01 + m10) / s;
      y = .25 * s;
      z = (m12 + m21) / s;
    } else {
      final s = math.sqrt(1.0 + m22 - m00 - m11) * 2.0;
      w = (m10 - m01) / s;
      x = (m02 + m20) / s;
      y = (m12 + m21) / s;
      z = .25 * s;
    }
    final q = vm.Quaternion(x, y, z, w);
    q.normalize();
    return q;
  }

  void _bindOriginalScreens() {
    // IMPORTANT:
    // surveillance_room.glb does NOT expose 28 separate "Lumires" primitives.
    // In this asset the 28 real monitor faces are batched inside one Lumires
    // primitive. We therefore split THAT ORIGINAL geometry by triangle location
    // and give each resulting real face its own material. No Cuboid/Plane
    // overlay is created anywhere in this path.
    final screenParts = List<MeshPrimitive?>.filled(_screenSpecs.length, null);
    var lumiresPrimitiveCount = 0;
    var lumiresTriangleCount = 0;

    for (final node in _room.meshNodes.toList()) {
      final mesh = node.mesh;
      if (mesh == null) continue;

      var changed = false;
      final rebuilt = <MeshPrimitive>[];

      for (final primitive in mesh.primitives) {
        final materialName = primitive.material.name.trim().toLowerCase();
        if (!materialName.contains('lumires')) {
          rebuilt.add(primitive);
          continue;
        }

        lumiresPrimitiveCount++;
        final geometry = primitive.geometry;
        if (!geometry.isReadable) {
          throw StateError(
            'surveillance_room.glb: Lumires geometry is not readable; '
            'cannot split its real monitor faces.',
          );
        }

        final data = geometry.extractMeshData();
        if (data.triangleCount == 0) {
          rebuilt.add(primitive);
          continue;
        }

        lumiresTriangleCount += data.triangleCount;
        final trianglesByScreen = List<List<int>>.generate(
          _screenSpecs.length,
          (_) => <int>[],
        );
        final unmatched = <int>[];

        // _screenSpecs are stored in the GLB's ORIGINAL authored coordinate
        // system. Node.fromGlbAsset() adds a synthetic handedness-conversion
        // transform at the imported root (currently a Z flip), so comparing a
        // descendant's runtime globalTransform directly against _screenSpecs
        // puts the two points in different coordinate systems. Convert every
        // triangle centroid back into _room local space first; that exactly
        // removes the importer root conversion (and any developer rig transform)
        // without hard-coding which axis flutter_scene flips.
        final roomWorldInverse = vm.Matrix4.identity();
        roomWorldInverse.copyInverse(_room.globalTransform);

        for (final triangle in data.triangles) {
          final localCentroid = vm.Vector3.copy(triangle.pa)
            ..add(triangle.pb)
            ..add(triangle.pc)
            ..scale(1 / 3);
          final runtimeWorldCentroid =
              node.globalTransform.transform3(vm.Vector3.copy(localCentroid));
          final authoredCentroid = roomWorldInverse.transform3(
            vm.Vector3.copy(runtimeWorldCentroid),
          );
          final screenIndex = _screenIndexForAuthoredPoint(authoredCentroid);

          final target = screenIndex == null
              ? unmatched
              : trianglesByScreen[screenIndex];
          target
            ..add(triangle.a)
            ..add(triangle.b)
            ..add(triangle.c);
        }

        var producedScreenPart = false;
        for (var screenIndex = 0;
            screenIndex < trianglesByScreen.length;
            screenIndex++) {
          final sourceCorners = trianglesByScreen[screenIndex];
          if (sourceCorners.isEmpty) continue;

          if (screenParts[screenIndex] != null) {
            throw StateError(
              'surveillance_room.glb: screen ${screenIndex + 1} was split '
              'from more than one Lumires region.',
            );
          }

          final partGeometry = MeshGeometry.fromMeshData(
            _subsetScreenMeshData(
              data,
              sourceCorners,
              node,
              roomWorldInverse,
              _screenSpecs[screenIndex],
            ),
          );
          final part = MeshPrimitive(partGeometry, primitive.material)
            ..castsShadow = false;
          screenParts[screenIndex] = part;
          rebuilt.add(part);
          producedScreenPart = true;
        }

        if (!producedScreenPart) {
          // Keep it rather than silently deleting source geometry. The final
          // validation below will explain which screen faces could not bind.
          rebuilt.add(primitive);
          continue;
        }

        // Preserve any Lumires triangles that are not one of the 28 measured
        // screen faces with the GLB's original material.
        if (unmatched.isNotEmpty) {
          rebuilt.add(
            MeshPrimitive(
              MeshGeometry.fromMeshData(_subsetMeshData(data, unmatched)),
              primitive.material,
            )..castsShadow = primitive.castsShadow,
          );
        }
        changed = true;
      }

      if (changed) {
        // Replacing the Mesh is intentional. When mounted, flutter_scene keeps
        // one RenderItem per MeshPrimitive; changing the Mesh registers the new
        // real-face primitive list correctly. During initialize this happens
        // before the room is mounted anyway.
        node.mesh = Mesh.primitives(primitives: rebuilt);
      }
    }

    final missing = <int>[];
    for (var i = 0; i < screenParts.length; i++) {
      if (screenParts[i] == null) missing.add(i + 1);
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'surveillance_room.glb: found $lumiresPrimitiveCount Lumires primitive(s) '
        'with $lumiresTriangleCount triangles, but could not bind original '
        'screen face(s): ${missing.join(', ')}.',
      );
    }

    _screenPrimitives
      ..clear()
      ..addAll(screenParts.cast<MeshPrimitive>());

    _screenMaterials.clear();
    for (var i = 0; i < _screenPrimitives.length; i++) {
      final owner = _screenOwners[i].clamp(0, 3).toInt();
      final material = _unlit(GuessTimePalette.colors[owner])
        ..name = 'guess_real_screen_$i'
        ..vertexColorWeight = 0
        ..doubleSided = true;
      _screenMaterials.add(material);
      _screenPrimitives[i].material = material;
    }

    _applyOriginalScreenMaterials();
  }

  int? _screenIndexForAuthoredPoint(vm.Vector3 point) {
    var bestIndex = -1;
    var bestScore = double.infinity;

    for (var i = 0; i < _screenSpecs.length; i++) {
      final spec = _screenSpecs[i];
      final delta = point - spec.center;
      final right = delta.dot(spec.right).abs();
      final up = delta.dot(spec.up).abs();
      final normal = delta.dot(spec.normal).abs();

      // Triangle centroids from the real luminous face are inside these limits.
      // The small margin tolerates importer float differences and edge bevels.
      final halfWidth = spec.width * .62;
      final halfHeight = spec.height * .62;
      const planeTolerance = .085;
      if (right > halfWidth || up > halfHeight || normal > planeTolerance) {
        continue;
      }

      final score =
          (right / math.max(.0001, spec.width * .5)) *
                  (right / math.max(.0001, spec.width * .5)) +
              (up / math.max(.0001, spec.height * .5)) *
                  (up / math.max(.0001, spec.height * .5)) +
              (normal / planeTolerance) * (normal / planeTolerance);
      if (score < bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    if (bestIndex >= 0) return bestIndex;

    // Fallback for a face whose source triangles are slightly outside the
    // measured rectangle. Still require a tight 3D distance so unrelated
    // luminous details can never become a gameplay screen.
    var nearestIndex = -1;
    var nearestDistance2 = double.infinity;
    for (var i = 0; i < _screenSpecs.length; i++) {
      final delta = point - _screenSpecs[i].center;
      final d2 = delta.length2;
      if (d2 < nearestDistance2) {
        nearestDistance2 = d2;
        nearestIndex = i;
      }
    }
    return nearestDistance2 <= .34 * .34 ? nearestIndex : null;
  }

  MeshData _subsetScreenMeshData(
    MeshData source,
    List<int> sourceCorners,
    Node node,
    vm.Matrix4 roomWorldInverse,
    _ScreenSpec spec,
  ) {
    final oldToNew = <int, int>{};
    final sourceVertices = <int>[];
    final newIndices = <int>[];

    for (final oldIndex in sourceCorners) {
      final newIndex = oldToNew.putIfAbsent(oldIndex, () {
        sourceVertices.add(oldIndex);
        return sourceVertices.length - 1;
      });
      newIndices.add(newIndex);
    }

    Float32List copyRequired(Float32List input, int components) {
      final output = Float32List(sourceVertices.length * components);
      for (var newVertex = 0; newVertex < sourceVertices.length; newVertex++) {
        final oldVertex = sourceVertices[newVertex];
        final sourceOffset = oldVertex * components;
        final targetOffset = newVertex * components;
        for (var c = 0; c < components; c++) {
          output[targetOffset + c] = input[sourceOffset + c];
        }
      }
      return output;
    }

    Float32List? copyOptional(Float32List? input, int components) =>
        input == null ? null : copyRequired(input, components);

    // surveillance_room.glb packs Lumires UVs into an atlas. Once the real
    // monitor triangles are split, preserving those atlas UVs makes our number
    // texture sample a tiny/unrelated area. Rebuild UV 0 from each monitor's
    // measured right/up basis so the entire material texture maps 0..1 onto the
    // ORIGINAL monitor face itself.
    final remappedUv = Float32List(sourceVertices.length * 2);
    for (var newVertex = 0; newVertex < sourceVertices.length; newVertex++) {
      final oldVertex = sourceVertices[newVertex];
      final p = oldVertex * 3;
      final local = vm.Vector3(
        source.positions[p],
        source.positions[p + 1],
        source.positions[p + 2],
      );
      final runtimeWorld = node.globalTransform.transform3(local);
      final authored = roomWorldInverse.transform3(runtimeWorld);
      final delta = authored - spec.center;
      final u = (.5 + delta.dot(spec.right) / spec.width).clamp(0.0, 1.0);
      final v = (.5 - delta.dot(spec.up) / spec.height).clamp(0.0, 1.0);
      remappedUv[newVertex * 2] = u.toDouble();
      remappedUv[newVertex * 2 + 1] = v.toDouble();
    }

    final customAttributes = <String, MeshAttributeData>{};
    for (final entry in source.customAttributes.entries) {
      customAttributes[entry.key] = MeshAttributeData(
        copyRequired(entry.value.data, entry.value.components),
        components: entry.value.components,
      );
    }

    return MeshData(
      positions: copyRequired(source.positions, 3),
      vertexCount: sourceVertices.length,
      normals: copyOptional(source.normals, 3),
      texCoords: remappedUv,
      texCoords1: copyOptional(source.texCoords1, 2),
      colors: copyOptional(source.colors, 4),
      tangents: copyOptional(source.tangents, 4),
      indices: newIndices,
      primitiveType: source.primitiveType,
      customAttributes: customAttributes,
    );
  }

  MeshData _subsetMeshData(MeshData source, List<int> sourceCorners) {
    final oldToNew = <int, int>{};
    final sourceVertices = <int>[];
    final newIndices = <int>[];

    for (final oldIndex in sourceCorners) {
      final newIndex = oldToNew.putIfAbsent(oldIndex, () {
        sourceVertices.add(oldIndex);
        return sourceVertices.length - 1;
      });
      newIndices.add(newIndex);
    }

    Float32List copyRequired(Float32List input, int components) {
      final output = Float32List(sourceVertices.length * components);
      for (var newVertex = 0; newVertex < sourceVertices.length; newVertex++) {
        final oldVertex = sourceVertices[newVertex];
        final sourceOffset = oldVertex * components;
        final targetOffset = newVertex * components;
        for (var c = 0; c < components; c++) {
          output[targetOffset + c] = input[sourceOffset + c];
        }
      }
      return output;
    }

    Float32List? copyOptional(Float32List? input, int components) =>
        input == null ? null : copyRequired(input, components);

    final customAttributes = <String, MeshAttributeData>{};
    for (final entry in source.customAttributes.entries) {
      customAttributes[entry.key] = MeshAttributeData(
        copyRequired(entry.value.data, entry.value.components),
        components: entry.value.components,
      );
    }

    return MeshData(
      positions: copyRequired(source.positions, 3),
      vertexCount: sourceVertices.length,
      normals: copyOptional(source.normals, 3),
      texCoords: copyOptional(source.texCoords, 2),
      texCoords1: copyOptional(source.texCoords1, 2),
      colors: copyOptional(source.colors, 4),
      tangents: copyOptional(source.tangents, 4),
      indices: newIndices,
      primitiveType: source.primitiveType,
      customAttributes: customAttributes,
    );
  }

  Future<void> _primeScreenTextures() async {
    for (var i = 0; i < _playerScreenValues.length; i++) {
      _playerScreenValues[i] = '00.00';
    }
    final revision = ++_screenTextureRevision;
    await _rebuildPlayerScreenTextures(revision);
  }

  void _applyOriginalScreenMaterials() {
    if (_screenMaterials.length != _screenSpecs.length) return;

    for (var i = 0; i < _screenMaterials.length; i++) {
      final owner = _screenOwners[i].clamp(0, 3).toInt();
      final texture = _playerScreenTextures[owner];
      final material = _screenMaterials[i];
      if (texture == null) {
        material
          ..baseColorTexture = null
          ..baseColorFactor = _vectorColor(GuessTimePalette.colors[owner]);
      } else {
        material
          ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
          ..baseColorTexture = texture;
      }
    }
  }

  String _formatScreenValue(num value) {
    final asDouble = value.toDouble();
    if (asDouble.isFinite && (asDouble - asDouble.roundToDouble()).abs() < .0001) {
      return asDouble.round().toString();
    }
    return asDouble
        .toStringAsFixed(1)
        .replaceFirst(RegExp(r'\.0$'), '');
  }

  Future<Texture2D> _makePlayerScreenTexture(Color color, String value) async {
    const width = 640;
    const height = 466;

    final recorder = dui.PictureRecorder();
    final canvas = dui.Canvas(recorder);
    final background = dui.Paint()..color = color;
    canvas.drawRect(
      dui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      background,
    );

    final frame = dui.Paint()
      ..color = const Color(0x66000000)
      ..style = dui.PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawRect(
      dui.Rect.fromLTWH(9, 9, width - 18.0, height - 18.0),
      frame,
    );

    if (value.isNotEmpty) {
      final shadow = ui.TextPainter(
        text: ui.TextSpan(
          text: value,
          style: const ui.TextStyle(
            fontSize: 154,
            height: 1,
            fontWeight: ui.FontWeight.w900,
            color: Color(0x99000000),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: ui.TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: width.toDouble());

      final text = ui.TextPainter(
        text: ui.TextSpan(
          text: value,
          style: const ui.TextStyle(
            fontSize: 154,
            height: 1,
            fontWeight: ui.FontWeight.w900,
            color: Color(0xFFFFFFFF),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: ui.TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: width.toDouble());

      final x = (width - text.width) * .5;
      final y = (height - text.height) * .5;
      shadow.paint(canvas, Offset(x + 9, y + 10));
      text.paint(canvas, Offset(x, y));
    }

    final image = await recorder.endRecording().toImage(width, height);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }


  Future<Texture2D> _makeStationTimerTexture(Color color, String value) async {
    const width = 384;
    const height = 128;
    final recorder = dui.PictureRecorder();
    final canvas = dui.Canvas(recorder);

    canvas.drawRRect(
      dui.RRect.fromRectAndRadius(
        dui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        const Radius.circular(20),
      ),
      dui.Paint()..color = const Color(0xFF030608),
    );
    canvas.drawRRect(
      dui.RRect.fromRectAndRadius(
        dui.Rect.fromLTWH(6, 6, width - 12.0, height - 12.0),
        const Radius.circular(16),
      ),
      dui.Paint()
        ..color = const Color(0xFF222A2E)
        ..style = dui.PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawRRect(
      dui.RRect.fromRectAndRadius(
        dui.Rect.fromLTWH(16, 16, width - 32.0, height - 32.0),
        const Radius.circular(12),
      ),
      dui.Paint()
        ..color = color.withOpacity(.35)
        ..style = dui.PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final painter = ui.TextPainter(
      text: ui.TextSpan(
        text: value,
        style: ui.TextStyle(
          fontSize: 66,
          height: 1,
          fontWeight: ui.FontWeight.w900,
          color: color,
          letterSpacing: 2.5,
          shadows: const [ui.Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(3, 3))],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: ui.TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: width.toDouble());
    painter.paint(canvas, Offset((width - painter.width) * .5, (height - painter.height) * .5));

    final image = await recorder.endRecording().toImage(width, height);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  Future<void> _rebuildStationTimerTextures(int revision) async {
    if (_stationTimerMaterials.length != 4) return;
    final textures = <Texture2D>[];
    for (var i = 0; i < 4; i++) {
      textures.add(await _makeStationTimerTexture(
        GuessTimePalette.colors[i],
        _stationTimerValues[i],
      ));
    }
    if (revision != _stationTimerTextureRevision) return;
    for (var i = 0; i < 4; i++) {
      _stationTimerTextures[i] = textures[i];
      _stationTimerMaterials[i]
        ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
        ..baseColorTexture = textures[i];
    }
  }

  Future<Texture2D> _makeBigScreenTexture({
    required GuessTimePhase phase,
    required int round,
    required int countdown,
    required int lockedCount,
    required int totalPlayers,
    required List<GuessTimeStanding> roundStandings,
    required List<GuessTimeStanding> finalStandings,
    required String? loserName,
  }) async {
    const width = 1600;
    const height = 1000;
    final recorder = dui.PictureRecorder();
    final canvas = dui.Canvas(recorder);
    final bg = switch (phase) {
      GuessTimePhase.elimination => const Color(0xFF3A080D),
      GuessTimePhase.roundResults => const Color(0xFF071A22),
      GuessTimePhase.finalResults || GuessTimePhase.finished => const Color(0xFF0C241C),
      _ => const Color(0xFF050A0D),
    };
    canvas.drawRect(
      dui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      dui.Paint()..color = tankDeveloperMode ? _dev.bigScreen.screenColor : bg,
    );
    canvas.drawRect(
      dui.Rect.fromLTWH(0, 0, width.toDouble(), 12),
      dui.Paint()..color = const Color(0xFF26363D),
    );
    canvas.drawRect(
      dui.Rect.fromLTWH(0, height - 12.0, width.toDouble(), 12),
      dui.Paint()..color = const Color(0xFF26363D),
    );

    void centerText(
      String value,
      double y, {
      double size = 54,
      Color color = const Color(0xFFFFFFFF),
      ui.FontWeight weight = ui.FontWeight.w900,
      double maxWidth = 1420,
      double xOffset = 0,
    }) {
      final p = ui.TextPainter(
        text: ui.TextSpan(
          text: value,
          style: ui.TextStyle(
            fontSize: size * _dev.bigScreen.globalTextScale,
            fontWeight: weight,
            color: color,
            height: 1.1,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: ui.TextAlign.center,
        maxLines: 3,
      )..layout(maxWidth: maxWidth);
      p.paint(canvas, Offset((width - p.width) * .5 + _dev.bigScreen.globalTextX + xOffset, y + _dev.bigScreen.globalTextY));
    }

    switch (phase) {
      case GuessTimePhase.waiting:
        centerText('استعد', 410, size: 104);
        break;
      case GuessTimePhase.reveal:
        centerText('الجولة $round / 5', 215, size: 44, color: const Color(0x99FFFFFF));
        centerText('احفظ وقت لونك', 380, size: 106);
        centerText('الوقت المطلوب ظاهر على شاشات الجدار', 540, size: 36, color: const Color(0xBFFFFFFF), weight: ui.FontWeight.w700);
        break;
      case GuessTimePhase.countdown:
        centerText(countdown == 0 ? 'ابدأ' : '$countdown', 260, size: 250);
        centerText('استعد لإيقاف المؤقت', 655, size: 42, color: const Color(0xBFFFFFFF), weight: ui.FontWeight.w700);
        break;
      case GuessTimePhase.timing:
        centerText('خَمِّن الآن', 330, size: 112);
        centerText('$lockedCount / $totalPlayers ثبّتوا أوقاتهم', 505, size: 44, color: const Color(0xCCFFFFFF), weight: ui.FontWeight.w700);
        break;
      case GuessTimePhase.roundResults:
      case GuessTimePhase.finalResults:
        final standings = phase == GuessTimePhase.roundResults
            ? roundStandings
            : finalStandings;
        // Result board intentionally shows ONLY: rank, name, and +/- error.
        centerText('الترتيب          الاسم          الفرق ±', _dev.bigScreen.headerY,
            size: _dev.bigScreen.headerFontSize, xOffset: _dev.bigScreen.headerX, color: const Color(0xE6FFFFFF), weight: ui.FontWeight.w900);
        for (var i = 0; i < standings.take(4).length; i++) {
          final s = standings[i];
          final y = _dev.bigScreen.rowsStartY + i * _dev.bigScreen.rowGap;
          canvas.drawRRect(
            dui.RRect.fromRectAndRadius(
              dui.Rect.fromLTWH((width - _dev.bigScreen.rowWidth) * .5 + _dev.bigScreen.rowsX, y, _dev.bigScreen.rowWidth, _dev.bigScreen.rowHeight),
              const Radius.circular(28),
            ),
            dui.Paint()..color = const Color(0x28FFFFFF),
          );
          canvas.drawRect(
            dui.Rect.fromLTWH(98, y + 20, 16, 126),
            dui.Paint()
              ..color = GuessTimePalette.colors[
                  s.player.colorIndex.clamp(0, 3).toInt()],
          );
          final rowText = '${s.rank}     ${s.player.name}     ±${(s.errorMs / 1000).toStringAsFixed(2)} ث';
          final row = ui.TextPainter(
            text: ui.TextSpan(
              text: rowText,
              style: ui.TextStyle(
                fontSize: _dev.bigScreen.rowFontSize * _dev.bigScreen.globalTextScale,
                color: Color(0xFFFFFFFF),
                fontWeight: ui.FontWeight.w900,
                height: 1,
              ),
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: ui.TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: math.max(200.0, _dev.bigScreen.rowWidth - 100).toDouble());
          row.paint(canvas, Offset((width - row.width) * .5 + _dev.bigScreen.rowsX + _dev.bigScreen.globalTextX, y + _dev.bigScreen.rowTextYOffset + _dev.bigScreen.globalTextY));
        }
        break;
      case GuessTimePhase.elimination:
        centerText('الترتيب          الاسم          الفرق ±', _dev.bigScreen.headerY,
            size: _dev.bigScreen.headerFontSize, xOffset: _dev.bigScreen.headerX, color: const Color(0xE6FFFFFF), weight: ui.FontWeight.w900);
        for (var i = 0; i < finalStandings.take(4).length; i++) {
          final s = finalStandings[i];
          final y = _dev.bigScreen.rowsStartY + i * _dev.bigScreen.rowGap;
          canvas.drawRRect(
            dui.RRect.fromRectAndRadius(
              dui.Rect.fromLTWH((width - _dev.bigScreen.rowWidth) * .5 + _dev.bigScreen.rowsX, y, _dev.bigScreen.rowWidth, _dev.bigScreen.rowHeight),
              const Radius.circular(28),
            ),
            dui.Paint()..color = const Color(0x28FFFFFF),
          );
          final rowText = '${s.rank}     ${s.player.name}     ±${(s.errorMs / 1000).toStringAsFixed(2)} ث';
          final row = ui.TextPainter(
            text: ui.TextSpan(
              text: rowText,
              style: ui.TextStyle(
                fontSize: _dev.bigScreen.rowFontSize * _dev.bigScreen.globalTextScale,
                color: Color(0xFFFFFFFF),
                fontWeight: ui.FontWeight.w900,
              ),
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: ui.TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: math.max(200.0, _dev.bigScreen.rowWidth - 100).toDouble());
          row.paint(canvas, Offset((width - row.width) * .5 + _dev.bigScreen.rowsX + _dev.bigScreen.globalTextX, y + _dev.bigScreen.rowTextYOffset + _dev.bigScreen.globalTextY));
        }
        break;
      case GuessTimePhase.finished:
        centerText('الترتيب          الاسم          الفرق ±', _dev.bigScreen.headerY,
            size: _dev.bigScreen.headerFontSize, xOffset: _dev.bigScreen.headerX, color: const Color(0xE6FFFFFF), weight: ui.FontWeight.w900);
        for (var i = 0; i < finalStandings.take(4).length; i++) {
          final s = finalStandings[i];
          final y = _dev.bigScreen.rowsStartY + i * _dev.bigScreen.rowGap;
          canvas.drawRRect(
            dui.RRect.fromRectAndRadius(
              dui.Rect.fromLTWH((width - _dev.bigScreen.rowWidth) * .5 + _dev.bigScreen.rowsX, y, _dev.bigScreen.rowWidth, _dev.bigScreen.rowHeight),
              const Radius.circular(28),
            ),
            dui.Paint()..color = const Color(0x28FFFFFF),
          );
          final rowText = '${s.rank}     ${s.player.name}     ±${(s.errorMs / 1000).toStringAsFixed(2)} ث';
          final row = ui.TextPainter(
            text: ui.TextSpan(
              text: rowText,
              style: ui.TextStyle(
                fontSize: _dev.bigScreen.rowFontSize * _dev.bigScreen.globalTextScale,
                color: Color(0xFFFFFFFF),
                fontWeight: ui.FontWeight.w900,
              ),
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: ui.TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: math.max(200.0, _dev.bigScreen.rowWidth - 100).toDouble());
          row.paint(canvas, Offset((width - row.width) * .5 + _dev.bigScreen.rowsX + _dev.bigScreen.globalTextX, y + _dev.bigScreen.rowTextYOffset + _dev.bigScreen.globalTextY));
        }
        break;
    }

    final image = await recorder.endRecording().toImage(width, height);
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  Future<void> _rebuildBigScreenTexture(
    int revision, {
    required GuessTimePhase phase,
    required int round,
    required int countdown,
    required int lockedCount,
    required int totalPlayers,
    required List<GuessTimeStanding> roundStandings,
    required List<GuessTimeStanding> finalStandings,
    required String? loserName,
  }) async {
    final texture = await _makeBigScreenTexture(
      phase: phase,
      round: round,
      countdown: countdown,
      lockedCount: lockedCount,
      totalPlayers: totalPlayers,
      roundStandings: roundStandings,
      finalStandings: finalStandings,
      loserName: loserName,
    );
    if (revision != _bigScreenTextureRevision) return;
    _bigScreenTexture = texture;
    _bigScreenMaterial
      ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
      ..baseColorTexture = texture;
  }

  Future<void> _rebuildPlayerScreenTextures(int revision) async {
    final textures = <Texture2D>[];
    for (var owner = 0; owner < 4; owner++) {
      textures.add(
        await _makePlayerScreenTexture(
          GuessTimePalette.colors[owner],
          _playerScreenValues[owner],
        ),
      );
    }

    if (revision != _screenTextureRevision || _screenMaterials.length != 28) {
      return;
    }

    for (var owner = 0; owner < 4; owner++) {
      _playerScreenTextures[owner] = textures[owner];
    }
    _applyOriginalScreenMaterials();
  }

  /// Sets the time shown on every ORIGINAL screen belonging to a player.
  /// The text is baked into that screen's material texture -- never a 2D/3D
  /// overlay floating in front of surveillance_room.glb.
  void setPlayerTimes(List<num> values) {
    final formatted = <String>[];
    for (var owner = 0; owner < 4; owner++) {
      formatted.add(
        owner < values.length ? formatGuessTime(values[owner].round()) : '00.00',
      );
    }
    setPlayerScreenTexts(formatted);
  }

  void setPlayerScreenTexts(List<String> values) {
    var changed = false;
    for (var owner = 0; owner < 4; owner++) {
      final next = owner < values.length ? values[owner] : '00.00';
      if (_playerScreenValues[owner] != next) {
        _playerScreenValues[owner] = next;
        changed = true;
      }
    }
    if (!changed) return;
    final revision = ++_screenTextureRevision;
    unawaited(_rebuildPlayerScreenTextures(revision));
  }

  void setPlayerScreenNumbers(List<num> values) => setPlayerTimes(values);


  void setStationTimerTexts(List<String> values) {
    for (var i = 0; i < 4; i++) {
      final next = i < values.length ? values[i] : '00.00';
      if (_stationTimerValues[i] == next) continue;
      _stationTimerValues[i] = next;
      _applySevenSegmentValue(i, next);
    }
  }

  void _applySevenSegmentValue(int stationIndex, String value) {
    if (stationIndex < 0 || stationIndex >= _stationDigitSegments.length) return;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0');
    final normalized = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits;
    for (var i = 0; i < 4; i++) {
      final digit = int.tryParse(normalized[i]) ?? 0;
      _setSevenSegmentDigit(_stationDigitSegments[stationIndex][i], digit);
    }
    if (stationIndex < _stationDecimalDots.length) {
      _stationDecimalDots[stationIndex].visible = true;
    }
  }

  static const List<List<int>> _sevenSegmentMap = <List<int>>[
    [0, 1, 2, 3, 4, 5],       // 0
    [1, 2],                   // 1
    [0, 1, 6, 4, 3],          // 2
    [0, 1, 2, 3, 6],          // 3
    [5, 6, 1, 2],             // 4
    [0, 5, 6, 2, 3],          // 5
    [0, 5, 4, 3, 2, 6],       // 6
    [0, 1, 2],                // 7
    [0, 1, 2, 3, 4, 5, 6],    // 8
    [0, 1, 2, 3, 5, 6],       // 9
  ];

  void _setSevenSegmentDigit(List<Node> segments, int digit) {
    final on = _sevenSegmentMap[digit.clamp(0, 9).toInt()];
    for (var i = 0; i < segments.length; i++) {
      segments[i].visible = on.contains(i);
    }
  }

  List<Node> _buildSevenSegmentDigit(
    UnlitMaterial material, {
    required vm.Vector3 center,
    double scale = 1,
  }) {
    final h = vm.Vector3(.070 * scale, .010 * scale, .008);
    final v = vm.Vector3(.010 * scale, .045 * scale, .008);
    final x = -.043 * scale;
    final y = .045 * scale;
    final z = center.z;
    Node seg(String name, vm.Vector3 position, vm.Vector3 size) => _mesh(
      _geo.unitCube,
      material,
      name: name,
      position: position,
      scale: size,
    )..castsShadows = false;
    return <Node>[
      seg('seg_a', vm.Vector3(center.x, center.y + y, z), h),
      seg('seg_b', vm.Vector3(center.x + x, center.y + y * .5, z), v),
      seg('seg_c', vm.Vector3(center.x + x, center.y - y * .5, z), v),
      seg('seg_d', vm.Vector3(center.x, center.y - y, z), h),
      seg('seg_e', vm.Vector3(center.x - x, center.y - y * .5, z), v),
      seg('seg_f', vm.Vector3(center.x - x, center.y + y * .5, z), v),
      seg('seg_g', vm.Vector3(center.x, center.y, z), h),
    ];
  }

  void setBigScreenDisplay({
    required GuessTimePhase phase,
    required int round,
    required int countdown,
    required int lockedCount,
    required int totalPlayers,
    required List<GuessTimeStanding> roundStandings,
    required List<GuessTimeStanding> finalStandings,
    required String? loserName,
  }) {
    _cachedBigScreenPhase = phase;
    _cachedBigScreenRound = round;
    _cachedBigScreenCountdown = countdown;
    _cachedBigScreenLockedCount = lockedCount;
    _cachedBigScreenTotalPlayers = totalPlayers;
    _cachedRoundStandings = List<GuessTimeStanding>.from(roundStandings);
    _cachedFinalStandings = List<GuessTimeStanding>.from(finalStandings);
    _cachedLoserName = loserName;
    final signature = [
      phase.name,
      round,
      countdown,
      lockedCount,
      totalPlayers,
      loserName ?? '',
      ...roundStandings.take(4).map((s) => '${s.rank}:${s.player.id}:${s.player.stoppedMs}:${s.errorMs}'),
      '|',
      ...finalStandings.take(4).map((s) => '${s.rank}:${s.player.id}:${s.errorMs}'),
    ].join('~');
    if (_lastBigScreenSignature == signature) return;
    _lastBigScreenSignature = signature;
    final revision = ++_bigScreenTextureRevision;
    unawaited(_rebuildBigScreenTexture(
      revision,
      phase: phase,
      round: round,
      countdown: countdown,
      lockedCount: lockedCount,
      totalPlayers: totalPlayers,
      roundStandings: List<GuessTimeStanding>.from(roundStandings),
      finalStandings: List<GuessTimeStanding>.from(finalStandings),
      loserName: loserName,
    ));
  }


  void _refreshBigScreenDeveloperTexture() {
    if (tankDeveloperMode) {
      final revision = ++_bigScreenTextureRevision;
      unawaited(_rebuildBigScreenDeveloperStatsTexture(revision));
      return;
    }
    final phase = _cachedBigScreenPhase;
    if (phase == null) return;
    final revision = ++_bigScreenTextureRevision;
    unawaited(_rebuildBigScreenTexture(
      revision,
      phase: phase,
      round: _cachedBigScreenRound,
      countdown: _cachedBigScreenCountdown,
      lockedCount: _cachedBigScreenLockedCount,
      totalPlayers: _cachedBigScreenTotalPlayers,
      roundStandings: List<GuessTimeStanding>.from(_cachedRoundStandings),
      finalStandings: List<GuessTimeStanding>.from(_cachedFinalStandings),
      loserName: _cachedLoserName,
    ));
  }

  Future<void> _rebuildBigScreenDeveloperStatsTexture(int revision) async {
    const width = 1600;
    const height = 1000;
    final t = _dev.bigScreen;
    final recorder = dui.PictureRecorder();
    final canvas = dui.Canvas(recorder);
    canvas.drawRect(
      dui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      dui.Paint()..color = t.screenColor,
    );
    canvas.drawRect(
      dui.Rect.fromLTWH(0, 0, width.toDouble(), 12),
      dui.Paint()..color = _shadeColor(t.frameColor, 1.15),
    );
    canvas.drawRect(
      dui.Rect.fromLTWH(0, height - 12.0, width.toDouble(), 12),
      dui.Paint()..color = _shadeColor(t.frameColor, 1.15),
    );

    void centerText(String value, double y, double size, {Color color = const Color(0xFFFFFFFF), double xOffset = 0}) {
      final p = ui.TextPainter(
        text: ui.TextSpan(
          text: value,
          style: ui.TextStyle(
            fontSize: size * t.globalTextScale,
            fontWeight: ui.FontWeight.w900,
            color: color,
            height: 1.05,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: ui.TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: 1500);
      p.paint(canvas, Offset((width - p.width) * .5 + t.globalTextX + xOffset, y + t.globalTextY));
    }

    centerText('الترتيب          الاسم          الفرق ±', t.headerY, t.headerFontSize, xOffset: t.headerX, color: const Color(0xEFFFFFFF));
    const names = ['محمد', 'علي', 'حسن', 'مصطفى'];
    const errors = [0.08, 0.21, 0.47, 0.93];
    for (var i = 0; i < 4; i++) {
      final y = t.rowsStartY + i * t.rowGap;
      canvas.drawRRect(
        dui.RRect.fromRectAndRadius(
          dui.Rect.fromLTWH((width - t.rowWidth) * .5 + t.rowsX, y, t.rowWidth, t.rowHeight),
          const Radius.circular(28),
        ),
        dui.Paint()..color = const Color(0x28FFFFFF),
      );
      canvas.drawRect(
        dui.Rect.fromLTWH((width - t.rowWidth) * .5 + t.rowsX + 18, y + 20, 14, math.max(20.0, t.rowHeight - 40)),
        dui.Paint()..color = GuessTimePalette.colors[i],
      );
      centerText('${i + 1}     ${names[i]}     ±${errors[i].toStringAsFixed(2)} ث', y + t.rowTextYOffset, t.rowFontSize, xOffset: t.rowsX);
    }

    final image = await recorder.endRecording().toImage(width, height);
    try {
      final texture = await Texture2D.fromImage(image);
      if (revision != _bigScreenTextureRevision) return;
      _bigScreenTexture = texture;
      _bigScreenMaterial
        ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
        ..baseColorTexture = texture;
    } finally {
      image.dispose();
    }
  }


  void setPlayerBehavior({
    required GuessTimePhase phase,
    required int elapsedMs,
    required List<bool> locked,
  }) {
    _behaviorPhase = phase;
    _behaviorElapsedMs = elapsedMs;
    for (var i = 0; i < _behaviorLocked.length; i++) {
      _behaviorLocked[i] = i < locked.length ? locked[i] : false;
    }
  }

  double stationDistance(int a, int b) {
    if (a < 0 || b < 0 || a >= _stations.length || b >= _stations.length) {
      return 0;
    }
    return (_stationPosition(a) - _stationPosition(b)).length;
  }

  _RoomLayout _deriveRoomLayout() {
    final center = vm.Vector3.zero();
    final normalSum = vm.Vector3.zero();
    for (final screen in _screenSpecs) {
      center.add(screen.center);
      normalSum.add(screen.normal);
    }
    center.scale(1 / _screenSpecs.length);
    normalSum.scale(1 / _screenSpecs.length);

    // The individual monitors are pitched toward the operator, so only the
    // horizontal component is used to establish the audience side of the wall.
    final front = vm.Vector3(normalSum.x, 0, normalSum.z)..normalize();
    final up = vm.Vector3(0, 1, 0);
    final right = up.cross(front)..normalize();

    var minRight = double.infinity;
    var maxRight = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final screen in _screenSpecs) {
      final p = screen.center.dot(right);
      minRight = math.min(minRight, p - screen.width * .5);
      maxRight = math.max(maxRight, p + screen.width * .5);
      minY = math.min(minY, screen.center.y - screen.height * .5);
      maxY = math.max(maxY, screen.center.y + screen.height * .5);
    }

    final wallWidth = maxRight - minRight;
    final wallHeight = maxY - minY;

    // Distances are derived from the measured wall width. This keeps the whole
    // layout proportional to the actual room instead of depending on guessed
    // X/Z coordinates. The row sits on the viewer side of the screen wall.
    final chairDistance = wallWidth * .64;
    final deskLead = wallWidth * .15;
    final stationSpacing = math.max(1.24, wallWidth / 4.15);
    final cameraTrail = wallWidth * .29;

    final rowCenter = vm.Vector3(center.x, _roomFloorY, center.z) + front * chairDistance;
    final deskCenter = rowCenter - front * deskLead;
    final cameraPosition = rowCenter + front * cameraTrail + up * (wallHeight * .80);
    final cameraTarget = vm.Vector3(
      (center.x + rowCenter.x) * .5,
      _roomFloorY + wallHeight * .70,
      (center.z + rowCenter.z) * .5,
    );

    return _RoomLayout(
      screensCenter: center,
      front: front,
      right: right,
      wallWidth: wallWidth,
      wallHeight: wallHeight,
      rowCenter: rowCenter,
      deskCenter: deskCenter,
      stationSpacing: stationSpacing,
      deskLead: deskLead,
      cameraPosition: cameraPosition,
      cameraTarget: cameraTarget,
    );
  }

  double _stationArcAngle(int index) {
    final radius = _layout.stationSpacing * 5.80;
    final step = _layout.stationSpacing / radius;
    return (index - 1.5) * step;
  }

  vm.Vector3 _baseStationPosition(int index) {
    final radius = _layout.stationSpacing * 5.80;
    final angle = _stationArcAngle(index);
    final arcOrigin = _layout.rowCenter + _layout.front * radius;
    return arcOrigin
        - _layout.front * (math.cos(angle) * radius)
        + _layout.right * (math.sin(angle) * radius);
  }

  double _baseStationYaw(int index) {
    final station = _baseStationPosition(index);
    final screenWorld = _authoredRoomPointToWorld(_layout.screensCenter);
    final target = vm.Vector3(screenWorld.x, station.y, screenWorld.z);
    final direction = target - station;
    return math.atan2(-direction.x, -direction.z);
  }

  void _initializeDeveloperStations() {
    const presets = <Map<String, double>>[
      {'x': 0.3969, 'y': -2.8885, 'z': 2.1992, 'pitch': 0, 'yaw': -53.109, 'roll': 0, 'camX': 0, 'camY': .2600, 'camZ': -.1100, 'camYaw': 0, 'camPitch': 0, 'camFov': 74},
      {'x': 1.5909, 'y': -2.8885, 'z': 3.0702, 'pitch': 0, 'yaw': -23.657, 'roll': 0, 'camX': 0, 'camY': .2000, 'camZ': -.1100, 'camYaw': 0, 'camPitch': 0, 'camFov': 74},
      {'x': 2.9236, 'y': -2.8885, 'z': 3.4509, 'pitch': 0, 'yaw': -12.454, 'roll': 0, 'camX': 0, 'camY': .2000, 'camZ': -.1100, 'camYaw': 0, 'camPitch': 0, 'camFov': 74},
      {'x': 4.2585, 'y': -2.8885, 'z': 3.4449, 'pitch': 0, 'yaw': 3.490, 'roll': 0, 'camX': 0, 'camY': .2000, 'camZ': -.1100, 'camYaw': 0, 'camPitch': 0, 'camFov': 74},
    ];
    for (var i = 0; i < 4; i++) {
      final s = _dev.stations[i];
      final c = presets[i];
      s
        ..x = c['x']!
        ..y = c['y']!
        ..z = c['z']!
        ..pitchDegrees = c['pitch']!
        ..yawDegrees = c['yaw']!
        ..rollDegrees = c['roll']!
        ..cameraX = c['camX']!
        ..cameraY = c['camY']!
        ..cameraZ = c['camZ']!
        ..cameraYawDegrees = c['camYaw']!
        ..cameraPitchDegrees = c['camPitch']!
        ..cameraFovDegrees = c['camFov']!
        ..initialized = true;
      s.captureDefaults();
    }
    _initializeDeveloperPoses();
  }

  void _initializeDeveloperPoses() {
    _PlayerPoseTuning applyPose(_PlayerPoseTuning p) {
      p
        ..x = 0
        ..y = .0200
        ..z = 0
        ..pitchDegrees = 0
        ..yawDegrees = 180
        ..rollDegrees = -.600
        ..scale = .960
        ..bodyX = 0
        ..bodyY = -.1940
        ..bodyZ = -.0500;
      p.hips.set(-2.865, 0, 0);
      p.spine.set(4.584, 0, 0);
      p.spine1.set(3.438, 0, 0);
      p.neck.set(0, 0, 0);
      p.head.set(0, 0, 0);
      p.leftShoulder.set(0.000, -30.000, -20.000);
      p.leftArm.set(-42.000, 0.000, 0.000);
      p.leftForeArm.set(2.000, 80.000, 1.000);
      p.leftHand.set(20.000, 1.000, 45.000);
      p.rightShoulder.set(-3.000, 40.000, 0.000);
      p.rightArm.set(-10.000, -40.000, 0.000);
      p.rightForeArm.set(40.000, 40.000, 0.000);
      p.rightHand.set(0.000, -9.000, 0.000);
      p.leftUpLeg.set(0.000, 0.000, -75.000);
      p.leftLeg.set(0.000, 0.000, 70.000);
      p.leftFoot.set(0.000, 0.000, 0.000);
      p.rightUpLeg.set(0.000, 0.000, 75.000);
      p.rightLeg.set(0.000, 0.000, -70.000);
      p.rightFoot.set(0.000, 0.000, 0.000);
      p.captureDefaults();
      return p;
    }
    for (var i = 0; i < _dev.poses.length; i++) {
      applyPose(_dev.poses[i]);
    }
  }

  vm.Vector3 _stationPosition(int index) {
    if (index >= 0 && index < _dev.stations.length) {
      final s = _dev.stations[index];
      if (s.initialized) return vm.Vector3(s.x, s.y, s.z);
    }
    return _baseStationPosition(index);
  }

  vm.Quaternion _stationRotation(int index) {
    if (index >= 0 && index < _dev.stations.length) {
      final s = _dev.stations[index];
      if (s.initialized) {
        final qPitch = vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          s.pitchDegrees * math.pi / 180,
        );
        final qYaw = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          s.yawDegrees * math.pi / 180,
        );
        final qRoll = vm.Quaternion.axisAngle(
          vm.Vector3(0, 0, 1),
          s.rollDegrees * math.pi / 180,
        );
        return qYaw * qPitch * qRoll;
      }
    }
    return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _baseStationYaw(index));
  }

  double _stationYaw(int index) {
    if (index >= 0 && index < _dev.stations.length) {
      final s = _dev.stations[index];
      if (s.initialized) return s.yawDegrees * math.pi / 180;
    }
    return _baseStationYaw(index);
  }

  vm.Vector3 _rotateLocalY(vm.Vector3 local, double yaw) {
    final c = math.cos(yaw);
    final s = math.sin(yaw);
    return vm.Vector3(
      local.x * c + local.z * s,
      local.y,
      -local.x * s + local.z * c,
    );
  }

  vm.Vector3 _rotateStationLocal(int index, vm.Vector3 local) {
    final matrix = vm.Matrix4.compose(
      vm.Vector3.zero(),
      _stationRotation(index),
      vm.Vector3.all(1),
    );
    return matrix.transform3(vm.Vector3.copy(local));
  }

  vm.Vector3 _stationLocalToWorld(int index, vm.Vector3 local) {
    return _stationPosition(index) + _rotateStationLocal(index, local);
  }

  void _applyDeveloperStationTransform(int index) {
    if (index < 0 || index >= _stations.length) return;
    final station = _stations[index]
      ..position = _stationPosition(index)
      ..rotation = _stationRotation(index);
    // Keep the assignment explicit so flutter_scene invalidates the transform.
    station.position = _stationPosition(index);
    if (index < _buttonPositions.length) {
      _buttonPositions[index] = _stationLocalToWorld(
        index,
        vm.Vector3(0, .82, -_layout.deskLead + .10),
      );
    }
    if (index < _stationDisplayPositions.length) {
      _stationDisplayPositions[index] = _stationLocalToWorld(
        index,
        vm.Vector3(0, .875, -_layout.deskLead - .055),
      );
    }
  }

  void _resetDeveloperStation(int index) {
    if (index < 0 || index >= _dev.stations.length) return;
    _dev.stations[index].resetToDefaults();
    _applyDeveloperStationTransform(index);
  }

  void _resetAllDeveloperStations() {
    for (var i = 0; i < _dev.stations.length; i++) {
      _resetDeveloperStation(i);
    }
  }

  void _buildRoomSafetyShell() {
    // The source GLB is open around the player row. Without surrounding
    // geometry a first-person camera legitimately sees SceneView's black clear
    // color when the user looks away from the monitor wall. This matte shell is
    // deliberately outside the authored set, only filling those open directions
    // so left/right/up/down never collapse into a completely black frame.
    final screenWorld = _authoredRoomPointToWorld(_layout.screensCenter);
    final row = _layout.rowCenter;
    final toward = vm.Vector3(screenWorld.x - row.x, 0, screenWorld.z - row.z);
    if (toward.length2 < .0001) return;
    toward.normalize();
    final up = vm.Vector3(0, 1, 0);
    final right = up.cross(toward)..normalize();

    final roomRotation = _rotationFromBasis(right, up, toward);
    final distance = vm.Vector3(screenWorld.x - row.x, 0, screenWorld.z - row.z).length;
    final depth = math.max(9.0, distance + 5.5);
    final width = math.max(11.0, _layout.wallWidth + 6.0);
    const height = 6.8;
    final center = row + toward * ((distance - 1.0) * .5);
    final floorY = _roomFloorY - .18;
    final centerY = floorY + height * .5;

    final wallMat = _pbr(const Color(0xFF17180C), roughness: .98, metallic: .0);
    final floorMat = _pbr(const Color(0xFF343313), roughness: .98, metallic: .0);
    final ceilingMat = _pbr(const Color(0xFF101108), roughness: 1.0, metallic: .0);

    final floorCenter = vm.Vector3(center.x, floorY, center.z);
    final ceilingCenter = vm.Vector3(center.x, floorY + height, center.z);
    final backCenter = vm.Vector3(row.x, centerY, row.z) - toward * 3.0;
    final frontCenter = vm.Vector3(screenWorld.x, centerY, screenWorld.z) + toward * .7;
    final sideCenter = vm.Vector3(center.x, centerY, center.z);

    final shell = Node(name: 'guess_room_safety_shell');
    shell.addAll([
      _mesh(
        _geo.unitCube,
        floorMat,
        name: 'guess_room_floor_extension',
        position: floorCenter,
        scale: vm.Vector3(width, .12, depth),
        rotation: roomRotation,
      ),
      _mesh(
        _geo.unitCube,
        ceilingMat,
        name: 'guess_room_ceiling_extension',
        position: ceilingCenter,
        scale: vm.Vector3(width, .12, depth),
        rotation: roomRotation,
      ),
      _mesh(
        _geo.unitCube,
        wallMat,
        name: 'guess_room_back_wall',
        position: backCenter,
        scale: vm.Vector3(width, height, .16),
        rotation: roomRotation,
      ),
      _mesh(
        _geo.unitCube,
        wallMat,
        name: 'guess_room_front_backdrop',
        position: frontCenter,
        scale: vm.Vector3(width, height, .12),
        rotation: roomRotation,
      ),
      _mesh(
        _geo.unitCube,
        wallMat,
        name: 'guess_room_left_wall',
        position: sideCenter - right * (width * .5),
        scale: vm.Vector3(.12, height, depth),
        rotation: roomRotation,
      ),
      _mesh(
        _geo.unitCube,
        wallMat,
        name: 'guess_room_right_wall',
        position: sideCenter + right * (width * .5),
        scale: vm.Vector3(.12, height, depth),
        rotation: roomRotation,
      ),
    ]);
    scene.add(shell);
  }


  Future<void> _buildEnvironment() async {
    _environmentRoot = Node(name: 'guess_environment_root');
    scene.add(_environmentRoot);

    _outerGroundMaterial = _pbr(_dev.environment.groundColor, roughness: .96, metallic: .02);
    _outerGround = Node(name: 'guess_outer_ground')
      ..mesh = Mesh.primitives(primitives: [MeshPrimitive(_geo.unitCube, _outerGroundMaterial)])
      ..castsShadows = true;
    _environmentRoot.add(_outerGround);

    const maxMountains = 16;
    for (var i = 0; i < maxMountains; i++) {
      Node model;
      try {
        model = await Node.fromGlbAsset('assets/models/mountain_looking_sand_mound_scan.glb');
      } catch (_) {
        model = _makeFallbackMountainModel();
      }
      model.name = 'guess_mountain_model_$i';
      _tintNodeMaterials(model, _dev.environment.mountains[i].color);
      for (final mesh in model.meshNodes) {
        mesh
          ..castsShadows = true;
      }
      final root = Node(name: 'guess_mountain_root_$i');
      root.add(model);
      _mountainRoots.add(root);
      _mountainModels.add(model);
      _mountainMaterials.add(_pbr(_dev.environment.mountains[i].color, roughness: .97, metallic: .01));
      _environmentRoot.add(root);
    }
    _applyEnvironmentDeveloperSettings();
  }

  Node _makeFallbackMountainModel() {
    final material = _pbr(const Color(0xFF8E7D4B), roughness: .97, metallic: .01);
    final root = Node(name: 'guess_fallback_mountain');
    final base = Node(name: 'guess_fallback_mountain_base')
      ..mesh = Mesh.primitives(primitives: [MeshPrimitive(_geo.button, material)])
      ..scale = vm.Vector3(1.8, .55, 1.8)
      ..castsShadows = true;
    final peak = Node(name: 'guess_fallback_mountain_peak')
      ..mesh = Mesh.primitives(primitives: [MeshPrimitive(_geo.button, material)])
      ..position = vm.Vector3(.0, .42, -.12)
      ..scale = vm.Vector3(1.05, .72, 1.05)
      ..castsShadows = true;
    root
      ..add(base)
      ..add(peak);
    return root;
  }

  void _tintNodeMaterials(Node root, Color color) {
    for (final meshNode in root.meshNodes) {
      final mesh = meshNode.mesh;
      if (mesh == null) continue;
      final updated = <MeshPrimitive>[];
      for (final primitive in mesh.primitives) {
        final source = primitive.material;
        if (source is PhysicallyBasedMaterial) {
          source.baseColorFactor = _vectorColor(color.withAlpha(255));
          source.alphaMode = AlphaMode.opaque;
          source.doubleSided = true;
          updated.add(MeshPrimitive(primitive.geometry, source)..castsShadow = primitive.castsShadow);
        } else if (source is UnlitMaterial) {
          source.baseColorFactor = _vectorColor(color.withAlpha(255));
          source.alphaMode = AlphaMode.opaque;
          source.doubleSided = true;
          updated.add(MeshPrimitive(primitive.geometry, source)..castsShadow = primitive.castsShadow);
        } else {
          final material = _pbr(color.withAlpha(255), roughness: .97, metallic: .01)
            ..alphaMode = AlphaMode.opaque
            ..doubleSided = true;
          updated.add(MeshPrimitive(primitive.geometry, material)..castsShadow = primitive.castsShadow);
        }
      }
      meshNode.mesh = Mesh.primitives(primitives: updated);
    }
  }

  void _applyEnvironmentDeveloperSettings() {
    final e = _dev.environment;
    _outerGround.visible = e.showGround;
    _outerGroundMaterial.baseColorFactor = _vectorColor(e.groundColor);
    _outerGround
      ..position = vm.Vector3(e.groundX, e.groundY, e.groundZ)
      ..rotation = vm.Quaternion.euler(
        vm.radians(e.groundPitchDegrees),
        vm.radians(e.groundYawDegrees),
        vm.radians(e.groundRollDegrees),
      )
      ..scale = vm.Vector3(
        math.max(.01, e.groundWidth),
        math.max(.01, e.groundThickness),
        math.max(.01, e.groundDepth),
      );

    final count = e.mountainCount.clamp(0, _mountainRoots.length).toInt();
    final arcStep = count <= 1 ? 0.0 : e.arcDegrees / count;
    for (var i = 0; i < _mountainRoots.length; i++) {
      final root = _mountainRoots[i];
      final model = _mountainModels[i];
      final m = e.mountains[i];
      final active = e.showMountains && i < count && m.enabled;
      root.visible = active;
      if (!active) continue;
      final angle = vm.radians(e.startAngleDegrees + arcStep * i);
      final radius = math.max(.1, e.ringRadius + m.radiusOffset);
      final px = e.centerX + math.cos(angle) * radius + m.x;
      final pz = e.centerZ + math.sin(angle) * radius + m.z;
      final py = e.centerY + m.y;
      final yaw = e.baseYawDegrees + e.faceCenterYawOffsetDegrees + m.yawDegrees;
      root
        ..position = vm.Vector3(px, py, pz)
        ..rotation = vm.Quaternion.euler(
          vm.radians(e.basePitchDegrees + m.pitchDegrees),
          vm.radians(yaw),
          vm.radians(e.baseRollDegrees + m.rollDegrees),
        );
      model.scale = vm.Vector3(
        math.max(.001, e.scaleX * m.scaleX),
        math.max(.001, e.scaleY * m.scaleY),
        math.max(.001, e.scaleZ * m.scaleZ),
      );
      _tintNodeMaterials(model, m.color);
      _mountainMaterials[i].baseColorFactor = _vectorColor(m.color.withAlpha(255));
      _mountainMaterials[i].alphaMode = AlphaMode.opaque;
      _mountainMaterials[i].doubleSided = true;
    }
  }

  String _environmentDeveloperSettingsText() {
    final e = _dev.environment;
    final b = StringBuffer('GUESS_TIME_ENVIRONMENT');
    b.writeln();
    b.writeln('GROUND visible=${e.showGround} color=${e.groundColor.toARGB32().toRadixString(16)} pos=${e.groundX.toStringAsFixed(3)},${e.groundY.toStringAsFixed(3)},${e.groundZ.toStringAsFixed(3)} rot=${e.groundPitchDegrees.toStringAsFixed(2)},${e.groundYawDegrees.toStringAsFixed(2)},${e.groundRollDegrees.toStringAsFixed(2)} size=${e.groundWidth.toStringAsFixed(3)},${e.groundThickness.toStringAsFixed(3)},${e.groundDepth.toStringAsFixed(3)}');
    b.writeln('MOUNTAINS visible=${e.showMountains} count=${e.mountainCount} center=${e.centerX.toStringAsFixed(3)},${e.centerY.toStringAsFixed(3)},${e.centerZ.toStringAsFixed(3)} radius=${e.ringRadius.toStringAsFixed(3)} arc=${e.arcDegrees.toStringAsFixed(2)} start=${e.startAngleDegrees.toStringAsFixed(2)} baseScale=${e.scaleX.toStringAsFixed(3)},${e.scaleY.toStringAsFixed(3)},${e.scaleZ.toStringAsFixed(3)} baseRot=${e.basePitchDegrees.toStringAsFixed(2)},${e.baseYawDegrees.toStringAsFixed(2)},${e.baseRollDegrees.toStringAsFixed(2)} face=${e.faceCenterYawOffsetDegrees.toStringAsFixed(2)}');
    for (var i = 0; i < e.mountains.length; i++) {
      final m = e.mountains[i];
      b.writeln('MOUNTAIN_${i + 1} enabled=${m.enabled} offset=${m.x.toStringAsFixed(3)},${m.y.toStringAsFixed(3)},${m.z.toStringAsFixed(3)} radiusOffset=${m.radiusOffset.toStringAsFixed(3)} scale=${m.scaleX.toStringAsFixed(3)},${m.scaleY.toStringAsFixed(3)},${m.scaleZ.toStringAsFixed(3)} rot=${m.pitchDegrees.toStringAsFixed(2)},${m.yawDegrees.toStringAsFixed(2)},${m.rollDegrees.toStringAsFixed(2)} color=${m.color.toARGB32().toRadixString(16)}');
    }
    return b.toString();
  }

  void _buildBigScreen() {
    _bigScreenMaterial = _unlit(const Color(0xFFFFFFFF))
      ..vertexColorWeight = 0
      ..doubleSided = true;
    final topY = _screenSpecs
        .map((s) => s.center.y + s.height * .5)
        .reduce(math.max);
    final authoredTop = vm.Vector3(
      _layout.screensCenter.x,
      topY,
      _layout.screensCenter.z,
    );
    final transformedTop = _authoredRoomPointToWorld(authoredTop);
    final position = transformedTop + vm.Vector3(0, _layout.wallHeight * .40, 0);
    final normal = vm.Vector3(
      _layout.rowCenter.x - position.x,
      0,
      _layout.rowCenter.z - position.z,
    )..normalize();
    final screenUp = vm.Vector3(0, 1, 0);
    final screenRight = screenUp.cross(normal)..normalize();
    final rotation = _rotationFromBasis(screenRight, screenUp, normal);

    _bigScreenFrameMaterial = _pbr(const Color(0xFF1A2328), roughness: .55, metallic: .24);
    _bigScreenBezelMaterial = _pbr(const Color(0xFF090E11), roughness: .72, metallic: .10);
    _bigScreenBasePosition = vm.Vector3.copy(position);
    _bigScreenBaseRotation = vm.Quaternion.copy(rotation);
    _bigScreenMount = Node(name: 'guess_big_result_screen_mount')
      ..position = position
      ..rotation = rotation;
    _bigScreenFrame = _mesh(
      _geo.unitCube,
      _bigScreenFrameMaterial,
      position: vm.Vector3(0, 0, -.07),
      scale: vm.Vector3(_layout.wallWidth * .76, _layout.wallHeight * .62, .14),
    );
    _bigScreenFrameCross = _mesh(
      _geo.unitCube,
      _bigScreenFrameMaterial,
      position: vm.Vector3(0, 0, -.07),
      scale: vm.Vector3(_layout.wallWidth * .76, _layout.wallHeight * .62, .14),
    );
    for (var i = 0; i < 4; i++) {
      final n = _mesh(
        _geo.explosion,
        _bigScreenFrameMaterial,
        position: vm.Vector3.zero(),
        scale: vm.Vector3.zero(),
      );
      _bigScreenFrameRoundNodes.add(n);
    }
    _bigScreenBezel = _mesh(
      _geo.unitCube,
      _bigScreenBezelMaterial,
      position: vm.Vector3(0, 0, -.025),
      scale: vm.Vector3(_layout.wallWidth * .71, _layout.wallHeight * .56, .07),
    );
    _bigScreenMount.add(_bigScreenFrame);
    _bigScreenMount.add(_bigScreenFrameCross);
    _bigScreenMount.addAll(_bigScreenFrameRoundNodes);
    _bigScreenMount.add(_bigScreenBezel);
    _bigScreen = _mesh(
      _geo.displayPlane,
      _bigScreenMaterial,
      name: 'guess_big_result_screen',
      position: vm.Vector3(0, 0, .014),
      scale: vm.Vector3(
        -_layout.wallWidth * .66,
        1,
        _layout.wallHeight * .49,
      ),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
    )..castsShadows = false;
    _bigScreenMount.add(_bigScreen);
    scene.add(_bigScreenMount);
    _applyBigScreenDeveloperTuning();
  }

  void _buildStations() {
    for (var i = 0; i < 4; i++) {
      final color = _vividPlayerColor(GuessTimePalette.colors[i]);
      _dev.surfaces[i].timerDigitColor = color;
      final metal = _pbr(const Color(0xFF222B31), roughness: .42, metallic: .62);
      final pedestalMat = _pbr(const Color(0xFF182228), roughness: .58, metallic: .34);
      final dark = _pbr(const Color(0xFF10171B), roughness: .62, metallic: .28);
      final timerShell = _pbr(const Color(0xFF222B31), roughness: .46, metallic: .48);
      _deskPrimaryMaterials.add(metal);
      _deskSecondaryMaterials.add(pedestalMat);
      _timerShellMaterials.add(timerShell);
      final accent = _unlit(color);
      final root = Node(name: 'player_station_$i')
        ..position = _stationPosition(i)
        ..rotation = _stationRotation(i);

      final desk = _mesh(
        _geo.unitCube,
        metal,
        name: 'station_desk_$i',
        position: vm.Vector3(0, .66, -_layout.deskLead),
        scale: vm.Vector3(.92, .10, .52),
      );
      final pedestal = _mesh(
        _geo.unitCube,
        pedestalMat,
        position: vm.Vector3(0, .35, -_layout.deskLead + .04),
        scale: vm.Vector3(.72, .56, .42),
      );
      final accentStrip = _mesh(
        _geo.unitCube,
        accent,
        position: vm.Vector3(0, .72, -_layout.deskLead - .20),
        scale: vm.Vector3(.62, .035, .025),
      )..castsShadows = false;

      // Compact physical stopwatch. The old solid bezel sat in front of the
      // display and hid every digit. The new bezel is four thin frame bars,
      // while the seven-segment digits sit on the player-facing side.
      final timerLocal = vm.Vector3(0, .875, -_layout.deskLead - .055);
      final timerBody = _mesh(
        _geo.unitCube,
        timerShell,
        position: vm.Vector3(0, .875, -_layout.deskLead - .105),
        scale: vm.Vector3(.48, .15, .10),
      );
      final timerBodyCross = _mesh(
        _geo.unitCube,
        timerShell,
        position: vm.Vector3(0, .875, -_layout.deskLead - .105),
        scale: vm.Vector3(.48, .15, .10),
      );
      final timerRoundNodes = <Node>[];
      for (var k = 0; k < 4; k++) {
        timerRoundNodes.add(_mesh(
          _geo.explosion,
          timerShell,
          position: vm.Vector3.zero(),
          scale: vm.Vector3.zero(),
        ));
      }
      _timerBodyCrossNodes.add(timerBodyCross);
      _timerBodyRoundNodes.add(timerRoundNodes);
      final timerFaceMaterial = _unlit(const Color(0xFF020506));
      _timerFaceMaterials.add(timerFaceMaterial);
      final timerFace = _mesh(
        _geo.unitCube,
        timerFaceMaterial,
        name: 'station_timer_$i',
        position: timerLocal,
        scale: vm.Vector3(.42, .10, .012),
      )..castsShadows = false;

      final timerFrameTop = _mesh(
        _geo.unitCube,
        timerShell,
        position: vm.Vector3(0, timerLocal.y + .061, timerLocal.z + .006),
        scale: vm.Vector3(.48, .022, .018),
      );
      final timerFrameBottom = _mesh(
        _geo.unitCube,
        timerShell,
        position: vm.Vector3(0, timerLocal.y - .061, timerLocal.z + .006),
        scale: vm.Vector3(.48, .022, .018),
      );
      final timerFrameLeft = _mesh(
        _geo.unitCube,
        timerShell,
        position: vm.Vector3(-.229, timerLocal.y, timerLocal.z + .006),
        scale: vm.Vector3(.022, .105, .018),
      );
      final timerFrameRight = _mesh(
        _geo.unitCube,
        timerShell,
        position: vm.Vector3(.229, timerLocal.y, timerLocal.z + .006),
        scale: vm.Vector3(.022, .105, .018),
      );

      final digitMaterial = _unlit(color)
        ..doubleSided = true
        ..vertexColorWeight = 0;
      _timerDigitMaterials.add(digitMaterial);
      final stationDigits = <List<Node>>[];
      const digitXs = [.145, .048, -.055, -.151];
      for (var digitIndex = 0; digitIndex < 4; digitIndex++) {
        final segments = _buildSevenSegmentDigit(
          digitMaterial,
          center: vm.Vector3(
            digitXs[digitIndex],
            timerLocal.y,
            timerLocal.z + .020,
          ),
          scale: .63,
        );
        stationDigits.add(segments);
        root.addAll(segments);
      }
      final dot = _mesh(
        _geo.unitCube,
        digitMaterial,
        name: 'station_timer_dot_$i',
        position: vm.Vector3(-.006, timerLocal.y - .020, timerLocal.z + .022),
        scale: vm.Vector3(.010, .010, .007),
      )..castsShadows = false;
      _stationDigitSegments.add(stationDigits);
      _stationDecimalDots.add(dot);
      root.add(dot);
      _applySevenSegmentValue(i, _stationTimerValues[i]);

      final buttonLocal = vm.Vector3(0, .82, -_layout.deskLead + .10);
      final buttonBase = _mesh(
        _geo.unitCube,
        dark,
        position: vm.Vector3(0, .77, -_layout.deskLead + .10),
        scale: vm.Vector3(.32, .08, .32),
      );
      final buttonRing = _mesh(
        _geo.button,
        metal,
        position: vm.Vector3(0, .81, -_layout.deskLead + .10),
        scale: vm.Vector3(.25, .065, .25),
      )..castsShadows = false;
      final button = _mesh(
        _geo.button,
        accent,
        name: 'station_button_$i',
        position: buttonLocal,
        scale: vm.Vector3(.18, .08, .18),
      )..castsShadows = false;

      final chair = _buildChair(i, color);

      // Developer texture/decal surfaces.  Images selected from the computer
      // are baked into a texture and mapped onto these real 3D planes.
      final deskImageMaterial = _unlit(const Color(0x00FFFFFF))
        ..doubleSided = true
        ..vertexColorWeight = 0
        ..alphaMode = AlphaMode.blend;
      final deskImageDecal = _mesh(
        _geo.displayPlane,
        deskImageMaterial,
        name: 'station_desk_image_$i',
        position: vm.Vector3(0, .716, -_layout.deskLead),
        scale: vm.Vector3(.82, 1, .42),
      )..castsShadows = false;
      final chairImageMaterial = _unlit(const Color(0x00FFFFFF))
        ..doubleSided = true
        ..vertexColorWeight = 0
        ..alphaMode = AlphaMode.blend;
      final chairImageDecal = Node(name: 'station_chair_image_$i');
      chairImageDecal.addAll([
        _mesh(
          _geo.displayPlane,
          chairImageMaterial,
          name: 'station_chair_image_back_$i',
          position: vm.Vector3(0, .93, .158),
          scale: vm.Vector3(.54, 1, .76),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
        )..castsShadows = false,
        _mesh(
          _geo.displayPlane,
          chairImageMaterial,
          name: 'station_chair_image_seat_$i',
          position: vm.Vector3(0, .536, -.01),
          scale: vm.Vector3(.54, 1, .49),
        )..castsShadows = false,
      ]);
      final timerImageMaterial = _unlit(const Color(0x00FFFFFF))
        ..doubleSided = true
        ..vertexColorWeight = 0
        ..alphaMode = AlphaMode.blend;
      final timerImageDecal = _mesh(
        _geo.displayPlane,
        timerImageMaterial,
        name: 'station_timer_image_$i',
        position: vm.Vector3(0, timerLocal.y, timerLocal.z + .014),
        scale: vm.Vector3(.40, 1, .085),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
      )..castsShadows = false;
      _deskImageMaterials.add(deskImageMaterial);
      _chairImageMaterials.add(chairImageMaterial);
      _timerImageMaterials.add(timerImageMaterial);
      _deskImageDecals.add(deskImageDecal);
      _chairImageDecals.add(chairImageDecal);
      _timerImageDecals.add(timerImageDecal);

      final timerNodes = <Node>[
        timerBody, timerBodyCross, ...timerRoundNodes, timerFace, timerFrameTop, timerFrameBottom,
        timerFrameLeft, timerFrameRight, timerImageDecal, dot,
        ...stationDigits.expand((e) => e),
      ];
      _timerAssemblies.add(_TimerVisualAssembly.capture(timerLocal, timerNodes));

      root.addAll([
        chair,
        chairImageDecal,
        desk,
        deskImageDecal,
        pedestal,
        accentStrip,
        timerBody,
        timerBodyCross,
        ...timerRoundNodes,
        timerFace,
        timerImageDecal,
        timerFrameTop,
        timerFrameBottom,
        timerFrameLeft,
        timerFrameRight,
        buttonBase,
        buttonRing,
        button,
      ]);

      _buttonPositions.add(_stationLocalToWorld(i, buttonLocal));
      _stationDisplayPositions.add(_stationLocalToWorld(i, timerLocal));
      _buttons.add(button);
      _chairs.add(chair);
      _stations.add(root);
      scene.add(root);
    }
  }

  Node _buildChair(int index, Color color) {
    final root = Node(name: 'player_chair_$index');
    final frame = _pbr(const Color(0xFF4D4525), roughness: .74, metallic: .10);
    final cushion = _pbr(const Color(0xFF78672F), roughness: .96, metallic: .01);
    final accent = _pbr(const Color(0xFFA88C3E), roughness: .68, metallic: .12);
    _chairPrimaryMaterials.add(cushion);
    _chairFrameMaterials.add(frame);
    _chairAccentMaterials.add(accent);

    final seat = _mesh(_geo.unitCube, cushion, position: vm.Vector3(0, .47, 0), scale: vm.Vector3(.62, .12, .58));
    final seatCross = _mesh(_geo.unitCube, cushion, position: vm.Vector3(0, .47, 0), scale: vm.Vector3(.62, .12, .58));
    final back = _mesh(_geo.unitCube, cushion, position: vm.Vector3(0, .93, .23), scale: vm.Vector3(.62, .88, .13));
    final backCross = _mesh(_geo.unitCube, cushion, position: vm.Vector3(0, .93, .23), scale: vm.Vector3(.62, .88, .13));
    final seatRound = <Node>[];
    final backRound = <Node>[];
    for (var k = 0; k < 4; k++) {
      seatRound.add(_mesh(_geo.explosion, cushion, position: vm.Vector3.zero(), scale: vm.Vector3.zero()));
      backRound.add(_mesh(_geo.explosion, cushion, position: vm.Vector3.zero(), scale: vm.Vector3.zero()));
    }
    _chairSeatCrossNodes.add(seatCross);
    _chairBackCrossNodes.add(backCross);
    _chairSeatRoundNodes.add(seatRound);
    _chairBackRoundNodes.add(backRound);

    root.addAll([
      seat,
      seatCross,
      ...seatRound,
      back,
      backCross,
      ...backRound,
      _mesh(_geo.unitCube, frame, position: vm.Vector3(0, .24, .10), scale: vm.Vector3(.12, .46, .12)),
      _mesh(_geo.unitCube, frame, position: vm.Vector3(0, .08, .10), scale: vm.Vector3(.58, .10, .58)),
      _mesh(_geo.unitCube, accent, position: vm.Vector3(0, 1.20, .155), scale: vm.Vector3(.42, .035, .02))
        ..castsShadows = false,
    ]);
    return root;
  }


  Future<void> _applyInitialSurfaceDeveloperSettings() async {
    for (var i = 0; i < 4; i++) {
      _applyStationSurfaceTuning(i);
      await _rebuildStationSurfaceTexture(i, 'chair');
      await _rebuildStationSurfaceTexture(i, 'desk');
      await _rebuildStationSurfaceTexture(i, 'timer');
    }
  }

  void _applyProjectileDeveloperTuning() {
    if (!ready && !_dev.projectile.initialized) {
      _dev.projectile.initialized = true;
    }
    final p = _dev.projectile;
    if (!_isNodeReady(_projectile)) return;
    _projectile.scale = vm.Vector3(p.scaleX, p.scaleY, p.scaleZ);
    _projectileModel.rotation = vm.Quaternion.euler(
      vm.radians(p.pitchDegrees),
      vm.radians(p.yawDegrees),
      vm.radians(p.rollDegrees),
    );
    _projectileGlowInner.scale = vm.Vector3.all(p.glowInnerSize);
    _projectileGlowOuter.scale = vm.Vector3.all(p.glowOuterSize);
    _projectileGlowMaterial.baseColorFactor = _vectorColor(p.glowColor, alpha: p.glowOpacity);
    _projectileTrailMaterial.baseColorFactor = _vectorColor(p.trailColor, alpha: p.trailOpacity);
    for (var i = 0; i < _projectileTrail.length; i++) {
      final k = 1.0 - i / math.max(1, _projectileTrail.length - 1);
      _projectileTrail[i].scale = vm.Vector3.all(p.trailSize * (.45 + .55 * k));
    }
    _updateProjectileDeveloperMuzzlePreview();
  }

  void _updateProjectileDeveloperMuzzlePreview() {
    if (!_projectileBuilt || !layoutDeveloperMode || (_tankDeveloperPathRunning && _shotTriggered)) return;
    final p = _dev.projectile;
    if (!p.previewAtMuzzle) {
      _projectile.visible = false;
      for (final n in _projectileTrail) n.visible = false;
      return;
    }
    final m = _tankMuzzle.globalTransform;
    final st = m.storage;
    final xAxis = vm.Vector3(st[0], st[1], st[2]);
    final yAxis = vm.Vector3(st[4], st[5], st[6]);
    final zAxis = vm.Vector3(st[8], st[9], st[10]);
    if (xAxis.length2 > .000001) xAxis.normalize();
    if (yAxis.length2 > .000001) yAxis.normalize();
    if (zAxis.length2 > .000001) zAxis.normalize();
    final muzzleWorld = m.getTranslation();
    _projectile
      ..visible = true
      ..position = muzzleWorld +
          xAxis * p.previewOffsetX +
          yAxis * p.previewOffsetY +
          zAxis * p.previewOffsetZ;
    for (final n in _projectileTrail) n.visible = false;
  }

  bool _isNodeReady(Node node) => true;

  void _updateProjectileTrail(vm.Vector3 from, vm.Vector3 to, double shotT) {
    final p = _dev.projectile;
    if (!_projectile.visible || !p.trailEnabled) {
      for (final n in _projectileTrail) n.visible = false;
      return;
    }
    final direction = to - from;
    for (var i = 0; i < _projectileTrail.length; i++) {
      final lag = (i + 1) * p.trailSpacing;
      final t = (shotT - lag).clamp(0.0, 1.0).toDouble();
      _projectileTrail[i]
        ..visible = shotT > lag * .45
        ..position = from + direction * _easeOutCubic(t);
    }
  }

  Future<dui.Image> _decodeDeveloperImage(Uint8List bytes) async {
    final codec = await dui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<Texture2D> _makeDeveloperPatternTexture(
    Uint8List bytes,
    _SurfaceImageTuning tuning,
  ) async {
    final src = await _decodeDeveloperImage(bytes);
    const size = 768;
    final recorder = dui.PictureRecorder();
    final canvas = dui.Canvas(recorder);
    canvas.drawRect(
      dui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      dui.Paint()..color = const Color(0x00000000),
    );

    void drawOne(dui.Rect target) {
      final save = canvas.getSaveCount();
      canvas.save();
      final center = target.center;
      canvas.translate(center.dx + tuning.offsetX * size, center.dy + tuning.offsetY * size);
      canvas.rotate(vm.radians(tuning.rotationDegrees));
      canvas.scale(tuning.imageScale, tuning.imageScale);
      final dst = dui.Rect.fromCenter(center: Offset.zero, width: target.width, height: target.height);
      final srcRect = dui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
      if (tuning.mode == 1 || tuning.mode == 2) {
        final srcAspect = src.width / src.height;
        final dstAspect = dst.width / dst.height;
        dui.Rect crop = srcRect;
        if (tuning.mode == 2) { // fill/crop
          if (srcAspect > dstAspect) {
            final w = src.height * dstAspect;
            crop = dui.Rect.fromLTWH((src.width - w) / 2, 0, w, src.height.toDouble());
          } else {
            final h = src.width / dstAspect;
            crop = dui.Rect.fromLTWH(0, (src.height - h) / 2, src.width.toDouble(), h);
          }
        } else { // fit
          double w = dst.width, h = dst.height;
          if (srcAspect > dstAspect) h = w / srcAspect; else w = h * srcAspect;
          final fitDst = dui.Rect.fromCenter(center: Offset.zero, width: w, height: h);
          canvas.drawImageRect(src, srcRect, fitDst, dui.Paint());
          canvas.restoreToCount(save);
          return;
        }
        canvas.drawImageRect(src, crop, dst, dui.Paint());
      } else {
        canvas.drawImageRect(src, srcRect, dst, dui.Paint());
      }
      canvas.restoreToCount(save);
    }

    if (tuning.mode == 3) {
      final rx = math.max(1, tuning.repeatX.round());
      final ry = math.max(1, tuning.repeatY.round());
      final tw = size / rx;
      final th = size / ry;
      for (var y = 0; y < ry; y++) {
        for (var x = 0; x < rx; x++) {
          drawOne(dui.Rect.fromLTWH(x * tw, y * th, tw, th));
        }
      }
    } else {
      drawOne(dui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    }

    final image = await recorder.endRecording().toImage(size, size);
    src.dispose();
    try {
      return await Texture2D.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  Future<void> _pickStationSurfaceImage(int station, String kind) async {
    final picked = await dev_picker.pickDeveloperImage();
    if (picked == null) return;
    final bytes = picked['bytes'];
    final path = picked['path'];
    if (bytes is! Uint8List) return;
    final tuning = _dev.surfaces[station];
    final imageTuning = switch (kind) {
      'chair' => tuning.chairImage,
      'desk' => tuning.deskImage,
      _ => tuning.timerImage,
    };
    imageTuning
      ..path = path?.toString() ?? ''
      ..bytes = bytes
      ..enabled = true;
    await _rebuildStationSurfaceTexture(station, kind);
  }

  Future<void> _rebuildStationSurfaceTexture(int station, String kind) async {
    if (station < 0 || station >= 4) return;
    final tuning = _dev.surfaces[station];
    final imageTuning = switch (kind) {
      'chair' => tuning.chairImage,
      'desk' => tuning.deskImage,
      _ => tuning.timerImage,
    };

    // The old implementation used flat decal planes. That made the image look
    // pasted only on the seat/top. We now assign the generated texture directly
    // to the REAL PBR materials of every 3D part. Lighting/roughness remain
    // active, so side faces naturally become darker and the object keeps depth.
    if (!imageTuning.enabled || imageTuning.bytes == null) {
      if (kind == 'chair') {
        _chairPrimaryMaterials[station].baseColorTexture = null;
        _chairFrameMaterials[station].baseColorTexture = null;
        _chairAccentMaterials[station].baseColorTexture = null;
      } else if (kind == 'desk') {
        _deskPrimaryMaterials[station].baseColorTexture = null;
        _deskSecondaryMaterials[station].baseColorTexture = null;
      } else {
        _timerShellMaterials[station].baseColorTexture = null;
      }
      _deskImageDecals[station].visible = false;
      _chairImageDecals[station].visible = false;
      _timerImageDecals[station].visible = false;
      _applyStationSurfaceTuning(station);
      return;
    }

    final tex = await _makeDeveloperPatternTexture(imageTuning.bytes!, imageTuning);
    if (kind == 'chair') {
      for (final m in <PhysicallyBasedMaterial>[
        _chairPrimaryMaterials[station],
        _chairFrameMaterials[station],
        _chairAccentMaterials[station],
      ]) {
        m
          ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
          ..baseColorTexture = tex;
      }
    } else if (kind == 'desk') {
      for (final m in <PhysicallyBasedMaterial>[
        _deskPrimaryMaterials[station],
        _deskSecondaryMaterials[station],
      ]) {
        m
          ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
          ..baseColorTexture = tex;
      }
    } else {
      // Timer image belongs to the casing ONLY. The black display face and the
      // seven-segment digits deliberately remain untouched and readable.
      _timerShellMaterials[station]
        ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF))
        ..baseColorTexture = tex;
    }

    // Flat overlay planes are permanently disabled; all texture is now on the
    // actual 3D geometry.
    _deskImageDecals[station].visible = false;
    _chairImageDecals[station].visible = false;
    _timerImageDecals[station].visible = false;
  }

  void _applyStationRoundedCorners(int station) {
    if (station < 0 || station >= 4) return;
    final t = _dev.surfaces[station];
    final cr = t.chairCornerRadius.clamp(0.0, .26).toDouble();
    if (station < _chairSeatCrossNodes.length) {
      final seatA = _chairs[station].children[0];
      final seatB = _chairSeatCrossNodes[station];
      seatA.scale = vm.Vector3(math.max(.02, .62 - cr * 2), .12, .58);
      seatB.scale = vm.Vector3(.62, .12, math.max(.02, .58 - cr * 2));
      final corners = _chairSeatRoundNodes[station];
      final xs = [-1.0, 1.0];
      final zs = [-1.0, 1.0];
      var k = 0;
      for (final sx in xs) {
        for (final sz in zs) {
          corners[k]
            ..position = vm.Vector3(sx * (.31 - cr), .47, sz * (.29 - cr))
            ..scale = vm.Vector3(cr * 2, .12, cr * 2);
          k++;
        }
      }
      final br = cr.clamp(0.0, .26).toDouble();
      final backA = _chairs[station].children[6];
      final backB = _chairBackCrossNodes[station];
      backA.scale = vm.Vector3(math.max(.02, .62 - br * 2), .88, .13);
      backB.scale = vm.Vector3(.62, math.max(.02, .88 - br * 2), .13);
      final bc = _chairBackRoundNodes[station];
      var j = 0;
      for (final sx in xs) {
        for (final sy in xs) {
          bc[j]
            ..position = vm.Vector3(sx * (.31 - br), .93 + sy * (.44 - br), .23)
            ..scale = vm.Vector3(br * 2, br * 2, .13);
          j++;
        }
      }
    }
    if (station < _timerBodyCrossNodes.length) {
      final tr = t.timerCornerRadius.clamp(0.0, .07).toDouble();
      final body = _timerAssemblies[station].nodes.first;
      final cross = _timerBodyCrossNodes[station];
      body.scale = vm.Vector3(math.max(.02, .48 - tr * 2), .15, .10);
      cross.scale = vm.Vector3(.48, math.max(.02, .15 - tr * 2), .10);
      final corners = _timerBodyRoundNodes[station];
      var k = 0;
      for (final sx in [-1.0, 1.0]) {
        for (final sy in [-1.0, 1.0]) {
          corners[k]
            ..position = vm.Vector3(sx * (.24 - tr), .875 + sy * (.075 - tr), -_layout.deskLead - .105)
            ..scale = vm.Vector3(tr * 2, tr * 2, .10);
          k++;
        }
      }
    }
  }

  void _applyStationSurfaceTuning(int station) {
    if (station < 0 || station >= 4 || station >= _stations.length) return;
    final t = _dev.surfaces[station];
    _applyStationRoundedCorners(station);
    final chairTextured = t.chairImage.enabled && t.chairImage.bytes != null;
    final deskTextured = t.deskImage.enabled && t.deskImage.bytes != null;
    final timerTextured = t.timerImage.enabled && t.timerImage.bytes != null;

    _chairPrimaryMaterials[station].baseColorFactor =
        _vectorColor(chairTextured ? const Color(0xFFFFFFFF) : t.chairColor);
    _chairFrameMaterials[station].baseColorFactor =
        _vectorColor(chairTextured ? const Color(0xFFFFFFFF) : t.chairFrameColor);
    _chairAccentMaterials[station].baseColorFactor =
        _vectorColor(chairTextured ? const Color(0xFFFFFFFF) : t.chairFrameColor);

    _deskPrimaryMaterials[station].baseColorFactor =
        _vectorColor(deskTextured ? const Color(0xFFFFFFFF) : t.deskColor);
    _deskSecondaryMaterials[station].baseColorFactor = _vectorColor(
      deskTextured ? const Color(0xFFFFFFFF) : _shadeColor(t.deskColor, .72),
    );

    _timerShellMaterials[station].baseColorFactor = _vectorColor(
      timerTextured ? const Color(0xFFFFFFFF) : _shadeColor(t.deskColor, .82),
    );
    _timerFaceMaterials[station].baseColorFactor = _vectorColor(t.timerFaceColor);
    _timerDigitMaterials[station].baseColorFactor = _vectorColor(t.timerDigitColor);

    _deskImageDecals[station].visible = false;
    _chairImageDecals[station].visible = false;
    _timerImageDecals[station].visible = false;

    final timer = _timerAssemblies[station];
    final q = vm.Quaternion.euler(
      vm.radians(t.timerPitchDegrees),
      vm.radians(t.timerYawDegrees),
      vm.radians(t.timerRollDegrees),
    );
    final delta = vm.Vector3(t.timerX, t.timerY, t.timerZ);
    timer.apply(delta, q, t.timerScaleX, t.timerScaleY);
  }

  Color _vividPlayerColor(Color c) {
    final hsl = ui.HSLColor.fromColor(c);
    return hsl
        .withSaturation(math.max(.82, hsl.saturation).toDouble())
        .withLightness(hsl.lightness.clamp(.48, .62).toDouble())
        .toColor();
  }

  Color _shadeColor(Color c, double factor) {
    final argb = c.toARGB32();
    final a = (argb >> 24) & 255;
    final r = (argb >> 16) & 255;
    final g = (argb >> 8) & 255;
    final b = argb & 255;
    return Color.fromARGB(
      a,
      (r * factor).round().clamp(0, 255).toInt(),
      (g * factor).round().clamp(0, 255).toInt(),
      (b * factor).round().clamp(0, 255).toInt(),
    );
  }

  void _applyBigScreenDeveloperTuning() {
    if (!_dev.bigScreen.initialized) _dev.bigScreen.initialized = true;
    final t = _dev.bigScreen;
    _bigScreenFrameMaterial.baseColorFactor = _vectorColor(t.frameColor);
    _bigScreenBezelMaterial.baseColorFactor = _vectorColor(t.bezelColor);
    if (!_dev.bigScreen.hasBasePosition) {
      t
        ..baseX = _bigScreenBasePosition.x
        ..baseY = _bigScreenBasePosition.y
        ..baseZ = _bigScreenBasePosition.z
        ..hasBasePosition = true;
    }
    _bigScreenMount.position = vm.Vector3(t.baseX + t.x, t.baseY + t.y, t.baseZ + t.z);
    _bigScreenMount.rotation = _bigScreenBaseRotation * vm.Quaternion.euler(
      vm.radians(t.pitchDegrees), vm.radians(t.yawDegrees), vm.radians(t.rollDegrees));

    final baseW = _layout.wallWidth * .66;
    final baseH = _layout.wallHeight * .49;
    final width = math.max(.2, baseW + t.left + t.right).toDouble();
    final height = math.max(.2, baseH + t.top + t.bottom).toDouble();
    final cx = (t.right - t.left) * .5;
    final cy = (t.top - t.bottom) * .5;
    _bigScreen
      ..position = vm.Vector3(cx, cy, .014)
      ..scale = vm.Vector3(-width, 1, height);
    final outerW = width + _layout.wallWidth * .10;
    final outerH = height + _layout.wallHeight * .13;
    final rr = t.frameCornerRadius.clamp(0.0, math.min(outerW, outerH) * .48).toDouble();
    _bigScreenFrame
      ..position = vm.Vector3(cx, cy, -.07)
      ..scale = vm.Vector3(math.max(.02, outerW - rr * 2), outerH, .14);
    _bigScreenFrameCross
      ..position = vm.Vector3(cx, cy, -.07)
      ..scale = vm.Vector3(outerW, math.max(.02, outerH - rr * 2), .14);
    var rk = 0;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        _bigScreenFrameRoundNodes[rk]
          ..position = vm.Vector3(cx + sx * (outerW * .5 - rr), cy + sy * (outerH * .5 - rr), -.07)
          ..scale = vm.Vector3(rr * 2, rr * 2, .14);
        rk++;
      }
    }
    _bigScreenBezel
      ..position = vm.Vector3(cx, cy, -.025)
      ..scale = vm.Vector3(width + _layout.wallWidth * .05, height + _layout.wallHeight * .07, .07);
    _lastBigScreenSignature = '';
    _refreshBigScreenDeveloperTexture();
  }

  String _visualDeveloperSettingsText() {
    final b = StringBuffer('GUESS_TIME_VISUALS\n');
    final p = _dev.projectile;
    b.writeln('FIREBALL preview=${p.previewAtMuzzle},${p.previewOffsetX.toStringAsFixed(3)},${p.previewOffsetY.toStringAsFixed(3)},${p.previewOffsetZ.toStringAsFixed(3)} scale=${p.scaleX.toStringAsFixed(3)},${p.scaleY.toStringAsFixed(3)},${p.scaleZ.toStringAsFixed(3)} rot=${p.pitchDegrees.toStringAsFixed(2)},${p.yawDegrees.toStringAsFixed(2)},${p.rollDegrees.toStringAsFixed(2)} glow=${p.glowInnerSize.toStringAsFixed(3)},${p.glowOuterSize.toStringAsFixed(3)},${p.glowOpacity.toStringAsFixed(2)} trail=${p.trailEnabled},${p.trailSize.toStringAsFixed(3)},${p.trailSpacing.toStringAsFixed(3)},${p.trailOpacity.toStringAsFixed(2)} spin=${p.spinX.toStringAsFixed(1)},${p.spinY.toStringAsFixed(1)},${p.spinZ.toStringAsFixed(1)} impact=${p.impactScale.toStringAsFixed(2)}');
    for (var i=0;i<4;i++) {
      final v=_dev.surfaces[i];
      b.writeln('STATION_${i+1} chairColor=${v.chairColor.toARGB32().toRadixString(16)} deskColor=${v.deskColor.toARGB32().toRadixString(16)} timer=${v.timerX.toStringAsFixed(3)},${v.timerY.toStringAsFixed(3)},${v.timerZ.toStringAsFixed(3)} rot=${v.timerPitchDegrees.toStringAsFixed(2)},${v.timerYawDegrees.toStringAsFixed(2)},${v.timerRollDegrees.toStringAsFixed(2)} scale=${v.timerScaleX.toStringAsFixed(3)},${v.timerScaleY.toStringAsFixed(3)} radius=${v.chairCornerRadius.toStringAsFixed(3)},${v.timerCornerRadius.toStringAsFixed(3)} chairImage=${v.chairImage.describe()} deskImage=${v.deskImage.describe()} timerImage=${v.timerImage.describe()}');
    }
    final s=_dev.bigScreen;
    b.writeln('BIG_SCREEN colors=${s.frameColor.toARGB32().toRadixString(16)},${s.bezelColor.toARGB32().toRadixString(16)},${s.screenColor.toARGB32().toRadixString(16)} pos=${s.x.toStringAsFixed(3)},${s.y.toStringAsFixed(3)},${s.z.toStringAsFixed(3)} rot=${s.pitchDegrees.toStringAsFixed(2)},${s.yawDegrees.toStringAsFixed(2)},${s.rollDegrees.toStringAsFixed(2)} edges=${s.left.toStringAsFixed(3)},${s.right.toStringAsFixed(3)},${s.top.toStringAsFixed(3)},${s.bottom.toStringAsFixed(3)} globalText=${s.globalTextScale.toStringAsFixed(2)},${s.globalTextX.toStringAsFixed(1)},${s.globalTextY.toStringAsFixed(1)} text=${s.headerFontSize.toStringAsFixed(1)},${s.rowFontSize.toStringAsFixed(1)},${s.headerX.toStringAsFixed(1)},${s.headerY.toStringAsFixed(1)},${s.rowsX.toStringAsFixed(1)},${s.rowsStartY.toStringAsFixed(1)},${s.rowGap.toStringAsFixed(1)},${s.rowWidth.toStringAsFixed(1)},${s.rowHeight.toStringAsFixed(1)},${s.rowTextYOffset.toStringAsFixed(1)} radius=${s.frameCornerRadius.toStringAsFixed(3)}');
    b.writeln(_environmentDeveloperSettingsText());
    return b.toString();
  }

  void _applyAvatar(Node model, KillerKilledAvatar avatar) {
    final visible = avatar.visibleNodeNames;
    for (final name in KillerKilledAvatar.customizableNodeNames) {
      final node = model.getChildByName(name);
      if (node != null) node.visible = visible.contains(name);
    }
    final body = model.getChildByName('Body_010');
    if (body != null) body.visible = true;
  }

  void _buildPlayer(int index, KillerKilledAvatar avatar) {
    final root = Node(name: 'guess_player_$index')
      ..position = vm.Vector3(0, .02, 0)
      // Creative Character faces +Z in its authored pose; station forward is -Z.
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    final bodyRoot = Node(name: 'guess_body_$index')..position = vm.Vector3(0, .08, 0);
    root.add(bodyRoot);

    final model = _characterTemplate.clone(recursive: true)
      ..name = 'guess_character_$index'
      ..scale = vm.Vector3.all(.96);
    bodyRoot.add(model);
    _applyAvatar(model, avatar);

    Node bone(String name) {
      final node = model.getChildByName(name);
      if (node == null) throw StateError('Missing character bone: $name');
      return node;
    }

    final bones = <String, Node>{
      'hips': bone('Hips'),
      'spine': bone('Spine'),
      'spine1': bone('Spine1'),
      'neck': bone('Neck'),
      'head': bone('Head'),
      'leftShoulder': bone('LeftShoulder'),
      'rightShoulder': bone('RightShoulder'),
      'leftArm': bone('LeftArm'),
      'rightArm': bone('RightArm'),
      'leftForeArm': bone('LeftForeArm'),
      'rightForeArm': bone('RightForeArm'),
      'leftHand': bone('LeftHand'),
      'rightHand': bone('RightHand'),
      'leftUpLeg': bone('LeftUpLeg'),
      'rightUpLeg': bone('RightUpLeg'),
      'leftLeg': bone('LeftLeg'),
      'rightLeg': bone('RightLeg'),
      'leftFoot': bone('LeftFoot'),
      'rightFoot': bone('RightFoot'),
    };
    final base = <String, vm.Quaternion>{
      for (final entry in bones.entries) entry.key: vm.Quaternion.copy(entry.value.rotation),
    };

    final visual = _PlayerVisual(
      index: index,
      root: root,
      bodyRoot: bodyRoot,
      model: model,
      avatar: avatar,
      bones: bones,
      base: base,
    );

    // FIXED STARTING BODY TRANSFORM FOR ALL FOUR PLAYERS.
    // These are the exact developer values approved by the user.  Apply them
    // again at model creation (not only when developer tuning is initialized)
    // so every spawned player always starts from the same root/body placement.
    final pose = _dev.poses[index.clamp(0, _dev.poses.length - 1)];
    pose
      ..x = 0.0000
      ..y = 0.0200
      ..z = 0.0000
      ..pitchDegrees = 0.000
      ..yawDegrees = 180.000
      ..rollDegrees = -0.600
      ..scale = 0.960
      ..bodyX = 0.0000
      ..bodyY = -0.1940
      ..bodyZ = -0.0500;

    _players.add(visual);
    _posePlayer(visual, press: 0);
    for (final mesh in model.meshNodes) {
      mesh
        ..castsShadows = true
        ..highlightColor = null;
    }
    _stations[index].add(root);
  }

  vm.Quaternion _delta(vm.Quaternion base, {double x = 0, double y = 0, double z = 0}) {
    var result = vm.Quaternion.copy(base);
    if (x != 0) result = result * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), x);
    if (y != 0) result = result * vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), y);
    if (z != 0) result = result * vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), z);
    return result;
  }


  double _wrapRadians(double value) {
    var v = value;
    while (v > math.pi) v -= math.pi * 2;
    while (v < -math.pi) v += math.pi * 2;
    return v;
  }

  vm.Vector2 _gazeTowardWorld(int index, vm.Vector3 target) {
    final origin = _stationLocalToWorld(index, vm.Vector3(0, 1.10, -.03));
    final delta = target - origin;
    final flat = math.sqrt(delta.x * delta.x + delta.z * delta.z);
    if (flat < .0001) return vm.Vector2.zero();
    final worldYaw = math.atan2(-delta.x, -delta.z);
    final relativeYaw = _wrapRadians(worldYaw - _stationYaw(index));
    final pitch = math.atan2(delta.y, flat);
    return vm.Vector2(
      relativeYaw.clamp(-.82, .82).toDouble(),
      pitch.clamp(-.55, .48).toDouble(),
    );
  }

  vm.Vector2 _smartGazeForPlayer(int index, double seconds, double press) {
    if (index == _viewerIndex && !_developerFreeCameraEnabled) {
      return vm.Vector2(
        _lookYaw.clamp(-.78, .78).toDouble(),
        _lookPitch.clamp(-.52, .52).toDouble(),
      );
    }

    if (press > .02 && index < _buttonPositions.length) {
      return _gazeTowardWorld(index, _buttonPositions[index]);
    }

    final screenTarget = _authoredRoomPointToWorld(
      _layout.screensCenter + vm.Vector3(0, _layout.wallHeight * .10, 0),
    );
    final screenGaze = _gazeTowardWorld(index, screenTarget);
    final timerGaze = index < _stationDisplayPositions.length
        ? _gazeTowardWorld(index, _stationDisplayPositions[index])
        : vm.Vector2(0, -.28);
    final buttonGaze = index < _buttonPositions.length
        ? _gazeTowardWorld(index, _buttonPositions[index])
        : vm.Vector2(0, -.38);
    final otherIndex = index < 3 ? index + 1 : index - 1;
    final otherHead = _stationLocalToWorld(otherIndex, vm.Vector3(0, 1.08, 0));
    final playerGaze = _gazeTowardWorld(index, otherHead);

    switch (_behaviorPhase) {
      case GuessTimePhase.reveal:
      case GuessTimePhase.countdown:
        return screenGaze;
      case GuessTimePhase.timing:
        if (index < _behaviorLocked.length && _behaviorLocked[index]) {
          final lockedCycle = ((_behaviorElapsedMs ~/ 1700) + index) % 2;
          return lockedCycle == 0 ? playerGaze : screenGaze;
        }
        final cycle = ((_behaviorElapsedMs ~/ 1150) + index) % 4;
        return switch (cycle) {
          0 => screenGaze,
          1 => timerGaze,
          2 => playerGaze,
          _ => buttonGaze,
        };
      case GuessTimePhase.roundResults:
      case GuessTimePhase.finalResults:
      case GuessTimePhase.finished:
        return screenGaze;
      case GuessTimePhase.elimination:
        return playerGaze;
      case GuessTimePhase.waiting:
        final idle = math.sin(seconds * .45 + index * .8) * .12;
        return vm.Vector2(idle, math.sin(seconds * .31 + index) * .035);
    }
  }

  void _posePlayer(_PlayerVisual v, {required double press}) {
    final pose = _dev.poses[v.index.clamp(0, _dev.poses.length - 1)];
    final seconds = DateTime.now().microsecondsSinceEpoch / 1000000.0;
    final phase = seconds * 1.55 + v.index * .83;

    // Barely-visible breathing: a few millimetres of body lift plus sub-degree
    // chest motion. It keeps the character alive without looking animated.
    final breath = math.sin(phase);
    final breathLift = breath * .0035;
    final breathChest = breath * .75 * math.pi / 180.0;

    v.root.position = vm.Vector3(pose.x, pose.y, pose.z);
    final qPitch = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      pose.pitchDegrees * math.pi / 180.0,
    );
    final qYaw = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      pose.yawDegrees * math.pi / 180.0,
    );
    final qRoll = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      pose.rollDegrees * math.pi / 180.0,
    );
    v.root.rotation =
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi) *
            qYaw *
            qPitch *
            qRoll;
    v.bodyRoot.position =
        vm.Vector3(pose.bodyX, pose.bodyY + breathLift, pose.bodyZ);
    v.model.scale = vm.Vector3.all(pose.scale);

    vm.Quaternion applyBone(String name, _EulerTuning t) {
      return _delta(
        v.base[name]!,
        x: t.xDegrees * math.pi / 180.0,
        y: t.yDegrees * math.pi / 180.0,
        z: t.zDegrees * math.pi / 180.0,
      );
    }

    v.bones['hips']!.rotation = applyBone('hips', pose.hips);
    v.bones['spine']!.rotation = _delta(
      applyBone('spine', pose.spine),
      x: breathChest * .42,
    );
    v.bones['spine1']!.rotation = _delta(
      applyBone('spine1', pose.spine1),
      x: breathChest,
    );

    // Every character now has a visible gaze. The local head follows the
    // camera; other players smoothly choose meaningful targets: wall screens,
    // their stopwatch, their button, or another player. Pressing always pulls
    // the gaze down to the physical button.
    final gazeTarget = _smartGazeForPlayer(v.index, seconds, press);
    final gazeEase = v.index == _viewerIndex ? .30 : .10;
    v.gazeYaw += (gazeTarget.x - v.gazeYaw) * gazeEase;
    v.gazePitch += (gazeTarget.y - v.gazePitch) * gazeEase;
    final lookYaw = v.gazeYaw;
    final lookPitch = v.gazePitch;

    v.bones['neck']!.rotation = _delta(
      applyBone('neck', pose.neck),
      x: -lookPitch * .30,
      y: lookYaw * .28,
    );
    v.bones['head']!.rotation = _delta(
      applyBone('head', pose.head),
      x: -lookPitch * .70,
      y: lookYaw * .72,
    );

    v.bones['leftShoulder']!.rotation =
        applyBone('leftShoulder', pose.leftShoulder);
    v.bones['leftArm']!.rotation = applyBone('leftArm', pose.leftArm);
    v.bones['leftForeArm']!.rotation =
        applyBone('leftForeArm', pose.leftForeArm);
    v.bones['leftHand']!.rotation = applyBone('leftHand', pose.leftHand);

    // In this imported Creative Character rig the authored RIGHT arm is the
    // visually-left arm. Give that hand a very small idle motion independent
    // from breathing so the pose never looks frozen.
    final handIdle = math.sin(seconds * 1.15 + v.index * .67);
    final handIdle2 = math.sin(seconds * .78 + v.index * 1.31);
    v.bones['rightShoulder']!.rotation = _delta(
      applyBone('rightShoulder', pose.rightShoulder),
      z: handIdle * .55 * math.pi / 180.0,
    );
    v.bones['rightArm']!.rotation = _delta(
      applyBone('rightArm', pose.rightArm),
      x: handIdle2 * .70 * math.pi / 180.0,
      z: handIdle * .45 * math.pi / 180.0,
    );
    v.bones['rightForeArm']!.rotation = _delta(
      applyBone('rightForeArm', pose.rightForeArm),
      x: handIdle * 1.10 * math.pi / 180.0,
      y: handIdle2 * .50 * math.pi / 180.0,
    );
    v.bones['rightHand']!.rotation = _delta(
      applyBone('rightHand', pose.rightHand),
      x: handIdle2 * .90 * math.pi / 180.0,
      z: handIdle * .70 * math.pi / 180.0,
    );

    v.bones['leftUpLeg']!.rotation = applyBone('leftUpLeg', pose.leftUpLeg);
    v.bones['leftLeg']!.rotation = applyBone('leftLeg', pose.leftLeg);
    v.bones['leftFoot']!.rotation = applyBone('leftFoot', pose.leftFoot);
    v.bones['rightUpLeg']!.rotation =
        applyBone('rightUpLeg', pose.rightUpLeg);
    v.bones['rightLeg']!.rotation = applyBone('rightLeg', pose.rightLeg);
    v.bones['rightFoot']!.rotation = applyBone('rightFoot', pose.rightFoot);

    if (press > 0) {
      // The imported left-side bones drive the visually-right pressing arm.
      v.bones['leftShoulder']!.rotation = _delta(
        v.bones['leftShoulder']!.rotation,
        z: -.30 * press,
      );
      v.bones['leftArm']!.rotation = _delta(
        v.bones['leftArm']!.rotation,
        x: -.55 * press,
      );
      v.bones['leftForeArm']!.rotation = _delta(
        v.bones['leftForeArm']!.rotation,
        x: -.46 * press,
      );
      v.bones['leftHand']!.rotation = _delta(
        v.bones['leftHand']!.rotation,
        x: .16 * press,
      );
    }
  }

  void animatePress(int index) {
    if (index < 0 || index >= _players.length) return;
    final visual = _players[index];
    visual.pressStartedAt = DateTime.now();
  }

  void setScreenOwners(List<int> owners, {List<num>? playerTimes}) {
    for (var i = 0; i < _screenOwners.length; i++) {
      _screenOwners[i] = (i < owners.length ? owners[i] : i % 4)
          .clamp(0, 3)
          .toInt();
    }
    _applyOriginalScreenMaterials();
    if (playerTimes != null) setPlayerTimes(playerTimes);
  }

  void setBigScreenState(GuessTimePhase phase) {}

  Future<void> _buildTank() async {
    final glow = _unlit(const Color(0xFFFF3A2E));

    final imported = await Node.fromGlbAsset('assets/models/tank_t-34.glb');
    imported.name = 't34_optimized_model';
    for (final mesh in imported.meshNodes) {
      mesh
        ..castsShadows = true
        ..highlightColor = null;
    }

    _tank = Node(name: 'execution_tank')..add(imported);
    final turret = imported.getChildByName('T34_TURRET_PIVOT');
    final turretMesh = imported.getChildByName('T34_TURRET_MESH');
    final barrel = imported.getChildByName('T34_BARREL_PIVOT');
    final barrelMesh = imported.getChildByName('T34_BARREL_MESH');
    if (turret == null || turretMesh == null || barrel == null || barrelMesh == null) {
      throw StateError(
        'tank_t-34.glb must contain T34_TURRET_PIVOT/T34_TURRET_MESH and '
        'T34_BARREL_PIVOT/T34_BARREL_MESH. Use the optimized Mundas tank asset.',
      );
    }
    _tankTurret = turret;
    _tankTurretMesh = turretMesh;
    _tankBarrel = barrel;
    _tankBarrelMesh = barrelMesh;

    // Correct the logical pivots without changing the visible model at all.
    // Turret geometry remains at its authored coordinates, but yaw now rotates
    // around the actual turret ring. The gun keeps its breech pivot.
    _tankTurret.position = vm.Vector3.copy(_t34TurretPivotBase);
    _tankTurretMesh.position = vm.Vector3(-_t34TurretPivotBase.x, -_t34TurretPivotBase.y, -_t34TurretPivotBase.z);
    _tankBarrel.position = _t34BarrelPivotBase - _t34TurretPivotBase;
    _tankBarrelMesh.position = vm.Vector3(-_t34BarrelPivotBase.x, -_t34BarrelPivotBase.y, -_t34BarrelPivotBase.z);

    // Real muzzle marker. The local offset is measured from the gun breech.
    _tankMuzzle = Node(name: 'T34_MUZZLE')
      ..position = vm.Vector3(.043, 121.48, 0);
    _tankBarrel.add(_tankMuzzle);

    // Developer-only pivot markers: cyan=turret ring, magenta=gun breech,
    // orange=muzzle. They are children of the actual nodes, so they always
    // reveal the true rotation centers even after offsets/scales are edited.
    _tankTurretPivotMarker = _mesh(
      _geo.explosion,
      _unlit(const Color(0xFF39F2FF)),
      name: 'tank_turret_pivot_marker',
      scale: vm.Vector3.all(4.0),
    )..castsShadows = false;
    _tankTurret.add(_tankTurretPivotMarker);
    _tankBarrelPivotMarker = _mesh(
      _geo.explosion,
      _unlit(const Color(0xFFFF47E6)),
      name: 'tank_barrel_pivot_marker',
      scale: vm.Vector3.all(3.2),
    )..castsShadows = false;
    _tankBarrel.add(_tankBarrelPivotMarker);
    _tankMuzzleMarker = _mesh(
      _geo.explosion,
      _unlit(const Color(0xFFFFA52E)),
      name: 'tank_muzzle_marker',
      scale: vm.Vector3.all(2.6),
    )..castsShadows = false;
    _tankMuzzle.add(_tankMuzzleMarker);

    _initializeTankDeveloperTuning();
    _tank.visible = layoutDeveloperMode;
    scene.add(_tank);
    _applyTankDeveloperPreviewTransform();
    _buildTankDeveloperMarkers();

    _projectileMaterial = glow;
    _projectileGlowMaterial = _unlit(const Color(0x88FF4B16))
      ..doubleSided = true
      ..alphaMode = AlphaMode.blend;
    _projectileTrailMaterial = _unlit(const Color(0x66FF6A16))
      ..doubleSided = true
      ..alphaMode = AlphaMode.blend;
    _explosionMaterial = _unlit(const Color(0xFFFFB12E));

    // The real Fireball VFX GLB is now the projectile model.  Extra glow/trail
    // nodes are children/siblings controlled by developer tuning, so the source
    // GLB remains untouched.
    _projectile = Node(name: 'tank_fireball_projectile')..visible = false;
    _projectileModel = await Node.fromGlbAsset('assets/models/fireball_vfx.glb')
      ..name = 'fireball_vfx_model';
    for (final mesh in _projectileModel.meshNodes) {
      mesh
        ..castsShadows = false
        ..highlightColor = null;
    }
    _projectileGlowInner = _mesh(
      _geo.explosion,
      _projectileGlowMaterial,
      name: 'fireball_glow_inner',
      scale: vm.Vector3.all(.22),
    )..castsShadows = false;
    _projectileGlowOuter = _mesh(
      _geo.explosion,
      _projectileGlowMaterial,
      name: 'fireball_glow_outer',
      scale: vm.Vector3.all(.34),
    )..castsShadows = false;
    _projectile.addAll([_projectileModel, _projectileGlowInner, _projectileGlowOuter]);
    scene.add(_projectile);
    for (var i = 0; i < 7; i++) {
      final trail = _mesh(
        _geo.explosion,
        _projectileTrailMaterial,
        name: 'fireball_trail_$i',
        scale: vm.Vector3.all(.12),
      )
        ..visible = false
        ..castsShadows = false;
      _projectileTrail.add(trail);
      scene.add(trail);
    }
    _projectileBuilt = true;
    _applyProjectileDeveloperTuning();
    _updateProjectileDeveloperMuzzlePreview();
  }

  void _initializeTankDeveloperTuning() {
    final t = _dev.tank;
    if (t.initialized) return;

    // User-tuned T-34 base values (2026-09-26 latest).
    t
      ..x = -2.4723
      ..y = -2.5285
      ..z = 3.7958
      ..pitchDegrees = 0
      ..yawDegrees = 0
      ..rollDegrees = 0
      ..scaleX = 1.0
      ..scaleY = 1.0
      ..scaleZ = 1.0
      ..turretX = 0
      ..turretY = 170.0
      ..turretZ = -80.0
      ..turretPivotX = 0
      ..turretPivotY = 0
      ..turretPivotZ = 0
      ..turretPitchDegrees = -90.0
      ..turretYawDegrees = 0
      ..turretRollDegrees = 0
      ..turretScaleX = 2.0
      ..turretScaleY = 2.0
      ..turretScaleZ = 2.0
      ..barrelX = 0
      ..barrelY = 0
      ..barrelZ = 0
      ..barrelPivotX = 0
      ..barrelPivotY = 0
      ..barrelPivotZ = 0
      ..barrelPitchDegrees = 0
      ..barrelYawDegrees = 0
      ..barrelRollDegrees = 0
      ..barrelScaleX = 1
      ..barrelScaleY = 1
      ..barrelScaleZ = 1
      ..barrelRecoil = 0
      ..muzzleX = .043
      ..muzzleY = 121.480
      ..muzzleZ = 0
      ..autoFacePath = false
      ..showMarkers = false
      ..showPartMarkers = false
      ..shotHullRecoilDistance = .14
      ..shotHullPitchDegrees = 1.20
      ..shotBarrelRecoilDistance = 8.0
      ..shotRecoilKickSeconds = .10
      ..shotRecoilHoldSeconds = .05
      ..shotRecoilReturnSeconds = .26;

    // All four eliminations use EXACTLY the authored TARGET_1 route.
    // Only the final aim changes per victim (see finalAimMap below).
    const target1Route = <List<double>>[
      [0.0000, -2.8200, -10.0000],
      [-0.1000, -2.8200, -4.0000],
      [3.8000, -2.8200, -0.5000],
      [3.8000, -2.8200, -0.6000],
      [3.2000, -2.8200, 0.0000],
      [-6.0000, -2.8200, 6.0000],
    ];

    const pointSets = <List<List<double>>>[
      target1Route,
      target1Route,
      target1Route,
      target1Route,
    ];

    // TARGET_1 is the master for EVERYTHING in the tank route: same coordinates,
    // stop rotations, move rotations, timings, and scan order for all players.
    // The ONLY per-player difference is the final aim used for the actual shot.
    const stopHullPitch = <double>[0, 0, -1, 2, 0, 0];
    const stopHullYaw = <double>[0, 20, -18, -17, -67, -67];
    const stopHullRoll = <double>[0, 0, 0, 0, 0, 0];
    const moveHullPitch = <double>[0, 0, -1, 2, 0, 0];
    const moveHullYaw = <double>[0, 34, 0, -17, -67, -67];
    const moveHullRoll = <double>[0, 0, 0, 0, 0, 0];
    const turretYaw = <double>[0, 5, 0, 0, 0, 0];
    const barrelPitch = <double>[0, 0, 0, 0, 0, 0];
    const barrelYaw = <double>[0, 0, 0, -1, 0, 0];

    // Four authored aim targets from TARGET_1. Each tuple is
    // turretYaw, barrelPitch, barrelYaw, seconds.
    const aimPlayer1 = <double>[35.000, -3.000, 0.000, 3.000];
    const aimPlayer2 = <double>[15.400, -4.300, 0.000, 1.000];
    const aimPlayer3 = <double>[-5.000, -4.000, 0.000, 1.000];
    const aimPlayer4 = <double>[-25.000, -4.000, 0.000, 1.000];

    // No player may be aimed at twice in one execution. The victim is always
    // the FINAL aim, and the original player-1 final aim swaps into the slot
    // previously occupied by that victim.
    const aimOrders = <List<List<double>>>[
      [aimPlayer3, aimPlayer2, aimPlayer4, aimPlayer1], // kill player 1
      [aimPlayer3, aimPlayer1, aimPlayer4, aimPlayer2], // kill player 2
      [aimPlayer1, aimPlayer2, aimPlayer4, aimPlayer3], // kill player 3
      [aimPlayer3, aimPlayer2, aimPlayer1, aimPlayer4], // kill player 4
    ];

    for (var i = 0; i < 4; i++) {
      final path = t.paths[i];
      final pts = pointSets[i];
      final dst = [path.start, path.way1, path.way2, path.fire, path.exit, path.end];
      for (var j = 0; j < dst.length; j++) {
        dst[j]
          ..x = pts[j][0]
          ..y = pts[j][1]
          ..z = pts[j][2]
          ..hullPitchDegrees = stopHullPitch[j]
          ..hullYawDegrees = stopHullYaw[j]
          ..hullRollDegrees = stopHullRoll[j]
          ..moveHullPitchDegrees = moveHullPitch[j]
          ..moveHullYawDegrees = moveHullYaw[j]
          ..moveHullRollDegrees = moveHullRoll[j]
          ..turretYawDegrees = turretYaw[j]
          ..barrelPitchDegrees = barrelPitch[j]
          ..barrelYawDegrees = barrelYaw[j];
      }

      path
        ..turnToWay1Seconds = .35
        ..toWay1Seconds = 3.00
        ..turnToWay2Seconds = 1.00
        ..toWay2Seconds = 3.00
        ..turnToFireSeconds = 1.00
        ..toFireSeconds = 3.00
        ..shotTravelSeconds = .15
        ..holdAfterKillSeconds = 1.00
        ..turnToExitSeconds = .35
        ..toExitSeconds = .25
        ..turnToEndSeconds = .35
        ..toEndSeconds = 1.45
        ..finalEndTurnSeconds = .35;

      final order = aimOrders[i];
      final stages = <_TankAimStageTuning>[
        path.aim1,
        path.aim2,
        path.aim3,
        path.finalAim,
      ];
      for (var aimIndex = 0; aimIndex < stages.length; aimIndex++) {
        final values = order[aimIndex];
        stages[aimIndex]
          ..turretYawDegrees = values[0]
          ..barrelPitchDegrees = values[1]
          ..barrelYawDegrees = values[2]
          ..seconds = values[3];
      }
      path.captureDefaults();
    }

    t.initialized = true;
    t.captureDefaults();
  }

  vm.Quaternion _tankRootRotation({
    double? pathPitchDegrees,
    double? pathYawDegrees,
    double? pathRollDegrees,
  }) {
    final t = _dev.tank;
    final pitch = pathPitchDegrees ?? t.pitchDegrees;
    final yaw = pathYawDegrees ?? t.yawDegrees;
    final roll = pathRollDegrees ?? t.rollDegrees;
    final qPitch = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      pitch * math.pi / 180,
    );
    final qYaw = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      yaw * math.pi / 180,
    );
    final qRoll = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      roll * math.pi / 180,
    );
    return qYaw * qPitch * qRoll;
  }

  void _applyTankDeveloperPreviewTransform({
    vm.Vector3? position,
    double? pathPitchDegrees,
    double? pathYawDegrees,
    double? pathRollDegrees,
    double? turretYawDegrees,
    double? barrelPitchDegrees,
    double? barrelYawDegrees,
    double suspensionY = 0,
    double extraBarrelRecoil = 0,
  }) {
    final t = _dev.tank;
    final p = position ?? vm.Vector3(t.x, t.y, t.z);
    _tank
      ..position = p + vm.Vector3(0, suspensionY, 0)
      ..scale = vm.Vector3(t.scaleX, t.scaleY, t.scaleZ)
      ..rotation = _tankRootRotation(
        pathPitchDegrees: pathPitchDegrees,
        pathYawDegrees: pathYawDegrees,
        pathRollDegrees: pathRollDegrees,
      );

    final turretOffset = vm.Vector3(t.turretX, t.turretY, t.turretZ);
    final turretPivotDelta =
        vm.Vector3(t.turretPivotX, t.turretPivotY, t.turretPivotZ);
    final barrelOffset = vm.Vector3(t.barrelX, t.barrelY, t.barrelZ);
    final barrelPivotDelta =
        vm.Vector3(t.barrelPivotX, t.barrelPivotY, t.barrelPivotZ);

    // Changing a pivot must NOT teleport the visible mesh. The matching child
    // mesh gets the inverse compensation while the rotation center moves.
    _tankTurret
      ..position = _t34TurretPivotBase + turretOffset + turretPivotDelta
      ..scale = vm.Vector3(t.turretScaleX, t.turretScaleY, t.turretScaleZ);
    _tankTurretMesh.position = vm.Vector3(
      -_t34TurretPivotBase.x - turretPivotDelta.x,
      -_t34TurretPivotBase.y - turretPivotDelta.y,
      -_t34TurretPivotBase.z - turretPivotDelta.z,
    );

    final turretPitch = t.turretPitchDegrees * math.pi / 180;
    final turretYaw =
        (turretYawDegrees ?? t.turretYawDegrees) * math.pi / 180;
    final turretRoll = t.turretRollDegrees * math.pi / 180;
    // Turret horizontal traverse must rotate around the tank's UP axis (Y).
    // The previous Z-axis yaw visually tilted the whole turret diagonally.
    _tankTurret.rotation =
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), turretYaw) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), turretPitch) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), turretRoll);

    // Gun breech position is relative to the corrected turret pivot. Turret
    // pivot edits are compensated here so the gun stays attached to the turret.
    _tankBarrel
      ..position = (_t34BarrelPivotBase - _t34TurretPivotBase) -
          turretPivotDelta + barrelOffset + barrelPivotDelta
      ..scale = vm.Vector3(t.barrelScaleX, t.barrelScaleY, t.barrelScaleZ);
    _tankBarrelMesh.position = vm.Vector3(
      -_t34BarrelPivotBase.x - barrelPivotDelta.x,
      -_t34BarrelPivotBase.y - barrelPivotDelta.y,
      -_t34BarrelPivotBase.z - barrelPivotDelta.z,
    );

    final barrelPitch =
        (barrelPitchDegrees ?? t.barrelPitchDegrees) * math.pi / 180;
    final barrelYaw =
        (barrelYawDegrees ?? t.barrelYawDegrees) * math.pi / 180;
    final barrelRoll = t.barrelRollDegrees * math.pi / 180;
    // The T-34 source is Z-up inside the corrected turret.  Apply horizontal
    // gun traverse FIRST around local Z, then elevation around local X.  This
    // keeps left/right motion level instead of turning into a diagonal tilt.
    _tankBarrel.rotation =
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), barrelYaw) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), barrelPitch) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), barrelRoll);

    // Recoil moves only the gun assembly backward along its authored +Y axis.
    final totalBarrelRecoil = t.barrelRecoil + extraBarrelRecoil;
    if (totalBarrelRecoil != 0) {
      _tankBarrel.position =
          _tankBarrel.position + vm.Vector3(0, -totalBarrelRecoil, 0);
    }

    // Keep the muzzle glued to the visible barrel when the breech pivot changes.
    _tankMuzzle.position =
        vm.Vector3(t.muzzleX, t.muzzleY, t.muzzleZ) - barrelPivotDelta;
    _refreshTankPartMarkers();
    _updateProjectileDeveloperMuzzlePreview();
  }

  void _refreshTankPartMarkers() {
    final visible = layoutDeveloperMode && _dev.tank.showPartMarkers;
    _tankTurretPivotMarker.visible = visible;
    _tankBarrelPivotMarker.visible = visible;
    _tankMuzzleMarker.visible = visible;
  }

  void _resetTankTurretDeveloperValues() {
    _dev.tank.resetTurretToDefaults();
    _applyTankDeveloperPreviewTransform();
  }

  void _resetTankBarrelDeveloperValues() {
    _dev.tank.resetBarrelToDefaults();
    _applyTankDeveloperPreviewTransform();
  }

  double _tankHeading(vm.Vector3 from, vm.Vector3 to, double offsetDegrees) {
    final d = to - from;
    if (d.x.abs() + d.z.abs() < .0001) return offsetDegrees;
    // The imported T-34's visual nose is opposite the generic -Z forward used
    // by the old path helper. Correct the authored model axis exactly once here.
    return _normalizeTankAngle(
      math.atan2(d.x, -d.z) * 180 / math.pi + 180.0 + offsetDegrees,
    );
  }

  double _normalizeTankAngle(double degrees) {
    var v = degrees % 360.0;
    if (v > 180.0) v -= 360.0;
    if (v <= -180.0) v += 360.0;
    return v;
  }

  double _tankMotionEase(double raw) {
    final t = raw.clamp(0.0, 1.0).toDouble();
    // Quintic smoothstep: zero velocity and acceleration at both ends. This
    // gives the heavy tank a planted accelerate/coast/brake feel instead of a
    // constant-speed ice slide.
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  vm.Vector3 _tankLerp(vm.Vector3 a, vm.Vector3 b, double t) =>
      a + (b - a) * _tankMotionEase(t);

  double _tankLerpAngle(double a, double b, double t) {
    var delta = (b - a) % 360.0;
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    return _normalizeTankAngle(a + delta * _tankMotionEase(t));
  }

  void _startTankDeveloperPath(int target) {
    _tankDeveloperTarget = target.clamp(0, 3).toInt();
    _restoreTankDeveloperVictim();
    _tankDeveloperPathRunning = true;
    _tankDeveloperPathStartedAt = DateTime.now();
    _loserIndex = _tankDeveloperTarget;
    _shotTriggered = false;
    _impactTriggered = false;
    _projectile.visible = false;
    for (final n in _projectileTrail) n.visible = false;
    _tank.visible = true;
    _refreshTankDeveloperMarkers();
  }

  void _stopTankDeveloperPath() {
    _tankDeveloperPathRunning = false;
    _tankDeveloperPathStartedAt = null;
    _projectile.visible = false;
    _updateProjectileDeveloperMuzzlePreview();
  }

  void _resetTankDeveloperPath([int? target]) {
    _stopTankDeveloperPath();
    if (target != null) _tankDeveloperTarget = target.clamp(0, 3).toInt();
    _restoreTankDeveloperVictim();
    final p = _dev.tank.paths[_tankDeveloperTarget];
    final start = p.start.vector;
    _dev.tank
      ..x = start.x
      ..y = start.y
      ..z = start.z;
    _applyTankDeveloperPreviewTransform(position: start);
    _refreshTankDeveloperMarkers();
  }

  double _tankPreviewYawForPoint(_TankPointTuning point) {
    if (!_dev.tank.autoFacePath) return point.hullYawDegrees;
    final path = _dev.tank.paths[_tankDeveloperTarget];
    final points = path.points.toList();
    final index = points.indexOf(point);
    vm.Vector3 next;
    if (index >= 0 && index < points.length - 1) {
      next = points[index + 1].vector;
    } else if (index > 0) {
      final previous = points[index - 1].vector;
      next = point.vector + (point.vector - previous);
    } else {
      next = point.vector + vm.Vector3(0, 0, -1);
    }
    return _tankHeading(point.vector, next, point.hullYawDegrees);
  }

  void _previewTankDeveloperPoint(_TankPointTuning point) {
    _stopTankDeveloperPath();
    _restoreTankDeveloperVictim();
    final p = point.vector;
    _dev.tank
      ..x = p.x
      ..y = p.y
      ..z = p.z;
    _applyTankDeveloperPreviewTransform(
      position: p,
      pathPitchDegrees: point.hullPitchDegrees,
      pathYawDegrees: _tankPreviewYawForPoint(point),
      pathRollDegrees: point.hullRollDegrees,
      turretYawDegrees: point.turretYawDegrees,
      barrelPitchDegrees: point.barrelPitchDegrees,
      barrelYawDegrees: point.barrelYawDegrees,
    );
  }

  void _previewTankDeveloperMoveRotation(_TankPointTuning point) {
    _stopTankDeveloperPath();
    _restoreTankDeveloperVictim();
    final p = point.vector;
    _dev.tank
      ..x = p.x
      ..y = p.y
      ..z = p.z;
    final path = _dev.tank.paths[_tankDeveloperTarget];
    final points = path.points.toList();
    final index = points.indexOf(point);
    vm.Vector3 toward;
    if (index >= 0 && index < points.length - 1) {
      toward = points[index + 1].vector;
    } else if (index > 0) {
      final previous = points[index - 1].vector;
      toward = p + (p - previous);
    } else {
      toward = p + vm.Vector3(0, 0, -1);
    }
    final moveYaw = _dev.tank.autoFacePath
        ? _tankHeading(p, toward, point.moveHullYawDegrees)
        : point.moveHullYawDegrees;
    _applyTankDeveloperPreviewTransform(
      position: p,
      pathPitchDegrees: point.moveHullPitchDegrees,
      pathYawDegrees: moveYaw,
      pathRollDegrees: point.moveHullRollDegrees,
      turretYawDegrees: point.turretYawDegrees,
      barrelPitchDegrees: point.barrelPitchDegrees,
      barrelYawDegrees: point.barrelYawDegrees,
    );
  }

  void _previewTankDeveloperAimStage(_TankAimStageTuning aim) {
    _stopTankDeveloperPath();
    _restoreTankDeveloperVictim();
    final path = _dev.tank.paths[_tankDeveloperTarget];
    final fire = path.fire;
    final p = fire.vector;
    _dev.tank
      ..x = p.x
      ..y = p.y
      ..z = p.z;
    _applyTankDeveloperPreviewTransform(
      position: p,
      pathPitchDegrees: fire.hullPitchDegrees,
      pathYawDegrees: _tankPreviewYawForPoint(fire),
      pathRollDegrees: fire.hullRollDegrees,
      turretYawDegrees: aim.turretYawDegrees,
      barrelPitchDegrees: aim.barrelPitchDegrees,
      barrelYawDegrees: aim.barrelYawDegrees,
    );
  }

  void _copyTankPathRotationsToAll(int sourceIndex) {
    final source = _dev.tank.paths[sourceIndex.clamp(0, 3).toInt()];
    for (var i = 0; i < _dev.tank.paths.length; i++) {
      if (i == sourceIndex) continue;
      final target = _dev.tank.paths[i];
      final sourcePoints = source.points.toList();
      final targetPoints = target.points.toList();
      for (var j = 0; j < sourcePoints.length; j++) {
        targetPoints[j]
          ..hullPitchDegrees = sourcePoints[j].hullPitchDegrees
          ..hullYawDegrees = sourcePoints[j].hullYawDegrees
          ..hullRollDegrees = sourcePoints[j].hullRollDegrees
          ..moveHullPitchDegrees = sourcePoints[j].moveHullPitchDegrees
          ..moveHullYawDegrees = sourcePoints[j].moveHullYawDegrees
          ..moveHullRollDegrees = sourcePoints[j].moveHullRollDegrees
          ..turretYawDegrees = sourcePoints[j].turretYawDegrees
          ..barrelPitchDegrees = sourcePoints[j].barrelPitchDegrees
          ..barrelYawDegrees = sourcePoints[j].barrelYawDegrees;
      }
      final sourceAims = source.aims.toList();
      final targetAims = target.aims.toList();
      for (var j = 0; j < sourceAims.length; j++) {
        targetAims[j]
          ..turretYawDegrees = sourceAims[j].turretYawDegrees
          ..barrelPitchDegrees = sourceAims[j].barrelPitchDegrees
          ..barrelYawDegrees = sourceAims[j].barrelYawDegrees
          ..seconds = sourceAims[j].seconds;
      }
      target
        ..turnToWay1Seconds = source.turnToWay1Seconds
        ..toWay1Seconds = source.toWay1Seconds
        ..turnToWay2Seconds = source.turnToWay2Seconds
        ..toWay2Seconds = source.toWay2Seconds
        ..turnToFireSeconds = source.turnToFireSeconds
        ..toFireSeconds = source.toFireSeconds
        ..shotTravelSeconds = source.shotTravelSeconds
        ..holdAfterKillSeconds = source.holdAfterKillSeconds
        ..turnToExitSeconds = source.turnToExitSeconds
        ..toExitSeconds = source.toExitSeconds
        ..turnToEndSeconds = source.turnToEndSeconds
        ..toEndSeconds = source.toEndSeconds
        ..finalEndTurnSeconds = source.finalEndTurnSeconds;
    }
  }

  void _selectTankDeveloperTarget(int target) {
    _tankDeveloperTarget = target.clamp(0, 3).toInt();
    _refreshTankDeveloperMarkers();
  }

  void _restoreTankDeveloperVictim() {
    for (var i = 0; i < _players.length; i++) {
      _players[i].root.visible = true;
      if (i < _chairs.length) _chairs[i].visible = true;
      if (i < _stations.length) _stations[i].visible = true;
    }
    for (final debris in _debris) {
      debris.node.detach();
    }
    _debris.clear();
    _impactTriggered = false;
    _shotTriggered = false;
  }


  double _easeOutCubic(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    final inv = 1.0 - t;
    return 1.0 - inv * inv * inv;
  }

  void _hideTankDeveloperVictim(int index) {
    if (index < 0 || index >= _players.length) return;

    _players[index].root.visible = false;
    if (index < _chairs.length) _chairs[index].visible = false;
    if (index < _stations.length) _stations[index].visible = false;

    final loserWorld = _stationPosition(index);
    final origin = vm.Vector3(loserWorld.x, _roomFloorY + .62, loserWorld.z);

    for (var i = 0; i < 22; i++) {
      final node = _mesh(
        i % 3 == 0 ? _geo.explosion : _geo.debris,
        i % 3 == 0
            ? _explosionMaterial
            : _pbr(
                const Color(0xFF31373B),
                roughness: .7,
                metallic: .2,
              ),
        position: origin +
            vm.Vector3(
              (_random.nextDouble() - .5) * .32,
              (_random.nextDouble() - .5) * .24,
              (_random.nextDouble() - .5) * .32,
            ),
        scale: vm.Vector3.all((.07 + _random.nextDouble() * .17) * _dev.projectile.impactScale),
      )..castsShadows = false;

      scene.add(node);

      final angle = _random.nextDouble() * math.pi * 2;
      final speed = .7 + _random.nextDouble() * 2.4;

      _debris.add(
        _Debris(
          node: node,
          velocity: vm.Vector3(
            math.cos(angle) * speed,
            1.1 + _random.nextDouble() * 2.0,
            math.sin(angle) * speed,
          ),
          life: .65 + _random.nextDouble() * 1.25,
        ),
      );
    }
  }

  void _updateTankDeveloperPreview() {
    if (!tankDeveloperMode || !_tankDeveloperPathRunning) return;
    final started = _tankDeveloperPathStartedAt;
    if (started == null) return;
    final path = _dev.tank.paths[_tankDeveloperTarget];
    final t = _dev.tank;
    final sec = DateTime.now().difference(started).inMicroseconds / 1000000.0;

    // Each stop has its OWN rotation stage.  Rotation is never blended while
    // travelling, so the tank cannot crab/slide diagonally anymore.
    final dTurnStart = path.turnToWay1Seconds;
    final dMove1 = dTurnStart + path.toWay1Seconds;
    final dTurnWay1 = dMove1 + path.turnToWay2Seconds;
    final dMove2 = dTurnWay1 + path.toWay2Seconds;
    final dTurnWay2 = dMove2 + path.turnToFireSeconds;
    final dMove3 = dTurnWay2 + path.toFireSeconds;
    final dAim1 = dMove3 + path.aim1.seconds;
    final dAim2 = dAim1 + path.aim2.seconds;
    final dAim3 = dAim2 + path.aim3.seconds;
    final dFinalAim = dAim3 + path.finalAim.seconds;
    final dShot = dFinalAim + path.shotTravelSeconds;
    final dHold = dShot + path.holdAfterKillSeconds;
    final dTurnFire = dHold + path.turnToExitSeconds;
    final dMoveExit = dTurnFire + path.toExitSeconds;
    final dTurnExit = dMoveExit + path.turnToEndSeconds;
    final dMoveEnd = dTurnExit + path.toEndSeconds;
    final dFinalEndTurn = dMoveEnd + path.finalEndTurnSeconds;

    vm.Vector3 pos = path.start.vector;
    double hullPitch = t.pitchDegrees;
    double hullYaw = t.yawDegrees;
    double hullRoll = t.rollDegrees;
    double turret = t.turretYawDegrees;
    double barrelPitch = t.barrelPitchDegrees;
    double barrelYaw = t.barrelYawDegrees;
    double segmentProgress = 0;
    bool moving = false;

    double manualOrAutoMoveYaw(_TankPointTuning point, vm.Vector3 toward) {
      if (!t.autoFacePath) return point.moveHullYawDegrees;
      return _tankHeading(point.vector, toward, point.moveHullYawDegrees);
    }

    void exactStop(
      vm.Vector3 at, {
      required double pitch,
      required double yaw,
      required double roll,
      required double turretYaw,
      required double gunPitch,
      required double gunYaw,
    }) {
      pos = at;
      hullPitch = pitch;
      hullYaw = yaw;
      hullRoll = roll;
      turret = turretYaw;
      barrelPitch = gunPitch;
      barrelYaw = gunYaw;
      moving = false;
    }

    void turnInPlace({
      required vm.Vector3 at,
      required double fromPitch,
      required double fromYaw,
      required double fromRoll,
      required double toPitch,
      required double toYaw,
      required double toRoll,
      required double fromTurret,
      required double toTurret,
      required double fromGunPitch,
      required double toGunPitch,
      required double fromGunYaw,
      required double toGunYaw,
      required double k,
    }) {
      final u = _tankMotionEase(k.clamp(0.0, 1.0).toDouble());
      pos = at;
      hullPitch = _tankLerpAngle(fromPitch, toPitch, u);
      hullYaw = _tankLerpAngle(fromYaw, toYaw, u);
      hullRoll = _tankLerpAngle(fromRoll, toRoll, u);
      turret = _tankLerpAngle(fromTurret, toTurret, u);
      barrelPitch = _tankLerpAngle(fromGunPitch, toGunPitch, u);
      barrelYaw = _tankLerpAngle(fromGunYaw, toGunYaw, u);
      segmentProgress = u;
      moving = false;
    }

    void stopThenAlignForMove({
      required vm.Vector3 at,
      required double fromPitch,
      required double fromYaw,
      required double fromRoll,
      required _TankPointTuning point,
      required double moveYaw,
      required double fromTurret,
      required double fromGunPitch,
      required double fromGunYaw,
      required double k,
    }) {
      final q = k.clamp(0.0, 1.0).toDouble();
      // First 55%: arrive/settle to STOP rotation. Remaining 45%: align to
      // independent MOVE rotation. The tank stays completely stationary.
      if (q <= .55) {
        final local = q / .55;
        turnInPlace(
          at: at,
          fromPitch: fromPitch, fromYaw: fromYaw, fromRoll: fromRoll,
          toPitch: point.hullPitchDegrees, toYaw: point.hullYawDegrees, toRoll: point.hullRollDegrees,
          fromTurret: fromTurret, toTurret: point.turretYawDegrees,
          fromGunPitch: fromGunPitch, toGunPitch: point.barrelPitchDegrees,
          fromGunYaw: fromGunYaw, toGunYaw: point.barrelYawDegrees,
          k: local,
        );
      } else {
        final local = (q - .55) / .45;
        turnInPlace(
          at: at,
          fromPitch: point.hullPitchDegrees, fromYaw: point.hullYawDegrees, fromRoll: point.hullRollDegrees,
          toPitch: point.moveHullPitchDegrees, toYaw: moveYaw, toRoll: point.moveHullRollDegrees,
          fromTurret: point.turretYawDegrees, toTurret: point.turretYawDegrees,
          fromGunPitch: point.barrelPitchDegrees, toGunPitch: point.barrelPitchDegrees,
          fromGunYaw: point.barrelYawDegrees, toGunYaw: point.barrelYawDegrees,
          k: local,
        );
      }
    }

    void moveOnly(
      _TankPointTuning from,
      _TankPointTuning to,
      double k, {
      required double fixedPitch,
      required double fixedYaw,
      required double fixedRoll,
      required double fixedTurret,
      required double fixedGunPitch,
      required double fixedGunYaw,
    }) {
      final u = k.clamp(0.0, 1.0).toDouble();
      segmentProgress = u;
      moving = true;
      pos = _tankLerp(from.vector, to.vector, u);
      // Absolutely NO rotation while moving.  The rotation chosen at the stop
      // remains frozen for the whole straight segment.
      hullPitch = fixedPitch;
      hullYaw = fixedYaw;
      hullRoll = fixedRoll;
      turret = fixedTurret;
      barrelPitch = fixedGunPitch;
      barrelYaw = fixedGunYaw;
    }

    final startMoveYaw = manualOrAutoMoveYaw(path.start, path.way1.vector);
    final way1MoveYaw = manualOrAutoMoveYaw(path.way1, path.way2.vector);
    final way2MoveYaw = manualOrAutoMoveYaw(path.way2, path.fire.vector);
    final fireMoveYaw = manualOrAutoMoveYaw(path.fire, path.exit.vector);
    final exitMoveYaw = manualOrAutoMoveYaw(path.exit, path.end.vector);
    final endStopYaw = path.end.hullYawDegrees;

    if (sec < dTurnStart) {
      // START: initial tank orientation -> START's independent departure angle.
      stopThenAlignForMove(
        at: path.start.vector,
        fromPitch: t.pitchDegrees, fromYaw: t.yawDegrees, fromRoll: t.rollDegrees,
        point: path.start, moveYaw: startMoveYaw,
        fromTurret: t.turretYawDegrees,
        fromGunPitch: t.barrelPitchDegrees, fromGunYaw: t.barrelYawDegrees,
        k: sec / math.max(.001, path.turnToWay1Seconds),
      );
    } else if (sec < dMove1) {
      moveOnly(path.start, path.way1,
          (sec - dTurnStart) / math.max(.001, path.toWay1Seconds),
          fixedPitch: path.start.moveHullPitchDegrees,
          fixedYaw: startMoveYaw,
          fixedRoll: path.start.moveHullRollDegrees,
          fixedTurret: path.start.turretYawDegrees,
          fixedGunPitch: path.start.barrelPitchDegrees,
          fixedGunYaw: path.start.barrelYawDegrees);
    } else if (sec < dTurnWay1) {
      // WAY1: stop first, then rotate to WAY1's departure angle.
      stopThenAlignForMove(
        at: path.way1.vector,
        fromPitch: path.start.moveHullPitchDegrees, fromYaw: startMoveYaw, fromRoll: path.start.moveHullRollDegrees,
        point: path.way1, moveYaw: way1MoveYaw,
        fromTurret: path.start.turretYawDegrees,
        fromGunPitch: path.start.barrelPitchDegrees, fromGunYaw: path.start.barrelYawDegrees,
        k: (sec - dMove1) / math.max(.001, path.turnToWay2Seconds),
      );
    } else if (sec < dMove2) {
      moveOnly(path.way1, path.way2,
          (sec - dTurnWay1) / math.max(.001, path.toWay2Seconds),
          fixedPitch: path.way1.moveHullPitchDegrees,
          fixedYaw: way1MoveYaw,
          fixedRoll: path.way1.moveHullRollDegrees,
          fixedTurret: path.way1.turretYawDegrees,
          fixedGunPitch: path.way1.barrelPitchDegrees,
          fixedGunYaw: path.way1.barrelYawDegrees);
    } else if (sec < dTurnWay2) {
      // WAY2: stop -> rotate -> move to FIRE.
      stopThenAlignForMove(
        at: path.way2.vector,
        fromPitch: path.way1.moveHullPitchDegrees, fromYaw: way1MoveYaw, fromRoll: path.way1.moveHullRollDegrees,
        point: path.way2, moveYaw: way2MoveYaw,
        fromTurret: path.way1.turretYawDegrees,
        fromGunPitch: path.way1.barrelPitchDegrees, fromGunYaw: path.way1.barrelYawDegrees,
        k: (sec - dMove2) / math.max(.001, path.turnToFireSeconds),
      );
    } else if (sec < dMove3) {
      moveOnly(path.way2, path.fire,
          (sec - dTurnWay2) / math.max(.001, path.toFireSeconds),
          fixedPitch: path.way2.moveHullPitchDegrees,
          fixedYaw: way2MoveYaw,
          fixedRoll: path.way2.moveHullRollDegrees,
          fixedTurret: path.way2.turretYawDegrees,
          fixedGunPitch: path.way2.barrelPitchDegrees,
          fixedGunYaw: path.way2.barrelYawDegrees);
    } else if (sec < dAim1) {
      // At FIRE the hull stays exactly as it arrived. Only turret/gun aim now.
      final k = (sec - dMove3) / math.max(.001, path.aim1.seconds);
      exactStop(path.fire.vector,
        pitch: _tankLerpAngle(path.way2.moveHullPitchDegrees, path.fire.hullPitchDegrees, k),
        yaw: _tankLerpAngle(way2MoveYaw, path.fire.hullYawDegrees, k),
        roll: _tankLerpAngle(path.way2.moveHullRollDegrees, path.fire.hullRollDegrees, k),
        turretYaw: _tankLerpAngle(path.fire.turretYawDegrees, path.aim1.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.fire.barrelPitchDegrees, path.aim1.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.fire.barrelYawDegrees, path.aim1.barrelYawDegrees, k));
    } else if (sec < dAim2) {
      final k = (sec - dAim1) / math.max(.001, path.aim2.seconds);
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: _tankLerpAngle(path.aim1.turretYawDegrees, path.aim2.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.aim1.barrelPitchDegrees, path.aim2.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.aim1.barrelYawDegrees, path.aim2.barrelYawDegrees, k));
    } else if (sec < dAim3) {
      final k = (sec - dAim2) / math.max(.001, path.aim3.seconds);
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: _tankLerpAngle(path.aim2.turretYawDegrees, path.aim3.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.aim2.barrelPitchDegrees, path.aim3.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.aim2.barrelYawDegrees, path.aim3.barrelYawDegrees, k));
    } else if (sec < dFinalAim) {
      final k = (sec - dAim3) / math.max(.001, path.finalAim.seconds);
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: _tankLerpAngle(path.aim3.turretYawDegrees, path.finalAim.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.aim3.barrelPitchDegrees, path.finalAim.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.aim3.barrelYawDegrees, path.finalAim.barrelYawDegrees, k));
    } else if (sec < dHold) {
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: path.finalAim.turretYawDegrees,
        gunPitch: path.finalAim.barrelPitchDegrees,
        gunYaw: path.finalAim.barrelYawDegrees);
    } else if (sec < dTurnFire) {
      // FIRE stop: after the kill, turn IN PLACE for the EXIT segment.
      turnInPlace(
        at: path.fire.vector,
        fromPitch: path.fire.hullPitchDegrees,
        fromYaw: path.fire.hullYawDegrees,
        fromRoll: path.fire.hullRollDegrees,
        toPitch: path.fire.moveHullPitchDegrees,
        toYaw: fireMoveYaw,
        toRoll: path.fire.moveHullRollDegrees,
        fromTurret: path.finalAim.turretYawDegrees,
        toTurret: path.fire.turretYawDegrees,
        fromGunPitch: path.finalAim.barrelPitchDegrees,
        toGunPitch: path.fire.barrelPitchDegrees,
        fromGunYaw: path.finalAim.barrelYawDegrees,
        toGunYaw: path.fire.barrelYawDegrees,
        k: (sec - dHold) / math.max(.001, path.turnToExitSeconds),
      );
    } else if (sec < dMoveExit) {
      moveOnly(path.fire, path.exit,
          (sec - dTurnFire) / math.max(.001, path.toExitSeconds),
          fixedPitch: path.fire.moveHullPitchDegrees,
          fixedYaw: fireMoveYaw,
          fixedRoll: path.fire.moveHullRollDegrees,
          fixedTurret: path.fire.turretYawDegrees,
          fixedGunPitch: path.fire.barrelPitchDegrees,
          fixedGunYaw: path.fire.barrelYawDegrees);
    } else if (sec < dTurnExit) {
      // EXIT stop: turn for END.
      stopThenAlignForMove(
        at: path.exit.vector,
        fromPitch: path.fire.moveHullPitchDegrees, fromYaw: fireMoveYaw, fromRoll: path.fire.moveHullRollDegrees,
        point: path.exit, moveYaw: exitMoveYaw,
        fromTurret: path.fire.turretYawDegrees,
        fromGunPitch: path.fire.barrelPitchDegrees, fromGunYaw: path.fire.barrelYawDegrees,
        k: (sec - dMoveExit) / math.max(.001, path.turnToEndSeconds),
      );
    } else if (sec < dMoveEnd) {
      moveOnly(path.exit, path.end,
          (sec - dTurnExit) / math.max(.001, path.toEndSeconds),
          fixedPitch: path.exit.moveHullPitchDegrees,
          fixedYaw: exitMoveYaw,
          fixedRoll: path.exit.moveHullRollDegrees,
          fixedTurret: path.exit.turretYawDegrees,
          fixedGunPitch: path.exit.barrelPitchDegrees,
          fixedGunYaw: path.exit.barrelYawDegrees);
    } else if (sec < dFinalEndTurn) {
      // END itself also gets an independent final in-place turn.
      turnInPlace(
        at: path.end.vector,
        fromPitch: path.exit.moveHullPitchDegrees,
        fromYaw: exitMoveYaw,
        fromRoll: path.exit.moveHullRollDegrees,
        toPitch: path.end.hullPitchDegrees,
        toYaw: endStopYaw,
        toRoll: path.end.hullRollDegrees,
        fromTurret: path.exit.turretYawDegrees,
        toTurret: path.end.turretYawDegrees,
        fromGunPitch: path.exit.barrelPitchDegrees,
        toGunPitch: path.end.barrelPitchDegrees,
        fromGunYaw: path.exit.barrelYawDegrees,
        toGunYaw: path.end.barrelYawDegrees,
        k: (sec - dMoveEnd) / math.max(.001, path.finalEndTurnSeconds),
      );
    } else {
      exactStop(path.end.vector,
        pitch: path.end.hullPitchDegrees, yaw: endStopYaw, roll: path.end.hullRollDegrees,
        turretYaw: path.end.turretYawDegrees,
        gunPitch: path.end.barrelPitchDegrees,
        gunYaw: path.end.barrelYawDegrees);
      _tankDeveloperPathRunning = false;
      _tankDeveloperPathStartedAt = null;
    }

    double recoilAmount = 0;
    if (sec >= dFinalAim) {
      final r = sec - dFinalAim;
      final kick = math.max(.001, t.shotRecoilKickSeconds);
      final hold = math.max(0.0, t.shotRecoilHoldSeconds);
      final back = math.max(.001, t.shotRecoilReturnSeconds);
      if (r < kick) {
        recoilAmount = _tankMotionEase(r / kick);
      } else if (r < kick + hold) {
        recoilAmount = 1;
      } else if (r < kick + hold + back) {
        recoilAmount = 1 - _tankMotionEase((r - kick - hold) / back);
      }
    }

    if (recoilAmount > 0) {
      final yawRad = hullYaw * math.pi / 180.0;
      final backward = vm.Vector3(-math.sin(yawRad), 0, math.cos(yawRad));
      pos = pos + backward * (t.shotHullRecoilDistance * recoilAmount);
      hullPitch += t.shotHullPitchDegrees * recoilAmount;
    }

    final suspension = moving
        ? math.sin(_tankMotionEase(segmentProgress) * math.pi) * .010
        : 0.0;
    _applyTankDeveloperPreviewTransform(
      position: pos,
      pathPitchDegrees: hullPitch,
      pathYawDegrees: hullYaw,
      pathRollDegrees: hullRoll,
      turretYawDegrees: turret,
      barrelPitchDegrees: barrelPitch,
      barrelYawDegrees: barrelYaw,
      suspensionY: suspension,
      extraBarrelRecoil: t.shotBarrelRecoilDistance * recoilAmount,
    );

    if (sec >= dFinalAim && !_shotTriggered) {
      _shotTriggered = true;
      _updateProjectileDeveloperMuzzlePreview();
      _shotStart = vm.Vector3.copy(_projectile.position);
      final loser = _stationPosition(_tankDeveloperTarget);
      _shotTarget = vm.Vector3(loser.x, _roomFloorY + .72, loser.z);
      _projectile
        ..visible = true
        ..position = vm.Vector3.copy(_shotStart);
    }

    if (_shotTriggered && !_impactTriggered) {
      final denom = math.max(.001, path.shotTravelSeconds);
      final shotT = ((sec - dFinalAim) / denom).clamp(0.0, 1.0).toDouble();
      _projectile.position = _shotStart + (_shotTarget - _shotStart) * _easeOutCubic(shotT);
      final spinSeconds = math.max(.001, path.shotTravelSeconds) * shotT;
      _projectileModel.rotation = vm.Quaternion.euler(
        vm.radians(_dev.projectile.pitchDegrees + _dev.projectile.spinX * spinSeconds),
        vm.radians(_dev.projectile.yawDegrees + _dev.projectile.spinY * spinSeconds),
        vm.radians(_dev.projectile.rollDegrees + _dev.projectile.spinZ * spinSeconds),
      );
      final pulse = 1.0 + math.sin(shotT * math.pi * 10) * .08;
      _projectileGlowInner.scale = vm.Vector3.all(_dev.projectile.glowInnerSize * pulse);
      _projectileGlowOuter.scale = vm.Vector3.all(_dev.projectile.glowOuterSize * (2.0 - pulse));
      _updateProjectileTrail(_shotStart, _shotTarget, shotT);
      if (shotT >= 1) {
        _projectile.visible = false;
        for (final n in _projectileTrail) n.visible = false;
        _impactTriggered = true;
        _hideTankDeveloperVictim(_tankDeveloperTarget);
      }
    }
  }

  void _previewTankDeveloperRecoil([double amount = 1.0]) {
    if (!tankDeveloperMode || !_dev.tank.initialized) return;
    final t = _dev.tank;
    final path = t.paths[_tankDeveloperTarget];
    final a = amount.clamp(0.0, 1.0).toDouble();
    final hullYaw = _tankPreviewYawForPoint(path.fire);
    final yawRad = hullYaw * math.pi / 180.0;
    final backward = vm.Vector3(-math.sin(yawRad), 0, math.cos(yawRad));
    final position = path.fire.vector + backward * (t.shotHullRecoilDistance * a);
    _applyTankDeveloperPreviewTransform(
      position: position,
      pathPitchDegrees: path.fire.hullPitchDegrees + t.shotHullPitchDegrees * a,
      pathYawDegrees: hullYaw,
      pathRollDegrees: path.fire.hullRollDegrees,
      turretYawDegrees: path.finalAim.turretYawDegrees,
      barrelPitchDegrees: path.finalAim.barrelPitchDegrees,
      barrelYawDegrees: path.finalAim.barrelYawDegrees,
      extraBarrelRecoil: t.shotBarrelRecoilDistance * a,
    );
  }

  void _buildTankDeveloperMarkers() {
    final colors = <Color>[
      const Color(0xFF00E5FF),
      const Color(0xFF64FFDA),
      const Color(0xFFFFD740),
      const Color(0xFFFF5252),
      const Color(0xFFB388FF),
      const Color(0xFF69F0AE),
    ];
    for (var i = 0; i < 6; i++) {
      final marker = _mesh(
        _geo.projectile,
        _unlit(colors[i]),
        name: 'tank_path_marker_$i',
        scale: vm.Vector3.all(i == 3 ? .12 : .085),
      )..castsShadows = false;
      _tankPathMarkers.add(marker);
      scene.add(marker);
    }
    _refreshTankDeveloperMarkers();
  }

  void _refreshTankDeveloperMarkers() {
    if (_tankPathMarkers.length != 6 || !_dev.tank.initialized) return;
    final p = _dev.tank.paths[_tankDeveloperTarget];
    final points = [p.start, p.way1, p.way2, p.fire, p.exit, p.end];
    for (var i = 0; i < _tankPathMarkers.length; i++) {
      _tankPathMarkers[i]
        ..visible = layoutDeveloperMode && _dev.tank.showMarkers
        ..position = points[i].vector + vm.Vector3(0, .10, 0);
    }
  }

  String _tankDeveloperSettingsText() {
    final t = _dev.tank;
    final lines = <String>[
      'GUESS_TIME_TANK',
      'TANK x=${t.x.toStringAsFixed(4)} y=${t.y.toStringAsFixed(4)} z=${t.z.toStringAsFixed(4)} '
          'pitch=${t.pitchDegrees.toStringAsFixed(3)} yaw=${t.yawDegrees.toStringAsFixed(3)} roll=${t.rollDegrees.toStringAsFixed(3)} '
          'scaleX=${t.scaleX.toStringAsFixed(5)} scaleY=${t.scaleY.toStringAsFixed(5)} scaleZ=${t.scaleZ.toStringAsFixed(5)}',
      'TURRET pos=${t.turretX.toStringAsFixed(3)},${t.turretY.toStringAsFixed(3)},${t.turretZ.toStringAsFixed(3)} '
          'pivot=${t.turretPivotX.toStringAsFixed(3)},${t.turretPivotY.toStringAsFixed(3)},${t.turretPivotZ.toStringAsFixed(3)} '
          'rot=${t.turretPitchDegrees.toStringAsFixed(3)},${t.turretYawDegrees.toStringAsFixed(3)},${t.turretRollDegrees.toStringAsFixed(3)} '
          'scale=${t.turretScaleX.toStringAsFixed(4)},${t.turretScaleY.toStringAsFixed(4)},${t.turretScaleZ.toStringAsFixed(4)}',
      'BARREL pos=${t.barrelX.toStringAsFixed(3)},${t.barrelY.toStringAsFixed(3)},${t.barrelZ.toStringAsFixed(3)} '
          'pivot=${t.barrelPivotX.toStringAsFixed(3)},${t.barrelPivotY.toStringAsFixed(3)},${t.barrelPivotZ.toStringAsFixed(3)} '
          'rot=${t.barrelPitchDegrees.toStringAsFixed(3)},${t.barrelYawDegrees.toStringAsFixed(3)},${t.barrelRollDegrees.toStringAsFixed(3)} '
          'scale=${t.barrelScaleX.toStringAsFixed(4)},${t.barrelScaleY.toStringAsFixed(4)},${t.barrelScaleZ.toStringAsFixed(4)} '
          'recoil=${t.barrelRecoil.toStringAsFixed(3)} muzzle=${t.muzzleX.toStringAsFixed(3)},${t.muzzleY.toStringAsFixed(3)},${t.muzzleZ.toStringAsFixed(3)} '
          'autoFacePath=${t.autoFacePath} showMarkers=${t.showMarkers} showPartMarkers=${t.showPartMarkers}',
      'SHOT_RECOIL hull=${t.shotHullRecoilDistance.toStringAsFixed(3)} pitch=${t.shotHullPitchDegrees.toStringAsFixed(3)} '
          'gun=${t.shotBarrelRecoilDistance.toStringAsFixed(3)} kick=${t.shotRecoilKickSeconds.toStringAsFixed(3)} '
          'hold=${t.shotRecoilHoldSeconds.toStringAsFixed(3)} return=${t.shotRecoilReturnSeconds.toStringAsFixed(3)}',
    ];
    for (var i = 0; i < t.paths.length; i++) {
      final p = t.paths[i];
      String pt(_TankPointTuning v) =>
          '${v.x.toStringAsFixed(4)},${v.y.toStringAsFixed(4)},${v.z.toStringAsFixed(4)}'
          '|stopHull=${v.hullPitchDegrees.toStringAsFixed(3)},${v.hullYawDegrees.toStringAsFixed(3)},${v.hullRollDegrees.toStringAsFixed(3)}'
          '|moveHull=${v.moveHullPitchDegrees.toStringAsFixed(3)},${v.moveHullYawDegrees.toStringAsFixed(3)},${v.moveHullRollDegrees.toStringAsFixed(3)}'
          '|turret=${v.turretYawDegrees.toStringAsFixed(3)}'
          '|barrel=${v.barrelPitchDegrees.toStringAsFixed(3)},${v.barrelYawDegrees.toStringAsFixed(3)}';
      String aim(_TankAimStageTuning a) =>
          '${a.turretYawDegrees.toStringAsFixed(3)},${a.barrelPitchDegrees.toStringAsFixed(3)},${a.barrelYawDegrees.toStringAsFixed(3)},${a.seconds.toStringAsFixed(3)}';
      lines.add(
        'TARGET_${i + 1} start=${pt(p.start)} way1=${pt(p.way1)} way2=${pt(p.way2)} fire=${pt(p.fire)} exit=${pt(p.exit)} end=${pt(p.end)} '
        'turns=${p.turnToWay1Seconds.toStringAsFixed(2)},${p.turnToWay2Seconds.toStringAsFixed(2)},${p.turnToFireSeconds.toStringAsFixed(2)},${p.turnToExitSeconds.toStringAsFixed(2)},${p.turnToEndSeconds.toStringAsFixed(2)},${p.finalEndTurnSeconds.toStringAsFixed(2)} '
        'times=${p.toWay1Seconds.toStringAsFixed(2)},${p.toWay2Seconds.toStringAsFixed(2)},${p.toFireSeconds.toStringAsFixed(2)},${p.shotTravelSeconds.toStringAsFixed(2)},${p.holdAfterKillSeconds.toStringAsFixed(2)},${p.toExitSeconds.toStringAsFixed(2)},${p.toEndSeconds.toStringAsFixed(2)} '
        'aim1=${aim(p.aim1)} aim2=${aim(p.aim2)} aim3=${aim(p.aim3)} finalAim=${aim(p.finalAim)}',
      );
    }
    return lines.join('\n');
  }

  void startElimination(int loserIndex) {
    if (_eliminationActive) return;
    _loserIndex = loserIndex.clamp(0, math.max(0, _players.length - 1)).toInt();
    _eliminationActive = true;
    _eliminationStartedAt = DateTime.now();
    _shotTriggered = false;
    _impactTriggered = false;
    final path = _dev.tank.paths[_loserIndex];
    final startMoveYaw = !_dev.tank.autoFacePath
        ? path.start.moveHullYawDegrees
        : _tankHeading(path.start.vector, path.way1.vector, path.start.moveHullYawDegrees);
    _tank.visible = true;
    _applyTankDeveloperPreviewTransform(
      position: path.start.vector,
      pathPitchDegrees: path.start.hullPitchDegrees,
      pathYawDegrees: startMoveYaw,
      pathRollDegrees: path.start.hullRollDegrees,
      turretYawDegrees: path.start.turretYawDegrees,
      barrelPitchDegrees: path.start.barrelPitchDegrees,
      barrelYawDegrees: path.start.barrelYawDegrees,
    );
    _projectile.visible = false;
    for (final n in _projectileTrail) n.visible = false;
  }

  bool get impactTriggered => _impactTriggered;

  void resetForRematch() {
    _eliminationActive = false;
    _eliminationStartedAt = null;
    _loserIndex = -1;
    _shotTriggered = false;
    _impactTriggered = false;
    _shotStart = vm.Vector3.zero();
    _shotTarget = vm.Vector3.zero();
    final resetPath = _dev.tank.paths[0];
    _tank.visible = false;
    _applyTankDeveloperPreviewTransform(
      position: resetPath.start.vector,
      pathPitchDegrees: resetPath.start.hullPitchDegrees,
      pathYawDegrees: !_dev.tank.autoFacePath
          ? resetPath.start.hullYawDegrees
          : _tankHeading(resetPath.start.vector, resetPath.way1.vector, resetPath.start.moveHullYawDegrees),
      pathRollDegrees: resetPath.start.hullRollDegrees,
      turretYawDegrees: resetPath.start.turretYawDegrees,
      barrelPitchDegrees: resetPath.start.barrelPitchDegrees,
      barrelYawDegrees: resetPath.start.barrelYawDegrees,
    );
    _tankTurret.rotation = vm.Quaternion.identity();
    _projectile.visible = false;
    for (final n in _projectileTrail) n.visible = false;

    for (final player in _players) {
      player.root.visible = true;
      player.pressStartedAt = null;
      _posePlayer(player, press: 0);
    }
    for (var i = 0; i < _chairs.length; i++) {
      _chairs[i].visible = true;
      _stations[i].visible = true;
      if (i < _buttons.length) {
        _buttons[i]
          ..position = vm.Vector3(0, .82, -_layout.deskLead + .10)
          ..scale = vm.Vector3(.23, .10, .23);
      }
    }
    for (final debris in _debris) {
      debris.node.detach();
    }
    _debris.clear();
    setBigScreenState(GuessTimePhase.waiting);
  }

  double _elimSeconds() {
    final started = _eliminationStartedAt;
    if (started == null) return 0;
    return DateTime.now().difference(started).inMicroseconds / 1000000;
  }

  void _updateAnimations() {
    final now = DateTime.now();
    for (var i = 0; i < _players.length; i++) {
      final v = _players[i];
      final started = v.pressStartedAt;
      var press = 0.0;
      if (started != null) {
        final seconds = now.difference(started).inMicroseconds / 1000000.0;
        const down = 0.070;
        const hold = 0.040;
        const up = 0.130;
        final total = down + hold + up;
        if (seconds < down) {
          press = _easeOutCubic(seconds / down);
        } else if (seconds < down + hold) {
          press = 1.0;
        } else if (seconds < total) {
          final releaseT = (seconds - down - hold) / up;
          press = 1.0 - _tankMotionEase(releaseT);
        } else {
          v.pressStartedAt = null;
        }
      }
      _posePlayer(v, press: press);
      if (i < _buttons.length) {
        _buttons[i].scale = vm.Vector3(.18, .08 - .050 * press, .18);
        _buttons[i].position = vm.Vector3(0, .82 - .038 * press, -_layout.deskLead + .10);
      }
    }

    if (_tankDeveloperPathRunning) {
      _updateTankDeveloperPreview();
    } else if (_eliminationActive) {
      _updateElimination();
    }

    for (var i = _debris.length - 1; i >= 0; i--) {
      final d = _debris[i];
      d.life -= .016;
      if (d.life <= 0) {
        d.node.detach();
        _debris.removeAt(i);
        continue;
      }
      d.velocity.y -= 5.2 * .016;
      d.node.position = d.node.position + d.velocity * .016;
      d.node.rotation = d.node.rotation * vm.Quaternion.axisAngle(vm.Vector3(1, .6, .25), .09);
    }
  }

  void _updateElimination() {
    if (_loserIndex < 0 || _loserIndex >= _dev.tank.paths.length) return;
    final path = _dev.tank.paths[_loserIndex];
    final t = _dev.tank;
    final sec = _elimSeconds();

    final dTurnStart = path.turnToWay1Seconds;
    final dMove1 = dTurnStart + path.toWay1Seconds;
    final dTurnWay1 = dMove1 + path.turnToWay2Seconds;
    final dMove2 = dTurnWay1 + path.toWay2Seconds;
    final dTurnWay2 = dMove2 + path.turnToFireSeconds;
    final dMove3 = dTurnWay2 + path.toFireSeconds;
    final dAim1 = dMove3 + path.aim1.seconds;
    final dAim2 = dAim1 + path.aim2.seconds;
    final dAim3 = dAim2 + path.aim3.seconds;
    final dFinalAim = dAim3 + path.finalAim.seconds;
    final dShot = dFinalAim + path.shotTravelSeconds;
    final dHold = dShot + path.holdAfterKillSeconds;
    final dTurnFire = dHold + path.turnToExitSeconds;
    final dMoveExit = dTurnFire + path.toExitSeconds;
    final dTurnExit = dMoveExit + path.turnToEndSeconds;
    final dMoveEnd = dTurnExit + path.toEndSeconds;
    final dFinalEndTurn = dMoveEnd + path.finalEndTurnSeconds;

    vm.Vector3 pos = path.start.vector;
    double hullPitch = t.pitchDegrees;
    double hullYaw = t.yawDegrees;
    double hullRoll = t.rollDegrees;
    double turret = t.turretYawDegrees;
    double barrelPitch = t.barrelPitchDegrees;
    double barrelYaw = t.barrelYawDegrees;
    double segmentProgress = 0;
    bool moving = false;

    double manualOrAutoMoveYaw(_TankPointTuning point, vm.Vector3 toward) {
      if (!t.autoFacePath) return point.moveHullYawDegrees;
      return _tankHeading(point.vector, toward, point.moveHullYawDegrees);
    }

    void exactStop(
      vm.Vector3 at, {
      required double pitch,
      required double yaw,
      required double roll,
      required double turretYaw,
      required double gunPitch,
      required double gunYaw,
    }) {
      pos = at;
      hullPitch = pitch;
      hullYaw = yaw;
      hullRoll = roll;
      turret = turretYaw;
      barrelPitch = gunPitch;
      barrelYaw = gunYaw;
      moving = false;
    }

    void turnInPlace({
      required vm.Vector3 at,
      required double fromPitch,
      required double fromYaw,
      required double fromRoll,
      required double toPitch,
      required double toYaw,
      required double toRoll,
      required double fromTurret,
      required double toTurret,
      required double fromGunPitch,
      required double toGunPitch,
      required double fromGunYaw,
      required double toGunYaw,
      required double k,
    }) {
      final u = _tankMotionEase(k.clamp(0.0, 1.0).toDouble());
      pos = at;
      hullPitch = _tankLerpAngle(fromPitch, toPitch, u);
      hullYaw = _tankLerpAngle(fromYaw, toYaw, u);
      hullRoll = _tankLerpAngle(fromRoll, toRoll, u);
      turret = _tankLerpAngle(fromTurret, toTurret, u);
      barrelPitch = _tankLerpAngle(fromGunPitch, toGunPitch, u);
      barrelYaw = _tankLerpAngle(fromGunYaw, toGunYaw, u);
      segmentProgress = u;
      moving = false;
    }

    void stopThenAlignForMove({
      required vm.Vector3 at,
      required double fromPitch,
      required double fromYaw,
      required double fromRoll,
      required _TankPointTuning point,
      required double moveYaw,
      required double fromTurret,
      required double fromGunPitch,
      required double fromGunYaw,
      required double k,
    }) {
      final q = k.clamp(0.0, 1.0).toDouble();
      if (q <= .55) {
        final local = q / .55;
        turnInPlace(
          at: at,
          fromPitch: fromPitch, fromYaw: fromYaw, fromRoll: fromRoll,
          toPitch: point.hullPitchDegrees, toYaw: point.hullYawDegrees, toRoll: point.hullRollDegrees,
          fromTurret: fromTurret, toTurret: point.turretYawDegrees,
          fromGunPitch: fromGunPitch, toGunPitch: point.barrelPitchDegrees,
          fromGunYaw: fromGunYaw, toGunYaw: point.barrelYawDegrees,
          k: local,
        );
      } else {
        final local = (q - .55) / .45;
        turnInPlace(
          at: at,
          fromPitch: point.hullPitchDegrees, fromYaw: point.hullYawDegrees, fromRoll: point.hullRollDegrees,
          toPitch: point.moveHullPitchDegrees, toYaw: moveYaw, toRoll: point.moveHullRollDegrees,
          fromTurret: point.turretYawDegrees, toTurret: point.turretYawDegrees,
          fromGunPitch: point.barrelPitchDegrees, toGunPitch: point.barrelPitchDegrees,
          fromGunYaw: point.barrelYawDegrees, toGunYaw: point.barrelYawDegrees,
          k: local,
        );
      }
    }

    void moveOnly(
      _TankPointTuning from,
      _TankPointTuning to,
      double k, {
      required double fixedPitch,
      required double fixedYaw,
      required double fixedRoll,
      required double fixedTurret,
      required double fixedGunPitch,
      required double fixedGunYaw,
    }) {
      final u = k.clamp(0.0, 1.0).toDouble();
      segmentProgress = u;
      moving = true;
      pos = _tankLerp(from.vector, to.vector, u);
      hullPitch = fixedPitch;
      hullYaw = fixedYaw;
      hullRoll = fixedRoll;
      turret = fixedTurret;
      barrelPitch = fixedGunPitch;
      barrelYaw = fixedGunYaw;
    }

    final startMoveYaw = manualOrAutoMoveYaw(path.start, path.way1.vector);
    final way1MoveYaw = manualOrAutoMoveYaw(path.way1, path.way2.vector);
    final way2MoveYaw = manualOrAutoMoveYaw(path.way2, path.fire.vector);
    final fireMoveYaw = manualOrAutoMoveYaw(path.fire, path.exit.vector);
    final exitMoveYaw = manualOrAutoMoveYaw(path.exit, path.end.vector);
    final endStopYaw = path.end.hullYawDegrees;

    if (sec < dTurnStart) {
      stopThenAlignForMove(
        at: path.start.vector,
        fromPitch: t.pitchDegrees, fromYaw: t.yawDegrees, fromRoll: t.rollDegrees,
        point: path.start, moveYaw: startMoveYaw,
        fromTurret: t.turretYawDegrees,
        fromGunPitch: t.barrelPitchDegrees, fromGunYaw: t.barrelYawDegrees,
        k: sec / math.max(.001, path.turnToWay1Seconds),
      );
    } else if (sec < dMove1) {
      moveOnly(path.start, path.way1,
          (sec - dTurnStart) / math.max(.001, path.toWay1Seconds),
          fixedPitch: path.start.moveHullPitchDegrees,
          fixedYaw: startMoveYaw,
          fixedRoll: path.start.moveHullRollDegrees,
          fixedTurret: path.start.turretYawDegrees,
          fixedGunPitch: path.start.barrelPitchDegrees,
          fixedGunYaw: path.start.barrelYawDegrees);
    } else if (sec < dTurnWay1) {
      stopThenAlignForMove(
        at: path.way1.vector,
        fromPitch: path.start.moveHullPitchDegrees, fromYaw: startMoveYaw, fromRoll: path.start.moveHullRollDegrees,
        point: path.way1, moveYaw: way1MoveYaw,
        fromTurret: path.start.turretYawDegrees,
        fromGunPitch: path.start.barrelPitchDegrees, fromGunYaw: path.start.barrelYawDegrees,
        k: (sec - dMove1) / math.max(.001, path.turnToWay2Seconds),
      );
    } else if (sec < dMove2) {
      moveOnly(path.way1, path.way2,
          (sec - dTurnWay1) / math.max(.001, path.toWay2Seconds),
          fixedPitch: path.way1.moveHullPitchDegrees,
          fixedYaw: way1MoveYaw,
          fixedRoll: path.way1.moveHullRollDegrees,
          fixedTurret: path.way1.turretYawDegrees,
          fixedGunPitch: path.way1.barrelPitchDegrees,
          fixedGunYaw: path.way1.barrelYawDegrees);
    } else if (sec < dTurnWay2) {
      stopThenAlignForMove(
        at: path.way2.vector,
        fromPitch: path.way1.moveHullPitchDegrees, fromYaw: way1MoveYaw, fromRoll: path.way1.moveHullRollDegrees,
        point: path.way2, moveYaw: way2MoveYaw,
        fromTurret: path.way1.turretYawDegrees,
        fromGunPitch: path.way1.barrelPitchDegrees, fromGunYaw: path.way1.barrelYawDegrees,
        k: (sec - dMove2) / math.max(.001, path.turnToFireSeconds),
      );
    } else if (sec < dMove3) {
      moveOnly(path.way2, path.fire,
          (sec - dTurnWay2) / math.max(.001, path.toFireSeconds),
          fixedPitch: path.way2.moveHullPitchDegrees,
          fixedYaw: way2MoveYaw,
          fixedRoll: path.way2.moveHullRollDegrees,
          fixedTurret: path.way2.turretYawDegrees,
          fixedGunPitch: path.way2.barrelPitchDegrees,
          fixedGunYaw: path.way2.barrelYawDegrees);
    } else if (sec < dAim1) {
      final k = (sec - dMove3) / math.max(.001, path.aim1.seconds);
      exactStop(path.fire.vector,
        pitch: _tankLerpAngle(path.way2.moveHullPitchDegrees, path.fire.hullPitchDegrees, k),
        yaw: _tankLerpAngle(way2MoveYaw, path.fire.hullYawDegrees, k),
        roll: _tankLerpAngle(path.way2.moveHullRollDegrees, path.fire.hullRollDegrees, k),
        turretYaw: _tankLerpAngle(path.fire.turretYawDegrees, path.aim1.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.fire.barrelPitchDegrees, path.aim1.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.fire.barrelYawDegrees, path.aim1.barrelYawDegrees, k));
    } else if (sec < dAim2) {
      final k = (sec - dAim1) / math.max(.001, path.aim2.seconds);
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: _tankLerpAngle(path.aim1.turretYawDegrees, path.aim2.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.aim1.barrelPitchDegrees, path.aim2.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.aim1.barrelYawDegrees, path.aim2.barrelYawDegrees, k));
    } else if (sec < dAim3) {
      final k = (sec - dAim2) / math.max(.001, path.aim3.seconds);
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: _tankLerpAngle(path.aim2.turretYawDegrees, path.aim3.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.aim2.barrelPitchDegrees, path.aim3.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.aim2.barrelYawDegrees, path.aim3.barrelYawDegrees, k));
    } else if (sec < dFinalAim) {
      final k = (sec - dAim3) / math.max(.001, path.finalAim.seconds);
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: _tankLerpAngle(path.aim3.turretYawDegrees, path.finalAim.turretYawDegrees, k),
        gunPitch: _tankLerpAngle(path.aim3.barrelPitchDegrees, path.finalAim.barrelPitchDegrees, k),
        gunYaw: _tankLerpAngle(path.aim3.barrelYawDegrees, path.finalAim.barrelYawDegrees, k));
    } else if (sec < dHold) {
      exactStop(path.fire.vector,
        pitch: path.fire.hullPitchDegrees, yaw: path.fire.hullYawDegrees, roll: path.fire.hullRollDegrees,
        turretYaw: path.finalAim.turretYawDegrees,
        gunPitch: path.finalAim.barrelPitchDegrees,
        gunYaw: path.finalAim.barrelYawDegrees);
    } else if (sec < dTurnFire) {
      turnInPlace(
        at: path.fire.vector,
        fromPitch: path.fire.hullPitchDegrees,
        fromYaw: path.fire.hullYawDegrees,
        fromRoll: path.fire.hullRollDegrees,
        toPitch: path.fire.moveHullPitchDegrees,
        toYaw: fireMoveYaw,
        toRoll: path.fire.moveHullRollDegrees,
        fromTurret: path.finalAim.turretYawDegrees,
        toTurret: path.fire.turretYawDegrees,
        fromGunPitch: path.finalAim.barrelPitchDegrees,
        toGunPitch: path.fire.barrelPitchDegrees,
        fromGunYaw: path.finalAim.barrelYawDegrees,
        toGunYaw: path.fire.barrelYawDegrees,
        k: (sec - dHold) / math.max(.001, path.turnToExitSeconds),
      );
    } else if (sec < dMoveExit) {
      moveOnly(path.fire, path.exit,
          (sec - dTurnFire) / math.max(.001, path.toExitSeconds),
          fixedPitch: path.fire.moveHullPitchDegrees,
          fixedYaw: fireMoveYaw,
          fixedRoll: path.fire.moveHullRollDegrees,
          fixedTurret: path.fire.turretYawDegrees,
          fixedGunPitch: path.fire.barrelPitchDegrees,
          fixedGunYaw: path.fire.barrelYawDegrees);
    } else if (sec < dTurnExit) {
      stopThenAlignForMove(
        at: path.exit.vector,
        fromPitch: path.fire.moveHullPitchDegrees, fromYaw: fireMoveYaw, fromRoll: path.fire.moveHullRollDegrees,
        point: path.exit, moveYaw: exitMoveYaw,
        fromTurret: path.fire.turretYawDegrees,
        fromGunPitch: path.fire.barrelPitchDegrees, fromGunYaw: path.fire.barrelYawDegrees,
        k: (sec - dMoveExit) / math.max(.001, path.turnToEndSeconds),
      );
    } else if (sec < dMoveEnd) {
      moveOnly(path.exit, path.end,
          (sec - dTurnExit) / math.max(.001, path.toEndSeconds),
          fixedPitch: path.exit.moveHullPitchDegrees,
          fixedYaw: exitMoveYaw,
          fixedRoll: path.exit.moveHullRollDegrees,
          fixedTurret: path.exit.turretYawDegrees,
          fixedGunPitch: path.exit.barrelPitchDegrees,
          fixedGunYaw: path.exit.barrelYawDegrees);
    } else if (sec < dFinalEndTurn) {
      turnInPlace(
        at: path.end.vector,
        fromPitch: path.exit.moveHullPitchDegrees,
        fromYaw: exitMoveYaw,
        fromRoll: path.exit.moveHullRollDegrees,
        toPitch: path.end.hullPitchDegrees,
        toYaw: endStopYaw,
        toRoll: path.end.hullRollDegrees,
        fromTurret: path.exit.turretYawDegrees,
        toTurret: path.end.turretYawDegrees,
        fromGunPitch: path.exit.barrelPitchDegrees,
        toGunPitch: path.end.barrelPitchDegrees,
        fromGunYaw: path.exit.barrelYawDegrees,
        toGunYaw: path.end.barrelYawDegrees,
        k: (sec - dMoveEnd) / math.max(.001, path.finalEndTurnSeconds),
      );
    } else {
      exactStop(path.end.vector,
        pitch: path.end.hullPitchDegrees, yaw: endStopYaw, roll: path.end.hullRollDegrees,
        turretYaw: path.end.turretYawDegrees,
        gunPitch: path.end.barrelPitchDegrees,
        gunYaw: path.end.barrelYawDegrees);
      _eliminationActive = false;
    }

    double recoilAmount = 0;
    if (sec >= dFinalAim) {
      final r = sec - dFinalAim;
      final kick = math.max(.001, t.shotRecoilKickSeconds);
      final hold = math.max(0.0, t.shotRecoilHoldSeconds);
      final back = math.max(.001, t.shotRecoilReturnSeconds);
      if (r < kick) {
        recoilAmount = _tankMotionEase(r / kick);
      } else if (r < kick + hold) {
        recoilAmount = 1;
      } else if (r < kick + hold + back) {
        recoilAmount = 1 - _tankMotionEase((r - kick - hold) / back);
      }
    }

    if (recoilAmount > 0) {
      final yawRad = hullYaw * math.pi / 180.0;
      final backward = vm.Vector3(-math.sin(yawRad), 0, math.cos(yawRad));
      pos = pos + backward * (t.shotHullRecoilDistance * recoilAmount);
      hullPitch += t.shotHullPitchDegrees * recoilAmount;
    }

    final suspension = moving
        ? math.sin(_tankMotionEase(segmentProgress) * math.pi) * .010
        : 0.0;
    _applyTankDeveloperPreviewTransform(
      position: pos,
      pathPitchDegrees: hullPitch,
      pathYawDegrees: hullYaw,
      pathRollDegrees: hullRoll,
      turretYawDegrees: turret,
      barrelPitchDegrees: barrelPitch,
      barrelYawDegrees: barrelYaw,
      suspensionY: suspension,
      extraBarrelRecoil: t.shotBarrelRecoilDistance * recoilAmount,
    );

    if (sec >= dFinalAim && !_shotTriggered) {
      _shotTriggered = true;
      _updateProjectileDeveloperMuzzlePreview();
      _shotStart = vm.Vector3.copy(_projectile.position);
      final loser = _stationPosition(_loserIndex);
      _shotTarget = vm.Vector3(loser.x, _roomFloorY + .72, loser.z);
      _projectile
        ..visible = true
        ..position = vm.Vector3.copy(_shotStart);
    }

    if (_shotTriggered && !_impactTriggered) {
      final denom = math.max(.001, path.shotTravelSeconds);
      final shotT = ((sec - dFinalAim) / denom).clamp(0.0, 1.0).toDouble();
      _projectile.position = _shotStart + (_shotTarget - _shotStart) * _easeOutCubic(shotT);
      final spinSeconds = math.max(.001, path.shotTravelSeconds) * shotT;
      _projectileModel.rotation = vm.Quaternion.euler(
        vm.radians(_dev.projectile.pitchDegrees + _dev.projectile.spinX * spinSeconds),
        vm.radians(_dev.projectile.yawDegrees + _dev.projectile.spinY * spinSeconds),
        vm.radians(_dev.projectile.rollDegrees + _dev.projectile.spinZ * spinSeconds),
      );
      final pulse = 1.0 + math.sin(shotT * math.pi * 10) * .08;
      _projectileGlowInner.scale = vm.Vector3.all(_dev.projectile.glowInnerSize * pulse);
      _projectileGlowOuter.scale = vm.Vector3.all(_dev.projectile.glowOuterSize * (2.0 - pulse));
      _updateProjectileTrail(_shotStart, _shotTarget, shotT);
      if (shotT >= 1) {
        _projectile.visible = false;
        for (final n in _projectileTrail) n.visible = false;
        _explodeLoser();
      }
    }
  }

  double _ease(double t) => 1 - math.pow(1 - t, 3).toDouble();

  void _explodeLoser() {
    if (_impactTriggered) return;
    _impactTriggered = true;
    _projectile.visible = false;
    for (final n in _projectileTrail) n.visible = false;

    if (_loserIndex < _players.length) _players[_loserIndex].root.visible = false;
    if (_loserIndex < _chairs.length) _chairs[_loserIndex].visible = false;
    if (_loserIndex < _stations.length) _stations[_loserIndex].visible = false;

    final loserWorld = _stationPosition(_loserIndex);
    final origin = vm.Vector3(loserWorld.x, _roomFloorY + .62, loserWorld.z);
    for (var i = 0; i < 34; i++) {
      final node = _mesh(
        i % 3 == 0 ? _geo.explosion : _geo.debris,
        i % 3 == 0 ? _explosionMaterial : _pbr(const Color(0xFF31373B), roughness: .7, metallic: .2),
        position: origin + vm.Vector3(
          (_random.nextDouble() - .5) * .38,
          (_random.nextDouble() - .5) * .28,
          (_random.nextDouble() - .5) * .38,
        ),
        scale: vm.Vector3.all(.08 + _random.nextDouble() * .22),
      )..castsShadows = false;
      scene.add(node);
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = .8 + _random.nextDouble() * 3.4;
      _debris.add(_Debris(
        node: node,
        velocity: vm.Vector3(math.cos(angle) * speed, 1.4 + _random.nextDouble() * 2.8, math.sin(angle) * speed),
        life: .8 + _random.nextDouble() * 1.7,
      ));
    }
  }

  void _buildLayoutDebug() {
    final red = _unlit(const Color(0xFFFF3B30));
    final green = _unlit(const Color(0xFF34C759));
    final blue = _unlit(const Color(0xFF0A84FF));
    final yellow = _unlit(const Color(0xFFFFD60A));

    scene.add(_mesh(_geo.projectile, yellow,
        name: 'debug_screens_center', position: _layout.screensCenter, scale: vm.Vector3.all(.08)));
    _addDebugLine(_layout.screensCenter, _layout.screensCenter + _layout.front * .9, red, 'debug_screen_front');

    for (var i = 0; i < 4; i++) {
      final station = _stationPosition(i) + vm.Vector3(0, .06, 0);
      scene.add(_mesh(_geo.projectile, green,
          name: 'debug_station_${i + 1}', position: station, scale: vm.Vector3.all(.07)));
      _addDebugLine(station, _layout.screensCenter, blue, 'debug_station_to_center_${i + 1}');
      final yaw = _stationYaw(i);
      final forward = _rotateLocalY(vm.Vector3(0, 0, -1), yaw);
      _addDebugLine(station, station + forward * .7, green, 'debug_chair_forward_${i + 1}');
    }

    for (var i = 0; i < _screenSpecs.length; i++) {
      final spec = _screenSpecs[i];
      final marker = spec.center + spec.normal * .025;
      scene.add(_mesh(_geo.projectile, yellow,
          name: 'debug_screen_number_${i + 1}', position: marker, scale: vm.Vector3.all(.035)));
    }
  }

  void _addDebugLine(vm.Vector3 a, vm.Vector3 b, Material material, String name) {
    final delta = b - a;
    final length = delta.length;
    if (length <= .0001) return;
    final mid = (a + b) * .5;
    final dir = delta / length;
    final yaw = math.atan2(dir.x, dir.z);
    final pitch = -math.asin(dir.y.clamp(-1.0, 1.0));
    final q = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitch);
    scene.add(_mesh(_geo.unitCube, material,
        name: name, position: mid, scale: vm.Vector3(.018, .018, length), rotation: q));
  }


  vm.Quaternion _developerMapRotation() {
    final yaw = _dev.mapYawDegrees * math.pi / 180.0;
    final pitch = _dev.mapPitchDegrees * math.pi / 180.0;
    final roll = _dev.mapRollDegrees * math.pi / 180.0;
    return vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitch) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), roll);
  }

  void _applyDeveloperMapTransform() {

    // IMPORTANT: _roomRig contains ONLY surveillance_room.glb, including its
    // REAL Lumires screen faces. Their gameplay materials therefore move/rotate
    // with the room automatically. Chairs, players, desks, buttons, big result
    // screen, tank and every other game object stay in world space.
    _roomRig
      ..position = vm.Vector3(_dev.mapX, _dev.mapY, _dev.mapZ)
      ..rotation = _developerMapRotation();
  }

  void _resetDeveloperCameraToDefaultView() {
    final position = _layout.cameraPosition;
    final direction = _layout.cameraTarget - position;
    final flat = math.sqrt(direction.x * direction.x + direction.z * direction.z);
    _dev
      ..cameraX = position.x
      ..cameraY = position.y
      ..cameraZ = position.z
      ..cameraYawDegrees = math.atan2(direction.x, -direction.z) * 180.0 / math.pi
      ..cameraPitchDegrees = math.atan2(direction.y, flat) * 180.0 / math.pi
      ..cameraFovDegrees = 72;
  }

  vm.Vector3 _developerCameraPosition() =>
      vm.Vector3(_dev.cameraX, _dev.cameraY, _dev.cameraZ);

  vm.Vector3 _developerCameraForward() {
    final yaw = _dev.cameraYawDegrees * math.pi / 180.0;
    final pitch = _dev.cameraPitchDegrees * math.pi / 180.0;
    final cp = math.cos(pitch);
    return vm.Vector3(
      math.sin(yaw) * cp,
      math.sin(pitch),
      -math.cos(yaw) * cp,
    )..normalize();
  }

  vm.Vector3 _developerCameraFlatForward() {
    final yaw = _dev.cameraYawDegrees * math.pi / 180.0;
    return vm.Vector3(math.sin(yaw), 0, -math.cos(yaw))..normalize();
  }

  vm.Vector3 _developerCameraRight() {
    final forward = _developerCameraFlatForward();
    return vm.Vector3(-forward.z, 0, forward.x)..normalize();
  }

  void _moveDeveloperCamera({double forward = 0, double right = 0, double up = 0}) {
    final p = _developerCameraPosition() +
        _developerCameraFlatForward() * forward +
        _developerCameraRight() * right +
        vm.Vector3(0, up, 0);
    _dev
      ..cameraX = p.x
      ..cameraY = p.y
      ..cameraZ = p.z;
  }

  PerspectiveCamera _developerFreeCamera() {
    final position = _developerCameraPosition();
    final forward = _developerCameraForward();
    final fov = _dev.cameraFovDegrees.clamp(5.0, 170.0).toDouble();
    return PerspectiveCamera(
      position: position,
      target: position + forward,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: fov * math.pi / 180.0,
      fovNear: .025,
      fovFar: 180,
    );
  }

  String _developerMapSettingsText() {
    return [
      'GUESS_TIME_MAP_ONLY',
      'MAP x=${_dev.mapX.toStringAsFixed(4)} y=${_dev.mapY.toStringAsFixed(4)} z=${_dev.mapZ.toStringAsFixed(4)}',
      'MAP_ROT pitch=${_dev.mapPitchDegrees.toStringAsFixed(3)} yaw=${_dev.mapYawDegrees.toStringAsFixed(3)} roll=${_dev.mapRollDegrees.toStringAsFixed(3)}',
    ].join('\n');
  }

  String _developerStationsSettingsText() {
    final lines = <String>['GUESS_TIME_STATIONS'];
    for (var i = 0; i < _dev.stations.length; i++) {
      final s = _dev.stations[i];
      lines.add(
        'PLAYER_${i + 1} x=${s.x.toStringAsFixed(4)} y=${s.y.toStringAsFixed(4)} z=${s.z.toStringAsFixed(4)} '
        'pitch=${s.pitchDegrees.toStringAsFixed(3)} yaw=${s.yawDegrees.toStringAsFixed(3)} roll=${s.rollDegrees.toStringAsFixed(3)} '
        'camX=${s.cameraX.toStringAsFixed(4)} camY=${s.cameraY.toStringAsFixed(4)} camZ=${s.cameraZ.toStringAsFixed(4)} '
        'camYaw=${s.cameraYawDegrees.toStringAsFixed(3)} camPitch=${s.cameraPitchDegrees.toStringAsFixed(3)} camFov=${s.cameraFovDegrees.toStringAsFixed(3)}',
      );
    }
    return lines.join('\n');
  }


  String _developerPlayerPosesSettingsText() {
    final lines = <String>['GUESS_TIME_PLAYER_POSES'];
    for (var i = 0; i < _dev.poses.length; i++) {
      final p = _dev.poses[i];
      String v(_EulerTuning e) => '${e.xDegrees.toStringAsFixed(3)},${e.yDegrees.toStringAsFixed(3)},${e.zDegrees.toStringAsFixed(3)}';
      lines.add(
        'POSE_${i + 1} x=${p.x.toStringAsFixed(4)} y=${p.y.toStringAsFixed(4)} z=${p.z.toStringAsFixed(4)} '
        'pitch=${p.pitchDegrees.toStringAsFixed(3)} yaw=${p.yawDegrees.toStringAsFixed(3)} roll=${p.rollDegrees.toStringAsFixed(3)} '
        'scale=${p.scale.toStringAsFixed(3)} '
        'body=${p.bodyX.toStringAsFixed(4)},${p.bodyY.toStringAsFixed(4)},${p.bodyZ.toStringAsFixed(4)} '
        'hips=${v(p.hips)} spine=${v(p.spine)} spine1=${v(p.spine1)} neck=${v(p.neck)} head=${v(p.head)} '
        'LShoulder=${v(p.leftShoulder)} LArm=${v(p.leftArm)} LForeArm=${v(p.leftForeArm)} LHand=${v(p.leftHand)} '
        'RShoulder=${v(p.rightShoulder)} RArm=${v(p.rightArm)} RForeArm=${v(p.rightForeArm)} RHand=${v(p.rightHand)} '
        'LThigh=${v(p.leftUpLeg)} LLeg=${v(p.leftLeg)} LFoot=${v(p.leftFoot)} '
        'RThigh=${v(p.rightUpLeg)} RLeg=${v(p.rightLeg)} RFoot=${v(p.rightFoot)}',
      );
    }
    return lines.join('\n');
  }

  String _developerSettingsText() {
    final cameraWorld = _developerCameraPosition();
    return [
      _tankDeveloperSettingsText(),
      '-------------------------------',
      _developerStationsSettingsText(),
      '-------------------------------',
      _developerPlayerPosesSettingsText(),
      '-------------------------------',
      _developerMapSettingsText(),
      'CAM_WORLD x=${cameraWorld.x.toStringAsFixed(4)} y=${cameraWorld.y.toStringAsFixed(4)} z=${cameraWorld.z.toStringAsFixed(4)}',
      'CAM_LOOK yaw=${_dev.cameraYawDegrees.toStringAsFixed(3)} pitch=${_dev.cameraPitchDegrees.toStringAsFixed(3)} fov=${_dev.cameraFovDegrees.toStringAsFixed(3)}',
    ].join('\n');
  }

  void _scheduleDeveloperOverlayAttach() {
    if (!(developerMode || stationDeveloperMode || tankDeveloperMode) || _developerOverlayEntry != null) return;
    ui.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(developerMode || stationDeveloperMode || tankDeveloperMode) || _developerOverlayEntry != null) return;
      final root = ui.WidgetsBinding.instance.rootElement;
      if (root == null) return;
      final overlay = _findDeveloperOverlay(root);
      if (overlay != null && overlay.mounted) {
        final entry = ui.OverlayEntry(
          builder: (_) => _GuessTimeDeveloperOverlay(world: this),
        );
        _developerOverlayEntry = entry;
        overlay.insert(entry);
        return;
      }

      if (_developerOverlayAttachAttempts < 12) {
        _developerOverlayAttachAttempts++;
        Future<void>.delayed(
          const Duration(milliseconds: 120),
          _scheduleDeveloperOverlayAttach,
        );
      }
    });
  }

  ui.OverlayState? _findDeveloperOverlay(ui.Element root) {
    ui.OverlayState? result;
    void visit(ui.Element element) {
      if (result == null &&
          element is ui.StatefulElement &&
          element.state is ui.OverlayState) {
        result = element.state as ui.OverlayState;
      }
      element.visitChildElements(visit);
    }

    visit(root);
    return result;
  }

  void _removeDeveloperOverlay() {
    final entry = _developerOverlayEntry;
    _developerOverlayEntry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  PerspectiveCamera cameraFor({required GuessTimePhase phase}) {
    _lastCameraFrame = DateTime.now();
    _updateAnimations();
    return _cameraForRaw(phase);
  }

  PerspectiveCamera _cameraForRaw(GuessTimePhase phase) {
    if (developerMode || (layoutDeveloperMode && _developerFreeCameraEnabled)) {
      return _developerFreeCamera();
    }
    return _firstPersonCamera();
  }

  bool get developerFreeCameraEnabled => _developerFreeCameraEnabled;
  double get developerCameraKeyboardStep => _dev.flyStep;
  bool get runtimeDeveloperModeEnabled => layoutDeveloperMode;

  void setRuntimeDeveloperMode(bool enabled) {
    _runtimeDeveloperMode = enabled;
    if (!enabled) {
      _developerFreeCameraEnabled = false;
      _removeDeveloperOverlay();
      if (ready && !_eliminationActive) _tank.visible = false;
      if (_projectileBuilt && !_shotTriggered) {
        _projectile.visible = false;
        for (final n in _projectileTrail) n.visible = false;
      }
      _refreshTankPartMarkers();
      _refreshTankDeveloperMarkers();
    } else if (ready) {
      _tank.visible = true;
      _lastCameraFrame = DateTime.now();
      _refreshTankPartMarkers();
      _refreshTankDeveloperMarkers();
      _updateProjectileDeveloperMuzzlePreview();
      _scheduleDeveloperOverlayAttach();
    }
  }

  void toggleDeveloperFreeCameraFromKeyboard() {
    if (!layoutDeveloperMode) return;
    _setDeveloperFreeCameraEnabled(!_developerFreeCameraEnabled);
    _developerOverlayEntry?.markNeedsBuild();
  }

  void moveDeveloperFreeCameraFromKeyboard({
    double forward = 0,
    double right = 0,
    double up = 0,
  }) {
    if (!layoutDeveloperMode || !_developerFreeCameraEnabled) return;
    _moveDeveloperCamera(forward: forward, right: right, up: up);
    _developerOverlayEntry?.markNeedsBuild();
  }

  void playSelectedTankDeveloperPathFromKeyboard() {
    if (!layoutDeveloperMode) return;
    _resetTankDeveloperPath(_tankDeveloperTarget);
    _startTankDeveloperPath(_tankDeveloperTarget);
    _developerOverlayEntry?.markNeedsBuild();
  }
  int get developerSelectedStation => _developerSelectedStation;

  void _selectDeveloperStation(int index) {
    _developerSelectedStation = index.clamp(0, 3).toInt();
    if (_developerFreeCameraEnabled) return;
    setViewerIndex(_developerSelectedStation);
    resetLook();
  }

  vm.Vector3 _stationDeveloperEyeLocal(int index) {
    final s = _dev.stations[index.clamp(0, 3).toInt()];
    return vm.Vector3(
      s.cameraX,
      1.10 + s.cameraY,
      -.19 + s.cameraZ,
    );
  }

  double _stationDeveloperYawRadians(int index) =>
      _dev.stations[index.clamp(0, 3).toInt()].cameraYawDegrees * math.pi / 180.0;

  double _stationDeveloperPitchRadians(int index) =>
      _dev.stations[index.clamp(0, 3).toInt()].cameraPitchDegrees * math.pi / 180.0;

  vm.Vector3 _stationDeveloperForwardWorld(int index) {
    final yaw = _lookYaw + _stationDeveloperYawRadians(index);
    final pitch = (_lookPitch + _stationDeveloperPitchRadians(index))
        .clamp(-1.50, 1.50)
        .toDouble();
    final cp = math.cos(pitch);
    final localDirection = vm.Vector3(
      math.sin(yaw) * cp,
      math.sin(pitch),
      -math.cos(yaw) * cp,
    );
    return _rotateStationLocal(index, localDirection)..normalize();
  }

  void _seedFreeCameraFromStation(int index) {
    final safe = index.clamp(0, 3).toInt();
    final eye = _stationLocalToWorld(safe, _stationDeveloperEyeLocal(safe));
    final forward = _stationDeveloperForwardWorld(safe);
    final flat = math.sqrt(forward.x * forward.x + forward.z * forward.z);
    final station = _dev.stations[safe];
    _dev
      ..cameraX = eye.x
      ..cameraY = eye.y
      ..cameraZ = eye.z
      ..cameraYawDegrees = math.atan2(forward.x, -forward.z) * 180.0 / math.pi
      ..cameraPitchDegrees = math.atan2(forward.y, flat) * 180.0 / math.pi
      ..cameraFovDegrees = station.cameraFovDegrees;
  }

  void _setDeveloperFreeCameraEnabled(bool enabled) {
    if (_developerFreeCameraEnabled == enabled) return;
    if (enabled) {
      _seedFreeCameraFromStation(_developerSelectedStation);
      _developerFreeCameraEnabled = true;
      return;
    }
    _developerFreeCameraEnabled = false;
    setViewerIndex(_developerSelectedStation);
    resetLook();
  }

  void setViewerIndex(int index) {
    if (_stations.isEmpty) {
      _viewerIndex = 0;
      return;
    }
    _viewerIndex = index.clamp(0, _stations.length - 1);
    _refreshFirstPersonSelfVisibility();
  }

  void _refreshFirstPersonSelfVisibility() {
    for (var i = 0; i < _players.length; i++) {
      final visual = _players[i];
      // Restore the authored avatar selection first.
      _applyAvatar(visual.model, visual.avatar);
      if (i != _viewerIndex) continue;

      // The local player's head accessories must never cross the near plane
      // while looking around. Keep torso/arms/legs visible so looking down still
      // shows the player's own body and hands naturally.
      final hideNames = <String>{
        visual.avatar.face,
        if (visual.avatar.hair != null) visual.avatar.hair!,
        if (visual.avatar.hat != null) visual.avatar.hat!,
        if (visual.avatar.glasses != null) visual.avatar.glasses!,
        if (visual.avatar.faceAccessory != null) visual.avatar.faceAccessory!,
      };
      for (final name in hideNames) {
        visual.model.getChildByName(name)?.visible = false;
      }
    }
  }

  void lookByDragDelta(Offset delta) {
    if (layoutDeveloperMode && _developerFreeCameraEnabled) {
      _dev.cameraYawDegrees += delta.dx * .22;
      _dev.cameraPitchDegrees =
          (_dev.cameraPitchDegrees - delta.dy * .22)
              .clamp(-89.5, 89.5)
              .toDouble();
      return;
    }

    // Update a target, not the camera directly. cameraFor() eases toward this
    // target so touch/mouse movement stays fluid instead of stepping framewise.
    const yawSensitivity = .0042;
    const pitchSensitivity = .0038;
    _lookYawTarget = (_lookYawTarget - delta.dx * yawSensitivity)
        .clamp(-1.18, 1.18)
        .toDouble();
    _lookPitchTarget = (_lookPitchTarget - delta.dy * pitchSensitivity)
        .clamp(-1.00, .68)
        .toDouble();
  }

  void resetLook() {
    _lookYaw = 0;
    _lookPitch = 0;
    _lookYawTarget = 0;
    _lookPitchTarget = 0;
  }

  PerspectiveCamera _firstPersonCamera() {
    final index = _stations.isEmpty
        ? 0
        : _viewerIndex.clamp(0, _stations.length - 1);
    _lookYaw += (_lookYawTarget - _lookYaw) * .42;
    _lookPitch += (_lookPitchTarget - _lookPitch) * .42;

    // Eye sits just in front of the face. The local face/hair are hidden above,
    // while torso, arms and legs stay visible when looking down.
    final eye = _stationLocalToWorld(index, _stationDeveloperEyeLocal(index));
    final worldDirection = _stationDeveloperForwardWorld(index);
    final target = eye + worldDirection * 12.0;
    return PerspectiveCamera(
      position: eye,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: _dev.stations[index].cameraFovDegrees.clamp(40.0, 105.0).toDouble() * math.pi / 180,
      fovNear: .045,
      fovFar: 120,
    );
  }

  Offset? projectButton(int index, Size size, GuessTimePhase phase) {
    if (index < 0 || index >= _buttonPositions.length) return null;
    return _cameraForRaw(phase).worldToScreen(_buttonPositions[index], size);
  }

  vm.Vector3 _authoredRoomPointToWorld(vm.Vector3 point) {
    // point is expressed in the original GLB coordinate system. _room is the
    // runtime-imported root, so its globalTransform includes BOTH the developer
    // map transform and flutter_scene's GLB handedness conversion. Using _roomRig
    // alone would omit that conversion and project the old 2D labels beside the
    // real monitors after the map is rotated.
    return _room.globalTransform.transform3(vm.Vector3.copy(point));
  }

  Offset? projectScreen(int index, Size size, GuessTimePhase phase) {
    if (index < 0 || index >= _screenSpecs.length) return null;
    return _cameraForRaw(phase).worldToScreen(
      _authoredRoomPointToWorld(_screenSpecs[index].center),
      size,
    );
  }

  Offset? projectStationDisplay(int index, Size size, GuessTimePhase phase) {
    if (index < 0 || index >= _stationDisplayPositions.length) return null;
    return _cameraForRaw(phase).worldToScreen(_stationDisplayPositions[index], size);
  }

  Offset? projectBigScreen(Size size, GuessTimePhase phase) {
    return _cameraForRaw(phase).worldToScreen(
      _bigScreen.globalTransform.getTranslation(),
      size,
    );
  }
}

class _RoomLayout {
  _RoomLayout({
    required this.screensCenter,
    required this.front,
    required this.right,
    required this.wallWidth,
    required this.wallHeight,
    required this.rowCenter,
    required this.deskCenter,
    required this.stationSpacing,
    required this.deskLead,
    required this.cameraPosition,
    required this.cameraTarget,
  });

  final vm.Vector3 screensCenter;
  final vm.Vector3 front;
  final vm.Vector3 right;
  final double wallWidth;
  final double wallHeight;
  final vm.Vector3 rowCenter;
  final vm.Vector3 deskCenter;
  final double stationSpacing;
  final double deskLead;
  final vm.Vector3 cameraPosition;
  final vm.Vector3 cameraTarget;
}

class _ScreenSpec {
  _ScreenSpec(this.center, this.right, this.up, this.normal, this.width, this.height);
  final vm.Vector3 center;
  final vm.Vector3 right;
  final vm.Vector3 up;
  final vm.Vector3 normal;
  final double width;
  final double height;
}

class _PlayerVisual {
  _PlayerVisual({
    required this.index,
    required this.root,
    required this.bodyRoot,
    required this.model,
    required this.avatar,
    required this.bones,
    required this.base,
  });

  final int index;
  final Node root;
  final Node bodyRoot;
  final Node model;
  final KillerKilledAvatar avatar;
  final Map<String, Node> bones;
  final Map<String, vm.Quaternion> base;
  DateTime? pressStartedAt;
  double gazeYaw = 0;
  double gazePitch = 0;
}

class _Debris {
  _Debris({required this.node, required this.velocity, required this.life});
  final Node node;
  final vm.Vector3 velocity;
  double life;
}

class _GuessGeometryBank {
  _GuessGeometryBank()
      : unitCube = CuboidGeometry(vm.Vector3.all(1)),
        screen = CuboidGeometry(vm.Vector3.all(1)),
        displayPlane = PlaneGeometry(width: 1, depth: 1),
        skySphere = IcosphereGeometry(radius: .5, subdivisions: 3),
        button = IcosphereGeometry(radius: .5, subdivisions: 2),
        projectile = IcosphereGeometry(radius: .5, subdivisions: 2),
        explosion = IcosphereGeometry(radius: .5, subdivisions: 1),
        debris = CuboidGeometry(vm.Vector3.all(1));

  final Geometry unitCube;
  final Geometry screen;
  final Geometry displayPlane;
  final Geometry skySphere;
  final Geometry button;
  final Geometry projectile;
  final Geometry explosion;
  final Geometry debris;
}


class _EulerTuning {
  double xDegrees = 0;
  double yDegrees = 0;
  double zDegrees = 0;
  double _defaultX = 0;
  double _defaultY = 0;
  double _defaultZ = 0;

  void set(double x, double y, double z) {
    xDegrees = x;
    yDegrees = y;
    zDegrees = z;
  }

  void captureDefaults() {
    _defaultX = xDegrees;
    _defaultY = yDegrees;
    _defaultZ = zDegrees;
  }

  void resetToDefaults() {
    xDegrees = _defaultX;
    yDegrees = _defaultY;
    zDegrees = _defaultZ;
  }
}

class _PlayerPoseTuning {
  double x = 0;
  double y = .02;
  double z = 0;
  double pitchDegrees = 0;
  double yawDegrees = 0;
  double rollDegrees = 0;
  double scale = .96;
  double bodyX = 0;
  double bodyY = -.34;
  double bodyZ = .05;

  final _EulerTuning hips = _EulerTuning();
  final _EulerTuning spine = _EulerTuning();
  final _EulerTuning spine1 = _EulerTuning();
  final _EulerTuning neck = _EulerTuning();
  final _EulerTuning head = _EulerTuning();
  final _EulerTuning leftShoulder = _EulerTuning();
  final _EulerTuning rightShoulder = _EulerTuning();
  final _EulerTuning leftArm = _EulerTuning();
  final _EulerTuning rightArm = _EulerTuning();
  final _EulerTuning leftForeArm = _EulerTuning();
  final _EulerTuning rightForeArm = _EulerTuning();
  final _EulerTuning leftHand = _EulerTuning();
  final _EulerTuning rightHand = _EulerTuning();
  final _EulerTuning leftUpLeg = _EulerTuning();
  final _EulerTuning rightUpLeg = _EulerTuning();
  final _EulerTuning leftLeg = _EulerTuning();
  final _EulerTuning rightLeg = _EulerTuning();
  final _EulerTuning leftFoot = _EulerTuning();
  final _EulerTuning rightFoot = _EulerTuning();

  double _defaultX = 0;
  double _defaultY = .02;
  double _defaultZ = 0;
  double _defaultPitch = 0;
  double _defaultYaw = 0;
  double _defaultRoll = 0;
  double _defaultScale = .96;
  double _defaultBodyX = 0;
  double _defaultBodyY = -.34;
  double _defaultBodyZ = .05;

  Iterable<_EulerTuning> get _all => [hips, spine, spine1, neck, head, leftShoulder, rightShoulder, leftArm, rightArm, leftForeArm, rightForeArm, leftHand, rightHand, leftUpLeg, rightUpLeg, leftLeg, rightLeg, leftFoot, rightFoot];

  void captureDefaults() {
    _defaultX = x;
    _defaultY = y;
    _defaultZ = z;
    _defaultPitch = pitchDegrees;
    _defaultYaw = yawDegrees;
    _defaultRoll = rollDegrees;
    _defaultScale = scale;
    _defaultBodyX = bodyX;
    _defaultBodyY = bodyY;
    _defaultBodyZ = bodyZ;
    for (final e in _all) e.captureDefaults();
  }

  void resetToDefaults() {
    x = _defaultX;
    y = _defaultY;
    z = _defaultZ;
    pitchDegrees = _defaultPitch;
    yawDegrees = _defaultYaw;
    rollDegrees = _defaultRoll;
    scale = _defaultScale;
    bodyX = _defaultBodyX;
    bodyY = _defaultBodyY;
    bodyZ = _defaultBodyZ;
    for (final e in _all) e.resetToDefaults();
  }
}


class _TankPointTuning {
  double x = 0;
  double y = 0;
  double z = 0;
  // In manual mode these are exact absolute rotations and preview == playback.
  // Auto-face mode derives yaw from travel direction and treats hullYaw as an
  // offset; model-forward correction is applied only in _tankHeading().
  double hullPitchDegrees = 0;
  double hullYawDegrees = 0;
  double hullRollDegrees = 0;
  // Independent body rotation while travelling OUT of this point.
  // STOP rotation above and MOVE rotation below are intentionally separate.
  double moveHullPitchDegrees = 0;
  double moveHullYawDegrees = 0;
  double moveHullRollDegrees = 0;
  double turretYawDegrees = 0;
  double barrelPitchDegrees = 0;
  double barrelYawDegrees = 0;

  double _dx = 0, _dy = 0, _dz = 0;
  double _dHullPitch = 0, _dHullYaw = 0, _dHullRoll = 0;
  double _dMoveHullPitch = 0, _dMoveHullYaw = 0, _dMoveHullRoll = 0;
  double _dTurretYaw = 0, _dBarrelPitch = 0, _dBarrelYaw = 0;

  vm.Vector3 get vector => vm.Vector3(x, y, z);
  void setVector(vm.Vector3 v) { x = v.x; y = v.y; z = v.z; }
  void captureDefaults() {
    _dx = x; _dy = y; _dz = z;
    _dHullPitch = hullPitchDegrees;
    _dHullYaw = hullYawDegrees;
    _dHullRoll = hullRollDegrees;
    _dMoveHullPitch = moveHullPitchDegrees;
    _dMoveHullYaw = moveHullYawDegrees;
    _dMoveHullRoll = moveHullRollDegrees;
    _dTurretYaw = turretYawDegrees;
    _dBarrelPitch = barrelPitchDegrees;
    _dBarrelYaw = barrelYawDegrees;
  }
  void resetToDefaults() {
    x = _dx; y = _dy; z = _dz;
    hullPitchDegrees = _dHullPitch;
    hullYawDegrees = _dHullYaw;
    hullRollDegrees = _dHullRoll;
    moveHullPitchDegrees = _dMoveHullPitch;
    moveHullYawDegrees = _dMoveHullYaw;
    moveHullRollDegrees = _dMoveHullRoll;
    turretYawDegrees = _dTurretYaw;
    barrelPitchDegrees = _dBarrelPitch;
    barrelYawDegrees = _dBarrelYaw;
  }
}

class _TankAimStageTuning {
  double turretYawDegrees = 0;
  double barrelPitchDegrees = 0;
  double barrelYawDegrees = 0;
  double seconds = .30;
  double _dTurretYaw = 0, _dBarrelPitch = 0, _dBarrelYaw = 0, _dSeconds = .30;
  void captureDefaults() {
    _dTurretYaw = turretYawDegrees;
    _dBarrelPitch = barrelPitchDegrees;
    _dBarrelYaw = barrelYawDegrees;
    _dSeconds = seconds;
  }
  void resetToDefaults() {
    turretYawDegrees = _dTurretYaw;
    barrelPitchDegrees = _dBarrelPitch;
    barrelYawDegrees = _dBarrelYaw;
    seconds = _dSeconds;
  }
}

class _TankPathTuning {
  final start = _TankPointTuning();
  final way1 = _TankPointTuning();
  final way2 = _TankPointTuning();
  final fire = _TankPointTuning();
  final exit = _TankPointTuning();
  final end = _TankPointTuning();

  final aim1 = _TankAimStageTuning();
  final aim2 = _TankAimStageTuning();
  final aim3 = _TankAimStageTuning();
  final finalAim = _TankAimStageTuning();

  double turnToWay1Seconds = .35;
  double toWay1Seconds = 1.45;
  double turnToWay2Seconds = .35;
  double toWay2Seconds = 1.45;
  double turnToFireSeconds = .35;
  double toFireSeconds = 1.35;
  double shotTravelSeconds = .58;
  double holdAfterKillSeconds = .85;
  double turnToExitSeconds = .35;
  double toExitSeconds = 1.55;
  double turnToEndSeconds = .35;
  double toEndSeconds = 1.45;
  // Final in-place rotation after the tank reaches END. There is no movement
  // after it; this exists because every stop must have its own independent turn.
  double finalEndTurnSeconds = .35;
  late List<double> _timingDefaults;

  Iterable<_TankPointTuning> get points => [start, way1, way2, fire, exit, end];
  Iterable<_TankAimStageTuning> get aims => [aim1, aim2, aim3, finalAim];

  void captureDefaults() {
    for (final p in points) p.captureDefaults();
    for (final a in aims) a.captureDefaults();
    _timingDefaults = [
      turnToWay1Seconds,
      toWay1Seconds,
      turnToWay2Seconds,
      toWay2Seconds,
      turnToFireSeconds,
      toFireSeconds,
      shotTravelSeconds,
      holdAfterKillSeconds,
      turnToExitSeconds,
      toExitSeconds,
      turnToEndSeconds,
      toEndSeconds,
      finalEndTurnSeconds,
    ];
  }

  void resetToDefaults() {
    for (final p in points) p.resetToDefaults();
    for (final a in aims) a.resetToDefaults();
    final t = _timingDefaults;
    turnToWay1Seconds = t[0];
    toWay1Seconds = t[1];
    turnToWay2Seconds = t[2];
    toWay2Seconds = t[3];
    turnToFireSeconds = t[4];
    toFireSeconds = t[5];
    shotTravelSeconds = t[6];
    holdAfterKillSeconds = t[7];
    turnToExitSeconds = t[8];
    toExitSeconds = t[9];
    turnToEndSeconds = t[10];
    toEndSeconds = t[11];
    finalEndTurnSeconds = t[12];
  }
}

class _TankDeveloperTuning {
  bool initialized = false;
  double x = 0, y = 0, z = 0;
  double pitchDegrees = -90, yawDegrees = 0, rollDegrees = 0;
  double scaleX = .0086, scaleY = .0086, scaleZ = .0086;

  // Turret placement vs pivot are intentionally separate. Position moves the
  // visible turret; Pivot moves only the rotation center while compensating the
  // mesh so artists can tune both independently.
  double turretX = 0, turretY = 0, turretZ = 0;
  double turretPivotX = 0, turretPivotY = 0, turretPivotZ = 0;
  double turretPitchDegrees = 0, turretYawDegrees = 0, turretRollDegrees = 0;
  double turretScaleX = 1, turretScaleY = 1, turretScaleZ = 1;

  double barrelX = 0, barrelY = 0, barrelZ = 0;
  double barrelPivotX = 0, barrelPivotY = 0, barrelPivotZ = 0;
  double barrelPitchDegrees = 0, barrelYawDegrees = 0, barrelRollDegrees = 0;
  double barrelScaleX = 1, barrelScaleY = 1, barrelScaleZ = 1;
  double barrelRecoil = 0;

  double muzzleX = .043, muzzleY = 121.48, muzzleZ = 0;
  bool autoFacePath = true;
  bool showMarkers = true;
  bool showPartMarkers = true;

  double shotHullRecoilDistance = .14;
  double shotHullPitchDegrees = 1.20;
  double shotBarrelRecoilDistance = 8.0;
  double shotRecoilKickSeconds = .10;
  double shotRecoilHoldSeconds = .05;
  double shotRecoilReturnSeconds = .26;

  final paths = List<_TankPathTuning>.generate(4, (_) => _TankPathTuning());
  late List<double> _defaults;
  late List<double> _turretDefaults;
  late List<double> _barrelDefaults;

  void captureDefaults() {
    _turretDefaults = [
      turretX,turretY,turretZ,
      turretPivotX,turretPivotY,turretPivotZ,
      turretPitchDegrees,turretYawDegrees,turretRollDegrees,
      turretScaleX,turretScaleY,turretScaleZ,
    ];
    _barrelDefaults = [
      barrelX,barrelY,barrelZ,
      barrelPivotX,barrelPivotY,barrelPivotZ,
      barrelPitchDegrees,barrelYawDegrees,barrelRollDegrees,
      barrelScaleX,barrelScaleY,barrelScaleZ,
      barrelRecoil,muzzleX,muzzleY,muzzleZ,
    ];
    _defaults=[
      x,y,z,pitchDegrees,yawDegrees,rollDegrees,scaleX,scaleY,scaleZ,
      shotHullRecoilDistance,shotHullPitchDegrees,shotBarrelRecoilDistance,
      shotRecoilKickSeconds,shotRecoilHoldSeconds,shotRecoilReturnSeconds,
      ..._turretDefaults,..._barrelDefaults,
    ];
  }

  void resetTurretToDefaults() {
    final d=_turretDefaults;
    turretX=d[0]; turretY=d[1]; turretZ=d[2];
    turretPivotX=d[3]; turretPivotY=d[4]; turretPivotZ=d[5];
    turretPitchDegrees=d[6]; turretYawDegrees=d[7]; turretRollDegrees=d[8];
    turretScaleX=d[9]; turretScaleY=d[10]; turretScaleZ=d[11];
  }

  void resetBarrelToDefaults() {
    final d=_barrelDefaults;
    barrelX=d[0]; barrelY=d[1]; barrelZ=d[2];
    barrelPivotX=d[3]; barrelPivotY=d[4]; barrelPivotZ=d[5];
    barrelPitchDegrees=d[6]; barrelYawDegrees=d[7]; barrelRollDegrees=d[8];
    barrelScaleX=d[9]; barrelScaleY=d[10]; barrelScaleZ=d[11];
    barrelRecoil=d[12]; muzzleX=d[13]; muzzleY=d[14]; muzzleZ=d[15];
  }

  void resetToDefaults() {
    final d=_defaults;
    x=d[0]; y=d[1]; z=d[2]; pitchDegrees=d[3]; yawDegrees=d[4]; rollDegrees=d[5];
    scaleX=d[6]; scaleY=d[7]; scaleZ=d[8];
    shotHullRecoilDistance=d[9]; shotHullPitchDegrees=d[10]; shotBarrelRecoilDistance=d[11];
    shotRecoilKickSeconds=d[12]; shotRecoilHoldSeconds=d[13]; shotRecoilReturnSeconds=d[14];
    resetTurretToDefaults();
    resetBarrelToDefaults();
  }
}

class _StationDeveloperTuning {
  bool initialized = false;
  double x = 0;
  double y = 0;
  double z = 0;
  double pitchDegrees = 0;
  double yawDegrees = 0;
  double rollDegrees = 0;
  double cameraX = 0;
  double cameraY = 0;
  double cameraZ = 0;
  double cameraYawDegrees = 0;
  double cameraPitchDegrees = 0;
  double cameraFovDegrees = 74;

  double _defaultX = 0;
  double _defaultY = 0;
  double _defaultZ = 0;
  double _defaultPitch = 0;
  double _defaultYaw = 0;
  double _defaultRoll = 0;
  double _defaultCameraX = 0;
  double _defaultCameraY = 0;
  double _defaultCameraZ = 0;
  double _defaultCameraYaw = 0;
  double _defaultCameraPitch = 0;
  double _defaultCameraFov = 74;

  void captureDefaults() {
    _defaultX = x;
    _defaultY = y;
    _defaultZ = z;
    _defaultPitch = pitchDegrees;
    _defaultYaw = yawDegrees;
    _defaultRoll = rollDegrees;
    _defaultCameraX = cameraX;
    _defaultCameraY = cameraY;
    _defaultCameraZ = cameraZ;
    _defaultCameraYaw = cameraYawDegrees;
    _defaultCameraPitch = cameraPitchDegrees;
    _defaultCameraFov = cameraFovDegrees;
  }

  void resetToDefaults() {
    x = _defaultX;
    y = _defaultY;
    z = _defaultZ;
    pitchDegrees = _defaultPitch;
    yawDegrees = _defaultYaw;
    rollDegrees = _defaultRoll;
    cameraX = _defaultCameraX;
    cameraY = _defaultCameraY;
    cameraZ = _defaultCameraZ;
    cameraYawDegrees = _defaultCameraYaw;
    cameraPitchDegrees = _defaultCameraPitch;
    cameraFovDegrees = _defaultCameraFov;
  }
}


class _TimerVisualAssembly {
  _TimerVisualAssembly(this.pivot, this.nodes, this.basePositions, this.baseRotations, this.baseScales);
  final vm.Vector3 pivot;
  final List<Node> nodes;
  final List<vm.Vector3> basePositions;
  final List<vm.Quaternion> baseRotations;
  final List<vm.Vector3> baseScales;

  factory _TimerVisualAssembly.capture(vm.Vector3 pivot, List<Node> nodes) {
    return _TimerVisualAssembly(
      vm.Vector3.copy(pivot),
      List<Node>.from(nodes),
      nodes.map((n) => vm.Vector3.copy(n.position)).toList(),
      nodes.map((n) => vm.Quaternion.copy(n.rotation)).toList(),
      nodes.map((n) => vm.Vector3.copy(n.scale)).toList(),
    );
  }

  void apply(vm.Vector3 delta, vm.Quaternion rotation, double scaleX, double scaleY) {
    for (var i=0;i<nodes.length;i++) {
      final offset = basePositions[i] - pivot;
      final scaled = vm.Vector3(offset.x * scaleX, offset.y * scaleY, offset.z);
      final rotated = rotation.rotated(scaled);
      nodes[i]
        ..position = pivot + delta + rotated
        ..rotation = rotation * baseRotations[i]
        ..scale = vm.Vector3(baseScales[i].x * scaleX, baseScales[i].y * scaleY, baseScales[i].z);
    }
  }
}

class _SurfaceImageTuning {
  bool enabled = false;
  int mode = 3; // 0 stretch, 1 fit, 2 fill, 3 tile
  double repeatX = 3;
  double repeatY = 3;
  double imageScale = 1;
  double offsetX = 0;
  double offsetY = 0;
  double rotationDegrees = 0;
  String path = '';
  Uint8List? bytes;
  String describe() => 'enabled=$enabled mode=$mode repeat=${repeatX.toStringAsFixed(1)},${repeatY.toStringAsFixed(1)} scale=${imageScale.toStringAsFixed(2)} offset=${offsetX.toStringAsFixed(2)},${offsetY.toStringAsFixed(2)} rot=${rotationDegrees.toStringAsFixed(1)} path=$path';
}

class _StationSurfaceTuning {
  Color chairColor = const Color(0xFF78672F);
  Color chairFrameColor = const Color(0xFF4D4525);
  Color deskColor = const Color(0xFF222B31);
  Color timerFaceColor = const Color(0xFF020506);
  Color timerDigitColor = const Color(0xFFFFFFFF);
  final chairImage = _SurfaceImageTuning();
  final deskImage = _SurfaceImageTuning();
  final timerImage = _SurfaceImageTuning();
  double timerX = 0, timerY = 0, timerZ = 0;
  double timerPitchDegrees = 0, timerYawDegrees = 0, timerRollDegrees = 0;
  double timerScaleX = 1, timerScaleY = 1;
  double chairCornerRadius = .035;
  double timerCornerRadius = .025;
}


class _ProjectileDeveloperTuning {
  bool initialized = false;
  bool previewAtMuzzle = true;
  double previewOffsetX = 0, previewOffsetY = 0, previewOffsetZ = 0;
  double scaleX = .14, scaleY = .14, scaleZ = .14;
  double pitchDegrees = 0, yawDegrees = 0, rollDegrees = 0;
  double spinX = 240, spinY = 320, spinZ = 180;
  double glowInnerSize = .22, glowOuterSize = .38, glowOpacity = .58;
  Color glowColor = const Color(0xFFFF3A12);
  bool trailEnabled = true;
  double trailSize = .15, trailSpacing = .055, trailOpacity = .48;
  Color trailColor = const Color(0xFFFF641A);
  double impactScale = 1.7;
}

class _BigScreenDeveloperTuning {
  bool initialized = false;
  Color frameColor = const Color(0xFF1A2328);
  Color bezelColor = const Color(0xFF090E11);
  Color screenColor = const Color(0xFF071A22);
  bool hasBasePosition = false;
  double baseX = 0, baseY = 0, baseZ = 0;
  double x = 0, y = 0, z = 0;
  double pitchDegrees = 0, yawDegrees = 0, rollDegrees = 0;
  double left = 0, right = 0, top = 0, bottom = 0;
  double globalTextScale = 1;
  double globalTextX = 0;
  double globalTextY = 0;
  double headerFontSize = 52;
  double rowFontSize = 66;
  double headerX = 0;
  double headerY = 52;
  double rowsX = 0;
  double rowsStartY = 145;
  double rowGap = 202;
  double rowWidth = 1440;
  double rowHeight = 166;
  double rowTextYOffset = 49;
  double frameCornerRadius = .10;
}


class _MountainVisualTuning {
  bool enabled = true;
  double x = -1.400;
  double y = 0.000;
  double z = 0.000;
  double radiusOffset = 0.000;
  double scaleX = 1.100;
  double scaleY = 1.500;
  double scaleZ = 1.000;
  double pitchDegrees = 0.00;
  double yawDegrees = 0.00;
  double rollDegrees = 0.50;
  Color color = const Color(0xFF101100);

  late final Map<String, Object> _defaults;
  void captureDefaults() {
    _defaults = {
      'enabled': enabled,
      'x': x, 'y': y, 'z': z, 'radiusOffset': radiusOffset,
      'scaleX': scaleX, 'scaleY': scaleY, 'scaleZ': scaleZ,
      'pitch': pitchDegrees, 'yaw': yawDegrees, 'roll': rollDegrees,
      'color': color,
    };
  }

  void resetToDefaults() {
    enabled = _defaults['enabled'] as bool;
    x = _defaults['x'] as double;
    y = _defaults['y'] as double;
    z = _defaults['z'] as double;
    radiusOffset = _defaults['radiusOffset'] as double;
    scaleX = _defaults['scaleX'] as double;
    scaleY = _defaults['scaleY'] as double;
    scaleZ = _defaults['scaleZ'] as double;
    pitchDegrees = _defaults['pitch'] as double;
    yawDegrees = _defaults['yaw'] as double;
    rollDegrees = _defaults['roll'] as double;
    color = _defaults['color'] as Color;
  }
}

class _EnvironmentDeveloperTuning {
  bool showGround = true;
  bool showMountains = true;
  Color groundColor = const Color(0xFF050500);
  double groundX = 0;
  double groundY = -3.128;
  double groundZ = 0;
  double groundWidth = 46;
  double groundDepth = 46;
  double groundThickness = .65;
  double groundPitchDegrees = 0;
  double groundYawDegrees = 0;
  double groundRollDegrees = 0;

  double centerX = 0;
  double centerY = -2.388;
  double centerZ = 0;
  int mountainCount = 12;
  double ringRadius = 18;
  double arcDegrees = 360;
  double startAngleDegrees = 0;
  double scaleX = .95;
  double scaleY = 1.65;
  double scaleZ = .95;
  double basePitchDegrees = 0;
  double baseYawDegrees = 0;
  double baseRollDegrees = 0;
  double faceCenterYawOffsetDegrees = 0;

  final List<_MountainVisualTuning> mountains = List<_MountainVisualTuning>.generate(16, (_) => _MountainVisualTuning());
  late final Map<String, Object> _defaults;

  void captureDefaults() {
    _defaults = {
      'showGround': showGround,
      'showMountains': showMountains,
      'groundColor': groundColor,
      'groundX': groundX, 'groundY': groundY, 'groundZ': groundZ,
      'groundWidth': groundWidth, 'groundDepth': groundDepth, 'groundThickness': groundThickness,
      'groundPitch': groundPitchDegrees, 'groundYaw': groundYawDegrees, 'groundRoll': groundRollDegrees,
      'centerX': centerX, 'centerY': centerY, 'centerZ': centerZ,
      'mountainCount': mountainCount, 'ringRadius': ringRadius, 'arcDegrees': arcDegrees, 'startAngleDegrees': startAngleDegrees,
      'scaleX': scaleX, 'scaleY': scaleY, 'scaleZ': scaleZ,
      'basePitch': basePitchDegrees, 'baseYaw': baseYawDegrees, 'baseRoll': baseRollDegrees,
      'faceCenter': faceCenterYawOffsetDegrees,
    };
    for (final m in mountains) {
      m.captureDefaults();
    }
  }

  void resetToDefaults() {
    showGround = _defaults['showGround'] as bool;
    showMountains = _defaults['showMountains'] as bool;
    groundColor = _defaults['groundColor'] as Color;
    groundX = _defaults['groundX'] as double;
    groundY = _defaults['groundY'] as double;
    groundZ = _defaults['groundZ'] as double;
    groundWidth = _defaults['groundWidth'] as double;
    groundDepth = _defaults['groundDepth'] as double;
    groundThickness = _defaults['groundThickness'] as double;
    groundPitchDegrees = _defaults['groundPitch'] as double;
    groundYawDegrees = _defaults['groundYaw'] as double;
    groundRollDegrees = _defaults['groundRoll'] as double;
    centerX = _defaults['centerX'] as double;
    centerY = _defaults['centerY'] as double;
    centerZ = _defaults['centerZ'] as double;
    mountainCount = _defaults['mountainCount'] as int;
    ringRadius = _defaults['ringRadius'] as double;
    arcDegrees = _defaults['arcDegrees'] as double;
    startAngleDegrees = _defaults['startAngleDegrees'] as double;
    scaleX = _defaults['scaleX'] as double;
    scaleY = _defaults['scaleY'] as double;
    scaleZ = _defaults['scaleZ'] as double;
    basePitchDegrees = _defaults['basePitch'] as double;
    baseYawDegrees = _defaults['baseYaw'] as double;
    baseRollDegrees = _defaults['baseRoll'] as double;
    faceCenterYawOffsetDegrees = _defaults['faceCenter'] as double;
    for (final m in mountains) {
      m.resetToDefaults();
    }
  }
}


class _GuessTimeDeveloperTuning {
  final List<_StationDeveloperTuning> stations =
      List<_StationDeveloperTuning>.generate(4, (_) => _StationDeveloperTuning());
  final List<_PlayerPoseTuning> poses =
      List<_PlayerPoseTuning>.generate(4, (_) => _PlayerPoseTuning());
  final _TankDeveloperTuning tank = _TankDeveloperTuning();
  final _ProjectileDeveloperTuning projectile = _ProjectileDeveloperTuning();
  final List<_StationSurfaceTuning> surfaces =
      List<_StationSurfaceTuning>.generate(4, (_) => _StationSurfaceTuning());
  final _BigScreenDeveloperTuning bigScreen = _BigScreenDeveloperTuning();
  final _EnvironmentDeveloperTuning environment = _EnvironmentDeveloperTuning();

  _GuessTimeDeveloperTuning() {
    final defaultTexture = _decodeDefaultBlackWallTextureBytes();
    for (var i = 0; i < surfaces.length; i++) {
      final s = surfaces[i];
      s.chairColor = const Color(0xFF78672F);
      s.deskColor = const Color(0xFF222B31);
      void configure(_SurfaceImageTuning image, int mode) {
        image
          ..enabled = true
          ..mode = mode
          ..repeatX = 3
          ..repeatY = 3
          ..imageScale = 1
          ..offsetX = 0
          ..offsetY = 0
          ..rotationDegrees = 0
          ..path = _kDefaultBlackWallTexturePath
          ..bytes = defaultTexture;
      }
      configure(s.chairImage, 2);
      configure(s.deskImage, i == 0 ? 0 : 2);
      configure(s.timerImage, i == 0 ? 0 : 2);
    }
    surfaces[0]
      ..timerX = 0.020
      ..timerY = 0.000
      ..timerZ = -0.060
      ..timerPitchDegrees = 0
      ..timerYawDegrees = 0
      ..timerRollDegrees = 0
      ..timerScaleX = 1.150
      ..timerScaleY = 1.350;

    projectile
      ..previewAtMuzzle = true
      ..previewOffsetX = -0.003
      ..previewOffsetY = -0.020
      ..previewOffsetZ = -0.020
      ..scaleX = 0.030
      ..scaleY = 0.030
      ..scaleZ = 0.030
      ..pitchDegrees = 21
      ..yawDegrees = 8
      ..rollDegrees = 0
      ..glowInnerSize = 2.000
      ..glowOuterSize = 0.090
      ..glowOpacity = 0.05
      ..trailEnabled = true
      ..trailSize = 0.140
      ..trailSpacing = 0.060
      ..trailOpacity = 0.48
      ..spinX = 240.0
      ..spinY = 320.0
      ..spinZ = 180.0
      ..impactScale = 1.70;

    bigScreen
      ..frameColor = const Color(0xFF373703)
      ..bezelColor = const Color(0xFF000000)
      ..screenColor = const Color(0xFF000000)
      ..x = 0
      ..y = 0
      ..z = 0
      ..pitchDegrees = 0
      ..yawDegrees = 30
      ..rollDegrees = 0
      ..left = 0
      ..right = 0
      ..top = 0.650
      ..bottom = 0
      ..globalTextScale = 1.25
      ..globalTextX = 180
      ..globalTextY = 0
      ..headerFontSize = 52
      ..headerX = -20
      ..headerY = 47
      ..rowFontSize = 66
      ..rowsX = 20
      ..rowsStartY = 145
      ..rowGap = 202
      ..rowWidth = 1560
      ..rowHeight = 161
      ..rowTextYOffset = 49;

    environment
      ..showGround = true
      ..groundColor = const Color(0xFF050500)
      ..groundX = 0.000
      ..groundY = -3.128
      ..groundZ = 0.000
      ..groundPitchDegrees = 0.00
      ..groundYawDegrees = 0.00
      ..groundRollDegrees = 0.00
      ..groundWidth = 46.000
      ..groundThickness = 0.650
      ..groundDepth = 46.000
      ..showMountains = true
      ..mountainCount = 12
      ..centerX = 0.000
      ..centerY = -2.388
      ..centerZ = 0.000
      ..ringRadius = 18.000
      ..arcDegrees = 360.00
      ..startAngleDegrees = 0.00
      ..scaleX = 0.950
      ..scaleY = 1.650
      ..scaleZ = 0.950
      ..basePitchDegrees = 0.00
      ..baseYawDegrees = 0.00
      ..baseRollDegrees = 0.00
      ..faceCenterYawOffsetDegrees = 0.00;
    for (final mountain in environment.mountains) {
      mountain
        ..enabled = true
        ..x = -1.400
        ..y = 0.000
        ..z = 0.000
        ..radiusOffset = 0.000
        ..scaleX = 1.100
        ..scaleY = 1.500
        ..scaleZ = 1.000
        ..pitchDegrees = 0.00
        ..yawDegrees = 0.00
        ..rollDegrees = 0.50
        ..color = const Color(0xFF101100);
    }
    environment.captureDefaults();
  }

  // Final room-only transform measured in the developer view on 2026-09-24.
  double mapX = 6.1;
  double mapY = .1;
  double mapZ = .1;
  double mapPitchDegrees = 0;
  double mapYawDegrees = -190;
  double mapRollDegrees = 0;

  // Completely free developer camera. It is NOT attached to a player/station.
  double cameraX = 0;
  double cameraY = 0;
  double cameraZ = 0;
  double cameraYawDegrees = 0;
  double cameraPitchDegrees = 0;
  double cameraFovDegrees = 72;

  double nudgeStep = .10;
  double flyStep = .25;

  void resetMap() {
    mapX = 0;
    mapY = 0;
    mapZ = 0;
    mapPitchDegrees = 0;
    mapYawDegrees = 0;
    mapRollDegrees = 0;
  }
}

class _GuessTimeDeveloperOverlay extends ui.StatefulWidget {
  const _GuessTimeDeveloperOverlay({required this.world});

  final GuessTime3DWorld world;

  @override
  ui.State<_GuessTimeDeveloperOverlay> createState() =>
      _GuessTimeDeveloperOverlayState();
}

class _GuessTimeDeveloperOverlayState
    extends ui.State<_GuessTimeDeveloperOverlay> {
  Timer? _watchdog;
  bool _collapsed = false;
  bool _copied = false;
  int _page = 0;
  int _selectedStation = 0;
  int _selectedTankTarget = 0;
  int _selectedMountain = 0;
  double _tankPartPositionStep = 1.0;
  double _tankPartAngleStep = 1.0;
  double _tankPartScaleStep = .01;

  @override
  void initState() {
    super.initState();
    widget.world._selectDeveloperStation(_selectedStation);
    widget.world._selectTankDeveloperTarget(_selectedTankTarget);
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final inactive =
          DateTime.now().difference(widget.world._lastCameraFrame).inMilliseconds >
              3500;
      if (inactive) {
        widget.world._removeDeveloperOverlay();
      }
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  void _changed([bool mapChanged = false]) {
    if (mapChanged) widget.world._applyDeveloperMapTransform();
    if (mounted) setState(() {});
  }

  void _copy() {
    services.Clipboard.setData(
      services.ClipboardData(text: widget.world._developerSettingsText()),
    );
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  ui.Widget _tab(String label, int page) {
    final selected = _page == page;
    return ui.SizedBox(
      width: 82,
      child: ui.FilledButton(
        style: ui.FilledButton.styleFrom(
          padding: const ui.EdgeInsets.symmetric(vertical: 9, horizontal: 5),
          backgroundColor: selected
              ? const ui.Color(0xFF219587)
              : const ui.Color(0xFF222B31),
        ),
        onPressed: () => setState(() => _page = page),
        child: ui.Text(label, style: const ui.TextStyle(fontSize: 11)),
      ),
    );
  }

  ui.Widget _stepControl() {
    final d = widget.world._dev;
    return ui.Wrap(
      crossAxisAlignment: ui.WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        const ui.Padding(
          padding: ui.EdgeInsets.only(left: 5),
          child: ui.Text('الخطوة', style: ui.TextStyle(fontSize: 12)),
        ),
        for (final step in const [.01, .05, .1, .5, 1.0, 5.0, 10.0])
          ui.ChoiceChip(
            label: ui.Text(step.toString()),
            selected: (d.nudgeStep - step).abs() < .000001,
            onSelected: (_) {
              d.nudgeStep = step;
              _changed();
            },
            visualDensity: ui.VisualDensity.compact,
            labelStyle: const ui.TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  ui.Widget _stationPage() {
    final d = widget.world._dev;
    final index = _selectedStation.clamp(0, 3).toInt();
    final s = d.stations[index];

    void apply() {
      widget.world._applyDeveloperStationTransform(index);
      _changed();
    }

    return ui.Column(
      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
      children: [
        ui.Container(
          padding: const ui.EdgeInsets.all(9),
          margin: const ui.EdgeInsets.only(bottom: 8),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0x33219587),
            borderRadius: ui.BorderRadius.circular(9),
          ),
          child: const ui.Text(
            'اختَر اللاعب ثم غيّر موقع الكرسي/الطاولة/الشخصية كلها كوحدة واحدة. '
            'X/Y/Z إحداثيات عالمية، والدوران بالدرجات. القيم التي تنسخها هنا هي القيم التي أرسلها لي لاحقاً للتثبيت النهائي.',
            style: ui.TextStyle(fontSize: 11, height: 1.45),
          ),
        ),
        ui.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 4; i++)
              ui.ChoiceChip(
                label: ui.Text('اللاعب ${i + 1}'),
                selected: _selectedStation == i,
                onSelected: (_) {
                  setState(() => _selectedStation = i);
                  widget.world._selectDeveloperStation(i);
                },
              ),
          ],
        ),
        const ui.SizedBox(height: 10),
        _DevNumberControl(
          label: 'X يمين / يسار',
          value: s.x,
          step: d.nudgeStep,
          onChanged: (v) { s.x = v; apply(); },
        ),
        _DevNumberControl(
          label: 'Y ارتفاع',
          value: s.y,
          step: d.nudgeStep,
          onChanged: (v) { s.y = v; apply(); },
        ),
        _DevNumberControl(
          label: 'Z أمام / خلف',
          value: s.z,
          step: d.nudgeStep,
          onChanged: (v) { s.z = v; apply(); },
        ),
        const ui.Divider(height: 16),
        _DevNumberControl(
          label: 'Pitch دوران X',
          value: s.pitchDegrees,
          step: d.nudgeStep,
          onChanged: (v) { s.pitchDegrees = v; apply(); },
        ),
        _DevNumberControl(
          label: 'Yaw دوران Y',
          value: s.yawDegrees,
          step: d.nudgeStep,
          onChanged: (v) { s.yawDegrees = v; apply(); },
        ),
        _DevNumberControl(
          label: 'Roll دوران Z',
          value: s.rollDegrees,
          step: d.nudgeStep,
          onChanged: (v) { s.rollDegrees = v; apply(); },
        ),
        const ui.Divider(height: 18),
        ui.Container(
          padding: const ui.EdgeInsets.all(9),
          margin: const ui.EdgeInsets.only(bottom: 7),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0x221E88E5),
            borderRadius: ui.BorderRadius.circular(9),
          ),
          child: ui.Text(
            widget.world._developerFreeCameraEnabled
                ? 'كاميرا حرة مفعلة: هذه القيم تعدّل كاميرا اللاعب ${index + 1} لكن الكاميرا الحالية لن تنتقل إليه حتى تطفئ الوضع الحر.'
                : 'كاميرا اللاعب ${index + 1}: عدّل موضع العين واتجاه النظر. اختيار لاعب آخر ينقل الكاميرا إليه تلقائياً.',
            style: const ui.TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
        _DevNumberControl(
          label: 'Camera X محلي',
          value: s.cameraX,
          step: d.nudgeStep,
          onChanged: (v) { s.cameraX = v; _changed(); },
        ),
        _DevNumberControl(
          label: 'Camera Y ارتفاع العين',
          value: s.cameraY,
          step: d.nudgeStep,
          onChanged: (v) { s.cameraY = v; _changed(); },
        ),
        _DevNumberControl(
          label: 'Camera Z أمام / خلف',
          value: s.cameraZ,
          step: d.nudgeStep,
          onChanged: (v) { s.cameraZ = v; _changed(); },
        ),
        _DevNumberControl(
          label: 'Camera Yaw',
          value: s.cameraYawDegrees,
          step: d.nudgeStep,
          onChanged: (v) { s.cameraYawDegrees = v; _changed(); },
        ),
        _DevNumberControl(
          label: 'Camera Pitch',
          value: s.cameraPitchDegrees,
          step: d.nudgeStep,
          onChanged: (v) { s.cameraPitchDegrees = v.clamp(-75.0, 75.0).toDouble(); _changed(); },
        ),
        _DevNumberControl(
          label: 'Camera FOV',
          value: s.cameraFovDegrees,
          step: d.nudgeStep,
          onChanged: (v) { s.cameraFovDegrees = v.clamp(40.0, 105.0).toDouble(); _changed(); },
        ),
        const ui.SizedBox(height: 8),
        ui.Row(
          children: [
            ui.Expanded(
              child: ui.OutlinedButton.icon(
                onPressed: () {
                  widget.world._resetDeveloperStation(index);
                  _changed();
                },
                icon: const ui.Icon(ui.Icons.restart_alt, size: 17),
                label: ui.Text('إرجاع اللاعب ${index + 1}'),
              ),
            ),
            const ui.SizedBox(width: 7),
            ui.Expanded(
              child: ui.OutlinedButton.icon(
                onPressed: () {
                  widget.world._resetAllDeveloperStations();
                  _changed();
                },
                icon: const ui.Icon(ui.Icons.refresh, size: 17),
                label: const ui.Text('إرجاع الكل'),
              ),
            ),
          ],
        ),
        const ui.SizedBox(height: 8),
        ui.FilledButton.icon(
          onPressed: () {
            services.Clipboard.setData(
              services.ClipboardData(
                text: [widget.world._developerStationsSettingsText(), '-------------------------------', widget.world._developerPlayerPosesSettingsText()].join('\n'),
              ),
            );
            setState(() => _copied = true);
            Future<void>.delayed(const Duration(milliseconds: 900), () {
              if (mounted) setState(() => _copied = false);
            });
          },
          icon: ui.Icon(_copied ? ui.Icons.check : ui.Icons.copy, size: 18),
          label: ui.Text(_copied ? 'تم نسخ إعدادات اللاعبين' : 'نسخ إعدادات اللاعبين الأربعة'),
        ),
      ],
    );
  }


  ui.Widget _poseSection(String label, _EulerTuning tuning, double step, void Function() changed) {
    return ui.Container(
      margin: const ui.EdgeInsets.only(bottom: 8),
      padding: const ui.EdgeInsets.all(8),
      decoration: ui.BoxDecoration(
        color: const ui.Color(0x1200BCD4),
        borderRadius: ui.BorderRadius.circular(8),
        border: ui.Border.all(color: const ui.Color(0x223A4F56)),
      ),
      child: ui.Column(
        crossAxisAlignment: ui.CrossAxisAlignment.stretch,
        children: [
          ui.Text(label, style: const ui.TextStyle(fontSize: 12, fontWeight: ui.FontWeight.w700)),
          _DevNumberControl(label: 'X', value: tuning.xDegrees, step: step, onChanged: (v){ tuning.xDegrees = v; changed(); }),
          _DevNumberControl(label: 'Y', value: tuning.yDegrees, step: step, onChanged: (v){ tuning.yDegrees = v; changed(); }),
          _DevNumberControl(label: 'Z', value: tuning.zDegrees, step: step, onChanged: (v){ tuning.zDegrees = v; changed(); }),
        ],
      ),
    );
  }

  ui.Widget _posePage() {
    final d = widget.world._dev;
    final index = _selectedStation.clamp(0, 3).toInt();
    final p = d.poses[index];
    void apply() {
      widget.world._posePlayer(widget.world._players[index], press: 0);
      _changed();
    }
    return ui.Column(
      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
      children: [
        ui.Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List<ui.Widget>.generate(4, (i) {
            final selected = _selectedStation == i;
            return ui.ChoiceChip(
              label: ui.Text('لاعب ${i + 1}'),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedStation = i);
                widget.world._selectDeveloperStation(i);
              },
            );
          }),
        ),
        const ui.SizedBox(height: 8),
        _DevNumberControl(label: 'Root X', value: p.x, step: d.nudgeStep, onChanged: (v){ p.x=v; apply(); }),
        _DevNumberControl(label: 'Root Y', value: p.y, step: d.nudgeStep, onChanged: (v){ p.y=v; apply(); }),
        _DevNumberControl(label: 'Root Z', value: p.z, step: d.nudgeStep, onChanged: (v){ p.z=v; apply(); }),
        _DevNumberControl(label: 'Root Pitch', value: p.pitchDegrees, step: d.nudgeStep, onChanged: (v){ p.pitchDegrees=v; apply(); }),
        _DevNumberControl(label: 'Root Yaw', value: p.yawDegrees, step: d.nudgeStep, onChanged: (v){ p.yawDegrees=v; apply(); }),
        _DevNumberControl(label: 'Root Roll', value: p.rollDegrees, step: d.nudgeStep, onChanged: (v){ p.rollDegrees=v; apply(); }),
        _DevNumberControl(label: 'Scale', value: p.scale, step: .01, onChanged: (v){ p.scale=v; apply(); }),
        _DevNumberControl(label: 'Body X', value: p.bodyX, step: d.nudgeStep, onChanged: (v){ p.bodyX=v; apply(); }),
        _DevNumberControl(label: 'Body Y', value: p.bodyY, step: d.nudgeStep, onChanged: (v){ p.bodyY=v; apply(); }),
        _DevNumberControl(label: 'Body Z', value: p.bodyZ, step: d.nudgeStep, onChanged: (v){ p.bodyZ=v; apply(); }),
        const ui.SizedBox(height: 8),
        _poseSection('الحوض Hips', p.hips, d.nudgeStep, apply),
        _poseSection('Spine', p.spine, d.nudgeStep, apply),
        _poseSection('Spine1', p.spine1, d.nudgeStep, apply),
        _poseSection('Neck', p.neck, d.nudgeStep, apply),
        _poseSection('Head', p.head, d.nudgeStep, apply),
        _poseSection('Left Shoulder', p.leftShoulder, d.nudgeStep, apply),
        _poseSection('Left Arm', p.leftArm, d.nudgeStep, apply),
        _poseSection('Left ForeArm', p.leftForeArm, d.nudgeStep, apply),
        _poseSection('Left Hand', p.leftHand, d.nudgeStep, apply),
        _poseSection('Right Shoulder', p.rightShoulder, d.nudgeStep, apply),
        _poseSection('Right Arm', p.rightArm, d.nudgeStep, apply),
        _poseSection('Right ForeArm', p.rightForeArm, d.nudgeStep, apply),
        _poseSection('Right Hand', p.rightHand, d.nudgeStep, apply),
        _poseSection('Left Thigh', p.leftUpLeg, d.nudgeStep, apply),
        _poseSection('Left Leg', p.leftLeg, d.nudgeStep, apply),
        _poseSection('Left Foot', p.leftFoot, d.nudgeStep, apply),
        _poseSection('Right Thigh', p.rightUpLeg, d.nudgeStep, apply),
        _poseSection('Right Leg', p.rightLeg, d.nudgeStep, apply),
        _poseSection('Right Foot', p.rightFoot, d.nudgeStep, apply),
        ui.OutlinedButton.icon(
          onPressed: () { p.resetToDefaults(); apply(); },
          icon: const ui.Icon(ui.Icons.restart_alt, size: 18),
          label: const ui.Text('إرجاع وضعية هذا اللاعب للقيم الافتراضية'),
        ),
      ],
    );
  }


  ui.Widget _tankPointEditor(
    String label,
    _TankPointTuning point,
    {bool emphasize = false}
  ) {
    final d = widget.world._dev;
    void changed() {
      widget.world._refreshTankDeveloperMarkers();
      widget.world._previewTankDeveloperPoint(point);
      _changed();
    }
    void changedMove() {
      widget.world._refreshTankDeveloperMarkers();
      widget.world._previewTankDeveloperMoveRotation(point);
      _changed();
    }
    return ui.Container(
      margin: const ui.EdgeInsets.only(bottom: 8),
      padding: const ui.EdgeInsets.all(8),
      decoration: ui.BoxDecoration(
        color: emphasize ? const ui.Color(0x22FF5252) : const ui.Color(0x141E8895),
        borderRadius: ui.BorderRadius.circular(9),
        border: ui.Border.all(color: emphasize ? const ui.Color(0x66FF5252) : const ui.Color(0x334C6972)),
      ),
      child: ui.Column(
        crossAxisAlignment: ui.CrossAxisAlignment.stretch,
        children: [
          ui.Text(label, style: const ui.TextStyle(fontWeight: ui.FontWeight.w700, fontSize: 12)),
          const ui.SizedBox(height: 4),
          const ui.Text('الموقع', style: ui.TextStyle(fontSize: 10.5, fontWeight: ui.FontWeight.w700, color: ui.Color(0xFF9FDCE2))),
          _DevNumberControl(label: 'X', value: point.x, step: d.nudgeStep, onChanged: (v){ point.x=v; changed(); }),
          _DevNumberControl(label: 'Y ارتفاع', value: point.y, step: d.nudgeStep, onChanged: (v){ point.y=v; changed(); }),
          _DevNumberControl(label: 'Z', value: point.z, step: d.nudgeStep, onChanged: (v){ point.z=v; changed(); }),
          const ui.SizedBox(height: 4),
          const ui.Text('STOP ROTATION — دوران جسم الدبابة وهي واقفة عند هذه النقطة', style: ui.TextStyle(fontSize: 10.5, fontWeight: ui.FontWeight.w700, color: ui.Color(0xFFFFD166))),
          _DevNumberControl(
            label: 'Tank Pitch',
            value: point.hullPitchDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.hullPitchDegrees=v; changed(); },
          ),
          _DevNumberControl(
            label: 'STOP Yaw — دوران الدبابة وهي واقفة',
            value: point.hullYawDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.hullYawDegrees=v; changed(); },
          ),
          _DevNumberControl(
            label: 'Tank Roll',
            value: point.hullRollDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.hullRollDegrees=v; changed(); },
          ),
          const ui.SizedBox(height: 5),
          const ui.Text('MOVE ROTATION — دوران جسم الدبابة أثناء المشي من هذه النقطة', style: ui.TextStyle(fontSize: 10.5, fontWeight: ui.FontWeight.w700, color: ui.Color(0xFF82E6A6))),
          _DevNumberControl(
            label: 'MOVE Pitch',
            value: point.moveHullPitchDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.moveHullPitchDegrees=v; changedMove(); },
          ),
          _DevNumberControl(
            label: 'MOVE Yaw — اتجاه جسم الدبابة أثناء المشي فقط',
            value: point.moveHullYawDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.moveHullYawDegrees=v; changedMove(); },
          ),
          _DevNumberControl(
            label: 'MOVE Roll',
            value: point.moveHullRollDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.moveHullRollDegrees=v; changedMove(); },
          ),
          _DevNumberControl(
            label: 'AIM Turret Yaw — البرج بالكامل يمين/يسار',
            value: point.turretYawDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.turretYawDegrees=v; changed(); },
          ),
          _DevNumberControl(
            label: 'AIM Gun Pitch — المدفعية أعلى/أسفل',
            value: point.barrelPitchDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.barrelPitchDegrees=v; changed(); },
          ),
          _DevNumberControl(
            label: 'AIM Gun Yaw — المدفعية يمين/يسار',
            value: point.barrelYawDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ point.barrelYawDegrees=v; changed(); },
          ),
          const ui.Padding(
            padding: ui.EdgeInsets.only(top: 5),
            child: ui.Text('المعاينة المباشرة تعرض STOP ROTATION. أما MOVE ROTATION فيُستخدم فقط أثناء سير الدبابة في المسار.', style: ui.TextStyle(fontSize: 9.5, color: ui.Color(0xFF9FDCE2))),
          ),
        ],
      ),
    );
  }

  ui.Widget _tankAimStageEditor(
    String label,
    _TankAimStageTuning aim,
    {bool finalStage = false}
  ) {
    void preview() {
      widget.world._previewTankDeveloperAimStage(aim);
      _changed();
    }
    return ui.Container(
      margin: const ui.EdgeInsets.only(bottom: 7),
      padding: const ui.EdgeInsets.all(8),
      decoration: ui.BoxDecoration(
        color: finalStage ? const ui.Color(0x2634C759) : const ui.Color(0x161C79B8),
        borderRadius: ui.BorderRadius.circular(9),
        border: ui.Border.all(
          color: finalStage ? const ui.Color(0x6657E389) : const ui.Color(0x334D8CB8),
        ),
      ),
      child: ui.Column(
        crossAxisAlignment: ui.CrossAxisAlignment.stretch,
        children: [
          ui.Text(
            label,
            style: ui.TextStyle(
              fontSize: 11.5,
              fontWeight: ui.FontWeight.w800,
              color: finalStage ? const ui.Color(0xFF76F39E) : const ui.Color(0xFF9ED8FF),
            ),
          ),
          _DevNumberControl(
            label: 'AIM Turret Yaw — البرج بالكامل يمين/يسار',
            value: aim.turretYawDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ aim.turretYawDegrees=v; preview(); },
          ),
          _DevNumberControl(
            label: 'AIM Gun Pitch — المدفعية أعلى/أسفل',
            value: aim.barrelPitchDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ aim.barrelPitchDegrees=v; preview(); },
          ),
          _DevNumberControl(
            label: 'AIM Gun Yaw — المدفعية يمين/يسار',
            value: aim.barrelYawDegrees,
            step: _tankPartAngleStep,
            onChanged: (v){ aim.barrelYawDegrees=v; preview(); },
          ),
          _DevNumberControl(
            label: 'مدة الانتقال لهذه الزاوية',
            value: aim.seconds,
            step: .05,
            onChanged: (v){ aim.seconds=math.max(.02,v).toDouble(); _changed(); },
          ),
        ],
      ),
    );
  }

  ui.Widget _tankPage() {
    final d = widget.world._dev;
    final t = d.tank;
    final path = t.paths[_selectedTankTarget];
    void applyTank() {
      widget.world._applyTankDeveloperPreviewTransform();
      widget.world._refreshTankDeveloperMarkers();
      _changed();
    }
    void applyPath() {
      widget.world._refreshTankDeveloperMarkers();
      _changed();
    }

    return ui.Column(
      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
      children: [
        ui.Container(
          padding: const ui.EdgeInsets.all(9),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0x22219587),
            borderRadius: ui.BorderRadius.circular(9),
          ),
          child: const ui.Text(
            'اختبار دبابة T-34 — اللعبة متوقفة. كل نقطة: توقف → دوران مستقل → حركة مستقيمة. اختصارات الكيبورد: Ctrl+Alt إظهار/إخفاء وضع المطور، Caps Lock كاميرا حرة، الأسهم حركة، Ctrl+↑/↓ صعود/نزول، Enter تشغيل مسار اللاعب المحدد.',
            style: ui.TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
        const ui.SizedBox(height: 8),
        ui.Wrap(
          spacing: 5,
          runSpacing: 5,
          children: List<ui.Widget>.generate(4, (i) => ui.ChoiceChip(
            label: ui.Text('قتل اللاعب ${i + 1}'),
            selected: _selectedTankTarget == i,
            onSelected: (_) {
              setState(() => _selectedTankTarget = i);
              widget.world._selectTankDeveloperTarget(i);
            },
          )),
        ),
        const ui.SizedBox(height: 8),
        ui.Row(children: [
          ui.Expanded(child: ui.FilledButton.icon(
            onPressed: () { widget.world._startTankDeveloperPath(_selectedTankTarget); _changed(); },
            icon: const ui.Icon(ui.Icons.play_arrow),
            label: ui.Text('تشغيل مسار ${_selectedTankTarget + 1}'),
          )),
          const ui.SizedBox(width: 6),
          ui.IconButton.filledTonal(
            tooltip: 'إيقاف',
            onPressed: () { widget.world._stopTankDeveloperPath(); _changed(); },
            icon: const ui.Icon(ui.Icons.stop),
          ),
          const ui.SizedBox(width: 4),
          ui.IconButton.filledTonal(
            tooltip: 'إعادة للبداية',
            onPressed: () { widget.world._resetTankDeveloperPath(_selectedTankTarget); _changed(); },
            icon: const ui.Icon(ui.Icons.replay),
          ),
        ]),
        const ui.Divider(height: 20),
        const ui.Text('حجم وتموضع الدبابة', style: ui.TextStyle(fontWeight: ui.FontWeight.w800)),
        _DevNumberControl(label: 'Tank X', value: t.x, step: d.nudgeStep, onChanged: (v){ t.x=v; applyTank(); }),
        _DevNumberControl(label: 'Tank Y ارتفاع', value: t.y, step: d.nudgeStep, onChanged: (v){ t.y=v; applyTank(); }),
        _DevNumberControl(label: 'Tank Z', value: t.z, step: d.nudgeStep, onChanged: (v){ t.z=v; applyTank(); }),
        _DevNumberControl(label: 'Pitch', value: t.pitchDegrees, step: d.nudgeStep, onChanged: (v){ t.pitchDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Yaw', value: t.yawDegrees, step: d.nudgeStep, onChanged: (v){ t.yawDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Roll', value: t.rollDegrees, step: d.nudgeStep, onChanged: (v){ t.rollDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'العرض Scale X', value: t.scaleX, step: .0002, onChanged: (v){ t.scaleX=math.max(.0001,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'الطول Scale Y', value: t.scaleY, step: .0002, onChanged: (v){ t.scaleY=math.max(.0001,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'الارتفاع Scale Z', value: t.scaleZ, step: .0002, onChanged: (v){ t.scaleZ=math.max(.0001,v).toDouble(); applyTank(); }),
        const ui.Divider(height: 20),
        const ui.Text('البرج والمدفع — تحكم تفصيلي', style: ui.TextStyle(fontWeight: ui.FontWeight.w800)),
        const ui.SizedBox(height: 5),
        ui.Container(
          padding: const ui.EdgeInsets.all(8),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0x1813C7D3),
            borderRadius: ui.BorderRadius.circular(8),
          ),
          child: const ui.Text(
            'النقاط: سماوي = Pivot البرج، وردي = Pivot المدفع، برتقالي = فوهة المدفع. '
            'Position يحرك الجزء نفسه، بينما Pivot يغيّر مركز الدوران بدون نقل الشكل المرئي.',
            style: ui.TextStyle(fontSize: 10.5, height: 1.4),
          ),
        ),
        const ui.SizedBox(height: 6),
        ui.Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: ui.WrapCrossAlignment.center,
          children: [
            const ui.Text('خطوة الموضع', style: ui.TextStyle(fontSize: 10.5)),
            for (final step in const [.01,.05,.1,.25,.5,1.0,2.0,5.0,10.0])
              ui.ChoiceChip(
                label: ui.Text(step.toString()),
                selected: (_tankPartPositionStep-step).abs()<.000001,
                onSelected: (_) => setState(() => _tankPartPositionStep=step),
                visualDensity: ui.VisualDensity.compact,
                labelStyle: const ui.TextStyle(fontSize: 9.5),
              ),
          ],
        ),
        ui.Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: ui.WrapCrossAlignment.center,
          children: [
            const ui.Text('خطوة الزاوية', style: ui.TextStyle(fontSize: 10.5)),
            for (final step in const [.1,.5,1.0,2.5,5.0,10.0,45.0])
              ui.ChoiceChip(
                label: ui.Text(step.toString()),
                selected: (_tankPartAngleStep-step).abs()<.000001,
                onSelected: (_) => setState(() => _tankPartAngleStep=step),
                visualDensity: ui.VisualDensity.compact,
                labelStyle: const ui.TextStyle(fontSize: 9.5),
              ),
          ],
        ),
        const ui.SizedBox(height: 8),
        const ui.Text('البرج TURRET', style: ui.TextStyle(fontWeight: ui.FontWeight.w800, color: ui.Color(0xFF61F3FF))),
        _DevNumberControl(label: 'Turret Position X', value: t.turretX, step: _tankPartPositionStep, onChanged: (v){ t.turretX=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Position Y', value: t.turretY, step: _tankPartPositionStep, onChanged: (v){ t.turretY=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Position Z', value: t.turretZ, step: _tankPartPositionStep, onChanged: (v){ t.turretZ=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Pivot X', value: t.turretPivotX, step: _tankPartPositionStep, onChanged: (v){ t.turretPivotX=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Pivot Y', value: t.turretPivotY, step: _tankPartPositionStep, onChanged: (v){ t.turretPivotY=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Pivot Z', value: t.turretPivotZ, step: _tankPartPositionStep, onChanged: (v){ t.turretPivotZ=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Pitch X', value: t.turretPitchDegrees, step: _tankPartAngleStep, onChanged: (v){ t.turretPitchDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Yaw أفقي', value: t.turretYawDegrees, step: _tankPartAngleStep, onChanged: (v){ t.turretYawDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Roll Y', value: t.turretRollDegrees, step: _tankPartAngleStep, onChanged: (v){ t.turretRollDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Turret Scale X', value: t.turretScaleX, step: _tankPartScaleStep, onChanged: (v){ t.turretScaleX=math.max(.01,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'Turret Scale Y', value: t.turretScaleY, step: _tankPartScaleStep, onChanged: (v){ t.turretScaleY=math.max(.01,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'Turret Scale Z', value: t.turretScaleZ, step: _tankPartScaleStep, onChanged: (v){ t.turretScaleZ=math.max(.01,v).toDouble(); applyTank(); }),
        ui.SizedBox(
          width: double.infinity,
          child: ui.OutlinedButton.icon(
            onPressed: () { widget.world._resetTankTurretDeveloperValues(); _changed(); },
            icon: const ui.Icon(ui.Icons.restart_alt, size: 17),
            label: const ui.Text('Reset البرج فقط'),
          ),
        ),
        const ui.SizedBox(height: 10),
        const ui.Text('المدفع / السبطانة BARREL', style: ui.TextStyle(fontWeight: ui.FontWeight.w800, color: ui.Color(0xFFFF73EA))),
        _DevNumberControl(label: 'Barrel Position X', value: t.barrelX, step: _tankPartPositionStep, onChanged: (v){ t.barrelX=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Position Y', value: t.barrelY, step: _tankPartPositionStep, onChanged: (v){ t.barrelY=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Position Z', value: t.barrelZ, step: _tankPartPositionStep, onChanged: (v){ t.barrelZ=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Pivot X', value: t.barrelPivotX, step: _tankPartPositionStep, onChanged: (v){ t.barrelPivotX=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Pivot Y', value: t.barrelPivotY, step: _tankPartPositionStep, onChanged: (v){ t.barrelPivotY=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Pivot Z', value: t.barrelPivotZ, step: _tankPartPositionStep, onChanged: (v){ t.barrelPivotZ=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Pitch X', value: t.barrelPitchDegrees, step: _tankPartAngleStep, onChanged: (v){ t.barrelPitchDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel/Gun Yaw أفقي', value: t.barrelYawDegrees, step: _tankPartAngleStep, onChanged: (v){ t.barrelYawDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Roll Y', value: t.barrelRollDegrees, step: _tankPartAngleStep, onChanged: (v){ t.barrelRollDegrees=v; applyTank(); }),
        _DevNumberControl(label: 'Barrel Scale X', value: t.barrelScaleX, step: _tankPartScaleStep, onChanged: (v){ t.barrelScaleX=math.max(.01,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'Barrel Scale Y', value: t.barrelScaleY, step: _tankPartScaleStep, onChanged: (v){ t.barrelScaleY=math.max(.01,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'Barrel Scale Z', value: t.barrelScaleZ, step: _tankPartScaleStep, onChanged: (v){ t.barrelScaleZ=math.max(.01,v).toDouble(); applyTank(); }),
        _DevNumberControl(label: 'Recoil للخلف', value: t.barrelRecoil, step: _tankPartPositionStep, onChanged: (v){ t.barrelRecoil=v; applyTank(); }),
        const ui.Text('فوهة المدفع MUZZLE', style: ui.TextStyle(fontWeight: ui.FontWeight.w700, color: ui.Color(0xFFFFB04A))),
        _DevNumberControl(label: 'Muzzle X', value: t.muzzleX, step: _tankPartPositionStep, onChanged: (v){ t.muzzleX=v; applyTank(); }),
        _DevNumberControl(label: 'Muzzle Y', value: t.muzzleY, step: _tankPartPositionStep, onChanged: (v){ t.muzzleY=v; applyTank(); }),
        _DevNumberControl(label: 'Muzzle Z', value: t.muzzleZ, step: _tankPartPositionStep, onChanged: (v){ t.muzzleZ=v; applyTank(); }),
        ui.SizedBox(
          width: double.infinity,
          child: ui.OutlinedButton.icon(
            onPressed: () { widget.world._resetTankBarrelDeveloperValues(); _changed(); },
            icon: const ui.Icon(ui.Icons.restart_alt, size: 17),
            label: const ui.Text('Reset المدفع والفوهة فقط'),
          ),
        ),
        ui.SwitchListTile.adaptive(
          dense: true,
          contentPadding: ui.EdgeInsets.zero,
          title: const ui.Text('إظهار Pivot البرج والمدفع والفوهة', style: ui.TextStyle(fontSize: 11)),
          subtitle: const ui.Text('سماوي / وردي / برتقالي', style: ui.TextStyle(fontSize: 9.5)),
          value: t.showPartMarkers,
          onChanged: (v){ t.showPartMarkers=v; widget.world._refreshTankPartMarkers(); _changed(); },
        ),
        ui.SwitchListTile.adaptive(
          dense: true,
          contentPadding: ui.EdgeInsets.zero,
          title: const ui.Text('توجيه جسم الدبابة تلقائياً مع المسار', style: ui.TextStyle(fontSize: 11)),
          subtitle: const ui.Text(
            'OFF (الموصى): زاوية كل نقطة هي نفسها بالمعاينة والتشغيل. ON: اتجاه السير تلقائي مع تصحيح محور T-34 بمقدار 180°.',
            style: ui.TextStyle(fontSize: 9.5),
          ),
          value: t.autoFacePath,
          onChanged: (v){
            t.autoFacePath=v;
            widget.world._previewTankDeveloperPoint(path.start);
            _changed();
          },
        ),
        ui.SwitchListTile.adaptive(
          dense: true,
          contentPadding: ui.EdgeInsets.zero,
          title: const ui.Text('إظهار نقاط المسار', style: ui.TextStyle(fontSize: 11)),
          value: t.showMarkers,
          onChanged: (v){ t.showMarkers=v; widget.world._refreshTankDeveloperMarkers(); _changed(); },
        ),
        const ui.Divider(height: 20),
        ui.Text('مسار قتل اللاعب ${_selectedTankTarget + 1}', style: const ui.TextStyle(fontWeight: ui.FontWeight.w800)),
        const ui.SizedBox(height: 6),
        _tankPointEditor('1 — البداية START', path.start),
        _tankPointEditor('2 — نقطة المرور الأولى WAY 1', path.way1),
        _tankPointEditor('3 — نقطة المرور الثانية WAY 2', path.way2),
        _tankPointEditor('4 — موقع الوقوف والإطلاق FIRE', path.fire, emphasize: true),
        _tankPointEditor('5 — طريق المغادرة EXIT', path.exit),
        _tankPointEditor('6 — نهاية المسار END', path.end),
        const ui.Text('التوقيت — قف ثم لف ثم امشِ', style: ui.TextStyle(fontWeight: ui.FontWeight.w800)),
        const ui.Text('كل مرحلة: توقف الدبابة، تدور في مكانها للزاوية الجديدة، ثم تمشي مستقيمة.', style: ui.TextStyle(fontSize: 9.5, color: ui.Color(0xFFB7D9DE))),
        _DevNumberControl(label: 'مدة دوران START قبل WAY1', value: path.turnToWay1Seconds, step: .05, onChanged: (v){ path.turnToWay1Seconds=math.max(.02,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مشي START → WAY1', value: path.toWay1Seconds, step: .05, onChanged: (v){ path.toWay1Seconds=math.max(.05,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مدة دوران WAY1 قبل WAY2', value: path.turnToWay2Seconds, step: .05, onChanged: (v){ path.turnToWay2Seconds=math.max(.02,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مشي WAY1 → WAY2', value: path.toWay2Seconds, step: .05, onChanged: (v){ path.toWay2Seconds=math.max(.05,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مدة دوران WAY2 قبل FIRE', value: path.turnToFireSeconds, step: .05, onChanged: (v){ path.turnToFireSeconds=math.max(.02,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مشي WAY2 → FIRE', value: path.toFireSeconds, step: .05, onChanged: (v){ path.toFireSeconds=math.max(.05,v).toDouble(); applyPath(); }),
        const ui.SizedBox(height: 8),
        ui.Container(
          padding: const ui.EdgeInsets.all(9),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0x18FFB300),
            borderRadius: ui.BorderRadius.circular(9),
            border: ui.Border.all(color: const ui.Color(0x44FFB300)),
          ),
          child: const ui.Text(
            'تسلسل التصويب عند FIRE: البرج + المدفعية يتحركان معاً في كل مرحلة. لكل Aim عندك Turret Yaw مستقل للبرج، وGun Yaw/Gun Pitch مستقلان للمدفعية. بعد Final Aim فقط تنطلق القذيفة.',
            style: ui.TextStyle(fontSize: 10.5, height: 1.45),
          ),
        ),
        const ui.SizedBox(height: 7),
        _tankAimStageEditor('التصويب 1 — AIM 1', path.aim1),
        _tankAimStageEditor('التصويب 2 — AIM 2', path.aim2),
        _tankAimStageEditor('التصويب 3 — AIM 3', path.aim3),
        _tankAimStageEditor('الزاوية النهائية قبل الإطلاق — FINAL AIM', path.finalAim, finalStage: true),
        const ui.SizedBox(height: 6),
        _DevNumberControl(label: 'مدة وصول القذيفة', value: path.shotTravelSeconds, step: .02, onChanged: (v){ path.shotTravelSeconds=math.max(.05,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'انتظار بعد القتل', value: path.holdAfterKillSeconds, step: .05, onChanged: (v){ path.holdAfterKillSeconds=math.max(0,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مدة دوران FIRE قبل EXIT', value: path.turnToExitSeconds, step: .05, onChanged: (v){ path.turnToExitSeconds=math.max(.02,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مشي FIRE → EXIT', value: path.toExitSeconds, step: .05, onChanged: (v){ path.toExitSeconds=math.max(.05,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مدة دوران EXIT قبل END', value: path.turnToEndSeconds, step: .05, onChanged: (v){ path.turnToEndSeconds=math.max(.02,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مشي EXIT → END', value: path.toEndSeconds, step: .05, onChanged: (v){ path.toEndSeconds=math.max(.05,v).toDouble(); applyPath(); }),
        _DevNumberControl(label: 'مدة الدوران النهائي عند END بعد الوصول', value: path.finalEndTurnSeconds, step: .05, onChanged: (v){ path.finalEndTurnSeconds=math.max(.02,v).toDouble(); applyPath(); }),
        const ui.SizedBox(height: 10),
        const ui.Text('ردة فعل الإطلاق RECOIL', style: ui.TextStyle(fontWeight: ui.FontWeight.w800, color: ui.Color(0xFFFFB74D))),
        const ui.Text('كل القيم أدناه تعمل فوراً عند تشغيل المسار ويمكن ضبط قوة ومدة الارتداد.', style: ui.TextStyle(fontSize: 9.5, color: ui.Color(0xFFFFD59A))),
        _DevNumberControl(label: 'ارتداد جسم الدبابة للخلف', value: t.shotHullRecoilDistance, step: .01, onChanged: (v){ t.shotHullRecoilDistance=v; widget.world._previewTankDeveloperRecoil(); _changed(); }),
        _DevNumberControl(label: 'ركلة جسم الدبابة Pitch', value: t.shotHullPitchDegrees, step: .1, onChanged: (v){ t.shotHullPitchDegrees=v; widget.world._previewTankDeveloperRecoil(); _changed(); }),
        _DevNumberControl(label: 'ارتداد المدفعية للخلف', value: t.shotBarrelRecoilDistance, step: .5, onChanged: (v){ t.shotBarrelRecoilDistance=v; widget.world._previewTankDeveloperRecoil(); _changed(); }),
        _DevNumberControl(label: 'مدة ركلة الارتداد', value: t.shotRecoilKickSeconds, step: .01, onChanged: (v){ t.shotRecoilKickSeconds=math.max(.01,v).toDouble(); _changed(); }),
        _DevNumberControl(label: 'تثبيت الارتداد', value: t.shotRecoilHoldSeconds, step: .01, onChanged: (v){ t.shotRecoilHoldSeconds=math.max(0,v).toDouble(); _changed(); }),
        _DevNumberControl(label: 'مدة الرجوع الطبيعي', value: t.shotRecoilReturnSeconds, step: .01, onChanged: (v){ t.shotRecoilReturnSeconds=math.max(.01,v).toDouble(); _changed(); }),
        ui.Row(children: [
          ui.Expanded(child: ui.OutlinedButton(
            onPressed: () { widget.world._previewTankDeveloperRecoil(1); _changed(); },
            child: const ui.Text('معاينة أقصى ارتداد'),
          )),
          const ui.SizedBox(width: 6),
          ui.Expanded(child: ui.OutlinedButton(
            onPressed: () { widget.world._previewTankDeveloperPoint(path.fire); _changed(); },
            child: const ui.Text('رجوع لوضع FIRE'),
          )),
        ]),
        const ui.SizedBox(height: 8),
        ui.SizedBox(
          width: double.infinity,
          child: ui.FilledButton.tonalIcon(
            onPressed: () {
              widget.world._copyTankPathRotationsToAll(_selectedTankTarget);
              _changed();
            },
            icon: const ui.Icon(ui.Icons.copy_all, size: 17),
            label: const ui.Text('نسخ دوران وتصويب هذا المسار إلى اللاعبين الأربعة'),
          ),
        ),
        const ui.SizedBox(height: 8),
        ui.Row(children: [
          ui.Expanded(child: ui.OutlinedButton(
            onPressed: () { path.resetToDefaults(); widget.world._refreshTankDeveloperMarkers(); _changed(); },
            child: const ui.Text('إرجاع مسار هذا اللاعب'),
          )),
          const ui.SizedBox(width: 6),
          ui.Expanded(child: ui.OutlinedButton(
            onPressed: () { t.resetToDefaults(); widget.world._applyTankDeveloperPreviewTransform(); _changed(); },
            child: const ui.Text('إرجاع حجم/دوران الدبابة'),
          )),
        ]),
        const ui.SizedBox(height: 8),
        ui.FilledButton.icon(
          onPressed: () {
            services.Clipboard.setData(services.ClipboardData(text: widget.world._tankDeveloperSettingsText()));
            setState(() => _copied = true);
            Future<void>.delayed(const Duration(milliseconds: 900), () { if (mounted) setState(() => _copied = false); });
          },
          icon: ui.Icon(_copied ? ui.Icons.check : ui.Icons.copy),
          label: ui.Text(_copied ? 'تم نسخ إعدادات الدبابة' : 'نسخ كل إعدادات الدبابة والمسارات'),
        ),
      ],
    );
  }


  ui.Widget _colorEditor(String title, ui.Color color, void Function(ui.Color) onChanged) {
    final argb = color.toARGB32();
    int r=(argb>>16)&255, g=(argb>>8)&255, b=argb&255;
    return ui.Container(
      margin: const ui.EdgeInsets.only(bottom: 6),
      padding: const ui.EdgeInsets.all(7),
      decoration: ui.BoxDecoration(color: const ui.Color(0x141FFFFFFF), borderRadius: ui.BorderRadius.circular(8)),
      child: ui.Column(crossAxisAlignment: ui.CrossAxisAlignment.start, children:[
        ui.Row(children:[
          ui.Container(width:24,height:24,decoration:ui.BoxDecoration(color:color,borderRadius:ui.BorderRadius.circular(5),border:ui.Border.all(color:const ui.Color(0x55FFFFFF)))),
          const ui.SizedBox(width:7),
          ui.Text(title, style:const ui.TextStyle(fontWeight:ui.FontWeight.w700)),
        ]),
        _DevNumberControl(label:'R',value:r.toDouble(),step:1,onChanged:(v){r=v.clamp(0,255).round();onChanged(ui.Color.fromARGB(255,r,g,b));}),
        _DevNumberControl(label:'G',value:g.toDouble(),step:1,onChanged:(v){g=v.clamp(0,255).round();onChanged(ui.Color.fromARGB(255,r,g,b));}),
        _DevNumberControl(label:'B',value:b.toDouble(),step:1,onChanged:(v){b=v.clamp(0,255).round();onChanged(ui.Color.fromARGB(255,r,g,b));}),
      ]),
    );
  }

  ui.Widget _projectilePage() {
    final p=widget.world._dev.projectile;
    void apply(){widget.world._applyProjectileDeveloperTuning();_changed();}
    return ui.Column(crossAxisAlignment:ui.CrossAxisAlignment.start,children:[
      const ui.Text('القذيفة النارية — FIREBALL VFX',style:ui.TextStyle(fontWeight:ui.FontWeight.w900,color:ui.Color(0xFFFF6B2B))),
      const ui.Text('هذه القيم تتحكم بمجسم fireball_vfx.glb نفسه، والهالة والذيل والانفجار.',style:ui.TextStyle(fontSize:10,height:1.4)),
      ui.SwitchListTile(contentPadding:ui.EdgeInsets.zero,dense:true,title:const ui.Text('إظهار القذيفة عند رأس المدفع قبل الإطلاق'),value:p.previewAtMuzzle,onChanged:(v){p.previewAtMuzzle=v;apply();}),
      _DevNumberControl(label:'Muzzle Preview X',value:p.previewOffsetX,step:.01,onChanged:(v){p.previewOffsetX=v;apply();}),
      _DevNumberControl(label:'Muzzle Preview Y',value:p.previewOffsetY,step:.01,onChanged:(v){p.previewOffsetY=v;apply();}),
      _DevNumberControl(label:'Muzzle Preview Z',value:p.previewOffsetZ,step:.01,onChanged:(v){p.previewOffsetZ=v;apply();}),
      const ui.Divider(),
      _DevNumberControl(label:'Scale X',value:p.scaleX,step:.01,onChanged:(v){p.scaleX=math.max(.01,v).toDouble();apply();}),
      _DevNumberControl(label:'Scale Y',value:p.scaleY,step:.01,onChanged:(v){p.scaleY=math.max(.01,v).toDouble();apply();}),
      _DevNumberControl(label:'Scale Z',value:p.scaleZ,step:.01,onChanged:(v){p.scaleZ=math.max(.01,v).toDouble();apply();}),
      _DevNumberControl(label:'Base Pitch',value:p.pitchDegrees,step:1,onChanged:(v){p.pitchDegrees=v;apply();}),
      _DevNumberControl(label:'Base Yaw',value:p.yawDegrees,step:1,onChanged:(v){p.yawDegrees=v;apply();}),
      _DevNumberControl(label:'Base Roll',value:p.rollDegrees,step:1,onChanged:(v){p.rollDegrees=v;apply();}),
      const ui.Divider(),
      const ui.Text('دوران الكرة أثناء الطيران (درجة/ثانية)',style:ui.TextStyle(fontWeight:ui.FontWeight.w700)),
      _DevNumberControl(label:'Spin X',value:p.spinX,step:10,onChanged:(v){p.spinX=v;apply();}),
      _DevNumberControl(label:'Spin Y',value:p.spinY,step:10,onChanged:(v){p.spinY=v;apply();}),
      _DevNumberControl(label:'Spin Z',value:p.spinZ,step:10,onChanged:(v){p.spinZ=v;apply();}),
      const ui.Divider(),
      const ui.Text('التوهج الناري',style:ui.TextStyle(fontWeight:ui.FontWeight.w800)),
      _DevNumberControl(label:'Glow inner size',value:p.glowInnerSize,step:.01,onChanged:(v){p.glowInnerSize=math.max(.01,v).toDouble();apply();}),
      _DevNumberControl(label:'Glow outer size',value:p.glowOuterSize,step:.01,onChanged:(v){p.glowOuterSize=math.max(.01,v).toDouble();apply();}),
      _DevNumberControl(label:'Glow opacity',value:p.glowOpacity,step:.05,onChanged:(v){p.glowOpacity=v.clamp(0,1).toDouble();apply();}),
      _colorEditor('لون التوهج',p.glowColor,(c){p.glowColor=c;apply();}),
      ui.SwitchListTile(contentPadding:ui.EdgeInsets.zero,title:const ui.Text('Fire Trail — الذيل الناري'),value:p.trailEnabled,onChanged:(v){p.trailEnabled=v;apply();}),
      _DevNumberControl(label:'Trail size',value:p.trailSize,step:.01,onChanged:(v){p.trailSize=math.max(.01,v).toDouble();apply();}),
      _DevNumberControl(label:'Trail spacing',value:p.trailSpacing,step:.005,onChanged:(v){p.trailSpacing=v.clamp(.005,.2).toDouble();apply();}),
      _DevNumberControl(label:'Trail opacity',value:p.trailOpacity,step:.05,onChanged:(v){p.trailOpacity=v.clamp(0,1).toDouble();apply();}),
      _colorEditor('لون الذيل',p.trailColor,(c){p.trailColor=c;apply();}),
      _DevNumberControl(label:'قوة/حجم تأثير الاصطدام',value:p.impactScale,step:.1,onChanged:(v){p.impactScale=math.max(.1,v).toDouble();apply();}),
      _DevNumberControl(label:'مدة وصول القذيفة / السرعة',value:widget.world._dev.tank.paths[_selectedTankTarget].shotTravelSeconds,step:.02,onChanged:(v){widget.world._dev.tank.paths[_selectedTankTarget].shotTravelSeconds=math.max(.05,v).toDouble();_changed();}),
      const ui.SizedBox(height:8),
      ui.FilledButton.icon(onPressed:(){widget.world._resetTankDeveloperPath(_selectedTankTarget);widget.world._startTankDeveloperPath(_selectedTankTarget);},icon:const ui.Icon(ui.Icons.play_arrow),label:const ui.Text('تشغيل المسار لمعاينة القذيفة')),
      const ui.SizedBox(height:6),
      ui.OutlinedButton.icon(onPressed:(){services.Clipboard.setData(services.ClipboardData(text:widget.world._visualDeveloperSettingsText()));},icon:const ui.Icon(ui.Icons.copy),label:const ui.Text('نسخ قيم القذيفة والخامات والشاشة')),
    ]);
  }

  ui.Widget _surfaceImageEditor(String title, _SurfaceImageTuning image, int station, String kind) {
    Future<void> rebuild() async { await widget.world._rebuildStationSurfaceTexture(station,kind); if(mounted)setState((){}); }
    return ui.Container(
      margin:const ui.EdgeInsets.only(bottom:8),padding:const ui.EdgeInsets.all(8),
      decoration:ui.BoxDecoration(color:const ui.Color(0x121FFFFFFF),borderRadius:ui.BorderRadius.circular(9),border:ui.Border.all(color:const ui.Color(0x22FFFFFF))),
      child:ui.Column(crossAxisAlignment:ui.CrossAxisAlignment.start,children:[
        ui.Text(title,style:const ui.TextStyle(fontWeight:ui.FontWeight.w800)),
        ui.Row(children:[
          ui.Expanded(child:ui.FilledButton.tonalIcon(onPressed:() async {await widget.world._pickStationSurfaceImage(station,kind);if(mounted)setState((){});},icon:const ui.Icon(ui.Icons.image),label:const ui.Text('اختيار صورة من الكمبيوتر'))),
          const ui.SizedBox(width:5),
          ui.IconButton(onPressed:(){image.enabled=false;rebuild();},tooltip:'إزالة الصورة',icon:const ui.Icon(ui.Icons.delete_outline)),
        ]),
        if(image.path.isNotEmpty) ui.Text(image.path,maxLines:2,overflow:ui.TextOverflow.ellipsis,style:const ui.TextStyle(fontSize:8.5,color:ui.Color(0xAAFFFFFF))),
        ui.SwitchListTile(contentPadding:ui.EdgeInsets.zero,dense:true,title:const ui.Text('إظهار الصورة'),value:image.enabled,onChanged:(v){image.enabled=v;rebuild();}),
        ui.Wrap(spacing:4,children:[
          for(final e in const [(0,'Stretch'),(1,'Fit'),(2,'Fill'),(3,'Tile')])
            ui.ChoiceChip(label:ui.Text(e.$2,style:const ui.TextStyle(fontSize:9)),selected:image.mode==e.$1,onSelected:(_){image.mode=e.$1;rebuild();}),
        ]),
        _DevNumberControl(label:'Repeat X',value:image.repeatX,step:1,onChanged:(v){image.repeatX=math.max(1,v).toDouble();rebuild();}),
        _DevNumberControl(label:'Repeat Y',value:image.repeatY,step:1,onChanged:(v){image.repeatY=math.max(1,v).toDouble();rebuild();}),
        _DevNumberControl(label:'Image Scale',value:image.imageScale,step:.05,onChanged:(v){image.imageScale=math.max(.05,v).toDouble();rebuild();}),
        _DevNumberControl(label:'Image Offset X',value:image.offsetX,step:.02,onChanged:(v){image.offsetX=v;rebuild();}),
        _DevNumberControl(label:'Image Offset Y',value:image.offsetY,step:.02,onChanged:(v){image.offsetY=v;rebuild();}),
        _DevNumberControl(label:'Image Rotation',value:image.rotationDegrees,step:5,onChanged:(v){image.rotationDegrees=v;rebuild();}),
      ]),
    );
  }

  ui.Widget _surfacesPage() {
    final t=widget.world._dev.surfaces[_selectedStation];
    void apply(){widget.world._applyStationSurfaceTuning(_selectedStation);_changed();}
    return ui.Column(crossAxisAlignment:ui.CrossAxisAlignment.start,children:[
      const ui.Text('ألوان وصور الكراسي والطاولات والتوقيت',style:ui.TextStyle(fontWeight:ui.FontWeight.w900)),
      ui.Wrap(spacing:4,children:List.generate(4,(i)=>ui.ChoiceChip(label:ui.Text('لاعب ${i+1}'),selected:_selectedStation==i,onSelected:(_){setState(()=>_selectedStation=i);widget.world._selectDeveloperStation(i);}))),
      const ui.SizedBox(height:7),
      _colorEditor('لون الكرسي',t.chairColor,(c){t.chairColor=c;apply();}),
      _colorEditor('لون هيكل الكرسي',t.chairFrameColor,(c){t.chairFrameColor=c;apply();}),
      _colorEditor('لون الطاولة',t.deskColor,(c){t.deskColor=c;apply();}),
      _DevNumberControl(label:'استدارة حواف الكرسي',value:t.chairCornerRadius,step:.005,onChanged:(v){t.chairCornerRadius=v.clamp(0,.26).toDouble();apply();}),
      _surfaceImageEditor('صورة الكرسي',t.chairImage,_selectedStation,'chair'),
      _surfaceImageEditor('صورة الطاولة',t.deskImage,_selectedStation,'desk'),
      const ui.Divider(),
      const ui.Text('مؤقت الكرسي — اللون/الموضع/الميلان/الدوران',style:ui.TextStyle(fontWeight:ui.FontWeight.w800)),
      _colorEditor('لون خلفية التوقيت',t.timerFaceColor,(c){t.timerFaceColor=c;apply();}),
      _colorEditor('لون أرقام التوقيت',t.timerDigitColor,(c){t.timerDigitColor=c;apply();}),
      _DevNumberControl(label:'Timer X',value:t.timerX,step:.01,onChanged:(v){t.timerX=v;apply();}),
      _DevNumberControl(label:'Timer Y — فوق/تحت',value:t.timerY,step:.01,onChanged:(v){t.timerY=v;apply();}),
      _DevNumberControl(label:'Timer Z — أمام/خلف',value:t.timerZ,step:.01,onChanged:(v){t.timerZ=v;apply();}),
      _DevNumberControl(label:'Timer Pitch — ميلان فوق/تحت',value:t.timerPitchDegrees,step:1,onChanged:(v){t.timerPitchDegrees=v;apply();}),
      _DevNumberControl(label:'Timer Yaw — يمين/يسار',value:t.timerYawDegrees,step:1,onChanged:(v){t.timerYawDegrees=v;apply();}),
      _DevNumberControl(label:'Timer Roll',value:t.timerRollDegrees,step:1,onChanged:(v){t.timerRollDegrees=v;apply();}),
      _DevNumberControl(label:'Timer Width Scale',value:t.timerScaleX,step:.05,onChanged:(v){t.timerScaleX=math.max(.1,v).toDouble();apply();}),
      _DevNumberControl(label:'Timer Height Scale',value:t.timerScaleY,step:.05,onChanged:(v){t.timerScaleY=math.max(.1,v).toDouble();apply();}),
      _DevNumberControl(label:'استدارة حواف جسم المؤقت',value:t.timerCornerRadius,step:.005,onChanged:(v){t.timerCornerRadius=v.clamp(0,.07).toDouble();apply();}),
      _surfaceImageEditor('صورة/خلفية التوقيت',t.timerImage,_selectedStation,'timer'),
      ui.OutlinedButton.icon(onPressed:(){services.Clipboard.setData(services.ClipboardData(text:widget.world._visualDeveloperSettingsText()));},icon:const ui.Icon(ui.Icons.copy),label:const ui.Text('نسخ قيم الخامات والتوقيت')),
    ]);
  }

  ui.Widget _environmentPage() {
    final d = widget.world._dev;
    final e = d.environment;
    final index = _selectedMountain.clamp(0, e.mountains.length - 1).toInt();
    final m = e.mountains[index];
    void apply() {
      widget.world._applyEnvironmentDeveloperSettings();
      _changed();
    }

    return ui.Column(
      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
      children: [
        ui.Container(
          padding: const ui.EdgeInsets.all(9),
          margin: const ui.EdgeInsets.only(bottom: 8),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0x223F51B5),
            borderRadius: ui.BorderRadius.circular(10),
          ),
          child: const ui.Text(
            'هذه الصفحة تضيف أرضية خارجية ممتدة وسلسلة جبال دائرية حول الماب. تقدر تغيّر الحجم، المكان، الدوران، وعدد الجبال، وبعدها تعدّل كل جبل وحده أيضاً.',
            style: ui.TextStyle(fontSize: 11, height: 1.45),
          ),
        ),
        ui.SwitchListTile.adaptive(
          dense: true,
          contentPadding: ui.EdgeInsets.zero,
          title: const ui.Text('إظهار الأرضية الخارجية', style: ui.TextStyle(fontSize: 11)),
          value: e.showGround,
          onChanged: (v){ e.showGround = v; apply(); },
        ),
        _colorEditor('لون الأرضية الخارجية', e.groundColor, (c){ e.groundColor = c; apply(); }),
        _DevNumberControl(label: 'Ground X', value: e.groundX, step: d.nudgeStep, onChanged: (v){ e.groundX=v; apply(); }),
        _DevNumberControl(label: 'Ground Y', value: e.groundY, step: d.nudgeStep, onChanged: (v){ e.groundY=v; apply(); }),
        _DevNumberControl(label: 'Ground Z', value: e.groundZ, step: d.nudgeStep, onChanged: (v){ e.groundZ=v; apply(); }),
        _DevNumberControl(label: 'عرض الأرضية', value: e.groundWidth, step: .25, onChanged: (v){ e.groundWidth=math.max(1,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'سماكة الأرضية', value: e.groundThickness, step: .05, onChanged: (v){ e.groundThickness=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'عمق الأرضية', value: e.groundDepth, step: .25, onChanged: (v){ e.groundDepth=math.max(1,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'Ground Pitch', value: e.groundPitchDegrees, step: .25, onChanged: (v){ e.groundPitchDegrees=v; apply(); }),
        _DevNumberControl(label: 'Ground Yaw', value: e.groundYawDegrees, step: .25, onChanged: (v){ e.groundYawDegrees=v; apply(); }),
        _DevNumberControl(label: 'Ground Roll', value: e.groundRollDegrees, step: .25, onChanged: (v){ e.groundRollDegrees=v; apply(); }),
        const ui.Divider(height: 20),
        ui.SwitchListTile.adaptive(
          dense: true,
          contentPadding: ui.EdgeInsets.zero,
          title: const ui.Text('إظهار الجبال', style: ui.TextStyle(fontSize: 11)),
          value: e.showMountains,
          onChanged: (v){ e.showMountains = v; apply(); },
        ),
        _DevNumberControl(label: 'عدد الجبال الظاهرة', value: e.mountainCount.toDouble(), step: 1, onChanged: (v){ e.mountainCount=v.round().clamp(0, e.mountains.length).toInt(); apply(); }),
        _DevNumberControl(label: 'مركز الجبال X', value: e.centerX, step: d.nudgeStep, onChanged: (v){ e.centerX=v; apply(); }),
        _DevNumberControl(label: 'مركز الجبال Y', value: e.centerY, step: d.nudgeStep, onChanged: (v){ e.centerY=v; apply(); }),
        _DevNumberControl(label: 'مركز الجبال Z', value: e.centerZ, step: d.nudgeStep, onChanged: (v){ e.centerZ=v; apply(); }),
        _DevNumberControl(label: 'نصف قطر الحلقة', value: e.ringRadius, step: .25, onChanged: (v){ e.ringRadius=math.max(.1,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'مدى الحلقة بالدرجات', value: e.arcDegrees, step: 1, onChanged: (v){ e.arcDegrees=v; apply(); }),
        _DevNumberControl(label: 'بداية الحلقة', value: e.startAngleDegrees, step: 1, onChanged: (v){ e.startAngleDegrees=v; apply(); }),
        _DevNumberControl(label: 'تكبير الجبال X', value: e.scaleX, step: .05, onChanged: (v){ e.scaleX=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'تكبير الجبال Y', value: e.scaleY, step: .05, onChanged: (v){ e.scaleY=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'تكبير الجبال Z', value: e.scaleZ, step: .05, onChanged: (v){ e.scaleZ=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'دوران أساسي Pitch', value: e.basePitchDegrees, step: .5, onChanged: (v){ e.basePitchDegrees=v; apply(); }),
        _DevNumberControl(label: 'دوران أساسي Yaw', value: e.baseYawDegrees, step: .5, onChanged: (v){ e.baseYawDegrees=v; apply(); }),
        _DevNumberControl(label: 'دوران أساسي Roll', value: e.baseRollDegrees, step: .5, onChanged: (v){ e.baseRollDegrees=v; apply(); }),
        _DevNumberControl(label: 'زاوية مواجهة المركز', value: e.faceCenterYawOffsetDegrees, step: .5, onChanged: (v){ e.faceCenterYawOffsetDegrees=v; apply(); }),
        const ui.Divider(height: 20),
        const ui.Text('تعديل جبل منفرد', style: ui.TextStyle(fontWeight: ui.FontWeight.w800)),
        const ui.SizedBox(height: 6),
        ui.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < e.mountains.length; i++)
              ui.ChoiceChip(
                label: ui.Text('${i + 1}'),
                selected: _selectedMountain == i,
                onSelected: (_) => setState(() => _selectedMountain = i),
              ),
          ],
        ),
        ui.SwitchListTile.adaptive(
          dense: true,
          contentPadding: ui.EdgeInsets.zero,
          title: ui.Text('تفعيل الجبل ${index + 1}', style: const ui.TextStyle(fontSize: 11)),
          value: m.enabled,
          onChanged: (v){ m.enabled=v; apply(); },
        ),
        _colorEditor('لون الجبل ${index + 1}', m.color, (c){ m.color = c; apply(); }),
        _DevNumberControl(label: 'Offset X', value: m.x, step: d.nudgeStep, onChanged: (v){ m.x=v; apply(); }),
        _DevNumberControl(label: 'Offset Y', value: m.y, step: d.nudgeStep, onChanged: (v){ m.y=v; apply(); }),
        _DevNumberControl(label: 'Offset Z', value: m.z, step: d.nudgeStep, onChanged: (v){ m.z=v; apply(); }),
        _DevNumberControl(label: 'Radius Offset', value: m.radiusOffset, step: .10, onChanged: (v){ m.radiusOffset=v; apply(); }),
        _DevNumberControl(label: 'Scale X', value: m.scaleX, step: .05, onChanged: (v){ m.scaleX=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'Scale Y', value: m.scaleY, step: .05, onChanged: (v){ m.scaleY=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'Scale Z', value: m.scaleZ, step: .05, onChanged: (v){ m.scaleZ=math.max(.01,v).toDouble(); apply(); }),
        _DevNumberControl(label: 'Pitch', value: m.pitchDegrees, step: .5, onChanged: (v){ m.pitchDegrees=v; apply(); }),
        _DevNumberControl(label: 'Yaw', value: m.yawDegrees, step: .5, onChanged: (v){ m.yawDegrees=v; apply(); }),
        _DevNumberControl(label: 'Roll', value: m.rollDegrees, step: .5, onChanged: (v){ m.rollDegrees=v; apply(); }),
        const ui.SizedBox(height: 8),
        ui.Row(
          children: [
            ui.Expanded(
              child: ui.OutlinedButton.icon(
                onPressed: () { e.mountains[index].resetToDefaults(); apply(); },
                icon: const ui.Icon(ui.Icons.landscape, size: 17),
                label: ui.Text('إرجاع الجبل ${index + 1}'),
              ),
            ),
            const ui.SizedBox(width: 7),
            ui.Expanded(
              child: ui.OutlinedButton.icon(
                onPressed: () { e.resetToDefaults(); apply(); },
                icon: const ui.Icon(ui.Icons.refresh, size: 17),
                label: const ui.Text('إرجاع البيئة كلها'),
              ),
            ),
          ],
        ),
        const ui.SizedBox(height: 8),
        ui.FilledButton.icon(
          onPressed: () {
            services.Clipboard.setData(services.ClipboardData(text: widget.world._environmentDeveloperSettingsText()));
            setState(() => _copied = true);
            Future<void>.delayed(const Duration(milliseconds: 900), () { if (mounted) setState(() => _copied = false); });
          },
          icon: ui.Icon(_copied ? ui.Icons.check : ui.Icons.copy, size: 18),
          label: ui.Text(_copied ? 'تم نسخ قيم البيئة' : 'نسخ قيم البيئة والجبال'),
        ),
      ],
    );
  }


  ui.Widget _bigScreenPage() {
    final t=widget.world._dev.bigScreen;
    void apply(){widget.world._applyBigScreenDeveloperTuning();_changed();}
    return ui.Column(crossAxisAlignment:ui.CrossAxisAlignment.start,children:[
      const ui.Text('الشاشة الكبيرة — 3D حقيقية',style:ui.TextStyle(fontWeight:ui.FontWeight.w900)),
      const ui.Text('تكبير الأطراف يغيّر الإطار والـbezel وسطح العرض معاً. النص يبقى Texture مدمج داخل الشاشة.',style:ui.TextStyle(fontSize:10,height:1.4)),
      _colorEditor('لون إطار التلفاز',t.frameColor,(c){t.frameColor=c;apply();}),
      _colorEditor('لون الحافة الداخلية Bezel',t.bezelColor,(c){t.bezelColor=c;apply();}),
      _colorEditor('لون خلفية الشاشة',t.screenColor,(c){t.screenColor=c;apply();}),
      _DevNumberControl(label:'استدارة حواف إطار التلفاز',value:t.frameCornerRadius,step:.02,onChanged:(v){t.frameCornerRadius=math.max(0,v).toDouble();apply();}),
      const ui.Text('وضع المطور يعرض الآن بيانات ترتيب اختبارية دائمًا حتى تقدر تضبط النصوص وهي اللعبة متوقفة.',style:ui.TextStyle(fontSize:9.5,color:ui.Color(0xCCFFFFFF))),
      _DevNumberControl(label:'Position X',value:t.x,step:.05,onChanged:(v){t.x=v;apply();}),
      _DevNumberControl(label:'Position Y',value:t.y,step:.05,onChanged:(v){t.y=v;apply();}),
      _DevNumberControl(label:'Position Z — تقديم/ترجيع',value:t.z,step:.05,onChanged:(v){t.z=v;apply();}),
      _DevNumberControl(label:'Pitch — ميلان فوق/تحت',value:t.pitchDegrees,step:1,onChanged:(v){t.pitchDegrees=v;apply();}),
      _DevNumberControl(label:'Yaw — يمين/يسار',value:t.yawDegrees,step:1,onChanged:(v){t.yawDegrees=v;apply();}),
      _DevNumberControl(label:'Roll',value:t.rollDegrees,step:1,onChanged:(v){t.rollDegrees=v;apply();}),
      const ui.Divider(),
      _DevNumberControl(label:'تكبير من اليسار LEFT',value:t.left,step:.05,onChanged:(v){t.left=v;apply();}),
      _DevNumberControl(label:'تكبير من اليمين RIGHT',value:t.right,step:.05,onChanged:(v){t.right=v;apply();}),
      _DevNumberControl(label:'تكبير من فوق TOP',value:t.top,step:.05,onChanged:(v){t.top=v;apply();}),
      _DevNumberControl(label:'تكبير من تحت BOTTOM',value:t.bottom,step:.05,onChanged:(v){t.bottom=v;apply();}),
      const ui.Divider(),
      const ui.Text('النصوص داخل Texture الشاشة',style:ui.TextStyle(fontWeight:ui.FontWeight.w800)),
      _DevNumberControl(label:'حجم كل النصوص',value:t.globalTextScale,step:.05,onChanged:(v){t.globalTextScale=math.max(.2,v).toDouble();apply();}),
      _DevNumberControl(label:'كل النصوص X',value:t.globalTextX,step:10,onChanged:(v){t.globalTextX=v;apply();}),
      _DevNumberControl(label:'كل النصوص Y',value:t.globalTextY,step:10,onChanged:(v){t.globalTextY=v;apply();}),
      _DevNumberControl(label:'حجم عنوان الجدول',value:t.headerFontSize,step:2,onChanged:(v){t.headerFontSize=math.max(8,v).toDouble();apply();}),
      _DevNumberControl(label:'عنوان الجدول X',value:t.headerX,step:10,onChanged:(v){t.headerX=v;apply();}),
      _DevNumberControl(label:'عنوان الجدول Y',value:t.headerY,step:5,onChanged:(v){t.headerY=v;apply();}),
      _DevNumberControl(label:'حجم نص الصفوف',value:t.rowFontSize,step:2,onChanged:(v){t.rowFontSize=math.max(8,v).toDouble();apply();}),
      _DevNumberControl(label:'Rows X',value:t.rowsX,step:10,onChanged:(v){t.rowsX=v;apply();}),
      _DevNumberControl(label:'أول صف Y',value:t.rowsStartY,step:10,onChanged:(v){t.rowsStartY=v;apply();}),
      _DevNumberControl(label:'المسافة بين الصفوف',value:t.rowGap,step:5,onChanged:(v){t.rowGap=v;apply();}),
      _DevNumberControl(label:'عرض خلفية الصف',value:t.rowWidth,step:10,onChanged:(v){t.rowWidth=math.max(200,v).toDouble();apply();}),
      _DevNumberControl(label:'ارتفاع خلفية الصف',value:t.rowHeight,step:5,onChanged:(v){t.rowHeight=math.max(40,v).toDouble();apply();}),
      _DevNumberControl(label:'النص داخل الصف Y',value:t.rowTextYOffset,step:5,onChanged:(v){t.rowTextYOffset=v;apply();}),
      ui.OutlinedButton.icon(onPressed:(){services.Clipboard.setData(services.ClipboardData(text:widget.world._visualDeveloperSettingsText()));},icon:const ui.Icon(ui.Icons.copy),label:const ui.Text('نسخ قيم الشاشة والنصوص')),
    ]);
  }

  ui.Widget _mapPage() {
    final d = widget.world._dev;
    return ui.Column(
      children: [
        ui.Container(
          width: double.infinity,
          padding: ui.EdgeInsets.all(9),
          margin: ui.EdgeInsets.only(bottom: 7),
          decoration: ui.BoxDecoration(
            color: ui.Color(0x33219587),
            borderRadius: ui.BorderRadius.all(ui.Radius.circular(9)),
          ),
          child: ui.Text(
            'هذه القيم تحرك وتدور surveillance_room.glb فقط. الكراسي واللاعبون والطاولات وباقي عناصر اللعبة ثابتة.',
            style: ui.TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
        _DevNumberControl(
          label: 'X يمين / يسار',
          value: d.mapX,
          step: d.nudgeStep,
          onChanged: (v) {
            d.mapX = v;
            _changed(true);
          },
        ),
        _DevNumberControl(
          label: 'Y أعلى / أسفل',
          value: d.mapY,
          step: d.nudgeStep,
          onChanged: (v) {
            d.mapY = v;
            _changed(true);
          },
        ),
        _DevNumberControl(
          label: 'Z أمام / خلف',
          value: d.mapZ,
          step: d.nudgeStep,
          onChanged: (v) {
            d.mapZ = v;
            _changed(true);
          },
        ),
        const ui.Divider(height: 14),
        _DevNumberControl(
          label: 'Pitch زاوية X',
          value: d.mapPitchDegrees,
          step: d.nudgeStep,
          onChanged: (v) {
            d.mapPitchDegrees = v;
            _changed(true);
          },
        ),
        _DevNumberControl(
          label: 'Yaw زاوية Y',
          value: d.mapYawDegrees,
          step: d.nudgeStep,
          onChanged: (v) {
            d.mapYawDegrees = v;
            _changed(true);
          },
        ),
        _DevNumberControl(
          label: 'Roll زاوية Z',
          value: d.mapRollDegrees,
          step: d.nudgeStep,
          onChanged: (v) {
            d.mapRollDegrees = v;
            _changed(true);
          },
        ),
        const ui.SizedBox(height: 8),
        ui.SizedBox(
          width: double.infinity,
          child: ui.OutlinedButton.icon(
            onPressed: () {
              d.resetMap();
              _changed(true);
            },
            icon: const ui.Icon(ui.Icons.restart_alt, size: 18),
            label: const ui.Text('إرجاع الماب إلى الصفر'),
          ),
        ),
      ],
    );
  }

  ui.Widget _cameraPage() {
    final d = widget.world._dev;
    final move = d.flyStep;

    ui.Widget moveButton(ui.IconData icon, String tooltip, void Function() action) {
      return ui.Tooltip(
        message: tooltip,
        child: ui.SizedBox(
          width: 54,
          height: 46,
          child: ui.OutlinedButton(
            style: ui.OutlinedButton.styleFrom(
              padding: ui.EdgeInsets.zero,
              minimumSize: const ui.Size(46, 42),
            ),
            onPressed: widget.world._developerFreeCameraEnabled
                ? () {
                    action();
                    _changed();
                  }
                : null,
            child: ui.Icon(icon, size: 22),
          ),
        ),
      );
    }

    return ui.Column(
      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
      children: [
        ui.Container(
          padding: const ui.EdgeInsets.all(9),
          decoration: ui.BoxDecoration(
            color: widget.world._developerFreeCameraEnabled
                ? const ui.Color(0x33E58A24)
                : const ui.Color(0x221E88E5),
            borderRadius: ui.BorderRadius.circular(9),
          ),
          child: ui.Text(
            widget.world._developerFreeCameraEnabled
                ? 'الكاميرا الحرة مفعلة. تحرك بأي مكان، واختيار لاعب من تبويب اللاعبين لن يغيّر موقع الكاميرا.'
                : 'فعّل الكاميرا الحرة من الزر أعلى اللوحة حتى تستخدم أدوات التجوال أدناه.',
            style: const ui.TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
        const ui.SizedBox(height: 8),
        ui.Wrap(
          crossAxisAlignment: ui.WrapCrossAlignment.center,
          spacing: 5,
          runSpacing: 5,
          children: [
            const ui.Text('سرعة الحركة', style: ui.TextStyle(fontSize: 11)),
            for (final step in const [.05, .10, .25, .50, 1.0, 2.0, 5.0])
              ui.ChoiceChip(
                label: ui.Text(step.toString()),
                selected: (d.flyStep - step).abs() < .000001,
                onSelected: (_) {
                  d.flyStep = step;
                  _changed();
                },
                visualDensity: ui.VisualDensity.compact,
                labelStyle: const ui.TextStyle(fontSize: 10),
              ),
          ],
        ),
        const ui.SizedBox(height: 10),
        ui.Row(
          mainAxisAlignment: ui.MainAxisAlignment.center,
          children: [
            moveButton(ui.Icons.arrow_upward, 'أمام', () =>
                widget.world._moveDeveloperCamera(forward: move)),
          ],
        ),
        const ui.SizedBox(height: 4),
        ui.Row(
          mainAxisAlignment: ui.MainAxisAlignment.center,
          children: [
            moveButton(ui.Icons.arrow_back, 'يسار', () =>
                widget.world._moveDeveloperCamera(right: -move)),
            const ui.SizedBox(width: 4),
            moveButton(ui.Icons.arrow_downward, 'خلف', () =>
                widget.world._moveDeveloperCamera(forward: -move)),
            const ui.SizedBox(width: 4),
            moveButton(ui.Icons.arrow_forward, 'يمين', () =>
                widget.world._moveDeveloperCamera(right: move)),
          ],
        ),
        const ui.SizedBox(height: 6),
        ui.Row(
          mainAxisAlignment: ui.MainAxisAlignment.center,
          children: [
            moveButton(ui.Icons.vertical_align_top, 'أعلى', () =>
                widget.world._moveDeveloperCamera(up: move)),
            const ui.SizedBox(width: 8),
            moveButton(ui.Icons.vertical_align_bottom, 'أسفل', () =>
                widget.world._moveDeveloperCamera(up: -move)),
          ],
        ),
        const ui.SizedBox(height: 12),
        ui.SizedBox(
          width: double.infinity,
          height: 125,
          child: ui.GestureDetector(
            behavior: ui.HitTestBehavior.opaque,
            onPanUpdate: (details) {
              d.cameraYawDegrees += details.delta.dx * .30;
              d.cameraPitchDegrees =
                  (d.cameraPitchDegrees - details.delta.dy * .30)
                      .clamp(-89.5, 89.5)
                      .toDouble();
              _changed();
            },
            child: ui.DecoratedBox(
              decoration: ui.BoxDecoration(
                color: const ui.Color(0xFF0E1519),
                borderRadius: ui.BorderRadius.circular(12),
                border: ui.Border.all(color: const ui.Color(0xFF34434B)),
              ),
              child: const ui.Center(
                child: ui.Column(
                  mainAxisSize: ui.MainAxisSize.min,
                  children: [
                    ui.Icon(ui.Icons.threesixty, size: 28),
                    ui.SizedBox(height: 5),
                    ui.Text(
                      'اسحب هنا بالماوس للنظر 360° يمين / يسار / أعلى / أسفل',
                      textAlign: ui.TextAlign.center,
                      style: ui.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const ui.SizedBox(height: 10),
        _DevNumberControl(
          label: 'Camera X',
          value: d.cameraX,
          step: d.nudgeStep,
          onChanged: (v) {
            d.cameraX = v;
            _changed();
          },
        ),
        _DevNumberControl(
          label: 'Camera Y',
          value: d.cameraY,
          step: d.nudgeStep,
          onChanged: (v) {
            d.cameraY = v;
            _changed();
          },
        ),
        _DevNumberControl(
          label: 'Camera Z',
          value: d.cameraZ,
          step: d.nudgeStep,
          onChanged: (v) {
            d.cameraZ = v;
            _changed();
          },
        ),
        _DevNumberControl(
          label: 'Look Yaw',
          value: d.cameraYawDegrees,
          step: d.nudgeStep,
          onChanged: (v) {
            d.cameraYawDegrees = v;
            _changed();
          },
        ),
        _DevNumberControl(
          label: 'Look Pitch',
          value: d.cameraPitchDegrees,
          step: d.nudgeStep,
          onChanged: (v) {
            d.cameraPitchDegrees = v.clamp(-89.5, 89.5).toDouble();
            _changed();
          },
        ),
        _DevNumberControl(
          label: 'FOV',
          value: d.cameraFovDegrees,
          step: d.nudgeStep,
          onChanged: (v) {
            d.cameraFovDegrees = v.clamp(5.0, 170.0).toDouble();
            _changed();
          },
        ),
        const ui.SizedBox(height: 8),
        ui.SizedBox(
          width: double.infinity,
          child: ui.OutlinedButton.icon(
            onPressed: () {
              widget.world._resetDeveloperCameraToDefaultView();
              _changed();
            },
            icon: const ui.Icon(ui.Icons.restart_alt, size: 18),
            label: const ui.Text('إرجاع كاميرا التجوال للبداية'),
          ),
        ),
      ],
    );
  }

  ui.Widget _valuesPage() {
    final text = widget.world._developerSettingsText();
    return ui.Column(
      crossAxisAlignment: ui.CrossAxisAlignment.stretch,
      children: [
        ui.Container(
          padding: const ui.EdgeInsets.all(10),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0xFF081014),
            borderRadius: ui.BorderRadius.circular(10),
          ),
          child: ui.SelectableText(
            text,
            textDirection: ui.TextDirection.ltr,
            style: const ui.TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
        const ui.SizedBox(height: 8),
        ui.FilledButton.icon(
          style: ui.FilledButton.styleFrom(backgroundColor: const ui.Color(0xFF6A4A20)),
          onPressed: () {
            services.Clipboard.setData(services.ClipboardData(text: widget.world._tankDeveloperSettingsText()));
            setState(() => _copied = true);
            Future<void>.delayed(const Duration(milliseconds: 900), () { if (mounted) setState(() => _copied = false); });
          },
          icon: const ui.Icon(ui.Icons.directions_car_filled, size: 18),
          label: const ui.Text('نسخ إعدادات الدبابة والمسارات'),
        ),
        const ui.SizedBox(height: 6),
        ui.FilledButton.icon(
          onPressed: () {
            services.Clipboard.setData(
              services.ClipboardData(
                text: [widget.world._developerStationsSettingsText(), '-------------------------------', widget.world._developerPlayerPosesSettingsText()].join('\n'),
              ),
            );
            setState(() => _copied = true);
            Future<void>.delayed(const Duration(milliseconds: 900), () {
              if (mounted) setState(() => _copied = false);
            });
          },
          icon: ui.Icon(_copied ? ui.Icons.check : ui.Icons.copy, size: 18),
          label: ui.Text(_copied ? 'تم نسخ اللاعبين والوضعيات' : 'نسخ قيم اللاعبين + وضعياتهم'),
        ),
        const ui.SizedBox(height: 6),
        ui.OutlinedButton.icon(
          onPressed: _copy,
          icon: const ui.Icon(ui.Icons.copy_all, size: 18),
          label: const ui.Text('نسخ الماب + موقع كاميرا التجوال'),
        ),
      ],
    );
  }

  @override
  ui.Widget build(ui.BuildContext context) {
    final mediaSize = ui.MediaQuery.sizeOf(context);
    final topPadding = ui.MediaQuery.paddingOf(context).top;
    final maxHeight =
        math.max(220.0, mediaSize.height - topPadding - 20.0);
    final requestedWidth = _collapsed ? 210.0 : 430.0;
    final panelWidth = math.min(requestedWidth, math.max(180.0, mediaSize.width - 20.0));

    return ui.Positioned(
      left: 10,
      top: topPadding + 10,
      child: ui.Material(
        color: ui.Colors.transparent,
        child: ui.Container(
          width: panelWidth,
          constraints: ui.BoxConstraints(maxHeight: maxHeight),
          decoration: ui.BoxDecoration(
            color: const ui.Color(0xF2151C20),
            borderRadius: ui.BorderRadius.circular(14),
            border: ui.Border.all(color: const ui.Color(0xFF38545B)),
            boxShadow: const [
              ui.BoxShadow(
                blurRadius: 18,
                spreadRadius: 2,
                color: ui.Color(0x66000000),
              ),
            ],
          ),
          child: ui.Directionality(
            textDirection: ui.TextDirection.rtl,
            child: ui.Padding(
              padding: const ui.EdgeInsets.all(10),
              child: ui.Column(
                mainAxisSize: ui.MainAxisSize.min,
                children: [
                  ui.Row(
                    children: [
                      const ui.Expanded(
                        child: ui.Text(
                          'وضع المطور — اللعبة متوقفة للتعديل',
                          style: ui.TextStyle(
                            fontSize: 14,
                            fontWeight: ui.FontWeight.w700,
                          ),
                        ),
                      ),
                      ui.IconButton(
                        tooltip: _collapsed ? 'فتح' : 'تصغير',
                        onPressed: () =>
                            setState(() => _collapsed = !_collapsed),
                        icon: ui.Icon(
                          _collapsed
                              ? ui.Icons.unfold_more
                              : ui.Icons.unfold_less,
                        ),
                      ),
                      ui.IconButton(
                        tooltip: 'إخفاء',
                        onPressed: widget.world._removeDeveloperOverlay,
                        icon: const ui.Icon(ui.Icons.close),
                      ),
                    ],
                  ),
                  if (!_collapsed) ...[
                    const ui.SizedBox(height: 4),
                    ui.SizedBox(
                      width: double.infinity,
                      child: ui.FilledButton.icon(
                        style: ui.FilledButton.styleFrom(
                          backgroundColor: widget.world._developerFreeCameraEnabled
                              ? const ui.Color(0xFFE58A24)
                              : const ui.Color(0xFF243238),
                        ),
                        onPressed: () {
                          widget.world._setDeveloperFreeCameraEnabled(
                            !widget.world._developerFreeCameraEnabled,
                          );
                          setState(() {});
                        },
                        icon: ui.Icon(
                          widget.world._developerFreeCameraEnabled
                              ? ui.Icons.videocam
                              : ui.Icons.videocam_outlined,
                          size: 18,
                        ),
                        label: ui.Text(
                          widget.world._developerFreeCameraEnabled
                              ? 'الكاميرا الحرة مفعلة — اختيار لاعب لن ينقل الكاميرا'
                              : 'تفعيل الكاميرا الحرة',
                          style: const ui.TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const ui.SizedBox(height: 7),
                    ui.Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _tab('الدبابة', 0),
                        _tab('اللاعبون', 1),
                        _tab('الجسم', 2),
                        _tab('الماب', 3),
                        _tab('الكاميرا', 4),
                        _tab('القيم', 5),
                        _tab('القذيفة', 6),
                        _tab('الخامات', 7),
                        _tab('الشاشة', 8),
                        _tab('البيئة', 9),
                      ],
                    ),
                    const ui.SizedBox(height: 8),
                    _stepControl(),
                    const ui.Divider(height: 16),
                    ui.Flexible(
                      child: ui.SingleChildScrollView(
                        padding: const ui.EdgeInsets.only(bottom: 72),
                        child: switch (_page) {
                          0 => _tankPage(),
                          1 => _stationPage(),
                          2 => _posePage(),
                          3 => _mapPage(),
                          4 => _cameraPage(),
                          5 => _valuesPage(),
                          6 => _projectilePage(),
                          7 => _surfacesPage(),
                          8 => _bigScreenPage(),
                          _ => _environmentPage(),
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DevNumberControl extends ui.StatefulWidget {
  const _DevNumberControl({
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double step;
  final ui.ValueChanged<double> onChanged;

  @override
  ui.State<_DevNumberControl> createState() => _DevNumberControlState();
}

class _DevNumberControlState extends ui.State<_DevNumberControl> {
  late final ui.TextEditingController _controller;
  final ui.FocusNode _focusNode = ui.FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = ui.TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _DevNumberControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        (oldWidget.value - widget.value).abs() > .0000001) {
      _controller.text = _format(widget.value);
    }
  }

  String _format(double value) {
    final fixed = value.toStringAsFixed(4);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _set(double value) {
    widget.onChanged(value);
    _controller.text = _format(value);
    _controller.selection = services.TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  ui.Widget build(ui.BuildContext context) {
    return ui.Padding(
      padding: const ui.EdgeInsets.symmetric(vertical: 3),
      child: ui.Row(
        children: [
          ui.SizedBox(
            width: 118,
            child: ui.Text(widget.label,
                style: const ui.TextStyle(fontSize: 11)),
          ),
          ui.IconButton(
            visualDensity: ui.VisualDensity.compact,
            onPressed: () => _set(widget.value - widget.step),
            icon: const ui.Icon(ui.Icons.remove, size: 17),
          ),
          ui.Expanded(
            child: ui.SizedBox(
              height: 34,
              child: ui.TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: ui.TextAlign.center,
                keyboardType: const ui.TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                style: const ui.TextStyle(fontSize: 12),
                decoration: const ui.InputDecoration(
                  isDense: true,
                  contentPadding:
                      ui.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: ui.OutlineInputBorder(),
                ),
                onChanged: (text) {
                  final value = double.tryParse(text.replaceAll(',', '.'));
                  if (value != null) widget.onChanged(value);
                },
                onSubmitted: (text) {
                  final value = double.tryParse(text.replaceAll(',', '.'));
                  if (value != null) _set(value);
                },
              ),
            ),
          ),
          ui.IconButton(
            visualDensity: ui.VisualDensity.compact,
            onPressed: () => _set(widget.value + widget.step),
            icon: const ui.Icon(ui.Icons.add, size: 17),
          ),
        ],
      ),
    );
  }
}

