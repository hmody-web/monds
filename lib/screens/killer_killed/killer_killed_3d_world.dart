import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Color, Offset, Size;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/killer_killed_avatar.dart';

enum KillerKilledBackgroundFit { cover, contain, repeat }

class KillerKilled3DWorld {
  KillerKilled3DWorld();

  static const double arenaWorldSize = 7.2;
  static const double fighterLabelHeight = 2.22;

  final Scene scene = Scene();
  final Map<int, KillerKilledFighterVisual> fighters = {};
  final List<_BloodStain> _bloodStains = <_BloodStain>[];
  final List<_BloodParticle> _bloodParticles = <_BloodParticle>[];
  final List<Node> _bloodDiscPool = <Node>[];
  final List<Node> _bloodDropPool = <Node>[];
  final List<Node> _bloodParticlePool = <Node>[];
  final math.Random _random = math.Random(1729);

  // Hard caps keep long sessions from growing the scene graph forever while
  // preserving the exact same blood geometry/material quality. Oldest stains
  // are recycled rather than destroyed/re-created.
  static const int _maxBloodStains = 48;
  static const int _maxBloodParticles = 64;

  bool _developerDebugLayerEnabled = false;

  bool get hasActiveEffects => _bloodParticles.isNotEmpty;
  bool get hasAnimatedBackground => _backgroundRotationSpeed.abs() > 0.000001;

  bool ready = false;

  late final _GeometryBank _geo;
  late final PhysicallyBasedMaterial _floorMaterial;
  late final PhysicallyBasedMaterial _parapetMaterial;
  late final PhysicallyBasedMaterial _obstacleTopMaterial;
  late final PhysicallyBasedMaterial _obstacleSideMaterial;
  late final PhysicallyBasedMaterial _obstacleEdgeMaterial;
  late final UnlitMaterial _gridMaterial;
  late final UnlitMaterial _bloodMaterial;
  late final UnlitMaterial _bloodSprayMaterial;
  late final UnlitMaterial _laserMaterial;
  late final UnlitMaterial _laserGlowMaterial;
  late final UnlitMaterial _shotMaterial;
  late final UnlitMaterial _debugHitboxMaterial;
  late final UnlitMaterial _debugLaserHitboxMaterial;
  late final UnlitMaterial _debugKillPathMaterial;
  late final Node _debugKillPathNode;

  double _laserThickness = 1.0;
  double _laserGlow = 1.0;
  Color _laserColor = const Color(0xFFFF3044);
  double _walkCycleSpeed = 1.0;
  double _supportArmWalkBlend = 1.0;
  double _supportArmOffsetX = 0.0;
  double _supportArmOffsetY = 0.0;
  double _supportArmOffsetZ = 0.0;
  double _supportForeArmBend = 0.0;
  double _rightArmPitch = 0.0;
  double _rightArmYaw = 0.0;
  double _leftArmPitch = 0.0;
  double _leftArmYaw = 0.0;

  // Full locomotion/body physics tuning. Defaults intentionally produce a
  // natural walk before the developer changes anything.
  double _playerScale = 1.0;
  double _walkPhase1 = 1.0;
  double _walkPhase2 = .16;
  double _walkPhase3 = .06;
  double _thighSwing = 29.0 * math.pi / 180;
  double _kneeBend = 20.0 * math.pi / 180;
  double _footSwing = 6.0 * math.pi / 180;
  double _shoulderSwing = 7.0 * math.pi / 180;
  double _armSwing = 12.0 * math.pi / 180;
  double _headYaw = 2.8 * math.pi / 180;
  double _headPitch = 1.4 * math.pi / 180;
  Map<String, List<double>> _idlePose = <String, List<double>>{};
  Map<String, List<double>> _walkPose = <String, List<double>>{};
  Map<String, List<double>> _developerDeathPose = <String, List<double>>{};
  double _bodyLean = 2.0 * math.pi / 180;
  double _bodyBob = .016;
  double _deathOffsetX = 0.0;
  double _deathOffsetY = .080;
  double _deathOffsetZ = 0.0;
  double _deathScale = 1.0;
  double _deathCameraX = -4.70;
  double _deathCameraY = 4.85;
  double _deathCameraZ = -4.70;
  double _deathCameraYaw = math.pi / 4;
  double _deathCameraPitch = -20 * math.pi / 180;
  double _deathCameraZoom = 1.0;
  Color _bloodColor = const Color(0xFFB00008);

  bool _debugHitboxes = false;
  double _debugHitboxForward = 1.0;
  double _debugHitboxSide = 1.0;
  double _debugHitboxVertical = 1.0;
  double _debugHitboxRadius = 1.0;
  double _debugTorsoForward = 1.0;
  double _debugTorsoSide = 1.0;
  double _debugTorsoVertical = 1.0;
  double _debugHeadForward = 1.0;
  double _debugHeadSide = 1.0;
  double _debugHeadVertical = 1.0;
  double _debugRightArmForward = 1.0;
  double _debugRightArmSide = 1.0;
  double _debugRightArmVertical = 1.0;
  double _debugLeftArmForward = 1.0;
  double _debugLeftArmSide = 1.0;
  double _debugLeftArmVertical = 1.0;
  double _debugTorsoOffsetX = 0.0;
  double _debugTorsoOffsetY = 0.0;
  double _debugTorsoOffsetZ = 0.0;
  double _debugHeadOffsetX = 0.0;
  double _debugHeadOffsetY = 0.0;
  double _debugHeadOffsetZ = 0.0;
  double _debugRightArmOffsetX = 0.0;
  double _debugRightArmOffsetY = 0.0;
  double _debugRightArmOffsetZ = 0.0;
  double _debugLeftArmOffsetX = 0.0;
  double _debugLeftArmOffsetY = 0.0;
  double _debugLeftArmOffsetZ = 0.0;

  late final Node _obstacleRoot;
  bool _lastObstacleVisible = false;
  double _lastObstacleX = double.nan;
  double _lastObstacleY = double.nan;
  late final Node _characterTemplate;
  late final Node _gunTemplate;
  late final Node _mapTemplate;
  Node? _mapRoot;
  Node? _obstacleColumnTemplate;
  double _mapScale = .160;
  Node? _lobbyBackdropBase;
  Node? _lobbyBackdropOverlay;
  UnlitMaterial? _lobbyBackdropBaseMaterial;
  UnlitMaterial? _lobbyBackdropSkyMaterial;
  Texture2D? _lobbyBackdropOverlayTexture;
  double _lobbyBackdropScale = 1.0;
  vm.Vector3 _lobbyBackdropPosition = vm.Vector3.zero();
  Node? _arenaBoundaryRoot;
  late final UnlitMaterial _arenaBoundaryMaterial;
  double _lastBackgroundUpdateSeconds = -999;
  final Map<Node, Mesh> _originalBackgroundMeshes = <Node, Mesh>{};
  Texture2D? _customBackgroundTexture;
  double _backgroundRotationSpeed = .0105;
  double _backgroundScale = 1.0;
  KillerKilledBackgroundFit _backgroundFit = KillerKilledBackgroundFit.cover;
  vm.Quaternion _lobbyBackdropBaseRotation = vm.Quaternion.identity();

  // Developer override for the visual pistol mesh ONLY. The weapon rig,
  // muzzle, laser and hit logic stay separate so you can tune the look of the
  // imported model without breaking gameplay.
  vm.Vector3 _gunVisualPosition = vm.Vector3(0, .018, .087);
  vm.Vector3 _gunVisualRotation = vm.Vector3.zero();
  vm.Vector3 _gunVisualScale = vm.Vector3(-.40, .40, .40);

  bool get _thermalOptimized =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _invalidateAllFighterVisuals() {
    for (final visual in fighters.values) {
      visual.forceVisualRefresh = true;
    }
  }

