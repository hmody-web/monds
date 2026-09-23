import 'dart:math' as math;

import 'package:flutter/material.dart' show Color, Offset, Size;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class KillerKilled3DWorld {
  KillerKilled3DWorld();

  static const double arenaWorldSize = 7.2;
  static const double fighterLabelHeight = 2.45;

  final Scene scene = Scene();
  final Map<int, KillerKilledFighterVisual> fighters = {};
  final List<Node> _bloodNodes = [];
  final math.Random _random = math.Random(1729);

  bool ready = false;

  late final _GeometryBank _geo;
  late final PhysicallyBasedMaterial _floorMaterial;
  late final PhysicallyBasedMaterial _parapetMaterial;
  late final PhysicallyBasedMaterial _obstacleTopMaterial;
  late final PhysicallyBasedMaterial _obstacleSideMaterial;
  late final PhysicallyBasedMaterial _blackClothMaterial;
  late final PhysicallyBasedMaterial _darkClothMaterial;
  late final PhysicallyBasedMaterial _pantsMaterial;
  late final PhysicallyBasedMaterial _skinMaterial;
  late final PhysicallyBasedMaterial _metalMaterial;
  late final PhysicallyBasedMaterial _gloveMaterial;
  late final UnlitMaterial _gridMaterial;
  late final UnlitMaterial _bloodMaterial;
  late final UnlitMaterial _windowMaterial;

  late final Node _obstacleRoot;

  Future<void> initialize() async {
    if (ready) return;
    await Scene.initializeStaticResources();

    scene.renderScale = 1.0;
    scene.exposure = 1.14;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.58, -1.0, -.43),
      color: vm.Vector3(.82, .90, 1.0),
      intensity: 2.45,
      castsShadow: true,
      shadowCascadeCount: 2,
      shadowMaxDistance: 34,
      shadowMapResolution: 1024,
      shadowSoftness: .16,
      shadowAmbientStrength: .22,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = true
      ..sampleCount = 8
      ..radius = .36
      ..intensity = .88;

    _geo = _GeometryBank();
    _createMaterials();
    _buildRooftop();
    ready = true;
  }

  void _createMaterials() {
    _floorMaterial = _pbr(const Color(0xFF182433), roughness: .72, metallic: .17);
    _parapetMaterial = _pbr(const Color(0xFF222D3A), roughness: .64, metallic: .22);
    _obstacleTopMaterial = _pbr(const Color(0xFF334154), roughness: .52, metallic: .25);
    _obstacleSideMaterial = _pbr(const Color(0xFF121A25), roughness: .72, metallic: .16);
    _blackClothMaterial = _pbr(const Color(0xFF0C1016), roughness: .88, metallic: .02);
    _darkClothMaterial = _pbr(const Color(0xFF171F2B), roughness: .80, metallic: .04);
    _pantsMaterial = _pbr(const Color(0xFF121923), roughness: .84, metallic: .02);
    _skinMaterial = _pbr(const Color(0xFFE2AE8B), roughness: .82, metallic: 0);
    _metalMaterial = _pbr(const Color(0xFF3B4554), roughness: .34, metallic: .74);
    _gloveMaterial = _pbr(const Color(0xFF0A0E13), roughness: .72, metallic: .04);
    _gridMaterial = _unlit(const Color(0x3A2F6DFF));
    _bloodMaterial = _unlit(const Color(0xFF8A0E1E));
    _windowMaterial = _unlit(const Color(0xFF1E63B6));
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
    final slab = _meshNode(
      CuboidGeometry(vm.Vector3(9.2, .42, 9.2)),
      _floorMaterial,
      name: 'roof_slab',
      position: vm.Vector3(0, -.21, 0),
    );
    slab.shadowStatic = true;
    scene.add(slab);

    // Main grid and diagonals for a cleaner high-quality floor.
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
    final diagA = _meshNode(
      CuboidGeometry(vm.Vector3(.018, .012, arenaWorldSize * 1.33)),
      _gridMaterial,
      position: vm.Vector3(0, .013, 0),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 4),
    );
    final diagB = _meshNode(
      CuboidGeometry(vm.Vector3(.018, .012, arenaWorldSize * 1.33)),
      _gridMaterial,
      position: vm.Vector3(0, .013, 0),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -math.pi / 4),
    );
    diagA.castsShadows = false;
    diagB.castsShadows = false;
    scene.addAll([diagA, diagB]);

    const wallHeight = .24;
    for (final wall in <({vm.Vector3 size, vm.Vector3 pos})>[
      (size: vm.Vector3(9.2, wallHeight, .12), pos: vm.Vector3(0, wallHeight / 2, -4.54)),
      (size: vm.Vector3(9.2, wallHeight, .12), pos: vm.Vector3(0, wallHeight / 2, 4.54)),
      (size: vm.Vector3(.12, wallHeight, 9.2), pos: vm.Vector3(-4.54, wallHeight / 2, 0)),
      (size: vm.Vector3(.12, wallHeight, 9.2), pos: vm.Vector3(4.54, wallHeight / 2, 0)),
    ]) {
      final node = _meshNode(CuboidGeometry(wall.size), _parapetMaterial, position: wall.pos);
      node.shadowStatic = true;
      scene.add(node);
    }

    // Single dynamic obstacle used by gameplay.
    _obstacleRoot = Node(name: 'dynamic_obstacle');
    _obstacleRoot.visible = false;
    final obstacleBody = _meshNode(
      CuboidGeometry(vm.Vector3(1.05, .84, .82)),
      _obstacleSideMaterial,
      position: vm.Vector3(0, .42, 0),
    );
    obstacleBody.shadowStatic = false;
    final obstacleTop = _meshNode(
      CuboidGeometry(vm.Vector3(.92, .09, .70)),
      _obstacleTopMaterial,
      position: vm.Vector3(0, .89, 0),
    );
    final obstacleStrip = _meshNode(
      CuboidGeometry(vm.Vector3(.60, .024, .03)),
      _gridMaterial,
      position: vm.Vector3(0, .95, 0),
    );
    obstacleStrip.castsShadows = false;
    _obstacleRoot.addAll([obstacleBody, obstacleTop, obstacleStrip]);
    scene.add(_obstacleRoot);

    _buildCityBackdrop();
  }

  void _buildCityBackdrop() {
    final buildingMaterial = _pbr(const Color(0xFF09111E), roughness: .92, metallic: .02);
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

  void setObstacle({required bool visible, double x = .5, double y = .5}) {
    _obstacleRoot.visible = visible;
    if (!visible) return;
    final world = worldPosition(x, y);
    _obstacleRoot.position = vm.Vector3(world.x, 0, world.z);
  }

  KillerKilledFighterVisual addFighter(int id, Color accentColor) {
    final existing = fighters[id];
    if (existing != null) return existing;

    final accent = _pbr(accentColor, roughness: .34, metallic: .36);
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

    final leftLegPivot = Node(name: 'left_leg_pivot')..position = vm.Vector3(-.12, .58, 0);
    final rightLegPivot = Node(name: 'right_leg_pivot')..position = vm.Vector3(.12, .58, 0);

    leftLegPivot.add(_meshNode(_geo.upperLeg, _pantsMaterial, position: vm.Vector3(0, -.22, 0)));
    rightLegPivot.add(_meshNode(_geo.upperLeg, _pantsMaterial, position: vm.Vector3(0, -.22, 0)));
    leftLegPivot.add(_meshNode(_geo.lowerLeg, _pantsMaterial, position: vm.Vector3(0, -.48, .01)));
    rightLegPivot.add(_meshNode(_geo.lowerLeg, _pantsMaterial, position: vm.Vector3(0, -.48, .01)));
    leftLegPivot.add(_meshNode(_geo.boot, _blackClothMaterial, position: vm.Vector3(0, -.68, .05)));
    rightLegPivot.add(_meshNode(_geo.boot, _blackClothMaterial, position: vm.Vector3(0, -.68, .05)));
    root.addAll([leftLegPivot, rightLegPivot]);

    final torsoPivot = Node(name: 'torso_pivot')..position = vm.Vector3(0, 1.14, 0);
    final leftTailPivot = Node(name: 'left_tail_pivot')..position = vm.Vector3(-.17, -.33, -.06);
    final rightTailPivot = Node(name: 'right_tail_pivot')..position = vm.Vector3(.17, -.33, -.06);
    final backTailPivot = Node(name: 'back_tail_pivot')..position = vm.Vector3(0, -.31, -.11);

    torsoPivot.add(_meshNode(_geo.coreTorso, _darkClothMaterial, position: vm.Vector3(0, -.02, 0)));
    torsoPivot.add(_meshNode(_geo.coatBody, _blackClothMaterial, position: vm.Vector3(0, -.07, -.02)));
    torsoPivot.add(_meshNode(_geo.coatShoulders, _blackClothMaterial, position: vm.Vector3(0, .14, -.03)));
    torsoPivot.add(_meshNode(_geo.belt, _darkClothMaterial, position: vm.Vector3(0, -.22, .08)));
    torsoPivot.add(_meshNode(_geo.coatLining, accent, position: vm.Vector3(0, -.19, .11)));

    torsoPivot.add(
      _meshNode(
        _geo.lapel,
        _blackClothMaterial,
        position: vm.Vector3(-.12, .02, .14),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -.34),
      ),
    );
    torsoPivot.add(
      _meshNode(
        _geo.lapel,
        _blackClothMaterial,
        position: vm.Vector3(.12, .02, .14),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), .34),
      ),
    );

    leftTailPivot.add(
      _meshNode(
        _geo.coatTail,
        _blackClothMaterial,
        position: vm.Vector3(0, -.32, .01),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), .12),
      ),
    );
    rightTailPivot.add(
      _meshNode(
        _geo.coatTail,
        _blackClothMaterial,
        position: vm.Vector3(0, -.32, .01),
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -.12),
      ),
    );
    backTailPivot.add(_meshNode(_geo.backTail, _blackClothMaterial, position: vm.Vector3(0, -.34, -.06)));
    torsoPivot.addAll([leftTailPivot, rightTailPivot, backTailPivot]);

    final leftArmPivot = Node(name: 'left_arm_pivot')..position = vm.Vector3(-.29, .15, .02);
    final rightArmPivot = Node(name: 'right_arm_pivot')..position = vm.Vector3(.29, .15, .02);
    leftArmPivot.add(_meshNode(_geo.upperArm, _darkClothMaterial, position: vm.Vector3(0, -.14, .08), rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.5)));
    rightArmPivot.add(_meshNode(_geo.upperArm, _darkClothMaterial, position: vm.Vector3(0, -.14, .08), rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.5)));
    leftArmPivot.add(_meshNode(_geo.foreArm, _darkClothMaterial, position: vm.Vector3(0, -.28, .16), rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.25)));
    rightArmPivot.add(_meshNode(_geo.foreArm, _darkClothMaterial, position: vm.Vector3(0, -.28, .16), rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2.25)));
    leftArmPivot.add(_meshNode(_geo.glove, _gloveMaterial, position: vm.Vector3(0, -.37, .23)));
    rightArmPivot.add(_meshNode(_geo.glove, _gloveMaterial, position: vm.Vector3(0, -.37, .23)));
    torsoPivot.addAll([leftArmPivot, rightArmPivot]);

    final headPivot = Node(name: 'head_pivot')..position = vm.Vector3(0, .56, .01);
    headPivot.add(_meshNode(_geo.headCore, _skinMaterial, position: vm.Vector3(0, -.01, 0)));
    headPivot.add(_meshNode(_geo.mask, _blackClothMaterial, position: vm.Vector3(0, -.03, .13)));
    headPivot.add(_meshNode(_geo.highCollar, _blackClothMaterial, position: vm.Vector3(0, -.08, .02)));
    headPivot.add(_meshNode(_geo.collarWing, _blackClothMaterial, position: vm.Vector3(-.16, -.02, -.01), rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -.18)));
    headPivot.add(_meshNode(_geo.collarWing, _blackClothMaterial, position: vm.Vector3(.16, -.02, -.01), rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), .18)));
    headPivot.add(_meshNode(_geo.hatBrim, _blackClothMaterial, position: vm.Vector3(0, .20, 0), rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -.05)));
    headPivot.add(_meshNode(_geo.hatCrown, _blackClothMaterial, position: vm.Vector3(0, .30, 0)));
    headPivot.add(_meshNode(_geo.hatBand, accent, position: vm.Vector3(0, .255, 0)));
    headPivot.add(_meshNode(_geo.eyeWhite, _unlit(const Color(0xFFF6FFFF)), position: vm.Vector3(.078, .02, .158)));
    headPivot.add(_meshNode(_geo.eyeBlue, _unlit(const Color(0xFF61DDFF)), position: vm.Vector3(.088, .02, .174)));
    torsoPivot.add(headPivot);

    final gunPivot = Node(name: 'gun_pivot')..position = vm.Vector3(.09, .02, .24);
    gunPivot.add(_meshNode(_geo.gunBody, _metalMaterial, position: vm.Vector3(0, 0, .22)));
    gunPivot.add(_meshNode(_geo.gunBarrel, _metalMaterial, position: vm.Vector3(0, .02, .42)));
    gunPivot.add(_meshNode(_geo.gunHandle, _metalMaterial, position: vm.Vector3(-.01, -.12, .10), rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.30)));
    gunPivot.add(_meshNode(_geo.muzzleAccent, accent, position: vm.Vector3(0, .02, .57)));
    torsoPivot.add(gunPivot);

    final muzzleFlash = _meshNode(
      _geo.muzzleFlash,
      accentUnlit,
      name: 'muzzle_flash',
      position: vm.Vector3(.09, .58, .83),
      scale: vm.Vector3.zero(),
    )..castsShadows = false;

    final laser = _meshNode(
      _geo.laser,
      accentUnlit,
      name: 'laser',
      position: vm.Vector3(.09, .58, 3.2),
      scale: vm.Vector3(.6, .6, 6.0),
    )
      ..visible = false
      ..castsShadows = false;

    root.addAll([torsoPivot, muzzleFlash, laser]);

    return KillerKilledFighterVisual(
      root: root,
      torsoPivot: torsoPivot,
      headPivot: headPivot,
      leftLegPivot: leftLegPivot,
      rightLegPivot: rightLegPivot,
      leftArmPivot: leftArmPivot,
      rightArmPivot: rightArmPivot,
      leftTailPivot: leftTailPivot,
      rightTailPivot: rightTailPivot,
      backTailPivot: backTailPivot,
      gunPivot: gunPivot,
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
      final fallQ = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), fall * 1.34);
      visual.root.rotation = yawQ * fallQ;
    } else {
      visual.root.rotation = yawQ;
    }

    final movementStrength = (speed / .24).clamp(0.0, 1.0) * (1 - fall);
    final swing = math.sin(walkTime * 7.6) * .54 * movementStrength;
    final swing2 = math.sin(walkTime * 7.6 + math.pi / 2) * .16 * movementStrength;

    visual.leftLegPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), swing);
    visual.rightLegPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -swing);

    final coatSway = math.sin(walkTime * 6.7 + id) * .12 * movementStrength;
    visual.leftTailPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), .14 + coatSway);
    visual.rightTailPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), .14 - coatSway);
    visual.backTailPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), .10 + swing2 * .5);

    final firePose = activeShooter ? 1.0 : 0.0;
    final recoil = (shotFlash / .22).clamp(0.0, 1.0);
    visual.torsoPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.05 * firePose + .06 * recoil);
    visual.headPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), .06 * firePose);
    visual.leftArmPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.28 * firePose + .18 * recoil);
    visual.rightArmPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.36 * firePose + .26 * recoil);
    visual.gunPivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -.10 * firePose + .22 * recoil);

    final highlight = activeShooter ? _vectorColor(visual.accentColor, alpha: .72) : null;
    for (final meshNode in visual.root.meshNodes) {
      meshNode.highlightColor = highlight;
    }

    visual.laser.visible = laserVisible;
    if (laserVisible) {
      final safeLength = laserLength.clamp(.28, 8.2);
      visual.laser.position = vm.Vector3(.09, .58, .82 + safeLength / 2);
      visual.laser.scale = vm.Vector3(.68, .68, safeLength);
    }

    if (shotFlash > 0) {
      final pulse = (shotFlash / .22).clamp(0.0, 1.0);
      visual.muzzleFlash.scale = vm.Vector3.all(.70 + pulse * 1.25);
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
      scale: vm.Vector3(.74 + _random.nextDouble() * .58, 1, .54 + _random.nextDouble() * .48),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _random.nextDouble() * math.pi),
    )..castsShadows = false;
    scene.add(stain);
    _bloodNodes.add(stain);

    for (var i = 0; i < 4; i++) {
      final drop = _meshNode(
        _geo.bloodDrop,
        _bloodMaterial,
        position: vm.Vector3(
          world.x + (_random.nextDouble() - .5) * .46,
          .019,
          world.z + (_random.nextDouble() - .5) * .46,
        ),
        scale: vm.Vector3.all(.28 + _random.nextDouble() * .35),
      )..castsShadows = false;
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
    return vm.Vector3((x - .5) * arenaWorldSize, height, (y - .5) * arenaWorldSize);
  }

  PerspectiveCamera cameraFor(double seconds, double focusX, double focusY) {
    final focus = worldPosition(focusX, focusY, height: .82);
    final swayX = math.sin(seconds * .34) * .08;
    final swayZ = math.cos(seconds * .30) * .08;
    return PerspectiveCamera(
      position: vm.Vector3(8.1 + swayX, 6.1, 8.1 + swayZ),
      target: vm.Vector3(focus.x * .18, .82, focus.z * .18),
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: 32 * math.pi / 180,
      fovNear: .1,
      fovFar: 75,
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
    return camera.worldToScreen(worldPosition(x, y, height: fighterLabelHeight), viewSize);
  }
}

