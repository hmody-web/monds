import 'dart:math' as math;

import 'package:flutter/material.dart' show Color, Offset, Size;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Real-time 3D scene used by "قاتل ومقتول".
///
/// The world is deliberately built from lightweight procedural meshes so the
/// first 3D version stays small and fast on phones. A future downloaded GLB can
/// replace the fighter subtree without changing the gameplay layer.
class KillerKilled3DWorld {
  KillerKilled3DWorld();

  static const double arenaWorldSize = 7.2;
  static const double fighterLabelHeight = 2.2;

  final Scene scene = Scene();
  final Map<int, KillerKilledFighterVisual> fighters = {};
  final List<Node> _bloodNodes = [];
  final math.Random _random = math.Random(1729);

  bool ready = false;

  late final _GeometryBank _geo;
  late final PhysicallyBasedMaterial _floorMaterial;
  late final PhysicallyBasedMaterial _obstacleTopMaterial;
  late final PhysicallyBasedMaterial _obstacleSideMaterial;
  late final PhysicallyBasedMaterial _blackClothMaterial;
  late final PhysicallyBasedMaterial _darkClothMaterial;
  late final PhysicallyBasedMaterial _pantsMaterial;
  late final PhysicallyBasedMaterial _skinMaterial;
  late final PhysicallyBasedMaterial _metalMaterial;
  late final UnlitMaterial _gridMaterial;
  late final UnlitMaterial _bloodMaterial;
  late final UnlitMaterial _windowMaterial;

  Future<void> initialize() async {
    if (ready) return;
    await Scene.initializeStaticResources();

    scene.renderScale = .92;
    scene.exposure = 1.08;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.62, -1.0, -.48),
      color: vm.Vector3(.78, .88, 1.0),
      intensity: 2.25,
      castsShadow: true,
      shadowCascadeCount: 2,
      shadowMaxDistance: 28,
      shadowMapResolution: 1024,
      shadowSoftness: .13,
      shadowAmbientStrength: .20,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = true
      ..sampleCount = 8
      ..radius = .34
      ..intensity = .82;