  Future<void> initialize({
    void Function(double progress, String stage)? onProgress,
  }) async {
    if (ready) {
      onProgress?.call(1, 'المشهد جاهز');
      return;
    }
    onProgress?.call(.06, 'تهيئة محرك ثلاثي الأبعاد');
    await Scene.initializeStaticResources();
    onProgress?.call(.16, 'إعداد الإضاءة والمؤثرات');

    final thermalOptimized = _thermalOptimized;

    // iOS uses a lighter render profile to avoid driving Retina-resolution
    // offscreen targets, cascaded shadows and SSAO at full cost continuously.
    // Other platforms keep the previously approved visual settings.
    scene.renderScale = thermalOptimized ? .72 : 1.0;
    scene.exposure = 1.12;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.56, -1.0, -.42),
      color: vm.Vector3(.84, .91, 1.0),
      intensity: 2.5,
      castsShadow: true,
      cacheStaticShadows: true,
      shadowCascadeCount: thermalOptimized ? 1 : 2,
      shadowMaxDistance: thermalOptimized ? 18 : 36,
      shadowMapResolution: thermalOptimized ? 512 : 1024,
      shadowSoftness: .16,
      shadowAmbientStrength: .22,
    );
    scene.ambientOcclusion
      ..enabled = !thermalOptimized
      ..halfResolution = true
      ..sampleCount = thermalOptimized ? 2 : 8
      ..radius = .34
      ..intensity = .86;

    _geo = _GeometryBank();
    _createMaterials();
    onProgress?.call(.24, 'تحميل الشخصية');
    _characterTemplate = await Node.fromGlbAsset(
      'assets/models/creative_character_free.glb',
    );
    onProgress?.call(.41, 'تحميل المسدس');
    _gunTemplate = await Node.fromGlbAsset(
      'assets/models/pistol_gun__p250_gun.glb',
    );
    onProgress?.call(.50, 'تحميل ماب قاتل ومقتول');
    _mapTemplate = await Node.fromGlbAsset(
      'assets/models/killer_killed_boss_room.glb',
    );
    onProgress?.call(.70, 'تجهيز خلفية اللعبة');
    onProgress?.call(.87, 'بناء الساحة');
    _buildArenaMap();
    await _buildLobbySpaceBackdrop();
    _debugKillPathNode = _meshNode(
      _geo.debugLaser,
      _debugKillPathMaterial,
      name: 'developer_kill_path',
      position: vm.Vector3.zero(),
      scale: vm.Vector3.zero(),
    )
      ..visible = false
      ..castsShadows = false
      ..raycastable = false;
    // Debug-only nodes stay detached from the live scene until the developer
    // laboratory is opened. This removes their traversal/draw bookkeeping from
    // normal gameplay entirely rather than merely hiding them.
    ready = true;
    onProgress?.call(1, 'المشهد جاهز');
  }

  void _createMaterials() {
    _floorMaterial = _pbr(const Color(0xFF182433), roughness: .72, metallic: .17);
    _parapetMaterial = _pbr(const Color(0xFF222D3A), roughness: .64, metallic: .22);
    // Industrial floor-matched obstacle: muted yellow metal with deep black guards.
    _obstacleTopMaterial = _pbr(const Color(0xFFA48B3B), roughness: .48, metallic: .48);
    _obstacleSideMaterial = _pbr(const Color(0xFF716437), roughness: .58, metallic: .40);
    _obstacleEdgeMaterial = _pbr(const Color(0xFF07090D), roughness: .42, metallic: .72);
    _gridMaterial = _unlit(const Color(0x3A2F6DFF));
    _bloodMaterial = _unlit(const Color(0xFFB00008));
    _bloodSprayMaterial = _unlit(const Color(0xFFE0000B));
    // Bright neon-red laser: a crisp luminous core plus a wider transparent
    // halo so it reads clearly against the black/star background.
    // Opaque neon core keeps correct depth against the floor; only the halo blends.
    // This prevents the beam from looking as if it were rendered underneath the floor.
    _laserMaterial = _unlit(_laserColor);
    _laserGlowMaterial = _unlit(const Color(0xA6FF3044));
    _shotMaterial = _unlit(const Color(0xFFFFF2C5));
    _debugHitboxMaterial = _unlit(const Color(0x3F62FF8B));
    _debugLaserHitboxMaterial = _unlit(const Color(0x665CEBFF));
    _debugKillPathMaterial = _unlit(const Color(0xE6FFD43B));
    _arenaBoundaryMaterial = _unlit(const Color(0xD95CFF7A));
  }

  PhysicallyBasedMaterial _pbr(
    Color color, {
    double roughness = .65,
    double metallic = .0,
  }) {
    final material = PhysicallyBasedMaterial();
    material.baseColorFactor = _vectorColor(color);
    material.roughnessFactor = roughness;
    material.metallicFactor = metallic;
    return material;
  }

  UnlitMaterial _unlit(Color color) {
    final material = UnlitMaterial();
    material.baseColorFactor = _vectorColor(color);
    final alpha = ((color.toARGB32() >> 24) & 0xFF) / 255.0;
    if (alpha < .999) material.alphaMode = AlphaMode.blend;
    return material;
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

  Node _meshNode(
    Geometry geometry,
    Material material, {
    String name = '',
    vm.Vector3? position,
    vm.Quaternion? rotation,
    vm.Vector3? scale,
  }) {
    final node = Node(name: name, mesh: Mesh(geometry, material));
    if (position != null) node.position = position;
    if (rotation != null) node.rotation = rotation;
    if (scale != null) node.scale = scale;
    return node;
  }

  Future<Texture2D> _makeLobbySpaceBackdropOverlayTexture() async {
    // Exact lightweight deep-space sky used by the arcade lobby / Guess Time.
    // It is generated once, so there is no large bitmap asset or runtime blur.
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

  Future<void> _buildLobbySpaceBackdrop() async {
    // Dedicated Milky Way panorama GLB used as the REAL environment backdrop.
    // It is kept separate from the gameplay map/space branches so developer
    // position, scale and tint controls affect only this sky background.
    final sky = await Node.fromGlbAsset(
      'assets/models/sky_pano_milkyway_game.glb',
    );
    sky
      ..name = 'sooky_killer_killed_milkyway_backdrop'
      ..position = _lobbyBackdropPosition.clone()
      ..scale = vm.Vector3.all(_lobbyBackdropScale)
      ..castsShadows = false
      ..raycastable = false
      ..highlightColor = null;

    // The GLB is authored as an unlit textured sphere. Force double-sided
    // rendering and disable shadow/raycast participation so the camera can
    // remain inside it cheaply.
    for (final meshNode in sky.meshNodes) {
      meshNode
        ..castsShadows = false
        ..raycastable = false
        ..highlightColor = null;
      final mesh = meshNode.mesh;
      if (mesh == null) continue;
      for (final primitive in mesh.primitives) {
        final material = primitive.material;
        if (material is UnlitMaterial) {
          material
            ..doubleSided = true
            ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF));
        } else if (material is PhysicallyBasedMaterial) {
          material
            ..doubleSided = true
            ..baseColorFactor = _vectorColor(const Color(0xFFFFFFFF));
        }
      }
    }

    _lobbyBackdropBase = sky;
    _lobbyBackdropBaseRotation = sky.rotation.clone();
    _originalBackgroundMeshes.clear();
    for (final meshNode in sky.meshNodes) {
      final mesh = meshNode.mesh;
      if (mesh != null) _originalBackgroundMeshes[meshNode] = mesh;
    }
    _lobbyBackdropOverlay = null;
    _lobbyBackdropBaseMaterial = null;
    _lobbyBackdropSkyMaterial = null;
    scene.add(sky);
  }

  void setLobbyBackdropColor(Color color) {
    // Tint the actual imported Milky Way material(s), preserving the panorama
    // texture while multiplying its RGB in real time.
    final sky = _lobbyBackdropBase;
    if (sky == null) return;
    for (final meshNode in sky.meshNodes) {
      final mesh = meshNode.mesh;
      if (mesh == null) continue;
      for (final primitive in mesh.primitives) {
        final material = primitive.material;
        if (material is UnlitMaterial) {
          material.baseColorFactor = _vectorColor(color);
        } else if (material is PhysicallyBasedMaterial) {
          material.baseColorFactor = _vectorColor(color);
        }
      }
    }
  }

  void setLobbyBackdropTransform({
    required double x,
    required double y,
    required double z,
    required double scale,
  }) {
    if (!x.isFinite || !y.isFinite || !z.isFinite || !scale.isFinite) return;
    _lobbyBackdropPosition = vm.Vector3(x, y, z);
    _lobbyBackdropScale = scale;
    final sky = _lobbyBackdropBase;
    if (sky == null) return;
    sky
      ..position = _lobbyBackdropPosition.clone()
      ..scale = vm.Vector3.all(_lobbyBackdropScale);
  }

  void setLobbyBackdropScale(double scale) {
    setLobbyBackdropTransform(
      x: _lobbyBackdropPosition.x,
      y: _lobbyBackdropPosition.y,
      z: _lobbyBackdropPosition.z,
      scale: scale,
    );
  }

  void setLightingTuning({
    required Color color,
    required double intensity,
    required double directionX,
    required double directionY,
    required double directionZ,
    required double exposure,
    required bool castsShadow,
  }) {
    final argb = color.toARGB32();
    final direction = vm.Vector3(directionX, directionY, directionZ);
    if (direction.length2 < .000001) direction.setValues(-.56, -1.0, -.42);
    scene.exposure = exposure.clamp(.05, 8.0).toDouble();
    scene.directionalLight = DirectionalLight(
      direction: direction,
      color: vm.Vector3(
        ((argb >> 16) & 0xFF) / 255.0,
        ((argb >> 8) & 0xFF) / 255.0,
        (argb & 0xFF) / 255.0,
      ),
      intensity: intensity.clamp(0.0, 20.0).toDouble(),
      castsShadow: castsShadow,
      cacheStaticShadows: true,
      shadowCascadeCount: _thermalOptimized ? 1 : 2,
      shadowMaxDistance: _thermalOptimized ? 18 : 36,
      shadowMapResolution: _thermalOptimized ? 512 : 1024,
      shadowSoftness: .16,
      shadowAmbientStrength: .22,
    );
  }

  void _buildArenaMap() {
    // Keep the imported boss-room GLB intact. We only transform its root; no
    // mesh decimation, texture resizing or quality reduction is performed.
    final map = _mapTemplate
      ..name = 'killer_killed_boss_room_map'
      ..position = vm.Vector3.zero()
      ..rotation = vm.Quaternion.identity()
      ..scale = vm.Vector3.all(_mapScale);
    _mapRoot = map;

    // The source contains exactly four columns under `Columns`. Keep one full
    // quality clone for the random gameplay obstacle, then hide all four
    // original columns from the decorative map.
    final columns = map.getChildByName('Columns');
    final sourceColumn = map.getChildByName('Column');
    if (sourceColumn != null) {
      _obstacleColumnTemplate = sourceColumn.clone(recursive: true);
    }
    if (columns != null) columns.visible = false;

    for (final meshNode in map.meshNodes) {
      meshNode.highlightColor = null;
      meshNode.shadowStatic = true;
      // Gameplay collision/laser tests are custom 2D math, so the decorative
      // map never needs to participate in the engine raycast acceleration path.
      meshNode.raycastable = false;
    }
    scene.add(map);

    // Eight independently adjustable sides. Each visual segment uses the same
    // center / length / angle values that gameplay collision uses.
    _arenaBoundaryRoot = Node(name: 'developer_octagon_boundary')
      ..visible = false
      ..castsShadows = false
      ..raycastable = false;
    for (var i = 0; i < 8; i++) {
      final seg = _meshNode(
        CuboidGeometry(vm.Vector3.all(1)),
        _arenaBoundaryMaterial,
        name: 'arena_boundary_side_${i + 1}',
        scale: vm.Vector3(.035, .025, 1),
      )
        ..castsShadows = false
        ..raycastable = false;
      _arenaBoundaryRoot!.add(seg);
    }
    // Keep developer boundary detached during normal gameplay.

    _obstacleRoot = Node(name: 'dynamic_column_obstacle')..visible = false;
    final column = _obstacleColumnTemplate;
    if (column != null) {
      final authoredY = column.position.y;
      column
        ..name = 'column_shield'
        ..position = vm.Vector3(0, authoredY, 0);
      for (final meshNode in column.meshNodes) {
        meshNode.highlightColor = null;
        meshNode.castsShadows = !_thermalOptimized;
        meshNode.raycastable = false;
      }
      _obstacleRoot.add(column);
    }
    _obstacleRoot.scale = vm.Vector3.all(_mapScale);
    scene.add(_obstacleRoot);
  }

  void setMapDeveloperTransform({
    required double x,
    required double y,
    required double z,
    required double rotationX,
    required double rotationY,
    required double rotationZ,
    required double scale,
  }) {
    final map = _mapRoot;
    if (map == null) return;
    _mapScale = scale.abs().clamp(.001, 20.0).toDouble();
    final mapRotation = vm.Quaternion.euler(rotationX, rotationY, rotationZ);
    map
      ..position = vm.Vector3(x, y, z)
      ..rotation = mapRotation
      ..scale = vm.Vector3.all(_mapScale);
    // The obstacle is the exact original map column, so it follows the map
    // scale/orientation and vertical offset while keeping its random X/Z spot.
    _obstacleRoot
      ..rotation = mapRotation.clone()
      ..scale = vm.Vector3.all(_mapScale);
  }

  void setArenaBoundaryPreview({
    required bool visible,
    required List<Offset> sideCenters,
    required List<double> sideLengths,
    required List<double> sideAnglesDegrees,
  }) {
    final root = _arenaBoundaryRoot;
    if (root == null) return;
    root
      ..visible = visible && _developerDebugLayerEnabled
      ..position = vm.Vector3.zero()
      ..scale = vm.Vector3.all(1.0);
    final count = math.min(
      root.children.length,
      math.min(sideCenters.length, math.min(sideLengths.length, sideAnglesDegrees.length)),
    );
    for (var i = 0; i < root.children.length; i++) {
      final seg = root.children[i];
      if (i >= count) {
        seg.visible = false;
        continue;
      }
      final center = sideCenters[i];
      final length = sideLengths[i].abs().clamp(.001, 4.0).toDouble();
      final angle = sideAnglesDegrees[i] * math.pi / 180.0;
      final a = worldPosition(
        center.dx - math.cos(angle) * length * .5,
        center.dy - math.sin(angle) * length * .5,
        height: .055,
      );
      final b = worldPosition(
        center.dx + math.cos(angle) * length * .5,
        center.dy + math.sin(angle) * length * .5,
        height: .055,
      );
      final worldLength = math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.z - a.z, 2)).toDouble();
      final yaw = math.atan2(b.x - a.x, b.z - a.z);
      seg
        ..visible = true
        ..position = vm.Vector3((a.x + b.x) * .5, .055, (a.z + b.z) * .5)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw)
        ..scale = vm.Vector3(.035, .025, worldLength);
    }
  }

  void _updateBackground(double seconds) {
    final sky = _lobbyBackdropBase;
    if (sky == null || !hasAnimatedBackground) return;
    if (_thermalOptimized &&
        seconds - _lastBackgroundUpdateSeconds < (1 / 12)) {
      return;
    }
    _lastBackgroundUpdateSeconds = seconds;
    final yaw = seconds * _backgroundRotationSpeed;
    sky.rotation = _lobbyBackdropBaseRotation *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
  }

  void setLaserStyle({
    required Color color,
    required double thickness,
    required double glow,
  }) {
    _laserColor = color;
    _laserThickness = thickness.abs().clamp(.001, 1000.0).toDouble();
    _laserGlow = glow.clamp(0.0, 1000.0).toDouble();
    _laserMaterial.baseColorFactor = _vectorColor(_laserColor);
    final glowAlpha = (.18 + _laserGlow * .22).clamp(.08, .86).toDouble();
    _laserGlowMaterial.baseColorFactor = _vectorColor(_laserColor, alpha: glowAlpha);
    for (final visual in fighters.values) {
      visual.forceLaserRefresh = true;
    }
    _invalidateAllFighterVisuals();
  }

  void setWalkAnimationTuning({
    required double cycleSpeed,
    required double supportArmWalkBlend,
    double supportArmOffsetX = 0,
    double supportArmOffsetY = 0,
    double supportArmOffsetZ = 0,
    double supportForeArmBend = 0,
    double rightArmPitch = 0,
    double rightArmYaw = 0,
    double leftArmPitch = 0,
    double leftArmYaw = 0,
  }) {
    _walkCycleSpeed = cycleSpeed;
    _supportArmWalkBlend = supportArmWalkBlend;
    _supportArmOffsetX = supportArmOffsetX;
    _supportArmOffsetY = supportArmOffsetY;
    _supportArmOffsetZ = supportArmOffsetZ;
    _supportForeArmBend = supportForeArmBend;
    _rightArmPitch = rightArmPitch;
    _rightArmYaw = rightArmYaw;
    _leftArmPitch = leftArmPitch;
    _leftArmYaw = leftArmYaw;
    _invalidateAllFighterVisuals();
  }

  void setPlayerPhysicsTuning({
    required double playerScale,
    required double phase1,
    required double phase2,
    required double phase3,
    required double thighSwing,
    required double kneeBend,
    required double footSwing,
    required double shoulderSwing,
    required double armSwing,
    required double headYaw,
    required double headPitch,
    required double bodyLean,
    required double bodyBob,
    required double deathOffsetX,
    required double deathOffsetY,
    required double deathOffsetZ,
    required double deathScale,
  }) {
    _playerScale = playerScale.clamp(.05, 5.0).toDouble();
    _walkPhase1 = phase1;
    _walkPhase2 = phase2;
    _walkPhase3 = phase3;
    _thighSwing = thighSwing;
    _kneeBend = kneeBend.abs();
    _footSwing = footSwing;
    _shoulderSwing = shoulderSwing;
    _armSwing = armSwing;
    _headYaw = headYaw;
    _headPitch = headPitch;
    _bodyLean = bodyLean;
    _bodyBob = bodyBob.abs();
    _deathOffsetX = deathOffsetX;
    _deathOffsetY = deathOffsetY;
    _deathOffsetZ = deathOffsetZ;
    _deathScale = deathScale.clamp(.05, 5.0).toDouble();

    for (final visual in fighters.values) {
      visual.root.scale = vm.Vector3.all(_playerScale);
      visual
        ..forceVisualRefresh = true
        ..lastRootFall = double.nan;
    }
  }

  void setDeveloperBodyPoses({
    required Map<String, List<double>> idlePose,
    required Map<String, List<double>> walkPose,
    required Map<String, List<double>> deathPose,
  }) {
    _idlePose = <String, List<double>>{
      for (final entry in idlePose.entries) entry.key: List<double>.from(entry.value),
    };
    _walkPose = <String, List<double>>{
      for (final entry in walkPose.entries) entry.key: List<double>.from(entry.value),
    };
    _developerDeathPose = <String, List<double>>{
      for (final entry in deathPose.entries) entry.key: List<double>.from(entry.value),
    };
    _invalidateAllFighterVisuals();
  }

  void setDeathCameraTuning({
    required double x,
    required double y,
    required double z,
    required double yaw,
    required double pitch,
    required double zoom,
  }) {
    _deathCameraX = x;
    _deathCameraY = y;
    _deathCameraZ = z;
    _deathCameraYaw = yaw;
    _deathCameraPitch = pitch;
    _deathCameraZoom = zoom.clamp(.05, 10.0).toDouble();
  }

  void setBloodStyle({required Color color}) {
    _bloodColor = color;
    _bloodMaterial.baseColorFactor = _vectorColor(color);
    final argb = color.toARGB32();
    final a = ((argb >> 24) & 0xFF) / 255.0;
    final spray = Color.fromARGB(
      (a * 255).round().clamp(0, 255).toInt(),
      (((argb >> 16) & 0xFF) * 1.08).round().clamp(0, 255).toInt(),
      (((argb >> 8) & 0xFF) * 1.02).round().clamp(0, 255).toInt(),
      (argb & 0xFF),
    );
    _bloodSprayMaterial.baseColorFactor = _vectorColor(spray);
    if (a < .999) {
      _bloodMaterial.alphaMode = AlphaMode.blend;
      _bloodSprayMaterial.alphaMode = AlphaMode.blend;
    }
  }

  void setDebugHitboxes({
    required bool enabled,
    required double forwardScale,
    required double sideScale,
    required double verticalScale,
    required double radiusScale,
    double torsoForward = 1,
    double torsoSide = 1,
    double torsoVertical = 1,
    double headForward = 1,
    double headSide = 1,
    double headVertical = 1,
    double rightArmForward = 1,
    double rightArmSide = 1,
    double rightArmVertical = 1,
    double leftArmForward = 1,
    double leftArmSide = 1,
    double leftArmVertical = 1,
    double torsoOffsetX = 0, double torsoOffsetY = 0, double torsoOffsetZ = 0,
    double headOffsetX = 0, double headOffsetY = 0, double headOffsetZ = 0,
    double rightArmOffsetX = 0, double rightArmOffsetY = 0, double rightArmOffsetZ = 0,
    double leftArmOffsetX = 0, double leftArmOffsetY = 0, double leftArmOffsetZ = 0,
  }) {
    _debugHitboxes = enabled;
    _debugHitboxForward = forwardScale;
    _debugHitboxSide = sideScale;
    _debugHitboxVertical = verticalScale;
    _debugHitboxRadius = radiusScale;
    _debugTorsoForward = torsoForward;
    _debugTorsoSide = torsoSide;
    _debugTorsoVertical = torsoVertical;
    _debugHeadForward = headForward;
    _debugHeadSide = headSide;
    _debugHeadVertical = headVertical;
    _debugRightArmForward = rightArmForward;
    _debugRightArmSide = rightArmSide;
    _debugRightArmVertical = rightArmVertical;
    _debugLeftArmForward = leftArmForward;
    _debugLeftArmSide = leftArmSide;
    _debugLeftArmVertical = leftArmVertical;
    _debugTorsoOffsetX = torsoOffsetX; _debugTorsoOffsetY = torsoOffsetY; _debugTorsoOffsetZ = torsoOffsetZ;
    _debugHeadOffsetX = headOffsetX; _debugHeadOffsetY = headOffsetY; _debugHeadOffsetZ = headOffsetZ;
    _debugRightArmOffsetX = rightArmOffsetX; _debugRightArmOffsetY = rightArmOffsetY; _debugRightArmOffsetZ = rightArmOffsetZ;
    _debugLeftArmOffsetX = leftArmOffsetX; _debugLeftArmOffsetY = leftArmOffsetY; _debugLeftArmOffsetZ = leftArmOffsetZ;

    double safe(double v) => v.abs().clamp(.001, 1000.0).toDouble();

    for (final visual in fighters.values) {
      visual.debugHitboxRoot.visible = enabled && _developerDebugLayerEnabled;
      final parts = visual.debugHitboxRoot.children;
      if (parts.length >= 6) {
        parts[0].position = vm.Vector3(_debugTorsoOffsetY, 1.02 + _debugTorsoOffsetZ, .02 * _debugHitboxForward + _debugTorsoOffsetX);
        parts[1].position = vm.Vector3(_debugHeadOffsetY, 1.63 + _debugHeadOffsetZ, .27 * _debugHitboxForward + _debugHeadOffsetX);
        parts[2].position = vm.Vector3(-.25 * _debugHitboxSide + _debugRightArmOffsetY, 1.16 + _debugRightArmOffsetZ, .35 * _debugHitboxForward + _debugRightArmOffsetX);
        parts[3].position = vm.Vector3(.25 * _debugHitboxSide + _debugLeftArmOffsetY, 1.05 + _debugLeftArmOffsetZ, -.10 * _debugHitboxForward + _debugLeftArmOffsetX);
        parts[4].position = vm.Vector3(-.13 * _debugHitboxSide, .48, -.30 * _debugHitboxForward);
        parts[5].position = vm.Vector3(.13 * _debugHitboxSide, .48, -.30 * _debugHitboxForward);

        parts[0].scale = vm.Vector3(
          .36 * safe(_debugHitboxSide * _debugHitboxRadius * _debugTorsoSide),
          .66 * safe(_debugHitboxVertical * _debugHitboxRadius * _debugTorsoVertical),
          .40 * safe(_debugHitboxForward * _debugHitboxRadius * _debugTorsoForward),
        );
        parts[1].scale = vm.Vector3(
          .33 * safe(_debugHitboxSide * _debugHitboxRadius * _debugHeadSide),
          .33 * safe(_debugHitboxVertical * _debugHitboxRadius * _debugHeadVertical),
          .33 * safe(_debugHitboxForward * _debugHitboxRadius * _debugHeadForward),
        );
        parts[2].scale = vm.Vector3(
          .18 * safe(_debugHitboxSide * _debugHitboxRadius * _debugRightArmSide),
          .25 * safe(_debugHitboxVertical * _debugHitboxRadius * _debugRightArmVertical),
          .72 * safe(_debugHitboxForward * _debugHitboxRadius * _debugRightArmForward),
        );
        parts[3].scale = vm.Vector3(
          .18 * safe(_debugHitboxSide * _debugHitboxRadius * _debugLeftArmSide),
          .50 * safe(_debugHitboxVertical * _debugHitboxRadius * _debugLeftArmVertical),
          .22 * safe(_debugHitboxForward * _debugHitboxRadius * _debugLeftArmForward),
        );
        parts[4].scale = vm.Vector3(
          .18 * safe(_debugHitboxSide * _debugHitboxRadius),
          .78 * safe(_debugHitboxVertical * _debugHitboxRadius),
          .22 * safe(_debugHitboxForward * _debugHitboxRadius),
        );
        parts[5].scale = vm.Vector3(
          .18 * safe(_debugHitboxSide * _debugHitboxRadius),
          .78 * safe(_debugHitboxVertical * _debugHitboxRadius),
          .22 * safe(_debugHitboxForward * _debugHitboxRadius),
        );
        if (parts.length >= 8) {
          parts[6].position = vm.Vector3(
            -.25 * _debugHitboxSide + _debugRightArmOffsetY,
            1.16 + _debugRightArmOffsetZ,
            .73 * _debugHitboxForward + _debugRightArmOffsetX,
          );
          parts[6].scale = vm.Vector3.all(
            .22 * safe(_debugHitboxRadius * (_debugRightArmSide.abs() + _debugRightArmForward.abs()) * .5),
          );
          parts[7].position = vm.Vector3(
            .25 * _debugHitboxSide + _debugLeftArmOffsetY,
            1.05 + _debugLeftArmOffsetZ,
            -.24 * _debugHitboxForward + _debugLeftArmOffsetX,
          );
          parts[7].scale = vm.Vector3.all(
            .22 * safe(_debugHitboxRadius * (_debugLeftArmSide.abs() + _debugLeftArmForward.abs()) * .5),
          );
        }
      }
      if (!enabled) visual.debugLaserHitbox.visible = false;
    }
  }

  void setDeveloperDebugLayerEnabled(bool enabled) {
    if (!ready || _developerDebugLayerEnabled == enabled) return;
    _developerDebugLayerEnabled = enabled;

    final boundary = _arenaBoundaryRoot;
    if (enabled) {
      if (boundary != null) scene.add(boundary);
      scene.add(_debugKillPathNode);
      for (final visual in fighters.values) {
        visual.root.add(visual.debugHitboxRoot);
        visual.aimRoot.add(visual.debugLaserHitbox);
        visual.debugHitboxRoot.visible = _debugHitboxes;
        visual.forceLaserRefresh = true;
      }
    } else {
      boundary?.detach();
      _debugKillPathNode
        ..visible = false
        ..detach();
      for (final visual in fighters.values) {
        visual.debugHitboxRoot
          ..visible = false
          ..detach();
        visual.debugLaserHitbox
          ..visible = false
          ..detach();
      }
    }
  }

  void setDeveloperKillPath({
    required bool visible,
    required double originX,
    required double originY,
    required double dirX,
    required double dirY,
    required double length,
    double offsetX = 0,
    double offsetY = 0,
    double angleOffsetRadians = 0,
    double thickness = 1,
    double height = .055,
  }) {
    if (!ready || !_developerDebugLayerEnabled) return;
    if (!visible || length.abs() < .000001) {
      _debugKillPathNode.visible = false;
      return;
    }
    final baseAngle = math.atan2(dirY, dirX) + angleOffsetRadians;
    final dx = math.cos(baseAngle);
    final dy = math.sin(baseAngle);
    final ox = originX + offsetX;
    final oy = originY + offsetY;
    final endX = ox + dx * length;
    final endY = oy + dy * length;
    final a = worldPosition(ox, oy, height: height);
    final b = worldPosition(endX, endY, height: height);
    final mx = (a.x + b.x) * .5;
    final mz = (a.z + b.z) * .5;
    final worldLength = math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.z - a.z, 2)).toDouble();
    final yaw = math.atan2(b.x - a.x, b.z - a.z);
    _debugKillPathNode
      ..visible = true
      ..position = vm.Vector3(mx, height, mz)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw)
      ..scale = vm.Vector3(
        .85 * thickness.abs().clamp(.001, 1000.0),
        .85 * thickness.abs().clamp(.001, 1000.0),
        worldLength,
      );
  }

  void setBackgroundTuning({
    required double rotationSpeed,
    required double scale,
  }) {
    _backgroundRotationSpeed = rotationSpeed;
    _backgroundScale = scale.abs().clamp(.001, 1000.0).toDouble();
    final sky = _lobbyBackdropBase;
    if (sky != null) {
      sky.scale = vm.Vector3.all(_lobbyBackdropScale * _backgroundScale);
      if (!hasAnimatedBackground) {
        sky.rotation = vm.Quaternion.copy(_lobbyBackdropBaseRotation);
      }
    }
    _lastBackgroundUpdateSeconds = -999;
  }

  Future<void> setBackgroundImage(
    Uint8List bytes, {
    required KillerKilledBackgroundFit fit,
  }) async {
    if (bytes.isEmpty || _originalBackgroundMeshes.isEmpty) return;
    _backgroundFit = fit;
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1024);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    codec.dispose();
    const targetSize = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0xFF05060B), ui.BlendMode.src);

    void drawFitted(ui.Rect dst) {
      final src = ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble());
      canvas.drawImageRect(
        source,
        src,
        dst,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    }

    if (fit == KillerKilledBackgroundFit.repeat) {
      final tileW = source.width >= source.height ? 512.0 : 384.0;
      final tileH = tileW * source.height / source.width;
      for (double y = 0; y < targetSize; y += tileH) {
        for (double x = 0; x < targetSize; x += tileW) {
          drawFitted(ui.Rect.fromLTWH(x, y, tileW, tileH));
        }
      }
    } else {
      final imageAspect = source.width / source.height;
      final targetAspect = 1.0;
      double w;
      double h;
      if ((fit == KillerKilledBackgroundFit.cover && imageAspect > targetAspect) ||
          (fit == KillerKilledBackgroundFit.contain && imageAspect < targetAspect)) {
        h = targetSize;
        w = h * imageAspect;
      } else {
        w = targetSize;
        h = w / imageAspect;
      }
      drawFitted(
        ui.Rect.fromLTWH(
          (targetSize - w) * .5,
          (targetSize - h) * .5,
          w,
          h,
        ),
      );
    }

    final rendered = await recorder.endRecording().toImage(1024, 1024);
    source.dispose();
    final texture = await Texture2D.fromImage(rendered);
    rendered.dispose();
    _customBackgroundTexture = texture;

    final material = _unlit(const Color(0xFFFFFFFF))
      ..name = 'developer_background_image'
      ..baseColorTexture = texture
      ..doubleSided = true;

    for (final entry in _originalBackgroundMeshes.entries) {
      final rebuilt = <MeshPrimitive>[];
      for (final primitive in entry.value.primitives) {
        rebuilt.add(
          MeshPrimitive(primitive.geometry, material)
            ..castsShadow = false,
        );
      }
      entry.key.mesh = Mesh.primitives(primitives: rebuilt);
    }
  }

  void restoreOriginalBackground() {
    for (final entry in _originalBackgroundMeshes.entries) {
      entry.key.mesh = entry.value;
    }
    _customBackgroundTexture = null;
  }

  void setObstacle({required bool visible, double x = .5, double y = .5}) {
    final visibilityChanged = _lastObstacleVisible != visible;
    final positionChanged = (x - _lastObstacleX).abs() > .000001 ||
        (y - _lastObstacleY).abs() > .000001;
    if (!visibilityChanged && (!visible || !positionChanged)) return;

    _lastObstacleVisible = visible;
    _obstacleRoot.visible = visible;
    if (!visible) return;

    _lastObstacleX = x;
    _lastObstacleY = y;
    final world = worldPosition(x, y);
    _obstacleRoot.position = vm.Vector3(world.x, _mapRoot?.position.y ?? 0, world.z);
  }

  KillerKilledFighterVisual addFighter(
    int id,
    KillerKilledAvatar avatar,
    Color accentColor,
  ) {
    final existing = fighters[id];
    if (existing != null) return existing;

    final visual = _buildFighter(id, avatar, accentColor);
    _applyGunDeveloperTransform(visual);
    fighters[id] = visual;
    scene.add(visual.root);
    if (_developerDebugLayerEnabled) {
      visual.root.add(visual.debugHitboxRoot);
      visual.aimRoot.add(visual.debugLaserHitbox);
      visual.debugHitboxRoot.visible = _debugHitboxes;
    }
    return visual;
  }

  void setGunDeveloperTransform({
    required double x,
    required double y,
    required double z,
    required double rotX,
    required double rotY,
    required double rotZ,
  }) {
    _gunVisualPosition = vm.Vector3(x, y, z);
    _gunVisualRotation = vm.Vector3(rotX, rotY, rotZ);
    for (final visual in fighters.values) {
      _applyGunDeveloperTransform(visual);
    }
  }

  void _applyGunDeveloperTransform(KillerKilledFighterVisual visual) {
    visual.gunModel.position = vm.Vector3(
      _gunVisualPosition.x,
      _gunVisualPosition.y,
      _gunVisualPosition.z,
    );
    visual.gunModel.scale = vm.Vector3(
      _gunVisualScale.x,
      _gunVisualScale.y,
      _gunVisualScale.z,
    );
    var rotation = vm.Quaternion.identity();
    if (_gunVisualRotation.x != 0) {
      rotation = rotation * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), _gunVisualRotation.x);
    }
    if (_gunVisualRotation.y != 0) {
      rotation = rotation * vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _gunVisualRotation.y);
    }
    if (_gunVisualRotation.z != 0) {
      rotation = rotation * vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), _gunVisualRotation.z);
    }
    visual.gunModel.rotation = rotation;
  }

  void setFighterAvatar(int id, KillerKilledAvatar avatar) {
    final visual = fighters[id];
    if (visual == null) return;
    _applyAvatarToModel(visual.model, avatar);
  }

  void _applyAvatarToModel(Node model, KillerKilledAvatar avatar) {
    final visible = avatar.visibleNodeNames;
    for (final name in KillerKilledAvatar.customizableNodeNames) {
      final node = model.getChildByName(name);
      if (node != null) node.visible = visible.contains(name);
    }
    final body = model.getChildByName('Body_010');
    if (body != null) body.visible = true;
  }

  KillerKilledFighterVisual _buildFighter(
    int id,
    KillerKilledAvatar avatar,
    Color accentColor,
  ) {
    final root = Node(name: 'fighter_$id');
    final bodyRoot = Node(name: 'body_root_$id');
    root.add(bodyRoot);

    final model = _characterTemplate.clone(recursive: true)
      ..name = 'creative_character_$id'
      ..scale = vm.Vector3.all(1.02)
      // The Creative Characters rig faces local +Z, which is the arena's
      // gameplay-forward axis.
      ..rotation = vm.Quaternion.identity();
    bodyRoot.add(model);

    // Selection outlines never change during gameplay. Configure them once
    // instead of touching every mesh on every frame for every fighter.
    for (final meshNode in model.meshNodes) {
      meshNode.highlightColor = null;
      meshNode.raycastable = false;
      if (_thermalOptimized) meshNode.castsShadows = false;
    }

    _applyAvatarToModel(model, avatar);

    Node bone(String name) {
      final node = model.getChildByName(name);
      if (node == null) {
        throw StateError('Missing character bone: $name');
      }
      return node;
    }

    final hips = bone('Hips');
    final spine = bone('Spine');
    final spine1 = bone('Spine1');
    // Creative Characters uses a two-spine chain. Keep a detached no-op node
    // for the optional third chest bone so the animation code stays generic.
    final spine2 = model.getChildByName('Spine2') ?? Node(name: 'virtual_spine2_$id');
    final neck = bone('Neck');
    final head = bone('Head');
    final leftShoulder = bone('LeftShoulder');
    final rightShoulder = bone('RightShoulder');
    final leftArm = bone('LeftArm');
    final rightArm = bone('RightArm');
    final leftForeArm = bone('LeftForeArm');
    final rightForeArm = bone('RightForeArm');
    final leftHand = bone('LeftHand');
    final rightHand = bone('RightHand');
    final leftHandProp = bone('LeftHandProp');
    final leftUpLeg = bone('LeftUpLeg');
    final rightUpLeg = bone('RightUpLeg');
    final leftLeg = bone('LeftLeg');
    final rightLeg = bone('RightLeg');
    final leftFoot = bone('LeftFoot');
    final rightFoot = bone('RightFoot');

    final baseRotations = <String, vm.Quaternion>{
      'hips': vm.Quaternion.copy(hips.rotation),
      'spine': vm.Quaternion.copy(spine.rotation),
      'spine1': vm.Quaternion.copy(spine1.rotation),
      'spine2': vm.Quaternion.copy(spine2.rotation),
      'neck': vm.Quaternion.copy(neck.rotation),
      'head': vm.Quaternion.copy(head.rotation),
      'leftShoulder': vm.Quaternion.copy(leftShoulder.rotation),
      'rightShoulder': vm.Quaternion.copy(rightShoulder.rotation),
      'leftArm': vm.Quaternion.copy(leftArm.rotation),
      'rightArm': vm.Quaternion.copy(rightArm.rotation),
      'leftForeArm': vm.Quaternion.copy(leftForeArm.rotation),
      'rightForeArm': vm.Quaternion.copy(rightForeArm.rotation),
      'leftHand': vm.Quaternion.copy(leftHand.rotation),
      'rightHand': vm.Quaternion.copy(rightHand.rotation),
      'leftUpLeg': vm.Quaternion.copy(leftUpLeg.rotation),
      'rightUpLeg': vm.Quaternion.copy(rightUpLeg.rotation),
      'leftLeg': vm.Quaternion.copy(leftLeg.rotation),
      'rightLeg': vm.Quaternion.copy(rightLeg.rotation),
      'leftFoot': vm.Quaternion.copy(leftFoot.rotation),
      'rightFoot': vm.Quaternion.copy(rightFoot.rotation),
    };

    final basePositions = <String, vm.Vector3>{
      'hips': vm.Vector3.copy(hips.position),
      'spine': vm.Vector3.copy(spine.position),
      'spine1': vm.Vector3.copy(spine1.position),
      'spine2': vm.Vector3.copy(spine2.position),
      'neck': vm.Vector3.copy(neck.position),
      'head': vm.Vector3.copy(head.position),
      'leftShoulder': vm.Vector3.copy(leftShoulder.position),
      'rightShoulder': vm.Vector3.copy(rightShoulder.position),
      'leftArm': vm.Vector3.copy(leftArm.position),
      'rightArm': vm.Vector3.copy(rightArm.position),
      'leftForeArm': vm.Vector3.copy(leftForeArm.position),
      'rightForeArm': vm.Vector3.copy(rightForeArm.position),
      'leftHand': vm.Vector3.copy(leftHand.position),
      'rightHand': vm.Vector3.copy(rightHand.position),
      'leftUpLeg': vm.Vector3.copy(leftUpLeg.position),
      'rightUpLeg': vm.Vector3.copy(rightUpLeg.position),
      'leftLeg': vm.Vector3.copy(leftLeg.position),
      'rightLeg': vm.Vector3.copy(rightLeg.position),
      'leftFoot': vm.Vector3.copy(leftFoot.position),
      'rightFoot': vm.Vector3.copy(rightFoot.position),
    };

    // Creative Characters' imported hand labels are visually mirrored in this
    // scene. LeftHandProp is the character's visible RIGHT hand, so the pistol
    // must be attached here to appear in the correct hand on screen.
    final gunBaseRotation = vm.Quaternion(
      0.81208887,
      -0.34605342,
      -0.34939943,
      -0.31413173,
    );
    final gunRoot = Node(name: 'gun_$id')
      ..position = vm.Vector3.zero()
      ..rotation = vm.Quaternion.copy(gunBaseRotation);
    // Offset in the pistol's own local axes: slightly higher and a little back
    // toward the wrist, without changing the hand/arm pose.
    final gunContent = Node(name: 'gun_content_$id');
    gunRoot.add(gunContent);

    // Real P250 GLB. The source mesh is centered around its length axis with
    // the muzzle at local +Z. Scale/offset align that muzzle to the exact same
    // aim point used by the previous lightweight procedural pistol.
    final gunModel = _gunTemplate.clone(recursive: true)
      ..name = 'p250_$id'
      // Flip ONLY the visual mesh side-to-side. This mirrors the pistol's
      // appearance without changing the weapon rig, laser direction, or hit
      // detection.
      ..scale = vm.Vector3(-.40, .40, .40)
      ..position = vm.Vector3(0, -.078, .230);
    for (final meshNode in gunModel.meshNodes) {
      meshNode
        ..highlightColor = null
        ..castsShadows = false
        ..raycastable = false;
    }
    gunContent.add(gunModel);
    leftHandProp.add(gunRoot);

    // aimRoot now lives INSIDE the pistol mesh transform so any developer
    // adjustment to the visible gun (position / rotation) automatically moves
    // the laser origin and the gameplay hit ray with the real muzzle.
    final aimRoot = Node(name: 'aim_root_$id')
      // Local muzzle point inside the imported P250 mesh. With the default
      // mesh scale/offset this resolves to the same external muzzle tip.
      ..position = vm.Vector3(0, .22, .50);
    final laserGlow = _meshNode(
      _geo.laserGlow,
      _laserGlowMaterial,
      name: 'laser_glow',
      position: vm.Vector3(0, 0, 50.0),
      scale: vm.Vector3(.55, .55, 100),
    )
      ..visible = false
      ..castsShadows = false
      ..raycastable = false;
    final laser = _meshNode(
      _geo.laser,
      _laserMaterial,
      name: 'laser',
      position: vm.Vector3(0, 0, 50.0),
      scale: vm.Vector3(.42, .42, 100),
    )
      ..visible = false
      ..castsShadows = false
      ..raycastable = false;
    final shotTracer = _meshNode(
      _geo.laser,
      _shotMaterial,
      name: 'shot_tracer',
      position: vm.Vector3(0, 0, 3.0),
      scale: vm.Vector3(1.45, 1.45, 6.0),
    )
      ..visible = false
      ..castsShadows = false
      ..raycastable = false;
    final muzzleFlash = _meshNode(
      _geo.muzzleFlash,
      _shotMaterial,
      name: 'muzzle_flash',
      position: vm.Vector3(0, 0, .015),
      scale: vm.Vector3.zero(),
    )
      ..castsShadows = false
      ..raycastable = false;
    aimRoot.addAll([laserGlow, laser, shotTracer, muzzleFlash]);
    gunModel.add(aimRoot);

    // Disable flutter_scene selection outlines completely for the weapon and
    // beam. A transparent highlight color still registers as a highlighted
    // node, so use null (no highlight pass) rather than RGBA(0,0,0,0).
    gunRoot.highlightColor = null;
    gunContent.highlightColor = null;
    aimRoot.highlightColor = null;
    laser.highlightColor = null;
    laserGlow.highlightColor = null;
    shotTracer.highlightColor = null;
    muzzleFlash.highlightColor = null;

    // A different believable face-down arm arrangement is picked once per
    // fighter. It is then frozen, so corpses never keep the standing/walking
    // animation after hitting the floor.
    double rr(double min, double max) => min + _random.nextDouble() * (max - min);
    final deathPose = <String, vm.Vector3>{
      'leftShoulder': vm.Vector3(rr(-.25, .18), rr(-.35, .20), rr(.30, .90)),
      'rightShoulder': vm.Vector3(rr(-.25, .18), rr(-.20, .35), rr(-.90, -.30)),
      'leftArm': vm.Vector3(rr(-.45, .35), rr(-.30, .30), rr(.35, 1.05)),
      'rightArm': vm.Vector3(rr(-.45, .35), rr(-.30, .30), rr(-1.05, -.35)),
      'leftForeArm': vm.Vector3(rr(-.55, .35), rr(-.22, .22), rr(-.20, .55)),
      'rightForeArm': vm.Vector3(rr(-.55, .35), rr(-.22, .22), rr(-.55, .20)),
      'leftHand': vm.Vector3(rr(-.35, .35), rr(-.30, .30), rr(-.45, .45)),
      'rightHand': vm.Vector3(rr(-.35, .35), rr(-.30, .30), rr(-.45, .45)),
    };

    final debugHitboxRoot = Node(name: 'debug_hitbox_$id')..visible = _debugHitboxes;
    Node debugPart(String name, vm.Vector3 pos, vm.Vector3 scale) => _meshNode(
          _geo.debugBox,
          _debugHitboxMaterial,
          name: name,
          position: pos,
          scale: scale,
        )
          ..castsShadows = false
          ..raycastable = false;
    debugHitboxRoot.addAll([
      debugPart('debug_torso_$id', vm.Vector3(0, 1.02, .02), vm.Vector3(.36, .66, .40)),
      debugPart('debug_head_$id', vm.Vector3(0, 1.63, .27), vm.Vector3(.32, .34, .32)),
      debugPart('debug_arm_r_$id', vm.Vector3(-.25, 1.16, .35), vm.Vector3(.18, .25, .72)),
      debugPart('debug_arm_l_$id', vm.Vector3(.25, 1.05, -.10), vm.Vector3(.18, .50, .22)),
      debugPart('debug_leg_r_$id', vm.Vector3(-.13, .48, -.30), vm.Vector3(.18, .78, .22)),
      debugPart('debug_leg_l_$id', vm.Vector3(.13, .48, -.30), vm.Vector3(.18, .78, .22)),
      // Explicit hand hitboxes: hands are valid damage targets exactly like the torso.
      debugPart('debug_hand_r_$id', vm.Vector3(-.25, 1.16, .73), vm.Vector3(.22, .22, .22)),
      debugPart('debug_hand_l_$id', vm.Vector3(.25, 1.05, -.24), vm.Vector3(.22, .22, .22)),
    ]);
    final debugLaserHitbox = _meshNode(
      _geo.debugLaser,
      _debugLaserHitboxMaterial,
      name: 'debug_laser_hitbox_$id',
      position: vm.Vector3(0, .012, 3),
      scale: vm.Vector3(1.7, 1.7, 6),
    )
      ..visible = false
      ..castsShadows = false
      ..raycastable = false;
    return KillerKilledFighterVisual(
      root: root,
      bodyRoot: bodyRoot,
      model: model,
      hips: hips,
      spine: spine,
      spine1: spine1,
      spine2: spine2,
      neck: neck,
      head: head,
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftArm: leftArm,
      rightArm: rightArm,
      leftForeArm: leftForeArm,
      rightForeArm: rightForeArm,
      leftHand: leftHand,
      rightHand: rightHand,
      leftUpLeg: leftUpLeg,
      rightUpLeg: rightUpLeg,
      leftLeg: leftLeg,
      rightLeg: rightLeg,
      leftFoot: leftFoot,
      rightFoot: rightFoot,
      baseRotations: baseRotations,
      basePositions: basePositions,
      gunRoot: gunRoot,
      gunBaseRotation: gunBaseRotation,
      gunModel: gunModel,
      aimRoot: aimRoot,
      laserGlow: laserGlow,
      laser: laser,
      muzzleFlash: muzzleFlash,
      shotTracer: shotTracer,
      debugHitboxRoot: debugHitboxRoot,
      debugLaserHitbox: debugLaserHitbox,
      deathPose: deathPose,
      poseNodes: <String, Node>{
        'hips': hips,
        'spine': spine,
        'spine1': spine1,
        'spine2': spine2,
        'neck': neck,
        'head': head,
        'leftShoulder': leftShoulder,
        'rightShoulder': rightShoulder,
        'leftArm': leftArm,
        'rightArm': rightArm,
        'leftForeArm': leftForeArm,
        'rightForeArm': rightForeArm,
        'leftHand': leftHand,
        'rightHand': rightHand,
        'leftUpLeg': leftUpLeg,
        'rightUpLeg': rightUpLeg,
        'leftLeg': leftLeg,
        'rightLeg': rightLeg,
        'leftFoot': leftFoot,
        'rightFoot': rightFoot,
      },
      accentColor: accentColor,
    );
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

  void setFighterVisible(int id, bool visible) {
    final visual = fighters[id];
    if (visual == null || visual.root.visible == visible) return;
    visual.root.visible = visible;
  }

  void updateFighter({
    required int id,
    required double x,
    required double y,
    required double angle,
    required double walkTime,
    required double speed,
    required double forwardMotion,
    required double strafeMotion,
    required double fall,
    required bool visible,
    required bool activeShooter,
    required bool laserVisible,
    required double laserLength,
    required double shotFlash,
    double hitFlash = 0,
    bool allowSkeletonUpdate = true,
  }) {
    final visual = fighters[id];
    if (visual == null) return;

    final visibilityChanged = visual.root.visible != visible;
    if (visibilityChanged) {
      visual.root.visible = visible;
      if (visible) visual.forceVisualRefresh = true;
    }
    if (!visible) return;

    if (visual.skeletonUpdateAllowed != allowSkeletonUpdate) {
      visual.skeletonUpdateAllowed = allowSkeletonUpdate;
      if (allowSkeletonUpdate) visual.forceVisualRefresh = true;
    }

    // Root transforms are deliberately applied every live sync. This is a tiny
    // cost (only a handful of Vector3/Quaternion assignments for <= 6 fighters)
    // and prevents a stale-transform failure where camera/HUD positions advance
    // while the rendered GLB stays at its previous location. Expensive skeleton
    // work remains gated below, so this does not undo the optimization pass.
    {
      // Death offsets are in gameplay-space X/Z plus vertical Y. The whole
      // fighter rig is scaled at the root, so weapon, muzzle/aim, laser and
      // visual hitboxes stay perfectly registered when player size changes.
      final deathPos = worldPosition(
        x + _deathOffsetX * fall,
        y + _deathOffsetZ * fall,
      );
      visual.root.position = vm.Vector3(
        deathPos.x,
        _deathOffsetY * fall,
        deathPos.z,
      );
      final deathScaleBlend = 1.0 + (_deathScale - 1.0) * fall;
      visual.root.scale = vm.Vector3.all(_playerScale * deathScaleBlend);

      final yaw = (math.pi / 2) - angle;
      final yawQ = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
      if (fall > 0) {
        final faceDownQ = vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          fall * (math.pi / 2),
        );
        visual.root.rotation = yawQ * faceDownQ;
      } else {
        visual.root.rotation = yawQ;
      }
      visual
        ..lastRootX = x
        ..lastRootY = y
        ..lastRootAngle = angle
        ..lastRootFall = fall;
    }

    final moving = speed.abs() > .003 ||
        forwardMotion.abs() > .003 ||
        strafeMotion.abs() > .003;
    final transientPose = (fall > .0001 && fall < .9999) ||
        shotFlash > .0001 || hitFlash > .0001;
    final inputChanged = (speed - visual.lastSkeletonSpeed).abs() > .001 ||
        (forwardMotion - visual.lastForwardMotion).abs() > .001 ||
        (strafeMotion - visual.lastStrafeMotion).abs() > .001 ||
        (fall - visual.lastSkeletonFall).abs() > .0005;
    final idleCadence = laserVisible ? (1 / 15) : (id == 0 ? (1 / 20) : .12);
    final idleDue = (walkTime - visual.lastSkeletonWalkTime).abs() >= idleCadence;
    final updateSkeleton = allowSkeletonUpdate &&
        (visual.forceVisualRefresh || moving || transientPose || inputChanged || idleDue);

    if (updateSkeleton) {
    final alive = (1.0 - fall).clamp(0.0, 1.0).toDouble();
    final move = fall > 0 ? 0.0 : (speed / .25).clamp(0.0, 1.0).toDouble();
    final gaitPhase = walkTime * 7.8 * _walkCycleSpeed;
    final rawStep = math.sin(gaitPhase) * _walkPhase1 +
        math.sin(gaitPhase * 2.0) * _walkPhase2 +
        math.sin(gaitPhase * 3.0) * _walkPhase3;
    final step = fall > 0 ? 0.0 : rawStep.clamp(-1.35, 1.35).toDouble();
    final idle = fall > 0 ? 0.0 : math.sin(walkTime * 1.65 + id * .7);
    final forwardIntent = forwardMotion.clamp(-1.0, 1.0).toDouble();
    final strafeIntent = strafeMotion.clamp(-1.0, 1.0).toDouble();
    final recoil = (shotFlash / .22).clamp(0.0, 1.0).toDouble();
    final hit = hitFlash.clamp(0.0, 1.0).toDouble();
    final aim = alive;

    final forwardAmount = forwardIntent.abs();
    final strafeAmount = strafeIntent.abs();
    final intentTotal = forwardAmount + strafeAmount;
    final forwardWeight = intentTotal > .001 ? forwardAmount / intentTotal : 0.0;
    final strafeWeight = intentTotal > .001 ? strafeAmount / intentTotal : 0.0;
    final gaitDirection = forwardIntent < -.08 ? -1.0 : 1.0;
    final forwardStep = step * gaitDirection * move * forwardWeight;

    // The Creative Characters legs are mirrored. Applying opposite local-Z
    // rotations made both feet travel the same world direction at once. Using
    // the SAME local-Z phase makes one foot advance while the other goes back.
    double leftSideSwing = 0;
    double rightSideSwing = 0;
    final sideAmplitude = .42 * move * strafeWeight;
    if (strafeIntent > .04) {
      // Move right: right foot leads, then the left foot follows.
      rightSideSwing = math.max(0.0, step) * sideAmplitude;
      leftSideSwing = -math.max(0.0, -step) * sideAmplitude;
    } else if (strafeIntent < -.04) {
      // Move left: left foot leads, then the right foot follows.
      leftSideSwing = math.max(0.0, step) * sideAmplitude;
      rightSideSwing = -math.max(0.0, -step) * sideAmplitude;
    }

    // Only vertical breathing/bounce here. Side movement rotates the whole
    // fighter in gameplay; it must never look like the body is falling/leaning.
    visual.bodyRoot.position = vm.Vector3(
      hit * -.035,
      .010 * idle * (1 - move) + _bodyBob * step.abs() * move,
      0,
    );
    visual.bodyRoot.rotation = _withDelta(
      vm.Quaternion.identity(),
      x: -_bodyLean * move,
      z: -.085 * hit + .012 * idle * (1 - move),
    );

    // Natural forward/back gait: opposite feet in world space, with real knee
    // flex. Backward simply reverses the phase while keeping the torso facing
    // the same way. Sideways uses local-X stepping instead of fake forward steps.
    visual.leftUpLeg.rotation = _withDelta(
      visual.baseRotations['leftUpLeg']!,
      x: leftSideSwing,
      z: _thighSwing * forwardStep + .16 * fall,
    );
    visual.rightUpLeg.rotation = _withDelta(
      visual.baseRotations['rightUpLeg']!,
      x: rightSideSwing,
      z: _thighSwing * forwardStep - .12 * fall,
    );
    visual.leftLeg.rotation = _withDelta(
      visual.baseRotations['leftLeg']!,
      z: _kneeBend * math.max(0.0, -forwardStep) + .15 * leftSideSwing.abs() + .25 * fall,
    );
    visual.rightLeg.rotation = _withDelta(
      visual.baseRotations['rightLeg']!,
      z: -_kneeBend * math.max(0.0, forwardStep) - .15 * rightSideSwing.abs() - .18 * fall,
    );
    visual.leftFoot.rotation = _withDelta(
      visual.baseRotations['leftFoot']!,
      x: -.10 * leftSideSwing,
      z: -_footSwing * forwardStep,
    );
    visual.rightFoot.rotation = _withDelta(
      visual.baseRotations['rightFoot']!,
      x: -.10 * rightSideSwing,
      z: _footSwing * forwardStep,
    );

    visual.hips.rotation = _withDelta(
      visual.baseRotations['hips']!,
      y: .030 * step * move,
      z: .10 * fall,
    );
    visual.spine.rotation = _withDelta(
      visual.baseRotations['spine']!,
      x: -.020 * move,
      z: -.020 * step * move - .12 * hit,
    );
    visual.spine1.rotation = _withDelta(
      visual.baseRotations['spine1']!,
      x: .010 * idle * (1 - move) - .035 * aim + .06 * recoil,
      z: .014 * step * move,
    );
    visual.spine2.rotation = _withDelta(
      visual.baseRotations['spine2']!,
      z: .016 * step * move,
    );

    // The imported rig is visually mirrored: the bones named Left* drive the
    // character's visible RIGHT arm. Keep that arm fully extended with the gun.
    // The visible LEFT arm (Right* bones) hangs relaxed at idle and rises
    // diagonally while walking, then smoothly lowers again when movement stops.
    vm.Vector3 death(String key) => visual.deathPose[key]!;
    double mix(double aliveValue, double deadValue) => aliveValue * alive + deadValue * fall;
    double pose(double idleValue, double walkingValue) =>
        idleValue + (walkingValue - idleValue) * move * _supportArmWalkBlend;

    // Visible RIGHT arm: pistol arm, stretched forward. Values are the mirrored
    // counterpart of the previously tested opposite-hand aiming pose.
    visual.leftShoulder.rotation = _withDelta(
      visual.baseRotations['leftShoulder']!,
      x: mix(.101 + .012 * recoil - _shoulderSwing * step * move * .35, death('leftShoulder').x),
      y: mix(-.470, death('leftShoulder').y),
      z: mix(-.229, death('leftShoulder').z),
    );
    visual.leftArm.rotation = _withDelta(
      visual.baseRotations['leftArm']!,
      x: mix(-.675 + .028 * recoil + _rightArmPitch - _armSwing * step * move * .22, death('leftArm').x),
      y: mix(.386 + _rightArmYaw, death('leftArm').y),
      z: mix(-.853, death('leftArm').z),
    );
    visual.leftForeArm.rotation = _withDelta(
      visual.baseRotations['leftForeArm']!,
      x: mix(-.173 + .022 * recoil, death('leftForeArm').x),
      y: mix(-.003, death('leftForeArm').y),
      z: mix(.304, death('leftForeArm').z),
    );

    // Visible LEFT arm: relaxed down while idle, raised diagonally on walk.
    visual.rightShoulder.rotation = _withDelta(
      visual.baseRotations['rightShoulder']!,
      x: mix(pose(.126, .365) + _shoulderSwing * step * move, death('rightShoulder').x),
      y: mix(pose(-.284, .003), death('rightShoulder').y),
      z: mix(pose(.200, -.468) - .026 * step * move, death('rightShoulder').z),
    );
    visual.rightArm.rotation = _withDelta(
      visual.baseRotations['rightArm']!,
      x: mix(pose(-.651, -.868) - _armSwing * step * move + _supportArmOffsetX * move + _leftArmPitch, death('rightArm').x),
      y: mix(pose(-.688, -.644) + _supportArmOffsetY * move + _leftArmYaw, death('rightArm').y),
      z: mix(pose(.366, .738) + .035 * step * move + _supportArmOffsetZ * move, death('rightArm').z),
    );
    visual.rightForeArm.rotation = _withDelta(
      visual.baseRotations['rightForeArm']!,
      x: mix(pose(-.051, .407) + .024 * step * move + _supportForeArmBend * move, death('rightForeArm').x),
      y: mix(pose(-.499, -.769), death('rightForeArm').y),
      z: mix(pose(-.105, -.776), death('rightForeArm').z),
    );

    visual.leftHand.rotation = _withDelta(
      visual.baseRotations['leftHand']!,
      x: mix(.012 * recoil, death('leftHand').x),
      y: mix(0, death('leftHand').y),
      z: mix(0, death('leftHand').z),
    );
    visual.rightHand.rotation = _withDelta(
      visual.baseRotations['rightHand']!,
      x: mix(0, death('rightHand').x),
      y: mix(0, death('rightHand').y),
      z: mix(0, death('rightHand').z),
    );

    visual.gunRoot.rotation = visual.gunBaseRotation *
        vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          recoil * .070,
        );

    visual.neck.rotation = _withDelta(
      visual.baseRotations['neck']!,
      y: .028 * idle * (1 - aim) - _headYaw * step * move * .35,
    );
    visual.head.rotation = _withDelta(
      visual.baseRotations['head']!,
      x: .018 * idle * (1 - aim) + _headPitch * step.abs() * move,
      y: .040 * idle * (1 - aim) + _headYaw * step * move,
      z: -.045 * hit,
    );

    // Developer body-pose layer. Idle values define the static pose; walking
    // values blend in on top as movement reaches full speed. Every frame starts
    // from the imported local bone positions, so offsets never accumulate.
    final poseNodes = visual.poseNodes;
    vm.Quaternion poseRotation(List<double> p, double blend) {
      final rx = p.length > 3 ? p[3] * math.pi / 180 * blend : 0.0;
      final ry = p.length > 4 ? p[4] * math.pi / 180 * blend : 0.0;
      final rz = p.length > 5 ? p[5] * math.pi / 180 * blend : 0.0;
      return vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), rx) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), ry) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), rz);
    }
    for (final entry in poseNodes.entries) {
      final key = entry.key;
      final node = entry.value;
      final basePosition = visual.basePositions[key];
      final idlePose = _idlePose[key] ?? const <double>[0, 0, 0, 0, 0, 0];
      final walkPose = _walkPose[key] ?? const <double>[0, 0, 0, 0, 0, 0];
      final deathPose = _developerDeathPose[key] ?? const <double>[0, 0, 0, 0, 0, 0];
      // Idle and walk developer poses are two ALTERNATIVE body states, not
      // additive layers. This is important for parity between developer
      // preview and real gameplay: at rest the idle pose is 100%, while at
      // full locomotion the walk pose is 100%. During acceleration/deceleration
      // we blend smoothly between both states.
      final idleBlend = 1.0 - move;
      if (basePosition != null) {
        node.position = vm.Vector3(
          basePosition.x + (idlePose[0] * idleBlend + walkPose[0] * move) * alive + deathPose[0] * fall,
          basePosition.y + (idlePose[1] * idleBlend + walkPose[1] * move) * alive + deathPose[1] * fall,
          basePosition.z + (idlePose[2] * idleBlend + walkPose[2] * move) * alive + deathPose[2] * fall,
        );
      }
      node.rotation = node.rotation *
          poseRotation(idlePose, idleBlend * alive) *
          poseRotation(walkPose, move * alive) *
          poseRotation(deathPose, fall);
    }

    visual
      ..lastSkeletonWalkTime = walkTime
      ..lastSkeletonSpeed = speed
      ..lastForwardMotion = forwardMotion
      ..lastStrafeMotion = strafeMotion
      ..lastSkeletonFall = fall
      ..forceVisualRefresh = false;
    }

    // Bright two-layer beam: a sharp red core plus a soft wider halo. Both are
    // unlit, so the beam remains visible in every lighting condition without
    // requiring an expensive bloom/post-process pass.
    if (visual.laser.visible != laserVisible) {
      visual.laser.visible = laserVisible;
    }
    if (visual.laserGlow.visible != laserVisible) {
      visual.laserGlow.visible = laserVisible;
    }
    final visualLength = math.max(.001, laserLength.abs());
    final laserGeometryDirty = laserVisible &&
        ((visualLength - visual.lastLaserLength).abs() > .0005 ||
         visual.forceLaserRefresh);
    if (laserGeometryDirty) {
      visual.laser.position = vm.Vector3(0, .012, visualLength / 2);
      visual.laser.scale = vm.Vector3(
        1.02 * _laserThickness,
        1.02 * _laserThickness,
        visualLength,
      );
      visual.laserGlow.position = vm.Vector3(0, .012, visualLength / 2);
      final glowScale = _laserThickness * (.72 + _laserGlow * .62);
      visual.laserGlow.scale = vm.Vector3(
        1.34 * glowScale,
        1.34 * glowScale,
        visualLength,
      );
      if (_developerDebugLayerEnabled) {
        visual.debugLaserHitbox
          ..visible = _debugHitboxes
          ..position = vm.Vector3(0, .012, visualLength / 2)
          ..scale = vm.Vector3(
            1.7 * _laserThickness,
            1.7 * _laserThickness,
            visualLength,
          );
      }
      visual
        ..lastLaserLength = visualLength
        ..forceLaserRefresh = false;
    }

    if (!laserVisible || !_developerDebugLayerEnabled) {
      visual.debugLaserHitbox.visible = false;
    }

    if (shotFlash > 0) {
      final pulse = (shotFlash / .22).clamp(0.0, 1.0).toDouble();
      visual.muzzleFlash.scale = vm.Vector3.all(.72 + pulse * 1.42);
      visual.muzzleFlash.visible = true;
      final tracerLength = math.max(.001, laserLength.abs());
      visual.shotTracer.position = vm.Vector3(0, 0, tracerLength / 2);
      visual.shotTracer.scale = vm.Vector3(
        1.55 + pulse * .95,
        1.55 + pulse * .95,
        tracerLength,
      );
      visual.shotTracer.visible = true;
    } else {
      visual.muzzleFlash.visible = false;
      visual.shotTracer.visible = false;
    }
  }

  Node _acquireBloodStainNode({required bool disc}) {
    final pool = disc ? _bloodDiscPool : _bloodDropPool;
    final node = pool.isNotEmpty
        ? pool.removeLast()
        : _meshNode(
            disc ? _geo.bloodDisc : _geo.bloodDrop,
            _bloodMaterial,
          )
            ..castsShadows = false
            ..raycastable = false;
    node.visible = true;
    scene.add(node);
    return node;
  }

  void _releaseBloodStain(_BloodStain stain) {
    stain.node
      ..visible = false
      ..detach();
    final pool = stain.disc ? _bloodDiscPool : _bloodDropPool;
    if (pool.length < _maxBloodStains) pool.add(stain.node);
  }

  void _pushBloodStain(Node node, {required bool disc}) {
    if (_bloodStains.length >= _maxBloodStains) {
      _releaseBloodStain(_bloodStains.removeAt(0));
    }
    _bloodStains.add(_BloodStain(node: node, disc: disc));
  }

  Node _acquireBloodParticleNode() {
    final node = _bloodParticlePool.isNotEmpty
        ? _bloodParticlePool.removeLast()
        : _meshNode(
            _geo.bloodParticle,
            _bloodSprayMaterial,
          )
            ..castsShadows = false
            ..raycastable = false;
    node.visible = true;
    scene.add(node);
    return node;
  }

  void _releaseBloodParticleNode(Node node) {
    node
      ..visible = false
      ..detach();
    if (_bloodParticlePool.length < _maxBloodParticles) {
      _bloodParticlePool.add(node);
    }
  }

  void addBlood(double x, double y, {double shotAngle = 0, bool lethal = false}) {
    final world = worldPosition(x, y);

    // Build one visually continuous but NON-CIRCULAR pool from overlapping
    // elliptical lobes. Real liquid stains develop an irregular perimeter with
    // projections/satellites depending on impact and surface; using several
    // offset lobes avoids the old perfect-disc look without adding a texture.
    final poolAngle = shotAngle + (_random.nextDouble() - .5) * .55;
    final lobeCount = lethal ? 8 : 5;
    for (var i = 0; i < lobeCount; i++) {
      final t = i / math.max(1, lobeCount - 1);
      final along = (t - .42) * (lethal ? .72 : .38) + (_random.nextDouble() - .5) * .16;
      final side = (_random.nextDouble() - .5) * (lethal ? .48 : .28);
      final fx = math.cos(poolAngle);
      final fz = math.sin(poolAngle);
      final sx = -fz;
      final sz = fx;
      final width = (lethal ? .72 : .48) * (.72 + _random.nextDouble() * .62);
      final length = (lethal ? 1.08 : .72) * (.72 + _random.nextDouble() * .70);
      final stain = _acquireBloodStainNode(disc: true)
        ..position = vm.Vector3(world.x + fx * along + sx * side, .018 + i * .00005, world.z + fz * along + sz * side)
        ..scale = vm.Vector3(width, 1, length)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), poolAngle + (_random.nextDouble() - .5) * .8);
      _pushBloodStain(stain, disc: true);
    }

    final floorDrops = lethal ? 14 : 7;
    for (var i = 0; i < floorDrops; i++) {
      final drop = _acquireBloodStainNode(disc: false)
        ..position = vm.Vector3(
          world.x + (_random.nextDouble() - .5) * (lethal ? .95 : .52),
          .019,
          world.z + (_random.nextDouble() - .5) * (lethal ? .95 : .52),
        )
        ..scale = vm.Vector3.all(.22 + _random.nextDouble() * (lethal ? .48 : .32))
        ..rotation = vm.Quaternion.identity();
      _pushBloodStain(drop, disc: false);
    }

    // Airborne spray comes from torso height and travels mainly away from the
    // incoming shot, with randomized vertical/side velocity. Fatal hits create
    // a much denser burst.
    final particleCount = lethal ? 38 : 16;
    final sprayForwardX = math.cos(shotAngle);
    final sprayForwardZ = math.sin(shotAngle);
    for (var i = 0; i < particleCount; i++) {
      final lateral = (_random.nextDouble() - .5) * (lethal ? 1.9 : 1.25);
      final forward = (lethal ? 1.15 : .72) + _random.nextDouble() * (lethal ? 1.65 : 1.00);
      final sideX = -sprayForwardZ;
      final sideZ = sprayForwardX;
      final velocity = vm.Vector3(
        sprayForwardX * forward + sideX * lateral,
        .72 + _random.nextDouble() * (lethal ? 1.90 : 1.25),
        sprayForwardZ * forward + sideZ * lateral,
      );
      if (_bloodParticles.length >= _maxBloodParticles) {
        final oldest = _bloodParticles.removeAt(0);
        _releaseBloodParticleNode(oldest.node);
      }
      final particle = _acquireBloodParticleNode()
        ..position = vm.Vector3(
          world.x + (_random.nextDouble() - .5) * .16,
          .92 + _random.nextDouble() * .42,
          world.z + (_random.nextDouble() - .5) * .16,
        )
        ..scale = vm.Vector3.all((lethal ? .72 : .52) + _random.nextDouble() * .58)
        ..rotation = vm.Quaternion.identity();
      _bloodParticles.add(
        _BloodParticle(
          node: particle,
          velocity: velocity,
          life: .52 + _random.nextDouble() * (lethal ? .78 : .50),
        ),
      );
    }
  }

  void updateEffects(double dt) {
    for (var i = _bloodParticles.length - 1; i >= 0; i--) {
      final particle = _bloodParticles[i];
      particle.life -= dt;
      if (particle.life <= 0) {
        _releaseBloodParticleNode(particle.node);
        _bloodParticles.removeAt(i);
        continue;
      }

      particle.velocity.y -= 4.8 * dt;
      final current = particle.node.position;
      particle.node.position = vm.Vector3(
        current.x + particle.velocity.x * dt,
        current.y + particle.velocity.y * dt,
        current.z + particle.velocity.z * dt,
      );

      if (particle.node.position.y <= .025) {
        final impact = _acquireBloodStainNode(disc: false)
          ..position = vm.Vector3(particle.node.position.x, .019, particle.node.position.z)
          ..scale = vm.Vector3.all(.18 + _random.nextDouble() * .24)
          ..rotation = vm.Quaternion.identity();
        _pushBloodStain(impact, disc: false);
        _releaseBloodParticleNode(particle.node);
        _bloodParticles.removeAt(i);
      }
    }
  }

  void clearBlood() {
    for (final stain in _bloodStains) {
      _releaseBloodStain(stain);
    }
    for (final particle in _bloodParticles) {
      _releaseBloodParticleNode(particle.node);
    }
    _bloodStains.clear();
    _bloodParticles.clear();
  }

  ({double x, double y, double dx, double dy})? fighterAimRay2D(int id) {
    final visual = fighters[id];
    if (visual == null || !visual.root.visible) return null;

    // Use the REAL muzzle transform after the full character skeleton, hand,
    // gun rotation and recoil have been applied. This keeps gameplay hit tests
    // on the exact same visible line as the laser instead of a parallel ray
    // starting from the fighter's body center.
    final transform = visual.aimRoot.globalTransform;
    final origin = vm.Vector3.zero();
    transform.transform3(origin);
    final forwardPoint = vm.Vector3(0, 0, 1);
    transform.transform3(forwardPoint);
    final dirX = forwardPoint.x - origin.x;
    final dirY = forwardPoint.z - origin.z;
    final length = math.sqrt(dirX * dirX + dirY * dirY);
    if (length < .000001) return null;

    return (
      x: origin.x / arenaWorldSize + .5,
      y: origin.z / arenaWorldSize + .5,
      dx: dirX / length,
      dy: dirY / length,
    );
  }

  vm.Vector3 worldPosition(double x, double y, {double height = 0}) {
    return vm.Vector3(
      (x - .5) * arenaWorldSize,
      height,
      (y - .5) * arenaWorldSize,
    );
  }

  vm.Vector3 _clampCameraInsideStage(vm.Vector3 position) {
    // Safe camera cylinder is intentionally smaller than the expanded outer
    // supports and roof. This guarantees that no legal pinch/orbit/death view
    // can reveal the model from the outside.
    const safeRadius = 10.15;
    const minHeight = .60;
    const maxHeight = 7.05;

    var x = position.x;
    var z = position.z;
    final radial = math.sqrt(x * x + z * z);
    if (radial > safeRadius && radial > .000001) {
      final scale = safeRadius / radial;
      x *= scale;
      z *= scale;
    }

    return vm.Vector3(
      x,
      position.y.clamp(minHeight, maxHeight).toDouble(),
      z,
    );
  }

  PerspectiveCamera developerFreeCameraFor({
    required double seconds,
    required double x,
    required double y,
    required double z,
    required double yaw,
    required double pitch,
    bool updateBackground = true,
  }) {
    if (updateBackground) {
      _updateBackground(seconds);
    }

    final cosPitch = math.cos(pitch);
    final forward = vm.Vector3(
      math.cos(yaw) * cosPitch,
      math.sin(pitch),
      math.sin(yaw) * cosPitch,
    );
    final position = vm.Vector3(x, y, z);
    final target = vm.Vector3(
      x + forward.x,
      y + forward.y,
      z + forward.z,
    );

    return PerspectiveCamera(
      position: position,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: 58 * math.pi / 180,
      fovNear: .03,
      fovFar: 1000,
    );
  }

  PerspectiveCamera cameraFor({
    required double seconds,
    required double playerX,
    required double playerY,
    required double playerAngle,
    required double cameraOrbit,
    required double cameraPitch,
    required double cameraZoom,
    required double cameraDistance,
    required double cameraOffsetX,
    required double cameraOffsetY,
    required double cameraYawOffset,
    required double spectatorAmount,
    bool updateBackground = true,
  }) {
    if (updateBackground) {
      _updateBackground(seconds);
    }

    final player = worldPosition(playerX, playerY);
    final orbitHeading = playerAngle + cameraYawOffset + cameraOrbit;
    final playerForward = vm.Vector3(
      math.cos(playerAngle),
      0,
      math.sin(playerAngle),
    );
    final cameraForward = vm.Vector3(
      math.cos(orbitHeading),
      0,
      math.sin(orbitHeading),
    );
    final cameraRight = vm.Vector3(
      -math.sin(orbitHeading),
      0,
      math.cos(orbitHeading),
    );

    // Third-person camera is intentionally constrained to the *interior* of
    // the enlarged stage. Pinch can still zoom in/out naturally, but it can no
    // longer pull the camera through the roof/dome or behind the outside shell.
    final zoom = math.max(.28, cameraZoom);
    final thirdPersonHorizontalDistance =
        (cameraDistance / zoom).clamp(.18, 6.20).toDouble();
    const baseThirdPersonElevation = 0.30;
    final thirdPersonElevation =
        (baseThirdPersonElevation + cameraPitch).clamp(-.82, 1.02).toDouble();
    final thirdPersonTarget = vm.Vector3(
      player.x + playerForward.x * .68,
      (1.08 + cameraOffsetY * .18).clamp(.55, 2.35).toDouble(),
      player.z + playerForward.z * .68,
    );
    final rawThirdPersonPosition = vm.Vector3(
      player.x - cameraForward.x * thirdPersonHorizontalDistance + cameraRight.x * cameraOffsetX,
      thirdPersonTarget.y + math.tan(thirdPersonElevation) * thirdPersonHorizontalDistance + cameraOffsetY,
      player.z - cameraForward.z * thirdPersonHorizontalDistance + cameraRight.z * cameraOffsetX,
    );
    final thirdPersonPosition = _clampCameraInsideStage(rawThirdPersonPosition);

    // Death camera is fully developer-controlled and isolated from the living
    // camera. Orbit/pitch/zoom still work as local adjustments while dead.
    final deathZoom = math.max(.05, _deathCameraZoom * zoom);
    final baseDeathPosition = vm.Vector3(_deathCameraX, _deathCameraY, _deathCameraZ);
    final orbitRadius = math.sqrt(baseDeathPosition.x * baseDeathPosition.x + baseDeathPosition.z * baseDeathPosition.z) / deathZoom;
    final baseHeading = math.atan2(baseDeathPosition.z, baseDeathPosition.x);
    final deathHeading = baseHeading + cameraOrbit;
    final rawSpectatorPosition = vm.Vector3(
      math.cos(deathHeading) * orbitRadius,
      _deathCameraY / deathZoom,
      math.sin(deathHeading) * orbitRadius,
    );
    final spectatorPosition = _clampCameraInsideStage(rawSpectatorPosition);
    final yaw = _deathCameraYaw + cameraOrbit;
    final pitch = (_deathCameraPitch + cameraPitch).clamp(-1.553, 1.553).toDouble();
    final forward = vm.Vector3(
      math.cos(pitch) * math.cos(yaw),
      math.sin(pitch),
      math.cos(pitch) * math.sin(yaw),
    );
    final spectatorTarget = spectatorPosition + forward * 4.0;

    final t = spectatorAmount.clamp(0.0, 1.0).toDouble();
    vm.Vector3 blend(vm.Vector3 a, vm.Vector3 b) => vm.Vector3(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.z + (b.z - a.z) * t,
        );

    final position = _clampCameraInsideStage(
      blend(thirdPersonPosition, spectatorPosition),
    );
    final target = blend(thirdPersonTarget, spectatorTarget);
    final deathFov = (54.0 / math.sqrt(_deathCameraZoom.clamp(.25, 4.0))).clamp(34.0, 78.0).toDouble();
    final fovDegrees = 58.0 + (deathFov - 58.0) * t;

    return PerspectiveCamera(
      position: position,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: fovDegrees * math.pi / 180,
      fovNear: .08,
      fovFar: 1000,
    );
  }

  Offset? labelScreenPoint({
    PerspectiveCamera? camera,
    required double x,
    required double y,
    double height = fighterLabelHeight,
    required double seconds,
    required double playerX,
    required double playerY,
    required double playerAngle,
    required double cameraOrbit,
    required double cameraPitch,
    required double cameraZoom,
    required double cameraDistance,
    required double cameraOffsetX,
    required double cameraOffsetY,
    required double cameraYawOffset,
    required double spectatorAmount,
    required Size viewSize,
  }) {
    final resolvedCamera = camera ?? cameraFor(
      seconds: seconds,
      playerX: playerX,
      playerY: playerY,
      playerAngle: playerAngle,
      cameraOrbit: cameraOrbit,
      cameraPitch: cameraPitch,
      cameraZoom: cameraZoom,
      cameraDistance: cameraDistance,
      cameraOffsetX: cameraOffsetX,
      cameraOffsetY: cameraOffsetY,
      cameraYawOffset: cameraYawOffset,
      spectatorAmount: spectatorAmount,
    );
    return resolvedCamera.worldToScreen(
      worldPosition(x, y, height: height),
      viewSize,
    );
  }
}

