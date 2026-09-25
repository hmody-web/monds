import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Radius, Size;
import 'dart:ui' as dui show Canvas, Gradient, Paint, PaintingStyle, PictureRecorder, RRect, Rect;

import 'package:flutter/material.dart' as ui;
import 'package:flutter/services.dart' as services;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';

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
  final List<Node> _stations = [];
  final List<Node> _buttons = [];
  final List<vm.Vector3> _buttonPositions = [];
  final List<vm.Vector3> _stationDisplayPositions = [];
  final List<Node> _chairs = [];
  final List<_Debris> _debris = [];
  final math.Random _random = math.Random(8831);
  Node? _spaceBackdrop;
  Texture2D? _spaceBackdropTexture;

  late final Node _characterTemplate;
  late final Node _roomRig;
  late final Node _room;
  late final UnlitMaterial _bigScreenMaterial;
  late final Node _bigScreen;
  Texture2D? _bigScreenTexture;
  late final Node _tank;
  late final Node _tankTurret;
  late final Node _tankBarrel;
  late final Node _projectile;
  late final UnlitMaterial _projectileMaterial;
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
  static const bool layoutDeveloperMode = stationDeveloperMode;
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

    onProgress?.call(.35, 'تحميل الشخصيات');
    _characterTemplate = await Node.fromGlbAsset('assets/models/creative_character_free.glb');

    onProgress?.call(.50, 'تجهيز شاشة النتائج');
    _buildBigScreen();

    onProgress?.call(.63, 'بناء محطات اللاعبين');
    _buildStations();
    // Keep the authored surveillance_room.glb open. The extra safety shell
    // used during camera debugging is intentionally not mounted anymore.

    onProgress?.call(.76, 'تجهيز الشخصيات والكراسي');
    for (var i = 0; i < players.length && i < 4; i++) {
      _buildPlayer(i, players[i].avatar);
    }

    onProgress?.call(.88, 'تجهيز مشهد الإقصاء');
    _buildTank();
    if (debugLayout) _buildLayoutDebug();

    onProgress?.call(.94, 'تهيئة شاشات الأوقات');
    await _primeScreenTextures();

    ready = true;
    if (developerMode || stationDeveloperMode) {
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
      dui.Paint()..color = bg,
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
    }) {
      final p = ui.TextPainter(
        text: ui.TextSpan(
          text: value,
          style: ui.TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
            height: 1.1,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: ui.TextAlign.center,
        maxLines: 3,
      )..layout(maxWidth: maxWidth);
      p.paint(canvas, Offset((width - p.width) * .5, y));
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
        centerText('الترتيب          الاسم          الفرق ±', 52,
            size: 52, color: const Color(0xE6FFFFFF), weight: ui.FontWeight.w900);
        for (var i = 0; i < standings.take(4).length; i++) {
          final s = standings[i];
          final y = 145.0 + i * 202.0;
          canvas.drawRRect(
            dui.RRect.fromRectAndRadius(
              dui.Rect.fromLTWH(80, y, 1440, 166),
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
              style: const ui.TextStyle(
                fontSize: 66,
                color: Color(0xFFFFFFFF),
                fontWeight: ui.FontWeight.w900,
                height: 1,
              ),
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: ui.TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: 1340);
          row.paint(canvas, Offset((width - row.width) * .5, y + 49));
        }
        break;
      case GuessTimePhase.elimination:
        centerText('الترتيب          الاسم          الفرق ±', 52,
            size: 52, color: const Color(0xE6FFFFFF), weight: ui.FontWeight.w900);
        for (var i = 0; i < finalStandings.take(4).length; i++) {
          final s = finalStandings[i];
          final y = 145.0 + i * 202.0;
          canvas.drawRRect(
            dui.RRect.fromRectAndRadius(
              dui.Rect.fromLTWH(80, y, 1440, 166),
              const Radius.circular(28),
            ),
            dui.Paint()..color = const Color(0x28FFFFFF),
          );
          final rowText = '${s.rank}     ${s.player.name}     ±${(s.errorMs / 1000).toStringAsFixed(2)} ث';
          final row = ui.TextPainter(
            text: ui.TextSpan(
              text: rowText,
              style: const ui.TextStyle(
                fontSize: 66,
                color: Color(0xFFFFFFFF),
                fontWeight: ui.FontWeight.w900,
              ),
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: ui.TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: 1340);
          row.paint(canvas, Offset((width - row.width) * .5, y + 49));
        }
        break;
      case GuessTimePhase.finished:
        centerText('الترتيب          الاسم          الفرق ±', 52,
            size: 52, color: const Color(0xE6FFFFFF), weight: ui.FontWeight.w900);
        for (var i = 0; i < finalStandings.take(4).length; i++) {
          final s = finalStandings[i];
          final y = 145.0 + i * 202.0;
          canvas.drawRRect(
            dui.RRect.fromRectAndRadius(
              dui.Rect.fromLTWH(80, y, 1440, 166),
              const Radius.circular(28),
            ),
            dui.Paint()..color = const Color(0x28FFFFFF),
          );
          final rowText = '${s.rank}     ${s.player.name}     ±${(s.errorMs / 1000).toStringAsFixed(2)} ث';
          final row = ui.TextPainter(
            text: ui.TextSpan(
              text: rowText,
              style: const ui.TextStyle(
                fontSize: 66,
                color: Color(0xFFFFFFFF),
                fontWeight: ui.FontWeight.w900,
              ),
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: ui.TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: 1340);
          row.paint(canvas, Offset((width - row.width) * .5, y + 49));
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

    final frame = _pbr(const Color(0xFF1A2328), roughness: .55, metallic: .24);
    final bezel = _pbr(const Color(0xFF090E11), roughness: .72, metallic: .10);
    final mount = Node(name: 'guess_big_result_screen_mount')
      ..position = position
      ..rotation = rotation;
    mount.add(_mesh(
      _geo.unitCube,
      frame,
      position: vm.Vector3(0, 0, -.07),
      scale: vm.Vector3(_layout.wallWidth * .76, _layout.wallHeight * .62, .14),
    ));
    mount.add(_mesh(
      _geo.unitCube,
      bezel,
      position: vm.Vector3(0, 0, -.025),
      scale: vm.Vector3(_layout.wallWidth * .71, _layout.wallHeight * .56, .07),
    ));
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
    mount.add(_bigScreen);
    scene.add(mount);
  }

  void _buildStations() {
    final metal = _pbr(const Color(0xFF222B31), roughness: .42, metallic: .62);
    final dark = _pbr(const Color(0xFF10171B), roughness: .62, metallic: .28);

    for (var i = 0; i < 4; i++) {
      final color = GuessTimePalette.colors[i];
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
        dark,
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
        dark,
        position: vm.Vector3(0, .875, -_layout.deskLead - .105),
        scale: vm.Vector3(.48, .15, .10),
      );
      final timerFace = _mesh(
        _geo.unitCube,
        _unlit(const Color(0xFF020506)),
        name: 'station_timer_$i',
        position: timerLocal,
        scale: vm.Vector3(.42, .10, .012),
      )..castsShadows = false;

      final timerFrameTop = _mesh(
        _geo.unitCube,
        metal,
        position: vm.Vector3(0, timerLocal.y + .061, timerLocal.z + .006),
        scale: vm.Vector3(.48, .022, .018),
      );
      final timerFrameBottom = _mesh(
        _geo.unitCube,
        metal,
        position: vm.Vector3(0, timerLocal.y - .061, timerLocal.z + .006),
        scale: vm.Vector3(.48, .022, .018),
      );
      final timerFrameLeft = _mesh(
        _geo.unitCube,
        metal,
        position: vm.Vector3(-.229, timerLocal.y, timerLocal.z + .006),
        scale: vm.Vector3(.022, .105, .018),
      );
      final timerFrameRight = _mesh(
        _geo.unitCube,
        metal,
        position: vm.Vector3(.229, timerLocal.y, timerLocal.z + .006),
        scale: vm.Vector3(.022, .105, .018),
      );

      final digitMaterial = _unlit(color)
        ..doubleSided = true
        ..vertexColorWeight = 0;
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
      root.addAll([
        chair,
        desk,
        pedestal,
        accentStrip,
        timerBody,
        timerFace,
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
    final accent = _unlit(const Color(0xFFA88C3E));

    root.addAll([
      _mesh(_geo.unitCube, cushion, position: vm.Vector3(0, .47, 0), scale: vm.Vector3(.62, .12, .58)),
      _mesh(_geo.unitCube, cushion, position: vm.Vector3(0, .93, .23), scale: vm.Vector3(.62, .88, .13)),
      _mesh(_geo.unitCube, frame, position: vm.Vector3(0, .24, .10), scale: vm.Vector3(.12, .46, .12)),
      _mesh(_geo.unitCube, frame, position: vm.Vector3(0, .08, .10), scale: vm.Vector3(.58, .10, .58)),
      _mesh(_geo.unitCube, accent, position: vm.Vector3(0, 1.20, .155), scale: vm.Vector3(.42, .035, .02))
        ..castsShadows = false,
    ]);
    return root;
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

  void _buildTank() {
    final bodyMat = _pbr(const Color(0xFF39483B), roughness: .62, metallic: .35);
    final darkMat = _pbr(const Color(0xFF111814), roughness: .52, metallic: .62);
    final glow = _unlit(const Color(0xFFFF3A2E));

    final tankStart = _layout.rowCenter - _layout.right * (_layout.wallWidth * 1.05) + _layout.front * .25 + vm.Vector3(0, .15, 0);
    _tank = Node(name: 'execution_tank')
      ..position = tankStart
      ..visible = false;
    _tank.addAll([
      _mesh(_geo.unitCube, bodyMat, position: vm.Vector3(0, .52, 0), scale: vm.Vector3(1.48, .62, 2.05)),
      _mesh(_geo.unitCube, darkMat, position: vm.Vector3(-.80, .33, 0), scale: vm.Vector3(.22, .52, 2.25)),
      _mesh(_geo.unitCube, darkMat, position: vm.Vector3(.80, .33, 0), scale: vm.Vector3(.22, .52, 2.25)),
    ]);

    _tankTurret = Node(name: 'tank_turret')..position = vm.Vector3(0, .92, -.08);
    _tankTurret.add(_mesh(_geo.unitCube, bodyMat, position: vm.Vector3.zero(), scale: vm.Vector3(.92, .40, .90)));
    _tankBarrel = _mesh(
      _geo.unitCube,
      darkMat,
      name: 'tank_barrel',
      position: vm.Vector3(0, .05, -1.15),
      scale: vm.Vector3(.16, .16, 2.20),
    );
    _tankTurret.add(_tankBarrel);
    _tank.add(_tankTurret);
    scene.add(_tank);

    _projectileMaterial = glow;
    _explosionMaterial = _unlit(const Color(0xFFFFB12E));
    _projectile = _mesh(
      _geo.projectile,
      _projectileMaterial,
      name: 'tank_projectile',
      scale: vm.Vector3.all(.13),
    )
      ..visible = false
      ..castsShadows = false;
    scene.add(_projectile);
  }

  void startElimination(int loserIndex) {
    if (_eliminationActive) return;
    _loserIndex = loserIndex.clamp(0, math.max(0, _players.length - 1)).toInt();
    _eliminationActive = true;
    _eliminationStartedAt = DateTime.now();
    _shotTriggered = false;
    _impactTriggered = false;
    _tank
      ..visible = true
      ..position = _layout.rowCenter - _layout.right * (_layout.wallWidth * 1.05) + _layout.front * .25 + vm.Vector3(0, .15, 0);
    _projectile.visible = false;
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
    _tank
      ..visible = false
      ..position = _layout.rowCenter - _layout.right * (_layout.wallWidth * 1.05) + _layout.front * .25 + vm.Vector3(0, .15, 0);
    _tankTurret.rotation = vm.Quaternion.identity();
    _projectile.visible = false;

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
        final t = now.difference(started).inMilliseconds / 900.0;
        if (t < 1) {
          press = math.sin(t.clamp(0.0, 1.0) * math.pi);
        } else {
          v.pressStartedAt = null;
        }
      }
      _posePlayer(v, press: press);
      if (i < _buttons.length) {
        _buttons[i].scale = vm.Vector3(.18, .08 - .032 * press, .18);
        _buttons[i].position = vm.Vector3(0, .82 - .018 * press, -_layout.deskLead + .10);
      }
    }

    if (_eliminationActive) _updateElimination();

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
    final t = _elimSeconds();
    final loserWorld = _stationPosition(_loserIndex);

    final entry = _layout.rowCenter - _layout.right * (_layout.wallWidth * 1.05) + _layout.front * .25 + vm.Vector3(0, .15, 0);
    final lane = _layout.rowCenter - _layout.right * (_layout.wallWidth * .78) + _layout.front * .08 + vm.Vector3(0, .15, 0);
    final besideLoser = loserWorld + _layout.right * 1.55 + vm.Vector3(0, .15, 0);
    if (t < 1.55) {
      final k = _ease((t / 1.55).clamp(0.0, 1.0).toDouble());
      _tank.position = entry + (lane - entry) * k;
    } else if (t < 3.4) {
      final k = _ease(((t - 1.55) / 1.85).clamp(0.0, 1.0).toDouble());
      _tank.position = lane + (besideLoser - lane) * k;
    } else {
      _tank.position = besideLoser;
    }

    final target = vm.Vector3(loserWorld.x, _roomFloorY + .78, loserWorld.z);
    final origin = _tank.position + vm.Vector3(0, 1.02, -.15);
    final dx = target.x - origin.x;
    final dz = target.z - origin.z;
    final yaw = math.atan2(dx, -dz);
    final aimT = ((t - 3.2) / 1.35).clamp(0.0, 1.0).toDouble();
    _tankTurret.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw * _ease(aimT));

    if (t >= 5.25 && !_shotTriggered) {
      _shotTriggered = true;
      _shotStart = vm.Vector3.copy(origin);
      _shotTarget = vm.Vector3(loserWorld.x, _roomFloorY + .72, loserWorld.z);
      _projectile
        ..visible = true
        ..position = vm.Vector3.copy(_shotStart);
    }

    if (_shotTriggered && !_impactTriggered) {
      final shotT = ((t - 5.25) / .58).clamp(0.0, 1.0).toDouble();
      _projectile.position = vm.Vector3(
        _shotStart.x + (_shotTarget.x - _shotStart.x) * shotT,
        _shotStart.y + (_shotTarget.y - _shotStart.y) * shotT,
        _shotStart.z + (_shotTarget.z - _shotStart.z) * shotT,
      );
      if (shotT >= 1) _explodeLoser();
    }
  }

  double _ease(double t) => 1 - math.pow(1 - t, 3).toDouble();

  void _explodeLoser() {
    if (_impactTriggered) return;
    _impactTriggered = true;
    _projectile.visible = false;

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
    if (!(developerMode || stationDeveloperMode) || _developerOverlayEntry != null) return;
    ui.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(developerMode || stationDeveloperMode) || _developerOverlayEntry != null) return;
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
    if (developerMode || (stationDeveloperMode && _developerFreeCameraEnabled)) {
      return _developerFreeCamera();
    }
    return _firstPersonCamera();
  }

  bool get developerFreeCameraEnabled => _developerFreeCameraEnabled;
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
    if (stationDeveloperMode && _developerFreeCameraEnabled) {
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

class _GuessTimeDeveloperTuning {
  final List<_StationDeveloperTuning> stations =
      List<_StationDeveloperTuning>.generate(4, (_) => _StationDeveloperTuning());
  final List<_PlayerPoseTuning> poses =
      List<_PlayerPoseTuning>.generate(4, (_) => _PlayerPoseTuning());

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

  @override
  void initState() {
    super.initState();
    widget.world._selectDeveloperStation(_selectedStation);
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
    return ui.Expanded(
      child: ui.Padding(
        padding: const ui.EdgeInsets.symmetric(horizontal: 3),
        child: ui.FilledButton(
          style: ui.FilledButton.styleFrom(
            padding: const ui.EdgeInsets.symmetric(vertical: 9),
            backgroundColor: selected
                ? const ui.Color(0xFF219587)
                : const ui.Color(0xFF222B31),
          ),
          onPressed: () => setState(() => _page = page),
          child: ui.Text(label, style: const ui.TextStyle(fontSize: 12)),
        ),
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
                    ui.Row(
                      children: [
                        _tab('اللاعبون', 0),
                        _tab('الجسم', 1),
                        _tab('الماب', 2),
                        _tab('الكاميرا', 3),
                        _tab('القيم', 4),
                      ],
                    ),
                    const ui.SizedBox(height: 8),
                    _stepControl(),
                    const ui.Divider(height: 16),
                    ui.Flexible(
                      child: ui.SingleChildScrollView(
                        child: switch (_page) {
                          0 => _stationPage(),
                          1 => _posePage(),
                          2 => _mapPage(),
                          3 => _cameraPage(),
                          _ => _valuesPage(),
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