    _geo = _GeometryBank();
    _createMaterials();
    _buildRooftop();
    ready = true;
  }

  void _createMaterials() {
    _floorMaterial = _pbr(const Color(0xFF182230), roughness: .74, metallic: .16);
    _obstacleTopMaterial = _pbr(const Color(0xFF283545), roughness: .60, metallic: .24);
    _obstacleSideMaterial = _pbr(const Color(0xFF101722), roughness: .72, metallic: .18);
    _blackClothMaterial = _pbr(const Color(0xFF0D1118), roughness: .86, metallic: .02);
    _darkClothMaterial = _pbr(const Color(0xFF171D27), roughness: .78, metallic: .04);
    _pantsMaterial = _pbr(const Color(0xFF111722), roughness: .84, metallic: .02);
    _skinMaterial = _pbr(const Color(0xFFE4AF8B), roughness: .83, metallic: 0);
    _metalMaterial = _pbr(const Color(0xFF303A49), roughness: .36, metallic: .72);
    _gridMaterial = _unlit(const Color(0x342F6DFF));
    _bloodMaterial = _unlit(const Color(0xFF8C0E20));
    _windowMaterial = _unlit(const Color(0xFF1D5FAE));
  }

  PhysicallyBasedMaterial _pbr(Color color, {double roughness = .65, double metallic = .0}) {
    final material = PhysicallyBasedMaterial();
    material.baseColorFactor = _vectorColor(color);
    material.roughnessFactor = roughness;
    material.metallicFactor = metallic;
    return material;
  }

  UnlitMaterial _unlit(Color color) {
    final material = UnlitMaterial();
    material.baseColorFactor = _vectorColor(color);
    return material;
  }

  vm.Vector4 _vectorColor(Color color, {double alpha = 1}) {
    final argb = color.toARGB32();
    return vm.Vector4(
      ((argb >> 16) & 0xFF) / 255.0,
      ((argb >> 8) & 0xFF) / 255.0,
      (argb & 0xFF) / 255.0,
      alpha,
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

  void _buildRooftop() {
    // Main roof slab. Its top is y = 0, so fighter feet sit exactly on it.
    final slab = _meshNode(
      CuboidGeometry(vm.Vector3(8.8, .38, 8.8)),
      _floorMaterial,
      name: 'roof_slab',
      position: vm.Vector3(0, -.19, 0),
    );
    slab.shadowStatic = true;
    scene.add(slab);

    // Thin neon grid across the playable part of the roof.
    for (var i = -4; i <= 4; i++) {
      final p = i * .8;
      final lineX = _meshNode(
        CuboidGeometry(vm.Vector3(.018, .012, arenaWorldSize)),
        _gridMaterial,
        position: vm.Vector3(p, .012, 0),
      );
      final lineZ = _meshNode(
        CuboidGeometry(vm.Vector3(arenaWorldSize, .012, .018)),
        _gridMaterial,
        position: vm.Vector3(0, .012, p),
      );
      lineX.castsShadows = false;
      lineZ.castsShadows = false;
      scene.addAll([lineX, lineZ]);
    }

    // Low parapets: enough to communicate the roof edge without hiding actors.
    const wallHeight = .22;
    final wallMaterial = _pbr(const Color(0xFF202A37), roughness: .66, metallic: .24);
    for (final wall in <({vm.Vector3 size, vm.Vector3 pos})>[
      (size: vm.Vector3(8.8, wallHeight, .12), pos: vm.Vector3(0, wallHeight / 2, -4.34)),
      (size: vm.Vector3(8.8, wallHeight, .12), pos: vm.Vector3(0, wallHeight / 2, 4.34)),
      (size: vm.Vector3(.12, wallHeight, 8.8), pos: vm.Vector3(-4.34, wallHeight / 2, 0)),
      (size: vm.Vector3(.12, wallHeight, 8.8), pos: vm.Vector3(4.34, wallHeight / 2, 0)),
    ]) {
      final node = _meshNode(CuboidGeometry(wall.size), wallMaterial, position: wall.pos);
      node.shadowStatic = true;
      scene.add(node);
    }

    // Actual gameplay obstacles. Values mirror the normalized collision map.
    const obstacles = <({double x, double y, double w, double h})>[
      (x: .22, y: .30, w: .12, h: .10),
      (x: .74, y: .30, w: .12, h: .10),
      (x: .37, y: .63, w: .14, h: .11),
      (x: .67, y: .69, w: .14, h: .11),
    ];
    for (final obstacle in obstacles) {
      final world = worldPosition(obstacle.x, obstacle.y);
      final base = _meshNode(
        CuboidGeometry(vm.Vector3(obstacle.w * arenaWorldSize, .72, obstacle.h * arenaWorldSize)),
        _obstacleSideMaterial,
        position: vm.Vector3(world.x, .36, world.z),
      );
      base.shadowStatic = true;
      scene.add(base);

      final top = _meshNode(
        CuboidGeometry(vm.Vector3(obstacle.w * arenaWorldSize * .91, .08, obstacle.h * arenaWorldSize * .91)),
        _obstacleTopMaterial,
        position: vm.Vector3(world.x, .76, world.z),
      );
      top.shadowStatic = true;
      scene.add(top);

      final strip = _meshNode(
        CuboidGeometry(vm.Vector3(obstacle.w * arenaWorldSize * .72, .025, .025)),
        _gridMaterial,
        position: vm.Vector3(world.x, .82, world.z),
      );
      strip.castsShadows = false;
      scene.add(strip);
    }

    _buildCityBackdrop();
  }

  void _buildCityBackdrop() {
    final buildingMaterial = _pbr(const Color(0xFF09111E), roughness: .92, metallic: .02);
    // Backdrop is intentionally sparse: it gives depth while keeping draw cost low.
    for (var i = 0; i < 18; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final along = -6.7 + (i ~/ 2) * 1.55;
      final height = 1.9 + _random.nextDouble() * 3.7;
      final width = .72 + _random.nextDouble() * .72;
      final depth = .7 + _random.nextDouble() * .8;
      final x = i % 4 < 2 ? along : side * (5.9 + _random.nextDouble() * 1.2);
      final z = i % 4 < 2 ? side * (5.7 + _random.nextDouble() * 1.2) : along;
      final building = _meshNode(
        CuboidGeometry(vm.Vector3(width, height, depth)),
        buildingMaterial,
        position: vm.Vector3(x, height / 2 - .15, z),
      );
      building.shadowStatic = true;
      scene.add(building);

      // Two cheap emissive-looking window strips per building.
      for (var w = 0; w < 2; w++) {
        final window = _meshNode(
          CuboidGeometry(vm.Vector3(width * .48, .04, .025)),
          _windowMaterial,
          position: vm.Vector3(x, .65 + w * .54, z - depth / 2 - .018),
        );
        window.castsShadows = false;
        scene.add(window);
      }
    }
  }

  KillerKilledFighterVisual addFighter(int id, Color accentColor) {
    final existing = fighters[id];
    if (existing != null) return existing;

    final accent = _pbr(accentColor, roughness: .36, metallic: .34);
    final accentUnlit = _unlit(accentColor);
    final visual = _buildFighter(id, accentColor, accent, accentUnlit);
    fighters[id] = visual;
    scene.add(visual.root);
    return visual;
  }

  KillerKilledFighterVisual _buildFighter(
    int id,
    Color accentColor,
    PhysicallyBasedMaterial accent,
    UnlitMaterial accentUnlit,
  ) {
    final root = Node(name: 'fighter_$id');

    final leftLegPivot = Node(name: 'left_leg_pivot', localTransform: vm.Matrix4.identity());
    leftLegPivot.position = vm.Vector3(-.115, .53, 0);
    final rightLegPivot = Node(name: 'right_leg_pivot', localTransform: vm.Matrix4.identity());
    rightLegPivot.position = vm.Vector3(.115, .53, 0);

    final leftLeg = _meshNode(
      _geo.leg,
      _pantsMaterial,
      position: vm.Vector3(0, -.24, 0),
    );
    final rightLeg = _meshNode(
      _geo.leg,
      _pantsMaterial,
      position: vm.Vector3(0, -.24, 0),
    );
    leftLegPivot.add(leftLeg);
    rightLegPivot.add(rightLeg);

    leftLegPivot.add(
      _meshNode(
        _geo.boot,
        _blackClothMaterial,
        position: vm.Vector3(0, -.49, .055),
      ),
    );
    rightLegPivot.add(
      _meshNode(
        _geo.boot,
        _blackClothMaterial,
        position: vm.Vector3(0, -.49, .055),
      ),
    );
    root.addAll([leftLegPivot, rightLegPivot]);

    final torsoPivot = Node(name: 'torso_pivot');
    torsoPivot.position = vm.Vector3(0, .95, 0);
    torsoPivot.add(_meshNode(_geo.torso, _darkClothMaterial));

    // Coat shoulders and long tails create the silhouette from the reference.
    torsoPivot.add(
      _meshNode(
        _geo.shoulder,
        _blackClothMaterial,
        position: vm.Vector3(0, .11, -.02),
      ),
    );

    final leftTailPivot = Node(name: 'left_coat_tail');
    leftTailPivot.position = vm.Vector3(-.15, -.24, -.07);
    leftTailPivot.add(
      _meshNode(
        _geo.coatTail,
        _blackClothMaterial,
        position: vm.Vector3(0, -.27, 0),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), .09),
      ),
    );
    final rightTailPivot = Node(name: 'right_coat_tail');
    rightTailPivot.position = vm.Vector3(.15, -.24, -.07);
    rightTailPivot.add(
      _meshNode(
        _geo.coatTail,
        _blackClothMaterial,
        position: vm.Vector3(0, -.27, 0),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -.09),
      ),
    );
    torsoPivot.addAll([leftTailPivot, rightTailPivot]);

    // Blue/player-color lining visible between coat tails.
    torsoPivot.add(
      _meshNode(
        _geo.coatLining,
        accent,
        position: vm.Vector3(0, -.36, -.025),
      ),
    );

    // Arms are separate pivots so the firing pose can be exaggerated.
    final leftArmPivot = Node(name: 'left_arm_pivot');
    leftArmPivot.position = vm.Vector3(-.30, .13, .02);
    leftArmPivot.add(
      _meshNode(
        _geo.arm,
        _darkClothMaterial,
        position: vm.Vector3(0, -.12, .13),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.55),
      ),
    );
    final rightArmPivot = Node(name: 'right_arm_pivot');
    rightArmPivot.position = vm.Vector3(.30, .13, .02);
    rightArmPivot.add(
      _meshNode(
        _geo.arm,
        _darkClothMaterial,
        position: vm.Vector3(0, -.12, .13),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.55),
      ),
    );
    torsoPivot.addAll([leftArmPivot, rightArmPivot]);

    // Head, high mask/collar, and fedora.
    torsoPivot.add(
      _meshNode(
        _geo.head,
        _skinMaterial,
        position: vm.Vector3(0, .57, .005),
      ),
    );
    torsoPivot.add(
      _meshNode(
        _geo.mask,
        _blackClothMaterial,
        position: vm.Vector3(0, .49, .14),
      ),
    );
    torsoPivot.add(
      _meshNode(
        _geo.hatBrim,
        _blackClothMaterial,
        position: vm.Vector3(0, .75, 0),
      ),
    );
    torsoPivot.add(
      _meshNode(
        _geo.hatCrown,
        _blackClothMaterial,
        position: vm.Vector3(0, .86, 0),
      ),
    );
    torsoPivot.add(
      _meshNode(
        _geo.hatBand,
        accent,
        position: vm.Vector3(0, .81, 0),
      ),
    );

    // One bright visible eye matching the reference silhouette.
    torsoPivot.add(
      _meshNode(
        _geo.eye,
        _unlit(const Color(0xFFEAFBFF)),
        position: vm.Vector3(.075, .59, .165),
      ),
    );
    torsoPivot.add(
      _meshNode(
        _geo.pupil,
        _unlit(const Color(0xFF5EDBFF)),
        position: vm.Vector3(.080, .59, .178),
      ),
    );

    // Gun points down local +Z, the same forward convention used by Node.lookAt.
    final gunPivot = Node(name: 'gun_pivot');
    gunPivot.position = vm.Vector3(.105, .06, .22);
    gunPivot.add(
      _meshNode(
        _geo.gunBody,
        _metalMaterial,
        position: vm.Vector3(0, 0, .18),
      ),
    );
    gunPivot.add(
      _meshNode(
        _geo.gunHandle,
        _metalMaterial,
        position: vm.Vector3(-.01, -.10, .08),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.28),
      ),
    );
    gunPivot.add(
      _meshNode(
        _geo.muzzleAccent,
        accent,
        position: vm.Vector3(0, .0, .39),
      ),
    );
    torsoPivot.add(gunPivot);

    final muzzleFlash = _meshNode(
      _geo.muzzleFlash,
      accentUnlit,
      name: 'muzzle_flash',
      position: vm.Vector3(.105, 1.01, .66),
      scale: vm.Vector3.zero(),
    );
    muzzleFlash.castsShadows = false;

    final laser = _meshNode(
      _geo.laser,
      accentUnlit,
      name: 'laser',
      position: vm.Vector3(.105, 1.01, 2.95),
      scale: vm.Vector3(.55, .55, 5.65),
    );
    laser.visible = false;
    laser.castsShadows = false;

    root.addAll([torsoPivot, muzzleFlash, laser]);

    return KillerKilledFighterVisual(
      root: root,
      torsoPivot: torsoPivot,
      leftLegPivot: leftLegPivot,
      rightLegPivot: rightLegPivot,
      leftArmPivot: leftArmPivot,
      rightArmPivot: rightArmPivot,
      leftTailPivot: leftTailPivot,
      rightTailPivot: rightTailPivot,
      laser: laser,
      muzzleFlash: muzzleFlash,
      accentColor: accentColor,
    );
  }

  void updateFighter({
    required int id,
    required double x,
    required double y,
    required double angle,
    required double walkTime,
    required double speed,
    required double fall,
    required bool visible,
    required bool activeShooter,
    required bool laserVisible,
    required double laserLength,
    required double shotFlash,
  }) {
    final visual = fighters[id];
    if (visual == null) return;

    visual.root.visible = visible;
    if (!visible) return;

    final pos = worldPosition(x, y);
    visual.root.position = vm.Vector3(pos.x, fall * .07, pos.z);

    final yaw = (math.pi / 2) - angle;
    final yawQ = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
    if (fall > 0) {
      final fallQ = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), fall * 1.36);
      visual.root.rotation = yawQ * fallQ;
    } else {
      visual.root.rotation = yawQ;
    }

    final movementStrength = (speed / .24).clamp(0.0, 1.0) * (1 - fall);
    final swing = math.sin(walkTime * 7.0) * .48 * movementStrength;
    visual.leftLegPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), swing);
    visual.rightLegPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -swing);

    final coatSway = math.sin(walkTime * 6.3 + id) * .11 * movementStrength;
    visual.leftTailPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), .10 + coatSway);
    visual.rightTailPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), .10 - coatSway);

    final firePose = activeShooter ? 1.0 : 0.0;
    visual.torsoPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.045 * firePose);
    visual.leftArmPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.24 * firePose);
    visual.rightArmPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.31 * firePose);

    final highlight = activeShooter
        ? _vectorColor(visual.accentColor, alpha: .72)
        : null;
    for (final meshNode in visual.root.meshNodes) {
      meshNode.highlightColor = highlight;
    }

    visual.laser.visible = laserVisible;
    if (laserVisible) {
      final safeLength = laserLength.clamp(.35, 8.2);
      visual.laser.position = vm.Vector3(.105, 1.01, .65 + safeLength / 2);
      visual.laser.scale = vm.Vector3(.62, .62, safeLength);
    }

    if (shotFlash > 0) {
      final pulse = (shotFlash / .14).clamp(0.0, 1.0);
      visual.muzzleFlash.scale = vm.Vector3.all(.55 + pulse * .95);
      visual.muzzleFlash.visible = true;
    } else {
      visual.muzzleFlash.visible = false;
    }
  }

  void addBlood(double x, double y) {
    final world = worldPosition(x, y);
    final stain = _meshNode(
      _geo.bloodDisc,
      _bloodMaterial,
      position: vm.Vector3(world.x, .018, world.z),
      scale: vm.Vector3(
        .72 + _random.nextDouble() * .55,
        1,
        .52 + _random.nextDouble() * .45,
      ),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _random.nextDouble() * math.pi),
    );
    stain.castsShadows = false;
    scene.add(stain);
    _bloodNodes.add(stain);

    for (var i = 0; i < 3; i++) {
      final drop = _meshNode(
        _geo.bloodDrop,
        _bloodMaterial,
        position: vm.Vector3(
          world.x + (_random.nextDouble() - .5) * .42,
          .019,
          world.z + (_random.nextDouble() - .5) * .42,
        ),
        scale: vm.Vector3.all(.28 + _random.nextDouble() * .35),
      );
      drop.castsShadows = false;
      scene.add(drop);
      _bloodNodes.add(drop);
    }
  }


  void clearBlood() {
    for (final node in _bloodNodes) {
      node.detach();
    }
    _bloodNodes.clear();
  }

  vm.Vector3 worldPosition(double x, double y, {double height = 0}) {
    return vm.Vector3(
      (x - .5) * arenaWorldSize,
      height,
      (y - .5) * arenaWorldSize,
    );
  }

  PerspectiveCamera cameraFor(double seconds, double focusX, double focusY) {
    final focus = worldPosition(focusX, focusY, height: .74);
    final swayX = math.sin(seconds * .34) * .085;
    final swayZ = math.cos(seconds * .29) * .085;
    return PerspectiveCamera(
      // Equal horizontal and vertical viewing distances keep the camera
      // very close to the agreed 45° top-down angle.
      position: vm.Vector3(6.45 + swayX, 9.85, 6.45 + swayZ),
      target: vm.Vector3(focus.x * .075, .72, focus.z * .075),
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: 36 * math.pi / 180,
      fovNear: .1,
      fovFar: 70,
    );
  }

  Offset? labelScreenPoint({
    required double x,
    required double y,
    required double seconds,
    required double focusX,
    required double focusY,
    required Size viewSize,
  }) {
    final camera = cameraFor(seconds, focusX, focusY);
    return camera.worldToScreen(
      worldPosition(x, y, height: fighterLabelHeight),
      viewSize,
    );
  }
}