class KillerKilledFighterVisual {
  KillerKilledFighterVisual({
    required this.root,
    required this.bodyRoot,
    required this.model,
    required this.hips,
    required this.spine,
    required this.spine1,
    required this.spine2,
    required this.neck,
    required this.head,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftArm,
    required this.rightArm,
    required this.leftForeArm,
    required this.rightForeArm,
    required this.leftHand,
    required this.rightHand,
    required this.leftUpLeg,
    required this.rightUpLeg,
    required this.leftLeg,
    required this.rightLeg,
    required this.leftFoot,
    required this.rightFoot,
    required this.baseRotations,
    required this.basePositions,
    required this.gunRoot,
    required this.gunBaseRotation,
    required this.gunModel,
    required this.aimRoot,
    required this.laserGlow,
    required this.laser,
    required this.muzzleFlash,
    required this.shotTracer,
    required this.debugHitboxRoot,
    required this.debugLaserHitbox,
    required this.deathPose,
    required this.poseNodes,
    required this.accentColor,
  });

  final Node root;
  final Node bodyRoot;
  final Node model;
  final Node hips;
  final Node spine;
  final Node spine1;
  final Node spine2;
  final Node neck;
  final Node head;
  final Node leftShoulder;
  final Node rightShoulder;
  final Node leftArm;
  final Node rightArm;
  final Node leftForeArm;
  final Node rightForeArm;
  final Node leftHand;
  final Node rightHand;
  final Node leftUpLeg;
  final Node rightUpLeg;
  final Node leftLeg;
  final Node rightLeg;
  final Node leftFoot;
  final Node rightFoot;
  final Map<String, vm.Quaternion> baseRotations;
  final Map<String, vm.Vector3> basePositions;
  final Node gunRoot;
  final vm.Quaternion gunBaseRotation;
  final Node gunModel;
  final Node aimRoot;
  final Node laserGlow;
  final Node laser;
  final Node muzzleFlash;
  final Node shotTracer;
  final Node debugHitboxRoot;
  final Node debugLaserHitbox;
  final Map<String, vm.Vector3> deathPose;
  final Map<String, Node> poseNodes;
  final Color accentColor;