class KillerKilledFighterVisual {
  KillerKilledFighterVisual({
    required this.root,
    required this.torsoPivot,
    required this.headPivot,
    required this.leftLegPivot,
    required this.rightLegPivot,
    required this.leftArmPivot,
    required this.rightArmPivot,
    required this.leftTailPivot,
    required this.rightTailPivot,
    required this.backTailPivot,
    required this.gunPivot,
    required this.laser,
    required this.muzzleFlash,
    required this.accentColor,
  });

  final Node root;
  final Node torsoPivot;
  final Node headPivot;
  final Node leftLegPivot;
  final Node rightLegPivot;
  final Node leftArmPivot;
  final Node rightArmPivot;
  final Node leftTailPivot;
  final Node rightTailPivot;
  final Node backTailPivot;
  final Node gunPivot;
  final Node laser;
  final Node muzzleFlash;
  final Color accentColor;
}

class _GeometryBank {
  _GeometryBank()
      : coreTorso = CapsuleGeometry(radius: .19, height: .42, radialSegments: 12, capRings: 4),
        coatBody = CuboidGeometry(vm.Vector3(.54, .78, .30)),
        coatShoulders = CuboidGeometry(vm.Vector3(.70, .18, .36)),
        belt = CuboidGeometry(vm.Vector3(.40, .05, .08)),
        lapel = CuboidGeometry(vm.Vector3(.10, .34, .05)),
        headCore = CapsuleGeometry(radius: .16, height: .11, radialSegments: 12, capRings: 4),
        upperLeg = CapsuleGeometry(radius: .072, height: .34, radialSegments: 8, capRings: 3),
        lowerLeg = CapsuleGeometry(radius: .062, height: .26, radialSegments: 8, capRings: 3),
        upperArm = CapsuleGeometry(radius: .052, height: .24, radialSegments: 8, capRings: 3),
        foreArm = CapsuleGeometry(radius: .046, height: .22, radialSegments: 8, capRings: 3),
        glove = CuboidGeometry(vm.Vector3(.10, .06, .13)),
        boot = CuboidGeometry(vm.Vector3(.18, .11, .31)),
        coatTail = CuboidGeometry(vm.Vector3(.20, .68, .08)),
        backTail = CuboidGeometry(vm.Vector3(.34, .70, .09)),
        coatLining = CuboidGeometry(vm.Vector3(.16, .58, .04)),
        mask = CuboidGeometry(vm.Vector3(.30, .19, .10)),
        highCollar = CuboidGeometry(vm.Vector3(.34, .16, .18)),
        collarWing = CuboidGeometry(vm.Vector3(.11, .24, .06)),
        hatBrim = DiscGeometry(radius: .33, segments: 28),
        hatCrown = CapsuleGeometry(radius: .17, height: .14, radialSegments: 14, capRings: 4),
        hatBand = TorusGeometry(radius: .17, tubeRadius: .022, radialSegments: 20, tubularSegments: 6),
        eyeWhite = CuboidGeometry(vm.Vector3(.11, .036, .019)),
        eyeBlue = IcosphereGeometry(radius: .020, subdivisions: 1),
        gunBody = CuboidGeometry(vm.Vector3(.082, .08, .40)),
        gunBarrel = CuboidGeometry(vm.Vector3(.05, .05, .18)),
        gunHandle = CuboidGeometry(vm.Vector3(.08, .20, .09)),
        muzzleAccent = CuboidGeometry(vm.Vector3(.10, .10, .04)),
        laser = CuboidGeometry(vm.Vector3(.020, .020, 1)),
        muzzleFlash = IcosphereGeometry(radius: .06, subdivisions: 1),
        bloodDisc = DiscGeometry(radius: .28, segments: 20),
        bloodDrop = DiscGeometry(radius: .10, segments: 14);

  final Geometry coreTorso;
  final Geometry coatBody;
  final Geometry coatShoulders;
  final Geometry belt;
  final Geometry lapel;
  final Geometry headCore;
  final Geometry upperLeg;
  final Geometry lowerLeg;
  final Geometry upperArm;
  final Geometry foreArm;
  final Geometry glove;
  final Geometry boot;
  final Geometry coatTail;
  final Geometry backTail;
  final Geometry coatLining;
  final Geometry mask;
  final Geometry highCollar;
  final Geometry collarWing;
  final Geometry hatBrim;
  final Geometry hatCrown;
  final Geometry hatBand;
  final Geometry eyeWhite;
  final Geometry eyeBlue;
  final Geometry gunBody;
  final Geometry gunBarrel;
  final Geometry gunHandle;
  final Geometry muzzleAccent;
  final Geometry laser;
  final Geometry muzzleFlash;
  final Geometry bloodDisc;
  final Geometry bloodDrop;
}