class KillerKilledFighterVisual {
  KillerKilledFighterVisual({
    required this.root,
    required this.torsoPivot,
    required this.leftLegPivot,
    required this.rightLegPivot,
    required this.leftArmPivot,
    required this.rightArmPivot,
    required this.leftTailPivot,
    required this.rightTailPivot,
    required this.laser,
    required this.muzzleFlash,
    required this.accentColor,
  });

  final Node root;
  final Node torsoPivot;
  final Node leftLegPivot;
  final Node rightLegPivot;
  final Node leftArmPivot;
  final Node rightArmPivot;
  final Node leftTailPivot;
  final Node rightTailPivot;
  final Node laser;
  final Node muzzleFlash;
  final Color accentColor;
}

class _GeometryBank {
  _GeometryBank()
      : torso = CapsuleGeometry(radius: .23, height: .47, radialSegments: 12, capRings: 4),
        shoulder = CuboidGeometry(vm.Vector3(.60, .19, .34)),
        head = IcosphereGeometry(radius: .18, subdivisions: 2),
        leg = CapsuleGeometry(radius: .073, height: .34, radialSegments: 8, capRings: 3),
        arm = CapsuleGeometry(radius: .055, height: .30, radialSegments: 8, capRings: 3),
        boot = CuboidGeometry(vm.Vector3(.17, .11, .29)),
        coatTail = CuboidGeometry(vm.Vector3(.23, .57, .095)),
        coatLining = CuboidGeometry(vm.Vector3(.18, .56, .035)),
        mask = CuboidGeometry(vm.Vector3(.29, .17, .10)),
        hatBrim = DiscGeometry(radius: .31, segments: 24),
        hatCrown = CapsuleGeometry(radius: .16, height: .095, radialSegments: 14, capRings: 4),
        hatBand = TorusGeometry(radius: .16, tubeRadius: .021, radialSegments: 20, tubularSegments: 6),
        eye = CuboidGeometry(vm.Vector3(.105, .035, .018)),
        pupil = IcosphereGeometry(radius: .019, subdivisions: 1),
        gunBody = CuboidGeometry(vm.Vector3(.075, .075, .36)),
        gunHandle = CuboidGeometry(vm.Vector3(.075, .19, .09)),
        muzzleAccent = CuboidGeometry(vm.Vector3(.09, .09, .035)),
        laser = CuboidGeometry(vm.Vector3(.020, .020, 1)),
        muzzleFlash = IcosphereGeometry(radius: .055, subdivisions: 1),
        bloodDisc = DiscGeometry(radius: .28, segments: 20),
        bloodDrop = DiscGeometry(radius: .10, segments: 14);

  final Geometry torso;
  final Geometry shoulder;
  final Geometry head;
  final Geometry leg;
  final Geometry arm;
  final Geometry boot;
  final Geometry coatTail;
  final Geometry coatLining;
  final Geometry mask;
  final Geometry hatBrim;
  final Geometry hatCrown;
  final Geometry hatBand;
  final Geometry eye;
  final Geometry pupil;
  final Geometry gunBody;
  final Geometry gunHandle;
  final Geometry muzzleAccent;
  final Geometry laser;
  final Geometry muzzleFlash;
  final Geometry bloodDisc;
  final Geometry bloodDrop;
}