  // Per-instance dirty state. These caches eliminate repeated bone/quaternion
  // work for idle/offscreen/dead fighters while preserving full-rate updates
  // whenever movement, recoil, damage or falling is actually visible.
  bool forceVisualRefresh = true;
  bool forceLaserRefresh = true;
  bool skeletonUpdateAllowed = true;
  double lastRootX = double.nan;
  double lastRootY = double.nan;
  double lastRootAngle = double.nan;
  double lastRootFall = double.nan;
  double lastSkeletonWalkTime = -1e9;
  double lastSkeletonSpeed = double.nan;
  double lastForwardMotion = double.nan;
  double lastStrafeMotion = double.nan;
  double lastSkeletonFall = double.nan;
  double lastLaserLength = double.nan;
}

class _GeometryBank {
  _GeometryBank()
      : laser = CuboidGeometry(vm.Vector3(.0045, .0045, 1)),
        laserGlow = CuboidGeometry(vm.Vector3(.012, .012, 1)),
        debugLaser = CuboidGeometry(vm.Vector3(.010, .010, 1)),
        debugBox = CuboidGeometry(vm.Vector3(1, 1, 1)),
        muzzleFlash = IcosphereGeometry(radius: .065, subdivisions: 1),
        bloodDisc = DiscGeometry(radius: .28, segments: 20),
        bloodDrop = DiscGeometry(radius: .10, segments: 14),
        bloodParticle = IcosphereGeometry(radius: .045, subdivisions: 1);

  final Geometry laser;
  final Geometry laserGlow;
  final Geometry debugLaser;
  final Geometry debugBox;
  final Geometry muzzleFlash;
  final Geometry bloodDisc;
  final Geometry bloodDrop;
  final Geometry bloodParticle;
}

class _BloodStain {
  _BloodStain({required this.node, required this.disc});

  final Node node;
  final bool disc;
}

class _BloodParticle {
  _BloodParticle({
    required this.node,
    required this.velocity,
    required this.life,
  });

  final Node node;
  final vm.Vector3 velocity;
  double life;
}
